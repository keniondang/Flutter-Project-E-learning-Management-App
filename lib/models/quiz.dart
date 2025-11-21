class Quiz {
  final String id;
  final String courseId;
  final String instructorId;
  final String title;
  final String? description;
  final DateTime openTime;
  final DateTime closeTime;
  final int durationMinutes;
  final int maxAttempts;
  final int easyQuestions;
  final int mediumQuestions;
  final int hardQuestions;
  final int totalPoints;
  final String scopeType;
  final List<String> targetGroups;
  final DateTime createdAt;

  final String? semesterId;

  // Additional fields
  final int? attemptCount;
  final double? highestScore;
  final bool? isCompleted;

  final int? submissionCount;

  Quiz({
    required this.id,
    required this.courseId,
    required this.instructorId,
    required this.title,
    this.description,
    required this.openTime,
    required this.closeTime,
    required this.durationMinutes,
    required this.maxAttempts,
    required this.easyQuestions,
    required this.mediumQuestions,
    required this.hardQuestions,
    required this.totalPoints,
    required this.scopeType,
    required this.targetGroups,
    required this.createdAt,
    this.attemptCount,
    this.highestScore,
    this.isCompleted,
    this.submissionCount, // ✅ Add to constructor
    this.semesterId,
  });

  factory Quiz.fromJson(
      {required Map<String, dynamic> json,
      String? semesterId,
      int? submissionCount}) {
    return Quiz(
        id: json['id'],
        courseId: json['course_id'],
        instructorId: json['instructor_id'],
        title: json['title'],
        description: json['description'],
        openTime: DateTime.parse(json['open_time']),
        closeTime: DateTime.parse(json['close_time']),
        durationMinutes: json['duration_minutes'],
        maxAttempts: json['max_attempts'] ?? 1,
        easyQuestions: json['easy_questions'] ?? 0,
        mediumQuestions: json['medium_questions'] ?? 0,
        hardQuestions: json['hard_questions'] ?? 0,
        totalPoints: json['total_points'] ?? 100,
        scopeType: json['scope_type'],
        targetGroups: List<String>.from(json['target_groups'] ?? []),
        createdAt: DateTime.parse(json['created_at']),
        attemptCount: json['attempt_count'],
        highestScore: json['highest_score']?.toDouble(),
        isCompleted: json['is_completed'],
        submissionCount: submissionCount ?? json['submission_count'],
        semesterId: semesterId ?? json['semester_id']);
  }

  Map<String, dynamic> toJson() {
    return {
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
    };
  }

  int get totalQuestions => easyQuestions + mediumQuestions + hardQuestions;

  bool get isOpen {
    final now = DateTime.now();
    return now.isAfter(openTime) && now.isBefore(closeTime);
  }

  bool get isPastDue {
    return DateTime.now().isAfter(closeTime);
  }
}

class Question {
  final String id;
  final String courseId;
  final String questionText;
  final List<QuestionOption> options;
  final String difficulty;
  final DateTime createdAt;

  Question({
    required this.id,
    required this.courseId,
    required this.questionText,
    required this.options,
    required this.difficulty,
    required this.createdAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final optionsList = (json['options'] as List)
        .map((opt) => QuestionOption.fromJson(opt))
        .toList();

    return Question(
      id: json['id'],
      courseId: json['course_id'],
      questionText: json['question_text'],
      options: optionsList,
      difficulty: json['difficulty'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'question_text': questionText,
      'options': options.map((opt) => opt.toJson()).toList(),
      'difficulty': difficulty,
    };
  }
}

class QuestionOption {
  final String text;
  final bool isCorrect;

  QuestionOption({required this.text, required this.isCorrect});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      text: json['text'],
      isCorrect: json['isCorrect'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'isCorrect': isCorrect};
  }
}

class QuizAttempt {
  final String id;
  final String quizId;
  final String studentId;
  final String studentName;
  final int attemptNumber;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final double? score;
  final bool isCompleted;

  QuizAttempt({
    required this.id,
    required this.quizId,
    required this.studentId,
    required this.studentName,
    required this.attemptNumber,
    required this.startedAt,
    this.submittedAt,
    this.score,
    required this.isCompleted,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: json['id'],
      quizId: json['quiz_id'],
      studentId: json['student_id'],
      // 'users' table is joined in the provider, 'full_name' is nested
      studentName: json['users']?['full_name'] ?? 'Unknown Student',
      attemptNumber: json['attempt_number'] ?? 1,
      startedAt: DateTime.parse(json['started_at']),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : null,
      score: json['score']?.toDouble(),
      isCompleted: json['is_completed'] ?? false,
    );
  }
}
