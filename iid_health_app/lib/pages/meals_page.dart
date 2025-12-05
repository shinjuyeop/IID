import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/meals_service.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  DateTime _selectedDate = DateTime.now();

  // Simple in-memory storage for meal notes by date (normalized to Y-M-D).
  final Map<DateTime, _MealNotes> _notesByDate = {};

  late final TextEditingController _breakfastCtrl;
  late final TextEditingController _lunchCtrl;
  late final TextEditingController _dinnerCtrl;
  String? _evaluation; // from backend

  @override
  void initState() {
    super.initState();
    _breakfastCtrl = TextEditingController();
    _lunchCtrl = TextEditingController();
    _dinnerCtrl = TextEditingController();
    _loadFor(_selectedDate);
  }

  @override
  void dispose() {
    _breakfastCtrl.dispose();
    _lunchCtrl.dispose();
    _dinnerCtrl.dispose();
    super.dispose();
  }

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  void _loadFor(DateTime date) {
    final key = _ymd(date);
    final note = _notesByDate[key];
    // Reset evaluation by default when changing dates to avoid stale comments.
    _evaluation = null;
    _breakfastCtrl.text = note?.breakfast ?? '';
    _lunchCtrl.text = note?.lunch ?? '';
    _dinnerCtrl.text = note?.dinner ?? '';
    // Also try to load from backend and local storage.
    _loadFromBackendAndPrefs(key);
  }

  void _saveCurrent() {
    final key = _ymd(_selectedDate);
    _notesByDate[key] = _MealNotes(
      breakfast: _breakfastCtrl.text,
      lunch: _lunchCtrl.text,
      dinner: _dinnerCtrl.text,
    );
  }

  String _recommendation() {
    if (_evaluation != null && _evaluation!.trim().isNotEmpty) {
      return _evaluation!;
    }
    final b = _breakfastCtrl.text.trim().isNotEmpty;
    final l = _lunchCtrl.text.trim().isNotEmpty;
    final d = _dinnerCtrl.text.trim().isNotEmpty;
    final count = [b, l, d].where((x) => x).length;
    if (count == 0) return '오늘의 식단을 입력해보세요!';
    if (count == 1) return '하루 세 끼를 골고루 챙겨보면 어때요?';
    if (count == 2) return '좋아요! 남은 한 끼도 가볍게 채워보세요.';
    return '아주 좋아요! 과일/채소와 단백질로 균형을 유지해요.';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: CalendarDatePicker(
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        onDateChanged: (date) {
                          // Save current and switch
                          _saveCurrent();
                          setState(() {
                            _selectedDate = date;
                            _loadFor(date);
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MealField(
                    label: '아침',
                    hint: '예: 삶은 달걀, 바나나, 우유',
                    controller: _breakfastCtrl,
                    onChanged: (_) => _saveCurrent(),
                  ),
                  const SizedBox(height: 12),
                  _MealField(
                    label: '점심',
                    hint: '예: 현미밥, 닭가슴살, 샐러드',
                    controller: _lunchCtrl,
                    onChanged: (_) => _saveCurrent(),
                  ),
                  const SizedBox(height: 12),
                  _MealField(
                    label: '저녁',
                    hint: '예: 고구마, 연어, 채소볶음',
                    controller: _dinnerCtrl,
                    onChanged: (_) => _saveCurrent(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 24),
                  _RecommendationBox(text: _recommendation()),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        _saveCurrent();
                        final messenger = ScaffoldMessenger.of(context);
                        await _persistFor(_selectedDate);
                        if (!mounted) return;
                        // Show loading while waiting for evaluation (can take ~5s)
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => const _LoadingDialog(message: '분석 중입니다... 잠시만 기다려주세요'),
                        );
                        // Send to backend and capture AI recommendation
                        // Load user_id for backend call
                        final prefs = await SharedPreferences.getInstance();
                        final userId = prefs.getInt('user_id');
                        String? rec;
                        if (userId == null) {
                          rec = null;
                          messenger.showSnackBar(const SnackBar(content: Text('로그인 정보(user_id)를 찾을 수 없어 추천을 받지 못했습니다.')));
                        } else {
                          rec = await MealsService.saveDailyMeals(
                            userId: userId,
                            date: _dateKey(_selectedDate),
                            breakfast: _breakfastCtrl.text,
                            lunch: _lunchCtrl.text,
                            dinner: _dinnerCtrl.text,
                          );
                        }
                        if (mounted) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                        if (!mounted) return;
                        if (rec != null) {
                          setState(() {
                            _evaluation = rec;
                          });
                          // persist evaluation for this date
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('meals_${_dateKey(_selectedDate)}_evaluation', rec);
                        }
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text(rec != null ? '저장 및 추천을 받았습니다.' : '저장되었습니다.')),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _persistFor(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(date);
    await prefs.setString('meals_${key}_b', _breakfastCtrl.text);
    await prefs.setString('meals_${key}_l', _lunchCtrl.text);
    await prefs.setString('meals_${key}_d', _dinnerCtrl.text);
  }

  Future<void> _loadFromPrefsAndApply(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(date);
    final b = prefs.getString('meals_${key}_b');
    final l = prefs.getString('meals_${key}_l');
    final d = prefs.getString('meals_${key}_d');
    final ai = prefs.getString('meals_${key}_evaluation');
    if (b == null && l == null && d == null) {
      // No local data for this date; ensure evaluation is cleared if currently selected.
      if (mounted && _ymd(_selectedDate) == _ymd(date)) {
        setState(() {
          _evaluation = null;
        });
      }
      return;
    }

    final note = _MealNotes(breakfast: b ?? '', lunch: l ?? '', dinner: d ?? '');
    _notesByDate[_ymd(date)] = note;
    if (!mounted) return;
    if (_ymd(_selectedDate) == _ymd(date)) {
      setState(() {
        _breakfastCtrl.text = note.breakfast;
        _lunchCtrl.text = note.lunch;
        _dinnerCtrl.text = note.dinner;
        _evaluation = ai; // may be null
      });
    }
  }

  /// Backend + local 저장소에서 식단/AI 코멘트를 불러와 적용
  Future<void> _loadFromBackendAndPrefs(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final keyStr = _dateKey(date);

    // 1) 먼저 백엔드에서 조회 시도
    if (userId != null) {
      final log = await MealsService.loadDailyMeals(userId: userId, date: keyStr);
      if (log != null && mounted && _ymd(_selectedDate) == _ymd(date)) {
        setState(() {
          _breakfastCtrl.text = log.breakfast ?? '';
          _lunchCtrl.text = log.lunch ?? '';
          _dinnerCtrl.text = log.dinner ?? '';
          _evaluation = log.aiComment ?? _evaluation;
        });

        // 백업용으로 로컬에도 저장
        await prefs.setString('meals_${keyStr}_b', _breakfastCtrl.text);
        await prefs.setString('meals_${keyStr}_l', _lunchCtrl.text);
        await prefs.setString('meals_${keyStr}_d', _dinnerCtrl.text);
        if (_evaluation != null) {
          await prefs.setString('meals_${keyStr}_evaluation', _evaluation!);
        }
        return;
      }
    }

    // 2) 백엔드 실패 시 기존 로컬 저장값 사용
    await _loadFromPrefsAndApply(date);
    // If neither backend nor prefs had data for this date, keep evaluation cleared.
  }
}

class _MealField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _MealField({
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 3,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RecommendationBox extends StatelessWidget {
  final String text;
  const _RecommendationBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('추천 코멘트', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealNotes {
  final String breakfast;
  final String lunch;
  final String dinner;
  const _MealNotes({this.breakfast = '', this.lunch = '', this.dinner = ''});
}

class _LoadingDialog extends StatelessWidget {
  final String message;
  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
