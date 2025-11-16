class Course {
  final String id;
  final String semesterId;
  final String code;
  final String name;
  final int sessions;
  final String? coverImage;
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

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      semesterId: json['semester_id'],
      code: json['code'],
      name: json['name'],
      sessions: json['sessions'],
      coverImage: json['cover_image'],
      createdAt: DateTime.parse(json['created_at']),
      semesterName: json['semester_name'],
      groupCount: json['group_count'],
      studentCount: json['student_count'],
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
