import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz.dart';

class StudentQuizProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _quizBoxName = 'student-quiz-box';
  final _attemptBoxName = 'student-quiz-attempt-box';

  List<Quiz> _quizzes = [];
  List<Quiz> get quizzes => _quizzes;

  Map<String, List<QuizAttempt>> _attemptsByQuiz = {};
  Map<String, List<QuizAttempt>> get attemptsByQuiz => _attemptsByQuiz;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Load quizzes for a course with student's attempt data
  Future<void> loadQuizzesForStudent(String courseId, String studentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final quizBox = await Hive.openBox<Quiz>(_quizBoxName);
      final attemptBox = await Hive.openBox<QuizAttempt>(_attemptBoxName);

      // Always fetch fresh data to get latest attempts
      final response = await _supabase
          .from('quizzes')
          .select('*, courses(semester_id)')
          .eq('course_id', courseId)
          .order('close_time', ascending: true);

      // Clear old quizzes for this course
      final oldQuizzes = quizBox.values
          .where((q) => q.courseId == courseId)
          .map((q) => q.id)
          .toList();
      for (var quizId in oldQuizzes) {
        await quizBox.delete(quizId);
      }

      // Process each quiz and load student's attempts
      for (var quizJson in response) {
        final quizId = quizJson['id'];

        // Get all attempts for this student on this quiz
        final attemptsResponse = await _supabase
            .from('quiz_attempts')
            .select()
            .eq('quiz_id', quizId)
            .eq('student_id', studentId)
            .order('attempt_number', ascending: true);

        final attempts = (attemptsResponse as List)
            .map((json) => QuizAttempt.fromJson({
                  ...json,
                  'users': {'full_name': 'You'}
                }))
            .toList();

        // Calculate student-specific stats
        final completedAttempts =
            attempts.where((a) => a.isCompleted).toList();
        final attemptCount = completedAttempts.length;
        final highestScore = completedAttempts.isEmpty
            ? null
            : completedAttempts
                .map((a) => a.score ?? 0.0)
                .reduce((a, b) => a > b ? a : b);
        final isCompleted = attemptCount > 0;

        // Get total submission count (for instructor)
        final submissionResponse = await _supabase
            .from('quiz_attempts')
            .select('id')
            .eq('quiz_id', quizId)
            .eq('is_completed', true)
            .count();

        // Create Quiz with student-specific data
        final quiz = Quiz.fromJson(
          json: quizJson,
          semesterId: quizJson['courses']['semester_id'],
          submissionCount: submissionResponse.count,
        ).copyWith(
          attemptCount: attemptCount,
          highestScore: highestScore,
          isCompleted: isCompleted,
        );

        // Save to Hive
        await quizBox.put(quiz.id, quiz);

        // Save attempts to Hive and memory
        _attemptsByQuiz[quizId] = attempts;
        for (var attempt in attempts) {
          await attemptBox.put('${quizId}_${attempt.attemptNumber}', attempt);
        }
      }

      _quizzes = quizBox.values.where((q) => q.courseId == courseId).toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading quizzes for student: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Get attempts for a specific quiz
  List<QuizAttempt> getAttemptsForQuiz(String quizId) {
    return _attemptsByQuiz[quizId] ?? [];
  }

  // Get highest score for a quiz
  double? getHighestScore(String quizId) {
    final attempts = getAttemptsForQuiz(quizId);
    final completedAttempts = attempts.where((a) => a.isCompleted).toList();

    if (completedAttempts.isEmpty) return null;

    return completedAttempts
        .map((a) => a.score ?? 0.0)
        .reduce((a, b) => a > b ? a : b);
  }

  // Check if student can attempt quiz
  bool canAttemptQuiz(String quizId) {
    final quiz = _quizzes.firstWhere((q) => q.id == quizId);
    final attempts = getAttemptsForQuiz(quizId);
    final completedAttempts = attempts.where((a) => a.isCompleted).length;

    return quiz.isOpen && completedAttempts < quiz.maxAttempts;
  }

  // Get remaining attempts
  int getRemainingAttempts(String quizId) {
    final quiz = _quizzes.firstWhere((q) => q.id == quizId);
    final attempts = getAttemptsForQuiz(quizId);
    final completedAttempts = attempts.where((a) => a.isCompleted).length;

    return quiz.maxAttempts - completedAttempts;
  }

  // Start a new quiz attempt
  Future<QuizAttempt?> startQuizAttempt(String quizId, String studentId) async {
    try {
      final attempts = getAttemptsForQuiz(quizId);
      final nextAttemptNumber =
          attempts.isEmpty ? 1 : attempts.last.attemptNumber + 1;

      final response = await _supabase.from('quiz_attempts').insert({
        'quiz_id': quizId,
        'student_id': studentId,
        'attempt_number': nextAttemptNumber,
        'started_at': DateTime.now().toIso8601String(),
        'is_completed': false,
      }).select();

      final attempt = QuizAttempt.fromJson({
        ...response.first,
        'users': {'full_name': 'You'}
      });

      // Update local state
      _attemptsByQuiz[quizId] = [...attempts, attempt];
      
      final attemptBox = await Hive.openBox<QuizAttempt>(_attemptBoxName);
      await attemptBox.put('${quizId}_${attempt.attemptNumber}', attempt);

      notifyListeners();
      return attempt;
    } catch (e) {
      _error = e.toString();
      print('Error starting quiz attempt: $e');
      return null;
    }
  }

  // Submit quiz attempt
  Future<bool> submitQuizAttempt({
    required String attemptId,
    required double score,
  }) async {
    try {
      await _supabase.from('quiz_attempts').update({
        'submitted_at': DateTime.now().toIso8601String(),
        'score': score,
        'is_completed': true,
      }).eq('id', attemptId);

      // Refresh data
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error submitting quiz attempt: $e');
      return false;
    }
  }
}

// Extension to add copyWith method to Quiz
extension QuizCopyWith on Quiz {
  Quiz copyWith({
    int? attemptCount,
    double? highestScore,
    bool? isCompleted,
    int? submissionCount,
  }) {
    return Quiz(
      id: id,
      courseId: courseId,
      instructorId: instructorId,
      title: title,
      description: description,
      openTime: openTime,
      closeTime: closeTime,
      durationMinutes: durationMinutes,
      maxAttempts: maxAttempts,
      easyQuestions: easyQuestions,
      mediumQuestions: mediumQuestions,
      hardQuestions: hardQuestions,
      totalPoints: totalPoints,
      scopeType: scopeType,
      targetGroups: targetGroups,
      createdAt: createdAt,
      semesterId: semesterId,
      attemptCount: attemptCount ?? this.attemptCount,
      highestScore: highestScore ?? this.highestScore,
      isCompleted: isCompleted ?? this.isCompleted,
      submissionCount: submissionCount ?? this.submissionCount,
    );
  }
}
