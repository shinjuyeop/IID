import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/profile_service.dart';
import '../services/measurements_service.dart';
import '../services/ai_service.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  double? heightCm;
  double? weightKg;
  double? bodyFat;
  String? gender;
  String? purpose;
  String? job;
  final _qCtrl = TextEditingController();
  String _aiAnswer = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      heightCm = prefs.getDouble('profile_height');
      weightKg = prefs.getDouble('profile_weight');
      bodyFat = prefs.getDouble('profile_bodyfat');
      gender = prefs.getString('profile_gender');
      purpose = prefs.getString('profile_purpose');
      job = prefs.getString('profile_job');
    });
  }

  Future<void> _editTextField({required String title, required String initial, required void Function(String) onSaved}) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(controller: ctrl, maxLines: 2),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('저장')),
          ],
        );
      },
    );
    if (result != null) onSaved(result);
  }

  Future<void> _updatePurpose() async {
    await _editTextField(
      title: '목표 수정',
      initial: purpose ?? '',
      onSaved: (val) async {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id');
        if (userId == null) return;
        final ok = await ProfileService.updatePurpose(userId: userId, purpose: val);
        if (ok) {
          await prefs.setString('profile_purpose', val);
          setState(() => purpose = val);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('목표 업데이트 실패')));
        }
      },
    );
  }

  Future<void> _updateJob() async {
    await _editTextField(
      title: '직업 수정',
      initial: job ?? '',
      onSaved: (val) async {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id');
        if (userId == null) return;
        final ok = await ProfileService.updateJob(userId: userId, job: val);
        if (ok) {
          await prefs.setString('profile_job', val);
          setState(() => job = val);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('직업 업데이트 실패')));
        }
      },
    );
  }

  Future<void> _sendQuestion() async {
    final question = _qCtrl.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('질문을 입력하세요.')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인 정보를 찾을 수 없습니다.')));
      return;
    }
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final answer = await AiService.askQuestion(userId: userId, question: question);
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      setState(() {
        _aiAnswer = answer ?? '답변을 불러오지 못했습니다.';
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('내 프로필', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _RowTile(label: '키', value: heightCm != null ? '${heightCm!.toStringAsFixed(1)} cm' : '-'),
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeightUpdatePage())).then((_) => _load()),
          child: _RowTile(label: '몸무게', value: weightKg != null ? '${weightKg!.toStringAsFixed(1)} kg' : '-', tappable: true),
        ),
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyFatUpdatePage())).then((_) => _load()),
          child: _RowTile(label: '체지방률', value: bodyFat != null ? '${bodyFat!.toStringAsFixed(1)} %' : '-', tappable: true),
        ),
        _RowTile(label: '성별', value: gender ?? '-'),
        InkWell(
          onTap: _updatePurpose,
          child: _RowTile(label: '목표', value: (purpose?.isNotEmpty ?? false) ? purpose! : '-', tappable: true),
        ),
        InkWell(
          onTap: _updateJob,
          child: _RowTile(label: '직업', value: (job?.isNotEmpty ?? false) ? job! : '-', tappable: true),
        ),
        const SizedBox(height: 24),
        const Text('물어보기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _qCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '궁금한 점을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _sendQuestion, child: const Text('전송')),
        const SizedBox(height: 12),
        if (_aiAnswer.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('답변', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(_aiAnswer),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }
}

class _RowTile extends StatelessWidget {
  final String label;
  final String value;
  final bool tappable;
  const _RowTile({required this.label, required this.value, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x22000000))),
      ),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
          if (tappable) const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );
  }
}

// ================= Weight Update =================
class WeightUpdatePage extends StatefulWidget {
  const WeightUpdatePage({super.key});

  @override
  State<WeightUpdatePage> createState() => _WeightUpdatePageState();
}

