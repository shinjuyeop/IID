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
    });

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    return resp.statusCode >= 200 && resp.statusCode < 300;
  }
}
