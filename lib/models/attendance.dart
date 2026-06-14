class Attendance {
  final int id;
  final int employeeId;
  final int shiftId;
  final DateTime attendanceDate;
  final String status;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.shiftId,
    required this.attendanceDate,
    required this.status,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] as int,
      employeeId: json['employee_id'] as int,
      shiftId: json['shift_id'] as int,
      attendanceDate: DateTime.parse(json['attendance_date'] as String),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'shift_id': shiftId,
      'attendance_date':
          '${attendanceDate.year.toString().padLeft(4, '0')}-${attendanceDate.month.toString().padLeft(2, '0')}-${attendanceDate.day.toString().padLeft(2, '0')}',
      'status': status,
    };
  }
}
