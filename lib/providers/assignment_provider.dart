import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment.dart';

class AssignmentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'assignment-box';

  List<Assignment> _assignments = [];
  List<Assignment> get assignments => _assignments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadAllAssignments(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Assignment>(_boxName);

    try {
      final response = await _supabase
          .from('assignments')
          .select('*, courses(semester_id)')
          .eq('course_id', courseId);

      await box
          .putAll(Map.fromEntries(await Future.wait(response.map((json) async {
        final assignment = Assignment.fromJson(
          json: json,
          semesterId: json['courses']['semester_id'],
          submissionCount: await _fetchSubmissionCount(json['id']),
        );

        return MapEntry(assignment.id, assignment);
      }))));
    } catch (e) {
      _error = e.toString();
      print('Error loading asignments: $e');
    }

    _assignments = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAssignments(String courseId, String? groupId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Assignment>(_boxName);

    try {
      late List<Map<String, dynamic>> response;

      if (groupId == null) {
        response = await _supabase
            .from('assignments')
            .select('*, courses(semester_id)')
            .eq('course_id', courseId)
            .eq('scope_type', 'all');
      } else {
        response = await _supabase
            .from('assignments')
            .select('*, courses(semester_id)')
            .eq('course_id', courseId)
            .or('scope_type.eq.all,target_groups.cs.{$groupId}');
      }

      await box
          .putAll(Map.fromEntries(await Future.wait(response.map((json) async {
        final assignment = Assignment.fromJson(
          json: json,
          semesterId: json['courses']['semester_id'],
          submissionCount: await _fetchSubmissionCount(json['id']),
        );

        return MapEntry(assignment.id, assignment);
      }))));
    } catch (e) {
      _error = e.toString();
      print('Error loading asignments: $e');
    }

    _assignments = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<int> countInSemester(String semesterId) async {
    try {
      final response = await _supabase
          .from('assignments')
          .select('*, courses!inner(semester_id)')
          .eq('courses.semester_id', semesterId)
          .count();

      return response.count;
    } catch (e) {
      _error = e.toString();
      print('Error loading assignments count: $e');

      final box = await Hive.openBox<Assignment>(_boxName);
      return box.values.where((x) => x.semesterId == semesterId).length;
    }
  }

  Future<int> _fetchSubmissionCount(String assignmentId) async {
    try {
      final response = await _supabase
          .from('assignment_submissions')
          .select('id')
          .eq('assignment_id', assignmentId)
          .count();

      return response.count;
    } catch (e) {
      print('Error loading assignment stats: $e');
      return 0;
    }
  }

  Future<bool> createAssignment({
    required String courseId,
    required String instructorId,
    required String title,
    required String description,
    required List<String> fileAttachments,
    required DateTime startDate,
    required DateTime dueDate,
    required bool lateSubmissionAllowed,
    DateTime? lateDueDate,
    required int maxAttempts,
    required int maxFileSize,
    required List<String> allowedFileTypes,
    required String scopeType,
    required List<String> targetGroups,
    required int totalPoints,
  }) async {
    try {
      final response = await _supabase.from('assignments').insert({
        'course_id': courseId,
        'instructor_id': instructorId,
        'title': title,
        'description': description,
        'file_attachments': fileAttachments,
        'start_date': startDate.toIso8601String(),
        'due_date': dueDate.toIso8601String(),
        'late_submission_allowed': lateSubmissionAllowed,
        'late_due_date': lateDueDate?.toIso8601String(),
        'max_attempts': maxAttempts,
        'max_file_size': maxFileSize,
        'allowed_file_types': allowedFileTypes,
        'scope_type': scopeType,
        'target_groups': targetGroups,
        'total_points': totalPoints,
      }).select('*, courses(semester_id)');

      final assignment = response
          .map((json) => Assignment.fromJson(
              json: json,
              semesterId: json['courses']['semester_id'],
              submissionCount: 0))
          .first;

      final box = await Hive.openBox<Assignment>(_boxName);

      await box.put(assignment.id, assignment);
      _assignments.add(assignment);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }
}
