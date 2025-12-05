class ForumReply {
  final String id;
  final String forumId;
  final String content;
  final String userId;
  final String userFullName;
  final bool userHasAvatar;
  final DateTime createdAt;

  ForumReply({
    required this.id,
    required this.forumId,
    required this.content,
    required this.userId,
    required this.userFullName,
    required this.userHasAvatar,
    required this.createdAt,
  });

  factory ForumReply.fromJson(
      {required Map<String, dynamic> json,
      required String userFullName,
      bool userHasAvatar = false}) {
    return ForumReply(
        id: json['id'],
        forumId: json['forum_id'],
        content: json['content'],
        userId: json['user_id'],
        userFullName: userFullName,
        userHasAvatar: userHasAvatar,
        createdAt: DateTime.parse(json['created_at']));
  }
}
