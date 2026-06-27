import 'package:flutter/foundation.dart';

enum StaffType { IP, LS, DW } // IP: Company Own, LS: Labour Supply, DW: Daily Wages
enum StaffCategory { Direct, Indirect }
enum LeaveCategory { Year1, Year2 }
enum JobCategory { AMC, PW, VO } // AMC, Project Work, Variation Order
enum SubCategory { Indoor, Outdoor, WF } // WF: Water Feature
enum JobType { Permanent, Remote }
enum JobFrequency { Daily, WeeklyThrice, WeeklyTwice, WeeklyOnce, BiWeekly }
enum GeofenceType { Circular, Polygon }

class Site {
  final String id;
  final String name;
  final String code;
  final JobCategory category;
  final SubCategory subCategory;
  final JobType jobType;
  final JobFrequency frequency;
  final String address;
  final double latitude;
  final double longitude;
  final double radius; // meters
  final String plannedStartTime;
  final String plannedEndTime;
  final bool isAccommodation; // True if accommodation geofence

  Site({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.subCategory,
    required this.jobType,
    required this.frequency,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.plannedStartTime,
    required this.plannedEndTime,
    this.isAccommodation = false,
  });

  Site copyWith({
    String? name,
    String? code,
    JobCategory? category,
    SubCategory? subCategory,
    JobType? jobType,
    JobFrequency? frequency,
    String? address,
    double? latitude,
    double? longitude,
    double? radius,
    String? plannedStartTime,
    String? plannedEndTime,
    bool? isAccommodation,
  }) {
    return Site(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      jobType: jobType ?? this.jobType,
      frequency: frequency ?? this.frequency,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      plannedStartTime: plannedStartTime ?? this.plannedStartTime,
      plannedEndTime: plannedEndTime ?? this.plannedEndTime,
      isAccommodation: isAccommodation ?? this.isAccommodation,
    );
  }

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      category: JobCategory.values.firstWhere((e) => e.toString() == 'JobCategory.${json['category']}', orElse: () => JobCategory.AMC),
      subCategory: SubCategory.values.firstWhere((e) => e.toString() == 'SubCategory.${json['subCategory']}', orElse: () => SubCategory.Indoor),
      jobType: JobType.values.firstWhere((e) => e.toString() == 'JobType.${json['jobType']}', orElse: () => JobType.Permanent),
      frequency: JobFrequency.values.firstWhere((e) => e.toString() == 'JobFrequency.${json['frequency']}', orElse: () => JobFrequency.Daily),
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      radius: (json['radius'] ?? 0).toDouble(),
      plannedStartTime: json['plannedStartTime'] ?? '',
      plannedEndTime: json['plannedEndTime'] ?? '',
      isAccommodation: json['isAccommodation'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'category': category.toString().split('.').last,
      'subCategory': subCategory.toString().split('.').last,
      'jobType': jobType.toString().split('.').last,
      'frequency': frequency.toString().split('.').last,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'plannedStartTime': plannedStartTime,
      'plannedEndTime': plannedEndTime,
      'isAccommodation': isAccommodation,
    };
  }
}

class Worker {
  final String id;
  final String employeeId;
  final String name;
  final String phone;
  final StaffType staffType;
  final StaffCategory staffCategory;
  final LeaveCategory leaveCategory;
  final String department;
  final String designation;
  final String username;
  final String password;
  final String staffHierarchy;
  final bool isActive;
  final String emiratesId;
  final DateTime emiratesIdExpiry;
  final String passportNo;
  final DateTime passportExpiry;
  final String labourCardNo;
  final DateTime labourCardExpiry;
  final DateTime joinedDate;
  final DateTime leaveDueDate;

  Worker({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.phone,
    required this.staffType,
    required this.staffCategory,
    required this.leaveCategory,
    required this.department,
    required this.designation,
    required this.username,
    required this.password,
    required this.staffHierarchy,
    required this.isActive,
    required this.emiratesId,
    required this.emiratesIdExpiry,
    required this.passportNo,
    required this.passportExpiry,
    required this.labourCardNo,
    required this.labourCardExpiry,
    required this.joinedDate,
    required this.leaveDueDate,
  });

