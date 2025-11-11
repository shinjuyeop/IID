import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ProfileService {
  /// Upload user profile to backend. Returns true on 2xx response.
  static Future<bool> uploadProfile({
    required int userId,
    required double heightCm,
    required double weightKg,
    required int age,
    required double bodyFat,
    required String gender,
    String? purpose,
    String? job,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/profile/update');

    final body = jsonEncode({
      'user_id': userId,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'age': age,
      'body_fat': bodyFat,
      'gender': gender,
      'purpose': purpose ?? '',
      'job': job ?? '',
    });

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  /// Convenience methods that reuse uploadProfile to update only weight or body fat.
  /// We pass through the rest of the profile values loaded by the caller.
  static Future<bool> updateWeight({
    required int userId,
    required double heightCm,
    required double newWeightKg,
    required int age,
    required double bodyFat,
    required String gender,
  }) async {
    // Partial update: send only user_id and weight_kg
    final uri = Uri.parse('${AppConfig.baseUrl}/profile/update');
    final body = jsonEncode({
      'user_id': userId,
      'weight_kg': newWeightKg,
    });
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  static Future<bool> updateBodyFat({
    required int userId,
    required double heightCm,
    required double weightKg,
    required int age,
    required double newBodyFat,
    required String gender,
  }) async {
    // Partial update: send only user_id and body_fat
    final uri = Uri.parse('${AppConfig.baseUrl}/profile/update');
    final body = jsonEncode({
      'user_id': userId,
      'body_fat': newBodyFat,
    });
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  static Future<bool> updatePurpose({
    required int userId,
    required String purpose,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/profile/update');
    final body = jsonEncode({
      'user_id': userId,
      'purpose': purpose,
    });
    final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  static Future<bool> updateJob({
    required int userId,
    required String job,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/profile/update');
    final body = jsonEncode({
      'user_id': userId,
      'job': job,
    });
    final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  static Future<bool> updateHeight({
    required int userId,
    required double heightCm,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/profile/update');
    final body = jsonEncode({
      'user_id': userId,
      'height_cm': heightCm,
    });
    final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }
}
