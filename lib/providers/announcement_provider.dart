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

  // --- CORE METHODS ---

  // ✅ UPDATED: Now requires currentUserId to check "hasViewed" correctly
  Future<void> loadAllAnnouncements(String courseId, String currentUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final Box<Announcement> box = await Hive.openBox<Announcement>(_boxName);
    final cachedAnnouncements = box.values.cast<Announcement>();

    // 1. Load Local Cache
    if (cachedAnnouncements.any((x) => x.courseId == courseId)) {
      _announcements = cachedAnnouncements
          .where((x) => x.courseId == courseId)
          .toList();
      _announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoading = false;
      notifyListeners();
    }

    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      // 2. Enrich Data
      final announcementsList =
          await Future.wait((response as List).map((json) async {
        final id = json['id'];
        
        final results = await Future.wait([
          _fetchViewCount(id),
          _fetchCommentCount(id),
          _checkIfViewed(id, currentUserId), // ✅ Pass userId here
        ]);

        return Announcement.fromJson(
          json: json,
          viewCount: results[0] as int,
          commentCount: results[1] as int,
          hasViewed: results[2] as bool,
        );
      }));

      await box.putAll(
          Map.fromEntries(announcementsList.map((a) => MapEntry(a.id, a))));

      _announcements = announcementsList;
    } catch (e) {
      _error = e.toString();
      print('Error loading announcements: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Announcement?> createAnnouncement({
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
              Announcement.fromJson(json: json, viewCount: 0, commentCount: 0, hasViewed: true))
          .first;

      final box = await Hive.openBox<Announcement>(_boxName);
      await box.put(announcement.id, announcement);
      
      _announcements.insert(0, announcement);
      notifyListeners();
      return announcement;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // --- HELPER METHODS ---

  Future<int> _fetchViewCount(String id) async {
    try {
      return (await _supabase.from('announcement_views').select('id').eq('announcement_id', id).count()).count;
    } catch (_) { return 0; }
  }

  Future<int> _fetchCommentCount(String id) async {
    try {
      return (await _supabase.from('announcement_comments').select('id').eq('announcement_id', id).count()).count;
    } catch (_) { return 0; }
  }

  // ✅ UPDATED: Now requires userId explicitly
  Future<bool> _checkIfViewed(String id, String userId) async {
    try {
      final res = await _supabase.from('announcement_views').select('id').eq('announcement_id', id).eq('user_id', userId).maybeSingle();
      return res != null;
    } catch (_) { return false; }
  }

  // --- SOCIAL METHODS ---

  Future<List<AnnouncementComment>> loadComments(String announcementId) async {
    try {
      final response = await _supabase
          .from('announcement_comments')
          .select('*, users(full_name, avatar_url)') 
          .eq('announcement_id', announcementId)
          .order('created_at', ascending: true);

      return (response as List).map((json) {
        final Map<String, dynamic> adaptedJson = Map.from(json);
        if (json['users'] != null) {
          adaptedJson['user_name'] = json['users']['full_name'];
        } else {
          adaptedJson['user_name'] = 'Unknown User';
        }
        return AnnouncementComment.fromJson(adaptedJson);
      }).toList();
    } catch (e) {
      // Fallback
      try {
        final fallbackResponse = await _supabase
          .from('announcement_comments')
          .select()
          .eq('announcement_id', announcementId)
          .order('created_at', ascending: true);
         return (fallbackResponse as List).map((json) {
            final Map<String, dynamic> adaptedJson = Map.from(json);
            adaptedJson['user_name'] = 'User'; 
            return AnnouncementComment.fromJson(adaptedJson);
         }).toList();
      } catch (e2) {
         return [];
      }
    }
  }

  // ✅ UPDATED: Now requires userId explicitly
  Future<AnnouncementComment?> addComment(String announcementId, String text, String userId) async {
    try {
      final response = await _supabase.from('announcement_comments').insert({
        'announcement_id': announcementId,
        'user_id': userId,
        'comment': text,
      }).select().single();

      final Map<String, dynamic> adaptedJson = Map.from(response);
      adaptedJson['user_name'] = 'Me'; 
      
      final newComment = AnnouncementComment.fromJson(adaptedJson);
      notifyListeners();
      return newComment;
    } catch (e) {
      print('Error adding comment: $e');
      throw e;
    }
  }

  // ✅ UPDATED: Now requires userId explicitly
  Future<void> markAsViewed(String id, String userId) async {
    try {
      await _supabase.from('announcement_views').upsert({
        'announcement_id': id,
        'user_id': userId,
        'viewed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'announcement_id, user_id');
    } catch (_) {}
  }

  // ✅ UPDATED: Now requires userId explicitly
  Future<void> trackDownload(String id, String fileName, String userId) async {
    try {
      await _supabase.from('announcement_downloads').insert({
        'announcement_id': id,
        'user_id': userId,
        'file_name': fileName,
        'downloaded_at': DateTime.now().toIso8601String(), 
      });
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getViewers(String id) async {
    try {
      final res = await _supabase
          .from('announcement_views')
          .select('viewed_at, users(full_name, email, avatar_url)')
          .eq('announcement_id', id)
          .order('viewed_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) { return []; }
  }
}