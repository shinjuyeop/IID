import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ExerciseService {
  static Future<List<WorkoutHistoryDay>> fetchHistory({
    required int userId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/workout/history?user_id=$userId');
    final resp = await http.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return [];
    }

    final json = jsonDecode(resp.body);
    final history = json['history'];
    if (history is! List) return [];

    final result = <WorkoutHistoryDay>[];
    for (final item in history) {
      final parsed = WorkoutHistoryDay.fromJson(item);
      if (parsed != null) {
        result.add(parsed);
      }
    }

    // 정렬: 날짜 내림차순, 같은 날이면 session_id 오름차순
    result.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return a.sessionId.compareTo(b.sessionId);
    });

    return result;
  }

  /// Fetch workout history for a specific date only (YYYY-MM-DD).
  /// Falls back to empty list on error.
  static Future<List<WorkoutHistoryDay>> fetchHistoryByDate({
    required int userId,
    required String date,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/workout/history?user_id=$userId&date=$date');
    final resp = await http.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return [];
    }

    final json = jsonDecode(resp.body);
    final history = json['history'];
    if (history is! List) return [];

    final result = <WorkoutHistoryDay>[];
    for (final item in history) {
      final parsed = WorkoutHistoryDay.fromJson(item);
      if (parsed != null) {
        result.add(parsed);
      }
    }

    // 정렬: 날짜 내림차순, 같은 날이면 session_id 오름차순
    result.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return a.sessionId.compareTo(b.sessionId);
    });

    return result;
  }

  /// Submit a daily workout review and receive AI feedback.
  /// Endpoint: POST `${baseUrl}/workout/daily-review`
  /// Body: { "user_id": 1, "date": "YYYY-MM-DD", "user_review": "..." }
  /// Response: { "ai_feedback": "...", "success": true }
  static Future<String?> submitDailyReview({
    required int userId,
    required String date,
    required String userReview,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/workout/daily-review');
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'date': date,
          'user_review': userReview,
        }),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final j = jsonDecode(resp.body);
      if (j is Map<String, dynamic>) {
        final success = j['success'] == true;
        if (!success) return null;
        final fb = j['ai_feedback'];
        if (fb is String) return fb;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Manually add an exercise session.
  /// POST `${baseUrl}/workout/manual/add`
  /// Body: { "user_id": 1, "date": "YYYY-MM-DD", "exercise_name": "squat", "sets": 3, "reps": 15, "duration": 30 }
  /// Returns true on success (2xx & success==true), false otherwise.
  static Future<bool> submitManualAdd({
    required int userId,
    required String date,
    required String exerciseName,
    required int sets,
    required int reps,
    required int minutes,
    required int seconds,
    double? distance,
    double? weight,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/workout/manual/add');
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'date': date,
          'exercise_name': exerciseName,
          'sets': sets,
          'reps': reps,
          'min': minutes,
          'sec': seconds,
          if (distance != null) 'distance': distance,
          if (weight != null) 'weight': weight,
        }),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
      final j = jsonDecode(resp.body);
      if (j is Map<String, dynamic>) {
        return j['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

class WorkoutHistoryDay {
  final DateTime date;
  final int sessionId;
  final List<ExerciseSummary> summaries;
  final int totalDurationMinutes;

  WorkoutHistoryDay({
    required this.date,
    required this.sessionId,
    required this.summaries,
    required this.totalDurationMinutes,
  });

  static WorkoutHistoryDay? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    try {
      final dateStr = j['date'] as String?;
      final sessionId = j['session_id'] as int?;
      final summaryList = j['summary'];
      final totalDuration = j['total_duration_minutes'] as int? ?? 0;
      if (dateStr == null || sessionId == null || summaryList is! List) return null;

      final date = DateTime.parse(dateStr);
      final summaries = summaryList
          .map((e) => ExerciseSummary.fromJson(e))
          .whereType<ExerciseSummary>()
          .toList();

      return WorkoutHistoryDay(
        date: date,
        sessionId: sessionId,
        summaries: summaries,
        totalDurationMinutes: totalDuration,
      );
    } catch (_) {
      return null;
    }
  }
}

class ExerciseSummary {
  final String exerciseName;
  final List<SetDetail> sets;
  final int totalReps;
  final int totalSets;
  final double? distance; // 러닝 등 거리 기반 운동일 경우 (이전 km)
  final double? weight; // 덤벨컬 등 중량 기반 운동일 경우 (이전 kg)

  ExerciseSummary({
    required this.exerciseName,
    required this.sets,
    required this.totalReps,
    required this.totalSets,
    this.distance,
    this.weight,
  });

  static ExerciseSummary? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    try {
      final name = j['exercise_name'] as String?;
      final setsDetails = j['sets_details'];
      final totalReps = j['total_reps'] as int? ?? 0;
      final totalSets = j['total_sets'] as int? ?? 0;
      // Support both new keys (distance, weight) and legacy keys (km, kg)
      final distanceRaw = j.containsKey('distance') ? j['distance'] : j['km'];
      final weightRaw = j.containsKey('weight') ? j['weight'] : j['kg'];
      if (name == null || setsDetails is! List) return null;

      final sets = setsDetails
          .map((e) => SetDetail.fromJson(e))
          .whereType<SetDetail>()
          .toList();
      // Fallback: if top-level distance/weight missing, derive from sets_details.
      double? derivedDistance;
      double? derivedWeight;
      if (distanceRaw is num) {
        derivedDistance = distanceRaw.toDouble();
      } else if (distanceRaw is String) {
        final d = double.tryParse(distanceRaw);
        if (d != null) derivedDistance = d;
      }
      if (weightRaw is num) {
        derivedWeight = weightRaw.toDouble();
      } else if (weightRaw is String) {
        final w = double.tryParse(weightRaw);
        if (w != null) derivedWeight = w;
      }

      // Scan sets for distance/weight if still null. Include legacy per-set keys 'km' and 'kg'.
      if (derivedDistance == null) {
        double sum = 0;
        bool any = false;
        for (final s in setsDetails) {
          if (s is Map) {
            final sd = s.containsKey('distance') ? s['distance'] : s['km'];
            if (sd is num) {
              sum += sd.toDouble();
              any = true;
            } else if (sd is String) {
              final d = double.tryParse(sd);
              if (d != null) {
                sum += d;
                any = true;
              }
            }
          }
        }
        if (any) derivedDistance = sum;
      }
      if (derivedWeight == null) {
        for (final s in setsDetails) {
          if (s is Map) {
            final sw = s.containsKey('weight') ? s['weight'] : s['kg'];
            if (sw is num) {
              derivedWeight = sw.toDouble();
              break;
            } else if (sw is String) {
              final w = double.tryParse(sw);
              if (w != null) {
                derivedWeight = w;
                break;
              }
            }
          }
        }
      }

      return ExerciseSummary(
        exerciseName: name,
        sets: sets,
        totalReps: totalReps,
        totalSets: totalSets,
        distance: derivedDistance,
        weight: derivedWeight,
      );
    } catch (_) {
      return null;
    }
  }
}

class SetDetail {
  final DateTime createdAt;
  final int durationSeconds;
  final bool isCompleted;
  final int repCount;
  final int setNumber;
  final double? distance; // 러닝 기록일 경우 해당 회차 거리 (km)

  SetDetail({
    required this.createdAt,
    required this.durationSeconds,
    required this.isCompleted,
    required this.repCount,
    required this.setNumber,
    this.distance,
  });

  static SetDetail? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    try {
      final createdAtStr = j['created_at'] as String?;
      final durationSeconds = j['duration_seconds'] as int? ?? 0;
      final isCompleted = j['is_completed'] as bool? ?? false;
      final repCount = j['rep_count'] as int? ?? 0;
      final setNumber = j['set_number'] as int? ?? 0;
      final distRaw = j.containsKey('distance') ? j['distance'] : j['km'];
      if (createdAtStr == null) return null;

      final createdAt = DateTime.parse(createdAtStr);
      double? dist;
      if (distRaw is num) {
        dist = distRaw.toDouble();
      } else if (distRaw is String) {
        final d = double.tryParse(distRaw);
        if (d != null) dist = d;
      }
      return SetDetail(
        createdAt: createdAt,
        durationSeconds: durationSeconds,
        isCompleted: isCompleted,
        repCount: repCount,
        setNumber: setNumber,
        distance: dist,
      );
    } catch (_) {
      return null;
    }
  }
}
