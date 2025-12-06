import 'package:elearning_management_app/models/course.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstructorCourseProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'instructor-course-box';

  String _currentSemester = "";
  String get currentSemester => _currentSemester;

  List<Course> _courses = [];
  List<Course> get courses => _courses;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Load courses for a semester
  Future<void> loadCourses(String semesterId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _currentSemester = semesterId;

    final box = await Hive.openBox<Course>(_boxName);

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

        final groupResponse = _fetchGroup(json['id']);
        final studentResponse = _fetchStudentCount(json['id']);

        final course = Course.fromJson(
            json: json,
            semesterName: semesterName,
            groupIds:
                (await groupResponse).map((x) => x['id'] as String).toSet(),
            studentCount: await studentResponse);

        return MapEntry(course.id, course);
      }))));
    } catch (e) {
      _error = e.toString();
      print('Error loading courses: $e');
    }

    _courses = box.values.where((x) => x.semesterId == semesterId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<Iterable<Map<String, dynamic>>> _fetchGroup(String courseId) async {
    final response =
        await _supabase.from('groups').select('id').eq('course_id', courseId);

    return response;
  }

  Future<int> _fetchStudentCount(String courseId) async {
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
    required String userId,
    String? coverImage,
  }) async {
    try {
      final response = await _supabase
          .from('courses')
          .insert({
            'semester_id': semesterId,
            'code': code,
            'name': name,
            'sessions': sessions,
            'cover_image': coverImage,
            'instructor_id': userId,
          })
          .select('*')
          .single();

      final newCourse = Course.fromJson(json: response);

      final box = await Hive.openBox<Course>(_boxName);

      await box.put(newCourse.id, newCourse);
      _courses.add(newCourse);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error creating course: $e');

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
          groupIds: old?.groupIds ?? {},
          studentCount: old?.studentCount,
        );
      }).first;

      await box.put(newCourse.id, newCourse);
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

      await box.delete(id);
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
