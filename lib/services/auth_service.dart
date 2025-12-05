import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Store current user
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Login method with proper password checking
  Future<UserModel?> login(String username, String password) async {
    try {
      // Query users table to check credentials
      final response = await _supabase
          .from('users')
          .select()
          .eq('username', username)
          .eq('password', password) // Check both username AND password
          .maybeSingle(); // Use maybeSingle instead of single to avoid errors

      if (response != null) {
        final hasAvatar = response['has_avatar'] as bool;

        if (hasAvatar) {
          _currentUser = UserModel.fromJson(
              json: response,
              avatarBytes: await _supabase.storage
                  .from('avatars')
                  .download('${response['id']}.jpg'));
        } else {
          _currentUser = UserModel.fromJson(json: response);
        }

        // Save login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _currentUser!.id);
        await prefs.setString('user_role', _currentUser!.role);
        await prefs.setString('username', _currentUser!.username);

        return _currentUser;
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

  // Load current user from storage
  Future<UserModel?> loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId != null) {
      try {
        final response = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (response != null) {
          _currentUser = UserModel.fromJson(json: response);
          return _currentUser;
        }
      } catch (e) {
        print('Error loading user: $e');
      }
    }
    return null;
  }
}
