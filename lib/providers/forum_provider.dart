import 'package:elearning_management_app/models/forum/forum.dart';
import 'package:elearning_management_app/models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForumProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'forum-box';

  List<Forum> _forums = [];
  List<Forum> get forums => _forums;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadForums(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Forum>(_boxName);

    try {
      final response = await _supabase
          .from('forums')
          .select('*, users(full_name), forum_replies(id.count())')
          .eq('course_id', courseId);

      await box.putAll(Map.fromEntries(response.map((json) {
        final String fullName = json['users']['full_name'];
        final forum = Forum.fromJson(
            json: json,
            replyCount: json['forum_replies'][0]['count'] as int,
            createdByFullName: fullName);

        return MapEntry(forum.id, forum);
      })));
    } catch (e) {
      _error = e.toString();
      print('Error loading forums: $e');
    }

    _forums = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createForum(
      String courseId, String title, String content, UserModel user) async {
    try {
      final response = await _supabase.from('forums').insert({
        'course_id': courseId,
        'title': title,
        'content': content,
        'created_by': user.id
      }).select();

      final forum = response
          .map((json) =>
              Forum.fromJson(json: json, createdByFullName: user.fullName))
          .first;

      final box = await Hive.openBox<Forum>(_boxName);

      await box.put(forum.id, forum);
      _forums.add(forum);

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
