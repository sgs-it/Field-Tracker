import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'map_service.dart';
import 'geofence_model.dart';
import 'worker_location.dart';
import 'tracker_state.dart';
import 'models.dart';

enum MapStyle { dark, light, satellite }

/// Converts a hex color string like '#00BFA5' to a Flutter Color
Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

/// Helper to extract worker name initials (e.g. "John Doe" -> "JD")
String getInitials(String name) {
  if (name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
  return parts[0][0].toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE MAP VIEW
// Full Wialon-style real-time map panel used in Tab 0 of the dashboard
// ─────────────────────────────────────────────────────────────────────────────

class LiveMapView extends StatefulWidget {
  const LiveMapView({super.key});

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> {
  final MapController _mapController = MapController();

  // UI state
  String? _selectedWorkerId;
  bool _showGeofences = true;
  bool _showTrails = true;
  bool _isDrawingGeofence = false;
  bool _hasCenteredOnPcLocation = false;
  MapStyle _mapStyle = MapStyle.satellite;
  double _currentZoom = 12.0; // tracks live zoom for adaptive geofence rendering

  // Geofence drawing
  LatLng? _drawingCenter;
  double _drawingRadius = 100.0; // meters
  final TextEditingController _geofenceNameCtrl = TextEditingController();
  String _drawingColor = '#00BFA5';

  // Polygon and Manual inputs
  GeofenceShape _drawingType = GeofenceShape.circle;
  final List<LatLng> _drawingPolygonPoints = [];
  bool _isManualInput = false;
  final TextEditingController _manualLatCtrl = TextEditingController();
  final TextEditingController _manualLngCtrl = TextEditingController();
  final TextEditingController _manualRadiusCtrl = TextEditingController();

  // Colors for worker trails (cycling palette)
  static const List<Color> _trailColors = [
    Color(0xFF00BFA5),
    Color(0xFFFF6D00),
    Color(0xFF7C4DFF),
    Color(0xFFFF4081),
    Color(0xFF00B0FF),
  ];

  @override
  void dispose() {
    _geofenceNameCtrl.dispose();
    _manualLatCtrl.dispose();
    _manualLngCtrl.dispose();
    _manualRadiusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapSvc = context.watch<MapService>();
    final trackerState = context.watch<TrackerState>();

    // Center on user PC location once it is loaded
    if (trackerState.hasRealLocation && !_hasCenteredOnPcLocation) {
      _hasCenteredOnPcLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(trackerState.currentLat, trackerState.currentLng),
          12,
        );
      });
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left: Map ────────────────────────────────────────────────────────
        Expanded(
          flex: 3,
          child: _buildMap(mapSvc, trackerState),
        ),

        const SizedBox(width: 16),

        // ── Right: Worker Sidebar ────────────────────────────────────────────
        SizedBox(
          width: 260,
          child: _buildWorkerSidebar(mapSvc, trackerState),
        ),
      ],
    );
  }

  // ── Map Widget ──────────────────────────────────────────────────────────────

  Widget _buildMap(MapService mapSvc, TrackerState trackerState) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D38)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // ── FlutterMap ────────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(trackerState.currentLat, trackerState.currentLng),
                initialZoom: 12,
                maxZoom: 22, // Allows satellite tiles to reach full native resolution
                onTap: _isDrawingGeofence ? _onMapTap : null,
                onMapEvent: (event) {
                  // Track zoom so geofence rendering adapts (icon vs full shape)
                  if (event is MapEventMove || event is MapEventScrollWheelZoom ||
                      event is MapEventDoubleTapZoom || event is MapEventFlingAnimation) {
                    final newZoom = _mapController.camera.zoom;
                    if ((newZoom - _currentZoom).abs() > 0.1) {
                      setState(() => _currentZoom = newZoom);
                    }
                  }
                },
              ),
              children: [
                // 1. Base tile layer based on selected style
                if (_mapStyle == MapStyle.dark)
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.sgs.field_tracker',
                    maxNativeZoom: 19,
                    maxZoom: 22,
                    keepBuffer: 4,
                    tileSize: 256,
                  )
                else if (_mapStyle == MapStyle.light)
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.sgs.field_tracker',
                    maxNativeZoom: 19,
                    maxZoom: 22,
                    keepBuffer: 4,
                    tileSize: 256,
                  )
                else if (_mapStyle == MapStyle.satellite)
                  // Google Satellite: globally available, CORS-friendly, crisp up to zoom 21
                  TileLayer(
                    urlTemplate:
                        'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.sgs.field_tracker',
                    maxNativeZoom: 21,
                    maxZoom: 22,
                    keepBuffer: 4,
                    tileSize: 256,
                  ),

                // 2. Stored geofences from PostgreSQL
                if (_showGeofences) _buildGeofenceLayer(mapSvc),

                // 3. Drawing preview (while user is placing a new geofence)
                if (_isDrawingGeofence && _drawingCenter != null)
                  _buildDrawingPreviewLayer(),

                // 4. Worker breadcrumb trails
                if (_showTrails) _buildTrailLayer(mapSvc, trackerState),

                // 5. Live worker pins
                _buildWorkerMarkerLayer(mapSvc, trackerState),
              ],
            ),

            // ── Top bar: Map controls ─────────────────────────────────────────
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _buildMapControls(mapSvc, trackerState),
            ),

            // ── Bottom bar: Connection status ─────────────────────────────────
            Positioned(
              bottom: 12,
              left: 12,
              child: _buildConnectionBadge(mapSvc),
            ),

            // ── Drawing instructions overlay ──────────────────────────────────
            if (_isDrawingGeofence)
              Positioned(
                bottom: 12,
                right: 12,
                child: _buildDrawingPanel(mapSvc),
              ),
          ],
        ),
      ),
    );
  }

  // ── Geofence Layer ──────────────────────────────────────────────────────────
  // Zoom < 12  → compact icon pin per geofence (doesn't clutter zoomed-out view)
  // Zoom >= 12 → full circle / polygon shape as normal

  static const double _geofenceIconZoomThreshold = 12.0;

  Widget _buildGeofenceLayer(MapService mapSvc) {
    final geofences = mapSvc.geofences;
    if (geofences.isEmpty) return const SizedBox.shrink();

    // 1. Build shapes (only when zoomed in enough)
    final circles = <CircleMarker>[];
    final polygons = <Polygon>[];

    if (_currentZoom >= _geofenceIconZoomThreshold) {
      for (final g in geofences) {
        final color = hexToColor(g.color);
        if (g.type == GeofenceShape.circle && g.center != null && g.radiusM != null) {
          circles.add(CircleMarker(
            point: g.center!,
            radius: g.radiusM!,
            useRadiusInMeter: true,
            color: color.withOpacity(0.08),
            borderColor: color.withOpacity(0.7),
            borderStrokeWidth: 2,
          ));
        } else if (g.type == GeofenceShape.polygon && g.polygon != null) {
          polygons.add(Polygon(
            points: g.polygon!,
            color: color.withOpacity(0.08),
            borderColor: color.withOpacity(0.7),
            borderStrokeWidth: 2,
          ));
        }
      }
    }

    // 2. Build icon pin markers (always visible!)
    final markers = geofences.map((g) {
      // Determine center point
      LatLng? center;
      if (g.type == GeofenceShape.circle && g.center != null) {
        center = g.center;
      } else if (g.type == GeofenceShape.polygon && g.polygon != null && g.polygon!.isNotEmpty) {
        // Compute centroid of polygon
        final pts = g.polygon!;
        center = LatLng(
          pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length,
          pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length,
        );
      }
      if (center == null) return null;

      final color = hexToColor(g.color);
      final isCircle = g.type == GeofenceShape.circle;
      final shortName = g.name.length > 14 ? '${g.name.substring(0, 12)}…' : g.name;

      return Marker(
        point: center,
        width: 68,
        height: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isCircle ? Icons.location_on : Icons.pentagon,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(height: 3),
            // Name label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.72),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                shortName,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }).whereType<Marker>().toList();

    return Stack(children: [
      if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
      if (circles.isNotEmpty) CircleLayer(circles: circles),
      if (markers.isNotEmpty) MarkerLayer(markers: markers),
    ]);
  }

  // ── Drawing Preview Layer ───────────────────────────────────────────────────

  Widget _buildDrawingPreviewLayer() {
    if (_drawingType == GeofenceShape.circle) {
      if (_drawingCenter == null) return const SizedBox.shrink();
      return CircleLayer(circles: [
        CircleMarker(
          point: _drawingCenter!,
          radius: _drawingRadius,
          useRadiusInMeter: true,
          color: hexToColor(_drawingColor).withOpacity(0.15),
          borderColor: hexToColor(_drawingColor),
          borderStrokeWidth: 2.5,
        ),
      ]);
    } else {
      if (_drawingPolygonPoints.isEmpty) return const SizedBox.shrink();
      final color = hexToColor(_drawingColor);

      final closedPoints = List<LatLng>.from(_drawingPolygonPoints);
      if (_drawingPolygonPoints.length >= 3) {
        closedPoints.add(_drawingPolygonPoints.first);
      }

      return Stack(
        children: [
          if (_drawingPolygonPoints.length >= 3)
            PolygonLayer(polygons: [
              Polygon(
                points: _drawingPolygonPoints,
                color: color.withOpacity(0.15),
                borderColor: color,
                borderStrokeWidth: 2.5,
              )
            ]),
          PolylineLayer(polylines: [
            Polyline(
              points: closedPoints,
              color: color,
              strokeWidth: 2.5,
            )
          ]),
          MarkerLayer(
            markers: _drawingPolygonPoints.asMap().entries.map((e) {
              final idx = e.key;
              final pt = e.value;
              return Marker(
                point: pt,
                width: 24,
                height: 24,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '${idx + 1}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }
  }

  // ── Trail Layer ─────────────────────────────────────────────────────────────

  Widget _buildTrailLayer(MapService mapSvc, TrackerState trackerState) {
    final polylines = <Polyline>[];
    int colorIdx = 0;

    for (final entry in mapSvc.workerLocations.entries) {
      final trail = entry.value.todayTrail;
      if (trail.length >= 2) {
        polylines.add(Polyline(
          points: trail,
          color: _trailColors[colorIdx % _trailColors.length].withOpacity(0.7),
          strokeWidth: 3,

        ));
      }
      colorIdx++;
    }

    return PolylineLayer(polylines: polylines);
  }

  // ── Worker Marker Layer ─────────────────────────────────────────────────────

  Widget _buildWorkerMarkerLayer(MapService mapSvc, TrackerState trackerState) {
    final markers = <Marker>[];

    // First add markers from live MapService locations
    for (final entry in mapSvc.workerLocations.entries) {
      final loc = entry.value;
      final isSelected = _selectedWorkerId == loc.workerId;
      markers.add(Marker(
        point: LatLng(loc.lat, loc.lng),
        width: isSelected ? 90 : 70,
        height: isSelected ? 90 : 70,
        child: GestureDetector(
          onTap: () => _onWorkerPinTap(loc, trackerState),
          child: _buildWorkerPin(loc, isSelected, trackerState),
        ),
      ));
    }

    // Fallback: show static pins for workers with no live location
    for (final worker in trackerState.workers) {
      if (!mapSvc.workerLocations.containsKey(worker.id)) {
        final hb = trackerState.heartbeatLogs
            .lastWhere((h) => h.workerId == worker.id,
                orElse: () => HeartbeatLog(
                      id: '',
                      workerId: worker.id,
                      timestamp: DateTime.now(),
                      latitude: 25.2048 + (trackerState.workers.indexOf(worker) * 0.005),
                      longitude: 55.2708,
                    ));
        markers.add(Marker(
          point: LatLng(hb.latitude, hb.longitude),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _onStaticWorkerTap(worker),
            child: _buildOfflinePin(worker),
          ),
        ));
      }
    }

    // Add My PC Location marker (blue pulsing dot)
    if (trackerState.hasRealLocation) {
      markers.add(Marker(
        point: LatLng(trackerState.currentLat, trackerState.currentLng),
        width: 32,
        height: 32,
        child: Tooltip(
          message: 'My PC Location',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent.withOpacity(0.2),
            ),
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
          ),
        ),
      ));
    }

    return MarkerLayer(markers: markers);
  }

  Widget _buildWorkerPin(WorkerLocation loc, bool isSelected, TrackerState trackerState) {
    final isOnline = loc.isOnline && loc.isRecent;
    final color = isOnline
        ? (loc.isOnShift ? const Color(0xFF00BFA5) : const Color(0xFFFFD600))
        : const Color(0xFFF44336);

    final initials = getInitials(loc.workerName);
    
    // Look up worker to get Employee ID and Phone
    final worker = trackerState.workers.firstWhere(
      (w) => w.id == loc.workerId,
      orElse: () => Worker(
        id: loc.workerId,
        employeeId: 'N/A',
        name: loc.workerName,
        phone: 'N/A',
        staffType: StaffType.IP,
        staffCategory: StaffCategory.Direct,
        leaveCategory: LeaveCategory.Year1,
        department: 'N/A',
        designation: 'N/A',
        username: '',
        password: '',
        staffHierarchy: '',
        isActive: true,
        emiratesId: '',
        emiratesIdExpiry: DateTime.now(),
        passportNo: '',
        passportExpiry: DateTime.now(),
        labourCardNo: '',
        labourCardExpiry: DateTime.now(),
        joinedDate: DateTime.now(),
        leaveDueDate: DateTime.now(),
      ),
    );

    final statusStr = isOnline
        ? (loc.isOnShift ? "On Shift (Present)" : "Pending check-in")
        : "Offline/Absent";

    final tooltipMsg = 'Name: ${worker.name}\n'
        'Employee ID: ${worker.employeeId}\n'
        'Phone: ${worker.phone}\n'
        'Status: $statusStr';

    return Tooltip(
      message: tooltipMsg,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.all(10),
      preferBelow: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isSelected ? 48 : 38,
            height: isSelected ? 48 : 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E26),
              border: Border.all(
                color: color,
                width: isSelected ? 3.5 : 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 3 : 1,
                )
              ],
            ),
            child: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSelected ? 13 : 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.5), width: 0.5),
            ),
            child: Text(
              loc.workerName.split(' ').first,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflinePin(Worker worker) {
    final initials = getInitials(worker.name);
    const color = Color(0xFFF44336); // Red for absent / offline/ static fallback
    final tooltipMsg = 'Name: ${worker.name}\n'
        'Employee ID: ${worker.employeeId}\n'
        'Phone: ${worker.phone}\n'
        'Status: Offline/Absent';

    return Tooltip(
      message: tooltipMsg,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.all(10),
      preferBelow: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E26),
              border: Border.all(
                color: color,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ],
            ),
            child: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.5), width: 0.5),
            ),
            child: Text(
              worker.name.split(' ').first,
              style: const TextStyle(color: Colors.grey, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  // ── Map Controls ────────────────────────────────────────────────────────────

  Widget _buildMapControls(MapService mapSvc, TrackerState trackerState) {
    return Row(
      children: [
        // Title badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.satellite_alt, color: Color(0xFF00BFA5), size: 13),
              SizedBox(width: 5),
              Text('Live Field Map', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // All right-side controls in a flexible scrollable row to prevent overflow
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle: Geofences
                _mapToggleBtn(
                  icon: Icons.radio_button_unchecked,
                  label: 'Fences',
                  active: _showGeofences,
                  onTap: () => setState(() => _showGeofences = !_showGeofences),
                ),
                const SizedBox(width: 5),
                // Toggle: Trails
                _mapToggleBtn(
                  icon: Icons.timeline,
                  label: 'Trails',
                  active: _showTrails,
                  onTap: () => setState(() => _showTrails = !_showTrails),
                ),

                const SizedBox(width: 5),
                // Fit all workers
                _mapIconBtn(
                  icon: Icons.fit_screen,
                  tooltip: 'Fit all workers',
                  onTap: () => _fitAllWorkers(mapSvc),
                ),
                const SizedBox(width: 5),
                // Center on my location
                _mapIconBtn(
                  icon: Icons.my_location,
                  tooltip: 'Center on my location',
                  onTap: () {
                    _mapController.move(
                      LatLng(trackerState.currentLat, trackerState.currentLng),
                      14,
                    );
                  },
                ),
                const SizedBox(width: 6),
                // Map Style Segmented Control
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2D2D38)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _styleSegmentBtn(MapStyle.dark, Icons.dark_mode, 'Dark'),
                      _styleSegmentBtn(MapStyle.light, Icons.light_mode, 'Light'),
                      _styleSegmentBtn(MapStyle.satellite, Icons.satellite, 'Sat'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _styleSegmentBtn(MapStyle style, IconData icon, String label) {
    final active = _mapStyle == style;
    return GestureDetector(
      onTap: () => setState(() => _mapStyle = style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00BFA5).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF00BFA5) : Colors.grey,
              size: 11,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF00BFA5) : Colors.grey,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapToggleBtn({
    required IconData icon,
    required String label,
    required bool active,
    Color activeColor = const Color(0xFF00BFA5),
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.15) : Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? activeColor : const Color(0xFF2D2D38)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? activeColor : Colors.grey, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: active ? activeColor : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _mapIconBtn({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2D2D38)),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ),
    );
  }

  Widget _buildConnectionBadge(MapService mapSvc) {
    final isOk = mapSvc.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOk ? const Color(0xFF00BFA5) : Colors.redAccent,
          width: 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOk ? const Color(0xFF00BFA5) : Colors.redAccent,
          ),
        ),
        const SizedBox(width: 6),
        Text(mapSvc.connectionStatus,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }

  // ── Geofence Drawing Panel ──────────────────────────────────────────────────

  Widget _buildDrawingPanel(MapService mapSvc) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
          )
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Draw Geofence', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDrawingGeofence = false;
                      _drawingCenter = null;
                      _drawingPolygonPoints.clear();
                    });
                  },
                  child: const Icon(Icons.close, color: Colors.grey, size: 14),
                )
              ],
            ),
            const SizedBox(height: 10),

            // Geofence Name
            TextField(
              controller: _geofenceNameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Geofence Name',
                labelStyle: TextStyle(color: Colors.grey, fontSize: 11),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D2D38))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00BFA5))),
              ),
            ),
            const SizedBox(height: 12),

            // Type Selector: Circle vs Polygon
            const Text('GEOFENCE TYPE', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Circle', style: TextStyle(fontSize: 10)),
                    selected: _drawingType == GeofenceShape.circle,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _drawingType = GeofenceShape.circle;
                          _drawingCenter = null;
                          _drawingPolygonPoints.clear();
                        });
                      }
                    },
                    selectedColor: const Color(0xFF00BFA5).withOpacity(0.2),
                    side: BorderSide(color: _drawingType == GeofenceShape.circle ? const Color(0xFF00BFA5) : const Color(0xFF2D2D38)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Polygon', style: TextStyle(fontSize: 10)),
                    selected: _drawingType == GeofenceShape.polygon,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _drawingType = GeofenceShape.polygon;
                          _drawingCenter = null;
                          _drawingPolygonPoints.clear();
                        });
                      }
                    },
                    selectedColor: const Color(0xFF00BFA5).withOpacity(0.2),
                    side: BorderSide(color: _drawingType == GeofenceShape.polygon ? const Color(0xFF00BFA5) : const Color(0xFF2D2D38)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mode Selector: Map Tap vs Manual Coord Entry
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('MANUAL COORDINATES', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                Switch(
                  value: _isManualInput,
                  activeColor: const Color(0xFF00BFA5),
                  onChanged: (val) {
                    setState(() {
                      _isManualInput = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Mode-specific options
            if (!_isManualInput) ...[
              // Map click mode
              if (_drawingType == GeofenceShape.circle) ...[
                Text(
                  _drawingCenter == null
                      ? '📍 Tap the map to set the center point.'
                      : '✅ Center: ${_drawingCenter!.latitude.toStringAsFixed(4)}, ${_drawingCenter!.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 10),
                Text('Radius: ${_drawingRadius.toInt()} m', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                Slider(
                  value: _drawingRadius,
                  min: 20,
                  max: 1000,
                  activeColor: Colors.orangeAccent,
                  inactiveColor: const Color(0xFF2D2D38),
                  onChanged: (v) => setState(() => _drawingRadius = v),
                ),
              ] else ...[
                Text(
                  '📍 Tap map vertices to draw polygon (${_drawingPolygonPoints.length} added)',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D2D38),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          textStyle: const TextStyle(fontSize: 10),
                        ),
                        onPressed: _drawingPolygonPoints.isEmpty
                            ? null
                            : () => setState(() => _drawingPolygonPoints.removeLast()),
                        child: const Text('Undo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D2D38),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          textStyle: const TextStyle(fontSize: 10),
                        ),
                        onPressed: _drawingPolygonPoints.isEmpty
                            ? null
                            : () => setState(() => _drawingPolygonPoints.clear()),
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Manual coordinate input mode
              if (_drawingType == GeofenceShape.circle) ...[
                _manualTextField(
                  controller: _manualLatCtrl,
                  label: 'Latitude',
                  hint: 'e.g. 25.2048',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                _manualTextField(
                  controller: _manualLngCtrl,
                  label: 'Longitude',
                  hint: 'e.g. 55.2708',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                _manualTextField(
                  controller: _manualRadiusCtrl,
                  label: 'Radius (meters)',
                  hint: 'e.g. 150',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ] else ...[
                _manualTextField(
                  controller: _manualLatCtrl, // reuse lat field as full poly coords string
                  label: 'Coordinates (Lat,Lng; Lat,Lng; ...)',
                  hint: '25.12,55.34; 25.13,55.35; 25.14,55.36',
                ),
              ],
            ],
            const SizedBox(height: 12),

            // Color picker
            Row(
              children: [
                const Text('Color: ', style: TextStyle(color: Colors.grey, fontSize: 10)),
                for (final c in ['#00BFA5', '#FF6D00', '#7C4DFF', '#FF4081', '#00B0FF'])
                  GestureDetector(
                    onTap: () => setState(() => _drawingColor = c),
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hexToColor(c),
                        border: _drawingColor == c
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Save Button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _saveDrawnGeofence(mapSvc),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Save Geofence'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 9),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          filled: true,
          fillColor: const Color(0xFF13131A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  // ── Worker Sidebar ──────────────────────────────────────────────────────────

  Widget _buildWorkerSidebar(MapService mapSvc, TrackerState trackerState) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D38)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2D2D38))),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: Color(0xFF00BFA5), size: 16),
                const SizedBox(width: 8),
                const Text('Workers', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.3)),
                  ),
                  child: Text(
                    '${mapSvc.workerLocations.values.where((w) => w.isOnline).length}/${trackerState.workers.length}',
                    style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Worker list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: trackerState.workers.length,
              itemBuilder: (context, i) {
                final worker = trackerState.workers[i];
                final liveLoc = mapSvc.workerLocations[worker.id];
                final isOnline = liveLoc != null && liveLoc.isOnline && liveLoc.isRecent;
                final isSelected = _selectedWorkerId == worker.id;

                return GestureDetector(
                  onTap: () => _focusWorker(worker.id, liveLoc),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00BFA5).withOpacity(0.08)
                          : const Color(0xFF13131A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00BFA5).withOpacity(0.4)
                            : const Color(0xFF2D2D38),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Online dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline
                                ? const Color(0xFF00BFA5)
                                : Colors.grey.shade600,
                            boxShadow: isOnline
                                ? [BoxShadow(color: const Color(0xFF00BFA5).withOpacity(0.6), blurRadius: 4)]
                                : [],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(worker.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                liveLoc != null
                                    ? 'Updated ${liveLoc.secondsSinceUpdate}s ago'
                                    : 'No signal',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                        if (liveLoc != null)
                          Icon(
                            liveLoc.isOnShift ? Icons.work : Icons.work_off,
                            color: liveLoc.isOnShift ? const Color(0xFF00BFA5) : Colors.grey,
                            size: 13,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Geofence management section
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF2D2D38))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Geofences', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (mapSvc.geofences.isEmpty)
                    const Text('No geofences yet.\nUse "Draw" on the map to create one.',
                        style: TextStyle(color: Colors.grey, fontSize: 9))
                  else
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: mapSvc.geofences.map((g) => _buildGeofenceRow(g, mapSvc)).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceRow(AppGeofence g, MapService mapSvc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hexToColor(g.color).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: hexToColor(g.color)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(g.name,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ),
          GestureDetector(
            onTap: () => _showEditGeofenceDialog(g, mapSvc),
            child: const Icon(Icons.edit, color: Colors.grey, size: 13),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _deleteGeofence(g.id, mapSvc),
            child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 13),
          ),
        ],
      ),
    );
  }

  // ── Interactions ────────────────────────────────────────────────────────────

  void _onMapTap(TapPosition tapPos, LatLng latlng) {
    if (_drawingType == GeofenceShape.circle) {
      setState(() {
        _drawingCenter = latlng;
        _manualLatCtrl.text = latlng.latitude.toStringAsFixed(6);
        _manualLngCtrl.text = latlng.longitude.toStringAsFixed(6);
      });
    } else {
      setState(() {
        _drawingPolygonPoints.add(latlng);
      });
    }
  }

  void _onWorkerPinTap(WorkerLocation loc, TrackerState trackerState) {
    setState(() => _selectedWorkerId = loc.workerId);
    _mapController.move(LatLng(loc.lat, loc.lng), 15);
    _showWorkerPopup(loc, trackerState);
  }

  void _onStaticWorkerTap(Worker worker) {
    setState(() => _selectedWorkerId = worker.id);
  }

  void _focusWorker(String workerId, WorkerLocation? loc) {
    setState(() => _selectedWorkerId = workerId);
    if (loc != null) {
      _mapController.move(LatLng(loc.lat, loc.lng), 15);
    }
  }

  void _fitAllWorkers(MapService mapSvc) {
    if (mapSvc.workerLocations.isEmpty) return;
    final points = mapSvc.workerLocations.values
        .map((l) => LatLng(l.lat, l.lng))
        .toList();
    if (points.length == 1) {
      _mapController.move(points.first, 14);
      return;
    }
    final minLat = points.map((p) => p.latitude).reduce(min);
    final maxLat = points.map((p) => p.latitude).reduce(max);
    final minLng = points.map((p) => p.longitude).reduce(min);
    final maxLng = points.map((p) => p.longitude).reduce(max);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  Future<void> _saveDrawnGeofence(MapService mapSvc) async {
    final name = _geofenceNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a geofence name'), backgroundColor: Colors.red),
      );
      return;
    }

    AppGeofence newFence;
    if (_drawingType == GeofenceShape.circle) {
      LatLng? centerPoint = _drawingCenter;
      double radiusVal = _drawingRadius;

      if (_isManualInput) {
        final double? mLat = double.tryParse(_manualLatCtrl.text);
        final double? mLng = double.tryParse(_manualLngCtrl.text);
        final double? mRad = double.tryParse(_manualRadiusCtrl.text);

        if (mLat == null || mLng == null || mRad == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid manual coordinate inputs'), backgroundColor: Colors.red),
          );
          return;
        }
        centerPoint = LatLng(mLat, mLng);
        radiusVal = mRad;
      }

      if (centerPoint == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please tap map to place center or enter coordinates'), backgroundColor: Colors.red),
        );
        return;
      }

      newFence = AppGeofence(
        id: '',
        name: name,
        type: GeofenceShape.circle,
        center: centerPoint,
        radiusM: radiusVal,
        color: _drawingColor,
      );
    } else {
      List<LatLng> points = List.from(_drawingPolygonPoints);
      if (_isManualInput) {
        final List<LatLng> manualPoints = [];
        final text = _manualLatCtrl.text.trim(); // Polygon vertices string
        if (text.isNotEmpty) {
          final parts = text.split(';');
          for (final part in parts) {
            final sub = part.split(',');
            if (sub.length == 2) {
              final double? lat = double.tryParse(sub[0].trim());
              final double? lng = double.tryParse(sub[1].trim());
              if (lat != null && lng != null) {
                manualPoints.add(LatLng(lat, lng));
              }
            }
          }
        }
        if (manualPoints.isNotEmpty) {
          points = manualPoints;
        }
      }

      if (points.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A polygon geofence requires at least 3 vertices'), backgroundColor: Colors.red),
        );
        return;
      }

      newFence = AppGeofence(
        id: '',
        name: name,
        type: GeofenceShape.polygon,
        polygon: points,
        color: _drawingColor,
      );
    }

    final created = await mapSvc.createGeofence(newFence);
    if (created != null && mounted) {
      setState(() {
        _isDrawingGeofence = false;
        _drawingCenter = null;
        _drawingPolygonPoints.clear();
        _geofenceNameCtrl.clear();
        _manualLatCtrl.clear();
        _manualLngCtrl.clear();
        _manualRadiusCtrl.clear();
        _drawingRadius = 100;
        _isManualInput = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geofence "${created.name}" saved ✅'), backgroundColor: const Color(0xFF00BFA5)),
      );
    }
  }

  Future<void> _deleteGeofence(String id, MapService mapSvc) async {
    final ok = await mapSvc.deleteGeofence(id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geofence deleted'), backgroundColor: Colors.red),
      );
    }
  }

  void _showWorkerPopup(WorkerLocation loc, TrackerState trackerState) {
    final worker = trackerState.workers.firstWhere(
      (w) => w.id == loc.workerId,
      orElse: () => trackerState.workers.first,
    );
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person, color: Color(0xFF00BFA5), size: 20),
            const SizedBox(width: 8),
            Text(loc.workerName, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _popupRow(Icons.badge, 'Employee ID', worker.employeeId),
            _popupRow(Icons.work, 'Designation', worker.designation),
            _popupRow(Icons.business, 'Department', worker.department),
            _popupRow(Icons.location_on, 'Coordinates',
                '${loc.lat.toStringAsFixed(5)}, ${loc.lng.toStringAsFixed(5)}'),
            _popupRow(Icons.gps_fixed, 'Accuracy', '±${loc.accuracy.toStringAsFixed(1)} m'),
            _popupRow(Icons.access_time, 'Last Update',
                DateFormat('hh:mm:ss a').format(loc.timestamp.toLocal())),
            _popupRow(
              loc.isOnShift ? Icons.check_circle : Icons.circle_outlined,
              'Shift Status',
              loc.isOnShift ? 'On Shift' : 'Off Shift',
            ),
            _popupRow(
              loc.isOnline ? Icons.wifi : Icons.wifi_off,
              'Connection',
              loc.isOnline ? 'Online' : 'Offline',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _popupRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 14),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _showEditGeofenceDialog(AppGeofence g, MapService mapSvc) {
    final nameCtrl = TextEditingController(text: g.name);
    double radius = g.radiusM ?? 100;
    String color = g.color;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Geofence', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D2D38))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00BFA5))),
                ),
              ),
              if (g.type == GeofenceShape.circle) ...[
                const SizedBox(height: 14),
                Text('Radius: ${radius.toInt()} m',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Slider(
                  value: radius,
                  min: 20,
                  max: 1000,
                  activeColor: const Color(0xFF00BFA5),
                  inactiveColor: const Color(0xFF2D2D38),
                  onChanged: (v) => setS(() => radius = v),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Color: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  for (final c in ['#00BFA5', '#FF6D00', '#7C4DFF', '#FF4081', '#00B0FF'])
                    GestureDetector(
                      onTap: () => setS(() => color = c),
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hexToColor(c),
                          border: color == c ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.black),
              onPressed: () async {
                final updated = g.copyWith(
                  name: nameCtrl.text.trim(),
                  radiusM: radius,
                  color: color,
                );
                await mapSvc.updateGeofence(updated);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
