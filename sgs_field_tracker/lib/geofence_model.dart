import 'package:latlong2/latlong.dart';

/// Shape of the geofence
enum GeofenceShape { circle, polygon }

/// A geofence stored in PostgreSQL backend
class AppGeofence {
  final String id;
  final String name;
  final String? siteId;
  final GeofenceShape type;

  // Circle-specific
  final LatLng? center;
  final double? radiusM;

  // Polygon-specific
  final List<LatLng>? polygon;

  final String color; // hex color string e.g. '#00BFA5'

  // Extra Site fields
  final String code;
  final String category;
  final String subCategory;
  final String jobType;
  final String frequency;
  final String address;
  final String plannedStartTime;
  final String plannedEndTime;
  final bool isAccommodation;

  AppGeofence({
    required this.id,
    required this.name,
    this.siteId,
    required this.type,
    this.center,
    this.radiusM,
    this.polygon,
    this.color = '#00BFA5',
    this.code = '',
    this.category = '',
    this.subCategory = '',
    this.jobType = '',
    this.frequency = '',
    this.address = '',
    this.plannedStartTime = '',
    this.plannedEndTime = '',
    this.isAccommodation = false,
  });

  factory AppGeofence.fromJson(Map<String, dynamic> json) {
    final type = json['type'] == 'polygon'
        ? GeofenceShape.polygon
        : GeofenceShape.circle;

    LatLng? center;
    if (json['lat'] != null && json['lng'] != null) {
      center = LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble());
    }

    List<LatLng>? polygon;
    if (json['polygon'] != null) {
      polygon = (json['polygon'] as List)
          .map((pt) => LatLng(
                (pt['lat'] as num).toDouble(),
                (pt['lng'] as num).toDouble(),
              ))
          .toList();
    }

    return AppGeofence(
      id: json['id'] as String,
      name: json['name'] as String,
      siteId: json['siteId'] as String?,
      type: type,
      center: center,
      radiusM: json['radiusM'] != null ? (json['radiusM'] as num).toDouble() : null,
      polygon: polygon,
      color: json['color'] as String? ?? '#00BFA5',
      code: json['code'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subCategory: json['subCategory'] as String? ?? '',
      jobType: json['jobType'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      address: json['address'] as String? ?? '',
      plannedStartTime: json['plannedStartTime'] as String? ?? '',
      plannedEndTime: json['plannedEndTime'] as String? ?? '',
      isAccommodation: json['isAccommodation'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'type': type == GeofenceShape.circle ? 'circle' : 'polygon',
      'color': color,
      'code': code,
      'category': category,
      'subCategory': subCategory,
      'jobType': jobType,
      'frequency': frequency,
      'address': address,
      'plannedStartTime': plannedStartTime,
      'plannedEndTime': plannedEndTime,
      'isAccommodation': isAccommodation,
    };
    if (siteId != null) map['siteId'] = siteId;
    if (center != null) {
      map['lat'] = center!.latitude;
      map['lng'] = center!.longitude;
    }
    if (radiusM != null) map['radiusM'] = radiusM;
    if (polygon != null) {
      map['polygon'] = polygon!
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();
    }
    return map;
  }

  AppGeofence copyWith({
    String? id,
    String? name,
    String? siteId,
    LatLng? center,
    double? radiusM,
    List<LatLng>? polygon,
    String? color,
    String? code,
    String? category,
    String? subCategory,
    String? jobType,
    String? frequency,
    String? address,
    String? plannedStartTime,
    String? plannedEndTime,
    bool? isAccommodation,
  }) {
    return AppGeofence(
      id: id ?? this.id,
      name: name ?? this.name,
      siteId: siteId ?? this.siteId,
      type: type,
      center: center ?? this.center,
      radiusM: radiusM ?? this.radiusM,
      polygon: polygon ?? this.polygon,
      color: color ?? this.color,
      code: code ?? this.code,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      jobType: jobType ?? this.jobType,
      frequency: frequency ?? this.frequency,
      address: address ?? this.address,
      plannedStartTime: plannedStartTime ?? this.plannedStartTime,
      plannedEndTime: plannedEndTime ?? this.plannedEndTime,
      isAccommodation: isAccommodation ?? this.isAccommodation,
    );
  }
}
