import 'package:elearning_management_app/models/course_material.dart';
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

    if (!box.values.any((x) => x.courseId == courseId)) {
      try {
        final response = await _supabase
            .from('materials')
            .select()
            .eq('course_id', courseId);
        // .order('created_at, ascending: false);

        await box.putAll(
            Map.fromEntries(await Future.wait(response.map((json) async {
          final (viewCount, downloadCount) = await _fetchStats(json['id']);

          final material = CourseMaterial.fromJson(
              json: json, viewCount: viewCount, downloadCount: downloadCount);

          return MapEntry(material.id, material);
        }))));
      } catch (e) {
        _error = e.toString();
        print('Error loading quizzes: $e');
      }
    }

    _materials = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  // Future<int> countInSemester(String semesterId) async {
  //   final box = await Hive.openBox<CourseMaterial>(_boxName);

  //   if (!box.values.any((x) => x.courseId == courseId)) {
  //     try {
  //       final response = await _supabase
  //           .from('materials')
  //           .select()
  //           .eq('course_id', courseId);
  //       // .order('created_at, ascending: false);

  //       await box.putAll(
  //           Map.fromEntries(await Future.wait(response.map((json) async {
  //         final material = CourseMaterial.fromJson(
  //             json: json, viewCount: await _fetchViewCount(json['id']));

  //         return MapEntry(material.id, material);
  //       }))));
  //     } catch (e) {
  //       _error = e.toString();
  //       print('Error loading quizzes: $e');
  //     }
  //   }
  // }

  // Future<void> countInSemester(String semesterId) async {
  //   _isLoading = true;
  //   _error = null;
  //   notifyListeners();

  //   try {
  //     final response = await _supabase
  //         .from('materials')
  //         .select('id, courses(id)')
  //         .eq('courses.semester_id', semesterId)
  //         .count(CountOption.estimated);
  //   } catch (e) {
  //     _error = e.toString();
  //     print('Error loading quizzes: $e');
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  Future<(int, int)> _fetchStats(String materialId) async {
    try {
      final response = await _supabase
          .from('material_views')
          .select('id')
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
    required List<String> fileUrls,
    required List<String> externalLinks,
  }) async {
    try {
      final response = await _supabase.from('materials').insert({
        'course_id': courseId,
        'instructor_id': instructorId,
        'title': title,
        'description': description,
        'file_urls': fileUrls,
        'external_links': externalLinks,
      }).select();

      final material = response
          .map((json) => CourseMaterial.fromJson(
              json: json, viewCount: 0, downloadCount: 0))
          .first;

      final box = await Hive.openBox(_boxName);

      await box.put(material.id, material);
      _materials.add(material);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
