import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Store current user
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Login method
  Future<UserModel?> login(String username, String password) async {
    try {
      // Query users table to check credentials
      final response = await _supabase
          .from('users')
          .select()
          .eq('username', username)
          .single();

      if (response != null) {
        // For this simple implementation, we check if password equals username
        // In production, use proper authentication
        if (password == username) {
          _currentUser = UserModel.fromJson(response);
          
          // Save login state
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', _currentUser!.id);
          await prefs.setString('user_role', _currentUser!.role);
          
          return _currentUser;
        }
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Logout method
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('user_id');
  }

  // Get saved user role
  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }
}