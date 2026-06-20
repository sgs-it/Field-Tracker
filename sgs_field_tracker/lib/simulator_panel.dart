import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'tracker_state.dart';
import 'models.dart';

class SimulatorPanel extends StatelessWidget {
  const SimulatorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TrackerState>(context);
    final currentWorker = state.currentWorker;
    final timeStr = DateFormat('hh:mm:ss a').format(state.simulatedTime);
    final dateStr = DateFormat('dd-MMM-yyyy').format(state.simulatedTime);

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2F),
        border: Border(left: BorderSide(color: Color(0xFF2D2D44), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF252538),
            child: const Row(
              children: [
                Icon(Icons.developer_board, color: Colors.tealAccent),
                SizedBox(width: 8),
                Text(
                  'INTERACTIVE SIMULATOR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Section: Simulated Time
                _buildSectionTitle('Simulated Environment Clock'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252538),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2D2D44)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 22,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTimeButton(context, '+15m', () => state.progressTimeMinutes(15)),
                          _buildTimeButton(context, '+30m', () => state.progressTimeMinutes(30)),
                          _buildTimeButton(context, '+1h', () => state.progressTimeMinutes(60)),
                          _buildTimeButton(context, '+2h', () => state.progressTimeMinutes(120)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Device Status Simulation
                _buildSectionTitle('Device Settings'),
                const SizedBox(height: 8),
                _buildToggleCard(
                  title: 'GPS Location Services',
                  subtitle: state.isGpsEnabled ? 'Enabled (Normal)' : 'Disabled (Tampered)',
                  value: state.isGpsEnabled,
                  onChanged: (val) => state.toggleGps(val),
                  activeColor: Colors.greenAccent,
                ),
                const SizedBox(height: 8),
                _buildToggleCard(
                  title: 'Mock / Fake Location',
                  subtitle: state.isFakeGpsEnabled ? 'Active (Spoofed)' : 'Inactive (Secure)',
                  value: state.isFakeGpsEnabled,
                  onChanged: (val) => state.toggleFakeGps(val),
                  activeColor: Colors.redAccent,
                ),
                const SizedBox(height: 8),
                _buildToggleCard(
                  title: 'Network / Internet Connection',
                  subtitle: state.isInternetEnabled ? 'Online' : 'Offline Mode (Local Sync)',
                  value: state.isInternetEnabled,
                  onChanged: (val) => state.toggleInternet(val),
                  activeColor: Colors.greenAccent,
                ),
                const SizedBox(height: 24),

                // Section: Morning Alarm Simulator
                _buildSectionTitle('Morning Alarm Engine'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    state.triggerAlarm(true);
                  },
                  icon: const Icon(Icons.alarm_add, color: Colors.white),
                  label: const Text('Simulate 08:00 AM Alarm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Geofence Transitions
                _buildSectionTitle('Geofence Crossings'),
                const SizedBox(height: 8),
                Text(
                  'Testing Worker: ${currentWorker.name} (${currentWorker.employeeId})',
                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),
                
                ...state.allSimulatableSites.map((site) {
                  // Find visit state
                  var att = state.allAttendanceRecords.firstWhere(
                    (r) => r.workerId == currentWorker.id && state.isSameDay(r.date, state.selectedDate),
                    orElse: () => state.allAttendanceRecords.first,
                  );
                  var visit = att.visits.firstWhere(
                    (v) => v.siteId == site.id,
                    orElse: () => VisitRecord(siteId: site.id, status: 'Not Assigned', checklistAtVisit: []),
                  );
                  
                  bool isAtSite = visit.status == 'Entry Recorded';

                  return Card(
                    color: const Color(0xFF252538),
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isAtSite ? Colors.tealAccent.withOpacity(0.5) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  site.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    decoration: site.isAccommodation ? TextDecoration.underline : TextDecoration.none,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: site.isAccommodation ? Colors.blue.withOpacity(0.2) : Colors.teal.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  site.isAccommodation ? 'Accommodation' : 'Work Site',
                                  style: TextStyle(
                                    color: site.isAccommodation ? Colors.blue : Colors.tealAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Status: ${visit.status}',
                                style: TextStyle(
                                  color: visit.status == 'Completed'
                                      ? Colors.greenAccent
                                      : visit.status == 'Entry Recorded'
                                          ? Colors.orangeAccent
                                          : Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: isAtSite
                                      ? null
                                      : () => state.simulateEnterGeofence(currentWorker.id, site.id),
                                  style: TextButton.styleFrom(
                                    backgroundColor: isAtSite ? Colors.transparent : Colors.teal.withOpacity(0.1),
                                    foregroundColor: Colors.tealAccent,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  child: const Text('ENTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton(
                                  onPressed: !isAtSite
                                      ? null
                                      : () => state.simulateExitGeofence(currentWorker.id, site.id),
                                  style: TextButton.styleFrom(
                                    backgroundColor: !isAtSite ? Colors.transparent : Colors.red.withOpacity(0.1),
                                    foregroundColor: Colors.redAccent,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  child: const Text('EXIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildTimeButton(BuildContext context, String text, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D44),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return Card(
      color: const Color(0xFF252538),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF2D2D44)),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
