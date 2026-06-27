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

// User represents a system user (Admin, Engineer, Supervisor)
type User struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Username  string    `json:"username"`
	Password  string    `json:"password"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"createdAt"`
}

// Worker represents a worker in the system
type Worker struct {
	ID                 string    `json:"id"`
	EmployeeID         string    `json:"employeeId"`
	Name               string    `json:"name"`
	Phone              string    `json:"phone"`
	StaffType          string    `json:"staffType"`
	StaffCategory      string    `json:"staffCategory"`
	LeaveCategory      string    `json:"leaveCategory"`
	Department         string    `json:"department"`
	Designation        string    `json:"designation"`
	Username           string    `json:"username"`
	Password           string    `json:"password"`
	StaffHierarchy     string    `json:"staffHierarchy"`
	IsActive           bool      `json:"isActive"`
	EmiratesID         string    `json:"emiratesId"`
	EmiratesIDExpiry   time.Time `json:"emiratesIdExpiry"`
	PassportNo         string    `json:"passportNo"`
	PassportExpiry     time.Time `json:"passportExpiry"`
	LabourCardNo       string    `json:"labourCardNo"`
	LabourCardExpiry   time.Time `json:"labourCardExpiry"`
	JoinedDate         time.Time `json:"joinedDate"`
	LeaveDueDate       time.Time `json:"leaveDueDate"`
	CreatedAt          time.Time `json:"createdAt"`
}

// ChecklistItem is a checklist task
type ChecklistItem struct {
	ID          string `json:"id"`
	Task        string `json:"task"`
	Category    string `json:"category"`
	IsCompleted bool   `json:"isCompleted"`
}

// Assignment represents a worker site assignment
type Assignment struct {
	ID           string          `json:"id"`
	WorkerID     string          `json:"workerId"`
	SiteID       string          `json:"siteId"`
	Date         time.Time       `json:"date"`
	Shift        string          `json:"shift"`
	Instructions string          `json:"instructions"`
	Checklist    []ChecklistItem `json:"checklist"`
	Priority     string          `json:"priority"`
	BreakTime    string          `json:"breakTime"`
	CreatedAt    time.Time       `json:"createdAt"`
}

// VisitRecord is a record of a geofence site visit
type VisitRecord struct {
	SiteID           string          `json:"siteId"`
	EntryTime        *time.Time      `json:"entryTime,omitempty"`
	ExitTime         *time.Time      `json:"exitTime,omitempty"`
	Status           string          `json:"status"`
	ChecklistAtVisit []ChecklistItem `json:"checklistAtVisit"`
	PhotoPath        *string         `json:"photoPath,omitempty"`
	Comments         *string         `json:"comments,omitempty"`
}

// AttendanceRecord represents a daily attendance record
type AttendanceRecord struct {
	ID                 string        `json:"id"`
	WorkerID           string        `json:"workerId"`
	Date               time.Time     `json:"date"`
	ShiftStart         *time.Time    `json:"shiftStart,omitempty"`
	ShiftEnd           *time.Time    `json:"shiftEnd,omitempty"`
	Visits             []VisitRecord `json:"visits"`
	OvertimeHours      float64       `json:"overtimeHours"`
	NormalHours        float64       `json:"normalHours"`
	Status             string        `json:"status"`
	SupervisorComments string        `json:"supervisorComments"`
	IsApproved         bool          `json:"isApproved"`
	CreatedAt          time.Time     `json:"createdAt"`
}

// TamperAlert represents a GPS or internet tampering alert
type TamperAlert struct {
	ID        string    `json:"id"`
	WorkerID  string    `json:"workerId"`
	Timestamp time.Time `json:"timestamp"`
	AlertType string    `json:"alertType"`
	Details   string    `json:"details"`
	CreatedAt time.Time `json:"createdAt"`
}

// HeartbeatLog represents a heartbeat log
type HeartbeatLog struct {
	ID        string    `json:"id"`
	WorkerID  string    `json:"workerId"`
	Timestamp time.Time `json:"timestamp"`
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	CreatedAt time.Time `json:"createdAt"`
}
