import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? accountName;
  String? accountEmail;
  String? serverEmail;
  int? userId;
  String message = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      accountName = prefs.getString('account_name');
      accountEmail = prefs.getString('account_email');
      serverEmail = prefs.getString('email');
      userId = prefs.getInt('user_id');
    });
  }

  Future<void> _withdraw() async {
    final email = serverEmail ?? accountEmail;
    if (email == null || email.isEmpty) {
      setState(() => message = '이메일 정보를 찾을 수 없습니다. 다시 로그인해주세요.');
      return;
    }

    final pwCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('정말로 탈퇴하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
            const SizedBox(height: 12),
            Text('이메일: $email', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('탈퇴')),
        ],
      ),
    );

    if (ok != true) return;
    final password = pwCtrl.text;
    if (password.isEmpty) {
      setState(() => message = '비밀번호를 입력하세요.');
      return;
    }

    setState(() => message = '탈퇴 처리 중...');
    final success = await AuthService.withdrawAccount(email: email, password: password);
    if (!success) {
      setState(() => message = '서버 탈퇴 요청이 실패했습니다.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('계정 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _InfoRow(label: '이름', value: accountName ?? '-'),
          _InfoRow(label: '이메일(가입)', value: accountEmail ?? '-'),
          _InfoRow(label: '이메일(서버)', value: serverEmail ?? '-'),
          _InfoRow(label: 'User ID', value: userId?.toString() ?? '-'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _logout,
                  child: const Text('로그아웃'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _withdraw,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade800,
                  ),
                  child: const Text('회원 탈퇴'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (message.isNotEmpty)
            Text(message, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
