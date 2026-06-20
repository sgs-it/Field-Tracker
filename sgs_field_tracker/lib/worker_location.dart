import 'package:latlong2/latlong.dart';

/// The latest known GPS position for a single worker
class WorkerLocation {
  final String workerId;
  final String workerName;
  final double lat;
  final double lng;
  final double accuracy;
  final DateTime timestamp;
  final bool isOnShift;
  final bool isOnline;

  /// Today's breadcrumb trail (populated separately from /api/trail)
  final List<LatLng> todayTrail;

  WorkerLocation({
    required this.workerId,
    required this.workerName,
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.timestamp,
    required this.isOnShift,
    required this.isOnline,
    this.todayTrail = const [],
  });

  LatLng get position => LatLng(lat, lng);

  factory WorkerLocation.fromJson(Map<String, dynamic> json) {
    return WorkerLocation(
      workerId: json['workerId'] as String,
      workerName: json['workerName'] as String? ?? 'Unknown',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isOnShift: json['isOnShift'] as bool? ?? false,
      isOnline: json['isOnline'] as bool? ?? true,
    );
  }

  WorkerLocation copyWith({
    double? lat,
    double? lng,
    double? accuracy,
    DateTime? timestamp,
    bool? isOnShift,
    bool? isOnline,
    List<LatLng>? todayTrail,
  }) {
    return WorkerLocation(
      workerId: workerId,
      workerName: workerName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      isOnShift: isOnShift ?? this.isOnShift,
      isOnline: isOnline ?? this.isOnline,
      todayTrail: todayTrail ?? this.todayTrail,
    );
  }

  /// Returns how many seconds since the last update
  int get secondsSinceUpdate =>
      DateTime.now().difference(timestamp).inSeconds;

  /// True if updated within the last 2 minutes
  bool get isRecent => secondsSinceUpdate < 120;
}
