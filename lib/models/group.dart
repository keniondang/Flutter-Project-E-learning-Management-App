class Group {
  final String id;
  final String courseId;
  final String name;
  final DateTime createdAt;

  // Additional fields for display
  final String? courseName;
  final int? studentCount;

  Group({
    required this.id,
    required this.courseId,
    required this.name,
    required this.createdAt,
    this.courseName,
    this.studentCount,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      courseId: json['course_id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
      courseName: json['course_name'],
      studentCount: json['student_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'course_id': courseId, 'name': name};
  }
}
