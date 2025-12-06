import 'dart:io';
import 'dart:typed_data';

import 'package:elearning_management_app/models/course_material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/analytic.dart';

class CourseMaterialProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'material-box';

  List<CourseMaterial> _materials = [];
  List<CourseMaterial> get materials => _materials;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadCourseMaterials(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<CourseMaterial>(_boxName);

    try {
      final response =
          await _supabase.from('materials').select().eq('course_id', courseId);
      // .order('created_at, ascending: false);

      await box
          .putAll(Map.fromEntries(await Future.wait(response.map((json) async {
        final id = json['id'];
        final hasAttachments = json['has_attachments'] as bool;

        final material = CourseMaterial.fromJson(
            json: json,
            fileAttachments:
                hasAttachments ? await _fetchFileAttachmentPaths(id) : null);

        return MapEntry(material.id, material);
      }))));
    } catch (e) {
      _error = e.toString();
      print('Error loading quizzes: $e');
    }

    _materials = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<List<String>> _fetchFileAttachmentPaths(String id) async {
    try {
      return (await _supabase.storage
              .from('materials_attachment')
              .list(path: id))
          .map((x) => '$id/${x.name}')
          .toList();
    } catch (e) {
      print('Error fetching announcement attachments: $e');
      return [];
    }
  }

  Future<bool> createMaterial({
    required String courseId,
    required String instructorId,
    required String title,
    String? description,
    required List<PlatformFile> fileAttachments,
    required List<String> externalLinks,
  }) async {
    try {
      final response = await _supabase
          .from('materials')
          .insert({
            'course_id': courseId,
            'instructor_id': instructorId,
            'title': title,
            'description': description,
            'has_attachments': fileAttachments.isNotEmpty,
            'file_urls': [],
            'external_links': externalLinks,
          })
          .select()
          .single();

      List<String> paths = [];

      if (fileAttachments.isNotEmpty) {
        paths.addAll((await Future.wait(fileAttachments.map((file) async {
          final id = response['id'] as String;

          if (file.bytes != null) {
            return await _supabase.storage
                .from('materials_attachment')
                .uploadBinary('$id/${file.name}', file.bytes!);
          } else if (file.path != null) {
            return await _supabase.storage
                .from('materials_attachment')
                .upload('$id/${file.name}', File(file.path!));
          }

          return '';
        })))
          ..removeWhere((x) => x.isEmpty));
      }

      final material = CourseMaterial.fromJson(
          json: response, fileAttachments: paths.isNotEmpty ? paths : []);

      final box = await Hive.openBox<CourseMaterial>(_boxName);

      await box.put(material.id, material);
      _materials.add(material);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error creating material: $e');

      notifyListeners();
      return false;
    }
  }

  Future<Uint8List?> fetchFileAttachment(String url) async {
    try {
      return await _supabase.storage.from('materials_attachment').download(url);
    } catch (e) {
      print('Error fetching file attachment: $e');
      return null;
    }
  }

  Future<void> markAsViewed(String materialId, String userId) async {
    try {
      await _supabase.from('material_views').upsert({
        'material_id': materialId,
        'user_id': userId,
        'viewed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'material_id, user_id');
    } catch (e) {
      print('Error marking material as viewed: $e');
    }
  }

  Future<void> trackDownload(
      String materialId, String userId, String fileName) async {
    try {
      await _supabase.from('material_downloads').upsert({
        'material_id': materialId,
        'user_id': userId,
        'file_name': fileName,
        'downloaded_at': DateTime.now().toIso8601String(),
      }, onConflict: 'material_id, user_id');
    } catch (e) {
      print('Error tracking material download: $e');
    }
  }

  Future<List<ViewAnalytic>> fetchViewAnalytics(String materialId) async {
    final box = await Hive.openBox('material-view-analytics');

    try {
      final response = await _supabase
          .from('material_views')
          .select('user_id, viewed_at')
          .eq('material_id', materialId);

      await box.put(materialId,
          response.map((json) => ViewAnalytic.fromJson(json)).toList());
    } catch (e) {
      print('Error fetching view analytics: $e');
    }

    return box.get(materialId) ?? [];
  }

  Future<List<DownloadAnalytic>> fetchDownloadAnalytics(
      String materialId, String userId) async {
    final box = await Hive.openBox('material-download-analytics');

    try {
      final response = await _supabase
          .from('material_downloads')
          .select('file_name, downloaded_at')
          .eq('material_id', materialId)
          .eq('user_id', userId);

      await box.put(materialId + userId,
          response.map((json) => DownloadAnalytic.fromJson(json)).toList());
    } catch (e) {
      print('Error fetching view analytics: $e');
    }

    return box.get(materialId + userId) ?? [];
  }
}
