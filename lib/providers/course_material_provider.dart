import 'dart:io';
import 'dart:typed_data';

import 'package:elearning_management_app/models/course_material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

        late CourseMaterial material;

        if (hasAttachments) {
          final results = await Future.wait(
              [_fetchStats(id), _fetchFileAttachmentPaths(id)]);
          final (viewCount, downloadCount) = results[0] as (int, int);

          material = CourseMaterial.fromJson(
              json: json,
              viewCount: viewCount,
              downloadCount: downloadCount,
              fileAttachments: results[1] as List<String>);
        } else {
          final (viewCount, downloadCount) = await _fetchStats(id);

          material = CourseMaterial.fromJson(
              json: json, viewCount: viewCount, downloadCount: downloadCount);
        }

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

  Future<(int, int)> _fetchStats(String materialId) async {
    try {
      final response = await _supabase
          .from('material_views')
          .select('*')
          .eq('material_id', materialId)
          .count();

      return (
        response.count,
        response.data.where((json) => json['downloads'] as bool).length
      );
    } catch (e) {
      print('Error loading material stats: $e');
      return (0, 0);
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
          json: response,
          viewCount: 0,
          downloadCount: 0,
          fileAttachments: paths.isNotEmpty ? paths : []);

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
}
