import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment.dart';

class AssignmentSubmissionProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<AssignmentSubmission> _submissions = [];
  bool _isLoading = false;
  String? _error;

  List<AssignmentSubmission> get submissions => _submissions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all submissions for a single assignment
  Future<void> loadSubmissions(String assignmentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('assignment_submissions')
          .select('*, users!assignment_submissions_student_id_fkey(full_name)')
          .eq('assignment_id', assignmentId)
          .order('submitted_at', ascending: false);

      _submissions = (response as List).map((json) {
        return AssignmentSubmission.fromJson({
          ...json,
          'student_name': json['users']['full_name'],
        });
      }).toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading submissions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      await _supabase
          .from('assignment_submissions')
          .update({
            'grade': grade,
            'feedback': feedback,
            'graded_at': DateTime.now().toIso8601String(),
            'graded_by': instructorId,
          })
          .eq('id', submissionId);

      // Update local list
      final index = _submissions.indexWhere((s) => s.id == submissionId);
      if (index != -1) {
        final oldSub = _submissions[index];
        _submissions[index] = AssignmentSubmission(
          id: oldSub.id,
          assignmentId: oldSub.assignmentId,
          studentId: oldSub.studentId,
          studentName: oldSub.studentName,
          submissionFiles: oldSub.submissionFiles,
          submissionText: oldSub.submissionText,
          attemptNumber: oldSub.attemptNumber,
          submittedAt: oldSub.submittedAt,
          isLate: oldSub.isLate,
          grade: grade, // Updated
          feedback: feedback, // Updated
          gradedAt: DateTime.now(), // Updated
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
