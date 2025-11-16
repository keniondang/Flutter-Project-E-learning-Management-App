import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_database_service.dart';
import 'package:sqflite/sqflite.dart';

class SyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final OfflineDatabaseService _offlineDb = OfflineDatabaseService();

  // Check connectivity
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Sync all data
  Future<void> syncAll(String userId) async {
    if (!await isOnline()) return;

    try {
      // Process offline queue first
      await _processOfflineQueue();

      // Sync user data
      await _syncUserData(userId);

      // Sync courses and content
      await _syncCoursesAndContent(userId);
    } catch (e) {
      print('Sync error: $e');
    }
  }

  // Process offline queue
  Future<void> _processOfflineQueue() async {
    final queue = await _offlineDb.getOfflineQueue();

    for (var item in queue) {
      try {
        switch (item['type']) {
          case 'assignment_submission':
            await _supabase.from('assignment_submissions').insert(item['data']);
            break;
          case 'quiz_attempt':
            await _supabase.from('quiz_attempts').insert(item['data']);
            break;
          case 'forum_reply':
            await _supabase.from('forum_replies').insert(item['data']);
            break;
        }

        // Remove from queue after successful sync
        await _offlineDb.removeFromOfflineQueue(item['id']);
      } catch (e) {
        print('Error processing offline item: $e');
      }
    }
  }

  // Sync user data
  Future<void> _syncUserData(String userId) async {
    try {
      final userData = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      await _offlineDb.database.then((db) {
        db.insert('cached_user', {
          'id': userId,
          'data': userData.toString(),
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } catch (e) {
      print('Error syncing user data: $e');
    }
  }

  // Sync courses and content
  Future<void> _syncCoursesAndContent(String userId) async {
    try {
      // Get enrolled courses for student
      final coursesResponse = await _supabase
          .from('enrollments')
          .select('groups(course_id, courses(*))')
          .eq('student_id', userId);

      final courses = <Map<String, dynamic>>[];
      for (var enrollment in coursesResponse) {
        if (enrollment['groups'] != null &&
            enrollment['groups']['courses'] != null) {
          courses.add(enrollment['groups']['courses']);
        }
      }

      // Save courses offline
      await _offlineDb.saveCourses(courses);

      // Sync content for each course
      for (var course in courses) {
        await _syncCourseContent(course['id']);
      }
    } catch (e) {
      print('Error syncing courses: $e');
    }
  }

  // Sync course content
  Future<void> _syncCourseContent(String courseId) async {
    try {
      // Sync announcements
      final announcements = await _supabase
          .from('announcements')
          .select()
          .eq('course_id', courseId);
      await _offlineDb.saveAnnouncements(
        courseId,
        List<Map<String, dynamic>>.from(announcements),
      );

      // Sync assignments
      final assignments = await _supabase
          .from('assignments')
          .select()
          .eq('course_id', courseId);

      final db = await _offlineDb.database;
      for (var assignment in assignments) {
        await db.insert('cached_assignments', {
          'id': assignment['id'],
          'course_id': courseId,
          'data': assignment.toString(),
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Sync materials
      final materials = await _supabase
          .from('materials')
          .select()
          .eq('course_id', courseId);

      for (var material in materials) {
        await db.insert('cached_materials', {
          'id': material['id'],
          'course_id': courseId,
          'data': material.toString(),
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      print('Error syncing course content: $e');
    }
  }
}
