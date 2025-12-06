import 'dart:io';
import 'dart:typed_data';

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

  // Load all submissions for a single assignment (For Instructor)
  Future<void> loadAllSubmissions(String assignmentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<AssignmentSubmission>(_boxName);

    try {
      final response = await _supabase
          .from('assignment_submissions')
          .select()
          .eq('assignment_id', assignmentId);

      await box
          .putAll(Map.fromEntries(await Future.wait(response.map((json) async {
        final id = json['id'] as String;
        
        // 1. Try to get files from the new DB column first (Faster)
        List<String> files = [];
        if (json['submission_files'] != null) {
          files = List<String>.from(json['submission_files']);
        } 
        // 2. Fallback: If column is empty but flag is true, fetch from Storage (Legacy support)
        else if (json['has_attachments'] == true) {
          files = await _fetchFileAttachmentPaths(id);
        }

        final submission = AssignmentSubmission.fromJson(
            json: json,
            submissionFiles: files // ✅ Explicitly pass the files
        );

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

  RealtimeChannel subscribeSubmissions(String assignmentId) {
    return _supabase
        .channel('submissions')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'assignment_submissions',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'assignment_id',
                value: assignmentId),
            callback: (payload) async {
              final json = payload.newRecord;
              
              // Handle Realtime files
              List<String> files = [];
              if (json['submission_files'] != null) {
                 files = List<String>.from(json['submission_files']);
              }

              final submission = AssignmentSubmission.fromJson(
                  json: json,
                  submissionFiles: files
              );

              _submissions.add(submission);
              notifyListeners();

              final box = await Hive.openBox<AssignmentSubmission>(_boxName);
              await box.put(submission.id, submission);
            })
        .subscribe();
  }

  // ✅ FIXED: Correctly parses 'submission_files' column
  Future<AssignmentSubmission?> fetchStudentSubmission(
      String assignmentId, String studentId) async {
    final box = await Hive.openBox<AssignmentSubmission>(_boxName);

    try {
      final response = await _supabase
          .from('assignment_submissions')
          .select()
          .eq('assignment_id', assignmentId)
          .eq('student_id', studentId)
          .order('attempt_number', ascending: false) // Get latest version
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      // ✅ FIX: Extract the array from JSON
      List<String> files = [];
      if (response['submission_files'] != null) {
        files = List<String>.from(response['submission_files']);
      }

      // ✅ FIX: Pass the extracted list to the model
      final submission = AssignmentSubmission.fromJson(
        json: response, 
        submissionFiles: files 
      );

      await box.put(submission.id, submission);

      notifyListeners();
      return submission;
    } catch (e) {
      print('Error loading submission: $e');

      // Fallback to local cache
      final studentSubmissions = box.values
          .where((x) =>
              x.assignmentId == assignmentId && x.studentId == studentId)
          .toList();

      if (studentSubmissions.isNotEmpty) {
        studentSubmissions
            .sort((a, b) => b.attemptNumber.compareTo(a.attemptNumber));
        return studentSubmissions.first;
      }

      notifyListeners();
      return null;
    }
  }

  // Get a single submission by student ID from memory
  AssignmentSubmission? getSubmissionForStudent(String studentId) {
    try {
      final studentSubmissions =
          _submissions.where((sub) => sub.studentId == studentId).toList();

      if (studentSubmissions.isEmpty) return null;

      // Sort to ensure we return the latest version
      studentSubmissions
          .sort((a, b) => b.attemptNumber.compareTo(a.attemptNumber));

      return studentSubmissions.first;
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
      if (box.containsKey(submissionId)) {
        final submission = box.get(submissionId)!;
        submission.grade = grade;
        submission.feedback = feedback;
        submission.gradedAt = gradedAt;
        await box.put(submission.id, submission);
        
        final index = _submissions.indexWhere((x) => x.id == submissionId);
        if (index != -1) {
           _submissions[index] = submission;
        }
      }

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
      // 1. Insert the submission record
      final response = await _supabase
          .from('assignment_submissions')
          .insert({
            'assignment_id': assignmentId,
            'student_id': studentId,
            'submission_text': submissionText,
            'has_attachments': submissionFiles.isNotEmpty,
            'submission_files': [], // Placeholder
            'attempt_number': attemptNumber,
            'is_late': isLate,
            'submitted_at': submittedAt.toIso8601String()
          })
          .select()
          .single();

      final submissionId = response['id'] as String;
      List<String> filePaths = [];

      // 2. Upload files
      if (submissionFiles.isNotEmpty) {
        filePaths = await Future.wait(submissionFiles.map((file) async {
          // Clean filename logic: timestamp_clean_name.pdf
          final cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName';
          final path = '$submissionId/$fileName';

          try {
            if (file.bytes != null) {
              await _supabase.storage
                  .from('submissions_attachment')
                  .uploadBinary(path, file.bytes!);
            } else if (file.path != null) {
              await _supabase.storage
                  .from('submissions_attachment')
                  .upload(path, File(file.path!));
            }
            return path;
          } catch (e) {
            print('Error uploading file ${file.name}: $e');
            return '';
          }
        }));

        // Remove failed uploads
        filePaths.removeWhere((path) => path.isEmpty);

        // 3. Update record with file paths
        if (filePaths.isNotEmpty) {
          await _supabase
              .from('assignment_submissions')
              .update({'submission_files': filePaths}).eq('id', submissionId);
        }
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