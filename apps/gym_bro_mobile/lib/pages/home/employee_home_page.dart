import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/my_shifts_card.dart';
import '../checkin/check_in_scanner_page.dart';
import '../gym_members_page.dart';
import '../invoices_page.dart';
import 'home_widgets.dart';

class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
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
            title: context.l10n.shellHello(widget.profile.name),
            subtitle: widget.profile.role.label(context.l10n),
          ),
          MyShiftsCard(key: ValueKey('shifts-$_refreshTick')),
          const SizedBox(height: 8),
          StaffGymsSection(
            key: ValueKey('gyms-$_refreshTick'),
            profile: widget.profile,
          ),
        ],
      ),
    );
  }
}

/// The gyms the user works at (as employee or employee-trainer) with member
/// counts and quick actions. Re-create with a new key to reload.
class StaffGymsSection extends StatefulWidget {
  const StaffGymsSection({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<StaffGymsSection> createState() => _StaffGymsSectionState();
}

class _StaffGymsSectionState extends State<StaffGymsSection> {
  final _api = ApiService();
  List<({Business gym, int memberCount})> _gyms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await Future.wait([
        _api.getEmployees(token, userId: widget.profile.id),
        _api.getEmployeeTrainers(token, userId: widget.profile.id),
      ]);
      final ids = {
        for (final list in rows)
          for (final r in list) r['gym_id'] as String,
      }.toList();
      final results = await Future.wait([
        Future.wait(ids.map((id) => _api.getBusiness(token, id))),
        Future.wait(ids.map((id) => _api.getMembers(token, gymId: id))),
      ]);
      final gyms = results[0] as List<Business>;
      final members = results[1] as List<List<Map<String, dynamic>>>;
      final entries = [
        for (var i = 0; i < ids.length; i++)
          (gym: gyms[i], memberCount: members[i].length),
      ]..sort((a, b) => a.gym.name.compareTo(b.gym.name));
      if (mounted) {
        setState(() {
          _gyms = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: HomeError(message: _error!, onRetry: _load),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          _gyms.length == 1
              ? context.l10n.shellYourGym
              : context.l10n.shellYourGyms,
        ),
        if (_gyms.isEmpty)
          HomeEmpty(
            icon: Icons.fitness_center_outlined,
            label: context.l10n.shellNotAssignedToGym,
          )
        else
          for (final entry in _gyms)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            child: Icon(
                              Icons.fitness_center,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.gym.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                context.l10n.shellMemberCount(
                                  entry.memberCount,
                                ),
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GymMembersPage(
                                    gymId: entry.gym.id,
                                    gymName: entry.gym.name,
                                  ),
                                ),
                              );
                              _load();
                            },
                            icon: const Icon(Icons.people_outline, size: 18),
                            label: Text(context.l10n.shellTabMembers),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoicesPage(
                                  gymId: entry.gym.id,
                                  gymName: entry.gym.name,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                            ),
                            label: Text(context.l10n.shellInvoices),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CheckInScannerPage(
                              gymId: entry.gym.id,
                              gymName: entry.gym.name,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: Text(context.l10n.shellScanCheckIns),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
