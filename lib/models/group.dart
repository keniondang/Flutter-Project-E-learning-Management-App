class Group {
  final String id;
  final String courseId;
  final String name;
  final DateTime createdAt;

  // Additional fields for display
  final String? courseName;
  final int? studentCount;

  final String? semesterId;

  Group({
    required this.id,
    required this.courseId,
    required this.name,
    required this.createdAt,
    this.courseName,
    this.studentCount,
    this.semesterId,
  });

  factory Group.fromJson(
      {required Map<String, dynamic> json,
      String? courseName,
      int? studentCount,
      String? semesterId}) {
    return Group(
        id: json['id'],
        courseId: json['course_id'],
        name: json['name'],
        createdAt: DateTime.parse(json['created_at']),
        courseName: courseName ?? json['course_name'],
        studentCount: studentCount ?? json['student_count'],
        semesterId: semesterId ?? json['semesterId']);
  }

  Map<String, dynamic> toJson() {
    return {'course_id': courseId, 'name': name};
  }
}
