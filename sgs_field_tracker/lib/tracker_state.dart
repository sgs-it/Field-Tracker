import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'geofence_model.dart';
import 'models.dart';
import 'map_service.dart' show kServerBaseUrl, kWsBaseUrl;

class TrackerState extends ChangeNotifier {
  // Lists holding current application state
  List<Site> _sites = [];
  List<Worker> _workers = [];
  List<Assignment> _assignments = [];
  List<AttendanceRecord> _attendanceRecords = [];
  List<TamperAlert> _tamperAlerts = [];
  List<HeartbeatLog> _heartbeatLogs = [];
  List<AppNotification> _notifications = [];

  // Active user selections
  String _activeRoleId = 'Admin'; // Admin, Engineer, Supervisor, Worker
  String _selectedWorkerId = 'worker_1'; // Active worker context for mobile simulator

  // Simulated device state
  DateTime _simulatedTime = DateTime(2026, 6, 17, 8, 0); // Simulated system clock (Starts at 8:00 AM)
  bool _isGpsEnabled = true;
  bool _isFakeGpsEnabled = false;
  bool _isInternetEnabled = true;
  bool _morningAlarmTriggered = false;
  bool _morningAlarmEnabled = true;
  bool _endShiftAlarmEnabled = true;
  bool _notificationsEnabled = true;
  bool _endShiftAlarmTriggered = false;

  // Live GPS tracking and WebSocket client state
  WebSocketChannel? _workerWsChannel;
  StreamSubscription<Position>? _gpsSubscription;
  bool _isWorkerWsConnected = false;
  Timer? _workerReconnectTimer;
  int _workerReconnectDelay = 2; // seconds

  double _currentLat = 25.1234;
  double _currentLng = 55.3456;
  double _currentAccuracy = 10.0;
  bool _hasRealLocation = false;
  final List<Map<String, dynamic>> _offlineLocationsBuffer = [];

  final Set<String> _insideGeofenceIds = {};
  List<AppGeofence> _backendGeofences = [];
  String? _activeNotificationBanner;
  String? get activeNotificationBanner => _activeNotificationBanner;

  // Local storage for offline synchronization
  final List<VisitRecord> _offlineVisits = [];
  final List<HeartbeatLog> _offlineHeartbeats = [];
  final List<TamperAlert> _offlineAlerts = [];

  // Shift settings
  String _companyShiftStart = "06:00 AM";
  int _companyShiftHours = 8;
  int _companyBreakMinutes = 60;
  int _gracePeriodMinutes = 15;
  String _lateMarkTime = "09:15 AM";

  // Selected date for scheduler / reports view
  DateTime _selectedDate = DateTime(2026, 6, 17);

  // Getters
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  double get currentAccuracy => _currentAccuracy;
  bool get hasRealLocation => _hasRealLocation;
  bool get isWorkerWsConnected => _isWorkerWsConnected;
  List<Site> get sites => _sites;
  List<Worker> get workers => _workers;
  List<Assignment> get assignments => _assignments.where((a) => isSameDay(a.date, _selectedDate)).toList();
  List<Assignment> get allAssignments => _assignments;
  List<AttendanceRecord> get attendanceRecords => _attendanceRecords.where((r) => isSameDay(r.date, _selectedDate)).toList();
  List<AttendanceRecord> get allAttendanceRecords => _attendanceRecords;
  List<TamperAlert> get tamperAlerts => _tamperAlerts;
  List<HeartbeatLog> get heartbeatLogs => _heartbeatLogs;
  String get activeRoleId => _activeRoleId;
  String get selectedWorkerId => _selectedWorkerId;
  DateTime get simulatedTime => _simulatedTime;
  bool get isGpsEnabled => _isGpsEnabled;
  bool get isFakeGpsEnabled => _isFakeGpsEnabled;
  bool get isInternetEnabled => _isInternetEnabled;
  bool get morningAlarmTriggered => _morningAlarmTriggered;
  bool get morningAlarmEnabled => _morningAlarmEnabled;
  bool get endShiftAlarmEnabled => _endShiftAlarmEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get endShiftAlarmTriggered => _endShiftAlarmTriggered;
  DateTime get selectedDate => _selectedDate;

  List<AppNotification> get allNotifications => _notifications;

  List<AppNotification> get activeNotifications {
    if (_activeRoleId == 'Worker') {
      return _notifications
          .where((n) => !n.isRead && n.targetRole == 'Worker' && (n.targetWorkerId == null || n.targetWorkerId == _selectedWorkerId))
          .toList();
    } else if (_activeRoleId == 'Admin' || _activeRoleId == 'Supervisor') {
      return _notifications
          .where((n) => !n.isRead && (n.targetRole == 'Admin' || n.targetRole == 'Supervisor'))
          .toList();
    }
    return [];
  }

  String get companyShiftStart => _companyShiftStart;
  int get companyShiftHours => _companyShiftHours;
  int get companyBreakMinutes => _companyBreakMinutes;
  int get gracePeriodMinutes => _gracePeriodMinutes;
  String get lateMarkTime => _lateMarkTime;

  Worker get currentWorker {
    if (_workers.isEmpty) {
      return Worker(
        id: 'no_workers',
        employeeId: 'EMP000',
        name: 'No Workers Added',
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
      );
    }
    return _workers.firstWhere((w) => w.id == _selectedWorkerId, orElse: () => _workers.first);
  }

  List<AppGeofence> get backendGeofences => _backendGeofences;

  List<Site> get allSimulatableSites {
    final list = List<Site>.from(_sites);
    for (final fence in _backendGeofences) {
      if (!list.any((s) => s.id == fence.id)) {
        list.add(Site(
          id: fence.id,
          name: fence.name,
          code: fence.name.substring(0, min(5, fence.name.length)).toUpperCase(),
          category: JobCategory.AMC,
          subCategory: SubCategory.Outdoor,
          jobType: JobType.Permanent,
          frequency: JobFrequency.Daily,
          address: '',
          latitude: fence.center?.latitude ??
              (fence.polygon != null && fence.polygon!.isNotEmpty
                  ? (fence.polygon!.map((p) => p.latitude).reduce((a, b) => a + b) / fence.polygon!.length)
                  : 25.1234),
          longitude: fence.center?.longitude ??
              (fence.polygon != null && fence.polygon!.isNotEmpty
                  ? (fence.polygon!.map((p) => p.longitude).reduce((a, b) => a + b) / fence.polygon!.length)
                  : 55.3456),
          radius: fence.radiusM ?? 100.0,
          plannedStartTime: '08:00 AM',
          plannedEndTime: '05:00 PM',
        ));
      }
    }
    return list;
  }

  Timer? _geofencePollTimer;

  TrackerState() {
    _init();
  }

