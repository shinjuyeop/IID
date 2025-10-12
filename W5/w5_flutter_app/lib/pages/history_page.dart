import 'package:flutter/material.dart';
import '../services/api_client.dart';

class HistoryPage extends StatefulWidget {
  final String metric; // 'temp' | 'humid' | 'dist'
  final String title;
  final String yLabel;
  const HistoryPage({Key? key, required this.metric, required this.title, required this.yLabel})
      : super(key: key);

  static HistoryPage temp() => const HistoryPage(metric: 'temp', title: '온도 최근 10개', yLabel: '℃');
  static HistoryPage humid() => const HistoryPage(metric: 'humid', title: '습도 최근 10개', yLabel: '%');
  static HistoryPage dist() => const HistoryPage(metric: 'dist', title: '거리 최근 10개', yLabel: 'cm');

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  final api = ApiClient();
  List<HistoryPoint> points = const [];
  bool busy = false;
  String? error;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { busy = true; error = null; });
    try {
      final data = await api.fetchHistory(widget.metric);
      setState(() => points = List.of(data.reversed));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: '그래프'), Tab(text: '최근 10개')]),
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: Colors.red))),
          Expanded(
            child: TabBarView(controller: _tab, children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(child: Padding(padding: const EdgeInsets.all(12), child: _LineChart(points: points, yLabel: widget.yLabel))),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: ListView.separated(
                    itemCount: points.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = points[i];
                      return ListTile(
                        dense: true,
                        title: Text(p.dt),
                        trailing: Text(p.value?.toStringAsFixed(2) ?? '--'),
                      );
                    },
                  ),
                ),
              ),
            ]),
          )
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<HistoryPoint> points;
  final String yLabel;
  const _LineChart({Key? key, required this.points, required this.yLabel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _LineChartPainter(points: points, yLabel: yLabel),
          size: Size.infinite,
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<HistoryPoint> points;
  final String yLabel;
  _LineChartPainter({required this.points, required this.yLabel});

  static const double margin = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(margin, margin, size.width - margin * 2, size.height - margin * 2);
    final axisPaint = Paint()..color = const Color(0xFF999999)..strokeWidth = 1;
    final gridPaint = Paint()..color = const Color(0xFFDDDDDD)..strokeWidth = 1;
    final linePaint = Paint()..color = const Color(0xFF1976D2)..strokeWidth = 2..style = PaintingStyle.stroke;

    // axes
    canvas.drawLine(Offset(area.left, area.bottom), Offset(area.right, area.bottom), axisPaint);
    canvas.drawLine(Offset(area.left, area.top), Offset(area.left, area.bottom), axisPaint);
    // grid
    for (int i = 1; i <= 4; i++) {
      final y = area.top + area.height * i / 5;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), gridPaint);
    }

    if (points.isEmpty) return;
    final vals = points.where((p) => p.value != null).map((p) => p.value!).toList();
    if (vals.isEmpty) return;
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);

    final path = Path();
    final n = points.length;
    for (int i = 0; i < n; i++) {
      final v = points[i].value ?? minV;
      final t = i / (n - 1 == 0 ? 1 : (n - 1));
      final x = area.left + area.width * t;
      final y = area.bottom - area.height * ((v - minV) / range);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.points != points || oldDelegate.yLabel != yLabel;
}
