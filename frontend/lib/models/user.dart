enum UserRole { user, agent, admin }

UserRole userRoleFromString(String value) {
  return UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.user,
  );
}

class User {
  final int id;
  final String name;
  final String? email;
  final UserRole role;
  final bool emailVerified;

  const User({
    required this.id,
    required this.name,
    this.email,
    required this.role,
    this.emailVerified = true,
  });

  bool get isStaff => role == UserRole.agent || role == UserRole.admin;

  bool get isAdmin => role == UserRole.admin;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        role: userRoleFromString(json['role']),
        emailVerified: json['email_verified'] ?? true,
      );
}