import 'package:flutter/material.dart';

import '../models/user_settings.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../services/push_service.dart';
import '../services/settings_service.dart';
import '../l10n/l10n.dart';
import 'typed_confirm_dialog.dart';

/// A group of notification types muted together from Settings.
/// Invites are never mutable: they need an answer.
enum _MuteCategory {
  classes(Icons.event_outlined, ['class_reminder', 'events']),
  billing(Icons.receipt_long_outlined, [
    'invoice_issued',
    'membership_expiring',
    'member_subscription_extended',
    'payment_received',
  ]),
  shop(Icons.storefront_outlined, [
    'order_update',
    'purchase_made',
    'shop_item_update',
  ]),
  community(Icons.forum_outlined, ['news', 'post_comment']),
  coaching(Icons.sports_outlined, [
    'training',
    'training_update',
    'session_comment',
  ]),
  staff(Icons.badge_outlined, [
    'shift_assigned',
    'member_join',
    'employee_join',
    'vendor_join',
  ]);

  const _MuteCategory(this.icon, this.types);

  final IconData icon;
  final List<String> types;

  String label(AppLocalizations l10n) => switch (this) {
    _MuteCategory.classes => l10n.shellMuteClasses,
    _MuteCategory.billing => l10n.shellMuteBilling,
    _MuteCategory.shop => l10n.shellMuteShop,
    _MuteCategory.community => l10n.shellMuteCommunity,
    _MuteCategory.coaching => l10n.shellMuteCoaching,
    _MuteCategory.staff => l10n.shellMuteStaff,
  };

