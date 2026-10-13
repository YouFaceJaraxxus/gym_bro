import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/user_search_result.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/user_search_field.dart';

class AddShopVendorPage extends StatefulWidget {
  const AddShopVendorPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AddShopVendorPage> createState() => _AddShopVendorPageState();
}

class _AddShopVendorPageState extends State<AddShopVendorPage> {
  final _api = ApiService();

  // ── existing vendor ids for exclusion / duplicate check ──────────────────
  Set<String> _existingUserIds = {};
  Set<String> _existingEmails = {};
  bool _loadingExisting = true;

  // ── search-and-add state ─────────────────────────────────────────────────
  String? _addingUserId;

  // ── invite-new-user form ─────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() => setState(() {}));
    _loadExisting();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final vendors = await _api.getShopVendors(token, shopId: widget.shopId);
      final userIds = <String>{};
      final emails = <String>{};
      for (final row in vendors) {
        final uid = row['user_id'] as String?;
        final em = row['email'] as String?;
        if (uid != null) userIds.add(uid);
        if (em != null) emails.add(em.toLowerCase());
      }
      if (mounted) {
        setState(() {
          _existingUserIds = userIds;
          _existingEmails = emails;
          _loadingExisting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _addExisting(UserSearchResult user) async {
    setState(() => _addingUserId = user.id);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.addShopVendor(token, userId: user.id, shopId: widget.shopId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _addingUserId = null);
      }
    }
  }

  bool get _emailDuplicate =>
      _existingEmails.contains(_emailCtrl.text.trim().toLowerCase());

  bool get _canInvite =>
      !_loadingExisting &&
      !_inviting &&
      !_emailDuplicate &&
      _emailCtrl.text.trim().isNotEmpty &&
      _nameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _usernameCtrl.text.trim().isNotEmpty;

  Future<void> _invite() async {
    setState(() => _inviting = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.addShopVendor(
        token,
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        shopId: widget.shopId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _inviting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDuplicate = _emailDuplicate;
    final busy = _addingUserId != null || _inviting;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessMgmtAddVendor)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Search existing users ─────────────────────────────────────
            UserSearchField(
              excludeUserIds: _existingUserIds,
              enabled: !busy,
              addingUserId: _addingUserId,
              onSelect: _addExisting,
            ),
            const SizedBox(height: 16),

            // ── Invite new user ───────────────────────────────────────────
            ExpansionTile(
              title: Text(l10n.businessMgmtInviteNewUser),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: _emailCtrl,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.businessMgmtEmail,
                    border: const OutlineInputBorder(),
                    errorText: isDuplicate ? l10n.businessMgmtAlreadyVendor : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.businessMgmtFirstName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameCtrl,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.businessMgmtLastName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameCtrl,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.businessMgmtUsername,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _canInvite ? _invite : null,
                  child: _inviting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cs.onSurfaceVariant),
                        )
                      : Text(l10n.businessMgmtInviteAndAddVendor),
                ),
                if (isDuplicate) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.businessMgmtEmailAlreadyVendor,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
