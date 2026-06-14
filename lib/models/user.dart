class User {
  final int id;
  String name;
  final String email;
  final String role;
  final String? nim;
  final int? employeeId;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.nim = '123220144',
    this.employeeId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      nim: json['nim'] as String? ?? '123220144',
      employeeId: json['employee_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'nim': nim,
      'employee_id': employeeId,
    };
  }
}
