class Assignment {
  final String id;
  final String courseId;
  final String instructorId;
  final String title;
  final String description;
  final List<String> fileAttachments;
  final DateTime startDate;
  final DateTime dueDate;
  final bool lateSubmissionAllowed;
  final DateTime? lateDueDate;
  final int maxAttempts;
  final int maxFileSize;
  final List<String> allowedFileTypes;
  final String scopeType;
  final List<String> targetGroups;
  final int totalPoints;
  final DateTime createdAt;

  final String? semesterId;

  // Additional fields for display
  final int? submissionCount;
  final bool? hasSubmitted;
  final double? grade;

  Assignment({
    required this.id,
    required this.courseId,
    required this.instructorId,
    required this.title,
    required this.description,
    required this.fileAttachments,
    required this.startDate,
    required this.dueDate,
    required this.lateSubmissionAllowed,
    this.lateDueDate,
    required this.maxAttempts,
    required this.maxFileSize,
    required this.allowedFileTypes,
    required this.scopeType,
    required this.targetGroups,
    required this.totalPoints,
    required this.createdAt,
    this.semesterId,
    this.submissionCount,
    this.hasSubmitted,
    this.grade,
  });

  factory Assignment.fromJson(
      {required Map<String, dynamic> json,
      String? semesterId,
      int? submissionCount}) {
    return Assignment(
      id: json['id'],
      courseId: json['course_id'],
      instructorId: json['instructor_id'],
      title: json['title'],
      description: json['description'],
      fileAttachments: List<String>.from(json['file_attachments'] ?? []),
      startDate: DateTime.parse(json['start_date']),
      dueDate: DateTime.parse(json['due_date']),
      lateSubmissionAllowed: json['late_submission_allowed'] ?? false,
      lateDueDate: json['late_due_date'] != null
          ? DateTime.parse(json['late_due_date'])
          : null,
      maxAttempts: json['max_attempts'] ?? 1,
      maxFileSize: json['max_file_size'] ?? 10485760,
      allowedFileTypes: List<String>.from(json['allowed_file_types'] ?? []),
      scopeType: json['scope_type'],
      targetGroups: List<String>.from(json['target_groups'] ?? []),
      totalPoints: json['total_points'] ?? 100,
      createdAt: DateTime.parse(json['created_at']),
      submissionCount: submissionCount ?? json['submission_count'],
      hasSubmitted: json['has_submitted'],
      grade: json['grade']?.toDouble(),
      semesterId: semesterId ?? json['semester_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'instructor_id': instructorId,
      'title': title,
      'description': description,
      'file_attachments': fileAttachments,
      'start_date': startDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'late_submission_allowed': lateSubmissionAllowed,
      'late_due_date': lateDueDate?.toIso8601String(),
      'max_attempts': maxAttempts,
      'max_file_size': maxFileSize,
      'allowed_file_types': allowedFileTypes,
      'scope_type': scopeType,
      'target_groups': targetGroups,
      'total_points': totalPoints,
    };
  }

  bool get isOpen {
    final now = DateTime.now();
    return now.isAfter(startDate) &&
        (lateSubmissionAllowed && lateDueDate != null
            ? now.isBefore(lateDueDate!)
            : now.isBefore(dueDate));
  }

  bool get isPastDue {
    return DateTime.now().isAfter(dueDate);
  }
}

class AssignmentSubmission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final List<String> submissionFiles;
  final String? submissionText;
  final int attemptNumber;
  final DateTime submittedAt;
  final bool isLate;
  final double? grade;
  final String? feedback;
  final DateTime? gradedAt;

  AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    required this.submissionFiles,
    this.submissionText,
    required this.attemptNumber,
    required this.submittedAt,
    required this.isLate,
    this.grade,
    this.feedback,
    this.gradedAt,
  });

  factory AssignmentSubmission.fromJson(
      {required Map<String, dynamic> json, String? studentName}) {
    return AssignmentSubmission(
      id: json['id'],
      assignmentId: json['assignment_id'],
      studentId: json['student_id'],
      studentName: studentName ?? 'Unknown',
      submissionFiles: List<String>.from(json['submission_files'] ?? []),
      submissionText: json['submission_text'],
      attemptNumber: json['attempt_number'] ?? 1,
      submittedAt: DateTime.parse(json['submitted_at']),
      isLate: json['is_late'] ?? false,
      grade: json['grade']?.toDouble(),
      feedback: json['feedback'],
      gradedAt:
          json['graded_at'] != null ? DateTime.parse(json['graded_at']) : null,
    );
  }
}
