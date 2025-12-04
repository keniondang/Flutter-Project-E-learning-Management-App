import 'package:elearning_management_app/models/student.dart';
import 'package:elearning_management_app/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
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
  Future<void> loadAllSubmissions(String assignmentId) async {
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

  Future<AssignmentSubmission?> fetchStudentSubmission(
      String assignmentId, UserModel student) async {
    final box = await Hive.openBox<AssignmentSubmission>(_boxName);

    try {
      final response = await _supabase
          .from('assignment_submissions')
          .select()
          .eq('assignment_id', assignmentId)
          .eq('student_id', student.id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final submission = AssignmentSubmission.fromJson(
          json: response, studentName: student.fullName);

      await box.put(submission.id, submission);

      notifyListeners();
      return submission;
    } catch (e) {
      print('Error loading submission: $e');

      final result = box.values.firstWhereOrNull(
          (x) => x.assignmentId == assignmentId && x.studentId == student.id);

      notifyListeners();
      return result;
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
      final gradedAt = DateTime.now();

      await _supabase.rpc('grade_assignment_submission', params: {
        'submission_id': submissionId,
        'grade': grade,
        'feedback': feedback,
        'instructor_id': instructorId,
        'graded_at': gradedAt.toIso8601String(),
      });

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

  Future<bool> createSubmission({
    required String assignmentId,
    required String studentId,
    String? submissionText,
    required List<String> submissionFiles,
    required int attemptNumber,
    required bool isLate,
    required DateTime submittedAt,
  }) async {
    try {
      await _supabase.from('assignment_submissions').insert({
        'assignment_id': assignmentId,
        'student_id': studentId,
        'submission_text': submissionText,
        'submission_files': [],
        'attempt_number': attemptNumber,
        'is_late': isLate,
        'submitted_at': submittedAt.toIso8601String()
      });

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error submitting: $e');

      notifyListeners();
      return false;
    }
  }
}
