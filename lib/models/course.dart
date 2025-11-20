class Course {
  final String id;
  final String semesterId;
  String code;
  String name;
  int sessions;
  String? coverImage;
  final DateTime createdAt;

  // Additional fields for display
  final String? semesterName;
  final int? groupCount;
  final int? studentCount;

  Course({
    required this.id,
    required this.semesterId,
    required this.code,
    required this.name,
    required this.sessions,
    this.coverImage,
    required this.createdAt,
    this.semesterName,
    this.groupCount,
    this.studentCount,
  });

  factory Course.fromJson(
      {required Map<String, dynamic> json,
      semesterName,
      groupCount,
      studentCount}) {
    return Course(
      id: json['id'],
      semesterId: json['semester_id'],
      code: json['code'],
      name: json['name'],
      sessions: json['sessions'],
      coverImage: json['cover_image'],
      createdAt: DateTime.parse(json['created_at']),
      // semesterName: json['semester_name'],
      // groupCount: json['group_count'],
      // studentCount: json['student_count'],
      semesterName: semesterName ?? json['semester_name'],
      groupCount: groupCount ?? 0,
      studentCount: studentCount ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'semester_id': semesterId,
      'code': code,
      'name': name,
      'sessions': sessions,
      'cover_image': coverImage,
    };
  }
}
