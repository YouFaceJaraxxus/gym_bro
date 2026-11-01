import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/challenge.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import '../../utils/device_timezone.dart';
import '../../utils/haptics.dart';
import '../../widgets/challenge_ring.dart';

/// Creates a challenge (for one of [gyms] I work at, or — with
/// [allowPlatform], super users — for everyone), or edits [existing].
/// Pops with the saved challenge.
class ChallengeFormPage extends StatefulWidget {
  final List<ChallengeGym> gyms;
  final bool allowPlatform;

  /// The gym picked first.
  final String? gymId;
  final Challenge? existing;

  const ChallengeFormPage({super.key, this.gyms = const [], this.allowPlatform = false, this.gymId, this.existing});

  @override
  State<ChallengeFormPage> createState() => _ChallengeFormPageState();
}

/// The longest a challenge may run (the server allows 366 days between its dates).
const _maxDays = 367;

class _ChallengeFormPageState extends State<ChallengeFormPage> {
  final _form = GlobalKey<FormState>();
  final _api = ApiService();
  final _settings = SettingsService.instance;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _target;
  String? _gymId;
  late ChallengeMetric _metric;
  late DateTime _starts;
  late DateTime _ends;
  bool _saving = false;

  Challenge? get _existing => widget.existing;

  /// Once it started, what counts and since when are fixed.
  bool get _locked => _existing != null && _existing!.status != ChallengeStatus.upcoming;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    final e = _existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _metric = e?.metric ?? ChallengeMetric.workouts;
    _target = TextEditingController(text: e == null ? '12' : _displayTarget(e.metric, e.target));
    _starts = e?.startsOn ?? _today;
    _ends = e?.endsOn ?? _today.add(const Duration(days: 29));
    if (e == null) {
      final ids = widget.gyms.map((g) => g.id).toList();
      _gymId = ids.contains(widget.gymId) ? widget.gymId : (ids.isNotEmpty ? ids.first : null);
    } else {
      _gymId = e.gym?.id;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    super.dispose();
  }

  String _displayTarget(ChallengeMetric m, int target) =>
      m == ChallengeMetric.volumeKg ? _settings.toDisplayWeight(target.toDouble()).round().toString() : '$target';

  /// The target as the server stores it (volume in kg).
  int? get _targetValue {
    final v = int.tryParse(_target.text.trim());
    if (v == null || v < 1) return null;
    return _metric == ChallengeMetric.volumeKg ? _settings.fromDisplayWeight(v.toDouble()).round() : v;
  }

  int get _lengthDays => _ends.difference(_starts).inDays + 1;

  String? _gymName(String? id) {
    for (final g in widget.gyms) {
      if (g.id == id) return g.name;
    }
    return _existing?.gym?.name;
  }

