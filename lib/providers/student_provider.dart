import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student.dart';

class StudentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Student> _students = [];
  bool _isLoading = false;
  String? _error;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all students
  Future<void> loadAllStudents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', 'student')
          .order('full_name');

      _students = (response as List)
          .map((json) => Student.fromJson(json))
          .toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading students: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load students in a group
  Future<void> loadStudentsInGroup(String groupId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('enrollments')
          .select('*, users!enrollments_student_id_fkey(*), groups(name, courses(name))')
          .eq('group_id', groupId);

      _students = (response as List).map((json) {
        final userJson = json['users'];
        final groupJson = json['groups'];
        
        return Student.fromJson({
          ...userJson,
          'group_id': groupId,
          'group_name': groupJson?['name'],
          'course_name': groupJson?['courses']?['name'],
        });
      }).toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading students in group: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new student
  Future<Map<String, dynamic>> createStudent({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Check if username already exists
      final existing = await _supabase
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (existing != null) {
        return {'success': false, 'message': 'Username already exists'};
      }

      await _supabase.from('users').insert({
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': 'student',
      });

      await loadAllStudents();
      return {'success': true, 'message': 'Student created successfully'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Create multiple students (for CSV import)
  Future<Map<String, dynamic>> createMultipleStudents(
    List<Map<String, dynamic>> studentsData,
  ) async {
    int successCount = 0;
    int duplicateCount = 0;
    int errorCount = 0;
    List<String> errors = [];

    for (var studentData in studentsData) {
      try {
        // Check if username already exists
        final existing = await _supabase
            .from('users')
            .select('id')
            .eq('username', studentData['username'])
            .maybeSingle();

        if (existing != null) {
          duplicateCount++;
          continue;
        }

        // Create new student
        await _supabase.from('users').insert({
          'username': studentData['username'],
          'email': studentData['email'],
          'password': studentData['password'],
          'full_name': studentData['full_name'],
          'role': 'student',
        });
        successCount++;
      } catch (e) {
        errorCount++;
        errors.add('Error with ${studentData['username']}: $e');
      }
    }

    await loadAllStudents();

    return {
      'success': errorCount == 0,
      'successCount': successCount,
      'duplicateCount': duplicateCount,
      'errorCount': errorCount,
      'errors': errors,
    };
  }

  // Enroll student in group
  Future<bool> enrollStudentInGroup({
    required String studentId,
    required String groupId,
    required String courseId,
  }) async {
    try {
      // Check if student is already enrolled in ANY group for THIS course
      final existingEnrollment = await _supabase
          .from('enrollments')
          .select('id, groups!inner(course_id)') // Join groups
          .eq('student_id', studentId)
          .eq('groups.course_id', courseId) // Check course_id on the joined group
          .maybeSingle();

      if (existingEnrollment != null) {
        _error = 'Student is already enrolled in another group for this course.';
        notifyListeners();
        return false;
      }

      // If no existing enrollment in this course, proceed to add
      await _supabase.from('enrollments').insert({
        'student_id': studentId,
        'group_id': groupId,
      });

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Enroll multiple students (for CSV import)
  Future<Map<String, dynamic>> enrollMultipleStudents(
    List<Map<String, dynamic>> enrollmentData,
  ) async {
    int successCount = 0;
    int duplicateCount = 0;
    int errorCount = 0;
    List<String> errors = [];

    for (var enrollment in enrollmentData) {
      try {
        // Get student ID from username
        final studentResponse = await _supabase
            .from('users')
            .select('id')
            .eq('username', enrollment['student_username'])
            .eq('role', 'student')
            .maybeSingle();

        if (studentResponse == null) {
          errorCount++;
          errors.add('Student ${enrollment['student_username']} not found');
          continue;
        }

        // Get group ID from group name
        final groupResponse = await _supabase
            .from('groups')
            .select('id')
            .eq('name', enrollment['group_name'])
            .maybeSingle();

        if (groupResponse == null) {
          errorCount++;
          errors.add('Group ${enrollment['group_name']} not found');
          continue;
        }

        // Check if already enrolled
        final existing = await _supabase
            .from('enrollments')
            .select('id')
            .eq('student_id', studentResponse['id'])
            .eq('group_id', groupResponse['id'])
            .maybeSingle();

        if (existing != null) {
          duplicateCount++;
          continue;
        }

        // Create enrollment
        await _supabase.from('enrollments').insert({
          'student_id': studentResponse['id'],
          'group_id': groupResponse['id'],
        });
        successCount++;
      } catch (e) {
        errorCount++;
        errors.add('Error: $e');
      }
    }

    return {
      'success': errorCount == 0,
      'successCount': successCount,
      'duplicateCount': duplicateCount,
      'errorCount': errorCount,
      'errors': errors,
    };
  }

  // Remove student from group
  Future<bool> removeStudentFromGroup({
    required String studentId,
    required String groupId,
  }) async {
    try {
      await _supabase
          .from('enrollments')
          .delete()
          .eq('student_id', studentId)
          .eq('group_id', groupId);

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update student
  Future<bool> updateStudent({
    required String id,
    required String email,
    required String fullName,
  }) async {
    try {
      await _supabase.from('users').update({
        'email': email,
        'full_name': fullName,
      }).eq('id', id);

      await loadAllStudents();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete student
  Future<bool> deleteStudent(String id) async {
    try {
      await _supabase.from('users').delete().eq('id', id);
      _students.removeWhere((student) => student.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ --- NEW METHOD --- ✅
  // Fetches all students but does NOT notify listeners or change state.
  // This is for use in dialogs/dropdowns.
  Future<List<Student>> fetchAllStudents() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', 'student')
          .order('full_name');

      return (response as List)
          .map((json) => Student.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching all students: $e');
      return [];
    }
  }
}