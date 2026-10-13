import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/staff_shift.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'schedule_widgets.dart';

/// Add or edit a staff shift at one gym (managers only). Pops `true` when the
/// shift was saved or deleted.
class ShiftFormPage extends StatefulWidget {
  const ShiftFormPage({
    super.key,
    required this.gymId,
    required this.gymName,
    required this.staff,
    this.existing,
    this.initialDate,
  });

  final String gymId;
  final String gymName;
  final List<ShiftStaffMember> staff;
  final StaffShift? existing;
  final DateTime? initialDate;

  @override
  State<ShiftFormPage> createState() => _ShiftFormPageState();
}

class _ShiftFormPageState extends State<ShiftFormPage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();

  String? _userId;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _userId = e.userId;
      _date = dateOnly(e.startsAt);
      _start = TimeOfDay.fromDateTime(e.startsAt);
      _end = TimeOfDay.fromDateTime(e.endsAt);
      _note.text = e.note ?? '';
    } else {
      final today = dateOnly(DateTime.now());
      final initial = widget.initialDate;
      _date = initial != null && !dateOnly(initial).isBefore(today)
          ? dateOnly(initial)
          : today;
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 17, minute: 0);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _startsAt =>
      DateTime(_date.year, _date.month, _date.day, _start.hour, _start.minute);

  /// An end time at or before the start means the shift runs past midnight.
  DateTime get _endsAt {
    var end = DateTime(_date.year, _date.month, _date.day, _end.hour, _end.minute);
    if (!end.isAfter(_startsAt)) end = end.add(const Duration(days: 1));
    return end;
  }

  bool get _overnight => !sameDay(_startsAt, _endsAt);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = dateOnly(now).subtract(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: _date.isBefore(first) ? _date : first,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t != null) setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t != null) setState(() => _end = t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final data = <String, dynamic>{
        'user_id': _userId,
        'starts_at': _startsAt.toUtc().toIso8601String(),
        'ends_at': _endsAt.toUtc().toIso8601String(),
        'note': _note.text.trim(),
      };
      if (_isEdit) {
        await _api.updateShift(token, widget.existing!.id, data);
        messenger.showSnackBar(SnackBar(content: Text(l10n.trainingShiftUpdated)));
      } else {
        data['gym_id'] = widget.gymId;
        await _api.createShift(token, data);
        messenger.showSnackBar(SnackBar(content: Text(l10n.trainingShiftAdded)));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.trainingShiftDeleteQuestion,
      message: l10n.trainingShiftDeleteNotifyMessage(
          e.fullName, formatDayLabel(context, e.startsAt)),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteShift(token, e.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.trainingShiftDeleted)));
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(err))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final staff = [...widget.staff];
    final e = widget.existing;
    if (e != null && !staff.any((s) => s.userId == e.userId)) {
      staff.add(ShiftStaffMember(
          userId: e.userId, name: e.name, lastName: e.lastName, roles: const []));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.trainingShiftEdit : l10n.trainingShiftNew),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l10n.trainingShiftDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: staff.isEmpty
          ? ScheduleEmpty(
              icon: Icons.badge_outlined,
              title: l10n.trainingShiftNoStaff,
              message: l10n.trainingShiftNoStaffMessage,
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fitness_center),
                    title: Text(widget.gymName),
                    subtitle: Text(l10n.trainingClassGym),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _userId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.trainingShiftStaffMember,
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    items: [
                      for (final s in staff)
                        DropdownMenuItem(
                          value: s.userId,
                          child: Text(
                            s.roles.isEmpty
                                ? s.fullName
                                : '${s.fullName} · ${s.roleLabel(l10n)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (v) => v == null ? l10n.trainingShiftPickStaff : null,
                    onChanged: (v) => setState(() => _userId = v),
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.trainingClassWhen, style: ts.titleSmall),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(DateFormat.yMMMMEEEEd(localeOf(context)).format(_date)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickStart,
                          icon: const Icon(Icons.login, size: 18),
                          label: Text(l10n.trainingShiftStart(_start.format(context))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickEnd,
                          icon: const Icon(Icons.logout, size: 18),
                          label: Text(l10n.trainingShiftEnd(_end.format(context))),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _overnight
                          ? l10n.trainingShiftEndsNextDay(
                              formatDuration(context, _endsAt.difference(_startsAt)))
                          : formatDuration(context, _endsAt.difference(_startsAt)),
                      style: ts.bodySmall?.copyWith(
                          color: _overnight ? cs.tertiary : cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: l10n.trainingShiftNoteOptional,
                      hintText: l10n.trainingShiftNoteHint,
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? l10n.trainingClassSaveChanges : l10n.trainingShiftAdd),
                  ),
                ],
              ),
            ),
    );
  }
}
