import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz.dart';

class QuestionBankProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'question-box';

  List<Question> _questions = [];
  List<Question> get questions => _questions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Load questions for a course
  Future<void> loadQuestions(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Question>(_boxName);

    if (!box.values.any((x) => x.courseId == courseId)) {
      try {
        final response = await _supabase
            .from('question_bank')
            .select()
            .eq('course_id', courseId)
            .order('created_at', ascending: false);

        await box.putAll(Map.fromEntries(response
            .map((json) => MapEntry(json['id'], Question.fromJson(json)))));
      } catch (e) {
        _error = e.toString();
        print('Error loading questions: $e');
      }
    }

    _questions = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  // Create new question
  Future<bool> createQuestion({
    required String courseId,
    required String questionText,
    required List<QuestionOption> options,
    required String difficulty,
  }) async {
    try {
      final response = await _supabase.from('question_bank').insert({
        'course_id': courseId,
        'question_text': questionText,
        'options': options.map((opt) => opt.toJson()).toList(),
        'difficulty': difficulty,
      }).select();

      final question = response.map((json) => Question.fromJson(json)).first;

      final box = await Hive.openBox<Question>(_boxName);

      await box.put(question.id, question);
      _questions.add(question);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update question
  Future<bool> updateQuestion({
    required String id,
    required String questionText,
    required List<QuestionOption> options,
    required String difficulty,
  }) async {
    try {
      final response = await _supabase
          .from('question_bank')
          .update({
            'question_text': questionText,
            'options': options.map((opt) => opt.toJson()).toList(),
            'difficulty': difficulty,
          })
          .eq('id', id)
          .select();

      final question = response.map((json) => Question.fromJson(json)).first;

      final box = await Hive.openBox<Question>(_boxName);

      await box.put(question.id, question);
      _questions[_questions.indexWhere((x) => x.id == question.id)] = question;

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete question
  Future<bool> deleteQuestion(String id) async {
    try {
      await _supabase.from('question_bank').delete().eq('id', id);
      final box = await Hive.openBox<Question>(_boxName);

      await box.delete(id);
      _questions.removeWhere((q) => q.id == id);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }

  // Get questions by difficulty for quiz
  List<Question> getQuestionsByDifficulty(String difficulty, int count) {
    final filtered =
        _questions.where((q) => q.difficulty == difficulty).toList();

    filtered.shuffle();
    return filtered.take(count).toList();
  }
}
