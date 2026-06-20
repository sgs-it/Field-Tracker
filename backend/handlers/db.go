package handlers

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"
)

var db *sql.DB

// InitDB connects to PostgreSQL using DATABASE_URL env var or default local config
func InitDB() error {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		host := getEnv("DB_HOST", "localhost")
		port := getEnv("DB_PORT", "5432")
		user := getEnv("DB_USER", "postgres")
		password := getEnv("DB_PASSWORD", "postgres")
		dbname := getEnv("DB_NAME", "field_tracker")
		dsn = fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
			host, port, user, password, dbname)
	}

	var err error
	db, err = sql.Open("postgres", dsn)
	if err != nil {
		return fmt.Errorf("failed to open DB: %w", err)
	}

	if err = db.Ping(); err != nil {
		return fmt.Errorf("failed to ping DB: %w", err)
	}

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)

	log.Println("✅ Connected to PostgreSQL")
	return nil
}

// RunMigrations creates all tables if they do not already exist
func RunMigrations() error {
	migrations := []string{
		`CREATE TABLE IF NOT EXISTS geofences (
			id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			name        VARCHAR(255) NOT NULL,
			site_id     VARCHAR(100),
			type        VARCHAR(20) NOT NULL CHECK (type IN ('circle', 'polygon')),
			lat         DOUBLE PRECISION,
			lng         DOUBLE PRECISION,
			radius_m    DOUBLE PRECISION,
			polygon     JSONB,
			color       VARCHAR(20) DEFAULT '#00BFA5',
			created_at  TIMESTAMPTZ DEFAULT NOW(),
			updated_at  TIMESTAMPTZ DEFAULT NOW()
		)`,

		`CREATE TABLE IF NOT EXISTS gps_trail (
			id           BIGSERIAL PRIMARY KEY,
			worker_id    VARCHAR(100) NOT NULL,
			worker_name  VARCHAR(255),
			lat          DOUBLE PRECISION NOT NULL,
			lng          DOUBLE PRECISION NOT NULL,
			accuracy     DOUBLE PRECISION,
			is_on_shift  BOOLEAN DEFAULT TRUE,
			recorded_at  TIMESTAMPTZ DEFAULT NOW()
		)`,

		`CREATE INDEX IF NOT EXISTS idx_gps_trail_worker_day
		 ON gps_trail(worker_id, recorded_at)`,

		// Alter table columns if they do not exist
		`ALTER TABLE geofences ADD COLUMN IF NOT EXISTS code VARCHAR(50)`,
		`ALTER TABLE geofences ADD COLUMN IF NOT EXISTS category VARCHAR(50)`,
		`ALTER TABLE geofences ADD COLUMN IF NOT EXISTS sub_category VARCHAR(50)`,
		`ALTER TABLE geofences ADD COLUMN IF NOT EXISTS job_type VARCHAR(50)`,
		`ALTER TABLE geofences ADD COLUMN IF NOT EXISTS frequency VARCHAR(50)`,
		`ALTER TABLE geofences ADD COLUMN IF NOT EXISTS address TEXT`,
		`ALTER TABLE geofences ADD COLUMN IF NOT EXISTS planned_start_time VARCHAR(50)`,
		`ALTER TABLE geofences ADD COLUMN IF NOT EXISTS planned_end_time VARCHAR(50)`,
		`ALTER TABLE geofences ADD COLUMN IF NOT EXISTS is_accommodation BOOLEAN DEFAULT FALSE`,
	}

	for _, m := range migrations {
		if _, err := db.Exec(m); err != nil {
			return fmt.Errorf("migration error: %w\nSQL: %s", err, m)
		}
	}

	// Automatic geofence seeding disabled

	log.Println("✅ Database migrations complete")
	return nil
}

// CloseDB closes the database connection pool
func CloseDB() {
	if db != nil {
		db.Close()
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
