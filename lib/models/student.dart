import 'user_model.dart';

class Student extends UserModel {
  final String? groupId;
  final String? groupName;
  final String? courseId;
  final String? courseName;

  Student({
    required String id,
    required String email,
    required String username,
    required String fullName,
    String? avatarUrl,
    this.groupId,
    this.groupName,
    this.courseId,
    this.courseName,
  }) : super(
    id: id,
    email: email,
    username: username,
    fullName: fullName,
    role: 'student',
    avatarUrl: avatarUrl,
  );

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      groupId: json['group_id'],
      groupName: json['group_name'],
      courseId: json['course_id'],
      courseName: json['course_name'],
    );
  }
}