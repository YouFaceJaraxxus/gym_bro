import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/gym_class.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'schedule_widgets.dart';

/// Create a class (optionally a weekly series) or edit an existing one.
/// Pops `true` when saved.
class ClassFormPage extends StatefulWidget {
  const ClassFormPage({super.key, this.existing, this.initialGymId});

  final GymClass? existing;

  /// Preselects this gym when creating (e.g. from a gym's schedule).
  final String? initialGymId;

  @override
  State<ClassFormPage> createState() => _ClassFormPageState();
}

class _ClassFormPageState extends State<ClassFormPage> {
  static const _durations = [30, 45, 60, 75, 90, 120];

  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _capacity = TextEditingController(text: '12');

  List<CoachingGym> _gyms = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  String? _gymId;
  String? _trainerId;
  late DateTime _date;
  late TimeOfDay _start;
  int _durationMinutes = 60;
  bool _repeat = false;
  int _weeks = 4;
  bool _applyToSeries = false;

  bool get _isEdit => widget.existing != null;
  String get _myId => AuthManager.instance.profile?.id ?? '';

  CoachingGym? get _gym {
    for (final g in _gyms) {
      if (g.gymId == _gymId) return g;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description ?? '';
      _location.text = e.location ?? '';
      _capacity.text = '${e.capacity}';
      _gymId = e.gymId;
      _trainerId = e.trainerId;
      _date = dateOnly(e.startsAt);
      _start = TimeOfDay.fromDateTime(e.startsAt);
      _durationMinutes = e.duration.inMinutes;
    } else {
      final soon = DateTime.now().add(const Duration(hours: 1));
      _date = dateOnly(soon);
      _start = TimeOfDay(hour: soon.hour, minute: 0);
      _gymId = widget.initialGymId;
    }
    _loadGyms();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _loadGyms() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final gyms = await _api.getCoachingGyms(token);
      if (!mounted) return;
      setState(() {
        _gyms = gyms;
        _loading = false;
        if (!_isEdit) {
          if (_gym == null && gyms.isNotEmpty) _gymId = gyms.first.gymId;
          _defaultTrainer();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  /// When creating: the caller teaches by default if they're a trainer there.
  void _defaultTrainer() {
    final g = _gym;
    if (g == null) return;
    _trainerId =
        g.trainers.any((t) => t.userId == _myId) ? _myId : null;
  }

  DateTime get _startsAt =>
      DateTime(_date.year, _date.month, _date.day, _start.hour, _start.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _isEdit && _date.isBefore(now) ? _date : dateOnly(now),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final gym = _gym;
    if (gym == null) return;
    final startsAt = _startsAt;
    final endsAt = startsAt.add(Duration(minutes: _durationMinutes));
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (!_isEdit && !startsAt.isAfter(DateTime.now())) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.trainingClassStartInFuture)));
      return;
    }

    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final data = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'location': _location.text.trim(),
        'capacity': int.parse(_capacity.text.trim()),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
      };
      if (_isEdit) {
        final e = widget.existing!;
        if (_trainerId != e.trainerId) data['trainer_id'] = _trainerId;
        if (e.isSeries) data['apply_to_series'] = _applyToSeries;
        await _api.updateClass(token, e.id, data);
        messenger.showSnackBar(SnackBar(content: Text(l10n.trainingClassUpdated)));
      } else {
        data['gym_id'] = gym.gymId;
        if (_trainerId != null) data['trainer_id'] = _trainerId;
        data['repeat_weeks'] = _repeat ? _weeks : 1;
        final created = await _api.createClass(token, data);
        messenger.showSnackBar(SnackBar(
          content: Text(created.length > 1
              ? l10n.trainingClassWeeklyCreated(created.length)
              : l10n.trainingClassCreated),
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.trainingClassEdit : l10n.trainingClassNew),
        actions: [
          if (!_loading && _error == null && _gyms.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.commonSave),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ScheduleError(message: _error!, onRetry: _loadGyms);
    if (_gyms.isEmpty || (_isEdit && _gym == null)) {
      return ScheduleEmpty(
        icon: Icons.sports_gymnastics,
        title: context.l10n.trainingClassNoGyms,
        message: context.l10n.trainingClassNoGymsMessage,
      );
    }

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = localeOf(context);
    final gym = _gym!;
    final durations = {..._durations, _durationMinutes}.toList()..sort();
    final endsAt = _startsAt.add(Duration(minutes: _durationMinutes));

    // Trainer options: staff pick anyone; plain trainers teach their own.
    final trainerOptions = <ClassTrainer>[...gym.trainers];
    final e = widget.existing;
    if (_trainerId != null && !trainerOptions.any((t) => t.userId == _trainerId)) {
      trainerOptions.add(ClassTrainer(
        userId: _trainerId!,
        name: e?.trainerId == _trainerId
            ? (e?.trainerName ?? l10n.trainingClassCurrentTrainer)
            : l10n.trainingClassCurrentTrainer,
        lastName: '',
      ));
    }
    final canPickTrainer = gym.canStaff;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_isEdit)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fitness_center),
              title: Text(gym.gymName),
              subtitle: Text(l10n.trainingClassGym),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _gymId,
              decoration: InputDecoration(
                labelText: l10n.trainingClassGym,
                prefixIcon: const Icon(Icons.fitness_center),
              ),
              items: [
                for (final g in _gyms)
                  DropdownMenuItem(value: g.gymId, child: Text(g.gymName)),
              ],
              onChanged: (v) => setState(() {
                _gymId = v;
                _defaultTrainer();
              }),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.trainingClassTitleLabel,
              hintText: l10n.trainingClassTitleHint,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.trainingClassTitleRequired
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.trainingClassDescriptionOptional,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _location,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.trainingClassLocationOptional,
              hintText: l10n.trainingClassLocationHint,
              prefixIcon: const Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.trainingClassWhen, style: ts.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(DateFormat.yMMMEd(locale).format(_date)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_start.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _durationMinutes,
            decoration: InputDecoration(
              labelText: l10n.trainingClassDuration,
              prefixIcon: const Icon(Icons.timelapse),
            ),
            items: [
              for (final d in durations)
                DropdownMenuItem(
                    value: d,
                    child: Text(formatDuration(context, Duration(minutes: d)))),
            ],
            onChanged: (v) => setState(() => _durationMinutes = v ?? 60),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              l10n.trainingClassEndsAt(formatTime(context, endsAt)),
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.trainingClassCapacity,
              helperText: l10n.trainingClassCapacityHelper,
              prefixIcon: const Icon(Icons.group_outlined),
            ),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              if (n == null || n < 1) return l10n.trainingClassCapacityMin;
              if (n > 500) return l10n.trainingClassCapacityMax;
              final booked = widget.existing?.bookedCount ?? 0;
              if (n < booked) return l10n.trainingClassCapacityBelowBooked(booked);
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (canPickTrainer)
            DropdownButtonFormField<String?>(
              key: ValueKey('trainer-$_gymId'),
              initialValue: _trainerId,
              decoration: InputDecoration(
                labelText: l10n.trainingStaffRoleTrainer,
                prefixIcon: const Icon(Icons.sports),
              ),
              items: [
                DropdownMenuItem<String?>(
                    value: null, child: Text(l10n.trainingClassNoTrainer)),
                for (final t in trainerOptions)
                  DropdownMenuItem<String?>(
                    value: t.userId,
                    child: Text(t.userId == _myId
                        ? l10n.trainingClassNameYou(t.fullName)
                        : t.fullName),
                  ),
              ],
              onChanged: (v) => setState(() => _trainerId = v),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sports),
              title: Text(_trainerId == _myId
                  ? l10n.trainingClassYou
                  : (trainerOptions
                          .where((t) => t.userId == _trainerId)
                          .firstOrNull
                          ?.fullName ??
                      l10n.trainingClassNoTrainer)),
              subtitle: Text(l10n.trainingStaffRoleTrainer),
            ),
          if (!_isEdit) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.trainingClassRepeatWeekly),
              subtitle: Text(_repeat
                  ? l10n.trainingClassRepeatSummary(
                      DateFormat.EEEE(locale).format(_date), _weeks)
                  : l10n.trainingClassOneOff),
              value: _repeat,
              onChanged: (v) => setState(() => _repeat = v),
            ),
            if (_repeat)
              Row(
                children: [
                  const SizedBox(width: 4),
                  Text(l10n.trainingClassWeeks, style: ts.bodyMedium),
                  Expanded(
                    child: Slider(
                      value: _weeks.toDouble(),
                      min: 2,
                      max: 12,
                      divisions: 10,
                      label: '$_weeks',
                      semanticFormatterCallback: (v) =>
                          l10n.trainingClassWeeksValue(v.round()),
                      onChanged: (v) => setState(() => _weeks = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('$_weeks', textAlign: TextAlign.end),
                  ),
                ],
              ),
          ],
          if (_isEdit && widget.existing!.isSeries) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.trainingClassApplyToSeries),
              subtitle: Text(_applyToSeries
                  ? l10n.trainingClassApplyToSeriesOn
                  : l10n.trainingClassApplyToSeriesOff),
              value: _applyToSeries,
              onChanged: (v) => setState(() => _applyToSeries = v),
            ),
          ],
          if (_isEdit && widget.existing!.bookedCount + widget.existing!.waitlistCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.trainingClassNotifyOnChange,
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? l10n.trainingClassSaveChanges : l10n.trainingClassCreate),
          ),
        ],
      ),
    );
  }
}
