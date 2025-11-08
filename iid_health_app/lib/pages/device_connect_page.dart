import 'package:flutter/material.dart';

class DeviceConnectPage extends StatelessWidget {
  const DeviceConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기기 연결 안내')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '스마트 기기 연결',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('지원 기기: 스마트워치/체중계 등. 설정 > 블루투스에서 기기를 페어링해 주세요.'),
            const SizedBox(height: 12),
            const Text('앱 내 연동은 이후 업데이트에서 제공될 예정입니다.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  // Placeholder: go to home/dashboard later
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('연결 가이드를 완료했습니다.')),
                  );
                },
                child: const Text('완료'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
