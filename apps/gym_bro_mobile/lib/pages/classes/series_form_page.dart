import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/class_series.dart';
import '../../models/gym_class.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'schedule_widgets.dart';
import 'series_format.dart';

/// Create a class with its timetable, or edit one. Pops `true` when saved.
class SeriesFormPage extends StatefulWidget {
  const SeriesFormPage({super.key, this.existing, this.initialGymId});

  final ClassSeries? existing;

  /// Preselects this gym when creating (e.g. from a gym's schedule).
  final String? initialGymId;

  @override
  State<SeriesFormPage> createState() => _SeriesFormPageState();
}

class _SeriesFormPageState extends State<SeriesFormPage> {
  static const _maxTimes = 12;

  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _capacity = TextEditingController(text: '12');
  final _duration = TextEditingController(text: '60');

  List<CoachingGym> _gyms = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _triedSave = false;

  String? _gymId;
  String? _trainerId;
  ClassRepeat _repeat = ClassRepeat.weekly;
  final Set<int> _weekdays = {};

  /// Start times as minutes after midnight.
  final Set<int> _times = {};
  late DateTime _startsOn;
  DateTime? _endsOn;
  String _timezone = 'UTC';

  ClassSeries? get _existing => widget.existing;
  bool get _isEdit => _existing != null;
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
    final e = _existing;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description ?? '';
      _location.text = e.location ?? '';
      _capacity.text = '${e.capacity}';
      _duration.text = '${e.durationMinutes}';
      _gymId = e.gymId;
      _trainerId = e.trainerId;
      _repeat = e.repeat;
      _weekdays.addAll(e.weekdays);
      _times.addAll(e.times.map(_parseTime));
      _startsOn = dateOnly(e.startsOn);
      _endsOn = e.repeat == ClassRepeat.none ? null : e.endsOn;
      _timezone = e.timezone;
    } else {
      final now = DateTime.now();
      _startsOn = dateOnly(now);
      _weekdays.add(now.weekday);
      _times.add(((now.hour + 1) % 24) * 60);
      _gymId = widget.initialGymId;
      _loadTimezone();
    }
    _loadGyms();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _loadTimezone() async {
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      if (mounted) setState(() => _timezone = tz.identifier);
    } catch (_) {
      // Stays UTC; shown under the times so it's never a surprise.
    }
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
    _trainerId = g.trainers.any((t) => t.userId == _myId) ? _myId : null;
  }

  static int _parseTime(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 +
        (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  String _formatTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  List<int> get _sortedTimes => _times.toList()..sort();
  List<int> get _sortedWeekdays => _weekdays.toList()..sort();

  Future<void> _addTime() async {
    final last = _times.isEmpty
        ? 18 * 60
        : (_sortedTimes.last + 60) % (24 * 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: last ~/ 60, minute: last % 60),
    );
    if (picked != null) {
      setState(() => _times.add(picked.hour * 60 + picked.minute));
    }
  }

  Future<void> _pickDate({required bool end}) async {
    final today = dateOnly(DateTime.now());
    final current = end
        ? (_endsOn ?? _startsOn.add(const Duration(days: 28)))
        : _startsOn;
    final first = end
        ? _startsOn
        : (_isEdit && _startsOn.isBefore(today) ? _startsOn : today);
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first) ? first : current,
      firstDate: first,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _endsOn = picked;
      } else {
        _startsOn = picked;
        if (_endsOn != null && _endsOn!.isBefore(picked)) _endsOn = picked;
      }
    });
  }

  /// Problems the fields' own validators can't show.
  String? _timetableProblem() {
    final l10n = context.l10n;
    if (_repeat == ClassRepeat.weekly && _weekdays.isEmpty) {
      return l10n.classSeriesPickWeekday;
    }
    if (_times.isEmpty) return l10n.classSeriesTimesRequired;
    if (_times.length > _maxTimes) return l10n.classSeriesTimesMax;
    if (_repeat != ClassRepeat.none &&
        _endsOn != null &&
        _endsOn!.isBefore(_startsOn)) {
      return l10n.classSeriesEndBeforeStart;
    }
    return null;
  }

  /// Everything the API takes, as it stands in the form.
  Map<String, dynamic> _fields() => {
    'title': _title.text.trim(),
    'description': _description.text.trim(),
    'location': _location.text.trim(),
    'capacity': int.parse(_capacity.text.trim()),
    'duration_minutes': int.parse(_duration.text.trim()),
    'repeat': _repeat.name,
    'weekdays': _repeat == ClassRepeat.weekly ? _sortedWeekdays : <int>[],
    'times': _sortedTimes.map(_hhmm).toList(),
    'starts_on': ymd(_startsOn),
    'ends_on': _repeat == ClassRepeat.none || _endsOn == null
        ? null
        : ymd(_endsOn!),
    'trainer_id': _trainerId,
  };

  /// Only what differs from the class being edited.
  Map<String, dynamic> _changes(ClassSeries e) {
    final f = _fields();
    bool sameList(List a, List b) =>
        a.length == b.length &&
        List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);
    final oldTimes = (e.times.map(_parseTime).toList()..sort())
        .map(_hhmm)
        .toList();
    return {
      if (f['title'] != e.title) 'title': f['title'],
      if (f['description'] != (e.description ?? ''))
        'description': f['description'],
      if (f['location'] != (e.location ?? '')) 'location': f['location'],
      if (f['capacity'] != e.capacity) 'capacity': f['capacity'],
      if (f['duration_minutes'] != e.durationMinutes)
        'duration_minutes': f['duration_minutes'],
      if (_repeat != e.repeat) 'repeat': f['repeat'],
      if (_repeat == ClassRepeat.weekly &&
          (_repeat != e.repeat ||
              !sameList(_sortedWeekdays, [...e.weekdays]..sort())))
        'weekdays': f['weekdays'],
      if (!sameList(f['times'] as List, oldTimes)) 'times': f['times'],
      if (!sameDay(_startsOn, e.startsOn)) 'starts_on': f['starts_on'],
      if (_repeat != ClassRepeat.none &&
          f['ends_on'] != (e.endsOn == null ? null : ymd(e.endsOn!)))
        'ends_on': f['ends_on'],
      if (_trainerId != e.trainerId) 'trainer_id': _trainerId,
    };
  }

  Future<void> _save() async {
    setState(() => _triedSave = true);
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _timetableProblem() != null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final e = _existing;

    Map<String, dynamic> body;
    if (e == null) {
      final gym = _gym;
      if (gym == null) return;
      body = {..._fields(), 'gym_id': gym.gymId, 'timezone': _timezone};
      // Without trainer_id the API makes a trainer creator the trainer;
      // staff choosing "No trainer" send null on purpose.
      if (_trainerId == null && !gym.canStaff) body.remove('trainer_id');
      if (body['ends_on'] == null) body.remove('ends_on');
    } else {
      body = _changes(e);
      if (body.isEmpty) {
        Navigator.pop(context, false);
        return;
      }
      const timetableKeys = {
        'repeat',
        'weekdays',
        'times',
        'starts_on',
        'ends_on',
      };
      final retimes = body.keys.any(timetableKeys.contains);
      if (retimes && e.active && (e.upcomingCount > 0 || e.enrolledCount > 0)) {
        final ok = await confirmDialog(
          context,
          title: l10n.classSeriesTimetableChangeTitle,
          message: l10n.classSeriesTimetableChangeMessage,
          confirmLabel: l10n.classSeriesTimetableChangeConfirm,
        );
        if (!ok || !mounted) return;
      }
    }

    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      if (e == null) {
        await _api.createClassSeries(token, body);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.classSeriesCreated)),
        );
      } else {
        await _api.updateClassSeries(token, e.id, body);
        messenger.showSnackBar(SnackBar(content: Text(l10n.classSeriesSaved)));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(err))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = !_loading && _error == null && (_isEdit || _gyms.isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.classSeriesEdit : l10n.classSeriesNew),
        actions: [
          if (ready)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.classSeriesSave),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
      );
    }
    if (_error != null) {
      return ScheduleError(message: _error!, onRetry: _loadGyms);
    }
    if (!_isEdit && _gyms.isEmpty) {
      return ScheduleEmpty(
        icon: Icons.fitness_center,
        title: l10n.classSeriesNoGyms,
        message: l10n.classSeriesNoGymsMessage,
      );
    }

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final locale = localeOf(context);
    final gym = _gym;
    final problem = _triedSave ? _timetableProblem() : null;
    final errorStyle = ts.bodySmall?.copyWith(color: cs.error);
    final muted = ts.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    // Staff pick any trainer at the gym; a trainer teaches their own classes.
    final trainers = <ClassTrainer>[...?gym?.trainers];
    final e = _existing;
    if (_trainerId != null && !trainers.any((t) => t.userId == _trainerId)) {
      trainers.add(
        ClassTrainer(
          userId: _trainerId!,
          name: e?.trainerId == _trainerId ? (e?.trainerName ?? '') : '',
          lastName: '',
        ),
      );
    }
    String trainerName(String? id) {
      if (id == null) return l10n.classSeriesNoTrainer;
      final t = trainers.where((t) => t.userId == id).firstOrNull;
      final name = t?.fullName ?? '';
      if (id == _myId) {
        return name.isEmpty
            ? l10n.classSeriesYou
            : l10n.classSeriesNameYou(name);
      }
      return name.isEmpty ? l10n.classSeriesTrainer : name;
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_isEdit)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fitness_center),
              title: Text(gym?.gymName ?? e!.gymName),
              subtitle: Text(l10n.classSeriesGym),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _gymId,
              decoration: InputDecoration(
                labelText: l10n.classSeriesGym,
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
            maxLength: 120,
            decoration: InputDecoration(
              labelText: l10n.classSeriesTitle,
              hintText: l10n.classSeriesTitleHint,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.classSeriesTitleRequired
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.classSeriesDescription,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _location,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.classSeriesLocation,
              hintText: l10n.classSeriesLocationHint,
              prefixIcon: const Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.classSeriesCapacity,
                    prefixIcon: const Icon(Icons.group_outlined),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return n == null || n < 1 || n > 1000
                        ? l10n.classSeriesCapacityInvalid
                        : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.classSeriesDuration,
                    prefixIcon: const Icon(Icons.timelapse),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return n == null || n < 5 || n > 1440
                        ? l10n.classSeriesDurationInvalid
                        : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (gym != null && gym.canStaff)
            DropdownButtonFormField<String?>(
              key: ValueKey('trainer-$_gymId'),
              initialValue: _trainerId,
              decoration: InputDecoration(
                labelText: l10n.classSeriesTrainer,
                prefixIcon: const Icon(Icons.sports),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.classSeriesNoTrainer),
                ),
                for (final t in trainers)
                  DropdownMenuItem<String?>(
                    value: t.userId,
                    child: Text(trainerName(t.userId)),
                  ),
              ],
              onChanged: (v) => setState(() => _trainerId = v),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sports),
              title: Text(trainerName(_trainerId)),
              subtitle: Text(l10n.classSeriesTrainer),
            ),
          const SizedBox(height: 20),
          Text(l10n.classSeriesRepeat, style: ts.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ClassRepeat>(
            segments: [
              ButtonSegment(
                value: ClassRepeat.none,
                label: Text(l10n.classSeriesRepeatOnce),
              ),
              ButtonSegment(
                value: ClassRepeat.daily,
                label: Text(l10n.classSeriesRepeatDaily),
              ),
              ButtonSegment(
                value: ClassRepeat.weekly,
                label: Text(l10n.classSeriesRepeatWeekly),
              ),
            ],
            selected: {_repeat},
            onSelectionChanged: (s) => setState(() {
              _repeat = s.first;
              if (_repeat == ClassRepeat.weekly && _weekdays.isEmpty) {
                _weekdays.add(_startsOn.weekday);
              }
            }),
          ),
          if (_repeat == ClassRepeat.weekly) ...[
            const SizedBox(height: 16),
            Text(l10n.classSeriesWeekdays, style: ts.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(weekdayShort(context, d)),
                    selected: _weekdays.contains(d),
                    onSelected: (on) => setState(
                      () => on ? _weekdays.add(d) : _weekdays.remove(d),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(l10n.classSeriesTimes, style: ts.titleSmall),
          Text(l10n.classSeriesTimesHint, style: muted),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final t in _sortedTimes)
                InputChip(
                  label: Text(_formatTime(t)),
                  onDeleted: () => setState(() => _times.remove(t)),
                  deleteButtonTooltipMessage: l10n.classSeriesRemoveTime(
                    _formatTime(t),
                  ),
                ),
              if (_times.length < _maxTimes)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.classSeriesAddTime),
                  onPressed: _addTime,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.classSeriesTimezone(_timezone), style: muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: _repeat == ClassRepeat.none
                      ? l10n.classSeriesDate
                      : l10n.classSeriesStarts,
                  value: DateFormat.yMMMEd(locale).format(_startsOn),
                  onTap: () => _pickDate(end: false),
                ),
              ),
              if (_repeat != ClassRepeat.none) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: l10n.classSeriesEnds,
                    value: _endsOn == null
                        ? l10n.classSeriesNoEndDate
                        : DateFormat.yMMMEd(locale).format(_endsOn!),
                    onTap: () => _pickDate(end: true),
                    onClear: _endsOn == null
                        ? null
                        : () => setState(() => _endsOn = null),
                    clearTooltip: l10n.classSeriesClearEndDate,
                  ),
                ),
              ],
            ],
          ),
          if (_repeat != ClassRepeat.none && _endsOn == null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(l10n.classSeriesNoEndDateHint, style: muted),
            ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(problem, style: errorStyle),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _isEdit ? l10n.classSeriesSave : l10n.classSeriesCreate,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable date with a label, like a read-only text field.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.clearTooltip,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: clearTooltip,
                  onPressed: onClear,
                ),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
