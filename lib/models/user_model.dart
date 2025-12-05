import 'dart:typed_data';

class UserModel {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final List<int>? avatarBytes;
  final bool hasAvatar;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.hasAvatar,
    this.avatarBytes,
  });

  factory UserModel.fromJson(
      {required Map<String, dynamic> json, Uint8List? avatarBytes}) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      role: json['role'],
      hasAvatar: json['has_avatar'],
      avatarBytes: avatarBytes,
    );
  }

  bool get isInstructor => role == 'instructor';
  bool get isStudent => role == 'student';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