  Future<void> _pickDate({required bool start}) async {
    final first = start ? (_starts.isBefore(_today) ? _starts : _today) : _starts;
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _starts : _ends,
      firstDate: first,
      lastDate: _today.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        final length = _lengthDays;
        _starts = picked;
        if (_ends.isBefore(_starts)) _ends = _starts.add(Duration(days: length - 1));
      } else {
        _ends = picked;
      }
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_ends.isBefore(_starts)) {
      _snack(l10n.challengeFormEndsBeforeStart);
      return;
    }
    if (_lengthDays > _maxDays) {
      _snack(l10n.challengeFormTooLong);
      return;
    }
    final draft = ChallengeDraft(
      gymId: _gymId,
      title: _title.text,
      description: _description.text,
      metric: _metric,
      target: _targetValue!,
      startsOn: _starts,
      endsOn: _ends,
    );
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      final tz = await deviceTimezone();
      final e = _existing;
      final saved = e == null
          ? await _api.createChallenge(token, draft, tz: tz)
          : await _api.updateChallenge(token, e.id, draft.changesFrom(e), tz: tz);
      if (e != null) messenger.showSnackBar(SnackBar(content: Text(l10n.challengeFormSaved)));
      Haptics.tap();
      nav.pop(saved);
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dateFormat = DateFormat.yMMMEd(l10n.localeName);
    final editing = _existing != null;
    final gymName = _gymName(_gymId);

    return Scaffold(
      appBar: AppBar(title: Text(editing ? l10n.challengeEdit : l10n.challengeCreate)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // ── Who ──
            if (!editing && (widget.gyms.length + (widget.allowPlatform ? 1 : 0)) > 1)
              DropdownButtonFormField<String?>(
                initialValue: _gymId,
                decoration: InputDecoration(labelText: l10n.challengeFormWho, border: const OutlineInputBorder()),
                items: [
                  for (final g in widget.gyms) DropdownMenuItem(value: g.id, child: Text(l10n.challengeFormMembersOf(g.name))),
                  if (widget.allowPlatform) DropdownMenuItem(value: null, child: Text(l10n.challengeFormEveryone)),
                ],
                onChanged: (v) => setState(() {
                  _gymId = v;
                  if (v == null && _metric.gymOnly) _metric = ChallengeMetric.workouts;
                }),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_gymId == null ? Icons.public_rounded : Icons.fitness_center_rounded),
                title: Text(l10n.challengeFormWho),
                subtitle: Text(gymName == null ? l10n.challengeFormEveryone : l10n.challengeFormMembersOf(gymName)),
              ),
            const SizedBox(height: 16),

            // ── Name ──
            TextFormField(
              controller: _title,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.challengeFormTitle,
                hintText: l10n.challengeFormTitleHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? l10n.challengeFormTitleRequired : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              maxLength: 1000,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.challengeFormDescription, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // ── What counts ──
            Text(l10n.challengeFormMetric, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in ChallengeMetric.values)
                  if (!m.gymOnly || _gymId != null)
                    ChoiceChip(
                      avatar: Icon(m.icon, size: 18, color: _metric == m ? Colors.white : m.color),
                      label: Text(m.label(l10n)),
                      selected: _metric == m,
                      selectedColor: m.color,
                      labelStyle: _metric == m ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w700) : null,
                      showCheckmark: false,
                      onSelected: _locked
                          ? null
                          : (_) => setState(() {
                                final before = _targetValue;
                                _metric = m;
                                if (before != null) _target.text = _displayTarget(m, before);
                              }),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_metric.rule(l10n, gymName: gymName), style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
              decoration: InputDecoration(
                labelText: l10n.challengeFormTarget,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(_metric.icon, color: _metric.color),
                suffixText: _metric.unit(l10n, int.tryParse(_target.text) ?? 2),
              ),
              onChanged: (_) => setState(() {}),
              validator: (_) => _targetValue == null ? l10n.challengeFormTargetInvalid : null,
            ),
            const SizedBox(height: 20),

            // ── When ──
            Text(l10n.challengeFormDates, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (!_locked)
              Wrap(
                spacing: 8,
                children: [
                  for (final days in const [7, 14, 30])
                    ActionChip(
                      label: Text(l10n.challengeFormLength(days)),
                      onPressed: () => setState(() => _ends = _starts.add(Duration(days: days - 1))),
                    ),
                ],
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: Text(l10n.challengeFormStarts),
              subtitle: Text(dateFormat.format(_starts)),
              enabled: !_locked,
              onTap: _locked ? null : () => _pickDate(start: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.challengeFormEnds),
              subtitle: Text(dateFormat.format(_ends)),
              trailing: Text(
                l10n.challengeFormLength(_lengthDays.clamp(1, 9999)),
                style: text.labelLarge?.copyWith(color: _lengthDays > _maxDays || _lengthDays < 1 ? cs.error : cs.onSurfaceVariant),
              ),
              onTap: () => _pickDate(start: false),
            ),
            if (_locked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.challengeFormLocked, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
            if (!editing && gymName != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l10n.challengeFormNotify(gymName), style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _saving
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(editing ? l10n.challengeFormSave : l10n.challengeFormCreate),
            ),
          ],
        ),
      ),
    );
  }
}
