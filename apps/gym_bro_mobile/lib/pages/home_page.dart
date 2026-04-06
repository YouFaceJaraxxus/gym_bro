import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_manager.dart';
import '../services/auth_service.dart';
import 'home/owner_home_page.dart';
import 'home/member_home_page.dart';
import 'home/trainer_home_page.dart';
import 'home/employee_home_page.dart';
import 'home/employee_trainer_home_page.dart';
import 'home/super_user_home_page.dart';

// ── Per-role nav tab definitions ──────────────────────────────────────────────

typedef _Tab = ({String label, IconData icon});

const _ownerTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Staff', icon: Icons.badge_outlined),
  (label: 'Members', icon: Icons.people_outline),
  (label: 'Profile', icon: Icons.person_outline),
];

const _memberTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Membership', icon: Icons.card_membership_outlined),
  (label: 'Schedule', icon: Icons.calendar_today_outlined),
  (label: 'Profile', icon: Icons.person_outline),
];

const _trainerTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Classes', icon: Icons.fitness_center_outlined),
  (label: 'Members', icon: Icons.people_outline),
  (label: 'Profile', icon: Icons.person_outline),
];

const _employeeTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Schedule', icon: Icons.schedule_outlined),
  (label: 'Profile', icon: Icons.person_outline),
];

const _employeeTrainerTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Classes', icon: Icons.fitness_center_outlined),
  (label: 'Schedule', icon: Icons.schedule_outlined),
  (label: 'Profile', icon: Icons.person_outline),
];

const _superUserTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Businesses', icon: Icons.business_outlined),
  (label: 'Users', icon: Icons.manage_accounts_outlined),
  (label: 'Profile', icon: Icons.person_outline),
];

List<_Tab> _tabsForRole(UserRole role) => switch (role) {
      UserRole.owner => _ownerTabs,
      UserRole.member => _memberTabs,
      UserRole.trainer => _trainerTabs,
      UserRole.employee => _employeeTabs,
      UserRole.employeeTrainer => _employeeTrainerTabs,
      UserRole.superUser => _superUserTabs,
    };

// ── HomePage shell ────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();

  int _tabIndex = 0;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Show the cached profile immediately to avoid a loading spinner, but
    // always fetch fresh from the API so the role is never stale.
    final cached = AuthManager.instance.profile;
    if (cached != null) {
      setState(() {
        _profile = cached;
        _loading = false;
      });
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      final data = await _authService.testEndpoint(token);
      final profileData = data['profile'] as Map<String, dynamic>?;
      if (profileData == null) throw Exception('No profile returned');
      final fresh = UserProfile.fromJson(profileData);
      await AuthManager.instance.updateProfile(fresh);
      if (mounted) {
        setState(() {
          _profile = fresh;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _profile == null) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await AuthManager.instance.clear();
    if (mounted) Navigator.pushReplacementNamed(context, '/signup');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(_error ?? 'Could not load profile'),
                const SizedBox(height: 24),
                FilledButton(onPressed: _logout, child: const Text('Back to Login')),
              ],
            ),
          ),
        ),
      );
    }

    final profile = _profile!;
    final tabs = _tabsForRole(profile.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_tabIndex].label),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(profile, _tabIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }

  Widget _buildBody(UserProfile profile, int index) {
    // Tab 0 is always the role-specific home page.
    if (index == 0) {
      return switch (profile.role) {
        UserRole.owner => OwnerHomePage(profile: profile),
        UserRole.member => MemberHomePage(profile: profile),
        UserRole.trainer => TrainerHomePage(profile: profile),
        UserRole.employee => EmployeeHomePage(profile: profile),
        UserRole.employeeTrainer => EmployeeTrainerHomePage(profile: profile),
        UserRole.superUser => SuperUserHomePage(profile: profile),
      };
    }
    // Remaining tabs show a placeholder until their pages are built.
    final tabs = _tabsForRole(profile.role);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tabs[index].icon,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(tabs[index].label,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
