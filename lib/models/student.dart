import 'user_model.dart';

class Student extends UserModel {
  // final String? groupId;
  // final String? groupName;
  // final String? courseId;
  // final String? courseName;
  Map<String, String> groupMap;
  Set<String> courseIds;

  Student({
    required super.id,
    required super.email,
    required super.username,
    required super.fullName,
    super.avatarUrl,
    // this.groupId,
    // this.groupName,
    // this.courseId,
    // this.courseName,
    Map<String, String>? groupMap,
    Set<String>? courseIds,
  })  : groupMap = groupMap ?? {},
        courseIds = courseIds ?? {},
        super(
          role: 'student',
        );

  factory Student.fromJson(
      {required Map<String, dynamic> json,
      Map<String, String>? groupMap,
      Set<String>? courseIds}) {
    return Student(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      // groupId: json['group_id'],
      // groupName: json['group_name'],
      // courseId: json['course_id'],
      // courseName: json['course_name'],

      groupMap: groupMap ?? {},
      courseIds: courseIds ?? {},
    );
  }
}
