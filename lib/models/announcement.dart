class Announcement {
  final String id;
  final String courseId;
  final String instructorId;
  final String title;
  final String content;
  final List<String> fileAttachments;
  final String scopeType;
  final List<String> targetGroups;
  final DateTime createdAt;
  final int? viewCount;
  final int? commentCount;
  final bool? hasViewed;

  Announcement({
    required this.id,
    required this.courseId,
    required this.instructorId,
    required this.title,
    required this.content,
    required this.fileAttachments,
    required this.scopeType,
    required this.targetGroups,
    required this.createdAt,
    this.viewCount,
    this.commentCount,
    this.hasViewed,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      courseId: json['course_id'],
      instructorId: json['instructor_id'],
      title: json['title'],
      content: json['content'],
      fileAttachments: List<String>.from(json['file_attachments'] ?? []),
      scopeType: json['scope_type'],
      targetGroups: List<String>.from(json['target_groups'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      viewCount: json['view_count'],
      commentCount: json['comment_count'],
      hasViewed: json['has_viewed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'instructor_id': instructorId,
      'title': title,
      'content': content,
      'file_attachments': fileAttachments,
      'scope_type': scopeType,
      'target_groups': targetGroups,
    };
  }
}

class AnnouncementComment {
  final String id;
  final String announcementId;
  final String userId;
  final String userName;
  final String comment;
  final DateTime createdAt;

  AnnouncementComment({
    required this.id,
    required this.announcementId,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.createdAt,
  });

  factory AnnouncementComment.fromJson(Map<String, dynamic> json) {
    return AnnouncementComment(
      id: json['id'],
      announcementId: json['announcement_id'],
      userId: json['user_id'],
      userName: json['user_name'] ?? 'Unknown',
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