  Worker copyWith({
    String? name,
    String? phone,
    StaffType? staffType,
    StaffCategory? staffCategory,
    LeaveCategory? leaveCategory,
    String? department,
    String? designation,
    String? username,
    String? password,
    String? staffHierarchy,
    bool? isActive,
    String? emiratesId,
    DateTime? emiratesIdExpiry,
    String? passportNo,
    DateTime? passportExpiry,
    String? labourCardNo,
    DateTime? labourCardExpiry,
    DateTime? joinedDate,
    DateTime? leaveDueDate,
  }) {
    return Worker(
      id: id,
      employeeId: employeeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      staffType: staffType ?? this.staffType,
      staffCategory: staffCategory ?? this.staffCategory,
      leaveCategory: leaveCategory ?? this.leaveCategory,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      username: username ?? this.username,
      password: password ?? this.password,
      staffHierarchy: staffHierarchy ?? this.staffHierarchy,
      isActive: isActive ?? this.isActive,
      emiratesId: emiratesId ?? this.emiratesId,
      emiratesIdExpiry: emiratesIdExpiry ?? this.emiratesIdExpiry,
      passportNo: passportNo ?? this.passportNo,
      passportExpiry: passportExpiry ?? this.passportExpiry,
      labourCardNo: labourCardNo ?? this.labourCardNo,
      labourCardExpiry: labourCardExpiry ?? this.labourCardExpiry,
      joinedDate: joinedDate ?? this.joinedDate,
      leaveDueDate: leaveDueDate ?? this.leaveDueDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'name': name,
      'phone': phone,
      'staffType': staffType.name,
      'staffCategory': staffCategory.name,
      'leaveCategory': leaveCategory.name,
      'department': department,
      'designation': designation,
      'username': username,
      'password': password,
      'staffHierarchy': staffHierarchy,
      'isActive': isActive,
      'emiratesId': emiratesId,
      'emiratesIdExpiry': emiratesIdExpiry.toIso8601String() + 'Z',
      'passportNo': passportNo,
      'passportExpiry': passportExpiry.toIso8601String() + 'Z',
      'labourCardNo': labourCardNo,
      'labourCardExpiry': labourCardExpiry.toIso8601String() + 'Z',
      'joinedDate': joinedDate.toIso8601String() + 'Z',
      'leaveDueDate': leaveDueDate.toIso8601String() + 'Z',
    };
  }

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      staffType: StaffType.values.firstWhere((e) => e.name == json['staffType']),
      staffCategory: StaffCategory.values.firstWhere((e) => e.name == json['staffCategory']),
      leaveCategory: LeaveCategory.values.firstWhere((e) => e.name == json['leaveCategory']),
      department: json['department'] as String,
      designation: json['designation'] as String,
      username: json['username'] as String,
      password: json['password'] as String? ?? 'password123',
      staffHierarchy: json['staffHierarchy'] as String? ?? 'Default',
      isActive: json['isActive'] as bool? ?? true,
      emiratesId: json['emiratesId'] as String? ?? 'N/A',
      emiratesIdExpiry: json['emiratesIdExpiry'] != null ? DateTime.parse(json['emiratesIdExpiry'] as String) : DateTime.now().add(const Duration(days: 365)),
      passportNo: json['passportNo'] as String? ?? 'N/A',
      passportExpiry: json['passportExpiry'] != null ? DateTime.parse(json['passportExpiry'] as String) : DateTime.now().add(const Duration(days: 365)),
      labourCardNo: json['labourCardNo'] as String? ?? 'N/A',
      labourCardExpiry: json['labourCardExpiry'] != null ? DateTime.parse(json['labourCardExpiry'] as String) : DateTime.now().add(const Duration(days: 365)),
      joinedDate: json['joinedDate'] != null ? DateTime.parse(json['joinedDate'] as String) : DateTime.now(),
      leaveDueDate: json['leaveDueDate'] != null ? DateTime.parse(json['leaveDueDate'] as String) : DateTime.now().add(const Duration(days: 365)),
    );
  }
}

