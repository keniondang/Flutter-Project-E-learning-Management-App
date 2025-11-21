import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz.dart';

class QuizProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'box-name';

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

    final box = await Hive.openBox<Quiz>(_boxName);

    if (!box.values.any((x) => x.courseId == courseId)) {
      try {
        final response = await _supabase
            .from('quizzes')
            .select('*, courses(semester_id)')
            .eq('course_id', courseId);

        await box.putAll(
            Map.fromEntries(await Future.wait(response.map((json) async {
          final quiz = Quiz.fromJson(
              json: json,
              semesterId: json['courses']['semester_id'],
              submissionCount: await _fetchSubmissionCount(json['id']));

          return MapEntry(quiz.id, quiz);
        }))));
      } catch (e) {
        _error = e.toString();
        print('Error loading quizzes: $e');
      }
    }

    _quizzes = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<int> countInSemester(String semesterId) async {
    final box = await Hive.openBox<Quiz>(_boxName);

    if (!box.values.any((x) => x.semesterId == semesterId)) {
      try {
        final response = await _supabase
            .from('quizzes')
            .select('*, courses(semester_id)')
            .eq('courses.semester_id', semesterId);

        await box.putAll(
            Map.fromEntries(await Future.wait(response.map((json) async {
          final quiz = Quiz.fromJson(
              json: json,
              semesterId: json['courses']['semester_id'],
              submissionCount: await _fetchSubmissionCount(json['id']));

          return MapEntry(quiz.id, quiz);
        }))));
      } catch (e) {
        _error = e.toString();
        print('Error loading quizzes: $e');
      }
    }

    return box.values.where((x) => x.semesterId == semesterId).length;
  }

  Future<int> _fetchSubmissionCount(String quizId) async {
    try {
      final response = await _supabase
          .from('quiz_attempts')
          .select('id')
          .eq('quiz_id', quizId)
          .eq('is_completed', true)
          .count(); // Only count completed attempts

      return response.count;
    } catch (e) {
      print('Error loading assignment stats: $e');
      return 0;
    }
  }

  // Future<void> _loadQuizStats(Quiz quiz) async {
  //   try {
  //     final submissionResponse = await _supabase
  //         .from('quiz_attempts')
  //         .select('id')
  //         .eq('quiz_id', quiz.id)
  //         .eq('is_completed', true); // Only count completed attempts

  //     final index = _quizzes.indexWhere((q) => q.id == quiz.id);
  //     if (index != -1) {
  //       _quizzes[index] = Quiz(
  //         id: quiz.id,
  //         courseId: quiz.courseId,
  //         instructorId: quiz.instructorId,
  //         title: quiz.title,
  //         description: quiz.description,
  //         openTime: quiz.openTime,
  //         closeTime: quiz.closeTime,
  //         durationMinutes: quiz.durationMinutes,
  //         maxAttempts: quiz.maxAttempts,
  //         easyQuestions: quiz.easyQuestions,
  //         mediumQuestions: quiz.mediumQuestions,
  //         hardQuestions: quiz.hardQuestions,
  //         totalPoints: quiz.totalPoints,
  //         scopeType: quiz.scopeType,
  //         targetGroups: quiz.targetGroups,
  //         createdAt: quiz.createdAt,
  //         submissionCount: (submissionResponse as List).length,
  //       );
  //     }
  //   } catch (e) {
  //     print('Error loading quiz stats: $e');
  //   }
  // }

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
      final response = await _supabase.from('quizzes').insert({
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
      }).select('*, courses(semester_id)');

      final quiz = response
          .map((json) => Quiz.fromJson(
              json: json,
              semesterId: json['courses']['semester_id'],
              submissionCount: 0))
          .first;

      final box = await Hive.openBox<Quiz>(_boxName);

      await box.put(quiz.id, quiz);
      _quizzes.add(quiz);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }
}
