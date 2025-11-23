import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';

class GroupProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'group-box';

  List<Group> _groups = [];
  List<Group> get groups => _groups;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Load groups for a course
  Future<void> loadGroups(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Group>(_boxName);

    if (!box.values.any((x) => x.courseId == courseId)) {
      try {
        final response = await _supabase
            .from('groups')
            .select('*, courses(name, semester_id)')
            .eq('course_id', courseId);

        await box.putAll(Map.fromEntries(
            await Future.wait((response as Iterable).map((json) async {
          String? courseName;
          String? semesterId;

          if (json['courses'] != null) {
            courseName = json['courses']['name'];
            semesterId = json['courses']['semester_id'];
          }

          final group = Group.fromJson(
            json: json,
            courseName: courseName,
            studentCount: await _fetchStudentCount(json['id']),
            semesterId: semesterId,
          );

          return MapEntry(group.id, group);
        }))));
      } catch (e) {
        _error = e.toString();
        print('Error loading groups: $e');
      }
    }

    _groups = box.values.where((x) => x.courseId == courseId).toList();

    _isLoading = false;
    notifyListeners();
  }

  // Update count locally
  Future<void> updateGroupStudentCount(String groupId, int change) async {
    try {
      final box = await Hive.openBox<Group>(_boxName);
      final index = _groups.indexWhere((g) => g.id == groupId);

      if (index != -1) {
        final oldGroup = _groups[index];
        final newCount = (oldGroup.studentCount ?? 0) + change;

        final newGroup = Group(
          id: oldGroup.id,
          courseId: oldGroup.courseId,
          name: oldGroup.name,
          createdAt: oldGroup.createdAt,
          courseName: oldGroup.courseName,
          studentCount: newCount < 0 ? 0 : newCount,
          semesterId: oldGroup.semesterId,
        );

        await box.put(groupId, newGroup);
        _groups[index] = newGroup;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating group student count: $e');
    }
  }

  Future<int> countInSemester(String semesterId) async {
    final box = await Hive.openBox<Group>(_boxName);
    
    // Logic to count...
    // (Existing implementation preserved)
    return box.values.where((x) => x.semesterId == semesterId).length;
  }

  Future<int> _fetchStudentCount(String groupId) async {
    try {
      final response = await _supabase
          .from('enrollments')
          .select('student_id')
          .eq('group_id', groupId)
          .count();
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  // Create new group with validation
  Future<bool> createGroup({
    required String courseId,
    required String name,
  }) async {
    try {
      final box = await Hive.openBox<Group>(_boxName);

      final nameExists = box.values.any((g) =>
          g.courseId == courseId &&
          g.name.trim().toLowerCase() == name.trim().toLowerCase());

      if (nameExists) {
        _error = 'A group with this name already exists.';
        notifyListeners();
        return false;
      }

      final response = await _supabase.from('groups').insert({
        'course_id': courseId,
        'name': name.trim(), // Trim whitespace
      }).select('*, courses(name)');

      final newGroup = (response as Iterable).map((json) {
        String? courseName;
        if (json['courses'] != null) {
          courseName = json['courses']['name'];
        }
        return Group.fromJson(json: json, courseName: courseName);
      }).first;

      await box.put(newGroup.id, newGroup);
      _groups.add(newGroup);

      notifyListeners();
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
      final groupsData = groupNames
          .map((name) => {'course_id': courseId, 'name': name})
          .toList();

      await _supabase.from('groups').insert(groupsData);
      await loadGroups(courseId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update group with validation
  Future<bool> updateGroup({required String id, required String name}) async {
    try {
      final box = await Hive.openBox<Group>(_boxName);
      final currentGroup = box.get(id);

      if (currentGroup != null) {
        // ✅ VALIDATION: Check duplicates excluding self
        final nameExists = box.values.any((g) =>
            g.courseId == currentGroup.courseId &&
            g.id != id && // Don't check against self
            g.name.trim().toLowerCase() == name.trim().toLowerCase());

        if (nameExists) {
          _error = 'A group with this name already exists.';
          notifyListeners();
          return false;
        }
      }

      final response = await _supabase
          .from('groups')
          .update({'name': name.trim()})
          .eq('id', id)
          .select('*, courses(name)');

      final group = (response as Iterable).map((json) {
        String? courseName;
        if (json['courses'] != null) {
          courseName = json['courses']['name'];
        }
        final old = box.get(json['id']);
        return Group.fromJson(
            json: json,
            courseName: courseName,
            studentCount: old!.studentCount);
      }).first;

      await box.put(group.id, group);
      _groups[_groups.indexWhere((x) => x.id == group.id)] = group;

      notifyListeners();
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

      final box = await Hive.openBox<Group>(_boxName);

      await box.delete(id);
      _groups.removeWhere((group) => group.id == id);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}