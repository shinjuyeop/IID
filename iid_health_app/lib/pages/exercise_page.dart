import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/exercise_service.dart';

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  DateTime _selectedDate = DateTime.now();
  List<WorkoutHistoryDay> _allHistory = [];
  bool _loading = false;
  String? _error;
  int _localSessionAutoId = -1; // for locally added sessions
  final TextEditingController _reviewCtrl = TextEditingController();
  String? _aiFeedback;
  bool _savingReview = false;

  @override
  void initState() {
    super.initState();
    _loadHistoryForDate(_selectedDate);
    _loadReviewFromPrefs(_selectedDate);
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryForDate(DateTime date) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 1; // fallback 1
      final dateStr = _dateKey(date);
      final history = await ExerciseService.fetchHistoryByDate(userId: userId, date: dateStr);
      if (!mounted) return;
      setState(() {
        _allHistory = history;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '운동 기록을 불러오지 못했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<ExerciseSummary> _summariesForSelectedDate() {
    final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    // 같은 날짜의 여러 세션을 모두 합치기
    final sameDay = _allHistory.where((h) {
      final d = DateTime(h.date.year, h.date.month, h.date.day);
      return d == key;
    }).toList();

    if (sameDay.isEmpty) return [];

    // 운동 이름별로 합산
    final Map<String, ExerciseSummary> merged = {};
    for (final day in sameDay) {
      for (final s in day.summaries) {
        final existing = merged[s.exerciseName];
        if (existing == null) {
          // 최초 생성: distance/weight 포함 복사
          merged[s.exerciseName] = ExerciseSummary(
            exerciseName: s.exerciseName,
            sets: List<SetDetail>.from(s.sets),
            totalReps: s.totalReps,
            totalSets: s.totalSets,
            distance: s.distance,
            weight: s.weight,
          );
        } else {
          // 병합: 세트/반복 합산, 거리 누적, 중량은 유지(비어있다면 새 값 사용)
          merged[s.exerciseName] = ExerciseSummary(
            exerciseName: existing.exerciseName,
            sets: [...existing.sets, ...s.sets],
            totalReps: existing.totalReps + s.totalReps,
            totalSets: existing.totalSets + s.totalSets,
            distance: (existing.distance != null || s.distance != null)
                ? (existing.distance ?? 0) + (s.distance ?? 0)
                : null,
            weight: existing.weight ?? s.weight,
          );
        }
      }
    }

    // 세트는 생성 시간 순으로 정렬
    for (final entry in merged.values) {
      entry.sets.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final list = merged.values.toList();
    list.sort((a, b) => a.exerciseName.compareTo(b.exerciseName));
    return list;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReviewFromPrefs(picked);
      _loadHistoryForDate(picked);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}년 ${d.month.toString().padLeft(2, '0')}월 ${d.day.toString().padLeft(2, '0')}일';
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final summaries = _summariesForSelectedDate();
    return LayoutBuilder(builder: (context, constraints) {
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                )
              else if (summaries.isEmpty)
                const Center(child: Text('해당 날짜의 운동 기록이 없습니다.'))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: summaries.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final s = summaries[index];
                    final totalSeconds = s.sets.fold<int>(0, (a, b) => a + b.durationSeconds);
                    final timeText = _formatMinSec(totalSeconds);
                    String subtitle;
                    final isRunning = s.exerciseName == '런닝';
                    final isCurl = s.exerciseName == '덤벨컬';
                    if (isRunning) {
                      // 런닝: 거리 있으면 거리+시간, 없으면 시간만
                      if (s.distance != null) {
                        subtitle = '총 거리: ${_formatNumber(s.distance!)}km, 총 시간: $timeText';
                      } else {
                        subtitle = '총 시간: $timeText';
                      }
                    } else if (isCurl) {
                      // 덤벨컬: 중량 + 세트/반복 + 시간 (중량 없으면 기존 포맷)
                      if (s.weight != null) {
                        subtitle = '중량: ${_formatNumber(s.weight!)}kg, 세트: ${s.totalSets}, 반복: ${s.totalReps}, 시간: $timeText';
                      } else {
                        subtitle = '세트: ${s.totalSets}, 반복: ${s.totalReps}, 시간: $timeText';
                      }
                    } else {
                      subtitle = '세트: ${s.totalSets}, 반복: ${s.totalReps}, 시간: $timeText';
                    }
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(s.exerciseName),
                      subtitle: Text(subtitle),
                      onTap: () => _showSetDetailDialog(s),
                    );
                  },
                ),
              const SizedBox(height: 12),
              Center(
                child: FilledButton.icon(
                  onPressed: _onAddExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('운동 추가하기'),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('리뷰', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '오늘 운동 느낌, 힘들었던 점, 다음에 개선할 점 등을 적어보세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _savingReview ? null : _saveReview,
                  icon: const Icon(Icons.save),
                  label: Text(_savingReview ? '저장 중...' : '저장'),
                ),
              ),
              if (_aiFeedback != null && _aiFeedback!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.blue.withOpacity(0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_aiFeedback!)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  void _showSetDetailDialog(ExerciseSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isRunning = summary.exerciseName == '런닝';
        final isCurl = summary.exerciseName == '덤벨컬';
        final totalSeconds = summary.sets.fold<int>(0, (a, b) => a + b.durationSeconds);
        return AlertDialog(
          title: Text('${summary.exerciseName} 상세'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.distance != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text('거리: ${_formatNumber(summary.distance!)}km'),
                  ),
                if (summary.weight != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text('중량: ${_formatNumber(summary.weight!)}kg'),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text('총 시간: ${_formatMinSec(totalSeconds)}'),
                ),
                // 러닝: 항상 각 회 표시 (1회라도), 회당 거리 & 시간 표시
                if (isRunning)
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: summary.sets.length,
                      itemBuilder: (context, index) {
                        final set = summary.sets[index];
                        final displayIndex = index + 1;
                        final perDist = set.distance != null ? '${_formatNumber(set.distance!)}km' : '';
                        final perTime = _formatMinSec(set.durationSeconds);
                        return ListTile(
                          title: Text('${displayIndex}회${perDist.isNotEmpty ? ' - $perDist' : ''}'),
                          subtitle: Text('시간: $perTime / ${set.isCompleted ? '완료' : '미완료'}'),
                        );
                      },
                    ),
                  )
                else
                  // 기타 운동: 세트와 반복 표시
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: summary.sets.length,
                      itemBuilder: (context, index) {
                        final set = summary.sets[index];
                        final displayIndex = index + 1;
                        String title;
                        if (isCurl) {
                          title = '$displayIndex세트 - ${set.repCount}회';
                        } else {
                          title = '$displayIndex세트 - ${set.repCount}회';
                        }
                        final perTime = _formatMinSec(set.durationSeconds);
                        return ListTile(
                          title: Text(title),
                          subtitle: Text('시간: $perTime / ${set.isCompleted ? '완료' : '미완료'}'),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onAddExercise() async {
    final result = await _showAddExerciseDialog();
    if (result == null) return;
    if (result.exerciseName.trim().isEmpty) return; // 세트가 없어도 추가 가능

    final now = DateTime.now();
    final dateBase = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour, now.minute, now.second);
    final totalSeconds = (result.minutes * 60) + result.seconds;
    final bool isRunning = result.distance != null;
    // bool isCurl = result.kg != null; // (중량은 summary.weightKg로 표시; 현재 분기 필요 없음)
    List<SetDetail> sets;
    int totalReps;
    int totalSets;
    if (isRunning) {
      sets = [
        SetDetail(
          createdAt: dateBase,
          durationSeconds: totalSeconds,
          isCompleted: true,
          repCount: 0,
          setNumber: 1,
          distance: result.distance,
        )
      ];
      totalReps = 0;
      totalSets = 1;
    } else {
      final repsList = result.repsPerSet;
      final nSets = repsList.length;
      final perSetSec = nSets > 0 ? (totalSeconds ~/ nSets) : 0;
      sets = <SetDetail>[];
      for (var i = 0; i < nSets; i++) {
        sets.add(SetDetail(
          createdAt: dateBase.add(Duration(seconds: i)),
          durationSeconds: perSetSec,
          isCompleted: true,
          repCount: repsList[i],
          setNumber: i + 1,
        ));
      }
      totalReps = repsList.fold(0, (a, b) => a + b);
      totalSets = nSets;
    }

    final summary = ExerciseSummary(
      exerciseName: result.exerciseName.trim(),
      sets: sets,
      totalReps: totalReps,
      totalSets: totalSets,
      distance: result.distance,
      weight: result.weight,
    );

    final newDay = WorkoutHistoryDay(
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      sessionId: _localSessionAutoId--,
      summaries: [summary],
      totalDurationMinutes: result.minutes,
    );

    setState(() {
      _allHistory = [..._allHistory, newDay];
    });

    // Send to backend manual add endpoint
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;
    final dateStr = _dateKey(_selectedDate);
    // Show lightweight progress indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
      ),
    );
    bool ok = false;
    try {
      ok = await ExerciseService.submitManualAdd(
        userId: userId,
        date: dateStr,
        exerciseName: result.exerciseName.trim(),
        sets: summary.totalSets,
        reps: summary.totalReps,
        minutes: result.minutes,
        seconds: result.seconds,
        distance: result.distance,
        weight: result.weight,
      );
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '운동이 저장되었습니다.' : '서버 저장에 실패했습니다 (로컬 반영됨).')),
    );
    if (ok) {
      // 성공 시 서버 최신 데이터로 교체
      _loadHistoryForDate(_selectedDate);
    }
  }

  Future<_AddExerciseResult?> _showAddExerciseDialog() async {
    const predefined = [
      '런닝', '덤벨컬', '스쿼트', '버피', '플랭크', '푸쉬업', '팔벌려뛰기', '런지', '힙쓰러스트', '크런치'
    ];
    String? selectedName;
    bool showCustom = false;
    final customNameCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '0');
    final secCtrl = TextEditingController(text: '0');
    final distanceCtrl = TextEditingController(text: '0');
    final weightCtrl = TextEditingController(text: '0'); // 덤벨컬 중량
    final repsCtrls = <TextEditingController>[];

    return showDialog<_AddExerciseResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: const Text('운동 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 운동 선택 Callout
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('운동 선택', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedName,
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                          items: predefined
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setStateDialog(() => selectedName = v),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: OutlinedButton(
                            onPressed: () {
                              setStateDialog(() {
                                showCustom = !showCustom;
                                if (showCustom) selectedName = null;
                              });
                            },
                            child: Text(showCustom ? '기본 목록' : '새 운동'),
                          ),
                        ),
                        if (showCustom) ...[
                          const SizedBox(height: 12),
                          const Text('새 운동명 입력'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: customNameCtrl,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: '예: 철봉'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 세트 / 횟수 또는 거리 Callout
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedName == '런닝' && !showCustom
                            ? '거리 (km)'
                            : (selectedName == '덤벨컬' && !showCustom ? '중량(kg) / 세트 / 횟수 ' : '세트 / 횟수'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (selectedName == '런닝' && !showCustom) ...[
                          TextField(
                            controller: distanceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: '예: 2.5'),
                          ),
                        ] else if (selectedName == '덤벨컬' && !showCustom) ...[
                          // 덤벨컬: 중량 입력 + 세트/횟수
                          TextField(
                            controller: weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: '중량 (kg)', hintText: '예: 7.5'),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(repsCtrls.length, (i) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(width: 64, child: Text('세트 ${i + 1}')),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: repsCtrls[i],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: '횟수'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      setStateDialog(() {
                                        repsCtrls.removeAt(i);
                                      });
                                    },
                                    icon: const Icon(Icons.remove_circle_outline),
                                  )
                                ],
                              ),
                            );
                          }),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setStateDialog(() {
                                  final last = repsCtrls.isNotEmpty ? repsCtrls.last.text : '10';
                                  repsCtrls.add(TextEditingController(text: last));
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('세트 추가'),
                            ),
                          ),
                        ] else ...[
                          ...List.generate(repsCtrls.length, (i) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(width: 64, child: Text('세트 ${i + 1}')),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: repsCtrls[i],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: '횟수'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      setStateDialog(() {
                                        repsCtrls.removeAt(i);
                                      });
                                    },
                                    icon: const Icon(Icons.remove_circle_outline),
                                  )
                                ],
                              ),
                            );
                          }),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setStateDialog(() {
                                  final last = repsCtrls.isNotEmpty ? repsCtrls.last.text : '10';
                                  repsCtrls.add(TextEditingController(text: last));
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('세트 추가'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 총 운동 시간 Callout
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('총 운동 시간', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: '분'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: secCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: '초'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  final chosen = showCustom ? customNameCtrl.text.trim() : (selectedName ?? '').trim();
                  final min = int.tryParse(minCtrl.text.trim()) ?? 0;
                  final sec = int.tryParse(secCtrl.text.trim()) ?? 0;
                  final isRunning = (selectedName == '런닝' && !showCustom);
                  final isCurl = (selectedName == '덤벨컬' && !showCustom);
                  final distanceVal = double.tryParse(distanceCtrl.text.trim());
                  final weightVal = double.tryParse(weightCtrl.text.trim());
                  final reps = isRunning
                      ? <int>[]
                      : repsCtrls
                          .map((c) => int.tryParse(c.text.trim()))
                          .whereType<int>()
                          .where((v) => v > 0)
                          .toList();
                  if (chosen.isEmpty || min < 0 || sec < 0 || sec > 59 ||
                      (isRunning && (distanceVal == null || distanceVal < 0)) ||
                      (isCurl && (weightVal == null || weightVal < 0))) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('입력을 확인해주세요.')));
                    return;
                  }
                  Navigator.of(ctx).pop(_AddExerciseResult(
                    exerciseName: chosen,
                    repsPerSet: reps,
                    minutes: min,
                    seconds: sec,
                    distance: isRunning ? distanceVal : null,
                    weight: isCurl ? weightVal : null,
                  ));
                },
                child: const Text('추가'),
              ),
            ],
          );
        });
      },
    );
  }

  // Wheel picker removed; picker now uses DropdownButtonFormField directly in dialog.

  Future<void> _saveReview() async {
    final userText = _reviewCtrl.text.trim();
    if (userText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('리뷰를 입력해 주세요.')));
      return;
    }

    setState(() => _savingReview = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;
    final dateStr = _dateKey(_selectedDate);

    // Optional: show a small loading dialog similar to meals
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
      ),
    );

    String? feedback;
    try {
      feedback = await ExerciseService.submitDailyReview(
        userId: userId,
        date: dateStr,
        userReview: userText,
      );
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        setState(() {
          _savingReview = false;
          if (feedback != null) _aiFeedback = feedback;
        });
      }
    }

    // Persist locally for this date
    await prefs.setString('workout_review_$dateStr', userText);
    if (feedback != null) {
      await prefs.setString('workout_feedback_$dateStr', feedback);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(feedback != null ? '저장 및 피드백을 받았습니다.' : '저장되었습니다.')),
    );
  }

  Future<void> _loadReviewFromPrefs(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(date);
    final text = prefs.getString('workout_review_$key');
    final fb = prefs.getString('workout_feedback_$key');
    if (!mounted) return;
    if (_dateKey(_selectedDate) == key) {
      setState(() {
        _reviewCtrl.text = text ?? '';
        _aiFeedback = fb;
      });
    }
  }
}

class _AddExerciseResult {
  final String exerciseName;
  final List<int> repsPerSet;
  final int minutes;
  final int seconds;
  final double? distance; // 러닝일 경우 거리 (이전 km)
  final double? weight; // 덤벨컬일 경우 중량 (이전 kg)
  _AddExerciseResult({
    required this.exerciseName,
    required this.repsPerSet,
    required this.minutes,
    required this.seconds,
    this.distance,
    this.weight,
  });
}

String _formatMinSec(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  if (m <= 0) return '${s}초';
  if (s <= 0) return '${m}분';
  return '${m}분 ${s}초';
}

String _formatNumber(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(2);
  s = s.replaceAll(RegExp(r'0+$'), '');
  s = s.replaceAll(RegExp(r'\.$'), '');
  return s;
}

