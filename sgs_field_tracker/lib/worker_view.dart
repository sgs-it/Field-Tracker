import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'tracker_state.dart';
import 'map_service.dart';
import 'geofence_model.dart';
import 'models.dart';

class WorkerView extends StatefulWidget {
  const WorkerView({super.key});

  @override
  State<WorkerView> createState() => _WorkerViewState();
}

class _WorkerViewState extends State<WorkerView> {
  int _currentIndex = 0;
  final MapController _mapController = MapController();
  bool _hasCenteredOnWorkerLocation = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TrackerState>(context);
    final worker = state.currentWorker;
    final att = state.allAttendanceRecords.firstWhere(
      (r) => r.workerId == worker.id && state.isSameDay(r.date, state.selectedDate),
      orElse: () => state.allAttendanceRecords.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF13131A),
      body: Stack(
        children: [
          // Main Content
          Column(
            children: [
              _buildHeader(context, state, worker, att),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildAssignmentsTab(context, state, att),
                    _buildMapTab(context, state),
                    _buildDiagnosticsTab(context, state),
                  ],
                ),
              ),
            ],
          ),

          // Geofence Notification Banner Overlay
          _buildGeofenceNotificationOverlay(context, state),

          // Morning Alarm Overlay (Full-screen alarm)
          if (state.morningAlarmTriggered)
            _buildMorningAlarmOverlay(context, state),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF1E1E26),
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Assigned Sites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Map View',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: 'Diagnostics',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TrackerState state, Worker worker, AttendanceRecord att) {
    String shiftTimeText = "Shift Not Started";
    if (att.shiftStart != null && att.shiftEnd == null) {
      final diff = state.simulatedTime.difference(att.shiftStart!);
      final hrs = diff.inHours.toString().padLeft(2, '0');
      final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
      shiftTimeText = "Active: $hrs:$mins";
    } else if (att.shiftEnd != null) {
      shiftTimeText = "Completed: ${att.normalHours + att.overtimeHours} hrs";
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E26),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${worker.designation} • ${worker.employeeId}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              // Device status indicators
              Row(
                children: [
                  Icon(
                    state.isInternetEnabled ? Icons.wifi : Icons.wifi_off,
                    color: state.isInternetEnabled ? Colors.greenAccent : Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    state.isGpsEnabled ? Icons.location_on : Icons.location_off,
                    color: state.isGpsEnabled ? Colors.greenAccent : Colors.redAccent,
                    size: 16,
                  ),
                  if (state.isFakeGpsEnabled) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 16),
                  ]
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Shift Toggle Button & Status Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF252530),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shiftTimeText,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      att.shiftStart != null
                          ? 'Start: ${DateFormat('hh:mm a').format(att.shiftStart!)}'
                          : 'Shift Time Limit: 8h',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                _buildShiftButton(context, state, att),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildShiftButton(BuildContext context, TrackerState state, AttendanceRecord att) {
    if (att.shiftStart == null) {
      return ElevatedButton(
        onPressed: () => state.startShift(state.currentWorker.id),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('START WORK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else if (att.shiftEnd == null) {
      return ElevatedButton(
        onPressed: () => state.endShift(state.currentWorker.id),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('END WORK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'COMPLETED',
          style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    }
  }

  Widget _buildAssignmentsTab(BuildContext context, TrackerState state, AttendanceRecord att) {
    // Separate accommodation and regular sites
    var workerAssigns = state.assignments.where((a) => a.workerId == state.currentWorker.id).toList();

    if (workerAssigns.isEmpty) {
      return const Center(
        child: Text(
          'No sites assigned for today.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workerAssigns.length,
      itemBuilder: (context, index) {
        var assign = workerAssigns[index];
        var site = state.sites.firstWhere((s) => s.id == assign.siteId, orElse: () => state.sites.first);
        var visit = att.visits.firstWhere(
          (v) => v.siteId == site.id,
          orElse: () => VisitRecord(siteId: site.id, checklistAtVisit: []),
        );

        Color statusColor = Colors.grey;
        if (visit.status == 'Completed') {
          statusColor = Colors.greenAccent;
        } else if (visit.status == 'Entry Recorded') {
          statusColor = Colors.orangeAccent;
        }

        return Card(
          color: const Color(0xFF1E1E26),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: InkWell(
            onTap: () => _showSiteDetailsSheet(context, state, assign, site, visit),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          site.name,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          visit.status == 'Entry Recorded' ? 'On Site' : visit.status,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Code: ${site.code} • ${site.jobType.name}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const Divider(color: Color(0xFF2D2D38), height: 20),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.grey, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Planned: ${site.plannedStartTime} - ${site.plannedEndTime}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const Spacer(),
                      _buildPriorityTag(assign.priority),
                    ],
                  ),
                  if (visit.entryTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.login, color: Colors.greenAccent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Entry: ${DateFormat('hh:mm a').format(visit.entryTime!)}',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                        ),
                        if (visit.exitTime != null) ...[
                          const SizedBox(width: 16),
                          const Icon(Icons.logout, color: Colors.redAccent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Exit: ${DateFormat('hh:mm a').format(visit.exitTime!)}',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ]
                      ],
                    )
                  ]
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriorityTag(String priority) {
    Color color = Colors.blue;
    if (priority == 'High') color = Colors.redAccent;
    if (priority == 'Medium') color = Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMapTab(BuildContext context, TrackerState state) {
    Color hexToColor(String hex) {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    }

    final mapSvc = Provider.of<MapService>(context);
    final workerPos = LatLng(state.currentLat, state.currentLng);
    final myTrail = state.heartbeatLogs
        .where((h) => h.workerId == state.currentWorker.id)
        .map((h) => LatLng(h.latitude, h.longitude))
        .toList();

    // Add current position to end of trail if not already there
    if (myTrail.isEmpty || myTrail.last.latitude != state.currentLat || myTrail.last.longitude != state.currentLng) {
      myTrail.add(workerPos);
    }

    // Center on worker location once a real position is acquired
    if (state.hasRealLocation && !_hasCenteredOnWorkerLocation) {
      _hasCenteredOnWorkerLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(workerPos, 14);
      });
    }

    final circles = <CircleMarker>[];
    final polygons = <Polygon>[];

    for (final g in mapSvc.geofences) {
      final color = hexToColor(g.color);
      if (g.type == GeofenceShape.circle && g.center != null && g.radiusM != null) {
        circles.add(CircleMarker(
          point: g.center!,
          radius: g.radiusM!,
          useRadiusInMeter: true,
          color: color.withOpacity(0.08),
          borderColor: color.withOpacity(0.6),
          borderStrokeWidth: 2,
        ));
      } else if (g.type == GeofenceShape.polygon && g.polygon != null) {
        polygons.add(Polygon(
          points: g.polygon!,
          color: color.withOpacity(0.08),
          borderColor: color.withOpacity(0.6),
          borderStrokeWidth: 2,
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E26),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: workerPos,
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.sgs.field_tracker',
                        ),
                        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
                        if (circles.isNotEmpty) CircleLayer(circles: circles),
                        if (myTrail.length >= 2)
                          PolylineLayer(polylines: [
                            Polyline(
                              points: myTrail,
                              color: Colors.tealAccent.withOpacity(0.8),
                              strokeWidth: 3,
                            )
                          ]),
                        MarkerLayer(markers: [
                          Marker(
                            point: workerPos,
                            width: 60,
                            height: 60,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.tealAccent.withOpacity(0.2),
                                    border: Border.all(
                                      color: state.isWorkerWsConnected ? Colors.tealAccent : Colors.orangeAccent,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: state.isWorkerWsConnected ? Colors.tealAccent.withOpacity(0.4) : Colors.orangeAccent.withOpacity(0.4),
                                        blurRadius: 10,
                                      )
                                    ],
                                  ),
                                  child: const Icon(Icons.person_pin, color: Colors.white, size: 24),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: state.isWorkerWsConnected ? Colors.tealAccent : Colors.orangeAccent),
                        ),
                        child: Text(
                          state.isWorkerWsConnected ? 'Connected (WS)' : 'Offline Mode',
                          style: TextStyle(
                            color: state.isWorkerWsConnected ? Colors.tealAccent : Colors.orangeAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Tooltip(
                        message: 'Center on my location',
                        child: FloatingActionButton.small(
                          heroTag: 'worker_recenter_fab',
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          onPressed: () {
                            _mapController.move(workerPos, 14);
                          },
                          child: const Icon(Icons.my_location, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Location card info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E26),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.tealAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coordinates: ${state.currentLat.toStringAsFixed(5)}° N, ${state.currentLng.toStringAsFixed(5)}° E',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Accuracy: ± ${state.currentAccuracy.toStringAsFixed(1)} meters • status: ${state.isGpsEnabled ? "GPS Active" : "GPS Disabled"}',
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: state.isGpsEnabled ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  width: 10,
                  height: 10,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsTab(BuildContext context, TrackerState state) {
    // Show heartbeat Logs and Tamper alerts
    final hbs = state.heartbeatLogs.where((h) => h.workerId == state.currentWorker.id).toList();
    final alerts = state.tamperAlerts.where((a) => a.workerId == state.currentWorker.id).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SYSTEM HEALTH DIAGNOSTIC', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard('Heartbeats Logged', '${hbs.length} pings', Icons.favorite, Colors.pinkAccent),
              const SizedBox(width: 12),
              _buildMetricCard('Tamper Events', '${alerts.length} alerts', Icons.warning, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 20),
          const Text('RECENT SECURITY ALERTS LOG', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: alerts.isEmpty
                ? const Center(child: Text('No tamper events recorded.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                : ListView.builder(
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final a = alerts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.alertType, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(a.details, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('hh:mm a').format(a.timestamp),
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E26),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showSiteDetailsSheet(BuildContext context, TrackerState state, Assignment assign, Site site, VisitRecord visit) {
    final TextEditingController commentController = TextEditingController(text: visit.comments);
    bool photoUploaded = visit.photoPath != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(site.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Code: ${site.code} • Priority: ${assign.priority}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF2D2D38), height: 20),
                  
                  // Instructions
                  const Text('INSTRUCTIONS FROM SUPERVISOR', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF252530), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      assign.instructions.isNotEmpty ? assign.instructions : "No special instructions given.",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Checklist Section
                  const Text('SITE CHECKLIST (TASK DETAILS)', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  
                  ...visit.checklistAtVisit.map((item) {
                    return CheckboxListTile(
                      title: Text(item.task, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      subtitle: Text('Category: ${item.category}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      value: item.isCompleted,
                      onChanged: (val) {
                        state.toggleChecklistItem(state.currentWorker.id, site.id, item.id);
                        setSheetState(() {});
                      },
                      activeColor: Colors.tealAccent,
                      checkColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
                  
                  const SizedBox(height: 16),

                  // Photo Camera Attachment Simulation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CAMERA PHOTO VERIFICATION', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      if (photoUploaded)
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                            SizedBox(width: 4),
                            Text('Attached', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                          ],
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setSheetState(() {
                        photoUploaded = true;
                      });
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Site Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: photoUploaded ? Colors.green.withOpacity(0.2) : const Color(0xFF2D2D44),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comments
                  const Text('COMMENTS / JUSTIFICATIONS', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: commentController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF252530),
                      hintText: 'Add notes (e.g., resources check, OT justifications)',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  ElevatedButton(
                    onPressed: () {
                      state.submitVisitDetails(
                        state.currentWorker.id,
                        site.id,
                        comments: commentController.text,
                        photoPath: photoUploaded ? 'mock_photo_path.jpg' : null,
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('SAVE & UPDATE VISIT', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMorningAlarmOverlay(BuildContext context, TrackerState state) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0C0C14).withOpacity(0.95),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm, color: Color(0xFF6C63FF), size: 80),
            const SizedBox(height: 24),
            const Text(
              '08:00 AM',
              style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Good Morning, Please Start Your Shift',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: Colors.greenAccent, size: 14),
                  SizedBox(width: 4),
                  Text('GPS coordinates automatically active', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                state.triggerAlarm(false);
                state.startShift(state.currentWorker.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Dismiss & Start Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceNotificationOverlay(BuildContext context, TrackerState state) {
    final bannerMessage = state.activeNotificationBanner;
    if (bannerMessage == null) return const SizedBox.shrink();

    final isEntry = bannerMessage.toLowerCase().contains('entered') || bannerMessage.toLowerCase().contains('returned');
    final color = isEntry ? Colors.tealAccent : Colors.redAccent;

    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: 0.9,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(isEntry ? Icons.check_circle : Icons.error, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bannerMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
