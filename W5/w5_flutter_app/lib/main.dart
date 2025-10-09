import 'package:flutter/material.dart';
import 'services/api_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'W5 IOT Controller',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = ApiClient();
  Status? status;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final s = await api.fetchData();
      setState(() => status = s);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _setMode(bool auto) async {
    try {
      await api.setMode(auto);
      await _refresh();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _control(int id, int state) async {
    if (status?.autoMode == true) return;
    try {
      await api.controlDevice(id, state);
      await _refresh();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('W5 IOT Controller'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Mode:'),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _setMode(true),
                      child: const Text('AUTO'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _setMode(false),
                      child: const Text('MANUAL'),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      label: Text(s?.autoMode == true ? 'AUTO' : 'MANUAL'),
                      backgroundColor: s?.autoMode == true
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Temperature: \\${s?.temperature?.toStringAsFixed(1) ?? '--'} ℃'),
                        Text('Humidity: \\${s?.humidity?.toStringAsFixed(1) ?? '--'} %'),
                        Text('Distance: \\${s?.distance?.toStringAsFixed(1) ?? '--'} cm'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _deviceCard('AirCon', 0, (s?.ledStatus.length ?? 0) > 0 && s!.ledStatus[0] == 1, s?.autoMode == true),
                    _deviceCard('Heater', 1, (s?.ledStatus.length ?? 0) > 1 && s!.ledStatus[1] == 1, s?.autoMode == true),
                    _deviceCard('Dehumid', 2, (s?.ledStatus.length ?? 0) > 2 && s!.ledStatus[2] == 1, s?.autoMode == true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deviceCard(String name, int id, bool on, bool autoLocked) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(on ? 'ON' : 'OFF',
                style: TextStyle(color: on ? Colors.green : Colors.red)),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: autoLocked ? null : () => _control(id, 1),
                  child: const Text('ON'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: autoLocked ? null : () => _control(id, 0),
                  child: const Text('OFF'),
                ),
              ],
            ),
            if (autoLocked)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('AUTO mode',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}
