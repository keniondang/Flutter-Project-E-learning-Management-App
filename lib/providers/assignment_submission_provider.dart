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

    if (!box.values.any((x) => x.assignmentId == assignmentId)) {
      try {
        final response = await _supabase
            .from('assignment_submissions')
            .select(
                '*, users!assignment_submissions_student_id_fkey(full_name)')
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
      final response = await _supabase
          .from('assignment_submissions')
          .update({
            'grade': grade,
            'feedback': feedback,
            'graded_at': DateTime.now().toIso8601String(),
            'graded_by': instructorId,
          })
          .eq('id', submissionId)
          .select('*, users(name)');

      // Update local list
      // final index = _submissions.indexWhere((s) => s.id == submissionId);
      // if (index != -1) {
      //   final oldSub = _submissions[index];
      //   _submissions[index] = AssignmentSubmission(
      //     id: oldSub.id,
      //     assignmentId: oldSub.assignmentId,
      //     studentId: oldSub.studentId,
      //     studentName: oldSub.studentName,
      //     submissionFiles: oldSub.submissionFiles,
      //     submissionText: oldSub.submissionText,
      //     attemptNumber: oldSub.attemptNumber,
      //     submittedAt: oldSub.submittedAt,
      //     isLate: oldSub.isLate,
      //     grade: grade, // Updated
      //     feedback: feedback, // Updated
      //     gradedAt: DateTime.now(), // Updated
      //   );
      //   notifyListeners();
      // }

      final submission = response
          .map((json) => AssignmentSubmission.fromJson(
              json: json, studentName: json['users']['name']))
          .first;

      final box = await Hive.openBox<AssignmentSubmission>(_boxName);
      await box.put(submission.id, submission);
      _submissions[_submissions.indexWhere((x) => x.id == submission.id)] =
          submission;

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }
}