class _WeightUpdatePageState extends State<WeightUpdatePage> {
  final ctrl = TextEditingController();
  String message = '';
  List<_DailyPoint> series = [];
  int _days = 7; // window size: 7/14/30

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    List<MeasurementPoint> server = [];
    if (userId != null) {
      server = await MeasurementsService.fetchGraph(userId: userId, type: 'weight');
    }
    // Build last N days [oldest..today]; missing days remain null (no dot), line connects across
    final today = DateTime.now();
    final map = {for (final p in server) _dateKey(p.date): p.value};
    final List<_DailyPoint> out = [];
    for (int i = _days - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final key = _dateKey(d);
      final local = prefs.getDouble('weight_log_$key');
      final v = (map[key] ?? local); // do not carry forward
      out.add(_DailyPoint(d, v));
    }
    setState(() => series = out);
  }

  Future<void> _update() async {
    final val = double.tryParse(ctrl.text.trim());
    if (val == null) {
      setState(() => message = '숫자로 입력하세요.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final h = prefs.getDouble('profile_height') ?? 0;
    final age = prefs.getInt('profile_age') ?? 0;
    final bf = prefs.getDouble('profile_bodyfat') ?? 0;
    final gender = prefs.getString('profile_gender') ?? '남성';
    if (userId == null) {
      setState(() => message = '로그인 정보를 찾을 수 없습니다.');
      return;
    }
    setState(() => message = '업데이트 중...');
    final ok = await ProfileService.updateWeight(
      userId: userId,
      heightCm: h,
      newWeightKg: val,
      age: age,
      bodyFat: bf,
      gender: gender,
    );
    if (!ok) {
      setState(() => message = '업데이트 실패: 서버 또는 네트워크 오류');
      return;
    }
    final todayKey = _dateKey(DateTime.now());
    await prefs.setDouble('profile_weight', val);
    await prefs.setDouble('weight_log_$todayKey', val);
    setState(() => message = '업데이트 완료');
    await _loadSeries();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('몸무게 업데이트')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '새 몸무게 (kg)'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _update, child: const Text('업데이트')),
            const SizedBox(height: 12),
            // 7/14/30 day toggle
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7일')),
                ButtonSegment(value: 14, label: Text('14일')),
                ButtonSegment(value: 30, label: Text('30일')),
              ],
              selected: {_days},
              onSelectionChanged: (s) {
                setState(() => _days = s.first);
                _loadSeries();
              },
            ),
            const SizedBox(height: 8),
            if (message.isNotEmpty) Text(message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            Expanded(child: _LineChart(points: series, label: '몸무게(kg)', days: _days)),
          ],
        ),
      ),
    );
  }
}

// ================= Body Fat Update =================
class BodyFatUpdatePage extends StatefulWidget {
  const BodyFatUpdatePage({super.key});

  @override
  State<BodyFatUpdatePage> createState() => _BodyFatUpdatePageState();
}

class _BodyFatUpdatePageState extends State<BodyFatUpdatePage> {
  final ctrl = TextEditingController();
  String message = '';
  List<_DailyPoint> series = [];
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    List<MeasurementPoint> server = [];
    if (userId != null) {
      server = await MeasurementsService.fetchGraph(userId: userId, type: 'body_fat');
    }
    final today = DateTime.now();
    final map = {for (final p in server) _dateKey(p.date): p.value};
    final List<_DailyPoint> out = [];
    for (int i = _days - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final key = _dateKey(d);
      final local = prefs.getDouble('bodyfat_log_$key');
      final v = (map[key] ?? local);
      out.add(_DailyPoint(d, v));
    }
    setState(() => series = out);
  }

  Future<void> _update() async {
    final val = double.tryParse(ctrl.text.trim());
    if (val == null) {
      setState(() => message = '숫자로 입력하세요.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final h = prefs.getDouble('profile_height') ?? 0;
    final age = prefs.getInt('profile_age') ?? 0;
    final w = prefs.getDouble('profile_weight') ?? 0;
    final gender = prefs.getString('profile_gender') ?? '남성';
    if (userId == null) {
      setState(() => message = '로그인 정보를 찾을 수 없습니다.');
      return;
    }
    setState(() => message = '업데이트 중...');
    final ok = await ProfileService.updateBodyFat(
      userId: userId,
      heightCm: h,
      weightKg: w,
      age: age,
      newBodyFat: val,
      gender: gender,
    );
    if (!ok) {
      setState(() => message = '업데이트 실패: 서버 또는 네트워크 오류');
      return;
    }
    final todayKey = _dateKey(DateTime.now());
    await prefs.setDouble('profile_bodyfat', val);
    await prefs.setDouble('bodyfat_log_$todayKey', val);
    setState(() => message = '업데이트 완료');
    await _loadSeries();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('체지방률 업데이트')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '새 체지방률 (%)'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _update, child: const Text('업데이트')),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7일')),
                ButtonSegment(value: 14, label: Text('14일')),
                ButtonSegment(value: 30, label: Text('30일')),
              ],
              selected: {_days},
              onSelectionChanged: (s) {
                setState(() => _days = s.first);
                _loadSeries();
              },
            ),
            const SizedBox(height: 8),
            if (message.isNotEmpty) Text(message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            Expanded(child: _LineChart(points: series, label: '체지방률(%)', days: _days)),
          ],
        ),
      ),
    );
  }
}