  Future<void> _init() async {
    await _loadSettingsFromStorage();
    await _loadWorkersFromStorage();
    await _loadSitesFromStorage();
    await _loadGeofencesFromStorage();
    await _loadAssignmentsFromStorage();
    await _loadAttendanceRecordsFromStorage();
    await _loadTamperAlertsFromStorage();
    await _loadHeartbeatLogsFromStorage();
    await _loadNotificationsFromStorage();
    _seedInitialData();
    _initializeCurrentLocation();
    _geofencePollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchGeofencesFromBackend();
    });
    notifyListeners();
  }

  Future<void> _saveSettingsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sgs_morning_alarm_enabled', _morningAlarmEnabled);
      await prefs.setBool('sgs_end_shift_alarm_enabled', _endShiftAlarmEnabled);
      await prefs.setBool('sgs_notifications_enabled', _notificationsEnabled);
    } catch (e) {
      debugPrint('Error saving settings to storage: $e');
    }
  }

  Future<void> _loadSettingsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _morningAlarmEnabled = prefs.getBool('sgs_morning_alarm_enabled') ?? true;
      _endShiftAlarmEnabled = prefs.getBool('sgs_end_shift_alarm_enabled') ?? true;
      _notificationsEnabled = prefs.getBool('sgs_notifications_enabled') ?? true;
    } catch (e) {
      debugPrint('Error loading settings from storage: $e');
    }
  }

  Future<void> _loadWorkersFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('sgs_field_tracker_workers');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _workers = list.map((e) => Worker.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _workers = [];
      }
    } catch (e) {
      debugPrint('Error loading workers from local storage: $e');
      _workers = [];
    }
    if (_workers.isNotEmpty) {
      _selectedWorkerId = _workers.first.id;
    } else {
      _selectedWorkerId = 'no_workers';
    }
  }

  Future<void> _loadSitesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('sgs_field_tracker_sites');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _sites = list.map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sites from local storage: $e');
    }
  }

  Future<void> _saveSitesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_sites.map((e) => e.toJson()).toList());
      await prefs.setString('sgs_field_tracker_sites', jsonStr);
    } catch (e) {
      debugPrint('Error saving sites to local storage: $e');
    }
  }

  Future<void> _saveWorkersToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_workers.map((w) => w.toJson()).toList());
      await prefs.setString('sgs_field_tracker_workers', jsonStr);
    } catch (e) {
      debugPrint('Error saving workers to local storage: $e');
    }
  }

  Future<void> _saveAssignmentsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_assignments.map((a) => a.toJson()).toList());
      await prefs.setString('sgs_field_tracker_assignments', jsonStr);
    } catch (e) {
      debugPrint('Error saving assignments to local storage: $e');
    }
  }

  Future<void> _loadAssignmentsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('sgs_field_tracker_assignments');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _assignments = list.map((e) => Assignment.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _assignments = [];
      }
    } catch (e) {
      debugPrint('Error loading assignments: $e');
      _assignments = [];
    }
  }

  Future<void> _saveAttendanceRecordsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_attendanceRecords.map((r) => r.toJson()).toList());
      await prefs.setString('sgs_field_tracker_attendance', jsonStr);
    } catch (e) {
      debugPrint('Error saving attendance: $e');
    }
  }

  Future<void> _loadAttendanceRecordsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('sgs_field_tracker_attendance');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _attendanceRecords = list.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _attendanceRecords = [];
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      _attendanceRecords = [];
    }
  }

  Future<void> _saveTamperAlertsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_tamperAlerts.map((a) => a.toJson()).toList());
      await prefs.setString('sgs_field_tracker_tamper_alerts', jsonStr);
    } catch (e) {
      debugPrint('Error saving tamper alerts: $e');
    }
  }

  Future<void> _loadTamperAlertsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('sgs_field_tracker_tamper_alerts');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _tamperAlerts = list.map((e) => TamperAlert.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _tamperAlerts = [];
      }
    } catch (e) {
      debugPrint('Error loading tamper alerts: $e');
      _tamperAlerts = [];
    }
  }

  Future<void> _saveHeartbeatLogsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_heartbeatLogs.map((l) => l.toJson()).toList());
      await prefs.setString('sgs_field_tracker_heartbeat_logs', jsonStr);
    } catch (e) {
      debugPrint('Error saving heartbeat logs: $e');
    }
  }

  Future<void> _loadHeartbeatLogsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('sgs_field_tracker_heartbeat_logs');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _heartbeatLogs = list.map((e) => HeartbeatLog.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _heartbeatLogs = [];
      }
    } catch (e) {
      debugPrint('Error loading heartbeat logs: $e');
      _heartbeatLogs = [];
    }
  }

  Future<void> _saveGeofencesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_backendGeofences.map((g) => g.toJson()).toList());
      await prefs.setString('sgs_field_tracker_geofences', jsonStr);
    } catch (e) {
      debugPrint('Error saving geofences: $e');
    }
  }

  Future<void> _loadGeofencesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('sgs_field_tracker_geofences');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _backendGeofences = list.map((e) => AppGeofence.fromJson(e as Map<String, dynamic>)).toList();
        
        final List<Site> loadedSites = [];
        for (final fence in _backendGeofences) {
          final siteId = fence.siteId ?? fence.id;
          final double lat = fence.center?.latitude ??
              (fence.polygon != null && fence.polygon!.isNotEmpty
                  ? (fence.polygon!.map((p) => p.latitude).reduce((a, b) => a + b) / fence.polygon!.length)
                  : 25.1234);
          final double lng = fence.center?.longitude ??
              (fence.polygon != null && fence.polygon!.isNotEmpty
                  ? (fence.polygon!.map((p) => p.longitude).reduce((a, b) => a + b) / fence.polygon!.length)
                  : 55.3456);
          final double radius = fence.radiusM ?? 100.0;
          
          final cat = JobCategory.values.firstWhere(
            (e) => e.name == fence.category || e.toString().split('.').last == fence.category,
            orElse: () => JobCategory.AMC,
          );
          final subCat = SubCategory.values.firstWhere(
            (e) => e.name == fence.subCategory || e.toString().split('.').last == fence.subCategory,
            orElse: () => SubCategory.Outdoor,
          );
          final jobT = JobType.values.firstWhere(
            (e) => e.name == fence.jobType || e.toString().split('.').last == fence.jobType,
            orElse: () => JobType.Permanent,
          );
          final freq = JobFrequency.values.firstWhere(
            (e) => e.name == fence.frequency || e.toString().split('.').last == fence.frequency,
            orElse: () => JobFrequency.Daily,
          );

          loadedSites.add(Site(
            id: siteId,
            name: fence.name,
            code: fence.code.isNotEmpty ? fence.code : fence.name.substring(0, min(5, fence.name.length)).toUpperCase(),
            category: cat,
            subCategory: subCat,
            jobType: jobT,
            frequency: freq,
            address: fence.address,
            latitude: lat,
            longitude: lng,
            radius: radius,
            plannedStartTime: fence.plannedStartTime.isNotEmpty ? fence.plannedStartTime : '08:00 AM',
            plannedEndTime: fence.plannedEndTime.isNotEmpty ? fence.plannedEndTime : '05:00 PM',
            isAccommodation: fence.isAccommodation,
          ));
        }
        if (loadedSites.isNotEmpty) {
          _sites = loadedSites;
        }
      }
    } catch (e) {
      debugPrint('Error loading geofences: $e');
    }
  }

  Future<void> _saveNotificationsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString('sgs_field_tracker_notifications', jsonStr);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  Future<void> _loadNotificationsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('sgs_field_tracker_notifications');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _notifications = list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _notifications = [];
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _notifications = [];
    }
  }

  void addNotification({
    required String title,
    required String message,
    required String targetRole,
    String? targetWorkerId,
  }) {
    final notification = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}',
      title: title,
      message: message,
      targetRole: targetRole,
      targetWorkerId: targetWorkerId,
      timestamp: _simulatedTime,
    );
    _notifications.add(notification);
    _saveNotificationsToStorage();
    notifyListeners();
  }

  void markNotificationAsRead(String id) {
    int index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      _saveNotificationsToStorage();
      notifyListeners();
    }
  }

  void clearAllNotifications() {
    _notifications.clear();
    _saveNotificationsToStorage();
    notifyListeners();
  }

  void toggleMorningAlarmEnabled(bool val) {
    _morningAlarmEnabled = val;
    _saveSettingsToStorage();
    notifyListeners();
  }

  void toggleEndShiftAlarmEnabled(bool val) {
    _endShiftAlarmEnabled = val;
    _saveSettingsToStorage();
    notifyListeners();
  }

  void toggleNotificationsEnabled(bool val) {
    _notificationsEnabled = val;
    _saveSettingsToStorage();
    notifyListeners();
  }

  void triggerEndShiftAlarm(bool value) {
    _endShiftAlarmTriggered = value;
    notifyListeners();
  }

  void _seedInitialData() {
    if (_sites.isNotEmpty) return;
    // 1. Seed Sites (including accommodation)
    _sites = [];

    DateTime today = DateTime(2026, 6, 17);
    _assignments = [];

    // 4. Initialize Attendance Records for Today
    for (var worker in _workers) {
      // Find assignments for this worker
      var workerAssigns = _assignments.where((a) => a.workerId == worker.id && isSameDay(a.date, today)).toList();
      
      List<VisitRecord> visits = [];
      for (var wa in workerAssigns) {
        visits.add(VisitRecord(
          siteId: wa.siteId,
          status: 'Pending',
          checklistAtVisit: wa.checklist.map((c) => c.copy()).toList(),
        ));
      }

      _attendanceRecords.add(AttendanceRecord(
        id: 'att_${worker.id}_${DateFormat('yyyyMMdd').format(today)}',
        workerId: worker.id,
        date: today,
        visits: visits,
        status: visits.isEmpty ? 'Present' : 'Absent', // default absent if has visits
      ));
    }
  }

  // Setters & Actions
  void setActiveRole(String roleId) {
    _activeRoleId = roleId;
    notifyListeners();
  }

  void setSelectedWorker(String workerId) {
    _closeWorkerWs();
    _stopGpsTracking();

    _selectedWorkerId = workerId;

    var att = _getCurrentAttendanceRecord(workerId);
    if (att != null && att.shiftStart != null && att.shiftEnd == null) {
      _connectWorkerWs();
      _startGpsTracking();
    }
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void updateShiftSettings({
    required String shiftStart,
    required int shiftHours,
    required int breakMinutes,
    required int graceMinutes,
    required String lateMark,
  }) {
    _companyShiftStart = shiftStart;
    _companyShiftHours = shiftHours;
    _companyBreakMinutes = breakMinutes;
    _gracePeriodMinutes = graceMinutes;
    _lateMarkTime = lateMark;
    notifyListeners();
  }

  // Device configuration settings
  void toggleGps(bool enabled) {
    _isGpsEnabled = enabled;
    if (!enabled) {
      triggerTamperAlert(currentWorker.id, 'GPS Disabled During Shift', 'Worker disabled GPS location services.');
      _stopGpsTracking();
    } else {
      final att = _getCurrentAttendanceRecord(currentWorker.id);
      if (att != null && att.shiftStart != null && att.shiftEnd == null) {
        _startGpsTracking();
      }
    }
    notifyListeners();
  }

  void toggleFakeGps(bool enabled) {
    _isFakeGpsEnabled = enabled;
    if (enabled) {
      triggerTamperAlert(currentWorker.id, 'Fake Location', 'Mock location coordinates detected on the device.');
    }
    notifyListeners();
  }

  void toggleInternet(bool enabled) {
    _isInternetEnabled = enabled;
    if (!enabled) {
      triggerTamperAlert(currentWorker.id, 'Internet Off', 'Worker disconnected from internet.');
      _closeWorkerWs();
    } else {
      // Re-connected! Sync offline queues
      _syncOfflineQueue();
      final att = _getCurrentAttendanceRecord(currentWorker.id);
      if (att != null && att.shiftStart != null && att.shiftEnd == null) {
        _connectWorkerWs();
      }
    }
    notifyListeners();
  }

  void triggerAlarm(bool value) {
    _morningAlarmTriggered = value;
    if (value) {
      // Alarm forces GPS on
      _isGpsEnabled = true;
    }
    notifyListeners();
  }

  // Simulated Time Progression
  void setSimulatedTime(DateTime time) {
    _simulatedTime = time;
    
    // Check if alarm should be triggered
    // Morning alarm triggers 30 mins before accommodation departure (planned exit from ACC-001 is 08:30 AM in initial setup, so alarm at 08:00 AM)
    if (_simulatedTime.hour == 8 && _simulatedTime.minute == 0 && !_morningAlarmTriggered && _morningAlarmEnabled) {
      _morningAlarmTriggered = true;
    }
    
    // Automatically generate background Heartbeat logs every 30 mins if shift is active
    var att = _getCurrentAttendanceRecord(currentWorker.id);
    if (att != null && att.shiftStart != null && att.shiftEnd == null) {
      if (_simulatedTime.minute == 0 || _simulatedTime.minute == 30) {
        logHeartbeat(currentWorker.id, 25.2048, 55.2708);
      }

      // End shift alarm triggers when work duration reaches or exceeds company shift hours
      final workDuration = _simulatedTime.difference(att.shiftStart!);
      if (workDuration.inHours >= _companyShiftHours && !_endShiftAlarmTriggered && _endShiftAlarmEnabled) {
        _endShiftAlarmTriggered = true;
      }
    }

    notifyListeners();
  }

  void progressTimeMinutes(int minutes) {
    setSimulatedTime(_simulatedTime.add(Duration(minutes: minutes)));
  }

  // Business Logic - Shift Operations
  void startShift(String workerId) {
    var att = _getOrCreateAttendanceRecord(workerId, _simulatedTime);
    if (att.shiftStart == null) {
      att.shiftStart = _simulatedTime;
      att.status = 'Pending';
      _recalculateAttendanceStatus(att);
      _connectWorkerWs();
      _startGpsTracking();
      notifyListeners();
    }
  }

  void endShift(String workerId) {
    var att = _getCurrentAttendanceRecord(workerId);
    if (att != null && att.shiftStart != null && att.shiftEnd == null) {
      att.shiftEnd = _simulatedTime;
      
      // Calculate work duration
      Duration duration = att.shiftEnd!.difference(att.shiftStart!);
      double totalHours = duration.inMinutes / 60.0;
      
      // Subtract standard break time (60 mins)
      double breakHours = _companyBreakMinutes / 60.0;
      double normalLimit = _companyShiftHours.toDouble();
      
      double calculatedWorkHours = totalHours - breakHours;
      if (calculatedWorkHours < 0) calculatedWorkHours = 0;
      
      att.normalHours = calculatedWorkHours > normalLimit ? normalLimit : calculatedWorkHours;
      
      // Overtime calculation
      if (calculatedWorkHours > normalLimit) {
        att.overtimeHours = calculatedWorkHours - normalLimit;
      } else {
        att.overtimeHours = 0.0;
      }

      _recalculateAttendanceStatus(att);
      _closeWorkerWs();
      _stopGpsTracking();
      notifyListeners();
    }
  }

  // Site Management CRUD
  void addSite(Site site) {
    _sites.add(site);
    _saveSitesToStorage();
    _saveGeofencesToStorage();
    addNotification(
      title: 'New Site Registered',
      message: 'A new site has been added: ${site.name} (${site.code}) at ${site.address}.',
      targetRole: 'Worker',
    );
    notifyListeners();
  }

  void editSite(Site updatedSite) {
    int index = _sites.indexWhere((s) => s.id == updatedSite.id);
    if (index != -1) {
      _sites[index] = updatedSite;
      _saveSitesToStorage();
      _saveGeofencesToStorage();
      notifyListeners();
    }
  }

  Future<bool> editSiteInBackend(Site updatedSite, AppGeofence updatedGeofence) async {
    final idx = _backendGeofences.indexWhere((g) => g.siteId == updatedSite.id);
    if (idx != -1) {
      final fenceId = _backendGeofences[idx].id;
      final geofenceToPost = updatedGeofence.copyWith(id: fenceId);
      try {
        final res = await http.put(
          Uri.parse('$kServerBaseUrl/api/geofences/$fenceId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(geofenceToPost.toJson()),
        ).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          _backendGeofences[idx] = geofenceToPost;
          _saveGeofencesToStorage();
          
          int index = _sites.indexWhere((s) => s.id == updatedSite.id);
          if (index != -1) {
            _sites[index] = updatedSite;
            _saveSitesToStorage();
            notifyListeners();
          }
          return true;
        }
      } catch (e) {
        debugPrint('[TrackerState] Edit site error: $e');
      }
    }
    return false;
  }

  void saveSiteLocally(Site site, AppGeofence geofence) {
    // 1. Update/Add in _sites
    final siteIdx = _sites.indexWhere((s) => s.id == site.id);
    if (siteIdx != -1) {
      _sites[siteIdx] = site;
    } else {
      _sites.add(site);
    }

    // 2. Update/Add in _backendGeofences
    final fenceIdx = _backendGeofences.indexWhere((g) => g.siteId == site.id || (g.id.isNotEmpty && g.id == geofence.id));
    final finalGeofence = geofence.copyWith(
      id: geofence.id.isEmpty ? site.id : geofence.id,
      siteId: site.id,
    );
    if (fenceIdx != -1) {
      _backendGeofences[fenceIdx] = finalGeofence;
    } else {
      _backendGeofences.add(finalGeofence);
    }

    // 3. Save to local storage
    _saveSitesToStorage();
    _saveGeofencesToStorage();
    notifyListeners();
  }

  Future<void> deleteSite(String siteId) async {
    final idx = _backendGeofences.indexWhere((g) => g.siteId == siteId);
    if (idx != -1) {
      final fenceId = _backendGeofences[idx].id;
      try {
        final res = await http.delete(Uri.parse('$kServerBaseUrl/api/geofences/$fenceId'));
        if (res.statusCode == 200) {
          _backendGeofences.removeAt(idx);
          _saveGeofencesToStorage();
        }
      } catch (e) {
        debugPrint('[TrackerState] Delete site error: $e');
      }
    }
    
    _sites.removeWhere((s) => s.id == siteId);
    _saveSitesToStorage();
    notifyListeners();
  }

  // Worker Management CRUD
  void addWorker(Worker worker) {
    _workers.add(worker);
    _saveWorkersToStorage();
    if (_selectedWorkerId == 'no_workers') {
      _selectedWorkerId = worker.id;
    }
    // Initialize empty attendance record for today
    _attendanceRecords.add(AttendanceRecord(
      id: 'att_${worker.id}_${DateFormat('yyyyMMdd').format(_selectedDate)}',
      workerId: worker.id,
      date: _selectedDate,
      visits: [],
      status: 'Present', // present if no assigned sites
    ));
    addNotification(
      title: 'Welcome to SGS Field Tracker',
      message: 'Hello ${worker.name}, your account is active.',
      targetRole: 'Worker',
      targetWorkerId: worker.id,
    );
    notifyListeners();
  }

  void editWorker(Worker updatedWorker) {
    int index = _workers.indexWhere((w) => w.id == updatedWorker.id);
    if (index != -1) {
      _workers[index] = updatedWorker;
      _saveWorkersToStorage();
      addNotification(
        title: 'Profile Updated',
        message: 'Your profile has been updated by the admin.',
        targetRole: 'Worker',
        targetWorkerId: updatedWorker.id,
      );
      notifyListeners();
    }
  }

  void deleteWorker(String workerId) {
    _workers.removeWhere((w) => w.id == workerId);
    _saveWorkersToStorage();
    if (_selectedWorkerId == workerId) {
      _selectedWorkerId = _workers.isNotEmpty ? _workers.first.id : 'no_workers';
    }
    notifyListeners();
  }

  // Scheduling Grid
  void assignSiteToWorker({
    required String workerId,
    required String siteId,
    required DateTime date,
    required String instructions,
    required List<ChecklistItem> checklist,
    required String priority,
    required String breakTime,
  }) {
    // Check if assignment already exists
    int existingIndex = _assignments.indexWhere(
        (a) => a.workerId == workerId && a.siteId == siteId && isSameDay(a.date, date));

    if (existingIndex != -1) {
      _assignments[existingIndex] = Assignment(
        id: _assignments[existingIndex].id,
        workerId: workerId,
        siteId: siteId,
        date: date,
        shift: 'Morning Shift',
        instructions: instructions,
        checklist: checklist,
        priority: priority,
        breakTime: breakTime,
      );
    } else {
      _assignments.add(Assignment(
        id: 'assign_${DateTime.now().millisecondsSinceEpoch}',
        workerId: workerId,
        siteId: siteId,
        date: date,
        shift: 'Morning Shift',
        instructions: instructions,
        checklist: checklist,
        priority: priority,
        breakTime: breakTime,
      ));
    }

    // Update attendance record visits list for this worker & date
    var att = _getOrCreateAttendanceRecord(workerId, date);
    int visitIndex = att.visits.indexWhere((v) => v.siteId == siteId);
    if (visitIndex == -1) {
      att.visits.add(VisitRecord(
        siteId: siteId,
        status: 'Pending',
        checklistAtVisit: checklist.map((c) {
          final copy = c.copy();
          copy.isCompleted = false;
          return copy;
        }).toList(),
      ));
    } else {
      // update checklist
      att.visits[visitIndex] = VisitRecord(
        siteId: siteId,
        status: att.visits[visitIndex].status,
        checklistAtVisit: checklist.map((c) {
          final copy = c.copy();
          copy.isCompleted = false;
          return copy;
        }).toList(),
        entryTime: att.visits[visitIndex].entryTime,
        exitTime: att.visits[visitIndex].exitTime,
        photoPath: att.visits[visitIndex].photoPath,
        comments: att.visits[visitIndex].comments,
      );
    }

    _recalculateAttendanceStatus(att);
    _saveAssignmentsToStorage();
    _saveAttendanceRecordsToStorage();

    String siteName = siteId;
    try {
      final s = _sites.firstWhere((x) => x.id == siteId);
      siteName = s.name;
    } catch (_) {
      try {
        final f = _backendGeofences.firstWhere((x) => x.id == siteId);
        siteName = f.name;
      } catch (_) {}
    }

    addNotification(
      title: 'New Site Assigned',
      message: 'You have been assigned to site: $siteName. Shift: Morning Shift. Instructions: $instructions',
      targetRole: 'Worker',
      targetWorkerId: workerId,
    );

    notifyListeners();
  }

  void removeAssignment(String assignmentId) {
    int assignIndex = _assignments.indexWhere((a) => a.id == assignmentId);
    if (assignIndex != -1) {
      var assign = _assignments[assignIndex];
      _assignments.removeAt(assignIndex);

      // Remove visit from attendance record
      var att = _getCurrentAttendanceRecord(assign.workerId);
      if (att != null) {
        att.visits.removeWhere((v) => v.siteId == assign.siteId);
        _recalculateAttendanceStatus(att);
      }
      
      _saveAssignmentsToStorage();
      _saveAttendanceRecordsToStorage();

      String siteName = assign.siteId;
      try {
        final s = _sites.firstWhere((x) => x.id == assign.siteId);
        siteName = s.name;
      } catch (_) {}

      addNotification(
        title: 'Assignment Removed',
        message: 'Your assignment for site: $siteName has been removed.',
        targetRole: 'Worker',
        targetWorkerId: assign.workerId,
      );

      notifyListeners();
    }
  }

  // Checklist Actions (Worker Side)
  void toggleChecklistItem(String workerId, String siteId, String itemId) {
    var att = _getCurrentAttendanceRecord(workerId);
    if (att != null) {
      var visit = att.visits.firstWhere((v) => v.siteId == siteId);
      var item = visit.checklistAtVisit.firstWhere((i) => i.id == itemId);
      item.isCompleted = !item.isCompleted;
      notifyListeners();
    }
  }

  void submitVisitDetails(String workerId, String siteId, {String? comments, String? photoPath}) {
    var att = _getCurrentAttendanceRecord(workerId);
    if (att != null) {
      var visit = att.visits.firstWhere((v) => v.siteId == siteId);
      visit.comments = comments;
      visit.photoPath = photoPath;
      notifyListeners();
    }
  }

  // Geofence Simulators
  void simulateEnterGeofence(String workerId, String siteId) {
    if (!_isGpsEnabled) return;
    _insideGeofenceIds.add(siteId);

    var site = _sites.firstWhere((s) => s.id == siteId, orElse: () {
      // Look in backend geofences
      final fence = _backendGeofences.firstWhere((g) => g.id == siteId);
      return Site(
        id: fence.id,
        name: fence.name,
        code: fence.name.substring(0, min(5, fence.name.length)).toUpperCase(),
        category: JobCategory.AMC,
        subCategory: SubCategory.Outdoor,
        jobType: JobType.Permanent,
        frequency: JobFrequency.Daily,
        address: '',
        latitude: fence.center?.latitude ??
            (fence.polygon != null && fence.polygon!.isNotEmpty
                ? (fence.polygon!.map((p) => p.latitude).reduce((a, b) => a + b) / fence.polygon!.length)
                : 25.1234),
        longitude: fence.center?.longitude ??
            (fence.polygon != null && fence.polygon!.isNotEmpty
                ? (fence.polygon!.map((p) => p.longitude).reduce((a, b) => a + b) / fence.polygon!.length)
                : 55.3456),
        radius: fence.radiusM ?? 100.0,
        plannedStartTime: '08:00 AM',
        plannedEndTime: '05:00 PM',
      );
    });
    
    // Auto-start shift if entering first work geofence and shift not started
    if (!site.isAccommodation) {
      startShift(workerId);
    }

    var att = _getOrCreateAttendanceRecord(workerId, _simulatedTime);

    if (site.isAccommodation) {
      // Morning Exit vs Evening Entry logic
      // Accommodation entry
      var visit = att.visits.firstWhere((v) => v.siteId == siteId, orElse: () {
        var nv = VisitRecord(
          siteId: siteId,
          status: 'Entry Recorded',
          entryTime: _simulatedTime,
          checklistAtVisit: [],
        );
        att.visits.add(nv);
        return nv;
      });
      visit.entryTime = _simulatedTime;
      visit.status = 'Entry Recorded';
    } else {
      // Work site entry
      var visit = att.visits.firstWhere((v) => v.siteId == siteId, orElse: () {
        var nv = VisitRecord(
          siteId: siteId,
          status: 'Pending',
          checklistAtVisit: [],
        );
        att.visits.add(nv);
        return nv;
      });
      
      visit.entryTime = _simulatedTime;
      visit.status = 'Entry Recorded';
    }

    if (!_isInternetEnabled) {
      var activeVisit = att.visits.firstWhere((v) => v.siteId == siteId);
      _offlineVisits.add(activeVisit.copy());
    }

    _currentLat = site.latitude;
    _currentLng = site.longitude;
    _currentAccuracy = 10.0;
    _sendHeartbeatToBackend(site.latitude, site.longitude, 10.0);

    notifyListeners();
  }

  void simulateExitGeofence(String workerId, String siteId) {
    if (!_isGpsEnabled) return;
    _insideGeofenceIds.remove(siteId);

    var site = _sites.firstWhere((s) => s.id == siteId, orElse: () {
      final fence = _backendGeofences.firstWhere((g) => g.id == siteId);
      return Site(
        id: fence.id,
        name: fence.name,
        code: fence.name.substring(0, min(5, fence.name.length)).toUpperCase(),
        category: JobCategory.AMC,
        subCategory: SubCategory.Outdoor,
        jobType: JobType.Permanent,
        frequency: JobFrequency.Daily,
        address: '',
        latitude: fence.center?.latitude ??
            (fence.polygon != null && fence.polygon!.isNotEmpty
                ? (fence.polygon!.map((p) => p.latitude).reduce((a, b) => a + b) / fence.polygon!.length)
                : 25.1234),
        longitude: fence.center?.longitude ??
            (fence.polygon != null && fence.polygon!.isNotEmpty
                ? (fence.polygon!.map((p) => p.longitude).reduce((a, b) => a + b) / fence.polygon!.length)
                : 55.3456),
        radius: fence.radiusM ?? 100.0,
        plannedStartTime: '08:00 AM',
        plannedEndTime: '05:00 PM',
      );
    });
    var att = _getCurrentAttendanceRecord(workerId);

    if (att != null) {
      var visit = att.visits.firstWhere((v) => v.siteId == siteId);
      visit.exitTime = _simulatedTime;
      
      if (site.isAccommodation) {
        visit.status = 'Exit Recorded';
      } else {
        visit.status = 'Completed';
      }

      if (!_isInternetEnabled) {
        _offlineVisits.add(visit.copy());
      }

      _currentLat = site.latitude + 0.003;
      _currentLng = site.longitude + 0.003;
      _currentAccuracy = 10.0;
      _sendHeartbeatToBackend(_currentLat, _currentLng, _currentAccuracy);

      _recalculateAttendanceStatus(att);
      notifyListeners();
    }
  }

  // Pending Visit Override (Supervisor / Engineer actions)
  void resolvePendingVisit(String recordId, String siteId, String action, {String? explanation}) {
    // Action can be: 'present' (mark complete), 'ignore' (remove visit from attendance score), 'completed'
    int recordIndex = _attendanceRecords.indexWhere((r) => r.id == recordId);
    if (recordIndex != -1) {
      var record = _attendanceRecords[recordIndex];
      int visitIndex = record.visits.indexWhere((v) => v.siteId == siteId);
      if (visitIndex != -1) {
        var visit = record.visits[visitIndex];
        if (action == 'present' || action == 'completed') {
          visit.status = 'Completed';
          visit.entryTime ??= DateTime(record.date.year, record.date.month, record.date.day, 9, 0);
          visit.exitTime ??= DateTime(record.date.year, record.date.month, record.date.day, 10, 0);
          visit.comments = explanation ?? "Resolved by Supervisor";
        } else if (action == 'ignore') {
          visit.status = 'Skipped';
          visit.comments = explanation ?? "Ignored by Supervisor";
        }
        _recalculateAttendanceStatus(record);
        notifyListeners();
      }
    }
  }

  // Heartbeat Logs & GPS Alerts
  void logHeartbeat(String workerId, double lat, double lng) {
    var log = HeartbeatLog(
      id: 'hb_${DateTime.now().millisecondsSinceEpoch}',
      workerId: workerId,
      timestamp: _simulatedTime,
      latitude: lat,
      longitude: lng,
    );

    if (_isInternetEnabled) {
      _heartbeatLogs.add(log);
    } else {
      _offlineHeartbeats.add(log);
    }
    
    // Also push heartbeat to server
    _sendHeartbeatToBackend(lat, lng, 10.0);
    
    notifyListeners();
  }

  void triggerTamperAlert(String workerId, String type, String details) {
    var alert = TamperAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      workerId: workerId,
      timestamp: _simulatedTime,
      alertType: type,
      details: details,
    );

    if (_isInternetEnabled) {
      _tamperAlerts.add(alert);
      _saveTamperAlertsToStorage();
    } else {
      _offlineAlerts.add(alert);
    }

    String workerName = workerId;
    try {
      final w = _workers.firstWhere((x) => x.id == workerId);
      workerName = w.name;
    } catch (_) {}

    addNotification(
      title: 'Security Alert: Location Tampering',
      message: 'Worker $workerName triggered a security alert: $type - $details',
      targetRole: 'Admin',
    );
    addNotification(
      title: 'Security Alert: Location Tampering',
      message: 'Worker $workerName triggered a security alert: $type - $details',
      targetRole: 'Supervisor',
    );

    notifyListeners();
  }

  // ── Worker WebSocket & Geolocator Tracking Client ──────────────────────────

  void _connectWorkerWs() {
    _closeWorkerWs();
    _workerReconnectTimer?.cancel();

    if (!_isInternetEnabled) return;

    final worker = currentWorker;
    // Replace localhost with network IP when debugging on actual phones
    final wsUrl = '$kWsBaseUrl/ws?role=worker&workerId=${worker.id}&workerName=${Uri.encodeComponent(worker.name)}';

    try {
      _workerWsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isWorkerWsConnected = true;
      _workerReconnectDelay = 2; // reset
      notifyListeners();

      _workerWsChannel!.stream.listen(
        (message) {
          debugPrint('[WorkerWS] Message from backend: $message');
        },
        onError: (err) {
          debugPrint('[WorkerWS] Error: $err');
          _isWorkerWsConnected = false;
          notifyListeners();
          _scheduleWorkerReconnect();
        },
        onDone: () {
          debugPrint('[WorkerWS] Closed');
          _isWorkerWsConnected = false;
          notifyListeners();
          _scheduleWorkerReconnect();
        },
        cancelOnError: false,
      );
      debugPrint('[WorkerWS] Connected successfully to $wsUrl');
    } catch (e) {
      debugPrint('[WorkerWS] Connection failed: $e');
      _isWorkerWsConnected = false;
      notifyListeners();
      _scheduleWorkerReconnect();
    }
  }

  void _closeWorkerWs() {
    _workerWsChannel?.sink.close();
    _workerWsChannel = null;
    _isWorkerWsConnected = false;
  }

  void _scheduleWorkerReconnect() {
    _workerReconnectTimer?.cancel();
    if (!_isInternetEnabled) return;
    
    final att = _getCurrentAttendanceRecord(currentWorker.id);
    if (att == null || att.shiftStart == null || att.shiftEnd != null) return;

    _workerReconnectTimer = Timer(Duration(seconds: _workerReconnectDelay), () {
      _workerReconnectDelay = (_workerReconnectDelay * 2).clamp(2, 60);
      _connectWorkerWs();
    });
  }

  Future<void> _startGpsTracking() async {
    _stopGpsTracking();

    if (!_isGpsEnabled) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GPS] Location services disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[GPS] Permission denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[GPS] Permission permanently denied.');
        return;
      }

      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (_isFakeGpsEnabled) return; // ignore real movements when fake location spoof is on
        _updateLocation(pos.latitude, pos.longitude, pos.accuracy);
      }, onError: (err) {
        debugPrint('[GPS] Stream error: $err');
      });
      debugPrint('[GPS] Geolocator listening to updates.');
    } catch (e) {
      debugPrint('[GPS] Failed to start tracking: $e');
    }
  }

  void _stopGpsTracking() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }

  void _updateLocation(double lat, double lng, double accuracy) {
    _currentLat = lat;
    _currentLng = lng;
    _currentAccuracy = accuracy;

    // Check geofence entry/exit boundary crossings
    _checkGeofenceTransitions(lat, lng);

    notifyListeners();

    // Create a local heartbeat log representation
    var log = HeartbeatLog(
      id: 'hb_${DateTime.now().millisecondsSinceEpoch}',
      workerId: currentWorker.id,
      timestamp: _simulatedTime,
      latitude: lat,
      longitude: lng,
    );
    if (_isInternetEnabled) {
      _heartbeatLogs.add(log);
    } else {
      _offlineHeartbeats.add(log);
    }

    _sendHeartbeatToBackend(lat, lng, accuracy);
  }

  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int i, j = polygon.length - 1;
    bool oddNodes = false;
    double x = point.longitude;
    double y = point.latitude;

    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude < y && polygon[j].latitude >= y ||
              polygon[j].latitude < y && polygon[i].latitude >= y) &&
          (polygon[i].longitude +
                  (y - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) *
                      (polygon[j].longitude - polygon[i].longitude) <
              x)) {
        oddNodes = !oddNodes;
      }
      j = i;
    }

    return oddNodes;
  }

  void _checkGeofenceTransitions(double lat, double lng) {
    final myPos = LatLng(lat, lng);

    // 1. Check static mock sites
    for (final site in _sites) {
      final double dist = Geolocator.distanceBetween(lat, lng, site.latitude, site.longitude);
      final bool isInside = dist <= site.radius;

      _evaluateGeofenceTransition(site.id, site.name, isInside);
    }

    // 2. Check dynamic PostgreSQL geofences
    for (final fence in _backendGeofences) {
      bool isInside = false;
      if (fence.type == GeofenceShape.circle && fence.center != null && fence.radiusM != null) {
        final double dist = Geolocator.distanceBetween(
          lat, lng, fence.center!.latitude, fence.center!.longitude,
        );
        isInside = dist <= fence.radiusM!;
      } else if (fence.type == GeofenceShape.polygon && fence.polygon != null) {
        isInside = isPointInPolygon(myPos, fence.polygon!);
      }

      _evaluateGeofenceTransition(fence.id, fence.name, isInside);
    }
  }

  void _evaluateGeofenceTransition(String id, String name, bool isInside) {
    if (isInside && !_insideGeofenceIds.contains(id)) {
      _insideGeofenceIds.add(id);

      final isCamp = name.toLowerCase().contains('camp') || name.toLowerCase().contains('accommodation');
      if (!isCamp) {
        startShift(currentWorker.id);
      }

      simulateEnterGeofence(currentWorker.id, id);

      _activeNotificationBanner = isCamp ? "Returned to accommodation camp" : "Destination Reached: Entered $name";
      notifyListeners();

      Timer(const Duration(seconds: 4), () {
        _activeNotificationBanner = null;
        notifyListeners();
      });

      debugPrint('[Geofence] ENTRY detected for $name ($id)');
    } else if (!isInside && _insideGeofenceIds.contains(id)) {
      _insideGeofenceIds.remove(id);

      simulateExitGeofence(currentWorker.id, id);

      final isCamp = name.toLowerCase().contains('camp') || name.toLowerCase().contains('accommodation');
      _activeNotificationBanner = isCamp ? "Departure from Camp" : "You Left Assigned Site: Exited $name";
      notifyListeners();

      Timer(const Duration(seconds: 4), () {
        _activeNotificationBanner = null;
        notifyListeners();
      });

      debugPrint('[Geofence] EXIT detected for $name ($id)');
    }
  }

  Future<void> _sendHeartbeatToBackend(double lat, double lng, double accuracy) async {
    final att = _getCurrentAttendanceRecord(currentWorker.id);
    final isOnShift = att != null && att.shiftStart != null && att.shiftEnd == null;

    final payload = {
      "type": "location",
      "workerId": currentWorker.id,
      "workerName": currentWorker.name,
      "lat": lat,
      "lng": lng,
      "accuracy": accuracy,
      "isOnShift": isOnShift,
      "timestamp": _simulatedTime.toUtc().toIso8601String(),
    };

    if (_isInternetEnabled && _isWorkerWsConnected && _workerWsChannel != null) {
      try {
        _workerWsChannel!.sink.add(jsonEncode(payload));
        debugPrint('[WorkerWS] Location update sent to Go backend: $lat, $lng');
      } catch (e) {
        debugPrint('[WorkerWS] Send error: $e. Saving to offline queue.');
        _queueOfflineLocation(lat, lng, accuracy, isOnShift);
      }
    } else {
      _queueOfflineLocation(lat, lng, accuracy, isOnShift);
    }
  }

  void _queueOfflineLocation(double lat, double lng, double accuracy, bool isOnShift) {
    _offlineLocationsBuffer.add({
      "workerId": currentWorker.id,
      "workerName": currentWorker.name,
      "lat": lat,
      "lng": lng,
      "accuracy": accuracy,
      "isOnShift": isOnShift,
      "timestamp": _simulatedTime.toUtc().toIso8601String(),
    });
    debugPrint('[Offline] Queued update (${_offlineLocationsBuffer.length} buffered)');
  }

  // ── Offline Sync ───────────────────────────────────────────────────────────

  Future<void> _syncOfflineQueue() async {
    if (_offlineVisits.isNotEmpty) {
      var todayRecord = _getCurrentAttendanceRecord(currentWorker.id);
      if (todayRecord != null) {
        for (var offlineVisit in _offlineVisits) {
          int index = todayRecord.visits.indexWhere((v) => v.siteId == offlineVisit.siteId);
          if (index != -1) {
            todayRecord.visits[index] = offlineVisit;
          }
        }
        _recalculateAttendanceStatus(todayRecord);
      }
      _offlineVisits.clear();
    }

    if (_offlineHeartbeats.isNotEmpty) {
      _heartbeatLogs.addAll(_offlineHeartbeats);
      _offlineHeartbeats.clear();
    }

    if (_offlineAlerts.isNotEmpty) {
      _tamperAlerts.addAll(_offlineAlerts);
      _offlineAlerts.clear();
    }

    // Sync buffered coordinates via REST api/heartbeat fallback
    if (_offlineLocationsBuffer.isNotEmpty && _isInternetEnabled) {
      final items = List<Map<String, dynamic>>.from(_offlineLocationsBuffer);
      _offlineLocationsBuffer.clear();
      debugPrint('[Sync] Syncing ${items.length} locations to Go backend...');

      for (final item in items) {
        try {
          final res = await http.post(
            Uri.parse('$kServerBaseUrl/api/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item),
          );
          if (res.statusCode != 200) {
            _offlineLocationsBuffer.add(item);
          } else {
            debugPrint('[Sync] Synced location point for ${item['workerId']}');
          }
        } catch (e) {
          debugPrint('[Sync] Upload failed: $e. Re-queuing.');
          _offlineLocationsBuffer.add(item);
          break; // server down, stop attempts for now
        }
      }
    }
    notifyListeners();
  }

  Future<void> fetchGeofencesFromBackend() async {
    try {
      final res = await http.get(Uri.parse('$kServerBaseUrl/api/geofences'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        
        final existingIds = _backendGeofences.map((g) => g.id).toSet();
        
        _backendGeofences.clear();
        _backendGeofences.addAll(
          list.map((e) => AppGeofence.fromJson(e as Map<String, dynamic>)),
        );
        _saveGeofencesToStorage();

        final List<Site> newSites = [];
        for (final fence in _backendGeofences) {
          final siteId = fence.siteId ?? fence.id;
          final double lat = fence.center?.latitude ??
              (fence.polygon != null && fence.polygon!.isNotEmpty
                  ? (fence.polygon!.map((p) => p.latitude).reduce((a, b) => a + b) / fence.polygon!.length)
                  : 25.1234);
          final double lng = fence.center?.longitude ??
              (fence.polygon != null && fence.polygon!.isNotEmpty
                  ? (fence.polygon!.map((p) => p.longitude).reduce((a, b) => a + b) / fence.polygon!.length)
                  : 55.3456);
          final double radius = fence.radiusM ?? 100.0;
          
          final cat = JobCategory.values.firstWhere(
            (e) => e.name == fence.category || e.toString().split('.').last == fence.category,
            orElse: () => JobCategory.AMC,
          );
          final subCat = SubCategory.values.firstWhere(
            (e) => e.name == fence.subCategory || e.toString().split('.').last == fence.subCategory,
            orElse: () => SubCategory.Outdoor,
          );
          final jobT = JobType.values.firstWhere(
            (e) => e.name == fence.jobType || e.toString().split('.').last == fence.jobType,
            orElse: () => JobType.Permanent,
          );
          final freq = JobFrequency.values.firstWhere(
            (e) => e.name == fence.frequency || e.toString().split('.').last == fence.frequency,
            orElse: () => JobFrequency.Daily,
          );

          newSites.add(Site(
            id: siteId,
            name: fence.name,
            code: fence.code.isNotEmpty ? fence.code : fence.name.substring(0, min(5, fence.name.length)).toUpperCase(),
            category: cat,
            subCategory: subCat,
            jobType: jobT,
            frequency: freq,
            address: fence.address,
            latitude: lat,
            longitude: lng,
            radius: radius,
            plannedStartTime: fence.plannedStartTime.isNotEmpty ? fence.plannedStartTime : '08:00 AM',
            plannedEndTime: fence.plannedEndTime.isNotEmpty ? fence.plannedEndTime : '05:00 PM',
            isAccommodation: fence.isAccommodation,
          ));

          if (existingIds.isNotEmpty && !existingIds.contains(fence.id)) {
            addNotification(
              title: 'New Geofence Site Added',
              message: 'Site: ${fence.name} has been added by admin.',
              targetRole: 'Worker',
            );
          }
        }

        if (newSites.isNotEmpty) {
          _sites = newSites;
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TrackerState] Geofence fetch error: $e');
    }
  }

  Future<void> _initializeCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GPS] Location services not enabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[GPS] Location permission denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[GPS] Location permission denied forever.');
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;
      _hasRealLocation = true;
      notifyListeners();
      debugPrint('[GPS] Initialized PC location: $_currentLat, $_currentLng');
    } catch (e) {
      debugPrint('[GPS] Failed to get current PC location: $e');
    }
  }

  // Helpers
  AttendanceRecord? _getCurrentAttendanceRecord(String workerId) {
    return _attendanceRecords.firstWhere(
      (r) => r.workerId == workerId && isSameDay(r.date, _selectedDate),
      orElse: () => _attendanceRecords.firstWhere((r) => r.workerId == workerId),
    );
  }

  AttendanceRecord _getOrCreateAttendanceRecord(String workerId, DateTime date) {
    int index = _attendanceRecords.indexWhere((r) => r.workerId == workerId && isSameDay(r.date, date));
    if (index != -1) {
      return _attendanceRecords[index];
    } else {
      var record = AttendanceRecord(
        id: 'att_${workerId}_${DateFormat('yyyyMMdd').format(date)}',
        workerId: workerId,
        date: date,
        visits: _assignments
            .where((a) => a.workerId == workerId && isSameDay(a.date, date))
            .map((a) => VisitRecord(
                  siteId: a.siteId,
                  status: 'Pending',
                  checklistAtVisit: a.checklist.map((c) {
                    final copy = c.copy();
                    copy.isCompleted = false;
                    return copy;
                  }).toList(),
                ))
            .toList(),
      );
      _attendanceRecords.add(record);
      return record;
    }
  }

  void _recalculateAttendanceStatus(AttendanceRecord record) {
    // Accommodation exits/entries don't count towards work attendance completions.
    // Exclude accommodation geofence from calculations
    var workVisits = record.visits.where((v) {
      var s = _sites.firstWhere((site) => site.id == v.siteId, orElse: () => _sites.first);
      return !s.isAccommodation;
    }).toList();

    if (workVisits.isEmpty) {
      record.status = 'Present';
      return;
    }

    int completed = workVisits.where((v) => v.status == 'Completed').length;
    int skipped = workVisits.where((v) => v.status == 'Skipped').length;
    int activeVisits = workVisits.length - skipped;

    if (activeVisits <= 0) {
      record.status = 'Present';
    } else if (completed == activeVisits) {
      record.status = 'Present';
    } else if (completed > 0) {
      record.status = 'Partial';
    } else {
      // If shift has started but no sites completed
      if (record.shiftStart != null) {
        record.status = 'Pending';
      } else {
        record.status = 'Absent';
      }
    }
  }

  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  void dispose() {
    _geofencePollTimer?.cancel();
    _closeWorkerWs();
    _stopGpsTracking();
    _workerReconnectTimer?.cancel();
    super.dispose();
  }
}
