import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';

class GroupProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Group> _groups = [];
  bool _isLoading = false;
  String? _error;
  
  // This is used to remember which course we are looking at
  String? _currentCourseId;

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load groups for a course
  Future<void> loadGroups(String courseId) async {
    _isLoading = true;
    _error = null;
    _currentCourseId = courseId; // Remember this courseId
    notifyListeners();

    try {
      final response = await _supabase
          .from('groups')
          .select('*, courses(name)')
          .eq('course_id', courseId)
          .order('name');

      _groups = (response as List).map((json) {
        String? courseName;
        if (json['courses'] != null) {
          courseName = json['courses']['name'];
        }
        
        return Group.fromJson({
          ...json,
          'course_name': courseName,
        });
      }).toList();

      // Load student count for each group
      for (var group in _groups) {
        await _loadGroupStats(group);
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading groups: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load stats for a group
  Future<void> _loadGroupStats(Group group) async {
    try {
      final response = await _supabase
          .from('enrollments')
          .select('student_id')
          .eq('group_id', group.id);
      
      final studentCount = (response as List).length;

      // Update group with stats
      final index = _groups.indexWhere((g) => g.id == group.id);
      if (index != -1) {
        _groups[index] = Group(
          id: group.id,
          courseId: group.courseId,
          name: group.name,
          createdAt: group.createdAt,
          courseName: group.courseName,
          studentCount: studentCount,
        );
      }
    } catch (e) {
      print('Error loading group stats: $e');
    }
  }

  // Create new group
  Future<bool> createGroup({
    required String courseId,
    required String name,
  }) async {
    try {
      await _supabase.from('groups').insert({
        'course_id': courseId,
        'name': name,
      });

      await loadGroups(courseId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Create multiple groups
  Future<bool> createMultipleGroups({
    required String courseId,
    required List<String> groupNames,
  }) async {
    try {
      final groupsData = groupNames.map((name) => {
        'course_id': courseId,
        'name': name,
      }).toList();

      await _supabase.from('groups').insert(groupsData);
      await loadGroups(courseId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update group
  Future<bool> updateGroup({
    required String id,
    required String name,
  }) async {
    try {
      await _supabase.from('groups').update({
        'name': name,
      }).eq('id', id);

      // Update local list
      final index = _groups.indexWhere((g) => g.id == id);
      if (index != -1) {
        final group = _groups[index];
        _groups[index] = Group(
          id: group.id,
          courseId: group.courseId,
          name: name,
          createdAt: group.createdAt,
          courseName: group.courseName,
          studentCount: group.studentCount,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete group
  Future<bool> deleteGroup(String id) async {
    try {
      await _supabase.from('groups').delete().eq('id', id);
      _groups.removeWhere((group) => group.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshCurrentCourseGroups() async {
    if (_currentCourseId != null) {
      await loadGroups(_currentCourseId!);
    }
  }
}