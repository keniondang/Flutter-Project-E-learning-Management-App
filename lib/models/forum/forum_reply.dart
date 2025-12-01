class ForumReply {
  final String id;
  final String forumId;
  final String content;
  final String userId;
  final String userFullName;
  final DateTime createdAt;

  ForumReply({
    required this.id,
    required this.forumId,
    required this.content,
    required this.userId,
    required this.userFullName,
    required this.createdAt,
  });

  factory ForumReply.fromJson(
      {required Map<String, dynamic> json, required String userFullName}) {
    return ForumReply(
        id: json['id'],
        forumId: json['forum_id'],
        content: json['content'],
        userId: json['user_id'],
        userFullName: userFullName,
        createdAt: DateTime.parse(json['created_at']));
  }
}
