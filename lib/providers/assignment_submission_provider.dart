import 'dart:io';
import 'dart:typed_data';

import 'package:elearning_management_app/models/user_model.dart';
import 'package:file_picker/file_picker.dart';
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

      await box
          .putAll(Map.fromEntries(await Future.wait(response.map((json) async {
        final id = json['id'] as String;
        final hasAttachments = json['has_attachments'] as bool;

        final submission = AssignmentSubmission.fromJson(
            json: json,
            studentName: json['users']['full_name'],
            submissionFiles:
                hasAttachments ? await _fetchFileAttachmentPaths(id) : null);

        return MapEntry(submission.id, submission);
      }))));
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
    required List<PlatformFile> submissionFiles,
    required int attemptNumber,
    required bool isLate,
    required DateTime submittedAt,
  }) async {
    try {
      final response = await _supabase
          .from('assignment_submissions')
          .insert({
            'assignment_id': assignmentId,
            'student_id': studentId,
            'submission_text': submissionText,
            'has_attachments': submissionFiles.isNotEmpty,
            'submission_files': [],
            'attempt_number': attemptNumber,
            'is_late': isLate,
            'submitted_at': submittedAt.toIso8601String()
          })
          .select()
          .single();

      List<String> paths = [];

      if (submissionFiles.isNotEmpty) {
        paths.addAll((await Future.wait(submissionFiles.map((file) async {
          final id = response['id'] as String;

          if (file.bytes != null) {
            return await _supabase.storage
                .from('submissions_attachment')
                .uploadBinary('$id/${file.name}', file.bytes!);
          } else if (file.path != null) {
            return await _supabase.storage
                .from('submissions_attachment')
                .upload('$id/${file.name}', File(file.path!));
          }

          return '';
        })))
          ..removeWhere((x) => x.isEmpty));
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error submitting: $e');

      notifyListeners();
      return false;
    }
  }

  Future<Uint8List?> fetchFileAttachment(String url) async {
    try {
      return await _supabase.storage
          .from('submissions_attachment')
          .download(url);
    } catch (e) {
      print('Error fetching file attachment: $e');
      return null;
    }
  }

  Future<List<String>> _fetchFileAttachmentPaths(String id) async {
    try {
      return (await _supabase.storage
              .from('submissions_attachment')
              .list(path: id))
          .map((x) => '$id/${x.name}')
          .toList();
    } catch (e) {
      print('Error fetching assignment attachments: $e');
      return [];
    }
  }
}
