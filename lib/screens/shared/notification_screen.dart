import 'package:elearning_management_app/models/notification.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../providers/notification_provider.dart';

class NotificationScreen extends StatefulWidget {
  final UserModel user;

  const NotificationScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    await context.read<NotificationProvider>().loadNotifications(
          widget.user.id,
        );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      // case 'announcement':
      //   return Icons.announcement;
      // case 'assignment':
      //   return Icons.assignment;
      // case 'quiz':
      //   return Icons.quiz;
      // case 'grade':
      //   return Icons.grade;
      // case 'message':
      //   return Icons.message;
      // case 'deadline':
      //   return Icons.event;
      // default:
      //   return Icons.notifications;
      case NotificationType.announcement:
        return Icons.announcement;
      case NotificationType.deadline:
        return Icons.event;
      case NotificationType.feedback:
        return Icons.event_note;
      case NotificationType.submission:
        return Icons.event_available;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      // case 'announcement':
      //   return Colors.blue;
      // case 'assignment':
      //   return Colors.green;
      // case 'quiz':
      //   return Colors.purple;
      // case 'grade':
      //   return Colors.orange;
      // case 'message':
      //   return Colors.teal;
      // case 'deadline':
      //   return Colors.red;
      // default:
      //   return Colors.grey;
      case NotificationType.announcement:
        return Colors.blue;
      case NotificationType.deadline:
        return Colors.red;
      case NotificationType.feedback:
        return Colors.teal;
      case NotificationType.submission:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<NotificationProvider>().markAllAsRead(
                    widget.user.id,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications marked as read'),
                ),
              );
            },
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re all caught up!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.notifications.length,
            itemBuilder: (context, index) {
              final notification = provider.notifications[index];
              final isRead = notification.isRead;
              final createdAt = notification.createdAt;

              return Card(
                color: isRead ? null : Colors.blue[50],
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getNotificationColor(
                      notification.type,
                    ).withOpacity(0.2),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      color: _getNotificationColor(notification.type),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: GoogleFonts.poppins(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.message,
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, HH:mm').format(createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!isRead) {
                      await provider.markAsRead(
                          notification.id, widget.user.id);
                    }

                    // // Navigate to related content if applicable
                    // if (notification['related_id'] != null) {
                    //   // TODO: Navigate based on related_type
                    // }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
