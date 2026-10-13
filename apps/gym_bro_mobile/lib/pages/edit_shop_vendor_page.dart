import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class EditShopVendorPage extends StatefulWidget {
  const EditShopVendorPage({
    super.key,
    required this.vendorId,
    required this.user,
    required this.shopName,
  });

  final String vendorId;
  final UserProfile user;
  final String shopName;

  @override
  State<EditShopVendorPage> createState() => _EditShopVendorPageState();
}

class _EditShopVendorPageState extends State<EditShopVendorPage> {
  final _api = ApiService();
  bool _resending = false;
  bool _removing = false;

  Future<void> _resendInvite() async {
    setState(() => _resending = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.resendInvite(token, widget.user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.businessMgmtInviteResentSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.businessMgmtRemoveVendorTitle),
        content: Text(context.l10n.businessMgmtRemoveVendorFromShopMessage(
            widget.user.fullName, widget.shopName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.businessMgmtRemove)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeShopVendor(token, widget.vendorId);
      if (mounted) Navigator.pop(context, 'removed');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _removing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessMgmtEditVendor)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 36,
                    child: Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.user.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.businessMgmtVendor,
                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Card(
            child: Column(
              children: [
                MergeSemantics(
                  child: ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(l10n.businessMgmtEmail),
                    subtitle: Text(widget.user.email),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                MergeSemantics(
                  child: ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: Text(l10n.businessMgmtUsername),
                    subtitle: Text(widget.user.username),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                MergeSemantics(
                  child: ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(l10n.businessMgmtShop),
                    subtitle: Text(widget.shopName),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: (_resending || _removing) ? null : _resendInvite,
            icon: _resending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mark_email_unread_outlined),
            label: Text(l10n.businessMgmtResendInvite),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: (_resending || _removing) ? null : _remove,
            icon: _removing
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.error),
                  )
                : Icon(Icons.person_remove_outlined, color: cs.error),
            label: Text(l10n.businessMgmtRemoveFromShop, style: TextStyle(color: cs.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}
