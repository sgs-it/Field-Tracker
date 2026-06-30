import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sgs_field_tracker/models.dart';

void main() async {
  final worker = Worker(
    id: 'test',
    employeeId: 'test',
    name: 'test',
    phone: '123',
    staffType: StaffType.BlueCollar,
    staffCategory: StaffCategory.Skilled,
    leaveCategory: LeaveCategory.Annual,
    department: 'test',
    designation: 'test',
    username: 'test',
    password: 'test',
    staffHierarchy: 'test',
    isActive: true,
    emiratesId: 'test',
    emiratesIdExpiry: DateTime.now(),
    passportNo: 'test',
    passportExpiry: DateTime.now(),
    labourCardNo: 'test',
    labourCardExpiry: DateTime.now(),
    joinedDate: DateTime.now(),
    leaveDueDate: DateTime.now(),
  );

  print('JSON: \');
  try {
    final res = await http.post(
      Uri.parse('http://127.0.0.1:8080/api/workers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(worker.toJson()),
    );
    print('Response status: \');
    print('Response body: \');
  } catch (e) {
    print('Error: \');
  }
}
