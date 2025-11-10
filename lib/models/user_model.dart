class UserModel {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      role: json['role'],
      avatarUrl: json['avatar_url'],
    );
  }

  bool get isInstructor => role == 'instructor';
  bool get isStudent => role == 'student';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is UserModel &&
      other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}