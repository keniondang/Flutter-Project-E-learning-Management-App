enum NotificationType { announcement, deadline, feedback, submission }

class Notification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  factory Notification.fromJson(
          {required Map<String, dynamic> json,
          required String userId,
          bool? isRead}) =>
      Notification(
        id: json['id'] as String,
        userId: userId,
        type: NotificationType.values.byName(json['type']),
        title: json['title'] as String,
        message: json['message'] as String,
        isRead: isRead ?? false,
        createdAt: DateTime.parse(json['created_at']),
      );
}
