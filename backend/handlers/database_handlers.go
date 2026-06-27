package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
)

// Helpers
func jsonArg(v interface{}) interface{} {
	data, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	return data
}

// ── WORKERS CRUD ─────────────────────────────────────────────────────────────

func GetWorkers(c *gin.Context) {
	rows, err := db.Query(`
		SELECT id, employee_id, name, phone, staff_type, staff_category, leave_category,
		       department, designation, username, password, staff_hierarchy, is_active,
		       emirates_id, emirates_id_expiry, passport_no, passport_expiry,
		       labour_card_no, labour_card_expiry, joined_date, leave_due_date
		FROM workers
		ORDER BY created_at DESC
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	workers := []Worker{}
	for rows.Next() {
		var w Worker
		err := rows.Scan(
			&w.ID, &w.EmployeeID, &w.Name, &w.Phone, &w.StaffType, &w.StaffCategory, &w.LeaveCategory,
			&w.Department, &w.Designation, &w.Username, &w.Password, &w.StaffHierarchy, &w.IsActive,
			&w.EmiratesID, &w.EmiratesIDExpiry, &w.PassportNo, &w.PassportExpiry,
			&w.LabourCardNo, &w.LabourCardExpiry, &w.JoinedDate, &w.LeaveDueDate,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		workers = append(workers, w)
	}
	c.JSON(http.StatusOK, workers)
}

func CreateWorker(c *gin.Context) {
	var w Worker
	if err := c.ShouldBindJSON(&w); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := db.Exec(`
		INSERT INTO workers (
			id, employee_id, name, phone, staff_type, staff_category, leave_category,
			department, designation, username, password, staff_hierarchy, is_active,
			emirates_id, emirates_id_expiry, passport_no, passport_expiry,
			labour_card_no, labour_card_expiry, joined_date, leave_due_date
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
		ON CONFLICT (id) DO UPDATE SET
			employee_id = EXCLUDED.employee_id,
			name = EXCLUDED.name,
			phone = EXCLUDED.phone,
			staff_type = EXCLUDED.staff_type,
			staff_category = EXCLUDED.staff_category,
			leave_category = EXCLUDED.leave_category,
			department = EXCLUDED.department,
			designation = EXCLUDED.designation,
			username = EXCLUDED.username,
			password = EXCLUDED.password,
			staff_hierarchy = EXCLUDED.staff_hierarchy,
			is_active = EXCLUDED.is_active,
			emirates_id = EXCLUDED.emirates_id,
			emirates_id_expiry = EXCLUDED.emirates_id_expiry,
			passport_no = EXCLUDED.passport_no,
			passport_expiry = EXCLUDED.passport_expiry,
			labour_card_no = EXCLUDED.labour_card_no,
			labour_card_expiry = EXCLUDED.labour_card_expiry,
			joined_date = EXCLUDED.joined_date,
			leave_due_date = EXCLUDED.leave_due_date
	`, w.ID, w.EmployeeID, w.Name, w.Phone, w.StaffType, w.StaffCategory, w.LeaveCategory,
		w.Department, w.Designation, w.Username, w.Password, w.StaffHierarchy, w.IsActive,
		w.EmiratesID, w.EmiratesIDExpiry, w.PassportNo, w.PassportExpiry,
		w.LabourCardNo, w.LabourCardExpiry, w.JoinedDate, w.LeaveDueDate)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, w)
}

func UpdateWorker(c *gin.Context) {
	id := c.Param("id")
	var w Worker
	if err := c.ShouldBindJSON(&w); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := db.Exec(`
		UPDATE workers
		SET employee_id = $1, name = $2, phone = $3, staff_type = $4, staff_category = $5,
		    leave_category = $6, department = $7, designation = $8, username = $9,
		    password = $10, staff_hierarchy = $11, is_active = $12, emirates_id = $13,
		    emirates_id_expiry = $14, passport_no = $15, passport_expiry = $16,
		    labour_card_no = $17, labour_card_expiry = $18, joined_date = $19, leave_due_date = $20
		WHERE id = $21
	`, w.EmployeeID, w.Name, w.Phone, w.StaffType, w.StaffCategory, w.LeaveCategory,
		w.Department, w.Designation, w.Username, w.Password, w.StaffHierarchy, w.IsActive,
		w.EmiratesID, w.EmiratesIDExpiry, w.PassportNo, w.PassportExpiry,
		w.LabourCardNo, w.LabourCardExpiry, w.JoinedDate, w.LeaveDueDate, id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "worker not found"})
		return
	}
	c.JSON(http.StatusOK, w)
}

func DeleteWorker(c *gin.Context) {
	id := c.Param("id")
	result, err := db.Exec("DELETE FROM workers WHERE id = $1", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "worker not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "worker deleted", "id": id})
}

// ── USERS CRUD ───────────────────────────────────────────────────────────────

func GetUsers(c *gin.Context) {
	rows, err := db.Query("SELECT id, name, username, password, role, created_at FROM users ORDER BY name ASC")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	users := []User{}
	for rows.Next() {
		var u User
		err := rows.Scan(&u.ID, &u.Name, &u.Username, &u.Password, &u.Role, &u.CreatedAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		users = append(users, u)
	}
	c.JSON(http.StatusOK, users)
}

func CreateUser(c *gin.Context) {
	var u User
	if err := c.ShouldBindJSON(&u); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var id string
	err := db.QueryRow(`
		INSERT INTO users (name, username, password, role)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at
	`, u.Name, u.Username, u.Password, u.Role).Scan(&id, &u.CreatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	u.ID = id
	c.JSON(http.StatusCreated, u)
}

func DeleteUser(c *gin.Context) {
	id := c.Param("id")
	result, err := db.Exec("DELETE FROM users WHERE id = $1", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "user deleted", "id": id})
}

// ── ASSIGNMENTS CRUD ─────────────────────────────────────────────────────────

func GetAssignments(c *gin.Context) {
	rows, err := db.Query("SELECT id, worker_id, site_id, date, shift, instructions, checklist, priority, break_time FROM assignments")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	assignments := []Assignment{}
	for rows.Next() {
		var a Assignment
		var checklistJSON sql.NullString
		err := rows.Scan(&a.ID, &a.WorkerID, &a.SiteID, &a.Date, &a.Shift, &a.Instructions, &checklistJSON, &a.Priority, &a.BreakTime)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if checklistJSON.Valid && checklistJSON.String != "" {
			var checklist []ChecklistItem
			if err := json.Unmarshal([]byte(checklistJSON.String), &checklist); err == nil {
				a.Checklist = checklist
			}
		} else {
			a.Checklist = []ChecklistItem{}
		}
		assignments = append(assignments, a)
	}
	c.JSON(http.StatusOK, assignments)
}

func CreateAssignment(c *gin.Context) {
	var a Assignment
	if err := c.ShouldBindJSON(&a); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := db.Exec(`
		INSERT INTO assignments (id, worker_id, site_id, date, shift, instructions, checklist, priority, break_time)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (id) DO UPDATE SET
			worker_id = EXCLUDED.worker_id,
			site_id = EXCLUDED.site_id,
			date = EXCLUDED.date,
			shift = EXCLUDED.shift,
			instructions = EXCLUDED.instructions,
			checklist = EXCLUDED.checklist,
			priority = EXCLUDED.priority,
			break_time = EXCLUDED.break_time
	`, a.ID, a.WorkerID, a.SiteID, a.Date, a.Shift, a.Instructions, jsonArg(a.Checklist), a.Priority, a.BreakTime)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, a)
}

func DeleteAssignment(c *gin.Context) {
	id := c.Param("id")
	result, err := db.Exec("DELETE FROM assignments WHERE id = $1", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "assignment not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "assignment deleted", "id": id})
}

// ── ATTENDANCE CRUD ──────────────────────────────────────────────────────────

func GetAttendance(c *gin.Context) {
	rows, err := db.Query(`
		SELECT id, worker_id, date, shift_start, shift_end, visits, overtime_hours, normal_hours,
		       status, supervisor_comments, is_approved
		FROM attendance
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	records := []AttendanceRecord{}
	for rows.Next() {
		var a AttendanceRecord
		var visitsJSON sql.NullString
		err := rows.Scan(&a.ID, &a.WorkerID, &a.Date, &a.ShiftStart, &a.ShiftEnd, &visitsJSON,
			&a.OvertimeHours, &a.NormalHours, &a.Status, &a.SupervisorComments, &a.IsApproved)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if visitsJSON.Valid && visitsJSON.String != "" {
			var visits []VisitRecord
			if err := json.Unmarshal([]byte(visitsJSON.String), &visits); err == nil {
				a.Visits = visits
			}
		} else {
			a.Visits = []VisitRecord{}
		}
		records = append(records, a)
	}
	c.JSON(http.StatusOK, records)
}

func CreateAttendance(c *gin.Context) {
	var a AttendanceRecord
	if err := c.ShouldBindJSON(&a); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := db.Exec(`
		INSERT INTO attendance (id, worker_id, date, shift_start, shift_end, visits, overtime_hours, normal_hours,
		                        status, supervisor_comments, is_approved)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		ON CONFLICT (id) DO UPDATE SET
			shift_start = EXCLUDED.shift_start,
			shift_end = EXCLUDED.shift_end,
			visits = EXCLUDED.visits,
			overtime_hours = EXCLUDED.overtime_hours,
			normal_hours = EXCLUDED.normal_hours,
			status = EXCLUDED.status,
			supervisor_comments = EXCLUDED.supervisor_comments,
			is_approved = EXCLUDED.is_approved
	`, a.ID, a.WorkerID, a.Date, a.ShiftStart, a.ShiftEnd, jsonArg(a.Visits), a.OvertimeHours, a.NormalHours,
		a.Status, a.SupervisorComments, a.IsApproved)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, a)
}

func UpdateAttendance(c *gin.Context) {
	id := c.Param("id")
	var a AttendanceRecord
	if err := c.ShouldBindJSON(&a); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := db.Exec(`
		UPDATE attendance
		SET shift_start = $1, shift_end = $2, visits = $3, overtime_hours = $4, normal_hours = $5,
		    status = $6, supervisor_comments = $7, is_approved = $8
		WHERE id = $9
	`, a.ShiftStart, a.ShiftEnd, jsonArg(a.Visits), a.OvertimeHours, a.NormalHours,
		a.Status, a.SupervisorComments, a.IsApproved, id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "attendance record not found"})
		return
	}
	c.JSON(http.StatusOK, a)
}

