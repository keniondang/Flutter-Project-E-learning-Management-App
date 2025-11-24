import 'package:csv/csv.dart';
import 'package:elearning_management_app/models/quiz.dart';
import 'package:elearning_management_app/models/student.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

class QuizAttemptProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'quiz-attempt-box';

  List<QuizAttempt> _submissions = [];
  List<QuizAttempt> get submissions => _submissions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Load submissions for a specific quiz
  Future<void> loadSubmissions(String quizId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<QuizAttempt>(_boxName);

    if (!box.values.any((x) => x.quizId == quizId)) {
      try {
        final response = await _supabase
            .from('quiz_attempts')
            .select('*, users!quiz_attempts_student_id_fkey(full_name)')
            .eq('quiz_id', quizId)
            .eq('is_completed', true) // We only care about completed attempts
            .order('submitted_at', ascending: false);

        await box.putAll(Map.fromEntries(response
            .map((json) => MapEntry(json['id'], QuizAttempt.fromJson(json)))));
      } catch (e) {
        _error = e.toString();
        print('Error loading submissions: $e');
      }
    }

    _submissions = box.values.where((x) => x.quizId == quizId).toList();

    _isLoading = false;
    notifyListeners();
  }

  // ✅ UPDATED: Gets the HIGHEST scoring submission for a student
  QuizAttempt? getSubmissionForStudent(String studentId) {
    try {
      // Find all submissions for this student
      var studentSubmissions =
          _submissions.where((s) => s.studentId == studentId).toList();
      
      if (studentSubmissions.isEmpty) return null;

      // Sort by score (highest first), then by attempt number (latest first)
      studentSubmissions.sort((a, b) {
        // First compare scores
        final scoreA = a.score ?? 0.0;
        final scoreB = b.score ?? 0.0;
        
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA); // Higher score first
        }
        
        // If scores are equal, return the latest attempt
        return b.attemptNumber.compareTo(a.attemptNumber);
      });
      
      return studentSubmissions.first;
    } catch (e) {
      return null;
    }
  }

  // ✅ NEW: Get all attempts for a student (for viewing history)
  List<QuizAttempt> getAllAttemptsForStudent(String studentId) {
    var attempts = _submissions.where((s) => s.studentId == studentId).toList();
    attempts.sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
    return attempts;
  }

  // Now requires the full list of students to include those who haven't submitted
  Future<String?> exportSubmissionsToCSV(
    Quiz quiz,
    List<Student> allStudents,
  ) async {
    if (allStudents.isEmpty) {
      return 'No students to export';
    }

    try {
      List<List<dynamic>> csvData = [
        // Headers
        [
          'Student Name',
          'Status',
          'Total Attempts',
          'Highest Score',
          'Total Points',
          'Percentage',
          'Best Attempt Number',
          'Last Submitted At',
        ],
      ];

      // Rows
      for (var student in allStudents) {
        // Find this student's HIGHEST scoring attempt
        final bestSubmission = getSubmissionForStudent(student.id);
        final allAttempts = getAllAttemptsForStudent(student.id);

        if (bestSubmission != null) {
          // Student has submitted
          final score = bestSubmission.score ?? 0.0;
          final totalPoints = quiz.totalPoints;
          final percentage =
              totalPoints > 0 ? (score / totalPoints) * 100 : 0.0;

          csvData.add([
            student.fullName,
            'Submitted',
            allAttempts.length,
            score.toStringAsFixed(2),
            totalPoints.toString(),
            '${percentage.toStringAsFixed(2)}%',
            bestSubmission.attemptNumber,
            bestSubmission.submittedAt != null
                ? bestSubmission.submittedAt!.toIso8601String()
                : 'N/A',
          ]);
        } else {
          // Student has not submitted
          csvData.add([
            student.fullName,
            'Not Submitted',
            0,
            'N/A',
            'N/A',
            'N/A',
            'N/A',
            'N/A',
          ]);
        }
      }

      String csv = const ListToCsvConverter().convert(csvData);

      // Web download
      if (kIsWeb) {
        final bytes = Uri.encodeComponent(csv);
        final anchor =
            html.AnchorElement(href: 'data:text/plain;charset=utf-8,$bytes')
              ..setAttribute('download', 'quiz_${quiz.title}_results.csv')
              ..click();
      } else {
        // Mobile/Desktop will be implemented later
        return 'Export only available on web for now.';
      }

      return null;
    } catch (e) {
      print('Error exporting CSV: $e');
      return e.toString();
    }
  }
}
