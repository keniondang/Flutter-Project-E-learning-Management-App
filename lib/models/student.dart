import 'user_model.dart';

class Student extends UserModel {
  Map<String, String> groupMap;
  Set<String> courseIds;

  Student({
    required super.id,
    required super.email,
    required super.username,
    required super.fullName,
    super.avatarUrl,
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
      groupMap: groupMap ?? {},
      courseIds: courseIds ?? {},
    );
  }
}
