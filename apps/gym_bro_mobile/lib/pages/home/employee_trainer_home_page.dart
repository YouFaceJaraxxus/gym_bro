import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/user_profile.dart';
import '../../widgets/my_shifts_card.dart';
import 'employee_home_page.dart';
import 'home_widgets.dart';
import 'trainer_today_section.dart';

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
            title: context.l10n.shellWelcome(widget.profile.name),
            subtitle: widget.profile.role.label(context.l10n),
          ),
          MyShiftsCard(key: ValueKey('shifts-$_refreshTick')),
          const SizedBox(height: 8),
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
