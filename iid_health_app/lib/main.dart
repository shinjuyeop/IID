import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/onboarding_intro.dart';
import 'pages/terms_consent.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/profile_setup_page.dart';
// import 'pages/device_connect_page.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IID Health',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (_) => const _SplashGate(),
        '/intro': (_) => const OnboardingIntroPage(),
        '/terms': (_) => const TermsConsentPage(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/profile': (_) => const ProfileSetupPage(),
  // '/device': (_) => const DeviceConnectPage(),
  '/home': (_) => const HomePage(),
      },
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();
  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _decideStart();
  }

  Future<void> _decideStart() async {
    final prefs = await SharedPreferences.getInstance();
    final introDone = prefs.getBool('onboarding_intro_done') ?? false;
    final termsAgreed = prefs.getBool('onboarding_terms_agreed') ?? false;
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    bool profileDone = false;
    if (loggedIn) {
      final userId = prefs.getInt('user_id');
      if (userId != null) {
        profileDone = prefs.getBool('profile_completed_${userId}') ?? false;
      }
    }

    String nextRoute;
    if (!introDone) {
      nextRoute = '/intro';
    } else if (!termsAgreed) {
      nextRoute = '/terms';
    } else if (!loggedIn) {
      nextRoute = '/login';
    } else if (!profileDone) {
      nextRoute = '/profile';
    } else {
      nextRoute = '/home';
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
