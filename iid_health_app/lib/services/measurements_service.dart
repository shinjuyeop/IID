import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class MeasurementsService {
  /// Fetch measurements graph data for a user and type ('weight' or 'body_fat').
  /// Returns a list of (date, value) maps sorted by date ascending.
  static Future<List<MeasurementPoint>> fetchGraph({
    required int userId,
    required String type, // 'weight' | 'body_fat'
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/measurements/graph?user_id=$userId&type=$type');
    final resp = await http.get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body);
      final data = json['data'];
      if (data is List) {
        final pts = data
            .map((e) => MeasurementPoint.fromJson(e))
            .whereType<MeasurementPoint>()
            .toList();
        pts.sort((a, b) => a.date.compareTo(b.date));
        return pts;
      }
    }
    return [];
  }
}

class MeasurementPoint {
  final DateTime date;
  final double value;
  MeasurementPoint({required this.date, required this.value});

  static MeasurementPoint? fromJson(dynamic j) {
    if (j is Map<String, dynamic>) {
      final ds = j['date'];
      final v = j['value'];
      if (ds is String && (v is num)) {
        try {
          return MeasurementPoint(date: DateTime.parse(ds), value: (v).toDouble());
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }
}
