import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../models/quiz.dart';
import '../../models/user_model.dart';
import '../../providers/question_bank_provider.dart';

class QuizTakingScreen extends StatefulWidget {
  final Quiz quiz;
  final UserModel student;

  const QuizTakingScreen({
    Key? key,
    required this.quiz,
    required this.student,
  }) : super(key: key);

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Question> _questions = [];
  Map<String, String> _answers = {};
  int _currentQuestionIndex = 0;
  Timer? _timer;
  int _remainingSeconds = 0;
  String? _attemptId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentAttemptNumber = 1;

  @override
  void initState() {
    super.initState();
    _checkAndStartQuiz();
  }

  // ✅ --- NEW FUNCTION TO FIX MAX ATTEMPTS BUG --- ✅
  Future<void> _checkAndStartQuiz() async {
    try {
      // 1. Check for existing completed attempts
      final response = await _supabase
          .from('quiz_attempts')
          .select('id')
          .eq('quiz_id', widget.quiz.id)
          .eq('student_id', widget.student.id)
          .eq('is_completed', true);

      final completedAttempts = (response as List).length;

      // 2. Compare to max attempts
      if (completedAttempts >= widget.quiz.maxAttempts) {
        // No attempts left
        setState(() => _isLoading = false);
        if (mounted) {
          _showMaxAttemptsDialog();
        }
        return;
      }

      // 3. Set current attempt number
      _currentAttemptNumber = completedAttempts + 1;

      // 4. Proceed to initialize quiz
      await _initializeQuiz();
    } catch (e) {
      print('Error checking attempts: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMaxAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Max Attempts Reached',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You have already used all ${widget.quiz.maxAttempts} attempt(s) for this quiz.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close quiz screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeQuiz() async {
    // Load questions from question bank
    await context.read<QuestionBankProvider>().loadQuestions(widget.quiz.courseId);
    
    // Get random questions based on difficulty
    final provider = context.read<QuestionBankProvider>();
    final easyQuestions = provider.getQuestionsByDifficulty('easy', widget.quiz.easyQuestions);
    final mediumQuestions = provider.getQuestionsByDifficulty('medium', widget.quiz.mediumQuestions);
    final hardQuestions = provider.getQuestionsByDifficulty('hard', widget.quiz.hardQuestions);
    
    setState(() {
      _questions = [...easyQuestions, ...mediumQuestions, ...hardQuestions];
      _questions.shuffle(); // Randomize question order
      _remainingSeconds = widget.quiz.durationMinutes * 60;
      _isLoading = false;
    });

    if (_questions.isEmpty) {
      return; // Stop if no questions
    }

    // Create quiz attempt record
    try {
      final response = await _supabase.from('quiz_attempts').insert({
        'quiz_id': widget.quiz.id,
        'student_id': widget.student.id,
        'attempt_number': _currentAttemptNumber, // ✅ Use correct attempt number
        'started_at': DateTime.now().toIso8601String(),
        'is_completed': false, // ✅ Set to false initially
      }).select().single();
      
      _attemptId = response['id'];
    } catch (e) {
      print('Error creating quiz attempt: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Start timer
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _submitQuiz();
        }
      });
    });
  }

  void _selectAnswer(String questionId, String answer) {
    setState(() {
      _answers[questionId] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _attemptId == null) return;
    
    setState(() => _isSubmitting = true);
    _timer?.cancel();

    // Calculate score
    double score = 0;
    final pointsPerQuestion = _questions.isNotEmpty 
        ? widget.quiz.totalPoints / _questions.length 
        : 0.0;
    
    for (var question in _questions) {
      final userAnswer = _answers[question.id];
      if (userAnswer != null) {
        final correctOption = question.options.firstWhere((opt) => opt.isCorrect);
        if (userAnswer == correctOption.text) {
          score += pointsPerQuestion;
        }
      }
    }

    // Save quiz attempt
    try {
      await _supabase.from('quiz_attempts').update({
        'submitted_at': DateTime.now().toIso8601String(),
        'score': score,
        'answers': _answers,
        'is_completed': true, // ✅ Mark as completed
      }).eq('id', _attemptId!);

      if (mounted) {
        // Show results
        _showResults(score);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting quiz: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showResults(double score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Quiz Completed!',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              score >= (widget.quiz.totalPoints * 0.7)
                  ? Icons.celebration
                  : Icons.sentiment_satisfied,
              size: 60,
              color: score >= (widget.quiz.totalPoints * 0.7)
                  ? Colors.green
                  : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Your Score',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            Text(
              '${score.toStringAsFixed(1)} / ${widget.quiz.totalPoints}',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: score >= (widget.quiz.totalPoints * 0.7)
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(widget.quiz.totalPoints > 0 ? (score / widget.quiz.totalPoints) * 100 : 0).toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close quiz screen
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Quiz', style: GoogleFonts.poppins()),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, size: 60, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'No questions available for this quiz',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title, style: GoogleFonts.poppins()),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _remainingSeconds < 60 ? Colors.red : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: _remainingSeconds < 60 ? Colors.white : Colors.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: _remainingSeconds < 60 ? Colors.white : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: Colors.grey[200],
          ),
          
          // Question counter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                Chip(
                  label: Text(
                    currentQuestion.difficulty.toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: currentQuestion.difficulty == 'easy'
                      ? Colors.green[100]
                      : currentQuestion.difficulty == 'medium'
                          ? Colors.orange[100]
                          : Colors.red[100],
                ),
              ],
            ),
          ),

          // Question content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentQuestion.questionText,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ...currentQuestion.options.map((option) {
                    final isSelected = _answers[currentQuestion.id] == option.text;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isSelected ? Colors.blue[50] : null,
                      child: RadioListTile<String>(
                        title: Text(
                          option.text,
                          style: GoogleFonts.poppins(),
                        ),
                        value: option.text,
                        groupValue: _answers[currentQuestion.id],
                        onChanged: (value) {
                          if (value != null) {
                            _selectAnswer(currentQuestion.id, value);
                          }
                        },
                        activeColor: Colors.blue,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: const Text('Previous'),
                ),
                const Spacer(),
                if (_currentQuestionIndex < _questions.length - 1)
                  ElevatedButton(
                    onPressed: _nextQuestion,
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Submit Quiz?'),
                          content: Text(
                            'You have answered ${_answers.length} out of ${_questions.length} questions. Are you sure you want to submit?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Review'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _submitQuiz();
                              },
                              child: const Text('Submit'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Submit Quiz'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}