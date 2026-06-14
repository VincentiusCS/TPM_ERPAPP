class Payroll {
  final int id;
  final int employeeId;
  final String? employeeName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalAttendance;
  final double totalSalary;

  Payroll({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.periodStart,
    required this.periodEnd,
    required this.totalAttendance,
    required this.totalSalary,
  });

  factory Payroll.fromJson(Map<String, dynamic> json) {
    return Payroll(
      id: json['id'] as int? ?? 0,
      employeeId: json['employee_id'] as int,
      employeeName: json['employee_name'] as String?,
      periodStart: json['period_start'] != null
          ? DateTime.parse(json['period_start'] as String)
          : DateTime.now(),
      periodEnd: json['period_end'] != null
          ? DateTime.parse(json['period_end'] as String)
          : DateTime.now(),
      totalAttendance: json['total_attendance'] is int
          ? json['total_attendance'] as int
          : int.parse(json['total_attendance'].toString()),
      totalSalary: double.parse(json['total_salary'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'period_start':
          '${periodStart.year.toString().padLeft(4, '0')}-${periodStart.month.toString().padLeft(2, '0')}-${periodStart.day.toString().padLeft(2, '0')}',
      'period_end':
          '${periodEnd.year.toString().padLeft(4, '0')}-${periodEnd.month.toString().padLeft(2, '0')}-${periodEnd.day.toString().padLeft(2, '0')}',
      'total_attendance': totalAttendance,
      'total_salary': totalSalary,
    };
  }
}
