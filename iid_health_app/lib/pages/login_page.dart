import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  bool keepLoggedIn = true;
  String message = '';

  Future<void> _doLogin() async {
    final email = emailCtrl.text.trim();
    final pw = pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => message = '이메일과 비밀번호를 입력하세요.');
      return;
    }
    try {
      // Try backend login first (email + password)
      final ok = await AuthService.login(email: email, password: pw);
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', keepLoggedIn);
    // 로그인 성공 후 해당 계정(user_id)의 profile_completed 플래그가 있으면 홈으로, 없으면 프로필 입력으로 이동
    final userId = prefs.getInt('user_id');
    final profileDone = (userId != null)
      ? (prefs.getBool('profile_completed_${userId}') ?? false)
      : false;
        if (mounted) {
          if (profileDone) {
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            Navigator.pushReplacementNamed(context, '/profile');
          }
        }
        return;
      }
      setState(() => message = '로그인 실패: 서버 검증에 실패했습니다.');
    } catch (e) {
      setState(() => message = '로그인 오류: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: keepLoggedIn,
                  onChanged: (v) => setState(() => keepLoggedIn = v ?? true),
                ),
                const Text('로그인 상태 유지'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _doLogin,
                child: const Text('로그인'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('회원가입'),
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            Text('현재 로그인 테이블: ${AppConfig.loginTable}', style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