// ── TAMPER ALERTS ────────────────────────────────────────────────────────────

func GetAlerts(c *gin.Context) {
	rows, err := db.Query("SELECT id, worker_id, timestamp, alert_type, details FROM tamper_alerts ORDER BY timestamp DESC")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	alerts := []TamperAlert{}
	for rows.Next() {
		var a TamperAlert
		err := rows.Scan(&a.ID, &a.WorkerID, &a.Timestamp, &a.AlertType, &a.Details)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		alerts = append(alerts, a)
	}
	c.JSON(http.StatusOK, alerts)
}

func CreateAlert(c *gin.Context) {
	var a TamperAlert
	if err := c.ShouldBindJSON(&a); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := db.Exec(`
		INSERT INTO tamper_alerts (id, worker_id, timestamp, alert_type, details)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (id) DO NOTHING
	`, a.ID, a.WorkerID, a.Timestamp, a.AlertType, a.Details)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, a)
}

// ── HEARTBEAT LOGS ───────────────────────────────────────────────────────────

func GetHeartbeats(c *gin.Context) {
	rows, err := db.Query("SELECT id, worker_id, timestamp, latitude, longitude FROM heartbeat_logs ORDER BY timestamp DESC")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	logs := []HeartbeatLog{}
	for rows.Next() {
		var l HeartbeatLog
		err := rows.Scan(&l.ID, &l.WorkerID, &l.Timestamp, &l.Latitude, &l.Longitude)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		logs = append(logs, l)
	}
	c.JSON(http.StatusOK, logs)
}

func CreateHeartbeatLog(c *gin.Context) {
	var l HeartbeatLog
	if err := c.ShouldBindJSON(&l); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := db.Exec(`
		INSERT INTO heartbeat_logs (id, worker_id, timestamp, latitude, longitude)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (id) DO NOTHING
	`, l.ID, l.WorkerID, l.Timestamp, l.Latitude, l.Longitude)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, l)
}
