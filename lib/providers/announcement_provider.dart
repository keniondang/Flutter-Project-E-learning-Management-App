import 'package:elearning_management_app/models/announcement.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  int? _semesterCount;
  int? get semesterCount => _semesterCount;

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

    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      _announcements = (response as List)
          .map((json) => Announcement.fromJson(json))
          .toList();

      // Load view counts and comment counts
      for (var announcement in _announcements) {
        await _loadAnnouncementStats(announcement);
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading quizzes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> countForSemester(String semesterId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('announcements')
          .select('id, courses(id)')
          .eq('courses.semester_id', semesterId)
          .count(CountOption.estimated);

      _semesterCount = response.count;
    } catch (e) {
      _error = e.toString();
      print('Error loading quizzes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAnnouncementStats(Announcement announcement) async {
    try {
      // Get view count
      final viewResponse = await _supabase
          .from('announcement_views')
          .select('id')
          .eq('announcement_id', announcement.id);

      // Get comment count
      final commentResponse = await _supabase
          .from('announcement_comments')
          .select('id')
          .eq('announcement_id', announcement.id);

      final index = _announcements.indexWhere((a) => a.id == announcement.id);
      if (index != -1) {
        _announcements[index] = Announcement(
          id: announcement.id,
          courseId: announcement.courseId,
          instructorId: announcement.instructorId,
          title: announcement.title,
          content: announcement.content,
          fileAttachments: announcement.fileAttachments,
          scopeType: announcement.scopeType,
          targetGroups: announcement.targetGroups,
          createdAt: announcement.createdAt,
          viewCount: (viewResponse as List).length,
          commentCount: (commentResponse as List).length,
        );
      }
    } catch (e) {
      print('Error loading announcement stats: $e');
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
      await _supabase.from('announcements').insert({
        'course_id': courseId,
        'instructor_id': instructorId,
        'title': title,
        'content': content,
        'file_attachments': fileAttachments,
        'scope_type': scopeType,
        'target_groups': targetGroups,
      });

      await loadAnnouncements(courseId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
