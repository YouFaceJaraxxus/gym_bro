import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../models/social.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/image_upload_field.dart';
import 'people_common.dart';

final _usernameRe = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
const _kBioMax = 300;
const _kInterestMaxLength = 30;

/// Edit my social profile (avatar, names, username, bio, interests) and
/// privacy settings. Saves only the changed fields.
class EditSocialProfilePage extends StatefulWidget {
  const EditSocialProfilePage({super.key, this.scrollToPrivacy = false});

  /// Opened from "Privacy": jump straight to the privacy section.
  final bool scrollToPrivacy;

  @override
  State<EditSocialProfilePage> createState() => _EditSocialProfilePageState();
}

class _EditSocialProfilePageState extends State<EditSocialProfilePage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _privacyKey = GlobalKey();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _interestFocus = FocusNode();

  PublicProfile? _original;
  String? _avatarUrl;
  List<String> _interests = [];
  bool _isPrivate = false;
  bool _discoverable = true;
  bool _showActivity = true;
  bool _allowNonFollowerMessages = true;
  bool _hasLocation = false;
  DateTime? _locationUpdatedAt;

  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _saveError;
  String? _usernameError;
  bool _locationBusy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _lastName, _username, _bio]) {
      c.addListener(_onEdited);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _lastName, _username, _bio, _interestCtrl]) {
      c.dispose();
    }
    _interestFocus.dispose();
    super.dispose();
  }

  void _onEdited() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final p = await _api.getMyProfile(token);
      if (!mounted) return;
      _apply(p);
      setState(() => _loading = false);
      if (widget.scrollToPrivacy) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _privacyKey.currentContext;
          if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = peopleErrorText(e);
      });
    }
  }

  void _apply(PublicProfile p) {
    final s = p.settings;
    _original = p;
    _name.text = p.name;
    _lastName.text = p.lastName;
    _username.text = p.username;
    _bio.text = p.bio ?? '';
    _avatarUrl = p.avatarUrl;
    _interests = [...p.interests];
    _isPrivate = s?.isPrivate ?? p.isPrivate;
    _discoverable = s?.discoverable ?? true;
    _showActivity = s?.showActivityStatus ?? true;
    _allowNonFollowerMessages = s?.allowNonFollowerMessages ?? true;
    _hasLocation = s?.hasLocation ?? false;
    _locationUpdatedAt = s?.locationUpdatedAt;
  }

  /// Only what differs from the loaded profile.
  Map<String, dynamic> _changes() {
    final p = _original;
    if (p == null) return const {};
    final s = p.settings;
    final bio = _bio.text.trim();
    return {
      if (_name.text.trim() != p.name) 'name': _name.text.trim(),
      if (_lastName.text.trim() != p.lastName) 'last_name': _lastName.text.trim(),
      if (_username.text.trim() != p.username) 'username': _username.text.trim(),
      if (bio != (p.bio ?? '').trim()) 'bio': bio,
      if (!listEquals(_interests, p.interests)) 'interests': _interests,
      if (_avatarUrl != p.avatarUrl) 'avatar_url': _avatarUrl,
      if (_isPrivate != (s?.isPrivate ?? p.isPrivate)) 'is_private': _isPrivate,
      if (_discoverable != (s?.discoverable ?? true)) 'discoverable': _discoverable,
      if (_showActivity != (s?.showActivityStatus ?? true)) 'show_activity_status': _showActivity,
      if (_allowNonFollowerMessages != (s?.allowNonFollowerMessages ?? true))
        'allow_non_follower_messages': _allowNonFollowerMessages,
    };
  }

  bool get _dirty => _changes().isNotEmpty;

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _usernameError = null);
    if (!_formKey.currentState!.validate()) return;
    final changes = _changes();
    if (changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.updateMyProfile(token, changes);
      // Keep the rest of the app (drawer, posts, chat) in sync.
      final me = AuthManager.instance.profile;
      if (me != null) {
        await AuthManager.instance.updateProfile(UserProfile(
          id: me.id,
          username: updated.username,
          email: me.email,
          name: updated.name,
          lastName: updated.lastName,
          role: me.role,
          avatarUrl: updated.avatarUrl,
        ));
      }
      if (!mounted) return;
      setState(() {
        _apply(updated);
        _saving = false;
      });
      showPeopleSnack(context, l10n.peopleSaved);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = peopleErrorText(e);
      setState(() {
        _saving = false;
        if (changes.containsKey('username') && msg.toLowerCase().contains('taken')) {
          _usernameError = l10n.peopleUsernameTaken;
        } else {
          _saveError = msg;
        }
      });
    }
  }

  Future<void> _onPrivateChanged(bool value) async {
    final wasPrivate = _original?.settings?.isPrivate ?? _original?.isPrivate ?? false;
    if (!value && wasPrivate) {
      final l10n = context.l10n;
      final ok = await confirmPeopleAction(
        context,
        title: l10n.peopleGoPublicTitle,
        body: l10n.peopleGoPublicBody,
        confirmLabel: l10n.peopleGoPublicConfirm,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _isPrivate = value);
  }

  // ── Interests ────────────────────────────────────────────────────────────

  void _addInterest(String raw) {
    var value = raw.trim().toLowerCase();
    if (value.isEmpty) return;
    if (value.length > _kInterestMaxLength) value = value.substring(0, _kInterestMaxLength);
    if (_interests.length >= kMaxInterests || _interests.contains(value)) {
      _interestCtrl.clear();
      return;
    }
    setState(() => _interests = [..._interests, value]);
    _interestCtrl.clear();
  }

  void _removeInterest(String value) => setState(() => _interests = _interests.where((i) => i != value).toList());

  // ── Location ─────────────────────────────────────────────────────────────

  Future<void> _updateLocation() async {
    final l10n = context.l10n;
    setState(() => _locationBusy = true);
    final error = await shareCoarseLocation(l10n);
    if (!mounted) return;
    setState(() {
      _locationBusy = false;
      if (error == null) {
        _hasLocation = true;
        _locationUpdatedAt = DateTime.now();
      }
    });
    showPeopleSnack(context, error ?? l10n.peopleLocationUpdated);
  }

  Future<void> _stopLocation() async {
    final l10n = context.l10n;
    setState(() => _locationBusy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.clearMyLocation(token);
      if (!mounted) return;
      setState(() {
        _hasLocation = false;
        _locationUpdatedAt = null;
      });
      showPeopleSnack(context, l10n.peopleLocationStopped);
    } catch (e) {
      if (!mounted) return;
      showPeopleSnack(context, peopleErrorText(e));
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final l10n = context.l10n;
    final ok = await confirmPeopleAction(
      context,
      title: l10n.peopleDiscardTitle,
      confirmLabel: l10n.peopleDiscard,
      destructive: true,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dirty = !_loading && _dirty;
    return PopScope(
      canPop: !dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.peopleEditTitle),
          actions: [
            if (_original != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _saving || !dirty ? null : _save,
                  child: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l10n.commonLoading),
                        )
                      : Text(l10n.commonSave),
                ),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) return Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading));
    final original = _original;
    if (original == null) {
      return Center(child: PeopleErrorState(message: _loadError ?? '', onRetry: _load));
    }
    final cs = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Center(
            child: AvatarPicker(
              imageUrl: _avatarUrl,
              folder: original.id,
              radius: 48,
              onUploaded: (url) => setState(() => _avatarUrl = url),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l10n.shellAuthFirstName),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastName,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l10n.shellAuthLastName),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _username,
            enabled: !_saving,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.shellAuthUsername,
              prefixText: '@',
              errorText: _usernameError,
              helperText: l10n.peopleUsernameInvalid,
            ),
            validator: (v) => _usernameRe.hasMatch((v ?? '').trim()) ? null : l10n.peopleUsernameInvalid,
            onChanged: (_) {
              if (_usernameError != null) setState(() => _usernameError = null);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bio,
            enabled: !_saving,
            maxLength: _kBioMax,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.peopleBio, hintText: l10n.peopleBioHint, alignLabelWithHint: true),
          ),
          const SizedBox(height: 8),
          _buildInterests(),
          const SizedBox(height: 24),
          const Divider(),
          _SectionTitle(key: _privacyKey, title: l10n.peoplePrivacy),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isPrivate,
            onChanged: _saving ? null : _onPrivateChanged,
            title: Text(l10n.peoplePrivateAccount),
            subtitle: Text(l10n.peoplePrivateAccountHint),
            secondary: Icon(_isPrivate ? Icons.lock_outline : Icons.lock_open_outlined),
          ),
          // Approved followers can always message; this decides everyone else.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _allowNonFollowerMessages,
            onChanged: _saving ? null : (v) => setState(() => _allowNonFollowerMessages = v),
            title: Text(l10n.peopleNonFollowerMessages),
            subtitle: Text(
              !_allowNonFollowerMessages
                  ? l10n.peopleNonFollowerMessagesOff
                  : _isPrivate
                  ? l10n.peopleNonFollowerMessagesPrivate
                  : l10n.peopleNonFollowerMessagesPublic,
            ),
            secondary: const Icon(Icons.forum_outlined),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showActivity,
            onChanged: _saving ? null : (v) => setState(() => _showActivity = v),
            title: Text(l10n.peopleShowActivity),
            subtitle: Text(l10n.peopleShowActivityHint),
            secondary: const Icon(Icons.circle_outlined),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _discoverable,
            onChanged: _saving ? null : (v) => setState(() => _discoverable = v),
            title: Text(l10n.peopleDiscoverable),
            subtitle: Text(l10n.peopleDiscoverableHint),
            secondary: const Icon(Icons.explore_outlined),
          ),
          const SizedBox(height: 8),
          const Divider(),
          _SectionTitle(title: l10n.peopleLocationSection),
          _buildLocation(),
          if (_saveError != null) ...[
            const SizedBox(height: 16),
            Text(_saveError!, style: TextStyle(color: cs.error)),
          ],
        ],
      ),
    );
  }

  Widget _buildInterests() {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final full = _interests.length >= kMaxInterests;
    final typed = _interestCtrl.text.trim().toLowerCase();
    final suggestions = kInterestSuggestions
        .where((s) => !_interests.contains(s))
        .where((s) => typed.isEmpty || s.contains(typed) || interestLabel(l10n, s).toLowerCase().contains(typed))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.peopleInterests, style: text.titleSmall)),
            Text(
              '${_interests.length}/$kMaxInterests',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_interests.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final i in _interests)
                InputChip(
                  label: Text(interestLabel(l10n, i)),
                  onDeleted: _saving ? null : () => _removeInterest(i),
                  deleteButtonTooltipMessage: l10n.peopleInterestRemove(interestLabel(l10n, i)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _interestCtrl,
          focusNode: _interestFocus,
          enabled: !full && !_saving,
          maxLength: _kInterestMaxLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: full ? l10n.peopleInterestsMax(kMaxInterests) : l10n.peopleInterestsHint,
            prefixIcon: const Icon(Icons.add),
            isDense: true,
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) {
            _addInterest(v);
            _interestFocus.requestFocus();
          },
        ),
        if (!full && suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in suggestions)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(interestLabel(l10n, s)),
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving ? null : () => _addInterest(s),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLocation() {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = !_hasLocation
        ? l10n.peopleLocationOff
        : _locationUpdatedAt == null
        ? l10n.peopleLocationOn
        : l10n.peopleLocationOnUpdated(relativeTime(l10n, _locationUpdatedAt!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_hasLocation ? Icons.location_on_outlined : Icons.location_off_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(status, style: text.bodyMedium)),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(l10n.peopleNearbyPrivacyBody, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _locationBusy ? null : _updateLocation,
                icon: _locationBusy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l10n.commonLoading),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_hasLocation ? l10n.peopleLocationUpdate : l10n.peopleShareLocation),
              ),
              if (_hasLocation)
                OutlinedButton(
                  onPressed: _locationBusy ? null : _stopLocation,
                  child: Text(l10n.peopleLocationStop),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
