package main

import (
	"log"
	"os"

	"field-tracker-backend/handlers"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env file if it exists
	_ = godotenv.Load()

	// Connect to PostgreSQL
	if err := handlers.InitDB(); err != nil {
		log.Fatalf("Failed to connect to PostgreSQL: %v", err)
	}
	defer handlers.CloseDB()

	// Run DB migrations (create tables if not exist)
	if err := handlers.RunMigrations(); err != nil {
		log.Fatalf("Migration failed: %v", err)
	}

	// Start WebSocket hub in background
	go handlers.RunHub()

	// Set up Gin router
	r := gin.Default()

	// CORS middleware (required for Flutter Web)
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "SGS Field Tracker Backend"})
	})

	// WebSocket endpoint
	r.GET("/ws", handlers.HandleWebSocket)

	// API routes
	api := r.Group("/api")
	{
		// Worker locations (latest positions in memory)
		api.GET("/locations", handlers.GetLocations)

		// GPS trail for a specific worker (today)
		api.GET("/trail/:workerId", handlers.GetTrail)

		// Offline sync fallback
		api.POST("/heartbeat", handlers.PostHeartbeat)

		// Geofence CRUD
		api.GET("/geofences", handlers.GetGeofences)
		api.POST("/geofences", handlers.CreateGeofence)
		api.PUT("/geofences/:id", handlers.UpdateGeofence)
		api.DELETE("/geofences/:id", handlers.DeleteGeofence)

		// Workers CRUD
		api.GET("/workers", handlers.GetWorkers)
		api.POST("/workers", handlers.CreateWorker)
		api.PUT("/workers/:id", handlers.UpdateWorker)
		api.DELETE("/workers/:id", handlers.DeleteWorker)

		// Users CRUD
		api.GET("/users", handlers.GetUsers)
		api.POST("/users", handlers.CreateUser)
		api.DELETE("/users/:id", handlers.DeleteUser)

		// Assignments CRUD
		api.GET("/assignments", handlers.GetAssignments)
		api.POST("/assignments", handlers.CreateAssignment)
		api.DELETE("/assignments/:id", handlers.DeleteAssignment)

		// Attendance CRUD
		api.GET("/attendance", handlers.GetAttendance)
		api.POST("/attendance", handlers.CreateAttendance)
		api.PUT("/attendance/:id", handlers.UpdateAttendance)

		// Tamper Alerts
		api.GET("/alerts", handlers.GetAlerts)
		api.POST("/alerts", handlers.CreateAlert)

		// Heartbeats
		api.GET("/heartbeats", handlers.GetHeartbeats)
		api.POST("/heartbeats", handlers.CreateHeartbeatLog)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 SGS Field Tracker Backend running on 0.0.0.0:%s", port)
	log.Printf("📡 WebSocket: ws://0.0.0.0:%s/ws", port)
	log.Printf("🗺️  API: http://0.0.0.0:%s/api/...", port)

	if err := r.Run("0.0.0.0:" + port); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
