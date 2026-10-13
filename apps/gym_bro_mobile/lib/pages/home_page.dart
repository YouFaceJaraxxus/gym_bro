import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../services/auth_service.dart';
import 'home/owner_home_page.dart';
import 'home/owner_businesses_page.dart';
import 'home/employee_members_page.dart';
import 'home/member_home_page.dart';
import 'home/trainer_home_page.dart';
import 'home/employee_home_page.dart';
import 'home/employee_trainer_home_page.dart';
import 'home/super_user_home_page.dart';
import 'home/owner_users_page.dart';
import 'home/trainer_members_page.dart';
import 'home/vendor_home_page.dart';
import 'home/vendor_shop_page.dart';
import 'notifications_page.dart';
import 'gym_hub_page.dart';
import 'profile_page.dart';
import 'sessions_page.dart';
import 'membership_page.dart';

// ── Per-role nav tab definitions ──────────────────────────────────────────────

typedef _Tab = ({String label, IconData icon});

// Shared tabs appended to every role's list.
const _sharedTabs = <_Tab>[
  (label: 'Gym', icon: Icons.fitness_center),
  (label: 'Profile', icon: Icons.person_outline),
];

const _ownerTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Businesses', icon: Icons.business_outlined),
  ..._sharedTabs,
];

const _memberTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Membership', icon: Icons.card_membership_outlined),
  (label: 'Schedule', icon: Icons.calendar_today_outlined),
  ..._sharedTabs,
];

const _trainerTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Classes', icon: Icons.fitness_center_outlined),
  (label: 'Members', icon: Icons.people_outline),
  ..._sharedTabs,
];

const _employeeTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Members', icon: Icons.people_outline),
  (label: 'Schedule', icon: Icons.schedule_outlined),
  ..._sharedTabs,
];

const _employeeTrainerTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Members', icon: Icons.people_outline),
  (label: 'Classes', icon: Icons.sports_gymnastics_outlined),
  (label: 'Schedule', icon: Icons.schedule_outlined),
  ..._sharedTabs,
];

const _vendorTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'My Shop', icon: Icons.storefront_outlined),
  ..._sharedTabs,
];

const _superUserTabs = <_Tab>[
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Businesses', icon: Icons.business_outlined),
  (label: 'Users', icon: Icons.manage_accounts_outlined),
  ..._sharedTabs,
];

List<_Tab> _tabsForRole(UserRole role) => switch (role) {
      UserRole.owner => _ownerTabs,
      UserRole.member => _memberTabs,
      UserRole.trainer => _trainerTabs,
      UserRole.employee => _employeeTabs,
      UserRole.employeeTrainer => _employeeTrainerTabs,
      UserRole.shopVendor => _vendorTabs,
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
  final _api = ApiService();

  int _tabIndex = 0;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  int _unreadNotifications = 0;

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
      _refreshUnreadCount(cached.id);
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
        _refreshUnreadCount(fresh.id);
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

  Future<void> _refreshUnreadCount(String userId) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final page = await _api.getNotifications(
        token,
        userId: userId,
        page: 0,
        pageSize: 1,
      );
      if (mounted) setState(() => _unreadNotifications = page.unreadCount);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
    // Refresh badge when returning from notifications
    final profile = _profile;
    if (profile != null && mounted) _refreshUnreadCount(profile.id);
  }

  Future<void> _logout() async {
    await AuthManager.instance.logout();
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
    // The role (and so the tab count) can change after a profile refresh.
    if (_tabIndex >= tabs.length) _tabIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_tabIndex].label),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: _openNotifications,
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _unreadNotifications > 99
                            ? '99+'
                            : '$_unreadNotifications',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
        // Icon-only look; labels are still exposed to screen readers.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              label: tab.label,
              tooltip: tab.label,
            ),
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
        UserRole.shopVendor => VendorHomePage(profile: profile),
        UserRole.superUser => SuperUserHomePage(profile: profile),
      };
    }

    // Shop vendor "My Shop" tab.
    if (profile.role == UserRole.shopVendor) {
      if (index == 1) return VendorShopPage(profile: profile);
    }

    // Owner / super-user Businesses tab.
    if (profile.role == UserRole.owner || profile.role == UserRole.superUser) {
      if (index == 1) return const OwnerBusinessesPage();
    }

    // Super-user Users tab.
    if (profile.role == UserRole.superUser) {
      if (index == 2) return const OwnerUsersPage();
    }

    // Employee / employee-trainer Members tab (index 1 for both roles).
    if (profile.role == UserRole.employee ||
        profile.role == UserRole.employeeTrainer) {
      if (index == 1) return EmployeeMembersPage(profile: profile);
    }

    // Member Membership + Schedule (their own sessions).
    if (profile.role == UserRole.member) {
      if (index == 1) return MembershipPage(profile: profile);
      if (index == 2) return const SessionsPage();
    }

    // Employee Schedule (their own logged sessions, if any).
    if (profile.role == UserRole.employee) {
      if (index == 2) return const SessionsPage();
    }

    // Trainer Classes (sessions they run for members) + Members they coach.
    if (profile.role == UserRole.trainer) {
      if (index == 1) return SessionsPage(asTrainerId: profile.id);
      if (index == 2) return TrainerMembersPage(profile: profile);
    }

    // Employee-trainer Classes + Schedule.
    if (profile.role == UserRole.employeeTrainer) {
      if (index == 2) return SessionsPage(asTrainerId: profile.id);
      if (index == 3) return const SessionsPage();
    }

    // Shared gym tab — always the second-to-last entry in every role's list.
    final tabs = _tabsForRole(profile.role);
    final tabCount = tabs.length;
    if (index == tabCount - 2) return GymHubPage(profile: profile);

    // Shared Profile tab — always the last entry in every role's list.
    if (index == tabCount - 1) {
      return ProfilePage(
        profile: profile,
        onUpdated: (updated) => setState(() => _profile = updated),
      );
    }

    // Every role's tabs are handled above.
    return const SizedBox.shrink();
  }
}
