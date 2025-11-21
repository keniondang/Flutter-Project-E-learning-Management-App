import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment.dart';

class AssignmentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'assignment-box';

  int? _semesterCount;
  int? get semesterCount => _semesterCount;

  List<Assignment> _assignments = [];
  List<Assignment> get assignments => _assignments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadAssignments(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Assignment>(_boxName);

    if (!box.values.any((x) => x.courseId == courseId)) {
      try {
        final response = await _supabase
            .from('assignments')
            .select('*, courses(semester_id)')
            .eq('course_id', courseId);

        await box.putAll(Map.fromEntries(
            await Future.wait((response as Iterable).map((json) async {
          final assignment = Assignment.fromJson(
            json: json,
            semesterId: json['courses']['semester_id'],
            submissionCount: await _fetchSubmissionCount(json['id']),
          );

          return MapEntry(assignment.id, assignment);
        }))));

        // // Load submission counts
        // for (var assignment in _assignments) {
        //   await _loadAssignmentStats(assignment);
        // }
      } catch (e) {
        _error = e.toString();
        print('Error loading quizzes: $e');
      }
    }

    _assignments = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<int> countInSemester(String semesterId) async {
    final box = await Hive.openBox<Assignment>(_boxName);

    if (!box.values.any((x) => x.semesterId == semesterId)) {
      try {
        final response = await _supabase
            .from('assignments')
            .select('*, courses(semester_id)')
            .eq('courses.semester_id', semesterId);

        await box.putAll(
            Map.fromEntries(await Future.wait(response.map((json) async {
          final assignment = Assignment.fromJson(
            json: json,
            semesterId: json['courses']['semester_id'],
            submissionCount: await _fetchSubmissionCount(json['id']),
          );

          return MapEntry(assignment.id, assignment);
        }))));
      } catch (e) {
        _error = e.toString();
        print('Error loading quizzes: $e');
      }
    }

    return box.values.where((x) => x.semesterId == semesterId).length;
  }

  // Future<void> _loadAssignmentStats(Assignment assignment) async {
  //   try {
  //     final submissionResponse = await _supabase
  //         .from('assignment_submissions')
  //         .select('id')
  //         .eq('assignment_id', assignment.id);

  //     final index = _assignments.indexWhere((a) => a.id == assignment.id);
  //     if (index != -1) {
  //       _assignments[index] = Assignment(
  //         id: assignment.id,
  //         courseId: assignment.courseId,
  //         instructorId: assignment.instructorId,
  //         title: assignment.title,
  //         description: assignment.description,
  //         fileAttachments: assignment.fileAttachments,
  //         startDate: assignment.startDate,
  //         dueDate: assignment.dueDate,
  //         lateSubmissionAllowed: assignment.lateSubmissionAllowed,
  //         lateDueDate: assignment.lateDueDate,
  //         maxAttempts: assignment.maxAttempts,
  //         maxFileSize: assignment.maxFileSize,
  //         allowedFileTypes: assignment.allowedFileTypes,
  //         scopeType: assignment.scopeType,
  //         targetGroups: assignment.targetGroups,
  //         totalPoints: assignment.totalPoints,
  //         createdAt: assignment.createdAt,
  //         submissionCount: (submissionResponse as List).length,
  //       );
  //     }
  //   } catch (e) {
  //     print('Error loading assignment stats: $e');
  //   }
  // }

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
