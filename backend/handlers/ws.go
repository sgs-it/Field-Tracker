package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

// ─── WebSocket Upgrader ───────────────────────────────────────────────────────

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins (CORS handled by Gin middleware)
	},
}

// ─── Hub ─────────────────────────────────────────────────────────────────────

type client struct {
	conn     *websocket.Conn
	role     string // "admin" or "worker"
	workerID string
	send     chan []byte
	mu       sync.Mutex
}

var (
	adminClients   = make(map[*client]bool)
	workerClients  = make(map[string]*client) // workerID → client
	latestLocations = make(map[string]LocationUpdate) // workerID → latest location
	hubMu          sync.RWMutex

	broadcast  = make(chan BroadcastMessage, 256)
	register   = make(chan *client, 64)
	unregister = make(chan *client, 64)
)

// RunHub runs the central hub goroutine that manages all connected clients
func RunHub() {
	for {
		select {
		case c := <-register:
			hubMu.Lock()
			if c.role == "admin" {
				adminClients[c] = true
				log.Printf("Admin client connected (total admins: %d)", len(adminClients))

				// Send all current worker locations to the newly connected admin
				for _, loc := range latestLocations {
					msg := BroadcastMessage{
						Type:       "location_update",
						WorkerID:   loc.WorkerID,
						WorkerName: loc.WorkerName,
						Lat:        loc.Lat,
						Lng:        loc.Lng,
						Accuracy:   loc.Accuracy,
						Timestamp:  loc.Timestamp,
						IsOnShift:  loc.IsOnShift,
					}
					data, _ := json.Marshal(msg)
					c.safeSend(data)
				}
			} else {
				// Worker connected — notify all admins
				workerClients[c.workerID] = c
				log.Printf("Worker '%s' connected", c.workerID)
				broadcast <- BroadcastMessage{
					Type:     "worker_online",
					WorkerID: c.workerID,
				}
			}
			hubMu.Unlock()

		case c := <-unregister:
			hubMu.Lock()
			if c.role == "admin" {
				delete(adminClients, c)
				log.Printf("Admin client disconnected (total admins: %d)", len(adminClients))
			} else {
				if existing, ok := workerClients[c.workerID]; ok && existing == c {
					delete(workerClients, c.workerID)
					log.Printf("Worker '%s' disconnected", c.workerID)
					broadcast <- BroadcastMessage{
						Type:     "worker_offline",
						WorkerID: c.workerID,
					}
				}
			}
			close(c.send)
			hubMu.Unlock()

		case msg := <-broadcast:
			data, err := json.Marshal(msg)
			if err != nil {
				continue
			}
			hubMu.RLock()
			for c := range adminClients {
				c.safeSend(data)
			}
			hubMu.RUnlock()
		}
	}
}

func (c *client) safeSend(data []byte) {
	select {
	case c.send <- data:
	default:
		// Client send buffer full — drop message
	}
}

// ─── WebSocket Handler ────────────────────────────────────────────────────────

// HandleWebSocket upgrades the HTTP connection to WebSocket.
// Query params: role=admin|worker, workerId=<id>, workerName=<name>
func HandleWebSocket(c *gin.Context) {
	role := c.Query("role")
	if role != "admin" && role != "worker" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "role must be 'admin' or 'worker'"})
		return
	}

	workerID := c.Query("workerId")
	if role == "worker" && workerID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "workerId required for worker role"})
		return
	}
	workerName := c.Query("workerName")

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	cl := &client{
		conn:     conn,
		role:     role,
		workerID: workerID,
		send:     make(chan []byte, 256),
	}

	register <- cl

	// Start goroutines for reading and writing
	go cl.writePump()
	cl.readPump(workerName)
}

// readPump reads messages from the WebSocket connection.
// For worker clients, it processes location updates.
// For admin clients, it just keeps the connection alive.
func (c *client) readPump(workerName string) {
	defer func() {
		unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(4096)
	c.conn.SetReadDeadline(time.Now().Add(90 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(90 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket read error for %s: %v", c.workerID, err)
			}
			break
		}

		if c.role != "worker" {
			continue // Admins don't send data
		}

		var loc LocationUpdate
		if err := json.Unmarshal(message, &loc); err != nil {
			log.Printf("Invalid location message from %s: %v", c.workerID, err)
			continue
		}

		if loc.Type != "location" {
			continue
		}

		// Ensure worker identity is set
		loc.WorkerID = c.workerID
		if loc.WorkerName == "" {
			loc.WorkerName = workerName
		}
		if loc.Timestamp.IsZero() {
			loc.Timestamp = time.Now()
		}

		// Save to latest locations (in-memory)
		hubMu.Lock()
		latestLocations[c.workerID] = loc
		hubMu.Unlock()

		// Persist to PostgreSQL gps_trail table
		go saveTrailPoint(loc)

		// Broadcast to all admin clients
		broadcast <- BroadcastMessage{
			Type:       "location_update",
			WorkerID:   loc.WorkerID,
			WorkerName: loc.WorkerName,
			Lat:        loc.Lat,
			Lng:        loc.Lng,
			Accuracy:   loc.Accuracy,
			Timestamp:  loc.Timestamp,
			IsOnShift:  loc.IsOnShift,
		}
	}
}

// writePump sends queued messages to the WebSocket client.
func (c *client) writePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			// Send ping to keep connection alive
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// saveTrailPoint persists a single GPS ping to PostgreSQL
func saveTrailPoint(loc LocationUpdate) {
	_, err := db.Exec(`
		INSERT INTO gps_trail (worker_id, worker_name, lat, lng, accuracy, is_on_shift, recorded_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		loc.WorkerID, loc.WorkerName, loc.Lat, loc.Lng,
		loc.Accuracy, loc.IsOnShift, loc.Timestamp,
	)
	if err != nil {
		log.Printf("Failed to save trail point for %s: %v", loc.WorkerID, err)
	}
}

// ─── REST: Get all latest locations ──────────────────────────────────────────

// GetLocations returns the latest known position for all connected workers
func GetLocations(c *gin.Context) {
	hubMu.RLock()
	locations := make([]LocationUpdate, 0, len(latestLocations))
	for _, loc := range latestLocations {
		locations = append(locations, loc)
	}
	hubMu.RUnlock()
	c.JSON(http.StatusOK, locations)
}
