class Forum {
  final String id;
  final String courseId;
  final String title;
  final String content;
  final String createdBy;
  final int replyCount;
  final DateTime createdAt;

  Forum({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    required this.createdBy,
    this.replyCount = 0,
    required this.createdAt,
  });

  factory Forum.fromJson(
      {required Map<String, dynamic> json, int? replyCount}) {
    return Forum(
      id: json['id'],
      courseId: json['course_id'],
      title: json['title'],
      content: json['content'],
      createdBy: json['created_by'],
      replyCount: replyCount ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
