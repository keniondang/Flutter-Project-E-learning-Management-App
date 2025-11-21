import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/semester.dart';

class SemesterProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _boxName = 'semester-box';

  List<Semester> _semesters = [];
  List<Semester> get semesters => _semesters;

  Semester? _currentSemester;
  Semester? get currentSemester => _currentSemester;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Load all semesters
  Future<void> loadSemesters() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final box = await Hive.openBox<Semester>(_boxName);

    if (box.isEmpty) {
      try {
        final response = await _supabase
            .from('semesters')
            .select()
            .order('created_at', ascending: false);

        // _semesters =
        //     (response as List).map((json) => Semester.fromJson(json)).toList();

        await box.putAll(Map.fromEntries(response
            .map((json) => MapEntry(json['id'], Semester.fromJson(json)))));
      } catch (e) {
        _error = e.toString();
        debugPrint('Error loading semesters: $e');
      }
    }

    _semesters = box.values.toList();
    _setCurrentSemester();

    _isLoading = false;
    notifyListeners();
  }

  // Create new semester
  Future<bool> createSemester(
    String code,
    String name,
    bool setAsCurrent,
  ) async {
    try {
      // If setting as current, unset all others
      if (setAsCurrent) {
        await _supabase
            .from('semesters')
            .update({'is_current': false}).eq('is_current', true);
      }

      final response = await _supabase.from('semesters').insert({
        'code': code,
        'name': name,
        'is_current': setAsCurrent,
      }).select();

      final semester = response.map((json) => Semester.fromJson(json)).first;

      final box = await Hive.openBox<Semester>(_boxName);

      await box.put(semester.id, semester);
      _semesters.add(semester);
      _setCurrentSemester();

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }

  // Update semester
  Future<bool> updateSemester(
    String id,
    String code,
    String name,
    bool setAsCurrent,
  ) async {
    try {
      if (setAsCurrent) {
        await _supabase
            .from('semesters')
            .update({'is_current': false}).eq('is_current', true);
      }

      final response = await _supabase
          .from('semesters')
          .update({'code': code, 'name': name, 'is_current': setAsCurrent})
          .eq('id', id)
          .select();

      final semester = response.map((json) => Semester.fromJson(json)).first;

      final box = await Hive.openBox<Semester>(_boxName);

      await box.put(semester.id, semester);
      _semesters[_semesters.indexWhere((x) => x.id == semester.id)] = semester;
      _setCurrentSemester();

      notifyListeners();
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
      final box = await Hive.openBox<Semester>(_boxName);

      await box.delete(id);
      _semesters.removeAt(_semesters.indexWhere((x) => x.id == id));
      _setCurrentSemester();

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

  void _setCurrentSemester() {
    if (_semesters.isEmpty) {
      _currentSemester = null;
    } else {
      _currentSemester = _semesters.firstWhere(
        (s) => s.isCurrent,
        orElse: () => _semesters.first,
      );
    }
  }
}
