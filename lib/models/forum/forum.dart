class Forum {
  final String id;
  final String courseId;
  final String title;
  final String content;
  final String createdBy;
  final String createdByFullName;
  final int replyCount;
  final DateTime createdAt;

  Forum({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    required this.createdBy,
    required this.createdByFullName,
    this.replyCount = 0,
    required this.createdAt,
  });

  factory Forum.fromJson(
      {required Map<String, dynamic> json,
      int? replyCount,
      required String createdByFullName}) {
    return Forum(
      id: json['id'],
      courseId: json['course_id'],
      title: json['title'],
      content: json['content'],
      createdBy: json['created_by'],
      createdByFullName: createdByFullName,
      replyCount: replyCount ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
