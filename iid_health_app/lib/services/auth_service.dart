import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class AuthService {
  /// Login with email + password
  /// POST `${baseUrl}/login` with { email, password }
  static Future<bool> login({required String email, required String password}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/login');
    final body = jsonEncode({
      'email': email,
      'password': password,
    });

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final String userEmail = data['email'] ?? email; // fallback to sent email
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', userEmail);
      // Store user name if provided by backend
      final backendName = data['user_name'] ?? data['name'];
      if (backendName is String && backendName.trim().isNotEmpty) {
        await prefs.setString('user_name', backendName.trim());
      }
      // 서버가 user_id를 반환하면 저장해둡니다. (예: { "user_id": 1, ... })
      if (data['user_id'] != null) {
        try {
          final int id = (data['user_id'] as num).toInt();
          await prefs.setInt('user_id', id);
        } catch (_) {
          // 무시: 숫자 파싱에 실패하면 저장하지 않음
        }
      }
      await prefs.setBool('is_logged_in', true);
      return true;
    }

    return false;
  }

  /// Register a user following backend contract:
  /// POST /register with JSON { user_name, password, email }
  /// Returns true on 2xx, else false
  static Future<bool> register({
    required String userName,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/register');
    final body = jsonEncode({
      'user_name': userName,
      'password': password,
      'email': email,
    });

    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      }
      // Bubble up detailed error for UI visibility
      throw Exception('Register failed: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      // Rethrow to be handled by UI
      rethrow;
    }
  }

  /// Withdraw (delete) account using email + password
  /// POST `${baseUrl}/withdraw` with { email, password }
  static Future<bool> withdrawAccount({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/withdraw');
    final body = jsonEncode({
      'email': email,
      'password': password,
    });

    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Delete the current user account by userId.
  /// NOTE: Adjust the endpoint path to match your backend.
  static Future<bool> deleteAccount({required int userId}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/users/$userId');
    try {
      final resp = await http.delete(uri);
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}
