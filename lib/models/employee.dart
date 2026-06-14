class Employee {
  final int id;
  final String employeeName;
  final String phone;
  final String address;
  final String status;

  Employee({
    required this.id,
    required this.employeeName,
    required this.phone,
    required this.address,
    required this.status,
  });

  /// Convenience getter for display purposes.
  String get name => employeeName;

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as int,
      employeeName: json['employee_name'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_name': employeeName,
      'phone': phone,
      'address': address,
      'status': status,
    };
  }
}
