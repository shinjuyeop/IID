import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/profile_service.dart';
// config not used here but keepable if endpoint customization later

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final bodyFatCtrl = TextEditingController();
  final purposeCtrl = TextEditingController();
  final jobCtrl = TextEditingController();
  String? selectedGender;
  int? selectedAge;

  String message = '';

  Future<void> _save() async {
    final h = double.tryParse(heightCtrl.text.trim());
    final w = double.tryParse(weightCtrl.text.trim());
    final bf = double.tryParse(bodyFatCtrl.text.trim());
    if (h == null || w == null || bf == null || selectedGender == null || selectedAge == null) {
      setState(() => message = '정확한 값과 성별/나이를 입력하세요.');
      return;
    }

    // 서버에 전송하기 전에 user_id가 있는지 확인
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      setState(() => message = '로그인 정보가 없습니다. 다시 로그인하세요.');
      return;
    }

    setState(() => message = '프로필 업로드 중...');
    final ok = await ProfileService.uploadProfile(
      userId: userId,
      heightCm: h,
      weightKg: w,
      age: selectedAge!,
      bodyFat: bf,
      gender: selectedGender!,
      purpose: purposeCtrl.text.trim(),
      job: jobCtrl.text.trim(),
    );

    if (!ok) {
      setState(() => message = '프로필 업로드에 실패했습니다. 네트워크 또는 서버를 확인하세요.');
      return;
    }

    // 서버 전송 성공 시 로컬에도 저장하고 완료 플래그 설정
    await prefs.setDouble('profile_height', h);
    await prefs.setDouble('profile_weight', w);
    await prefs.setDouble('profile_bodyfat', bf);
  await prefs.setString('profile_gender', selectedGender!);
    await prefs.setInt('profile_age', selectedAge!);
  await prefs.setString('profile_purpose', purposeCtrl.text.trim());
  await prefs.setString('profile_job', jobCtrl.text.trim());
  // per-user profile completed flag
  await prefs.setBool('profile_completed_${userId}', true);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    heightCtrl.dispose();
    weightCtrl.dispose();
    bodyFatCtrl.dispose();
    purposeCtrl.dispose();
    jobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('초기 프로필 입력')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: heightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '키 (cm)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '몸무게 (kg)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyFatCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '체지방률 (%)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: purposeCtrl,
              decoration: const InputDecoration(labelText: '목표 (예: 몸무게 10kg 감량)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: jobCtrl,
              decoration: const InputDecoration(labelText: '직업 (예: 사무직 개발자)'),
            ),
            const SizedBox(height: 12),
            // 성별 드롭다운
            DropdownButtonFormField<String>(
              value: selectedGender,
              decoration: const InputDecoration(labelText: '성별'),
              items: ['남성', '여성']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => selectedGender = v),
            ),
            const SizedBox(height: 12),
            // 나이 드롭다운 (10~100)
            DropdownButtonFormField<int>(
              value: selectedAge,
              decoration: const InputDecoration(labelText: '나이'),
              items: List.generate(91, (i) => i + 10)
                  .map((age) => DropdownMenuItem(value: age, child: Text('$age')))
                  .toList(),
              onChanged: (v) => setState(() => selectedAge = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('저장하고 계속'),
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