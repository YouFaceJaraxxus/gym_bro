import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/business.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/image_upload_field.dart';
import 'typed_confirm_dialog.dart';

/// Applies for a new gym/shop (pending until a super user approves it), or
/// edits a business's profile. Owners also switch the gym and shop sides and
/// can delete it; staff edit the rest.
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
  late final TextEditingController _bioCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _phoneCtrl;

  late bool _hasGym;
  late bool _hasShop;
  late TimeOfDay _fromTime;
  late TimeOfDay _toTime;
  late Set<int> _weekdays;
  String? _logo;

  bool _loading = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.business != null;

  /// Sides and deleting are the owner's (or a super user's) call.
  bool get _canManage =>
      !_isEditing ||
      widget.business!.isOwner ||
      (AuthManager.instance.profile?.isSuperUser ?? false);

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _locationCtrl = TextEditingController(text: b?.location ?? '');
    _bioCtrl = TextEditingController(text: b?.bio ?? '');
    _websiteCtrl = TextEditingController(text: b?.website ?? '');
    _phoneCtrl = TextEditingController(text: b?.phone ?? '');
    _hasGym = b?.hasGym ?? true;
    _hasShop = b?.hasShop ?? false;
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
    _bioCtrl.dispose();
    _websiteCtrl.dispose();
    _phoneCtrl.dispose();
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
    if (!_hasGym && !_hasShop) {
      setState(() => _error = context.l10n.rolesFormPickSide);
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
        'bio': _bioCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_canManage) ...{'has_gym': _hasGym, 'has_shop': _hasShop},
        'working_hours_from': _formatTime(_fromTime),
        'working_hours_to': _formatTime(_toTime),
        'working_weekdays': sortedDays,
        'logo': _logo,
      };

      if (_isEditing) {
        await _api.updateBusiness(token, widget.business!.id, data);
      } else {
        final created = await _api.createBusiness(token, data);
        // Applications wait for review; say so before leaving.
        if (mounted && !created.isApproved) await _showSubmitted();
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSubmitted() {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.hourglass_top_outlined),
        title: Text(l10n.rolesFormSubmittedTitle),
        content: Text(l10n.rolesFormSubmittedBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final business = widget.business!;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => TypedConfirmDialog(
        title: l10n.businessGymFormDeleteTitle(business.name),
        message: l10n.rolesFormDeleteMessage,
        confirmText: business.name,
        actionLabel: l10n.businessGymFormDelete,
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
              : l10n.rolesMenuRegisterBusiness)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isEditing) ...[
                Text(
                  l10n.rolesFormIntro,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
              ],
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioCtrl,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: l10n.rolesFormBio),
              ),
              TextFormField(
                controller: _websiteCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.rolesFormWebsite,
                  hintText: 'https://',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  return RegExp(r'^https?://\S+$').hasMatch(t)
                      ? null
                      : l10n.rolesFormWebsiteInvalid;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 40,
                decoration: InputDecoration(labelText: l10n.rolesFormPhone),
              ),
              const SizedBox(height: 8),
              Text(l10n.rolesFormSides,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                l10n.rolesFormSidesHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.fitness_center),
                title: Text(l10n.rolesKindGym),
                subtitle: Text(l10n.rolesFormGymHint),
                value: _hasGym,
                onChanged:
                    _canManage ? (v) => setState(() => _hasGym = v) : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.storefront_outlined),
                title: Text(l10n.rolesKindShop),
                subtitle: Text(l10n.rolesFormShopHint),
                value: _hasShop,
                onChanged:
                    _canManage ? (v) => setState(() => _hasShop = v) : null,
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
                        : l10n.rolesFormApply),
              ),
              if (_isEditing && _canManage) ...[
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