  String description(AppLocalizations l10n) => switch (this) {
    _MuteCategory.classes => l10n.shellMuteClassesDescription,
    _MuteCategory.billing => l10n.shellMuteBillingDescription,
    _MuteCategory.shop => l10n.shellMuteShopDescription,
    _MuteCategory.community => l10n.shellMuteCommunityDescription,
    _MuteCategory.coaching => l10n.shellMuteCoachingDescription,
    _MuteCategory.staff => l10n.shellMuteStaffDescription,
  };
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settings = SettingsService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Show cached values immediately; refresh from the server in the background.
    _settings.syncFromServer();
  }

  Future<void> _save(Future<void> Function() change) async {
    try {
      await change();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.shellSettingsSaveFailed(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        ),
      );
    }
  }

  void _setCategoryMuted(UserSettings s, _MuteCategory c, bool muted) {
    final next = {...s.mutedTypes};
    if (muted) {
      next.addAll(c.types);
    } else {
      next.removeAll(c.types);
    }
    _save(() => _settings.update(mutedTypes: next));
  }

  Future<void> _changeEmail() async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangeEmailDialog(),
    );
    if (message == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_unread_outlined),
        title: Text(ctx.l10n.shellConfirmNewEmailTitle),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonOk),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.shellPasswordChanged)),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final profile = AuthManager.instance.profile;
    if (profile == null) return;
    final impersonating = AuthManager.instance.isImpersonating;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => TypedConfirmDialog(
        title: impersonating
            ? ctx.l10n.shellDeleteUserTitle(profile.fullName)
            : ctx.l10n.shellDeleteAccountTitle,
        message: impersonating
            ? ctx.l10n.shellDeleteUserMessage(profile.fullName)
            : ctx.l10n.shellDeleteAccountMessage,
        confirmText: ctx.l10n.shellDeleteConfirmWord,
        actionLabel: ctx.l10n.shellDeleteAccount,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await ApiService().deleteUser(token, profile.id);
      if (impersonating) {
        // Back to the super user's own account.
        final restored = await AuthManager.instance.stopImpersonation();
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(restored ? '/home' : '/signup', (_) => false);
      } else {
        await AuthManager.instance.clear();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/signup', (_) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // 409 when the user still owns a gym or shop — show the API message.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.shellDeleteAccountFailed),
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.commonOk),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shellSettings)),
      body: ValueListenableBuilder<UserSettings>(
        valueListenable: _settings.settings,
        builder: (context, s, _) => RefreshIndicator(
          onRefresh: _settings.syncFromServer,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Appearance ───────────────────────────────────────────────
              _SectionTitle(l10n.shellSettingsAppearance),
              _SettingCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.shellSettingsTheme,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: const Icon(
                                  Icons.brightness_auto_outlined,
                                ),
                                label: Text(l10n.shellThemeSystem),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: const Icon(Icons.light_mode_outlined),
                                label: Text(l10n.shellThemeLight),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: const Icon(Icons.dark_mode_outlined),
                                label: Text(l10n.shellThemeDark),
                              ),
                            ],
                            selected: {_settings.themeMode.value},
                            onSelectionChanged: (v) => _save(
                              () => _settings.update(themeMode: v.first),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Language ─────────────────────────────────────────────────
              _SectionTitle(context.l10n.settingsLanguage),
              _SettingCard(
                children: [
                  RadioGroup<Locale?>(
                    groupValue: _settings.locale.value,
                    onChanged: (v) => _save(
                      () => v == null
                          ? _settings.update(useSystemLocale: true)
                          : _settings.update(locale: v),
                    ),
                    child: Column(
                      children: [
                        for (final option in <(String, Locale?)>[
                          (context.l10n.settingsLanguageSystem, null),
                          (
                            context.l10n.settingsLanguageEnglish,
                            const Locale('en'),
                          ),
                          (
                            context.l10n.settingsLanguageSerbian,
                            const Locale.fromSubtags(
                              languageCode: 'sr',
                              scriptCode: 'Latn',
                            ),
                          ),
                        ])
                          RadioListTile<Locale?>(
                            title: Text(option.$1),
                            value: option.$2,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Units ────────────────────────────────────────────────────
              _SectionTitle(l10n.shellSettingsUnits),
              _SettingCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text(l10n.shellSettingsWeight),
                    subtitle: Text(
                      s.weightUnit == 'lb'
                          ? l10n.shellUnitPounds
                          : l10n.shellUnitKilograms,
                    ),
                    trailing: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: [
                        ButtonSegment(
                          value: 'kg',
                          label: Text(
                            'kg',
                            semanticsLabel: l10n.shellUnitKilograms,
                          ),
                        ),
                        ButtonSegment(
                          value: 'lb',
                          label: Text(
                            'lb',
                            semanticsLabel: l10n.shellUnitPounds,
                          ),
                        ),
                      ],
                      selected: {s.weightUnit},
                      onSelectionChanged: (v) =>
                          _save(() => _settings.update(weightUnit: v.first)),
                    ),
                  ),
                ],
              ),

              // ── Notifications ────────────────────────────────────────────
              _SectionTitle(l10n.shellHomeNotifications),
              if (!PushService.isConfigured)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _InfoNote(
                    icon: Icons.info_outline,
                    text: l10n.shellPushUnavailable,
                  ),
                ),
              _SettingCard(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(l10n.shellPushNotifications),
                    subtitle: Text(l10n.shellPushNotificationsSubtitle),
                    value: s.pushEnabled,
                    onChanged: (v) =>
                        _save(() => _settings.update(pushEnabled: v)),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      l10n.shellSendMePushesAbout,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final c in _MuteCategory.values)
                    SwitchListTile(
                      secondary: Icon(c.icon),
                      title: Text(c.label(l10n)),
                      subtitle: Text(c.description(l10n)),
                      value: !c.types.every(s.mutedTypes.contains),
                      onChanged: s.pushEnabled
                          ? (on) => _setCategoryMuted(s, c, !on)
                          : null,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Text(
                      l10n.shellMuteFootnote,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Account ──────────────────────────────────────────────────
              _SectionTitle(l10n.shellSettingsAccount),
              _SettingCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: Text(l10n.shellChangeEmail),
                    subtitle: Text(AuthManager.instance.profile?.email ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : _changeEmail,
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l10n.shellChangePassword),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : _changePassword,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: cs.error,
                    ),
                    title: Text(
                      l10n.shellDeleteAccount,
                      style: TextStyle(color: cs.error),
                    ),
                    subtitle: Text(l10n.shellDeleteAccountSubtitle),
                    trailing: _busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: l10n.commonLoading,
                            ),
                          )
                        : null,
                    onTap: _busy ? null : _deleteAccount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Building blocks ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Change email dialog ───────────────────────────────────────────────────────

class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog();

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final message = await _api.changeEmail(
        token,
        newEmail: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final current = AuthManager.instance.profile?.email ?? '';
    return AlertDialog(
      title: Text(l10n.shellChangeEmail),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shellChangeEmailIntro,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                decoration: InputDecoration(labelText: l10n.shellNewEmail),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                    return l10n.shellAuthInvalidEmail;
                  }
                  if (value.toLowerCase() == current.toLowerCase()) {
                    return l10n.shellAlreadyYourEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: l10n.shellCurrentPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscure
                        ? l10n.shellShowPassword
                        : l10n.shellHidePassword,
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l10n.commonRequired : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: l10n.commonLoading,
                  ),
                )
              : Text(l10n.shellSendLink),
        ),
      ],
    );
  }
}

// ── Change password dialog ────────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.changePassword(
        token,
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final toggle = IconButton(
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      tooltip: _obscure ? l10n.shellShowPasswords : l10n.shellHidePasswords,
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return AlertDialog(
      title: Text(l10n.shellChangePassword),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: l10n.shellCurrentPassword,
                  suffixIcon: toggle,
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l10n.commonRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(labelText: l10n.shellNewPassword),
                validator: (v) => (v == null || v.length < 6)
                    ? l10n.shellAuthPasswordMin(6)
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: l10n.shellConfirmNewPassword,
                ),
                validator: (v) =>
                    v != _newCtrl.text ? l10n.shellPasswordsDontMatch : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: l10n.commonLoading,
                  ),
                )
              : Text(l10n.shellChange),
        ),
      ],
    );
  }
}
