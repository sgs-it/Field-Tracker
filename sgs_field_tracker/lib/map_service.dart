import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'geofence_model.dart';
import 'worker_location.dart';

/// The backend server base URL.
/// Change this to your PC's local IP when testing with real devices on the same WiFi.
/// Example: 'http://192.168.1.105:8080'
const String kServerBaseUrl = 'http://localhost:8080';
const String kWsBaseUrl = 'ws://localhost:8080';

/// MapService connects the admin dashboard to the Go backend.
/// It manages the admin WebSocket connection, worker locations, geofences,
/// and auto-reconnects on disconnect.
class MapService extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectDelay = 2; // seconds, doubles on each failure

  // ── State ──────────────────────────────────────────────────────────────────
  final Map<String, WorkerLocation> _workerLocations = {};
  final List<AppGeofence> _geofences = [];
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';

  // ── Getters ────────────────────────────────────────────────────────────────
  Map<String, WorkerLocation> get workerLocations => Map.unmodifiable(_workerLocations);
  List<AppGeofence> get geofences => List.unmodifiable(_geofences);
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;

  // ── Initialization ─────────────────────────────────────────────────────────

  MapService() {
    _connectWebSocket();
    fetchGeofences(); // Load persisted geofences from PostgreSQL
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  void _connectWebSocket() {
    _connectionStatus = 'Connecting...';
    notifyListeners();

    try {
      final uri = Uri.parse('$kWsBaseUrl/ws?role=admin');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _isConnected = true;
      _reconnectDelay = 2; // reset backoff
      _connectionStatus = 'Connected';
      notifyListeners();

      debugPrint('[MapService] WebSocket connected to $uri');
    } catch (e) {
      _onError(e);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'location_update':
          final loc = WorkerLocation.fromJson(data);
          final existing = _workerLocations[loc.workerId];
          // Preserve existing trail when receiving a live update
          _workerLocations[loc.workerId] = loc.copyWith(
            todayTrail: existing != null
                ? [...existing.todayTrail, LatLng(loc.lat, loc.lng)]
                : [LatLng(loc.lat, loc.lng)],
          );
          notifyListeners();

        case 'worker_online':
          final workerId = data['workerId'] as String;
          if (_workerLocations.containsKey(workerId)) {
            _workerLocations[workerId] =
                _workerLocations[workerId]!.copyWith(isOnline: true);
          }
          // Fetch trail for this worker
          _fetchWorkerTrail(workerId);
          notifyListeners();

        case 'worker_offline':
          final workerId = data['workerId'] as String;
          if (_workerLocations.containsKey(workerId)) {
            _workerLocations[workerId] =
                _workerLocations[workerId]!.copyWith(isOnline: false);
          }
          notifyListeners();
      }
    } catch (e) {
      debugPrint('[MapService] Message parse error: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[MapService] WebSocket error: $error');
    _isConnected = false;
    _connectionStatus = 'Error — reconnecting in ${_reconnectDelay}s';
    notifyListeners();
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[MapService] WebSocket closed');
    _isConnected = false;
    _connectionStatus = 'Disconnected — reconnecting in ${_reconnectDelay}s';
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectDelay = (_reconnectDelay * 2).clamp(2, 60);
      _connectWebSocket();
    });
  }

  // ── Trail ─────────────────────────────────────────────────────────────────

  Future<void> _fetchWorkerTrail(String workerId) async {
    try {
      final res = await http.get(
        Uri.parse('$kServerBaseUrl/api/trail/$workerId'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final trailJson = body['trail'] as List<dynamic>;
        final trail = trailJson
            .map((pt) => LatLng(
                  (pt['lat'] as num).toDouble(),
                  (pt['lng'] as num).toDouble(),
                ))
            .toList();

        if (_workerLocations.containsKey(workerId)) {
          _workerLocations[workerId] =
              _workerLocations[workerId]!.copyWith(todayTrail: trail);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[MapService] Trail fetch error for $workerId: $e');
    }
  }

  // ── Geofences ─────────────────────────────────────────────────────────────

  Future<void> fetchGeofences() async {
    try {
      final res = await http.get(Uri.parse('$kServerBaseUrl/api/geofences'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _geofences.clear();
        _geofences.addAll(
          list.map((e) => AppGeofence.fromJson(e as Map<String, dynamic>)),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MapService] Geofence fetch error: $e');
    }
  }

  Future<AppGeofence?> createGeofence(AppGeofence geofence) async {
    try {
      final res = await http.post(
        Uri.parse('$kServerBaseUrl/api/geofences'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(geofence.toJson()),
      );
      if (res.statusCode == 201) {
        final created = AppGeofence.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        _geofences.add(created);
        notifyListeners();
        return created;
      }
    } catch (e) {
      debugPrint('[MapService] Create geofence error: $e');
    }
    return null;
  }

  Future<bool> updateGeofence(AppGeofence geofence) async {
    try {
      final res = await http.put(
        Uri.parse('$kServerBaseUrl/api/geofences/${geofence.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(geofence.toJson()),
      );
      if (res.statusCode == 200) {
        final idx = _geofences.indexWhere((g) => g.id == geofence.id);
        if (idx != -1) {
          _geofences[idx] = geofence;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('[MapService] Update geofence error: $e');
    }
    return false;
  }

  Future<bool> deleteGeofence(String id) async {
    try {
      final res = await http.delete(
          Uri.parse('$kServerBaseUrl/api/geofences/$id'));
      if (res.statusCode == 200) {
        _geofences.removeWhere((g) => g.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[MapService] Delete geofence error: $e');
    }
    return false;
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
