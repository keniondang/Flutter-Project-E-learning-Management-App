import 'package:elearning_management_app/models/course.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstructorCourseProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'instructor-course-box';

  String _currentSemester = "";
  String get currentSemester => _currentSemester;

  int? _semesterCount;
  int? get semesterCount => _semesterCount;

  List<Course> _courses = [];
  List<Course> get courses => _courses;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;

  String? get error => _error;

  // CourseProvider({required Directory isarDir}) : _isarDir = isarDir;

  // Load courses for a semester
  Future<void> loadCourses(String semesterId) async {
    if (semesterId == _currentSemester) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    _currentSemester = semesterId;

    final box = await Hive.openBox<Course>(_boxName);

    if (!box.containsKey(semesterId)) {
      try {
        final response = await _supabase
            .from('courses')
            .select('*, semesters(name)')
            .eq('semester_id', semesterId);
        // .order('created_at', ascending: false);

        await box.putAll(Map.fromEntries(
            await Future.wait((response as List).map((json) async {
          String? semesterName;

          if (json['semesters'] != null) {
            semesterName = json['semesters']['name'];
          }

          final groupCount = _fetchGroupCount(json['id']);
          final studentCount = _fetchStudentCount(json['id']);

          final course = Course.fromJson(
            json: json,
            semesterName: semesterName,
            groupCount: await groupCount,
            studentCount: await studentCount,
          );

          return MapEntry(course.id, course);
        }))));
      } catch (e) {
        _error = e.toString();
        print('Error loading courses: $e');
      }
    }

    _courses = box.values.where((x) => x.semesterId == semesterId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<int> _fetchGroupCount(dynamic courseId) async {
    final response = await _supabase
        .from('groups')
        .select('id')
        .eq('course_id', courseId)
        .count();

    return response.count;
  }

  Future<int> _fetchStudentCount(dynamic courseId) async {
    final response = await _supabase
        .from('enrollments')
        .select('student_id, groups!inner(course_id)')
        .eq('groups.course_id', courseId)
        .count();

    return response.count;
  }

  // Create new course
  Future<bool> createCourse({
    required String semesterId,
    required String code,
    required String name,
    required int sessions,
    String? coverImage,
  }) async {
    try {
      final response = await _supabase.from('courses').insert({
        'semester_id': semesterId,
        'code': code,
        'name': name,
        'sessions': sessions,
        'cover_image': coverImage,
      }).select('*, semesters(name)');

      final box = await Hive.openBox<Course>(_boxName);

      final newCourse = (response as List).map((json) {
        // Extract semester name from relation
        String? semesterName;

        if (json['semesters'] != null) {
          semesterName = json['semesters']['name'];
        }

        final old = box.get(json['id']);

        return Course.fromJson(
          json: json,
          semesterName: semesterName,
          groupCount: old?.groupCount ?? 0,
          studentCount: old?.studentCount ?? 0,
        );
      }).first;

      box.put(newCourse.id, newCourse);
      _courses.add(newCourse);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }

  // Update course
  Future<bool> updateCourse({
    required String id,
    required String code,
    required String name,
    required int sessions,
    String? coverImage,
  }) async {
    try {
      final response = await _supabase
          .from('courses')
          .update({
            'code': code,
            'name': name,
            'sessions': sessions,
            'cover_image': coverImage,
          })
          .eq('id', id)
          .select('*, semesters(name)');

      final box = await Hive.openBox<Course>(_boxName);

      final newCourse = (response as List).map((json) {
        // Extract semester name from relation
        String? semesterName;

        if (json['semesters'] != null) {
          semesterName = json['semesters']['name'];
        }

        final old = box.get(json['id']);

        return Course.fromJson(
          json: json,
          semesterName: semesterName,
          groupCount: old?.groupCount ?? 0,
          studentCount: old?.studentCount ?? 0,
        );
      }).first;

      box.put(newCourse.id, newCourse);
      _courses[_courses.indexWhere((x) => x.id == newCourse.id)] = newCourse;

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete course
  Future<bool> deleteCourse(String id) async {
    try {
      await _supabase.from('courses').delete().eq('id', id);

      final box = await Hive.openBox<Course>(_boxName);

      box.delete(id);
      _courses.removeWhere((x) => x.id == id);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
