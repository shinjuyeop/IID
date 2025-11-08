import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:shared_preferences/shared_preferences.dart';
import 'records_page.dart';
import 'meals_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final _pages = const [RecordsPage(), MealsPage(), SettingsPage()];

  String get _title => ['기록', '식단', '설정'][_index];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.schedule), label: '기록'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: '식단'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
