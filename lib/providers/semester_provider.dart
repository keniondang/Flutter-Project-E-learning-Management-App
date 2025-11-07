import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/semester.dart';

class SemesterProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Semester> _semesters = [];
  Semester? _currentSemester;
  bool _isLoading = false;
  String? _error;

  List<Semester> get semesters => _semesters;
  Semester? get currentSemester => _currentSemester;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all semesters
  Future<void> loadSemesters() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('semesters')
          .select()
          .order('created_at', ascending: false);

      _semesters = (response as List)
          .map((json) => Semester.fromJson(json))
          .toList();

      // ✅ Safely set current semester (may remain null if none exist)
      if (_semesters.isEmpty) {
        _currentSemester = null;
      } else {
        _currentSemester = _semesters.firstWhere(
          (s) => s.isCurrent,
          orElse: () => _semesters.first,
        );
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading semesters: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new semester
  Future<bool> createSemester(String code, String name, bool setAsCurrent) async {
    try {
      // If setting as current, unset all others
      if (setAsCurrent) {
        await _supabase
            .from('semesters')
            .update({'is_current': false})
            .eq('is_current', true);
      }

      await _supabase.from('semesters').insert({
        'code': code,
        'name': name,
        'is_current': setAsCurrent,
      });

      await loadSemesters();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update semester
  Future<bool> updateSemester(String id, String code, String name, bool setAsCurrent) async {
    try {
      if (setAsCurrent) {
        await _supabase
            .from('semesters')
            .update({'is_current': false})
            .eq('is_current', true);
      }

      await _supabase
          .from('semesters')
          .update({
            'code': code,
            'name': name,
            'is_current': setAsCurrent,
          })
          .eq('id', id);

      await loadSemesters();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete semester
  Future<bool> deleteSemester(String id) async {
    try {
      await _supabase.from('semesters').delete().eq('id', id);
      await loadSemesters();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Set current semester
  Future<void> setCurrentSemester(Semester semester) async {
    _currentSemester = semester;
    notifyListeners();
  }
}
