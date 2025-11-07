import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz.dart';

class QuestionBankProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
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

    try {
      final response = await _supabase
          .from('question_bank')
          .select()
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      _questions = (response as List)
          .map((json) => Question.fromJson(json))
          .toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading questions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new question
  Future<bool> createQuestion({
    required String courseId,
    required String questionText,
    required List<QuestionOption> options,
    required String difficulty,
  }) async {
    try {
      await _supabase.from('question_bank').insert({
        'course_id': courseId,
        'question_text': questionText,
        'options': options.map((opt) => opt.toJson()).toList(),
        'difficulty': difficulty,
      });

      await loadQuestions(courseId);
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
      await _supabase.from('question_bank').update({
        'question_text': questionText,
        'options': options.map((opt) => opt.toJson()).toList(),
        'difficulty': difficulty,
      }).eq('id', id);

      final index = _questions.indexWhere((q) => q.id == id);
      if (index != -1) {
        await loadQuestions(_questions[index].courseId);
      }
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
    final filtered = _questions.where((q) => q.difficulty == difficulty).toList();
    filtered.shuffle();
    return filtered.take(count).toList();
  }
}