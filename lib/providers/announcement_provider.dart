import 'package:elearning_management_app/models/announcement.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'announcement-box';

  List<Announcement> _announcements = [];
  List<Announcement> get announcements => _announcements;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadAnnouncements(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Announcement>(_boxName);

    if (!box.values.any((x) => x.courseId == courseId)) {
      try {
        final response = await _supabase
            .from('announcements')
            .select()
            .eq('course_id', courseId);

        await box.putAll(
            Map.fromEntries(await Future.wait(response.map((json) async {
          final announcement = Announcement.fromJson(
              json: json,
              viewCount: await _fetchViewCount(json['id']),
              commentCount: await _fetchCommentCount(json['id']));

          return MapEntry(announcement.id, announcement);
        }))));
      } catch (e) {
        _error = e.toString();
        print('Error loading quizzes: $e');
      }
    }

    _announcements = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<int> _fetchViewCount(String announcementId) async {
    try {
      final response = await _supabase
          .from('announcement_views')
          .select('id')
          .eq('announcement_id', announcementId)
          .count();

      return response.count;
    } catch (e) {
      print('Error loading announcement: $e');
      return 0;
    }
  }

  Future<int> _fetchCommentCount(String announcementId) async {
    try {
      final response = await _supabase
          .from('announcement_comments')
          .select('id')
          .eq('announcement_id', announcementId)
          .count();

      return response.count;
    } catch (e) {
      print('Error loading announcement: $e');
      return 0;
    }
  }

  Future<bool> createAnnouncement({
    required String courseId,
    required String instructorId,
    required String title,
    required String content,
    required List<String> fileAttachments,
    required String scopeType,
    required List<String> targetGroups,
  }) async {
    try {
      final response = await _supabase.from('announcements').insert({
        'course_id': courseId,
        'instructor_id': instructorId,
        'title': title,
        'content': content,
        'file_attachments': fileAttachments,
        'scope_type': scopeType,
        'target_groups': targetGroups,
      }).select();

      final announcement = response
          .map((json) =>
              Announcement.fromJson(json: json, viewCount: 0, commentCount: 0))
          .first;

      final box = await Hive.openBox<Announcement>(_boxName);

      await box.put(announcement.id, announcement);
      _announcements.add(announcement);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }
}
