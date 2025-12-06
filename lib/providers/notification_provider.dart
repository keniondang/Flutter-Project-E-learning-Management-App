import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'notification-box';

  List<Notification> _notifications = [];
  List<Notification> get notifications => _notifications;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    notifyListeners();

    final box = await Hive.openBox<Notification>(_boxName);

    try {
      final response = await _supabase
          .from('notifications_to')
          .select(
              '*, notifications!notifications_to_notification_id_fkey!inner(*)')
          .eq('user_id', userId)
          .order('created_at', referencedTable: 'notifications')
          .limit(50);

      await box.putAll(Map.fromEntries(response.map((json) {
        final notificationJson = json['notifications'];

        final notification = Notification.fromJson(
            json: notificationJson, userId: userId, isRead: json['is_read']);

        return MapEntry(notification.id, notification);
      })));
    } catch (e) {
      print('Error loading notifications: $e');
    }

    _notifications = box.values.where((x) => x.userId == userId).toList();
    _unreadCount = _notifications.where((n) => !n.isRead).length;

    _isLoading = false;
    notifyListeners();
  }

  RealtimeChannel subscribeNotification(String userId) {
    return _supabase
        .channel('notifications')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications_to',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId),
            callback: (payload) async {
              final notification = await _fetchNotification(payload.newRecord);

              if (notification != null) {
                _notifications.insert(0, notification);

                if (!notification.isRead) {
                  _unreadCount += 1;
                }

                notifyListeners();

                final box = await Hive.openBox<Notification>(_boxName);
                await box.put(notification.id, notification);
              }
            })
        .subscribe();
  }

  Future<void> markAsRead(String notificationId, String userId) async {
    try {
      await _supabase
          .from('notifications_to')
          .update({'is_read': true})
          .eq('notification_id', notificationId)
          .eq('user_id', userId);

      final index = notifications.indexWhere((x) => x.id == notificationId);

      if (index > -1) {
        final notification = _notifications[index];
        notification.isRead = true;

        _notifications[index] = notification;
        _unreadCount -= 1;
        notifyListeners();

        final box = await Hive.openBox<Notification>(_boxName);
        await box.put(notification.id, notification);
      }
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

      final box = await Hive.openBox<Notification>(_boxName);
      await box.putAll(
          Map.fromEntries(_notifications.map((x) => MapEntry(x.id, x))));
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

  Future<Notification?> _fetchNotification(Map<String, dynamic> request) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('id', request['notification_id'])
          .maybeSingle();

      if (response == null) {
        return null;
      } else {
        return Notification.fromJson(
            json: response,
            userId: request['user_id'],
            isRead: request['is_read'] as bool);
      }
    } catch (e) {
      print('Error fetching notification: $e');

      return null;
    }
  }
}
