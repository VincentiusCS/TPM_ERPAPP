class User {
  final int id;
  String name;
  final String email;
  final String role;
  final String? nim;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.nim = '123220144',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      nim: json['nim'] as String? ?? '123220144',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'nim': nim,
    };
  }
}
