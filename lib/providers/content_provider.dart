import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement.dart';
import '../models/assignment.dart';
import '../models/quiz.dart';
import '../models/course_material.dart';

class ContentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Announcements
  List<Announcement> _announcements = [];
  List<Announcement> get announcements => _announcements;
  
  // Assignments
  List<Assignment> _assignments = [];
  List<Assignment> get assignments => _assignments;
  
  // Quizzes
  List<Quiz> _quizzes = [];
  List<Quiz> get quizzes => _quizzes;
  
  // Materials
  List<CourseMaterial> _materials = [];
  List<CourseMaterial> get materials => _materials;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _error;
  String? get error => _error;

  // Load all content for a course
  Future<void> loadCourseContent(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        loadAnnouncements(courseId),
        loadAssignments(courseId),
        loadQuizzes(courseId),
        loadMaterials(courseId),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ANNOUNCEMENTS
  Future<void> loadAnnouncements(String courseId) async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      _announcements = (response as List)
          .map((json) => Announcement.fromJson(json))
          .toList();
      
      // Load view counts and comment counts
      for (var announcement in _announcements) {
        await _loadAnnouncementStats(announcement);
      }
    } catch (e) {
      print('Error loading announcements: $e');
      throw e;
    }
  }

  Future<void> _loadAnnouncementStats(Announcement announcement) async {
    try {
      // Get view count
      final viewResponse = await _supabase
          .from('announcement_views')
          .select('id')
          .eq('announcement_id', announcement.id);
      
      // Get comment count
      final commentResponse = await _supabase
          .from('announcement_comments')
          .select('id')
          .eq('announcement_id', announcement.id);

      final index = _announcements.indexWhere((a) => a.id == announcement.id);
      if (index != -1) {
        _announcements[index] = Announcement(
          id: announcement.id,
          courseId: announcement.courseId,
          instructorId: announcement.instructorId,
          title: announcement.title,
          content: announcement.content,
          fileAttachments: announcement.fileAttachments,
          scopeType: announcement.scopeType,
          targetGroups: announcement.targetGroups,
          createdAt: announcement.createdAt,
          viewCount: (viewResponse as List).length,
          commentCount: (commentResponse as List).length,
        );
      }
    } catch (e) {
      print('Error loading announcement stats: $e');
    }
  }

  Future<bool> createAnnouncement({
    required String courseId,
    required String instructorId,
    required String title,
    required String content,
    required List<String> fileAttachments,
    required String scopeType,
    required List<String> targetGroups,
  }) async {
    try {
      await _supabase.from('announcements').insert({
        'course_id': courseId,
        'instructor_id': instructorId,
        'title': title,
        'content': content,
        'file_attachments': fileAttachments,
        'scope_type': scopeType,
        'target_groups': targetGroups,
      });

      await loadAnnouncements(courseId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ASSIGNMENTS
  Future<void> loadAssignments(String courseId) async {
    try {
      final response = await _supabase
          .from('assignments')
          .select()
          .eq('course_id', courseId)
          .order('due_date', ascending: true);

      _assignments = (response as List)
          .map((json) => Assignment.fromJson(json))
          .toList();
      
      // Load submission counts
      for (var assignment in _assignments) {
        await _loadAssignmentStats(assignment);
      }
    } catch (e) {
      print('Error loading assignments: $e');
      throw e;
    }
  }

  Future<void> _loadAssignmentStats(Assignment assignment) async {
    try {
      final submissionResponse = await _supabase
          .from('assignment_submissions')
          .select('id')
          .eq('assignment_id', assignment.id);

      final index = _assignments.indexWhere((a) => a.id == assignment.id);
      if (index != -1) {
        _assignments[index] = Assignment(
          id: assignment.id,
          courseId: assignment.courseId,
          instructorId: assignment.instructorId,
          title: assignment.title,
          description: assignment.description,
          fileAttachments: assignment.fileAttachments,
          startDate: assignment.startDate,
          dueDate: assignment.dueDate,
          lateSubmissionAllowed: assignment.lateSubmissionAllowed,
          lateDueDate: assignment.lateDueDate,
          maxAttempts: assignment.maxAttempts,
          maxFileSize: assignment.maxFileSize,
          allowedFileTypes: assignment.allowedFileTypes,
          scopeType: assignment.scopeType,
          targetGroups: assignment.targetGroups,
          totalPoints: assignment.totalPoints,
          createdAt: assignment.createdAt,
          submissionCount: (submissionResponse as List).length,
        );
      }
    } catch (e) {
      print('Error loading assignment stats: $e');
    }
  }

  Future<bool> createAssignment({
    required String courseId,
    required String instructorId,
    required String title,
    required String description,
    required List<String> fileAttachments,
    required DateTime startDate,
    required DateTime dueDate,
    required bool lateSubmissionAllowed,
    DateTime? lateDueDate,
    required int maxAttempts,
    required int maxFileSize,
    required List<String> allowedFileTypes,
    required String scopeType,
    required List<String> targetGroups,
    required int totalPoints,
  }) async {
    try {
      await _supabase.from('assignments').insert({
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
      });

      await loadAssignments(courseId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // QUIZZES
  Future<void> loadQuizzes(String courseId) async {
    try {
      final response = await _supabase
          .from('quizzes')
          .select()
          .eq('course_id', courseId)
          .order('close_time', ascending: true);

      _quizzes = (response as List)
          .map((json) => Quiz.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading quizzes: $e');
      throw e;
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

  // MATERIALS
  Future<void> loadMaterials(String courseId) async {
    try {
      final response = await _supabase
          .from('materials')
          .select()
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      _materials = (response as List)
          .map((json) => CourseMaterial.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading materials: $e');
      throw e;
    }
  }

Future<bool> createMaterial({
    required String courseId,
    required String instructorId,
    required String title,
    String? description,
    required List<String> fileUrls,
    required List<String> externalLinks,
  }) async {
    try {
      await _supabase.from('materials').insert({
        'course_id': courseId,
        'instructor_id': instructorId,
        'title': title,
        'description': description,
        'file_urls': fileUrls,
        'external_links': externalLinks,
      });

      await loadMaterials(courseId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Track announcement view
  Future<void> trackAnnouncementView(String announcementId, String userId) async {
    try {
      await _supabase.from('announcement_views').upsert({
        'announcement_id': announcementId,
        'user_id': userId,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error tracking view: $e');
    }
  }

  // Add comment to announcement
  Future<bool> addAnnouncementComment(String announcementId, String userId, String comment) async {
    try {
      await _supabase.from('announcement_comments').insert({
        'announcement_id': announcementId,
        'user_id': userId,
        'comment': comment,
      });
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}