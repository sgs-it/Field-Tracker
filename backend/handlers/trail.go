package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// GetTrail returns today's GPS breadcrumb trail for a specific worker
func GetTrail(c *gin.Context) {
	workerID := c.Param("workerId")

	// Optional: allow querying a specific date via ?date=2026-06-18
	dateStr := c.Query("date")
	var startOfDay, endOfDay time.Time
	if dateStr != "" {
		parsed, err := time.Parse("2006-01-02", dateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid date format, use YYYY-MM-DD"})
			return
		}
		startOfDay = parsed
		endOfDay = parsed.Add(24 * time.Hour)
	} else {
		now := time.Now()
		startOfDay = time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
		endOfDay = startOfDay.Add(24 * time.Hour)
	}

	rows, err := db.Query(`
		SELECT lat, lng, accuracy, recorded_at
		FROM gps_trail
		WHERE worker_id = $1
		  AND recorded_at >= $2
		  AND recorded_at < $3
		ORDER BY recorded_at ASC
	`, workerID, startOfDay, endOfDay)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	trail := []TrailPoint{}
	for rows.Next() {
		var pt TrailPoint
		if err := rows.Scan(&pt.Lat, &pt.Lng, &pt.Accuracy, &pt.RecordedAt); err != nil {
			continue
		}
		trail = append(trail, pt)
	}

	c.JSON(http.StatusOK, gin.H{
		"workerId": workerID,
		"date":     startOfDay.Format("2006-01-02"),
		"count":    len(trail),
		"trail":    trail,
	})
}

// PostHeartbeat is the REST fallback for workers with no active WebSocket connection.
// Called during offline-sync when internet is restored.
func PostHeartbeat(c *gin.Context) {
	var req HeartbeatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Timestamp.IsZero() {
		req.Timestamp = time.Now()
	}

	// Save to gps_trail
	_, err := db.Exec(`
		INSERT INTO gps_trail (worker_id, worker_name, lat, lng, accuracy, is_on_shift, recorded_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		req.WorkerID, req.WorkerName, req.Lat, req.Lng,
		req.Accuracy, req.IsOnShift, req.Timestamp,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Also broadcast to admins via WebSocket hub (if any admin is connected)
	broadcast <- BroadcastMessage{
		Type:       "location_update",
		WorkerID:   req.WorkerID,
		WorkerName: req.WorkerName,
		Lat:        req.Lat,
		Lng:        req.Lng,
		Accuracy:   req.Accuracy,
		Timestamp:  req.Timestamp,
		IsOnShift:  req.IsOnShift,
	}

	c.JSON(http.StatusOK, gin.H{"message": "heartbeat recorded"})
}
