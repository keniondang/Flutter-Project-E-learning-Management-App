import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment.dart';

class AssignmentSubmissionProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'assignment-submission-box';

  List<AssignmentSubmission> _submissions = [];
  List<AssignmentSubmission> get submissions => _submissions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Load all submissions for a single assignment
  Future<void> loadSubmissions(String assignmentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<AssignmentSubmission>(_boxName);

    try {
      final response = await _supabase
          .from('assignment_submissions')
          .select('*, users!assignment_submissions_student_id_fkey(full_name)')
          .eq('assignment_id', assignmentId);

      await box.putAll(Map.fromEntries(response.map((json) {
        final submission = AssignmentSubmission.fromJson(
            json: json, studentName: json['users']['full_name']);

        return MapEntry(submission.id, submission);
      })));
    } catch (e) {
      _error = e.toString();
      print('Error loading submissions: $e');
    }

    _submissions =
        box.values.where((x) => x.assignmentId == assignmentId).toList();

    _isLoading = false;
    notifyListeners();
  }

  // Get a single submission by student ID
  AssignmentSubmission? getSubmissionForStudent(String studentId) {
    try {
      return _submissions.firstWhere((sub) => sub.studentId == studentId);
    } catch (e) {
      return null;
    }
  }

  // Grade or re-grade a submission
  Future<bool> gradeSubmission({
    required String submissionId,
    required double grade,
    required String feedback,
    required String instructorId,
  }) async {
    try {
      // final response = await _supabase
      //     .from('assignment_submissions')
      //     .update({
      //       'grade': grade,
      //       'feedback': feedback,
      //       'graded_at': DateTime.now().toIso8601String(),
      //       'graded_by': instructorId,
      //     })
      //     .eq('id', submissionId)
      //     .select(
      //         '*, users!assignment_submissions_student_id_fkey!inner(full_name)');

      final gradedAt = DateTime.now();

      await _supabase.rpc('grade_assignment_submission', params: {
        'submission_id': submissionId,
        'grade': grade,
        'feedback': feedback,
        'instructor_id': instructorId,
        'graded_at': gradedAt.toIso8601String(),
      });

      // final submission = response
      //     .map((json) => AssignmentSubmission.fromJson(
      //         json: json, studentName: json['users']['full_name']))
      //     .first;

      final box = await Hive.openBox<AssignmentSubmission>(_boxName);
      final submission = box.get(submissionId)!;

      submission.grade = grade;
      submission.feedback = feedback;
      submission.gradedAt = gradedAt;

      await box.put(submission.id, submission);
      _submissions[_submissions.indexWhere((x) => x.id == submission.id)] =
          submission;

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error grading submission: $e');

      notifyListeners();
      return false;
    }
  }
}
