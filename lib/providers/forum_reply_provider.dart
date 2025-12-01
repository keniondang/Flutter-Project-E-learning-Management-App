import 'package:elearning_management_app/models/forum/forum_reply.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class ForumReplyProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'forum-reply-box';

  List<ForumReply> _forumReplies = [];
  List<ForumReply> get forumReplies => _forumReplies;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadForumReplies(String forumId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<ForumReply>(_boxName);

    try {
      final response = await _supabase
          .from('forum_replies')
          .select('*, users(full_name)')
          .eq('forum_id', forumId);

      await box.putAll(Map.fromEntries(response.map((json) {
        final String fullName = json['users']['full_name'];
        final forumReply =
            ForumReply.fromJson(json: json, userFullName: fullName);

        return MapEntry(forumReply.id, forumReply);
      })));
    } catch (e) {
      _error = e.toString();
      print('Error loading forums: $e');
    }

    _forumReplies = box.values.where((x) => x.forumId == forumId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createForumReply(
      String forumId, String content, UserModel user) async {
    try {
      final response = await _supabase.from('forum_replies').insert({
        'forum_id': forumId,
        'content': content,
        'user_id': user.id,
      }).select();

      final forumReply = response
          .map((json) =>
              ForumReply.fromJson(json: json, userFullName: user.fullName))
          .first;

      final box = await Hive.openBox<ForumReply>(_boxName);

      await box.put(forumReply.id, forumReply);
      _forumReplies.add(forumReply);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error creating forum: $e');

      notifyListeners();
      return false;
    }
  }
}
