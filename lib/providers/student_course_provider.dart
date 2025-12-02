import 'package:elearning_management_app/models/course.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentCourseProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'student-course-box';

  String _currentSemester = "";
  String get currentSemester => _currentSemester;

  List<Course> _courses = [];
  List<Course> get courses => _courses;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadEnrolledCourses(String studentId, String semesterId) async {
    if (semesterId == _currentSemester) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    _currentSemester = semesterId;

    final box = await Hive.openBox<Course>(_boxName);

    try {
      final response = await _supabase
          .from('enrollments')
          .select('groups!inner(course_id, courses!inner(*))')
          .eq('student_id', studentId)
          .eq('groups.courses.semester_id', semesterId);

      await box.putAll(Map.fromEntries((response as List).map((json) {
        final course = Course.fromJson(json: json["groups"]["courses"]);
        return MapEntry(course.id, course);
      })));
    } catch (e) {
      _error = e.toString();
      print('Error loading courses: $e');
    }

    _courses = box.values.where((x) => x.semesterId == semesterId).toList();

    _isLoading = false;
    notifyListeners();
  }
}
