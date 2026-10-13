import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/business.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/image_upload_field.dart';
import 'typed_confirm_dialog.dart';

class BusinessFormPage extends StatefulWidget {
  const BusinessFormPage({super.key, this.business});

  /// Null = create mode, non-null = edit mode.
  final Business? business;

  @override
  State<BusinessFormPage> createState() => _BusinessFormPageState();
}

class _BusinessFormPageState extends State<BusinessFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;

  late String _type;
  late TimeOfDay _fromTime;
  late TimeOfDay _toTime;
  late Set<int> _weekdays;
  String? _logo;

  bool _loading = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.business != null;

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _locationCtrl = TextEditingController(text: b?.location ?? '');
    _type = b?.type ?? 'gym';
    _fromTime = b != null
        ? _parseTime(b.workingHoursFrom)
        : const TimeOfDay(hour: 9, minute: 0);
    _toTime = b != null
        ? _parseTime(b.workingHoursTo)
        : const TimeOfDay(hour: 17, minute: 0);
    _weekdays =
        b != null ? b.workingWeekdays.toSet() : {1, 2, 3, 4, 5};
    _logo = b?.logo;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime({required bool isFrom}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _fromTime : _toTime,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromTime = picked;
        } else {
          _toTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_weekdays.isEmpty) {
      setState(() => _error = context.l10n.businessGymFormSelectWorkingDay);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await AuthManager.instance.getValidToken();
      final sortedDays = _weekdays.toList()..sort();
      final data = {
        'name': _nameCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'type': _type,
        'working_hours_from': _formatTime(_fromTime),
        'working_hours_to': _formatTime(_toTime),
        'working_weekdays': sortedDays,
        'logo': _logo,
      };

      if (_isEditing) {
        await _api.updateBusiness(token, widget.business!.id, data);
      } else {
        await _api.createBusiness(token, data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final business = widget.business!;
    final l10n = context.l10n;
    final isGym = business.type == 'gym';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => TypedConfirmDialog(
        title: l10n.businessGymFormDeleteTitle(business.name),
        message: isGym
            ? l10n.businessGymFormDeleteGymMessage
            : l10n.businessGymFormDeleteShopMessage,
        confirmText: business.name,
        actionLabel: isGym
            ? l10n.businessGymFormDeleteGymAction
            : l10n.businessGymFormDeleteShopAction,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteBusiness(token, business.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.businessGymFormDeleted(business.name))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing
              ? l10n.businessGymFormTitleEdit
              : l10n.businessGymFormTitleNew)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ImagePickerField(
                imageUrl: _logo,
                folder: 'businesses',
                label: l10n.businessGymFormAddLogo,
                height: 120,
                onUploaded: (url) => setState(() => _logo = url),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    InputDecoration(labelText: l10n.businessGymFormName),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.commonRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration:
                    InputDecoration(labelText: l10n.businessGymFormLocation),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.commonRequired
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(_type),
                initialValue: _type,
                decoration:
                    InputDecoration(labelText: l10n.businessGymFormType),
                items: [
                  DropdownMenuItem(
                      value: 'gym', child: Text(l10n.businessGymFormTypeGym)),
                  DropdownMenuItem(
                      value: 'shop',
                      child: Text(l10n.businessGymFormTypeShop)),
                ],
                // Type is immutable after creation.
                onChanged: _isEditing
                    ? null
                    : (v) {
                        if (v != null) setState(() => _type = v);
                      },
              ),
              const SizedBox(height: 24),
              Text(l10n.businessGymFormWorkingHours,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: l10n.businessGymFormFrom,
                      time: _fromTime,
                      onTap: () => _pickTime(isFrom: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeTile(
                      label: l10n.businessGymFormTo,
                      time: _toTime,
                      onTap: () => _pickTime(isFrom: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.businessGymFormWorkingDays,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(weekdayLabel(day, locale)),
                      tooltip: weekdayLabel(day, locale, abbreviated: false),
                      selected: _weekdays.contains(day),
                      onSelected: (sel) {
                        setState(() {
                          sel ? _weekdays.add(day) : _weekdays.remove(day);
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: (_loading || _deleting) ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        // Button is disabled while loading, so use the
                        // default (primary) color instead of onPrimary.
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing
                        ? l10n.businessGymFormSaveChanges
                        : l10n.businessGymFormCreate),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: (_loading || _deleting) ? null : _delete,
                  icon: _deleting
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.error),
                        )
                      : Icon(Icons.delete_forever_outlined,
                          color: Theme.of(context).colorScheme.error),
                  label: Text(l10n.businessGymFormDelete,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile(
      {required this.label,
      required this.time,
      required this.onTap});

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
              color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(time.format(context),
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
