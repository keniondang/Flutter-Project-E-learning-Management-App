import 'package:elearning_management_app/models/course_material.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseMaterialProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  int? _semesterCount;
  int? get semesterCount => _semesterCount;

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

    try {
      final response = await _supabase
          .from('materials')
          .select()
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      _materials = (response as List)
          .map((json) => CourseMaterial.fromJson(json))
          .toList();
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
          .from('materials')
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

  Future<bool> createMaterial({
    required String courseId,
    required String instructorId,
    required String title,
    String? description,
    required List<String> fileUrls,
    required List<String> externalLinks,
  }) async {
    try {
      await _supabase.from('materials').insert({
        'course_id': courseId,
        'instructor_id': instructorId,
        'title': title,
        'description': description,
        'file_urls': fileUrls,
        'external_links': externalLinks,
      });

      await loadCourseMaterials(courseId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
