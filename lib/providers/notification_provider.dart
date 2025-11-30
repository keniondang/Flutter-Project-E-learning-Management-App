import 'package:flutter/material.dart' hide Notification;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Notification> _notifications = [];
  List<Notification> get notifications => _notifications;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('notifications_to')
          .select(
              '*, notifications!notifications_to_notification_id_fkey!inner(*)')
          .eq('user_id', userId)
          // .order('notifications.created_at', ascending: false)
          .limit(50);

      _notifications = response.map((json) {
        final notificationJson = json['notifications'];

        return Notification.fromJson(
            json: notificationJson, isRead: json['is_read']);
      }).toList();

      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId, String userId) async {
    try {
      await _supabase
          .from('notifications_to')
          .update({'is_read': true})
          .eq('notification_id', notificationId)
          .eq('user_id', userId);

      _notifications[notifications.indexWhere((x) => x.id == notificationId)]
          .isRead = true;
      _unreadCount -= 1;
      notifyListeners();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications_to')
          .update({'is_read': true}).eq('user_id', userId);

      for (var notification in _notifications) {
        notification.isRead = true;
      }

      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      print('Error marking all notification as read: $e');
    }
  }

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? relatedId,
    String? relatedType,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'related_id': relatedId,
        'related_type': relatedType,
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }
}
