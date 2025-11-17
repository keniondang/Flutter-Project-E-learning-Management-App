import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz.dart';

class QuizProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  int? _semesterCount;
  int? get semesterCount => _semesterCount;

  List<Quiz> _quizzes = [];
  List<Quiz> get quizzes => _quizzes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadQuizzes(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('quizzes')
          .select()
          .eq('course_id', courseId)
          .order('close_time', ascending: true);

      _quizzes = (response as List).map((json) => Quiz.fromJson(json)).toList();

      for (var quiz in _quizzes) {
        await _loadQuizStats(quiz);
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading quizzes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> countForSemester(String semesterId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('quizzes')
          .select('id, courses(id)')
          .eq('courses.semester_id', semesterId)
          .count(CountOption.estimated);

      _semesterCount = response.count;
    } catch (e) {
      _error = e.toString();
      print('Error loading quizzes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadQuizStats(Quiz quiz) async {
    try {
      final submissionResponse = await _supabase
          .from('quiz_attempts')
          .select('id')
          .eq('quiz_id', quiz.id)
          .eq('is_completed', true); // Only count completed attempts

      final index = _quizzes.indexWhere((q) => q.id == quiz.id);
      if (index != -1) {
        _quizzes[index] = Quiz(
          id: quiz.id,
          courseId: quiz.courseId,
          instructorId: quiz.instructorId,
          title: quiz.title,
          description: quiz.description,
          openTime: quiz.openTime,
          closeTime: quiz.closeTime,
          durationMinutes: quiz.durationMinutes,
          maxAttempts: quiz.maxAttempts,
          easyQuestions: quiz.easyQuestions,
          mediumQuestions: quiz.mediumQuestions,
          hardQuestions: quiz.hardQuestions,
          totalPoints: quiz.totalPoints,
          scopeType: quiz.scopeType,
          targetGroups: quiz.targetGroups,
          createdAt: quiz.createdAt,
          submissionCount: (submissionResponse as List).length,
        );
      }
    } catch (e) {
      print('Error loading quiz stats: $e');
    }
  }

  Future<bool> createQuiz({
    required String courseId,
    required String instructorId,
    required String title,
    String? description,
    required DateTime openTime,
    required DateTime closeTime,
    required int durationMinutes,
    required int maxAttempts,
    required int easyQuestions,
    required int mediumQuestions,
    required int hardQuestions,
    required int totalPoints,
    required String scopeType,
    required List<String> targetGroups,
  }) async {
    try {
      await _supabase.from('quizzes').insert({
        'course_id': courseId,
        'instructor_id': instructorId,
        'title': title,
        'description': description,
        'open_time': openTime.toIso8601String(),
        'close_time': closeTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'max_attempts': maxAttempts,
        'easy_questions': easyQuestions,
        'medium_questions': mediumQuestions,
        'hard_questions': hardQuestions,
        'total_points': totalPoints,
        'scope_type': scopeType,
        'target_groups': targetGroups,
      });

      await loadQuizzes(courseId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
