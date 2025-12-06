import 'dart:io';
import 'dart:typed_data';

import 'package:elearning_management_app/models/analytic.dart';
import 'package:elearning_management_app/models/announcement.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  final _boxName = 'announcement-box';
  final _boxCommentName = 'announcement-comment-box';

  List<Announcement> _announcements = [];
  List<Announcement> get announcements => _announcements;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // --- CORE METHODS ---
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
            _fetchCommentCount(id),
            _fetchFileAttachmentPaths(id),
          ]);

          return Announcement.fromJson(
            json: json,
            commentCount: results[0] as int,
            fileAttachments: results[1] as List<String>,
          );
        } else {
          return Announcement.fromJson(
              json: json, commentCount: await _fetchCommentCount(id));
        }
      }));

      await box.putAll(
          Map.fromEntries(announcementsList.map((a) => MapEntry(a.id, a))));
    } catch (e) {
      _error = e.toString();
      print('Error loading announcements: $e');
    }

    _announcements = box.values.where((x) => x.courseId == courseId).toList();

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
            _fetchCommentCount(id),
            _fetchFileAttachmentPaths(id),
          ]);

          return Announcement.fromJson(
            json: json,
            commentCount: results[0] as int,
            fileAttachments: results[1] as List<String>,
          );
        } else {
          return Announcement.fromJson(
              json: json, commentCount: await _fetchCommentCount(id));
        }
      }));

      await box.putAll(
          Map.fromEntries(announcementsList.map((a) => MapEntry(a.id, a))));
    } catch (e) {
      _error = e.toString();
      print('Error loading announcements: $e');
    }

    _announcements = box.values.where((x) => x.courseId == courseId).toList();

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
          commentCount: 0,
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

  // Future<int> _fetchViewCount(String id) async {
  //   try {
  //     return (await _supabase
  //             .from('announcement_views')
  //             .select('id')
  //             .eq('announcement_id', id)
  //             .count())
  //         .count;
  //   } catch (_) {
  //     return 0;
  //   }
  // }

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

  // Future<bool> _checkIfViewed(String id, String userId) async {
  //   try {
  //     final res = await _supabase
  //         .from('announcement_views')
  //         .select('id')
  //         .eq('announcement_id', id)
  //         .eq('user_id', userId)
  //         .maybeSingle();
  //     return res != null;
  //   } catch (_) {
  //     return false;
  //   }
  // }

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
    final box = await Hive.openBox<AnnouncementComment>(_boxCommentName);

    try {
      final response = await _supabase
          .from('announcement_comments')
          .select()
          .eq('announcement_id', announcementId);

      await box.putAll(Map.fromEntries(response.map((json) {
        final announcementComment = AnnouncementComment.fromJson(json);

        return MapEntry(announcementComment.id, announcementComment);
      })));
    } catch (e) {
      print('Error loading announcement\'s comments: $e');
    }

    return box.values.where((x) => x.announcementId == announcementId).toList();
  }

  Future<AnnouncementComment?> addComment(
      String announcementId, String text, String userId) async {
    try {
      final response = await _supabase
          .from('announcement_comments')
          .insert({
            'announcement_id': announcementId,
            'user_id': userId,
            'comment': text
          })
          .select()
          .single();

      final comment = AnnouncementComment.fromJson(response);
      final box = await Hive.openBox<AnnouncementComment>(_boxCommentName);

      box.put(comment.id, comment);

      return comment;
    } catch (e) {
      _error = e.toString();
      print('Error adding comment: $e');

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
    } catch (e) {
      print('Error marking announcement as viewed: $e');
    }
  }

  Future<void> trackDownload(
      String announcementId, String userId, String fileName) async {
    try {
      await _supabase.from('announcement_downloads').upsert({
        'announcement_id': announcementId,
        'user_id': userId,
        'file_name': fileName,
        'downloaded_at': DateTime.now().toIso8601String(),
      }, onConflict: 'announcement_id, user_id');
    } catch (e) {
      print('Error tracking announcement download: $e');
    }
  }

  Future<List<ViewAnalytic>> fetchViewAnalytics(String announcementId) async {
    final box = await Hive.openBox('announcement-view-analytics');

    try {
      final response = await _supabase
          .from('announcement_views')
          .select('user_id, viewed_at')
          .eq('announcement_id', announcementId);

      await box.put(announcementId,
          response.map((json) => ViewAnalytic.fromJson(json)).toList());
    } catch (e) {
      print('Error fetching view analytics: $e');
    }

    return box.get(announcementId) ?? [];
  }

  Future<List<DownloadAnalytic>> fetchDownloadAnalytics(
      String announcementId, String userId) async {
    final box = await Hive.openBox('announcement-download-analytics');

    try {
      final response = await _supabase
          .from('announcement_downloads')
          .select('file_name, downloaded_at')
          .eq('announcement_id', announcementId)
          .eq('user_id', userId);

      await box.put(announcementId + userId,
          response.map((json) => DownloadAnalytic.fromJson(json)).toList());
    } catch (e) {
      print('Error fetching view analytics: $e');
    }

    return box.get(announcementId + userId) ?? [];
  }
}
