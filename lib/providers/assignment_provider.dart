import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
        final id = json['id'] as String;
        final hasAttachments = json['has_attachments'] as bool;

        late Assignment assignment;

        if (hasAttachments) {
          final results = await Future.wait(
              [_fetchSubmissionCount(id), _fetchFileAttachmentPaths(id)]);

          assignment = Assignment.fromJson(
              json: json,
              semesterId: json['courses']['semester_id'],
              submissionCount: results[0] as int,
              fileAttachments: results[1] as List<String>);
        } else {
          assignment = Assignment.fromJson(
              json: json,
              semesterId: json['courses']['semester_id'],
              submissionCount: await _fetchSubmissionCount(json['id']));
        }

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
        final id = json['id'] as String;
        final hasAttachments = json['has_attachments'] as bool;

        late Assignment assignment;

        if (hasAttachments) {
          final results = await Future.wait(
              [_fetchSubmissionCount(id), _fetchFileAttachmentPaths(id)]);

          assignment = Assignment.fromJson(
              json: json,
              semesterId: json['courses']['semester_id'],
              submissionCount: results[0] as int,
              fileAttachments: results[1] as List<String>);
        } else {
          assignment = Assignment.fromJson(
              json: json,
              semesterId: json['courses']['semester_id'],
              submissionCount: await _fetchSubmissionCount(json['id']));
        }

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

  Future<Uint8List?> fetchFileAttachment(String url) async {
    try {
      return await _supabase.storage
          .from('assignments_attachment')
          .download(url);
    } catch (e) {
      print('Error fetching file attachment: $e');
      return null;
    }
  }

  Future<int> _fetchSubmissionCount(String assignmentId) async {
    try {
      // 1. Fetch ALL rows, but only select the 'student_id' column
      final response = await _supabase
          .from('assignment_submissions')
          .select('student_id') 
          .eq('assignment_id', assignmentId);

      // 2. Convert to a Set (which automatically removes duplicates)
      final uniqueStudents = (response as List)
          .map((data) => data['student_id'] as String)
          .toSet();

      // 3. Return the count of UNIQUE students
      return uniqueStudents.length;
    } catch (e) {
      print('Error loading assignment stats: $e');
      return 0;
    }
  }

  Future<List<String>> _fetchFileAttachmentPaths(String id) async {
    try {
      return (await _supabase.storage
              .from('assignments_attachment')
              .list(path: id))
          .map((x) => '$id/${x.name}')
          .toList();
    } catch (e) {
      print('Error fetching assignment attachments: $e');
      return [];
    }
  }

  Future<bool> createAssignment({
    required String courseId,
    required String instructorId,
    required String title,
    required String description,
    required List<PlatformFile> fileAttachments,
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
      final response = await _supabase
          .from('assignments')
          .insert({
            'course_id': courseId,
            'instructor_id': instructorId,
            'title': title,
            'description': description,
            'has_attachments': fileAttachments.isNotEmpty,
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
          })
          .select('*, courses(semester_id)')
          .single();

      List<String> paths = [];

      if (fileAttachments.isNotEmpty) {
        paths.addAll((await Future.wait(fileAttachments.map((file) async {
          final id = response['id'] as String;

          if (file.bytes != null) {
            return await _supabase.storage
                .from('assignments_attachment')
                .uploadBinary('$id/${file.name}', file.bytes!);
          } else if (file.path != null) {
            return await _supabase.storage
                .from('assignments_attachment')
                .upload('$id/${file.name}', File(file.path!));
          }

          return '';
        })))
          ..removeWhere((x) => x.isEmpty));
      }

      final assignment = Assignment.fromJson(
          json: response,
          semesterId: response['courses']['semester_id'],
          submissionCount: 0,
          fileAttachments: paths.isNotEmpty ? paths : null);

      final box = await Hive.openBox<Assignment>(_boxName);

      await box.put(assignment.id, assignment);
      _assignments.add(assignment);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Erroring creating assignment: $e');

      notifyListeners();
      return false;
    }
  }
}
