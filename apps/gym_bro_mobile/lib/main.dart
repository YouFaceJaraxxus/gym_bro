import 'package:flutter/material.dart';
import 'pages/signup_page.dart';
import 'pages/check_email_page.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/auth_manager.dart';

void main() {
  runApp(const GymBroApp());
}

class GymBroApp extends StatelessWidget {
  const GymBroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Bro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const _AppInit(),
        '/signup': (_) => const SignupPage(),
        '/check-email': (_) => const CheckEmailPage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
      },
    );
  }
}

class _AppInit extends StatefulWidget {
  const _AppInit();

  @override
  State<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<_AppInit> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final hasSession = await AuthManager.instance.tryRestoreSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, hasSession ? '/home' : '/signup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