class ChecklistItem {
  final String id;
  final String task;
  final String category; // 'Labour', 'Equipment', 'Materials', 'General'
  bool isCompleted;

  ChecklistItem({
    required this.id,
    required this.task,
    required this.category,
    this.isCompleted = false,
  });

  ChecklistItem copy() {
    return ChecklistItem(
      id: id,
      task: task,
      category: category,
      isCompleted: isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task': task,
      'category': category,
      'isCompleted': isCompleted,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      task: json['task'] as String,
      category: json['category'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

class Assignment {
  final String id;
  final String workerId;
  final String siteId;
  final DateTime date;
  final String shift; // e.g. "Morning Shift"
  final String instructions;
  final List<ChecklistItem> checklist;
  final String priority; // 'High', 'Medium', 'Low'
  final String breakTime; // e.g. "12:00 PM - 01:00 PM"

  Assignment({
    required this.id,
    required this.workerId,
    required this.siteId,
    required this.date,
    required this.shift,
    required this.instructions,
    required this.checklist,
    required this.priority,
    required this.breakTime,
  });

  Assignment copyWith({
    String? siteId,
    String? shift,
    String? instructions,
    List<ChecklistItem>? checklist,
    String? priority,
    String? breakTime,
  }) {
    return Assignment(
      id: id,
      workerId: workerId,
      siteId: siteId ?? this.siteId,
      date: date,
      shift: shift ?? this.shift,
      instructions: instructions ?? this.instructions,
      checklist: checklist ?? this.checklist.map((e) => e.copy()).toList(),
      priority: priority ?? this.priority,
      breakTime: breakTime ?? this.breakTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workerId': workerId,
      'siteId': siteId,
      'date': date.toIso8601String() + 'Z',
      'shift': shift,
      'instructions': instructions,
      'checklist': checklist.map((e) => e.toJson()).toList(),
      'priority': priority,
      'breakTime': breakTime,
    };
  }

  factory Assignment.fromJson(Map<String, dynamic> json) {
    var list = json['checklist'] as List? ?? [];
    return Assignment(
      id: json['id'] as String,
      workerId: json['workerId'] as String,
      siteId: json['siteId'] as String,
      date: DateTime(DateTime.parse(json['date'] as String).year, DateTime.parse(json['date'] as String).month, DateTime.parse(json['date'] as String).day),
      shift: json['shift'] as String,
      instructions: json['instructions'] as String,
      checklist: list.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>)).toList(),
      priority: json['priority'] as String,
      breakTime: json['breakTime'] as String,
    );
  }
}

class VisitRecord {
  final String siteId;
  DateTime? entryTime;
  DateTime? exitTime;
  String status; // 'Pending', 'Completed', 'Skipped', 'Exit Recorded', 'Entry Recorded'
  final List<ChecklistItem> checklistAtVisit;
  String? photoPath;
  String? comments;

  VisitRecord({
    required this.siteId,
    this.entryTime,
    this.exitTime,
    this.status = 'Pending',
    required this.checklistAtVisit,
    this.photoPath,
    this.comments,
  });

  VisitRecord copy() {
    return VisitRecord(
      siteId: siteId,
      entryTime: entryTime,
      exitTime: exitTime,
      status: status,
      checklistAtVisit: checklistAtVisit.map((e) => e.copy()).toList(),
      photoPath: photoPath,
      comments: comments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'siteId': siteId,
      'entryTime': entryTime?.toUtc().toIso8601String(),
      'exitTime': exitTime?.toUtc().toIso8601String(),
      'status': status,
      'checklistAtVisit': checklistAtVisit.map((e) => e.toJson()).toList(),
      'photoPath': photoPath,
      'comments': comments,
    };
  }

  factory VisitRecord.fromJson(Map<String, dynamic> json) {
    var list = json['checklistAtVisit'] as List? ?? [];
    return VisitRecord(
      siteId: json['siteId'] as String,
      entryTime: json['entryTime'] != null ? DateTime.parse(json['entryTime'] as String) : null,
      exitTime: json['exitTime'] != null ? DateTime.parse(json['exitTime'] as String) : null,
      status: json['status'] as String? ?? 'Pending',
      checklistAtVisit: list.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>)).toList(),
      photoPath: json['photoPath'] as String?,
      comments: json['comments'] as String?,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String workerId;
  final DateTime date;
  DateTime? shiftStart;
  DateTime? shiftEnd;
  final List<VisitRecord> visits;
  double overtimeHours; // Hours beyond basic
  double normalHours;
  String status; // 'Present', 'Partial', 'Absent', 'Pending'
  String supervisorComments;
  bool isApproved;

  AttendanceRecord({
    required this.id,
    required this.workerId,
    required this.date,
    this.shiftStart,
    this.shiftEnd,
    required this.visits,
    this.overtimeHours = 0.0,
    this.normalHours = 0.0,
    this.status = 'Absent',
    this.supervisorComments = '',
    this.isApproved = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workerId': workerId,
      'date': date.toIso8601String() + 'Z',
      'shiftStart': shiftStart?.toUtc().toIso8601String(),
      'shiftEnd': shiftEnd?.toUtc().toIso8601String(),
      'visits': visits.map((e) => e.toJson()).toList(),
      'overtimeHours': overtimeHours,
      'normalHours': normalHours,
      'status': status,
      'supervisorComments': supervisorComments,
      'isApproved': isApproved,
    };
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    var list = json['visits'] as List? ?? [];
    return AttendanceRecord(
      id: json['id'] as String,
      workerId: json['workerId'] as String,
      date: DateTime(DateTime.parse(json['date'] as String).year, DateTime.parse(json['date'] as String).month, DateTime.parse(json['date'] as String).day),
      shiftStart: json['shiftStart'] != null ? DateTime.parse(json['shiftStart'] as String) : null,
      shiftEnd: json['shiftEnd'] != null ? DateTime.parse(json['shiftEnd'] as String) : null,
      visits: list.map((e) => VisitRecord.fromJson(e as Map<String, dynamic>)).toList(),
      overtimeHours: (json['overtimeHours'] as num? ?? 0.0).toDouble(),
      normalHours: (json['normalHours'] as num? ?? 0.0).toDouble(),
      status: json['status'] as String? ?? 'Absent',
      supervisorComments: json['supervisorComments'] as String? ?? '',
      isApproved: json['isApproved'] as bool? ?? false,
    );
  }
}

class TamperAlert {
  final String id;
  final String workerId;
  final DateTime timestamp;
  final String alertType; // 'GPS Off', 'Fake Location', 'Internet Off'
  final String details;

  TamperAlert({
    required this.id,
    required this.workerId,
    required this.timestamp,
    required this.alertType,
    required this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workerId': workerId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'alertType': alertType,
      'details': details,
    };
  }

  factory TamperAlert.fromJson(Map<String, dynamic> json) {
    return TamperAlert(
      id: json['id'] as String,
      workerId: json['workerId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      alertType: json['alertType'] as String,
      details: json['details'] as String,
    );
  }
}

class HeartbeatLog {
  final String id;
  final String workerId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  HeartbeatLog({
    required this.id,
    required this.workerId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workerId': workerId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory HeartbeatLog.fromJson(Map<String, dynamic> json) {
    return HeartbeatLog(
      id: json['id'] as String,
      workerId: json['workerId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String targetRole; // 'Admin', 'Supervisor', 'Worker'
  final String? targetWorkerId;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.targetRole,
    this.targetWorkerId,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'targetRole': targetRole,
      'targetWorkerId': targetWorkerId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'isRead': isRead,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      targetRole: json['targetRole'] as String,
      targetWorkerId: json['targetWorkerId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
