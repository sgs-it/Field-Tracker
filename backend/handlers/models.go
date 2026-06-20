package handlers

import "time"

// LocationUpdate is the message sent by a worker client over WebSocket
type LocationUpdate struct {
	Type       string    `json:"type"`       // "location"
	WorkerID   string    `json:"workerId"`
	WorkerName string    `json:"workerName"`
	Lat        float64   `json:"lat"`
	Lng        float64   `json:"lng"`
	Accuracy   float64   `json:"accuracy"`
	Timestamp  time.Time `json:"timestamp"`
	IsOnShift  bool      `json:"isOnShift"`
}

// BroadcastMessage is sent from the server to all admin clients
type BroadcastMessage struct {
	Type       string    `json:"type"` // "location_update", "worker_online", "worker_offline"
	WorkerID   string    `json:"workerId"`
	WorkerName string    `json:"workerName,omitempty"`
	Lat        float64   `json:"lat,omitempty"`
	Lng        float64   `json:"lng,omitempty"`
	Accuracy   float64   `json:"accuracy,omitempty"`
	Timestamp  time.Time `json:"timestamp,omitempty"`
	IsOnShift  bool      `json:"isOnShift,omitempty"`
}

// Geofence represents a stored geofence in PostgreSQL
type Geofence struct {
	ID               string          `json:"id"`
	Name             string          `json:"name"`
	SiteID           *string         `json:"siteId,omitempty"`
	Type             string          `json:"type"` // "circle" or "polygon"
	Lat              *float64        `json:"lat,omitempty"`
	Lng              *float64        `json:"lng,omitempty"`
	RadiusM          *float64        `json:"radiusM,omitempty"`
	Polygon          *[]PolygonPoint `json:"polygon,omitempty"`
	Color            string          `json:"color"`
	CreatedAt        time.Time       `json:"createdAt"`
	UpdatedAt        time.Time       `json:"updatedAt"`
	Code             string          `json:"code"`
	Category         string          `json:"category"`
	SubCategory      string          `json:"subCategory"`
	JobType          string          `json:"jobType"`
	Frequency        string          `json:"frequency"`
	Address          string          `json:"address"`
	PlannedStartTime string          `json:"plannedStartTime"`
	PlannedEndTime   string          `json:"plannedEndTime"`
	IsAccommodation  bool            `json:"isAccommodation"`
}

// PolygonPoint is a lat/lng coordinate for polygon geofences
type PolygonPoint struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

// TrailPoint is a single GPS point in a worker's trail
type TrailPoint struct {
	Lat        float64   `json:"lat"`
	Lng        float64   `json:"lng"`
	Accuracy   float64   `json:"accuracy"`
	RecordedAt time.Time `json:"recordedAt"`
}

// HeartbeatRequest is used by the offline-sync REST endpoint
type HeartbeatRequest struct {
	WorkerID   string    `json:"workerId" binding:"required"`
	WorkerName string    `json:"workerName"`
	Lat        float64   `json:"lat" binding:"required"`
	Lng        float64   `json:"lng" binding:"required"`
	Accuracy   float64   `json:"accuracy"`
	IsOnShift  bool      `json:"isOnShift"`
	Timestamp  time.Time `json:"timestamp"`
}
