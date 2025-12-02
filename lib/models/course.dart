class Course {
  final String id;
  final String semesterId;
  String code;
  String name;
  int sessions;
  String? coverImage;
  final DateTime createdAt;
  final String? instructorId;
  late Set<String> groupIds;
  // late Set<String> studentIds;

  // Additional fields for display
  final String? semesterName;
  int get groupCount => groupIds.length;
  int? studentCount;
  // int get studentCount => studentIds.length;

  Course({
    required this.id,
    required this.semesterId,
    required this.code,
    required this.name,
    required this.sessions,
    this.coverImage,
    required this.createdAt,
    required this.instructorId,
    this.semesterName,
    Set<String>? groupIds,
    // this.groupCount,
    this.studentCount,
  }) : groupIds = groupIds ?? {};

  factory Course.fromJson({
    required Map<String, dynamic> json,
    String? semesterName,
    Set<String>? groupIds,
    int? studentCount,
  }) {
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
      groupIds: groupIds,
      studentCount: studentCount,
      // studentIds: studentIds,
      instructorId: json['instructor_id'] ?? '',  // Add this
      // groupCount: groupCount ?? 0,
      // studentCount: studentCount ?? 0,
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
