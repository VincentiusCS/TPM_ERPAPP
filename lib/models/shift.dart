class Shift {
  final int id;
  final int employeeId;
  final DateTime shiftDate;
  final double wagePerShift;
  final String? employeeName;

  Shift({
    required this.id,
    required this.employeeId,
    required this.shiftDate,
    required this.wagePerShift,
    this.employeeName,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as int,
      employeeId: json['employee_id'] as int,
      shiftDate: DateTime.parse(json['shift_date'] as String),
      wagePerShift: double.parse(json['wage_per_shift'].toString()),
      employeeName: json['employee']?['employee_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'shift_date':
          '${shiftDate.year.toString().padLeft(4, '0')}-${shiftDate.month.toString().padLeft(2, '0')}-${shiftDate.day.toString().padLeft(2, '0')}',
      'wage_per_shift': wagePerShift,
    };
  }
}
