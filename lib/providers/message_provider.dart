import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';

class MessageProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'private-message-box';

  List<PrivateMessage> _messages = [];
  List<PrivateMessage> get messages => _messages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Load conversation between Current User and Target User
  Future<void> loadConversation(
      String currentUserId, String otherUserId) async {
    _isLoading = true;
    _messages = []; // Clear previous chat
    notifyListeners();

    final box = await Hive.openBox<PrivateMessage>(_boxName);

    try {
      // Fetch messages where (sender=Me AND receiver=Other) OR (sender=Other AND receiver=Me)
      final response = await _supabase
          .from('private_messages')
          .select()
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
          .order('created_at', ascending: true);

      await box.putAll(Map.fromEntries(response.map((json) {
        final message = PrivateMessage.fromJson(json);

        return MapEntry(message.id, message);
      })));

      // Mark received messages as read
      _markAsRead(currentUserId, otherUserId);
    } catch (e) {
      print('Error loading messages: $e');
    }

    _messages = box.values
        .where((x) =>
            (x.senderId == currentUserId && x.receiverId == otherUserId) ||
            (x.senderId == otherUserId && x.receiverId == currentUserId))
        .toList();

    _isLoading = false;
    notifyListeners();
  }

  RealtimeChannel subscribeMessages(String currentUserId, String otherUserId) {
    return _supabase
        .channel('messages')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'private_messages',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'receiver_id',
                value: currentUserId),
            callback: (payload) {
              final message = PrivateMessage.fromJson(payload.newRecord);

              if (message.senderId == otherUserId) {
                _messages.add(message);
                notifyListeners();
              }
            })
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'private_messages',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'receiver_id',
                value: currentUserId),
            callback: (payload) async {
              final message = PrivateMessage.fromJson(payload.newRecord);

              if (message.senderId == otherUserId) {
                _messages[_messages.indexWhere((x) => x.id == message.id)] =
                    message;
                notifyListeners();

                final box = await Hive.openBox<PrivateMessage>(_boxName);
                box.put(message.id, message);
              }
            })
        .subscribe();
  }

  // Send a message
  Future<void> sendMessage(
      String senderId, String receiverId, String content) async {
    try {
      final response = await _supabase
          .from('private_messages')
          .insert({
            'sender_id': senderId,
            'receiver_id': receiverId,
            'content': content,
          })
          .select()
          .single();

      final message = PrivateMessage.fromJson(response);
      _messages.add(message);
      notifyListeners();

      final box = await Hive.openBox<PrivateMessage>(_boxName);
      box.put(message.id, message);
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> _markAsRead(String currentUserId, String senderId) async {
    try {
      await _supabase
          .from('private_messages')
          .update({'is_read': true})
          .eq('receiver_id', currentUserId)
          .eq('sender_id', senderId)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking read: $e');
    }
  }
}
