import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:shared_preferences/shared_preferences.dart';
import 'meals_page.dart';
import 'settings_page.dart';
import 'exercise_page.dart';
import 'mypage_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final _pages = const [
    ExercisePage(),
    MealsPage(),
    MyPage(),
    SettingsPage(),
  ];

  String get _title => ['운동', '식단', '마이페이지', '설정'][_index];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fitness_center), label: '운동'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: '식단'),
          NavigationDestination(icon: Icon(Icons.person), label: '마이페이지'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
