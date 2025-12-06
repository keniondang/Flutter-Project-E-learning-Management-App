import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';
import '../models/quiz.dart';
import '../models/student.dart';

class CsvExportService {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// ---------------------------------------------------------
  /// 1. EXPORT ASSIGNMENT REPORT
  /// Requirement: Track student submission status and grades
  /// ---------------------------------------------------------
  Future<void> exportAssignmentGrades({
    required Assignment assignment,
    required List<AssignmentSubmission> submissions,
    required List<Student> allStudents,
  }) async {
    // Header (Removed Student ID)
    List<List<dynamic>> rows = [
      [
        'Full Name',
        'Email',
        'Group',
        'Status',
        'Submitted At',
        'Is Late',
        'Grade',
        'Max Points',
        'Feedback'
      ]
    ];

    for (var student in allStudents) {
      // Find submission for this student
      final sub = submissions
          .cast<AssignmentSubmission?>()
          .firstWhere((s) => s?.studentId == student.id, orElse: () => null);

      final groupName = student.groupMap.values.join(', '); // Get student's group
      
      String status = 'Not Submitted';
      String submittedAt = '-';
      String isLate = '-';
      String grade = '0';
      String feedback = '';

      if (sub != null) {
        status = 'Submitted';
        submittedAt = _dateFormat.format(sub.submittedAt);
        isLate = sub.isLate ? 'Yes' : 'No';
        grade = sub.grade?.toString() ?? 'Not Graded';
        feedback = sub.feedback ?? '';
      }

      // Row Data (Removed student.id)
      rows.add([
        student.fullName,
        student.email,
        groupName,
        status,
        submittedAt,
        isLate,
        grade,
        assignment.totalPoints,
        feedback
      ]);
    }

    await _saveFile('Assignment_${assignment.title}_Report', rows);
  }

  /// ---------------------------------------------------------
  /// 2. EXPORT QUIZ REPORT
  /// Requirement: Track attempts, scores, and completion
  /// ---------------------------------------------------------
  Future<void> exportQuizResults({
    required Quiz quiz,
    required List<QuizAttempt> attempts,
    required List<Student> allStudents,
  }) async {
    // Header (Removed Student ID)
    List<List<dynamic>> rows = [
      [
        'Full Name',
        'Email',
        'Attempt #',
        'Started At',
        'Finished At',
        'Score',
        'Total Points',
        'Percentage'
      ]
    ];

    for (var student in allStudents) {
      // Get all attempts by this student
      final studentAttempts = attempts.where((a) => a.studentId == student.id).toList();

      // If no attempts
      if (studentAttempts.isEmpty) {
        rows.add([
          student.fullName,
          student.email,
          '0',
          '-',
          '-',
          '0',
          quiz.totalPoints,
          '0%'
        ]);
        continue;
      }

      // If multiple attempts, add a row for EACH attempt
      for (var attempt in studentAttempts) {
        final percentage = (attempt.score ?? 0) / (quiz.totalPoints == 0 ? 1 : quiz.totalPoints) * 100;
        
        // Row Data (Removed student.id)
        rows.add([
          student.fullName,
          student.email,
          attempt.attemptNumber,
          _dateFormat.format(attempt.startedAt),
          attempt.submittedAt != null ? _dateFormat.format(attempt.submittedAt!) : 'In Progress',
          attempt.score?.toStringAsFixed(2) ?? '0',
          quiz.totalPoints,
          '${percentage.toStringAsFixed(1)}%'
        ]);
      }
    }

    await _saveFile('Quiz_${quiz.title}_Report', rows);
  }

  /// ---------------------------------------------------------
  /// 3. EXPORT FINAL GRADEBOOK (Course Level)
  /// Requirement: End-of-semester report with all columns
  /// ---------------------------------------------------------
  Future<void> exportCourseGradebook({
    required String courseName,
    required List<Student> students,
    required List<Assignment> assignments,
    required List<Quiz> quizzes,
    required List<AssignmentSubmission> allSubmissions,
    required List<QuizAttempt> allAttempts,
  }) async {
    // 1. Build Header Row (Removed Student ID)
    List<dynamic> headers = ['Full Name', 'Email', 'Group'];
    
    // Add columns for Assignments
    for (var a in assignments) {
      headers.add('ASS: ${a.title} (${a.totalPoints}pts)');
    }
    // Add columns for Quizzes
    for (var q in quizzes) {
      headers.add('QUIZ: ${q.title} (${q.totalPoints}pts)');
    }
    // Add Total Column
    headers.add('TOTAL SCORE');

    List<List<dynamic>> rows = [headers];

    // 2. Build Student Rows
    for (var student in students) {
      double totalStudentScore = 0;
      double maxPossibleScore = 0; // Calculated but currently unused in row data

      // Row Data (Removed student.id)
      List<dynamic> row = [
        student.fullName,
        student.email,
        student.groupMap.values.join(', '),
      ];

      // -- Process Assignments --
      for (var assignment in assignments) {
        final sub = allSubmissions
            .cast<AssignmentSubmission?>()
            .firstWhere(
              (s) => s?.assignmentId == assignment.id && s?.studentId == student.id,
              orElse: () => null,
            );
        
        double score = sub?.grade ?? 0.0;
        row.add(score);
        
        totalStudentScore += score;
        maxPossibleScore += assignment.totalPoints;
      }

      // -- Process Quizzes --
      for (var quiz in quizzes) {
        // Find best score for this quiz
        final studentAttempts = allAttempts.where(
          (a) => a.quizId == quiz.id && a.studentId == student.id && a.isCompleted
        ).toList();

        double bestScore = 0;
        if (studentAttempts.isNotEmpty) {
           // Get max score from attempts
           bestScore = studentAttempts
               .map((a) => a.score ?? 0.0)
               .reduce((a, b) => a > b ? a : b);
        }

        row.add(bestScore.toStringAsFixed(2));
        
        totalStudentScore += bestScore;
        maxPossibleScore += quiz.totalPoints;
      }

      // -- Total Score Column --
      row.add(totalStudentScore.toStringAsFixed(2));

      rows.add(row);
    }

    await _saveFile('${courseName}_Final_Gradebook', rows);
  }

  /// Helper: Save File Cross-Platform
  Future<void> _saveFile(String fileName, List<List<dynamic>> rows) async {
    String csvData = const ListToCsvConverter().convert(rows);
    
    // Add UTF-8 BOM for Excel compatibility (Important for Vietnamese names)
    final List<int> bytes = utf8.encode('\uFEFF$csvData'); 
    
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      ext: 'csv',
      mimeType: MimeType.csv,
    );
  }
}