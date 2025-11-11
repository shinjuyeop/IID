import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  final pw2Ctrl = TextEditingController();
  String message = '';
  bool pwVisible = false;

  Future<void> _register() async {
    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pw = pwCtrl.text;
    final pw2 = pw2Ctrl.text;

    if ([name, email, pw, pw2].any((e) => e.isEmpty)) {
      setState(() => message = '모든 항목을 입력하세요.');
      return;
    }
    if (pw != pw2) {
      setState(() => message = '비밀번호가 일치하지 않습니다.');
      return;
    }
    try {
      final ok = await AuthService.register(
        userName: name, // backend expects 'user_name' → using name field
        email: email,
        password: pw,
      );

      if (ok) {
        // Store basic info locally for convenience and consistency with SettingsPage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('account_name', name);
        await prefs.setString('account_email', email);
        await prefs.setString('user_name', name); // for SettingsPage
        await prefs.setString('email', email);    // for SettingsPage

        if (!mounted) return;
        Navigator.pop(context); // Back to login
      } else {
        setState(() => message = '회원가입 실패: 서버 오류가 발생했습니다.');
      }
    } catch (e) {
      setState(() => message = '회원가입 오류: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            const SizedBox(height: 12),
            // ID 입력칸 제거: 이메일 + 비밀번호 기준 회원가입
            TextField(
              controller: pwCtrl,
              obscureText: !pwVisible,
              decoration: InputDecoration(
                labelText: '비밀번호',
                suffixIcon: IconButton(
                  icon: Icon(pwVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => pwVisible = !pwVisible),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pw2Ctrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호 확인'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _register,
                child: const Text('가입하기'),
              ),
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
