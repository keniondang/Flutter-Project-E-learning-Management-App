import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import '../models/student.dart';

class StudentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'student-box';

  List<Student> _students = [];
  List<Student> get students => _students;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Load all students
  Future<void> loadAllStudents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Student>(_boxName);

    if (box.isEmpty) {
      try {
        final response =
            await _supabase.from('users').select().eq('role', 'student');

        await box.putAll(Map.fromEntries((response as Iterable).map((json) {
          final student = Student.fromJson(json: json);
          return MapEntry(student.id, student);
        })));
      } catch (e) {
        _error = e.toString();
        print('Error loading students: $e');
      }
    }

    _students = box.values.toList();

    _isLoading = false;
    notifyListeners();
  }

  // Load students in a group
  Future<void> loadStudentsInGroup(String groupId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Student>(_boxName);

    // ✅ FIX: Always fetch fresh enrollment data for the group
    try {
      final response = await _supabase
          .from('enrollments')
          .select(
            '*, users!enrollments_student_id_fkey(id, email, username, full_name, avatar_url), groups(id, name, course_id)',
          )
          .eq('group_id', groupId);

      // Update all students in this group
      await box.putAll(Map.fromEntries((response as Iterable).map((json) {
        final userId = json['users']['id'];
        final groupJson = json['groups'];
        
        // Get existing student or create new
        final existingStudent = box.get(userId);
        final student = existingStudent ?? Student.fromJson(json: json['users']);
        
        // Update group mapping and course IDs
        student.groupMap[groupJson['id']] = groupJson['name'];
        student.courseIds.add(groupJson['course_id']);

        return MapEntry(student.id, student);
      })));
    } catch (e) {
      _error = e.toString();
      print('Error loading students in group: $e');
    }

    _students =
        box.values.where((x) => x.groupMap.containsKey(groupId)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<int> countTotalStudents() async {
    final box = await Hive.openBox<Student>(_boxName);

    if (box.isEmpty) {
      try {
        final response =
            await _supabase.from('users').select().eq('role', 'student');

        await box.putAll(Map.fromEntries((response as Iterable).map((json) {
          final student = Student.fromJson(json: json);
          return MapEntry(student.id, student);
        })));
      } catch (e) {
        _error = e.toString();
        print('Error loading students in group: $e');
      }
    }

    return box.length;
  }

  // Create new student
  Future<Map<String, dynamic>> createStudent({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final box = await Hive.openBox<Student>(_boxName);

      if (box.values.any((x) => x.username == username)) {
        return {'success': false, 'message': 'Username already exists'};
      }

      final existing = await _supabase
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (existing != null) {
        return {'success': false, 'message': 'Username already exists'};
      }

      final response = await _supabase.from('users').insert({
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': 'student',
      }).select();

      final newStudent = (response as Iterable)
          .map((json) => Student.fromJson(json: json))
          .first;

      await box.put(newStudent.id, newStudent);
      _students.add(newStudent);

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

    // await loadAllStudents();

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
    required Group group,
    required String courseId,
  }) async {
    try {
      final box = await Hive.openBox<Student>(_boxName);

      if (box.get(studentId)?.courseIds.contains(courseId) ?? false) {
        _error =
            'Student is already enrolled in another group for this course.';
        notifyListeners();
        return false;
      }

      // Check if student is already enrolled in ANY group for THIS course
      final existingEnrollment = await _supabase
          .from('enrollments')
          .select('id, groups!inner(course_id)') // Join groups
          .eq('student_id', studentId)
          .eq(
            'groups.course_id',
            courseId,
          ) // Check course_id on the joined group
          .maybeSingle();

      if (existingEnrollment != null) {
        _error =
            'Student is already enrolled in another group for this course.';
        notifyListeners();
        return false;
      }

      // If no existing enrollment in this course, proceed to add
      await _supabase.from('enrollments').insert({
        'student_id': studentId,
        'group_id': group.id,
      });

      final student = box.get(studentId)!;
      student.groupMap[group.id] = group.name;
      student.courseIds.add(courseId);
      await box.put(student.id, student);

      _students.add(student);

      notifyListeners();
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

      final box = await Hive.openBox<Student>(_boxName);

      final student = box.get(studentId)!;
      student.groupMap.remove(groupId);
      await box.put(student.id, student);

      _students =
          box.values.where((x) => x.groupMap.containsKey(groupId)).toList();

      notifyListeners();
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
      await _supabase
          .from('users')
          .update({'email': email, 'full_name': fullName}).eq('id', id);

      final box = await Hive.openBox<Student>(_boxName);

      final student = box.get(id)!;

      await box.put(
          student.id,
          Student(
            id: student.id,
            email: email,
            username: student.username,
            fullName: fullName,
            avatarUrl: student.avatarUrl,
            groupMap: student.groupMap,
            courseIds: student.courseIds,
          ));

      _students = box.values.toList();

      notifyListeners();
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
      final box = await Hive.openBox<Student>(_boxName);

      await box.delete(id);
      _students = box.values.toList();

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }

  Future<List<Student>> fetchAllStudents() async {
    final box = await Hive.openBox<Student>(_boxName);

    if (box.isEmpty) {
      try {
        final response =
            await _supabase.from('users').select().eq('role', 'student');
        // .order('full_name');

        await box.putAll(Map.fromEntries((response as Iterable).map((json) {
          final student = Student.fromJson(json: json);
          return MapEntry(student.id, student);
        })));
      } catch (e) {
        print('Error fetching all students: $e');
        // return [];
      }
    }

    return box.values.toList();
  }

  // ✅ FIXED: Load all students enrolled in a specific course and update state
  Future<void> loadStudentsForCourse(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Student>(_boxName);

    // ✅ FIX: Always fetch fresh enrollment data for this course
    try {
      final response = await _supabase
          .from('enrollments')
          .select(
            'users!enrollments_student_id_fkey(id, email, username, full_name, avatar_url), groups!inner(id, course_id, name)',
          )
          .eq('groups.course_id', courseId);

      // Update all students in this course
      await box.putAll(Map.fromEntries((response as Iterable).map((json) {
        final userId = json['users']['id'];
        final groupJson = json['groups'];

        // Get existing student or create new
        final existingStudent = box.get(userId);
        final student = existingStudent ?? Student.fromJson(json: json['users']);

        // Update group mapping and course IDs
        student.groupMap[groupJson['id']] = groupJson['name'];
        student.courseIds.add(courseId);

        return MapEntry(student.id, student);
      })));
    } catch (e) {
      _error = e.toString();
      print('Error loading students for course: $e');
    }

    _students =
        box.values.where((x) => x.courseIds.contains(courseId)).toList();

    _isLoading = false;
    notifyListeners();
  }

  // ✅ FIXED: Load all students enrolled in a specific course (no state update)
  Future<List<Student>> loadStudentsInCourse(String courseId) async {
    final box = await Hive.openBox<Student>(_boxName);

    // ✅ FIX: Always fetch fresh enrollment data for this course
    try {
      final response = await _supabase
          .from('enrollments')
          .select(
            'users!enrollments_student_id_fkey(id, email, username, full_name, avatar_url), groups!inner(id, course_id, name)',
          )
          .eq('groups.course_id', courseId);

      // Update all students in this course
      await box.putAll(Map.fromEntries((response as Iterable).map((json) {
        final userId = json['users']['id'];
        final groupJson = json['groups'];

        // Get existing student or create new
        final existingStudent = box.get(userId);
        final student = existingStudent ?? Student.fromJson(json: json['users']);

        // Update group mapping and course IDs
        student.groupMap[groupJson['id']] = groupJson['name'];
        student.courseIds.add(courseId);

        return MapEntry(student.id, student);
      })));
    } catch (e) {
      print('Error loading students in course: $e');
    }

    return box.values.where((x) => x.courseIds.contains(courseId)).toList();
  }
}
