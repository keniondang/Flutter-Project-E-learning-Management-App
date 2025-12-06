class ForumReply {
  final String id;
  final String forumId;
  final String content;
  final String userId;
  final DateTime createdAt;

  ForumReply({
    required this.id,
    required this.forumId,
    required this.content,
    required this.userId,
    required this.createdAt,
  });

  factory ForumReply.fromJson(Map<String, dynamic> json) {
    return ForumReply(
        id: json['id'],
        forumId: json['forum_id'],
        content: json['content'],
        userId: json['user_id'],
        createdAt: DateTime.parse(json['created_at']));
  }
}
