import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TermsConsentPage extends StatefulWidget {
  const TermsConsentPage({super.key});

  @override
  State<TermsConsentPage> createState() => _TermsConsentPageState();
}

class _TermsConsentPageState extends State<TermsConsentPage> {
  bool agreeService = false;
  bool agreePrivacy = false;

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_terms_agreed', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = agreeService && agreePrivacy;
    return Scaffold(
      appBar: AppBar(title: const Text('약관 동의')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('서비스 소개', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('이 앱은 건강 관리, 운동/식단 기록 및 목표 설정을 돕습니다.'),
            const SizedBox(height: 24),
            CheckboxListTile(
              value: agreeService,
              onChanged: (v) => setState(() => agreeService = v ?? false),
              title: const Text('[필수] 서비스 이용약관 동의'),
            ),
            CheckboxListTile(
              value: agreePrivacy,
              onChanged: (v) => setState(() => agreePrivacy = v ?? false),
              title: const Text('[필수] 개인정보 처리방침 동의'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canProceed ? _accept : null,
                child: const Text('동의하고 계속하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
