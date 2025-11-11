import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class MealsService {
  /// Evaluate diet by sending daily meals to backend.
  /// Endpoint: POST `${baseUrl}/diet/evaluate`
  /// Request JSON example:
  /// {
  ///   "user_id": 1,
  ///   "date": "2025-11-11",
  ///   "breakfast": "바나나 1개, 그릭 요거트",
  ///   "lunch": null,
  ///   "dinner": null
  /// }
  /// Response JSON:
  /// { "ai_recommendation_text": "..." }
  static Future<String?> saveDailyMeals({
    required int userId,
    required String date,
    String? breakfast,
    String? lunch,
    String? dinner,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/diet/evaluate');
    final payload = {
      'user_id': userId,
      'date': date,
      'breakfast': (breakfast == null || breakfast.trim().isEmpty) ? null : breakfast,
      'lunch': (lunch == null || lunch.trim().isEmpty) ? null : lunch,
      'dinner': (dinner == null || dinner.trim().isEmpty) ? null : dinner,
    };
    final body = jsonEncode(payload);

    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        // Expect 'evaluation' from backend
        final rec = data['evaluation'];
        if (rec is String && rec.isNotEmpty) return rec;
        return null;
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }
}
