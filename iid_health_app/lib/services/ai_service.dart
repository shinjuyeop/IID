import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class AiService {
  static Future<String?> askQuestion({required int userId, required String question}) async {
  final url = Uri.parse('${AppConfig.baseUrl}/ai/ask');
    final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      'user_id': userId,
      'question': question,
    }));
    if (resp.statusCode != 200) return null;
    try {
      final data = jsonDecode(resp.body);
      if (data is Map && data['answer'] != null) {
        return data['answer'].toString();
      }
      // Some backends may return { evaluation: ... } or { result: ... }
      if (data['evaluation'] != null) return data['evaluation'].toString();
      if (data['result'] != null) return data['result'].toString();
      return resp.body; // fallback raw
    } catch (_) {
      return resp.body; // fallback
    }
  }

  // Optional helper to reuse stored user_id without passing explicitly
  static Future<String?> askWithStoredUser(String question) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return null;
    return askQuestion(userId: userId, question: question);
  }
}
