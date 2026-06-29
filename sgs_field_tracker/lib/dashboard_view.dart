import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'tracker_state.dart';
import 'models.dart';
import 'geofence_model.dart';
import 'map_service.dart';
import 'live_map_view.dart' show LiveMapView, MapStyle, hexToColor;
import 'worker_location.dart';
import 'dart:math';

Color _hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

class ActivityEvent {
  final String workerName;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  ActivityEvent({
    required this.workerName,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _activeTab = 0;
  final MapController _dashboardMapController = MapController();
  String _selectedDepartmentFilter = 'All';
  MapStyle _dashboardMapStyle = MapStyle.satellite;
  
  Worker? _selectedSiteWiseWorker;
  final ScrollController _dailyScrollCtrl = ScrollController();
  final ScrollController _siteWiseScrollCtrl = ScrollController();
  final ScrollController _overtimeScrollCtrl = ScrollController();

  final List<String> _tabs = [
    'Dashboard',
    'Live Map',
    'Workers',
    'Sites',
    'Pending Visits',
    'Attendance',
    'Reports',
    'Schedule',
    'Checklists',
    'Settings',
    'Profile',
  ];

  @override
  void dispose() {
    _dashboardMapController.dispose();
    _dailyScrollCtrl.dispose();
    _siteWiseScrollCtrl.dispose();
    _overtimeScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TrackerState>(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF13131A),
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar (Visible only on desktop/large screens)
              if (isDesktop) _buildSidebar(context, state),
              
              // Main Body Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopNav(context, state, isDesktop),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        child: _buildActiveTabContent(context, state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 80,
            right: 24,
            width: 320,
            child: _buildFloatingNotifications(context, state),
          ),
        ],
      ),
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context, state)) : null,
    );
  }

  Widget _buildSidebar(BuildContext context, TrackerState state) {
    return Container(
      width: 250,
      color: const Color(0xFF1E1E26),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.centerLeft,
            child: const Row(
              children: [
                Icon(Icons.track_changes, color: Colors.tealAccent, size: 28),
                SizedBox(width: 12),
                Text(
                  'SGS TRACKER',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2D2D38)),
          Expanded(
            child: ListView.builder(
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                bool isActive = _activeTab == index;
                IconData icon;
                switch (index) {
                  case 0: icon = Icons.dashboard_outlined; break;
                  case 1: icon = Icons.map_outlined; break;
                  case 2: icon = Icons.people_outline; break;
                  case 3: icon = Icons.business_outlined; break;
                  case 4: icon = Icons.pending_actions_outlined; break;
                  case 5: icon = Icons.assignment_turned_in_outlined; break;
                  case 6: icon = Icons.bar_chart_outlined; break;
                  case 7: icon = Icons.calendar_month_outlined; break;
                  case 8: icon = Icons.checklist_outlined; break;
                  case 9: icon = Icons.settings_outlined; break;
                  case 10: icon = Icons.person_outline; break;
                  default: icon = Icons.circle;
                }
                return ListTile(
                  leading: Icon(icon, color: isActive ? Colors.tealAccent : Colors.grey, size: 20),
                  title: Text(
                    _tabs[index],
                    style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
                  ),
                  selected: isActive,
                  selectedTileColor: Colors.teal.withOpacity(0.08),
                  onTap: () {
                    setState(() => _activeTab = index);
                    if (Navigator.canPop(context)) Navigator.pop(context); // close drawer
                  },
                );
              },
            ),
          ),
          // Footer / Version
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: const Text('v1.0.0 Stable (June 2026)', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNav(BuildContext context, TrackerState state, bool isDesktop) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E26),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D38))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (!isDesktop)
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _activeTab == 0 ? '' : _tabs[_activeTab],
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Role & Date selection
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Role dropdown selector
              if (isDesktop)
                const Text('Active Role: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
              if (isDesktop)
                const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13131A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2D2D38)),
                ),
                child: DropdownButton<String>(
                  value: state.activeRoleId,
                  dropdownColor: const Color(0xFF1E1E26),
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    if (val != null) state.setActiveRole(val);
                  },
                  items: ['Admin', 'Engineer', 'Supervisor'].map((role) {
                    return DropdownMenuItem<String>(value: role, child: Text(role));
                  }).toList(),
                ),
              ),
              if (isDesktop)
                const SizedBox(width: 16)
              else
                const SizedBox(width: 8),
              // Date picker display (hidden on dashboard)
              if (_activeTab != 0 && isDesktop)
                InkWell(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: state.selectedDate,
                      firstDate: DateTime(2026, 1, 1),
                      lastDate: DateTime(2026, 12, 31),
                    );
                    if (picked != null) state.setSelectedDate(picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13131A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2D2D38)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.tealAccent, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd-MMM-yyyy').format(state.selectedDate),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(BuildContext context, TrackerState state) {
    switch (_activeTab) {
      case 0: return _buildDashboard(context, state);
      case 1: return const LiveMapView();
      case 2: return _buildWorkerManagement(context, state);
      case 3: return _buildSiteManagement(context, state);
      case 4: return _buildPendingVisits(context, state);
      case 5: return _buildReports(context, state); // Attendance
      case 6: return _buildReports(context, state); // Reports
      case 7: return _buildAdvancedScheduler(context, state); // Schedule
      default: return _buildPlaceholderTab(_tabs[_activeTab]);
    }
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_outlined, size: 64, color: Colors.tealAccent.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('$title Page Under Construction', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('This feature is being prepared as part of the supervisor console.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _showFilterDialog(BuildContext context, TrackerState state) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E26),
          title: const Text('Filter Workers by Department', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['All', 'Irrigation', 'Landscaping', 'Civil', 'Projects'].map((dept) {
              final isSelected = _selectedDepartmentFilter == dept;
              return ListTile(
                title: Text(dept, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white, fontSize: 14)),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.tealAccent) : null,
                onTap: () {
                  setState(() {
                    _selectedDepartmentFilter = dept;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  Widget _dashboardStyleSegmentBtn(MapStyle style, String label) {
    final active = _dashboardMapStyle == style;
    return GestureDetector(
      onTap: () => setState(() => _dashboardMapStyle = style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00BFA5).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF00BFA5) : Colors.grey,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, TrackerState state) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final filteredWorkers = _selectedDepartmentFilter == 'All'
        ? state.workers
        : state.workers.where((w) => w.department == _selectedDepartmentFilter).toList();

    final totalWorkers = filteredWorkers.length;
    
    final presentCount = state.attendanceRecords.where((r) => 
        filteredWorkers.any((w) => w.id == r.workerId) && r.status == 'Present').length;
    final pendingCount = state.attendanceRecords.where((r) => 
        filteredWorkers.any((w) => w.id == r.workerId) && r.status == 'Pending').length;
    final absentCount = state.attendanceRecords.where((r) => 
        filteredWorkers.any((w) => w.id == r.workerId) && r.status == 'Absent').length;
    
    final mapSvc = Provider.of<MapService>(context);
    final gpsOfflineCount = filteredWorkers.where((w) {
      if (mapSvc.workerLocations.containsKey(w.id)) {
        final loc = mapSvc.workerLocations[w.id]!;
        return !loc.isOnline || !loc.isRecent;
      }
      return true;
    }).length;

    final presentPct = totalWorkers > 0 ? (presentCount / totalWorkers * 100).toStringAsFixed(1) : '0.0';
    final pendingPct = totalWorkers > 0 ? (pendingCount / totalWorkers * 100).toStringAsFixed(1) : '0.0';
    final absentPct = totalWorkers > 0 ? (absentCount / totalWorkers * 100).toStringAsFixed(1) : '0.0';
    final offlinePct = totalWorkers > 0 ? (gpsOfflineCount / totalWorkers * 100).toStringAsFixed(1) : '0.0';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: state.selectedDate,
                        firstDate: DateTime(2026, 1, 1),
                        lastDate: DateTime(2026, 12, 31),
                      );
                      if (picked != null) state.setSelectedDate(picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2D2D38)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.tealAccent, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy').format(state.selectedDate),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _showFilterDialog(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2D2D38)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.filter_alt_outlined, color: Colors.grey, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _selectedDepartmentFilter == 'All' ? 'Filters' : 'Filter: $_selectedDepartmentFilter',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (isDesktop)
            Row(
              children: [
                _buildDashboardStatCard('Total Workers', '$totalWorkers', null, Colors.white),
                const SizedBox(width: 16),
                _buildDashboardStatCard('Present', '$presentCount', '$presentPct%', const Color(0xFF00BFA5)),
                const SizedBox(width: 16),
                _buildDashboardStatCard('Pending', '$pendingCount', '$pendingPct%', const Color(0xFFFF9800)),
                const SizedBox(width: 16),
                _buildDashboardStatCard('Absent', '$absentCount', '$absentPct%', const Color(0xFFF44336)),
                const SizedBox(width: 16),
                _buildDashboardStatCard('GPS Offline', '$gpsOfflineCount', '$offlinePct%', const Color(0xFFF44336)),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    _buildDashboardStatCard('Total Workers', '$totalWorkers', null, Colors.white),
                    const SizedBox(width: 12),
                    _buildDashboardStatCard('Present', '$presentCount', '$presentPct%', const Color(0xFF00BFA5)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildDashboardStatCard('Pending', '$pendingCount', '$pendingPct%', const Color(0xFFFF9800)),
                    const SizedBox(width: 12),
                    _buildDashboardStatCard('Absent', '$absentCount', '$absentPct%', const Color(0xFFF44336)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildDashboardStatCard('GPS Offline', '$gpsOfflineCount', '$offlinePct%', const Color(0xFFF44336)),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 24),

          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 480,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E26),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2D2D38)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            const Text(
                              'Live Workers on Map',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2D2D38)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _dashboardStyleSegmentBtn(MapStyle.dark, 'Dark'),
                                      _dashboardStyleSegmentBtn(MapStyle.light, 'Light'),
                                      _dashboardStyleSegmentBtn(MapStyle.satellite, 'Sat'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.fullscreen, color: Colors.tealAccent, size: 20),
                                  tooltip: 'View Full Screen Map',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      _activeTab = 1;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                _buildDashboardMapPreview(context, state),
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: Column(
                                    children: [
                                      _buildMapZoomButton(Icons.add, () {
                                        _dashboardMapController.move(
                                          _dashboardMapController.camera.center,
                                          (_dashboardMapController.camera.zoom + 1).clamp(1.0, 22.0),
                                        );
                                      }),
                                      const SizedBox(height: 8),
                                      _buildMapZoomButton(Icons.remove, () {
                                        _dashboardMapController.move(
                                          _dashboardMapController.camera.center,
                                          (_dashboardMapController.camera.zoom - 1).clamp(1.0, 22.0),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                Expanded(
                  flex: 1,
                  child: Container(
                    height: 480,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E26),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2D2D38)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Activity',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _buildRecentActivityFeed(context, state),
                        ),
                        const Divider(color: Color(0xFF2D2D38), height: 24),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _activeTab = 5; // navigate to Attendance Reports
                              });
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 350,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E26),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2D2D38)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Expanded(
                              child: const Text(
                                'Live Workers on Map',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2D2D38)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _dashboardStyleSegmentBtn(MapStyle.dark, 'Dark'),
                                      _dashboardStyleSegmentBtn(MapStyle.light, 'Light'),
                                      _dashboardStyleSegmentBtn(MapStyle.satellite, 'Sat'),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.fullscreen, color: Colors.tealAccent, size: 20),
                                tooltip: 'View Full Screen Map',
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() {
                                    _activeTab = 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              _buildDashboardMapPreview(context, state),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Column(
                                  children: [
                                    _buildMapZoomButton(Icons.add, () {
                                      _dashboardMapController.move(
                                        _dashboardMapController.camera.center,
                                        (_dashboardMapController.camera.zoom + 1).clamp(1.0, 22.0),
                                      );
                                    }),
                                    const SizedBox(height: 6),
                                    _buildMapZoomButton(Icons.remove, () {
                                      _dashboardMapController.move(
                                        _dashboardMapController.camera.center,
                                        (_dashboardMapController.camera.zoom - 1).clamp(1.0, 22.0),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 350,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E26),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2D2D38)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildRecentActivityFeed(context, state),
                      ),
                      const Divider(color: Color(0xFF2D2D38), height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _activeTab = 5; // navigate to Attendance Reports
                            });
                          },
                          child: const Text(
                            'View All',
                            style: TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardStatCard(String title, String value, String? percentage, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2D2D38)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color == Colors.white ? Colors.white : color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (percentage != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        percentage,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardMapPreview(BuildContext context, TrackerState state) {
    final mapSvc = Provider.of<MapService>(context);
    final geofences = mapSvc.geofences;
    final circles = <CircleMarker>[];
    final polygons = <Polygon>[];

    for (final g in geofences) {
      final color = _hexToColor(g.color);
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

    final markers = <Marker>[];

    final filteredWorkers = _selectedDepartmentFilter == 'All'
        ? state.workers
        : state.workers.where((w) => w.department == _selectedDepartmentFilter).toList();

    for (final entry in mapSvc.workerLocations.entries) {
      final loc = entry.value;
      if (!filteredWorkers.any((w) => w.id == loc.workerId)) continue;
      markers.add(Marker(
        point: LatLng(loc.lat, loc.lng),
        width: 60,
        height: 60,
        child: _buildDashboardWorkerMarker(loc),
      ));
    }

    for (final worker in filteredWorkers) {
      if (!mapSvc.workerLocations.containsKey(worker.id)) {
        final hb = state.heartbeatLogs
            .lastWhere((h) => h.workerId == worker.id,
                orElse: () => HeartbeatLog(
                      id: '',
                      workerId: worker.id,
                      timestamp: DateTime.now(),
                      latitude: 25.2048 + (state.workers.indexOf(worker) * 0.005),
                      longitude: 55.2708,
                    ));
        markers.add(Marker(
          point: LatLng(hb.latitude, hb.longitude),
          width: 50,
          height: 50,
          child: _buildDashboardOfflineMarker(worker.name),
        ));
      }
    }

    if (state.hasRealLocation) {
      markers.add(Marker(
        point: LatLng(state.currentLat, state.currentLng),
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blueAccent.withOpacity(0.3),
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ));
    }

    TileLayer tileLayer;
    if (_dashboardMapStyle == MapStyle.dark) {
      tileLayer = TileLayer(
        urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
        subdomains: const ['a', 'b', 'c', 'd'],
        userAgentPackageName: 'com.sgs.field_tracker',
      );
    } else if (_dashboardMapStyle == MapStyle.light) {
      tileLayer = TileLayer(
        urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
        subdomains: const ['a', 'b', 'c', 'd'],
        userAgentPackageName: 'com.sgs.field_tracker',
      );
    } else {
      tileLayer = TileLayer(
        urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
        userAgentPackageName: 'com.sgs.field_tracker',
        maxNativeZoom: 21,
        maxZoom: 22,
      );
    }

    return FlutterMap(
      mapController: _dashboardMapController,
      options: MapOptions(
        initialCenter: LatLng(state.currentLat, state.currentLng),
        initialZoom: 12,
        maxZoom: 22,
      ),
      children: [
        tileLayer,
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        if (circles.isNotEmpty) CircleLayer(circles: circles),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildDashboardWorkerMarker(WorkerLocation loc) {
    final isOnline = loc.isOnline && loc.isRecent;
    final color = isOnline
        ? (loc.isOnShift ? const Color(0xFF00BFA5) : const Color(0xFFFFD600))
        : const Color(0xFFF44336);
    final initials = _getInitials(loc.workerName);

    final tooltipMsg = 'Name: ${loc.workerName}\n'
        'Status: ${isOnline ? (loc.isOnShift ? "On Shift (Present)" : "Pending check-in") : "Offline/Absent"}\n'
        'Last Active: ${DateFormat('hh:mm a').format(loc.timestamp)}';

    return Tooltip(
      message: tooltipMsg,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.all(8),
      preferBelow: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E26),
              border: Border.all(color: color, width: 2),
            ),
            child: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Text(
                initials,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              loc.workerName.split(' ').first,
              style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardOfflineMarker(String name) {
    final initials = _getInitials(name);
    const color = Color(0xFFF44336);
    final tooltipMsg = 'Name: $name\nStatus: Offline/Absent';

    return Tooltip(
      message: tooltipMsg,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.all(8),
      preferBelow: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E26),
              border: Border.all(color: color, width: 1.5),
            ),
            child: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Text(
                initials,
                style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              name.split(' ').first,
              style: const TextStyle(color: Colors.grey, fontSize: 7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapZoomButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E26),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2D2D38)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildRecentActivityFeed(BuildContext context, TrackerState state) {
    final List<ActivityEvent> events = [];
    final filteredWorkers = _selectedDepartmentFilter == 'All'
        ? state.workers
        : state.workers.where((w) => w.department == _selectedDepartmentFilter).toList();

    for (var record in state.attendanceRecords) {
      if (!filteredWorkers.any((w) => w.id == record.workerId)) continue;
      final worker = filteredWorkers.firstWhere((w) => w.id == record.workerId);
      if (record.shiftStart != null) {
        events.add(ActivityEvent(
          workerName: worker.name,
          description: 'Started shift',
          timestamp: record.shiftStart!,
          icon: Icons.login,
          color: const Color(0xFF00BFA5),
        ));
      }
      if (record.shiftEnd != null) {
        events.add(ActivityEvent(
          workerName: worker.name,
          description: 'Ended shift',
          timestamp: record.shiftEnd!,
          icon: Icons.logout,
          color: Colors.grey,
        ));
      }
      for (var visit in record.visits) {
        final site = state.sites.firstWhere((s) => s.id == visit.siteId, orElse: () => Site(
          id: visit.siteId, name: 'Worksite', code: 'WS', category: JobCategory.AMC,
          subCategory: SubCategory.Outdoor, jobType: JobType.Permanent, frequency: JobFrequency.Daily,
          address: '', latitude: 0, longitude: 0, radius: 100, plannedStartTime: '', plannedEndTime: '',
        ));
        if (visit.entryTime != null) {
          events.add(ActivityEvent(
            workerName: worker.name,
            description: 'Entered ${site.name}',
            timestamp: visit.entryTime!,
            icon: Icons.check_circle_outline,
            color: const Color(0xFF00BFA5),
          ));
        }
        if (visit.exitTime != null) {
          events.add(ActivityEvent(
            workerName: worker.name,
            description: 'Exited ${site.name}',
            timestamp: visit.exitTime!,
            icon: Icons.exit_to_app,
            color: const Color(0xFFFF9800),
          ));
        }
      }
    }

    for (var alert in state.tamperAlerts) {
      if (state.isSameDay(alert.timestamp, state.selectedDate)) {
        if (!filteredWorkers.any((w) => w.id == alert.workerId)) continue;
        final worker = filteredWorkers.firstWhere((w) => w.id == alert.workerId);
        events.add(ActivityEvent(
          workerName: worker.name,
          description: '${alert.alertType}: ${alert.details}',
          timestamp: alert.timestamp,
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFF44336),
        ));
      }
    }

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (events.length < 4) {
      final baseDate = state.selectedDate;
      events.add(ActivityEvent(
        workerName: 'John Smith',
        description: 'Entered ABC Construction Site',
        timestamp: DateTime(baseDate.year, baseDate.month, baseDate.day, 9, 5),
        icon: Icons.check_circle_outline,
        color: const Color(0xFF00BFA5),
      ));
      events.add(ActivityEvent(
        workerName: 'Alex Kumar',
        description: 'Started shift',
        timestamp: DateTime(baseDate.year, baseDate.month, baseDate.day, 8, 45),
        icon: Icons.login,
        color: const Color(0xFF00BFA5),
      ));
      events.add(ActivityEvent(
        workerName: 'Mohammed Ali',
        description: 'Exited Palm Tower Site',
        timestamp: DateTime(baseDate.year, baseDate.month, baseDate.day, 8, 30),
        icon: Icons.exit_to_app,
        color: const Color(0xFFFF9800),
      ));
      events.add(ActivityEvent(
        workerName: 'Ravi Singh',
        description: 'Missed check-in',
        timestamp: DateTime(baseDate.year, baseDate.month, baseDate.day, 8, 0),
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFF44336),
      ));
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    return ListView.separated(
      itemCount: min(events.length, 5),
      separatorBuilder: (context, index) => const Divider(color: Color(0xFF2D2D38), height: 16),
      itemBuilder: (context, index) {
        final ev = events[index];
        return Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ev.color.withOpacity(0.1),
                border: Border.all(color: ev.color.withOpacity(0.5), width: 1),
              ),
              child: Center(
                child: Icon(ev.icon, color: ev.color, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ev.workerName,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ev.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('hh:mm a').format(ev.timestamp),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 1: SITE MANAGEMENT ---
  Widget _buildSiteManagement(BuildContext context, TrackerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Registered Worksites & Camps',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (state.activeRoleId == 'Admin' || state.activeRoleId == 'Engineer')
              ElevatedButton.icon(
                onPressed: () => _showAddSiteDialog(context, state),
                icon: const Icon(Icons.add),
                label: const Text('Add New Site'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
              )
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: state.sites.length,
            itemBuilder: (context, index) {
              final s = state.sites[index];
              return Card(
                color: const Color(0xFF1E1E26),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: s.isAccommodation ? Colors.blue.withOpacity(0.1) : Colors.teal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              s.isAccommodation ? Icons.home_work_outlined : Icons.business,
                              color: s.isAccommodation ? Colors.blue : Colors.tealAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Code: ${s.code} • Frequency: ${s.frequency.name}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text('Location: ${s.latitude.toStringAsFixed(4)}, ${s.longitude.toStringAsFixed(4)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text('Address: ${s.address}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text('Category: ${s.category.name} / ${s.subCategory.name}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF13131A), borderRadius: BorderRadius.circular(6)),
                            child: Text('Radius: ${s.radius.toInt()}m', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          if (state.activeRoleId == 'Admin' || state.activeRoleId == 'Engineer') ...[
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.tealAccent, size: 20),
                              tooltip: 'Edit Site',
                              onPressed: () => _showEditSiteDialog(context, state, s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              tooltip: 'Delete Site',
                              onPressed: () => _showDeleteConfirmation(context, state, s),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddSiteDialog(BuildContext context, TrackerState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddSiteDialog(state: state),
    );
  }

  void _showEditSiteDialog(BuildContext context, TrackerState state, Site site) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddSiteDialog(state: state, site: site),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TrackerState state, Site site) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: const Text('Delete Worksite', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${site.name}"? This will also remove its geofence from the backend database.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final mapSvc = Provider.of<MapService>(context, listen: false);
              
              // Delete from TrackerState and backend DB
              await state.deleteSite(site.id);
              
              // Refresh MapService geofences
              await mapSvc.fetchGeofences();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Site "${site.name}" deleted successfully.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: WORKER MANAGEMENT ---
  Widget _buildWorkerManagement(BuildContext context, TrackerState state) {
    final expCount = state.workers.where((w) {
      final daysId = w.emiratesIdExpiry.difference(state.simulatedTime).inDays;
      final daysPass = w.passportExpiry.difference(state.simulatedTime).inDays;
      final daysLab = w.labourCardExpiry.difference(state.simulatedTime).inDays;
      return daysId <= 90 || daysPass <= 180 || daysLab <= 90;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Roster title and Alert warning banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Employee Roster & Document Registry',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (state.activeRoleId == 'Admin' || state.activeRoleId == 'Engineer')
              ElevatedButton.icon(
                onPressed: () => _showAddWorkerDialog(context, state),
                icon: const Icon(Icons.add),
                label: const Text('Add Worker'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
              )
          ],
        ),
        const SizedBox(height: 12),
        if (expCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Text(
                  'CRITICAL DOCUMENT RENEWAL SYSTEM: $expCount Workers have credentials expiring soon (Emirates ID/Labour card <= 3mo, Passport <= 6mo).',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: state.workers.length,
            itemBuilder: (context, index) {
              final w = state.workers[index];
              final daysId = w.emiratesIdExpiry.difference(state.simulatedTime).inDays;
              final daysPass = w.passportExpiry.difference(state.simulatedTime).inDays;
              final daysLab = w.labourCardExpiry.difference(state.simulatedTime).inDays;

              bool idAlert = daysId <= 90;
              bool passAlert = daysPass <= 180;
              bool labAlert = daysLab <= 90;

              return Card(
                color: const Color(0xFF1E1E26),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(color: Color(0xFF13131A), shape: BoxShape.circle),
                            child: const Icon(Icons.person, color: Colors.tealAccent),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${w.designation} • ${w.department} Dept • Emp ID: ${w.employeeId}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text('Staff Type: ${w.staffType.name} | Staff Category: ${w.staffCategory.name} | Joined: ${DateFormat('dd-MMM-yyyy').format(w.joinedDate)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Select worker context for simulation helper and delete option
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (state.activeRoleId == 'Admin' || state.activeRoleId == 'Engineer')
                            TextButton.icon(
                              onPressed: () => state.setSelectedWorker(w.id),
                              icon: Icon(Icons.touch_app, size: 14, color: state.selectedWorkerId == w.id ? Colors.tealAccent : Colors.grey),
                              label: Text('Focus for Simulator', style: TextStyle(color: state.selectedWorkerId == w.id ? Colors.tealAccent : Colors.grey, fontSize: 11)),
                            ),
                          const Spacer(),
                          if (state.activeRoleId == 'Admin' || state.activeRoleId == 'Engineer')
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              tooltip: 'Delete Worker',
                              onPressed: () => _showDeleteWorkerConfirmation(context, state, w),
                            ),
                        ],
                      ),
                      const Divider(color: Color(0xFF2D2D38), height: 20),
                      // Expiry Warning indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildExpiryLabel('Emirates ID', w.emiratesId, daysId, idAlert),
                          _buildExpiryLabel('Passport No', w.passportNo, daysPass, passAlert),
                          _buildExpiryLabel('Labour Card', w.labourCardNo, daysLab, labAlert),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDeleteWorkerConfirmation(BuildContext context, TrackerState state, Worker worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: const Text('Delete Worker Profile', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${worker.name}"? This action will permanently remove this worker from the registry.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              state.deleteWorker(worker.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Worker "${worker.name}" deleted successfully.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryLabel(String doc, String val, int daysLeft, bool alert) {
    Color color = Colors.greenAccent;
    String status = "Secure";
    if (daysLeft <= 30) {
      color = Colors.redAccent;
      status = "Expired soon ($daysLeft days)";
    } else if (alert) {
      color = Colors.orangeAccent;
      status = "Renewal warning ($daysLeft days)";
    } else {
      status = "Valid ($daysLeft days)";
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$doc: $val', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(status, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  void _showAddWorkerDialog(BuildContext context, TrackerState state) {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final deptController = TextEditingController(text: "Operations");
    final desController = TextEditingController(text: "Technician");
    final userController = TextEditingController();
    final passController = TextEditingController(text: "password123");
    final emiratesController = TextEditingController();
    final passportController = TextEditingController();
    final labourController = TextEditingController();

    StaffType selectedStaffType = StaffType.IP;
    StaffCategory selectedStaffCategory = StaffCategory.Direct;
    LeaveCategory selectedLeaveCategory = LeaveCategory.Year1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E26),
              title: const Text('Add Worker Profile', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Employee ID (e.g. EMP006)', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    TextField(
                      controller: phoneController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Staff Type: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            DropdownButton<StaffType>(
                              value: selectedStaffType,
                              dropdownColor: const Color(0xFF1E1E26),
                              style: const TextStyle(color: Colors.white),
                              onChanged: (val) => setDialogState(() => selectedStaffType = val!),
                              items: StaffType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Category: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            DropdownButton<StaffCategory>(
                              value: selectedStaffCategory,
                              dropdownColor: const Color(0xFF1E1E26),
                              style: const TextStyle(color: Colors.white),
                              onChanged: (val) => setDialogState(() => selectedStaffCategory = val!),
                              items: StaffCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    TextField(
                      controller: deptController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Department', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    TextField(
                      controller: desController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Designation', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    TextField(
                      controller: userController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Username', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    TextField(
                      controller: passController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    TextField(
                      controller: emiratesController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Emirates ID No', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    TextField(
                      controller: passportController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Passport No', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    TextField(
                      controller: labourController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Labour Card No', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    state.addWorker(Worker(
                      id: 'worker_${DateTime.now().millisecondsSinceEpoch}',
                      employeeId: idController.text,
                      name: nameController.text,
                      phone: phoneController.text,
                      staffType: selectedStaffType,
                      staffCategory: selectedStaffCategory,
                      leaveCategory: selectedLeaveCategory,
                      department: deptController.text,
                      designation: desController.text,
                      username: userController.text,
                      password: passController.text,
                      staffHierarchy: 'Supervisor -> ' + nameController.text,
                      isActive: true,
                      emiratesId: emiratesController.text,
                      emiratesIdExpiry: state.simulatedTime.add(const Duration(days: 365)), // 1 year expiry
                      passportNo: passportController.text,
                      passportExpiry: state.simulatedTime.add(const Duration(days: 500)),
                      labourCardNo: labourController.text,
                      labourCardExpiry: state.simulatedTime.add(const Duration(days: 365)),
                      joinedDate: state.simulatedTime,
                      leaveDueDate: state.simulatedTime.add(const Duration(days: 365)),
                    ));
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- TAB 3: ADVANCED SCHEDULER ---
  Widget _buildAdvancedScheduler(BuildContext context, TrackerState state) {
    // Spreadsheet grid: Workers as Rows, Days (Next 15 days) as Columns
    List<DateTime> days = List.generate(15, (index) => DateTime(2026, 6, 17).add(Duration(days: index)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('15-Day Advanced Spreadsheet Scheduler Grid', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Click on any grid cell to create, edit, or remove worksite assignments.', style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: const Color(0xFF2D2D38)),
                defaultColumnWidth: const FixedColumnWidth(150),
                children: [
                  // Header Row
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFF1E1E26)),
                    children: [
                      const TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Workers \\ Dates', style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      ...days.map((d) {
                        return TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              DateFormat('dd-MMM (EEE)').format(d),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  // Workers Rows
                  ...state.workers.map((worker) {
                    return TableRow(
                      children: [
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(worker.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(worker.employeeId, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                        ...days.map((date) {
                          // Find assignments for this worker and date
                          var cellAssigns = state.allAssignments.where((a) => a.workerId == worker.id && state.isSameDay(a.date, date)).toList();

                          return TableCell(
                            child: InkWell(
                              onTap: cellAssigns.isEmpty ? () => _showCellSchedulingDialog(context, state, worker, date, forceNew: true) : null,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 60),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: cellAssigns.isNotEmpty ? Colors.teal.withOpacity(0.1) : Colors.transparent,
                                ),
                                child: cellAssigns.isEmpty
                                    ? const Center(child: Icon(Icons.add, color: Color(0xFF2D2D38), size: 16))
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: cellAssigns.map((a) {
                                          var site = state.sites.firstWhere((s) => s.id == a.siteId, orElse: () => state.sites.first);
                                          return InkWell(
                                            onTap: () => _showCellSchedulingDialog(context, state, worker, date, targetAssignment: a),
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 2),
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFF13131A), borderRadius: BorderRadius.circular(4)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    site.name,
                                                    style: const TextStyle(color: Colors.tealAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                                    overflow: TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 12),
                                                  onPressed: () {
                                                    state.removeAssignment(a.id);
                                                  },
                                                )
                                              ],
                                            ),
                                          ));
                                        }).toList(),
                                      ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  })
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCellSchedulingDialog(BuildContext context, TrackerState state, Worker worker, DateTime date, {bool forceNew = false, Assignment? targetAssignment}) {
    if (state.activeRoleId == 'Supervisor') {
      // Show warning since Supervisor can only temporarily rearrange but let's allow it in simulation
    }

    final matchingAssignments = state.allAssignments.where((a) => a.workerId == worker.id && state.isSameDay(a.date, date)).toList();
    final existingAssignment = forceNew ? null : (targetAssignment ?? (matchingAssignments.isNotEmpty ? matchingAssignments.first : null));
    bool isEditing = existingAssignment == null;

    final instructionController = TextEditingController(text: existingAssignment?.instructions ?? "");
    final breakController = TextEditingController(text: existingAssignment?.breakTime ?? "12:00 PM - 01:00 PM");
    
    // Checklist inputs
    List<ChecklistItem> defaultChecklists = [
      ChecklistItem(id: 'c_l1', task: 'Check resources (Labour present)', category: 'Labour'),
      ChecklistItem(id: 'c_l2', task: 'Check resources (Equipment & Machineries)', category: 'Equipment'),
      ChecklistItem(id: 'c_l3', task: 'Inspect Hand tools & Vehicle log', category: 'Tools'),
      ChecklistItem(id: 'c_l4', task: 'Verify materials status', category: 'Materials'),
    ];

    List<ChecklistItem> checklist = [];
    if (existingAssignment != null) {
      checklist = defaultChecklists.map((c) {
        final copy = c.copy();
        copy.isCompleted = existingAssignment.checklist.any((ea) => ea.task == c.task);
        return copy;
      }).toList();
      for (var ea in existingAssignment.checklist) {
        if (!checklist.any((c) => c.task == ea.task)) {
          final custom = ea.copy();
          custom.isCompleted = true; // Selected
          checklist.add(custom);
        }
      }
    } else {
      checklist = defaultChecklists.map((c) {
        final copy = c.copy();
        copy.isCompleted = true; // Default behavior
        return copy;
      }).toList();
    }

    final newChecklistController = TextEditingController();
    final checklistScrollController = ScrollController();

    String selectedSiteId = existingAssignment?.siteId ?? state.sites.firstWhere((s) => !s.isAccommodation).id;
    String selectedPriority = existingAssignment?.priority ?? 'High';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E26),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Schedule Work: ${worker.name}\nDate: ${DateFormat('dd-MMM-yyyy').format(date)}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  if (existingAssignment != null) 
                    IconButton(
                      icon: Icon(isEditing ? Icons.close : Icons.edit, color: Colors.tealAccent),
                      onPressed: () => setDialogState(() => isEditing = !isEditing),
                    )
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        controller: checklistScrollController,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Select Worksite: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                if (isEditing)
                                  DropdownButton<String>(
                                    value: selectedSiteId,
                                    dropdownColor: const Color(0xFF1E1E26),
                                    style: const TextStyle(color: Colors.white),
                                    onChanged: (val) => setDialogState(() => selectedSiteId = val!),
                                    items: state.sites.where((s) => !s.isAccommodation).map((site) {
                                      return DropdownMenuItem(value: site.id, child: Text(site.name));
                                    }).toList(),
                                  )
                                else
                                  Text(state.sites.firstWhere((s) => s.id == selectedSiteId, orElse: () => state.sites.first).name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text('Priority: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                if (isEditing)
                                  DropdownButton<String>(
                                    value: selectedPriority,
                                    dropdownColor: const Color(0xFF1E1E26),
                                    style: const TextStyle(color: Colors.white),
                                    onChanged: (val) => setDialogState(() => selectedPriority = val!),
                                    items: ['High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                  )
                                else
                                  Text(selectedPriority, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (isEditing)
                              TextField(
                                controller: instructionController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(labelText: 'Instructions', labelStyle: TextStyle(color: Colors.grey)),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Instructions', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text(instructionController.text.isEmpty ? 'None' : instructionController.text, style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                            const SizedBox(height: 12),
                            if (isEditing)
                              TextField(
                                controller: breakController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(labelText: 'Break Times', labelStyle: TextStyle(color: Colors.grey)),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Break Times', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text(breakController.text, style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                            const SizedBox(height: 16),
                            const Align(alignment: Alignment.centerLeft, child: Text('Checklists to Attach:', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                            const SizedBox(height: 8),
                            Column(
                              children: checklist.map((item) {
                                return CheckboxListTile(
                                  title: Text(item.task, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  value: item.isCompleted,
                                  onChanged: isEditing ? (val) => setDialogState(() => item.isCompleted = val!) : null,
                                  activeColor: Colors.tealAccent,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newChecklistController,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(hintText: 'Add Checklist Option', hintStyle: TextStyle(color: Colors.grey, fontSize: 12)),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (newChecklistController.text.isNotEmpty) {
                                setDialogState(() {
                                  checklist.add(ChecklistItem(id: 'custom_${DateTime.now().millisecondsSinceEpoch}', task: newChecklistController.text, category: 'Custom', isCompleted: true));
                                  newChecklistController.clear();
                                });
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  if (checklistScrollController.hasClients) {
                                    checklistScrollController.animateTo(
                                      checklistScrollController.position.maxScrollExtent,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                });
                              }
                            },
                            child: const Text('Add', style: TextStyle(color: Colors.tealAccent)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (existingAssignment != null && !isEditing)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCellSchedulingDialog(context, state, worker, date, forceNew: true);
                    },
                    child: const Text('Add New Site', style: TextStyle(color: Colors.tealAccent)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
                if (isEditing)
                  ElevatedButton(
                    onPressed: () {
                      final finalChecklist = checklist.where((c) => c.isCompleted).map((c) {
                        final copy = c.copy();
                        copy.isCompleted = false; 
                        return copy;
                      }).toList();

                      state.assignSiteToWorker(
                        workerId: worker.id,
                        siteId: selectedSiteId,
                        date: date,
                        instructions: instructionController.text,
                        checklist: finalChecklist,
                        priority: selectedPriority,
                        breakTime: breakController.text,
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
                    child: const Text('Save Assignment', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // --- TAB 4: PENDING VISITS OVERRIDE ---
  Widget _buildPendingVisits(BuildContext context, TrackerState state) {
    // List all incomplete visits for today's active assignments
    List<Map<String, dynamic>> pendingItems = [];

    for (var record in state.attendanceRecords) {
      final worker = state.workers.firstWhere((w) => w.id == record.workerId, orElse: () => Worker(
        id: record.workerId,
        employeeId: 'EMP000',
        name: 'Unknown Worker',
        phone: '',
        staffType: StaffType.IP,
        staffCategory: StaffCategory.Direct,
        leaveCategory: LeaveCategory.Year1,
        department: 'None',
        designation: 'N/A',
        username: 'none',
        password: '',
        staffHierarchy: '',
        isActive: false,
        emiratesId: '',
        emiratesIdExpiry: DateTime.now(),
        passportNo: '',
        passportExpiry: DateTime.now(),
        labourCardNo: '',
        labourCardExpiry: DateTime.now(),
        joinedDate: DateTime.now(),
        leaveDueDate: DateTime.now(),
      ));
      for (var visit in record.visits) {
        final site = state.sites.firstWhere((s) => s.id == visit.siteId);
        if (visit.status == 'Pending' && !site.isAccommodation) {
          pendingItems.add({
            'recordId': record.id,
            'worker': worker,
            'visit': visit,
            'site': site,
          });
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pending Worksite Visit Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Manage workers who missed site entry logs. Engineers and Supervisors can manually adjust attendance.', style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 16),
        Expanded(
          child: pendingItems.isEmpty
              ? const Center(child: Text('No pending visits for today.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: pendingItems.length,
                  itemBuilder: (context, index) {
                    final item = pendingItems[index];
                    final Worker worker = item['worker'];
                    final VisitRecord visit = item['visit'];
                    final Site site = item['site'];

                    return Card(
                      color: const Color(0xFF1E1E26),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(worker.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('Missed Site: ${site.name} (${site.code})', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text('Planned: ${site.plannedStartTime} - ${site.plannedEndTime}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            // Quick Action Override buttons
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showPendingResolveDialog(context, state, item['recordId'], site.id, 'present'),
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('Mark Present', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _showPendingResolveDialog(context, state, item['recordId'], site.id, 'ignore'),
                                  icon: const Icon(Icons.close, size: 14),
                                  label: const Text('Ignore', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showPendingResolveDialog(BuildContext context, TrackerState state, String recordId, String siteId, String action) {
    final expController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E26),
          title: Text(action == 'present' ? 'Override Visit to Completed' : 'Ignore Pending Visit', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: expController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Justification / Explanation',
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: 'e.g., Worker had vehicle puncture, resolved manually',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                state.resolvePendingVisit(recordId, siteId, action, explanation: expController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 5: REPORTS ---
  Widget _buildReports(BuildContext context, TrackerState state) {
    // We offer: 1. Daily Attendance Report, 2. Site-wise Detailed Report, 3. Overtime Salary calculations
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Daily Attendance'),
              Tab(text: 'Site-Wise Details'),
              Tab(text: 'Overtime Module'),
            ],
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.grey,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                _buildDailyAttendanceReport(context, state),
                _buildSiteWiseDetailedReport(context, state),
                _buildOvertimeReport(context, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyAttendanceReport(BuildContext context, TrackerState state) {
    return Scrollbar(
      controller: _dailyScrollCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _dailyScrollCtrl,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Container(
          color: const Color(0xFF1E1E26),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Emp ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Worker Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Shift Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Shift End', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Assigned', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Visited', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Work Hrs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Overtime', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Approval', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
            rows: state.attendanceRecords.map((r) {
              final w = state.workers.firstWhere((worker) => worker.id == r.workerId);
              
              var workVisits = r.visits.where((v) {
                var s = state.sites.firstWhere((site) => site.id == v.siteId, orElse: () => state.sites.first);
                return !s.isAccommodation;
              }).toList();
              
              int completed = workVisits.where((v) => v.status == 'Completed').length;
              int skipped = workVisits.where((v) => v.status == 'Skipped').length;
              int assignedCount = workVisits.length - skipped;

              String startStr = r.shiftStart != null ? DateFormat('hh:mm a').format(r.shiftStart!) : '—';
              String endStr = r.shiftEnd != null ? DateFormat('hh:mm a').format(r.shiftEnd!) : '—';
              
              double normalHours = r.normalHours;
              double otHours = r.overtimeHours;
              double totalHours = normalHours + otHours;

              Color statusColor = Colors.redAccent;
              if (r.status == 'Present') statusColor = Colors.greenAccent;
              if (r.status == 'Partial') statusColor = Colors.orangeAccent;
              if (r.status == 'Pending') statusColor = Colors.yellowAccent;

              return DataRow(
                cells: [
                  DataCell(Text(w.employeeId, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(w.name, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(startStr, style: const TextStyle(color: Colors.grey))),
                  DataCell(Text(endStr, style: const TextStyle(color: Colors.grey))),
                  DataCell(Text('$assignedCount', style: const TextStyle(color: Colors.white))),
                  DataCell(Text('$completed', style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${totalHours.toStringAsFixed(1)}h', style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${otHours.toStringAsFixed(1)}h', style: TextStyle(color: otHours > 0 ? Colors.blueAccent : Colors.grey))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(r.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  DataCell(
                    Checkbox(
                      value: r.isApproved,
                      onChanged: (val) {
                        r.isApproved = val!;
                        state.notifyListeners();
                      },
                      activeColor: Colors.tealAccent,
                      checkColor: Colors.black,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSiteWiseDetailedReport(BuildContext context, TrackerState state) {
    if (_selectedSiteWiseWorker == null) {
      return Scrollbar(
        controller: _siteWiseScrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _siteWiseScrollCtrl,
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Container(
              color: const Color(0xFF1E1E26),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Emp ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Worker Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Daily Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Action', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
                rows: state.workers.map((w) {
                  final r = state.allAttendanceRecords.firstWhere(
                    (rec) => rec.workerId == w.id && state.isSameDay(rec.date, state.selectedDate),
                    orElse: () => state.allAttendanceRecords.firstWhere((rec) => rec.workerId == w.id, orElse: () => state.allAttendanceRecords.first),
                  );
                  return DataRow(
                    cells: [
                      DataCell(Text(w.employeeId, style: const TextStyle(color: Colors.white))),
                      DataCell(
                        TextButton(
                          onPressed: () => setState(() => _selectedSiteWiseWorker = w),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                          child: Text(w.name, style: const TextStyle(color: Colors.tealAccent, decoration: TextDecoration.underline, decorationColor: Colors.tealAccent)),
                        ),
                      ),
                      DataCell(Text(r.status, style: const TextStyle(color: Colors.grey))),
                      DataCell(
                        ElevatedButton(
                          onPressed: () => setState(() => _selectedSiteWiseWorker = w),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                          child: const Text('View Details', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
    }

    final w = _selectedSiteWiseWorker!;
    final r = state.allAttendanceRecords.firstWhere(
      (rec) => rec.workerId == w.id && state.isSameDay(rec.date, state.selectedDate),
      orElse: () => state.allAttendanceRecords.first,
    );

    List<Map<String, dynamic>> detailedRows = [];
    detailedRows.add({
      'name': 'SGS Labour Camp',
      'type': 'Accommodation (ACC-001)',
      'entry': '—',
      'exit': '08:30 AM',
      'duration': '—',
      'checklist': 'N/A',
      'instructions': 'N/A',
      'status': 'Exit Recorded',
      'color': Colors.blueAccent,
    });

    for (var visit in r.visits) {
      final site = state.sites.firstWhere((s) => s.id == visit.siteId);
      if (site.isAccommodation) continue;

      String entryStr = visit.entryTime != null ? DateFormat('hh:mm a').format(visit.entryTime!) : '—';
      String exitStr = visit.exitTime != null ? DateFormat('hh:mm a').format(visit.exitTime!) : '—';
      
      String durationStr = '—';
      if (visit.entryTime != null && visit.exitTime != null) {
        final d = visit.exitTime!.difference(visit.entryTime!);
        durationStr = '${d.inHours}h ${d.inMinutes % 60}m';
      }

      detailedRows.add({
        'name': site.name,
        'type': site.jobType.name,
        'entry': entryStr,
        'exit': exitStr,
        'duration': durationStr,
        'checklist': visit.status == 'Completed' ? '✓' : '—',
        'instructions': '✓',
        'status': visit.status,
        'color': Colors.tealAccent,
      });
    }

    bool accReentered = r.visits.any((v) {
      var s = state.sites.firstWhere((site) => site.id == v.siteId, orElse: () => state.sites.first);
      return s.isAccommodation && v.status == 'Entry Recorded';
    });

    detailedRows.add({
      'name': 'SGS Labour Camp',
      'type': 'Accommodation (ACC-001)',
      'entry': accReentered ? '06:10 PM' : '—',
      'exit': '—',
      'duration': '—',
      'checklist': 'N/A',
      'instructions': 'N/A',
      'status': accReentered ? 'Entry Recorded' : 'Pending Return',
      'color': Colors.blueAccent,
    });

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.tealAccent),
                onPressed: () => setState(() => _selectedSiteWiseWorker = null),
              ),
              Expanded(
                child: Text('Site-wise Event Details for Worker: ${w.name} (${w.employeeId})', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Scrollbar(
            controller: _siteWiseScrollCtrl,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _siteWiseScrollCtrl,
              scrollDirection: Axis.horizontal,
              child: Container(
                color: const Color(0xFF1E1E26),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Site Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Type', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Duration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Checklist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Instructions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Visit Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ],
                  rows: detailedRows.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(row['name'], style: TextStyle(color: row['color'], fontWeight: FontWeight.bold))),
                        DataCell(Text(row['type'], style: const TextStyle(color: Colors.grey))),
                        DataCell(Text(row['entry'], style: const TextStyle(color: Colors.white))),
                        DataCell(Text(row['exit'], style: const TextStyle(color: Colors.white))),
                        DataCell(Text(row['duration'], style: const TextStyle(color: Colors.grey))),
                        DataCell(Text(row['checklist'], style: const TextStyle(color: Colors.white))),
                        DataCell(Text(row['instructions'], style: const TextStyle(color: Colors.white))),
                        DataCell(Text(row['status'], style: TextStyle(color: row['color']))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeReport(BuildContext context, TrackerState state) {
    // Shows shift end time vs normal shift, computes overtime multiplier payouts
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Overtime Salary Calculation Engine', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('Formula: Normal 8h | OT1: 1.25x | OT2: 1.50x (Holidays)', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Scrollbar(
            controller: _overtimeScrollCtrl,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _overtimeScrollCtrl,
              scrollDirection: Axis.horizontal,
              child: Container(
                color: const Color(0xFF1E1E26),
                child: DataTable(
              columns: const [
                DataColumn(label: Text('Emp ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Worker Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Shift Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Shift End', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('OT Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('OT Pay Multiplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
              rows: state.attendanceRecords.map((r) {
                final w = state.workers.firstWhere((worker) => worker.id == r.workerId);
                String startStr = r.shiftStart != null ? DateFormat('hh:mm a').format(r.shiftStart!) : '—';
                String endStr = r.shiftEnd != null ? DateFormat('hh:mm a').format(r.shiftEnd!) : '—';
                
                double otHours = r.overtimeHours;
                
                // Determine multiplier: Sunday/holidays gets OT2 (1.50x), normal gets OT1 (1.25x)
                bool isWeekend = state.selectedDate.weekday == DateTime.sunday;
                String multiplier = otHours > 0 ? (isWeekend ? "1.50x (OT2)" : "1.25x (OT1)") : "—";

                return DataRow(
                  cells: [
                    DataCell(Text(w.employeeId, style: const TextStyle(color: Colors.white))),
                    DataCell(Text(w.name, style: const TextStyle(color: Colors.white))),
                    DataCell(Text(startStr, style: const TextStyle(color: Colors.grey))),
                    DataCell(Text(endStr, style: const TextStyle(color: Colors.grey))),
                    DataCell(Text(otHours > 0 ? '${otHours.toStringAsFixed(1)} hrs' : '0.0', style: TextStyle(color: otHours > 0 ? Colors.blueAccent : Colors.grey))),
                    DataCell(Text(multiplier, style: TextStyle(color: otHours > 0 ? Colors.greenAccent : Colors.grey))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildFloatingNotifications(BuildContext context, TrackerState state) {
    final list = state.activeNotifications.where((n) => n.title.contains('Security Alert') || n.title.contains('Tampering')).toList();
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: list.map((n) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning, color: Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.message,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, color: Colors.grey, size: 14),
                onPressed: () {
                  state.markNotificationAsRead(n.id);
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add New Site Dialog — Full Screen with Embedded Geofence Map
// ─────────────────────────────────────────────────────────────────────────────

class _AddSiteDialog extends StatefulWidget {
  final TrackerState state;
  final Site? site;
  const _AddSiteDialog({required this.state, this.site});

  @override
  State<_AddSiteDialog> createState() => _AddSiteDialogState();
}

class _AddSiteDialogState extends State<_AddSiteDialog> {
  // ── Form controllers ────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _startCtrl = TextEditingController(text: '08:00 AM');
  final _endCtrl = TextEditingController(text: '05:00 PM');

  JobCategory _category = JobCategory.AMC;
  SubCategory _subCategory = SubCategory.Outdoor;
  JobType _jobType = JobType.Permanent;
  JobFrequency _frequency = JobFrequency.Daily;
  bool _isAcc = false;

  // ── Geofence drawing state ──────────────────────────────────────────────────
  final MapController _mapController = MapController();
  GeofenceShape _fenceShape = GeofenceShape.circle;
  LatLng? _circleCenter;
  double _circleRadius = 150.0; // meters
  final List<LatLng> _polygonPoints = [];
  String _fenceColor = '#00BFA5';

  // ── Map style & device location ─────────────────────────────────────────────
  MapStyle _mapStyle = MapStyle.satellite;
  LatLng? _deviceLocation;
  bool _isLocating = false;

  bool _isSaving = false;
  bool _isFullscreenMap = false;

  static const List<String> _colorOptions = [
    '#00BFA5', '#FF6D00', '#7C4DFF', '#FF4081', '#00B0FF',
    '#FFD600', '#69F0AE', '#FF5252', '#40C4FF', '#EA80FC',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.site != null) {
      _nameCtrl.text = widget.site!.name;
      _codeCtrl.text = widget.site!.code;
      _addressCtrl.text = widget.site!.address;
      _startCtrl.text = widget.site!.plannedStartTime;
      _endCtrl.text = widget.site!.plannedEndTime;
      _category = widget.site!.category;
      _subCategory = widget.site!.subCategory;
      _jobType = widget.site!.jobType;
      _frequency = widget.site!.frequency;
      _isAcc = widget.site!.isAccommodation;

      // Find geofence center/radius or polygon from backendGeofences
      final fenceIdx = widget.state.backendGeofences.indexWhere((g) => g.siteId == widget.site!.id);
      if (fenceIdx != -1) {
        final fence = widget.state.backendGeofences[fenceIdx];
        _fenceShape = fence.type;
        _fenceColor = fence.color;
        if (fence.type == GeofenceShape.circle) {
          _circleCenter = fence.center;
          _circleRadius = fence.radiusM ?? widget.site!.radius;
        } else if (fence.type == GeofenceShape.polygon && fence.polygon != null) {
          _polygonPoints.addAll(fence.polygon!);
        }
      } else {
        _circleCenter = LatLng(widget.site!.latitude, widget.site!.longitude);
        _circleRadius = widget.site!.radius;
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_circleCenter != null) {
          _mapController.move(_circleCenter!, 15);
        } else if (_polygonPoints.isNotEmpty) {
          _mapController.move(_polygonPoints.first, 15);
        }
      });
    } else {
      _fetchDeviceLocation();
    }
  }

  Future<void> _fetchDeviceLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _deviceLocation = LatLng(pos.latitude, pos.longitude);
          _isLocating = false;
        });
        // Fly map to device location
        _mapController.move(_deviceLocation!, 15);
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _addressCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      if (_fenceShape == GeofenceShape.circle) {
        _circleCenter = point;
      } else {
        _polygonPoints.add(point);
      }
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a site name.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Validate geofence data
    if (_fenceShape == GeofenceShape.circle && _circleCenter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please click on the map to set the geofence center.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }
    if (_fenceShape == GeofenceShape.polygon && _polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A polygon geofence needs at least 3 points.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Determine site lat/lng from geofence
    double siteLat, siteLng, siteRadius;
    if (_fenceShape == GeofenceShape.circle) {
      siteLat = _circleCenter!.latitude;
      siteLng = _circleCenter!.longitude;
      siteRadius = _circleRadius;
    } else {
      // Centroid of polygon
      siteLat = _polygonPoints.map((p) => p.latitude).reduce((a, b) => a + b) / _polygonPoints.length;
      siteLng = _polygonPoints.map((p) => p.longitude).reduce((a, b) => a + b) / _polygonPoints.length;
      siteRadius = 100.0; // default for polygon sites
    }

    final siteId = widget.site?.id ?? 'site_${DateTime.now().millisecondsSinceEpoch}';

    final siteObj = Site(
      id: siteId,
      name: _nameCtrl.text.trim(),
      code: _codeCtrl.text.trim(),
      category: _category,
      subCategory: _subCategory,
      jobType: _jobType,
      frequency: _frequency,
      address: _addressCtrl.text.trim(),
      latitude: siteLat,
      longitude: siteLng,
      radius: siteRadius,
      plannedStartTime: _startCtrl.text,
      plannedEndTime: _endCtrl.text,
      isAccommodation: _isAcc,
    );

    final geofence = AppGeofence(
      id: '',
      name: _nameCtrl.text.trim(),
      siteId: siteId,
      type: _fenceShape,
      center: _fenceShape == GeofenceShape.circle ? _circleCenter : null,
      radiusM: _fenceShape == GeofenceShape.circle ? _circleRadius : null,
      polygon: _fenceShape == GeofenceShape.polygon ? List.from(_polygonPoints) : null,
      color: _fenceColor,
      code: _codeCtrl.text.trim(),
      category: _category.name,
      subCategory: _subCategory.name,
      jobType: _jobType.name,
      frequency: _frequency.name,
      address: _addressCtrl.text.trim(),
      plannedStartTime: _startCtrl.text,
      plannedEndTime: _endCtrl.text,
      isAccommodation: _isAcc,
    );

    // Pre-capture values before async gaps to avoid "unmounted state/context" errors
    final TrackerState localState = widget.state;
    final Site? localSite = widget.site;
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final MapService localMapSvc = context.read<MapService>();

    try {
      if (localSite != null) {
        // Edit mode: save to backend PostgreSQL
        final success = await localState.editSiteInBackend(siteObj, geofence).timeout(const Duration(seconds: 2));
        if (!success) {
          throw Exception("Backend edit returned false");
        }
      } else {
        // Add mode: save to backend PostgreSQL
        final created = await localMapSvc.createGeofence(geofence).timeout(const Duration(seconds: 2));
        if (created == null) {
          throw Exception("Backend create returned null");
        }
        await localState.fetchGeofencesFromBackend().timeout(const Duration(seconds: 2));
      }

      // Refresh MapService geofences (for maps)
      await localMapSvc.fetchGeofences().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[AddSiteDialog] Backend save failed, saving locally: $e');
      localState.saveSiteLocally(siteObj, geofence);

      // Notify user about local fallback
      messenger.showSnackBar(
        const SnackBar(
          content: Text('⚠️ Backend database offline. Saved locally.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }

    // Safely close dialog and notify success
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(localSite != null
            ? '✅ Site "${siteObj.name}" updated successfully!'
            : '✅ Site "${siteObj.name}" and geofence saved successfully!'),
        backgroundColor: const Color(0xFF00BFA5),
      ),
    );
  }

  Widget _buildFooterStatusBadge(bool isMobile) {
    if (_fenceShape == GeofenceShape.circle && _circleCenter != null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: 5),
        decoration: BoxDecoration(
          color: _hexToColor(_fenceColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _hexToColor(_fenceColor).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radio_button_checked, color: _hexToColor(_fenceColor), size: 13),
            if (!isMobile) ...[
              const SizedBox(width: 6),
              Text(
                'Circle • ${_circleRadius.toInt()}m radius',
                style: TextStyle(color: _hexToColor(_fenceColor), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      );
    } else if (_fenceShape == GeofenceShape.polygon && _polygonPoints.isNotEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: 5),
        decoration: BoxDecoration(
          color: _hexToColor(_fenceColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _hexToColor(_fenceColor).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pentagon_outlined, color: _hexToColor(_fenceColor), size: 13),
            if (!isMobile) ...[
              const SizedBox(width: 6),
              Text(
                'Polygon • ${_polygonPoints.length} pts',
                style: TextStyle(color: _hexToColor(_fenceColor), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      );
    } else {
      return Text(
        isMobile ? '⚠️ Empty' : '⚠️  No geofence drawn yet',
        style: const TextStyle(color: Colors.orange, fontSize: 11),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fenceColor = _hexToColor(_fenceColor);
    final isMobile = MediaQuery.of(context).size.width < 700;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Container(
        width: double.infinity,
        height: isMobile
            ? (MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom - 40)
                .clamp(200.0, MediaQuery.of(context).size.height * 0.9)
            : MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2D2D38)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E26),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.site != null ? Icons.edit_location_alt : Icons.add_location_alt, color: const Color(0xFF00BFA5), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.site != null ? 'Edit Worksite' : 'Add New Worksite',
                          style: TextStyle(color: Colors.white, fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.site != null ? 'Modify site details and adjust geofence' : 'Fill site details and mark the geofence on the map',
                          style: TextStyle(color: Colors.grey, fontSize: isMobile ? 10 : 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // ── Body: Left form + Right map (Desktop) or Vertical Stack (Mobile) ──
            Expanded(
              child: _isFullscreenMap
                  ? _buildMapPanel(fenceColor)
                  : isMobile
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: _buildFormPanel(),
                              ),
                              const Divider(color: Color(0xFF2D2D38), height: 1),
                              SizedBox(
                                height: keyboardOpen ? 120 : 280,
                                child: _buildMapPanel(fenceColor),
                              ),
                            ],
                          ),
                        )
                      : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── LEFT: Site Details Form ──────────────────────────────────
                        SizedBox(
                          width: 340,
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: Color(0xFF2D2D38))),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: _buildFormPanel(),
                            ),
                          ),
                        ),

                        // ── RIGHT: Interactive Map ────────────────────────────────────
                        Expanded(
                          child: _buildMapPanel(fenceColor),
                        ),
                      ],
                    ),
            ),

            // ── Footer: Actions ─────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24,
                vertical: (isMobile && keyboardOpen) ? 6 : 14,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E26),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFF2D2D38))),
              ),
              child: isMobile
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!keyboardOpen) ...[
                          Center(
                            child: _buildFooterStatusBadge(isMobile),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSaving ? null : () => Navigator.pop(context),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _save,
                              icon: _isSaving
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                  : const Icon(Icons.save_alt, size: 16),
                              label: Text(_isSaving ? 'Saving...' : 'Save'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BFA5),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _buildFooterStatusBadge(isMobile),
                        const Spacer(),
                        TextButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.save_alt, size: 16),
                          label: Text(_isSaving ? 'Saving...' : 'Save Site & Geofence'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BFA5),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
            ),

          ],
        ),
      ),
    );
  }

  // ── Left Form Panel ──────────────────────────────────────────────────────────
  Widget _buildFormPanel() {
    const labelStyle = TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600);
    const inputStyle = TextStyle(color: Colors.white, fontSize: 13);
    const inputDecor = InputDecoration(
      labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D2D38))),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00BFA5))),
      isDense: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section: Site Info ───────────────────────────────────────────────
        _sectionLabel('SITE INFORMATION'),
        const SizedBox(height: 10),
        TextField(
          controller: _nameCtrl,
          style: inputStyle,
          decoration: inputDecor.copyWith(labelText: 'Site / Job Name *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeCtrl,
          style: inputStyle,
          decoration: inputDecor.copyWith(labelText: 'Job Code'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressCtrl,
          style: inputStyle,
          maxLines: 2,
          decoration: inputDecor.copyWith(labelText: 'Address'),
        ),
        const SizedBox(height: 20),

        // ── Section: Classification ──────────────────────────────────────────
        _sectionLabel('CLASSIFICATION'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildDropdown<JobCategory>('Category', JobCategory.values, _category, (v) => setState(() => _category = v!))),
            const SizedBox(width: 12),
            Expanded(child: _buildDropdown<SubCategory>('Sub', SubCategory.values, _subCategory, (v) => setState(() => _subCategory = v!))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildDropdown<JobType>('Type', JobType.values, _jobType, (v) => setState(() => _jobType = v!))),
            const SizedBox(width: 12),
            Expanded(child: _buildDropdown<JobFrequency>('Frequency', JobFrequency.values, _frequency, (v) => setState(() => _frequency = v!))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startCtrl,
                style: inputStyle,
                decoration: inputDecor.copyWith(labelText: 'Shift Start'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _endCtrl,
                style: inputStyle,
                decoration: inputDecor.copyWith(labelText: 'Shift End'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Accommodation Geofence', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Workers live here overnight', style: TextStyle(color: Colors.grey, fontSize: 10)),
          value: _isAcc,
          activeColor: const Color(0xFF00BFA5),
          onChanged: (v) => setState(() => _isAcc = v),
        ),
        const SizedBox(height: 20),

        // ── Section: Geofence Settings ───────────────────────────────────────
        _sectionLabel('GEOFENCE SETTINGS'),
        const SizedBox(height: 10),

        // Shape selector
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _fenceShape = GeofenceShape.circle;
                  _polygonPoints.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _fenceShape == GeofenceShape.circle
                        ? const Color(0xFF00BFA5).withOpacity(0.15)
                        : const Color(0xFF1E1E26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _fenceShape == GeofenceShape.circle
                          ? const Color(0xFF00BFA5)
                          : const Color(0xFF2D2D38),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.radio_button_checked,
                          color: _fenceShape == GeofenceShape.circle ? const Color(0xFF00BFA5) : Colors.grey,
                          size: 20),
                      const SizedBox(height: 4),
                      Text('Circle', style: TextStyle(
                          color: _fenceShape == GeofenceShape.circle ? const Color(0xFF00BFA5) : Colors.grey,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _fenceShape = GeofenceShape.polygon;
                  _circleCenter = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _fenceShape == GeofenceShape.polygon
                        ? const Color(0xFF00BFA5).withOpacity(0.15)
                        : const Color(0xFF1E1E26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _fenceShape == GeofenceShape.polygon
                          ? const Color(0xFF00BFA5)
                          : const Color(0xFF2D2D38),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.pentagon_outlined,
                          color: _fenceShape == GeofenceShape.polygon ? const Color(0xFF00BFA5) : Colors.grey,
                          size: 20),
                      const SizedBox(height: 4),
                      Text('Polygon', style: TextStyle(
                          color: _fenceShape == GeofenceShape.polygon ? const Color(0xFF00BFA5) : Colors.grey,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Circle radius slider
        if (_fenceShape == GeofenceShape.circle) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Radius', style: labelStyle),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_circleRadius.toInt()} m',
                  style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Slider(
            value: _circleRadius,
            min: 30,
            max: 2000,
            divisions: 197,
            activeColor: const Color(0xFF00BFA5),
            inactiveColor: const Color(0xFF2D2D38),
            onChanged: (v) => setState(() => _circleRadius = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('30m', style: TextStyle(color: Colors.grey, fontSize: 9)),
              Text('2000m', style: TextStyle(color: Colors.grey, fontSize: 9)),
            ],
          ),
        ],

        // Polygon instructions + undo
        if (_fenceShape == GeofenceShape.polygon) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.touch_app, color: Colors.orangeAccent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Click on the map to place boundary points. Minimum 3 points required.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_polygonPoints.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_polygonPoints.length} point(s) placed', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                TextButton.icon(
                  onPressed: () => setState(() => _polygonPoints.removeLast()),
                  icon: const Icon(Icons.undo, size: 14, color: Colors.orangeAccent),
                  label: const Text('Undo', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                ),
              ],
            ),
          if (_polygonPoints.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _polygonPoints.clear()),
              icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
              label: const Text('Clear All Points', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
            ),
        ],
        const SizedBox(height: 16),

        // Color picker
        Text('Fence Colour', style: labelStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colorOptions.map((hex) {
            final selected = hex == _fenceColor;
            return GestureDetector(
              onTap: () => setState(() => _fenceColor = hex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _hexToColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: selected ? 2.5 : 0,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: _hexToColor(hex).withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                      : [],
                ),
                child: selected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF00BFA5),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDropdown<T>(String label, List<T> values, T current, ValueChanged<T?> onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        DropdownButtonFormField<T>(
          value: current,
          dropdownColor: const Color(0xFF1E1E26),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 4),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D2D38))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00BFA5))),
          ),
          onChanged: onChange,
          items: values
              .map((v) => DropdownMenuItem<T>(value: v, child: Text(v.toString().split('.').last)))
              .toList(),
        ),
      ],
    );
  }

  // ── Right Map Panel ──────────────────────────────────────────────────────────
  Widget _buildMapPanel(Color fenceColor) {
    final trackerState = widget.state;

    // Pick tile URL based on selected style
    Widget tileLayer;
    switch (_mapStyle) {
      case MapStyle.light:
        tileLayer = TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.sgs.field_tracker',
          maxNativeZoom: 19,
          maxZoom: 22,
          keepBuffer: 4,
          tileSize: 256,
        );
      case MapStyle.satellite:
        tileLayer = TileLayer(
          urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
          userAgentPackageName: 'com.sgs.field_tracker',
          maxNativeZoom: 21,
          maxZoom: 22,
          keepBuffer: 4,
          tileSize: 256,
        );
      case MapStyle.dark:
      default:
        tileLayer = TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.sgs.field_tracker',
          maxNativeZoom: 19,
          maxZoom: 22,
          keepBuffer: 4,
          tileSize: 256,
        );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(topRight: Radius.circular(20)),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(trackerState.currentLat, trackerState.currentLng),
              initialZoom: 13,
              maxZoom: 22,
              onTap: _onMapTap,
            ),
            children: [
              // Tile layer (switches by style)
              tileLayer,

              // Device location blue dot
              if (_deviceLocation != null)
                CircleLayer(circles: [
                  // Outer glow ring
                  CircleMarker(
                    point: _deviceLocation!,
                    radius: 14,
                    useRadiusInMeter: false,
                    color: const Color(0xFF2196F3).withOpacity(0.2),
                    borderColor: Colors.transparent,
                    borderStrokeWidth: 0,
                  ),
                  // Solid blue dot
                  CircleMarker(
                    point: _deviceLocation!,
                    radius: 7,
                    useRadiusInMeter: false,
                    color: const Color(0xFF2196F3),
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ]),

              // Circle geofence preview
              if (_fenceShape == GeofenceShape.circle && _circleCenter != null)
                CircleLayer(circles: [
                  CircleMarker(
                    point: _circleCenter!,
                    radius: _circleRadius,
                    useRadiusInMeter: true,
                    color: fenceColor.withOpacity(0.12),
                    borderColor: fenceColor,
                    borderStrokeWidth: 2.5,
                  ),
                ]),

              // Polygon preview
              if (_fenceShape == GeofenceShape.polygon && _polygonPoints.length >= 3)
                PolygonLayer(polygons: [
                  Polygon(
                    points: _polygonPoints,
                    color: fenceColor.withOpacity(0.12),
                    borderColor: fenceColor,
                    borderStrokeWidth: 2.5,
                  ),
                ]),

              // Polygon outline (even when < 3 pts, draw a polyline)
              if (_fenceShape == GeofenceShape.polygon && _polygonPoints.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: [..._polygonPoints, _polygonPoints.first],
                    color: fenceColor.withOpacity(0.8),
                    strokeWidth: 2,
                  ),
                ]),

              // Polygon point markers
              if (_fenceShape == GeofenceShape.polygon && _polygonPoints.isNotEmpty)
                MarkerLayer(
                  markers: _polygonPoints.asMap().entries.map((e) {
                    return Marker(
                      point: e.value,
                      width: 26,
                      height: 26,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: fenceColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Circle center pin
              if (_fenceShape == GeofenceShape.circle && _circleCenter != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _circleCenter!,
                    width: 32,
                    height: 32,
                    child: Icon(Icons.location_pin, color: fenceColor, size: 32),
                  ),
                ]),
            ],
          ),

          // ── Top Overlays (Search, Instructions, Styles) ─────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Bar
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2D2D38)),
                  ),
                  child: const TextField(
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search site name or place...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                      prefixIcon: Icon(Icons.search, color: Colors.grey, size: 16),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Controls Wrap
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    // Drawing instruction hint
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _fenceShape == GeofenceShape.circle ? Icons.touch_app : Icons.pentagon_outlined,
                            color: fenceColor,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _fenceShape == GeofenceShape.circle
                                ? 'Tap map to set center'
                                : 'Tap to add points',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    // Map Style Switcher
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2D2D38)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _styleBtn(MapStyle.dark, Icons.dark_mode, 'Dark'),
                          _styleBtn(MapStyle.light, Icons.light_mode, 'Light'),
                          _styleBtn(MapStyle.satellite, Icons.satellite_alt, 'Sat'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Right-side FAB buttons ────────────────────────────────────────────
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Fullscreen toggle
                FloatingActionButton.small(
                  heroTag: 'fullscreen_fab',
                  backgroundColor: const Color(0xFF1E1E26),
                  onPressed: () {
                    setState(() {
                      _isFullscreenMap = !_isFullscreenMap;
                    });
                  },
                  child: Icon(_isFullscreenMap ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 8),
                // Go to device location
                FloatingActionButton.small(
                  heroTag: 'goto_device_loc_fab',
                  backgroundColor: const Color(0xFF1E1E26),
                  onPressed: _isLocating ? null : () {
                    if (_deviceLocation != null) {
                      _mapController.move(_deviceLocation!, 16);
                    } else {
                      _fetchDeviceLocation();
                    }
                  },
                  child: _isLocating
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2196F3)),
                        )
                      : const Icon(Icons.my_location, color: Color(0xFF2196F3), size: 18),
                ),
                const SizedBox(height: 8),
                // Set geofence here (go to current device location and auto-place)
                if (_deviceLocation != null && _fenceShape == GeofenceShape.circle && _circleCenter == null)
                  FloatingActionButton.small(
                    heroTag: 'place_here_fab',
                    backgroundColor: fenceColor.withOpacity(0.9),
                    onPressed: () {
                      setState(() => _circleCenter = _deviceLocation);
                      _mapController.move(_deviceLocation!, 16);
                    },
                    child: const Icon(Icons.add_location_alt, color: Colors.white, size: 18),
                  ),
              ],
            ),
          ),

          // ── Device location label ─────────────────────────────────────────────
          if (_deviceLocation != null)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2196F3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'You: ${_deviceLocation!.latitude.toStringAsFixed(5)}, ${_deviceLocation!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Style toggle button helper
  Widget _styleBtn(MapStyle style, IconData icon, String label) {
    final isActive = _mapStyle == style;
    return GestureDetector(
      onTap: () => setState(() => _mapStyle = style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00BFA5) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? Colors.black : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white70,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
