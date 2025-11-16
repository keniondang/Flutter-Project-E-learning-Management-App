import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/quiz.dart';
import '../models/student.dart'; // ✅ --- ADD THIS IMPORT --- ✅

class QuizSubmissionProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ✅ --- Use the new model --- ✅
  List<QuizAttempt> _submissions = [];
  bool _isLoading = false;
  String? _error;

  // ✅ --- Use the new model --- ✅
  List<QuizAttempt> get submissions => _submissions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load submissions for a specific quiz
  Future<void> loadSubmissions(String quizId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('quiz_attempts')
          .select('*, users!quiz_attempts_student_id_fkey(full_name)')
          .eq('quiz_id', quizId)
          .eq('is_completed', true) // We only care about completed attempts
          .order('submitted_at', ascending: false);

      // ✅ --- Parse into the new model --- ✅
      _submissions = (response as List)
          .map((json) => QuizAttempt.fromJson(json))
          .toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading submissions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ --- ADDED HELPER FUNCTION --- ✅
  // Gets the latest submission for a student
  QuizAttempt? getSubmissionForStudent(String studentId) {
    try {
      // Find all submissions for this student and sort by attempt number
      var studentSubmissions = _submissions
          .where((s) => s.studentId == studentId)
          .toList();
      if (studentSubmissions.isEmpty) return null;

      studentSubmissions.sort(
        (a, b) => b.attemptNumber.compareTo(a.attemptNumber),
      );
      return studentSubmissions.first;
    } catch (e) {
      return null;
    }
  }

  // ✅ --- MODIFIED CSV EXPORT --- ✅
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
          'Attempt Number',
          'Score',
          'Total Points',
          'Percentage',
          'Submitted At',
        ],
      ];

      // Rows
      for (var student in allStudents) {
        // Find this student's submission
        final submission = getSubmissionForStudent(student.id);

        if (submission != null) {
          // Student has submitted
          final score = submission.score ?? 0.0;
          final totalPoints = quiz.totalPoints;
          final percentage = totalPoints > 0
              ? (score / totalPoints) * 100
              : 0.0;

          csvData.add([
            student.fullName,
            'Submitted',
            submission.attemptNumber,
            score.toStringAsFixed(2),
            totalPoints.toString(),
            '${percentage.toStringAsFixed(2)}%',
            submission.submittedAt != null
                ? submission.submittedAt!.toIso8601String()
                : 'N/A',
          ]);
        } else {
          // Student has not submitted
          csvData.add([
            student.fullName,
            'Not Submitted',
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
              ..setAttribute('download', 'quiz_${quiz.title}_submissions.csv')
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