// =============== Shared Utils ===============
String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _DailyPoint {
  final DateTime date;
  final double? value;
  _DailyPoint(this.date, this.value);
}

class _LineChart extends StatelessWidget {
  final List<_DailyPoint> points;
  final String label;
  final int days; // window size used for slots/label
  const _LineChart({required this.points, required this.label, required this.days});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: CustomPaint(
                painter: _LineChartPainter(points, days),
                child: Container(),
              ),
            ),
            const SizedBox(height: 4),
            Text('최근 $days일', textAlign: TextAlign.right, style: const TextStyle(color: Colors.black45, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_DailyPoint> pts;
  final int days;
  _LineChartPainter(this.pts, this.days);

  @override
  void paint(Canvas canvas, Size size) {
    final paintAxis = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    final paintLine = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final paintDot = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    final paintAxisLabel = const TextStyle(fontSize: 11, color: Color(0x99000000));

  final leftPad = 44.0; // extra space for y-axis labels
  final bottomPad = 28.0;
  final topPad = 8.0;
  final rightPad = 8.0;
  final chartRect = Rect.fromLTWH(leftPad, topPad, size.width - leftPad - rightPad, size.height - bottomPad - topPad);

    // Draw axes
  canvas.drawLine(Offset(chartRect.left, chartRect.bottom), Offset(chartRect.right, chartRect.bottom), paintAxis);
  canvas.drawLine(Offset(chartRect.left, chartRect.top), Offset(chartRect.left, chartRect.bottom), paintAxis);

    // Build y-range excluding nulls
    final values = pts.map((e) => e.value).whereType<double>().toList();
    if (values.isEmpty) return;
    double minV = values.reduce((a, b) => a < b ? a : b);
    double maxV = values.reduce((a, b) => a > b ? a : b);
    if ((maxV - minV).abs() < 1e-6) {
      // Expand range slightly if flat
      minV -= 1;
      maxV += 1;
    }

    // Draw Y-axis ticks and labels (5 ticks)
    const tickCount = 5;
    final textStyle = const TextStyle(fontSize: 11, color: Color(0x99000000));
    for (int i = 0; i <= tickCount; i++) {
      final ratio = i / tickCount;
      final y = chartRect.bottom - ratio * chartRect.height;
      final val = minV + ratio * (maxV - minV);
      // Tick line
      canvas.drawLine(Offset(chartRect.left - 4, y), Offset(chartRect.left, y), paintAxis);
      // Label
      final tp = TextPainter(
        text: TextSpan(text: val.toStringAsFixed(1), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPad - 8);
      tp.paint(canvas, Offset(chartRect.left - leftPad + 4, y - tp.height / 2));
    }

  final path = Path();
  final int totalSlots = days < 1 ? 1 : days;
  final double stepX = totalSlots > 1 ? chartRect.width / (totalSlots - 1) : 0.0;
    bool started = false;
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      final v = p.value;
      final x = chartRect.left + stepX * i;
      if (v == null) continue;
      final yRatio = (v - minV) / (maxV - minV);
      final y = chartRect.bottom - yRatio * chartRect.height;
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
      canvas.drawCircle(Offset(x, y), 5, paintDot); // larger point radius
    }
    // Draw X-axis labels at controlled density based on selected window (7: daily, 14: every 2 days, 30: every 5 days)
    int step;
    if (days == 7) {
      step = 1;
    } else if (days == 14) {
      step = 2;
    } else if (days == 30) {
      step = 5;
    } else {
      // Fallback: scale roughly
      step = days <= 7 ? 1 : days <= 14 ? 2 : 5;
    }
    final lastIndex = pts.length - 1;
    for (int i = 0; i < pts.length; i++) {
      // Anchor labeling to the most recent date (rightmost)
      final shouldLabel = ((lastIndex - i) % step == 0) || (i == lastIndex);
      if (!shouldLabel) continue;
      final p = pts[i];
      final x = chartRect.left + stepX * i;
      final label = '${p.date.month.toString().padLeft(2,'0')}/${p.date.day.toString().padLeft(2,'0')}';
      final tp = TextPainter(
        text: TextSpan(text: label, style: paintAxisLabel),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width/2, chartRect.bottom + 4));
    }
    // Draw an x-axis baseline again to overlay behind labels (optional thickness reuse)
    canvas.drawLine(Offset(chartRect.left, chartRect.bottom), Offset(chartRect.right, chartRect.bottom), paintAxis);
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
