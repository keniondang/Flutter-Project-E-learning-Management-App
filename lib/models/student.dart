import 'dart:typed_data';

import 'user_model.dart';

class Student extends UserModel {
  Map<String, String> groupMap;
  Set<String> courseIds;

  Student({
    required super.id,
    required super.email,
    required super.username,
    required super.fullName,
    required super.hasAvatar,
    super.avatarBytes,
    Map<String, String>? groupMap,
    Set<String>? courseIds,
  })  : groupMap = groupMap ?? {},
        courseIds = courseIds ?? {},
        super(
          role: 'student',
        );

  factory Student.fromJson(
      {required Map<String, dynamic> json,
      Uint8List? avatarByes,
      Map<String, String>? groupMap,
      Set<String>? courseIds}) {
    return Student(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      hasAvatar: json['has_avatar'],
      avatarBytes: avatarByes,
      groupMap: groupMap ?? {},
      courseIds: courseIds ?? {},
    );
  }
}
