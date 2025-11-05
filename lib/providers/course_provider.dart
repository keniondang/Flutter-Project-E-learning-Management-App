import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';

class CourseProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Course> _courses = [];
  bool _isLoading = false;
  String? _error;

  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load courses for a semester
  Future<void> loadCourses(String semesterId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('courses')
          .select('*, semesters(name)')
          .eq('semester_id', semesterId)
          .order('created_at', ascending: false);

      _courses = (response as List).map((json) {
        // Extract semester name from relation
        String? semesterName;
        if (json['semesters'] != null) {
          semesterName = json['semesters']['name'];
        }
        
        return Course.fromJson({
          ...json,
          'semester_name': semesterName,
        });
      }).toList();

      // Load group and student counts
      for (var course in _courses) {
        await _loadCourseStats(course);
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading courses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load stats for a course
  Future<void> _loadCourseStats(Course course) async {
    try {
      // Count groups
      final groupResponse = await _supabase
          .from('groups')
          .select('id')
          .eq('course_id', course.id);
      
      final groupCount = (groupResponse as List).length;

      // Count students (through enrollments)
      final studentResponse = await _supabase
          .from('enrollments')
          .select('student_id, groups!inner(course_id)')
          .eq('groups.course_id', course.id);
      
      final studentCount = (studentResponse as List).length;

      // Update course with stats
      final index = _courses.indexWhere((c) => c.id == course.id);
      if (index != -1) {
        _courses[index] = Course(
          id: course.id,
          semesterId: course.semesterId,
          code: course.code,
          name: course.name,
          sessions: course.sessions,
          coverImage: course.coverImage,
          createdAt: course.createdAt,
          semesterName: course.semesterName,
          groupCount: groupCount,
          studentCount: studentCount,
        );
      }
    } catch (e) {
      print('Error loading course stats: $e');
    }
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
      await _supabase.from('courses').insert({
        'semester_id': semesterId,
        'code': code,
        'name': name,
        'sessions': sessions,
        'cover_image': coverImage,
      });

      await loadCourses(semesterId);
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
      await _supabase.from('courses').update({
        'code': code,
        'name': name,
        'sessions': sessions,
        'cover_image': coverImage,
      }).eq('id', id);

      // Reload courses for the current semester
      if (_courses.isNotEmpty) {
        await loadCourses(_courses.first.semesterId);
      }
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
      
      // Remove from local list
      _courses.removeWhere((course) => course.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}