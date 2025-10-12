import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

class Status {
  final double? temperature;
  final double? humidity;
  final double? distance;
  final List<int> ledStatus;
  final bool autoMode;

  Status({
    required this.temperature,
    required this.humidity,
    required this.distance,
    required this.ledStatus,
    required this.autoMode,
  });

  factory Status.fromJson(Map<String, dynamic> j) {
    return Status(
      temperature: (j['temperature'] as num?)?.toDouble(),
      humidity: (j['humidity'] as num?)?.toDouble(),
      distance: (j['distance'] as num?)?.toDouble(),
      ledStatus:
          (j['led_status'] as List?)?.map((e) => (e as num).toInt()).toList() ??
              <int>[0, 0, 0],
      autoMode: j['auto_mode'] as bool? ?? true,
    );
  }
}

class ApiClient {
  // Default to port 8080 to match the current Flask server setting in W4_shin.py
  final String baseUrl;
  final http.Client _http;

  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://YOUR_PC_LAN_IP:8080',
            ),
        _http = httpClient ?? http.Client();

  Future<Status> fetchData() async {
    final uri = Uri.parse('$baseUrl/status');
    final res = await _http.get(uri);
    if (res.statusCode == 200) {
      final j = json.decode(res.body) as Map<String, dynamic>;
      return Status.fromJson(j);
    }
    throw ApiException('GET /status failed: ${res.statusCode}');
  }

  Future<void> setMode(bool auto) async {
    final res = await _http.get(Uri.parse('$baseUrl/set_mode/${auto ? 1 : 0}'));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('GET /set_mode failed: ${res.statusCode}');
    }
  }

  Future<void> controlDevice(int id, int state) async {
    final res = await _http.get(Uri.parse('$baseUrl/control/$id/$state'));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('GET /control failed: ${res.statusCode}');
    }
  }

  Future<List<HistoryPoint>> fetchHistory(String metric) async {
    final uri = Uri.parse('$baseUrl/history_data/$metric');
    final res = await _http.get(uri);
    if (res.statusCode == 200) {
      final arr = json.decode(res.body) as List;
      return arr
          .map((e) => HistoryPoint(
                dt: e['dt'] as String? ?? '',
                value: (e['value'] as num?)?.toDouble(),
              ))
          .toList();
    }
    throw ApiException('GET /history_data/$metric failed: ${res.statusCode}');
  }
}

class HistoryPoint {
  final String dt;
  final double? value;
  const HistoryPoint({required this.dt, required this.value});
}
