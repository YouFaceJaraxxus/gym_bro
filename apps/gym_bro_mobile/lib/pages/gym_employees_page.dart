import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'add_gym_employee_page.dart';
import 'edit_gym_employee_page.dart';

enum _StaffType { employee, employeeTrainer }

class _StaffEntry {
  final String staffId;
  final _StaffType type;
  final UserProfile user;

  const _StaffEntry(
      {required this.staffId, required this.type, required this.user});
}

class GymEmployeesPage extends StatefulWidget {
  const GymEmployeesPage(
      {super.key, required this.gymId, required this.gymName});

  final String gymId;
  final String gymName;

  @override
  State<GymEmployeesPage> createState() => _GymEmployeesPageState();
}

class _GymEmployeesPageState extends State<GymEmployeesPage> {
  final _api = ApiService();

  List<_StaffEntry> _staff = [];
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
      final results = await Future.wait([
        _api.getEmployees(token, gymId: widget.gymId),
        _api.getEmployeeTrainers(token, gymId: widget.gymId),
      ]);
      final employeeRows = results[0];
      final trainerRows = results[1];

      if (mounted) {
        setState(() {
          _staff = [
            ...employeeRows.map((r) => _StaffEntry(
                  staffId: r['id'] as String,
                  type: _StaffType.employee,
                  user: UserProfile.fromJson(r),
                )),
            ...trainerRows.map((r) => _StaffEntry(
                  staffId: r['id'] as String,
                  type: _StaffType.employeeTrainer,
                  user: UserProfile.fromJson(r),
                )),
          ];
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

  Future<void> _resendInvite(_StaffEntry entry) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.resendInvite(token, entry.user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.businessGymInviteResent)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _removeStaff(_StaffEntry entry) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.businessGymRemoveStaffTitle),
        content: Text(l10n.businessGymRemoveStaffMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.businessGymRemove)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      if (entry.type == _StaffType.employee) {
        await _api.removeEmployee(token, entry.staffId);
      } else {
        await _api.removeEmployeeTrainer(token, entry.staffId);
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _openEdit(_StaffEntry entry) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditGymEmployeePage(
          staffId: entry.staffId,
          staffType: entry.type == _StaffType.employeeTrainer
              ? 'employee_trainer'
              : 'employee',
          user: entry.user,
          gymName: widget.gymName,
          gymId: widget.gymId,
        ),
      ),
    );
    if (result == 'removed' || result == 'changed') _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(context.l10n.businessGymStaffTitle(widget.gymName))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddGymEmployeePage(gymId: widget.gymId),
            ),
          );
          if (added == true) _load();
        },
        icon: const Icon(Icons.person_add_outlined),
        label: Text(context.l10n.businessGymAddEmployee),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(_error!),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _load, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }

  Widget _buildList() {
    final l10n = context.l10n;
    if (_staff.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.badge_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(context.l10n.businessGymNoStaffYet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
        itemCount: _staff.length,
        itemBuilder: (_, i) {
          final entry = _staff[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _openEdit(entry),
              leading: CircleAvatar(
                child: Text(entry.user.name.isNotEmpty
                    ? entry.user.name[0].toUpperCase()
                    : '?'),
              ),
              title: Text(entry.user.fullName),
              subtitle: Text(
                '${entry.user.email}  ·  ${entry.type == _StaffType.employeeTrainer ? l10n.businessGymRoleEmployeeTrainerShort : l10n.businessGymRoleEmployee}',
              ),
              trailing: PopupMenuButton<_EmployeeAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: l10n.businessGymEmployeeActions,
                onSelected: (action) {
                  switch (action) {
                    case _EmployeeAction.edit:
                      _openEdit(entry);
                    case _EmployeeAction.resendInvite:
                      _resendInvite(entry);
                    case _EmployeeAction.remove:
                      _removeStaff(entry);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _EmployeeAction.edit,
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l10n.businessGymEditEmployee),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _EmployeeAction.resendInvite,
                    child: ListTile(
                      leading: const Icon(Icons.mark_email_unread_outlined),
                      title: Text(l10n.businessGymResendInvite),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _EmployeeAction.remove,
                    child: ListTile(
                      leading: const Icon(Icons.person_remove_outlined),
                      title: Text(l10n.businessGymRemove),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _EmployeeAction { edit, resendInvite, remove }
