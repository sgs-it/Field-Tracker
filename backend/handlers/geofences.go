package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// jsonbArg returns nil (SQL NULL) for nil polygon, or marshalled JSON bytes
func jsonbArg(polygon *[]PolygonPoint) interface{} {
	if polygon == nil {
		return nil
	}
	data, err := json.Marshal(polygon)
	if err != nil {
		return nil
	}
	return data
}

// GetGeofences returns all stored geofences from PostgreSQL
func GetGeofences(c *gin.Context) {
	rows, err := db.Query(`
		SELECT id, name, site_id, type, lat, lng, radius_m, polygon, color, created_at, updated_at,
		       COALESCE(code, ''), COALESCE(category, ''), COALESCE(sub_category, ''),
		       COALESCE(job_type, ''), COALESCE(frequency, ''), COALESCE(address, ''),
		       COALESCE(planned_start_time, ''), COALESCE(planned_end_time, ''),
		       COALESCE(is_accommodation, FALSE)
		FROM geofences
		ORDER BY created_at ASC
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	geofences := []Geofence{}
	for rows.Next() {
		var g Geofence
		var polygonJSON sql.NullString
		var siteID sql.NullString
		err := rows.Scan(
			&g.ID, &g.Name, &siteID, &g.Type,
			&g.Lat, &g.Lng, &g.RadiusM, &polygonJSON,
			&g.Color, &g.CreatedAt, &g.UpdatedAt,
			&g.Code, &g.Category, &g.SubCategory,
			&g.JobType, &g.Frequency, &g.Address,
			&g.PlannedStartTime, &g.PlannedEndTime,
			&g.IsAccommodation,
		)
		if err != nil {
			continue
		}
		if siteID.Valid {
			g.SiteID = &siteID.String
		}
		if polygonJSON.Valid && polygonJSON.String != "" {
			var pts []PolygonPoint
			if err := json.Unmarshal([]byte(polygonJSON.String), &pts); err == nil {
				g.Polygon = &pts
			}
		}
		geofences = append(geofences, g)
	}

	c.JSON(http.StatusOK, geofences)
}

// CreateGeofence creates a new geofence and stores it in PostgreSQL
func CreateGeofence(c *gin.Context) {
	var body Geofence
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if body.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name is required"})
		return
	}
	if body.Type != "circle" && body.Type != "polygon" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "type must be 'circle' or 'polygon'"})
		return
	}
	if body.Type == "circle" && (body.Lat == nil || body.Lng == nil || body.RadiusM == nil) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "circle geofence requires lat, lng, and radiusM"})
		return
	}
	if body.Color == "" {
		body.Color = "#00BFA5"
	}

	var id string
	err := db.QueryRow(`
		INSERT INTO geofences (name, site_id, type, lat, lng, radius_m, polygon, color,
		                       code, category, sub_category, job_type, frequency,
		                       address, planned_start_time, planned_end_time, is_accommodation)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
		RETURNING id`,
		body.Name, body.SiteID, body.Type,
		body.Lat, body.Lng, body.RadiusM,
		jsonbArg(body.Polygon), body.Color,
		body.Code, body.Category, body.SubCategory,
		body.JobType, body.Frequency,
		body.Address, body.PlannedStartTime, body.PlannedEndTime,
		body.IsAccommodation,
	).Scan(&id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	body.ID = id
	body.CreatedAt = time.Now()
	body.UpdatedAt = time.Now()
	c.JSON(http.StatusCreated, body)
}

// UpdateGeofence edits an existing geofence by ID
func UpdateGeofence(c *gin.Context) {
	id := c.Param("id")
	var body Geofence
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := db.Exec(`
		UPDATE geofences
		SET name = $1, site_id = $2, type = $3, lat = $4, lng = $5,
		    radius_m = $6, polygon = $7, color = $8, updated_at = NOW(),
		    code = $9, category = $10, sub_category = $11, job_type = $12,
		    frequency = $13, address = $14, planned_start_time = $15,
		    planned_end_time = $16, is_accommodation = $17
		WHERE id = $18`,
		body.Name, body.SiteID, body.Type,
		body.Lat, body.Lng, body.RadiusM,
		jsonbArg(body.Polygon), body.Color,
		body.Code, body.Category, body.SubCategory,
		body.JobType, body.Frequency,
		body.Address, body.PlannedStartTime, body.PlannedEndTime,
		body.IsAccommodation, id,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "geofence not found"})
		return
	}

	body.ID = id
	body.UpdatedAt = time.Now()
	c.JSON(http.StatusOK, body)
}

// DeleteGeofence removes a geofence by ID
func DeleteGeofence(c *gin.Context) {
	id := c.Param("id")

	result, err := db.Exec(`DELETE FROM geofences WHERE id = $1`, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "geofence not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Geofence deleted", "id": id})
}
