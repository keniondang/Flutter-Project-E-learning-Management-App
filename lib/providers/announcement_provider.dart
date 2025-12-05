import 'dart:io';
import 'dart:typed_data';

import 'package:elearning_management_app/models/announcement.dart';
import 'package:elearning_management_app/models/user_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

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
  Future<void> loadAllAnnouncements(
      String courseId, String currentUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Announcement>(_boxName);

    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('course_id', courseId);

      // 2. Enrich Data
      final announcementsList =
          await Future.wait((response as List).map((json) async {
        final id = json['id'];
        final hasAttachments = json['has_attachments'] as bool;

        if (hasAttachments) {
          final results = await Future.wait([
            _fetchViewCount(id),
            _fetchCommentCount(id),
            _checkIfViewed(id, currentUserId), // ✅ Pass userId here
            _fetchFileAttachmentPaths(id),
          ]);

          return Announcement.fromJson(
            json: json,
            viewCount: results[0] as int,
            commentCount: results[1] as int,
            hasViewed: results[2] as bool,
            fileAttachments: results[3] as List<String>,
          );
        } else {
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
        }
      }));

      await box.putAll(
          Map.fromEntries(announcementsList.map((a) => MapEntry(a.id, a))));
    } catch (e) {
      _error = e.toString();
      print('Error loading announcements: $e');
    }

    _announcements = box.values.where((x) => x.courseId == courseId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAnnouncements(
      String courseId, String currentUserId, String? groupId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Announcement>(_boxName);

    try {
      late List<Map<String, dynamic>> response;

      if (groupId == null) {
        response = await _supabase
            .from('announcements')
            .select()
            .eq('course_id', courseId)
            .eq('scope_type', 'all');
      } else {
        response = await _supabase
            .from('announcements')
            .select()
            .eq('course_id', courseId)
            .or('scope_type.eq.all,target_groups.cs.{$groupId}');
      }

      final announcementsList =
          await Future.wait((response as List).map((json) async {
        final id = json['id'];

        final hasAttachments = json['has_attachments'] as bool;

        if (hasAttachments) {
          final results = await Future.wait([
            _fetchViewCount(id),
            _fetchCommentCount(id),
            _checkIfViewed(id, currentUserId), // ✅ Pass userId here
            _fetchFileAttachmentPaths(id),
          ]);

          return Announcement.fromJson(
            json: json,
            viewCount: results[0] as int,
            commentCount: results[1] as int,
            hasViewed: results[2] as bool,
            fileAttachments: results[3] as List<String>,
          );
        } else {
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
        }
      }));

      await box.putAll(
          Map.fromEntries(announcementsList.map((a) => MapEntry(a.id, a))));
    } catch (e) {
      _error = e.toString();
      print('Error loading announcements: $e');
    }

    _announcements = box.values.where((x) => x.courseId == courseId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createAnnouncement({
    required String courseId,
    required String instructorId,
    required String title,
    required String content,
    required List<PlatformFile> fileAttachments,
    required String scopeType,
    required List<String> targetGroups,
  }) async {
    try {
      final response = await _supabase
          .from('announcements')
          .insert({
            'course_id': courseId,
            'instructor_id': instructorId,
            'title': title,
            'content': content,
            'has_attachments': fileAttachments.isNotEmpty,
            'scope_type': scopeType,
            'target_groups': targetGroups,
          })
          .select()
          .single();

      List<String> paths = [];

      if (fileAttachments.isNotEmpty) {
        paths.addAll((await Future.wait(fileAttachments.map((file) async {
          final id = response['id'] as String;

          if (file.bytes != null) {
            return await _supabase.storage
                .from('announcements_attachment')
                .uploadBinary('$id/${file.name}', file.bytes!);
          } else if (file.path != null) {
            return await _supabase.storage
                .from('announcements_attachment')
                .upload('$id/${file.name}', File(file.path!));
          }

          return '';
        })))
          ..removeWhere((x) => x.isEmpty));
      }

      final announcement = Announcement.fromJson(
          json: response,
          viewCount: 0,
          commentCount: 0,
          hasViewed: true,
          fileAttachments: paths.isNotEmpty ? paths : null);

      final box = await Hive.openBox<Announcement>(_boxName);
      await box.put(announcement.id, announcement);

      _announcements.insert(0, announcement);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }

  Future<Uint8List?> fetchFileAttachment(String url) async {
    try {
      return await _supabase.storage
          .from('announcements_attachment')
          .download(url);
    } catch (e) {
      print('Error fetching file attachment: $e');
      return null;
    }
  }

  // --- HELPER METHODS ---

  Future<int> _fetchViewCount(String id) async {
    try {
      return (await _supabase
              .from('announcement_views')
              .select('id')
              .eq('announcement_id', id)
              .count())
          .count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchCommentCount(String id) async {
    try {
      return (await _supabase
              .from('announcement_comments')
              .select('id')
              .eq('announcement_id', id)
              .count())
          .count;
    } catch (_) {
      return 0;
    }
  }

  // ✅ UPDATED: Now requires userId explicitly
  Future<bool> _checkIfViewed(String id, String userId) async {
    try {
      final res = await _supabase
          .from('announcement_views')
          .select('id')
          .eq('announcement_id', id)
          .eq('user_id', userId)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _fetchFileAttachmentPaths(String id) async {
    try {
      return (await _supabase.storage
              .from('announcements_attachment')
              .list(path: id))
          .map((x) => '$id/${x.name}')
          .toList();
    } catch (e) {
      print('Error fetching announcement attachments: $e');
      return [];
    }
  }

  // --- SOCIAL METHODS ---

  Future<List<AnnouncementComment>> loadComments(String announcementId) async {
    try {
      final response = await _supabase
          .from('announcement_comments')
          .select('*, users(full_name, has_avatar)')
          .eq('announcement_id', announcementId)
          .order('created_at', ascending: true);

      return response
          .map((json) => AnnouncementComment.fromJson(
              json: json,
              userName: json['users']['full_name'],
              userHasAvatar: json['users']['has_avatar']))
          .toList();
    } catch (e) {
      print('Error loading announcement\'s comments: $e');
      return [];
    }
  }

  // ✅ UPDATED: Now requires userId explicitly
  Future<Map<String, dynamic>?> addComment(
      String announcementId, String text, String userId) async {
    try {
      final response = await _supabase
          .from('announcement_comments')
          .insert({
            'announcement_id': announcementId,
            'user_id': userId,
            'comment': text,
          })
          .select()
          .single();

      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      print('Error adding comment: $e');

      notifyListeners();
      return null;
    }
  }

  Future<void> markAsViewed(String id, String userId) async {
    try {
      await _supabase.from('announcement_views').upsert({
        'announcement_id': id,
        'user_id': userId,
        'viewed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'announcement_id, user_id');
    } catch (_) {}
  }

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

  Future<List<({UserModel user, DateTime viewAt})>> getAnalytics(
      String id) async {
    try {
      final response = await _supabase
          .from('announcement_views')
          .select('viewed_at, users(*)')
          .eq('announcement_id', id)
          .order('viewed_at', ascending: false);
      final users = response.map((json) {
        final userJson = json['users'];
        return (
          user: UserModel.fromJson(json: userJson),
          viewAt: DateTime.parse(json['viewed_at'])
        );
      }).toList();

      return users;
    } catch (_) {
      return [];
    }
  }
}
