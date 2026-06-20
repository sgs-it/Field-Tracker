# SGS Field Tracker System

A real-time field tracking and site management system featuring an administrative web dashboard, interactive map geofences (circular and polygonal), simulated offline sync buffers, and worker location sync over WebSockets.

---

## Technical Architecture

- **Web Dashboard & Mobile Frame**: Flutter Web / Dart
- **State Management**: Provider
- **Backend API Server**: Go (Gin Gonic Framework, WebSockets)
- **Database**: PostgreSQL (with direct automated migrations and seeding)

---

## Prerequisites

Before running the application, make sure you have installed:
1. **Flutter SDK** (v3.22+ or latest stable)
2. **Go** (v1.20+)
3. **PostgreSQL Database** running locally

---

## Step-by-Step Setup Guide

### Step 1: PostgreSQL Database Configuration

1. Create a database named `field_tracker` in PostgreSQL:
   ```sql
   CREATE DATABASE field_tracker;
   ```
2. Navigate to the `backend/` directory.
3. Locate or create the `.env` file and set your PostgreSQL credentials:
   ```env
   DB_HOST=localhost
   DB_PORT=5432
   DB_USER=postgres
   DB_PASSWORD=your_postgres_password
   DB_NAME=field_tracker
   PORT=8080
   ```

### Step 2: Running the Go Backend Server

1. Open a terminal and navigate to the backend folder:
   ```bash
   cd backend
   ```
2. Run the server:
   ```bash
   go run main.go
   ```
   *Note: On first startup, the backend automatically runs migrations to create table schemas (`geofences`, `gps_trail`) and seeds the database with the 6 initial default sites.*

### Step 3: Launching the Flutter Web Application

1. Open a new terminal window and navigate to the Flutter project folder:
   ```bash
   cd sgs_field_tracker
   ```
2. Fetch package dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application in Chrome:
   ```bash
   flutter run -d chrome
   ```

---

## Key Features & How to Test

### 1. Persistent Worksite CRUD Operations
- **Add New Site**: Go to the **Site Management** tab in the dashboard, click **Add New Site**, select a circle/polygon shape, mark it on the interactive map, and save. It immediately updates PostgreSQL.
- **Edit Site**: Click the **Edit** (teal pencil) icon next to a site. The dialog will load all existing metadata, and let you modify its address, categories, or redraw the geofence on the map.
- **Delete Site**: Click the **Delete** (red trash) icon next to a site. The site and geofence will be deleted from the database and disappear from all maps.
- **Persistent Reload**: Close the browser tab and reload. All user-created geofences will remain visible and load directly from PostgreSQL.

### 2. Live Map
- **Always-on Icons**: Pins marking the center of geofenced areas remain visible at all zoom levels to assist navigation. Full boundary circles and polygons automatically render when zoomed in ($\ge$ 12.0 zoom level).
- **Map Styles**: Switch between **Dark Mode**, **Light Mode**, and **Google Satellite** styles.
- **Draw geofence**: Interactively click on the map to draw boundaries.
