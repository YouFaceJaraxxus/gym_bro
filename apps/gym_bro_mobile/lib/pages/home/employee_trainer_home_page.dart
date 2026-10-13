import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import 'employee_home_page.dart';
import 'home_widgets.dart';
import 'trainer_home_page.dart';

/// Employee-trainer home: today's coaching sessions plus the gyms they staff.
class EmployeeTrainerHomePage extends StatefulWidget {
  const EmployeeTrainerHomePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EmployeeTrainerHomePage> createState() =>
      _EmployeeTrainerHomePageState();
}

class _EmployeeTrainerHomePageState extends State<EmployeeTrainerHomePage> {
  int _refreshTick = 0;

  Future<void> _refresh() async => setState(() => _refreshTick++);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          HomeHeader(
            title: 'Welcome, ${widget.profile.name}',
            subtitle: widget.profile.role.displayName,
          ),
          TrainerTodaySection(
            key: ValueKey('trainer-$_refreshTick'),
            profile: widget.profile,
          ),
          StaffGymsSection(
            key: ValueKey('gyms-$_refreshTick'),
            profile: widget.profile,
          ),
        ],
      ),
    );
  }
}
