import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/auth_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();

  bool _loading = true;
  String? _successMessage;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _callTestEndpoint();
  }

  Future<void> _callTestEndpoint() async {
    try {
      final accessToken = await AuthManager.instance.getValidToken();
      final data = await _authService.testEndpoint(accessToken);
      final profile = data['profile'] as Map<String, dynamic>?;
      setState(() {
        _successMessage =
            'Authenticated as ${profile?['username'] ?? profile?['email'] ?? 'user'}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await AuthManager.instance.clear();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/signup');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello World',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              if (_loading)
                const CircularProgressIndicator()
              else if (_successMessage != null)
                _StatusCard(
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  title: 'Test endpoint OK',
                  body: _successMessage!,
                )
              else if (_errorMessage != null)
                _StatusCard(
                  icon: Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  title: 'Test endpoint failed',
                  body: _errorMessage!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
