import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'add_shop_vendor_page.dart';
import 'edit_shop_vendor_page.dart';

class _VendorEntry {
  final String vendorId;
  final UserProfile user;

  const _VendorEntry({required this.vendorId, required this.user});
}

class ShopVendorsPage extends StatefulWidget {
  const ShopVendorsPage(
      {super.key, required this.shopId, required this.shopName});

  final String shopId;
  final String shopName;

  @override
  State<ShopVendorsPage> createState() => _ShopVendorsPageState();
}

class _ShopVendorsPageState extends State<ShopVendorsPage> {
  final _api = ApiService();

  List<_VendorEntry> _vendors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getShopVendors(token, shopId: widget.shopId);
      if (mounted) {
        setState(() {
          _vendors = rows
              .map((r) => _VendorEntry(
                    vendorId: r['id'] as String,
                    user: UserProfile.fromJson(r),
                  ))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _resendInvite(_VendorEntry entry) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.resendInvite(token, entry.user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.businessMgmtInviteResent)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _removeVendor(_VendorEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.businessMgmtRemoveVendorTitle),
        content: Text(context.l10n.businessMgmtRemoveVendorMessage),
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
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeShopVendor(token, entry.vendorId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _openEdit(_VendorEntry entry) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditShopVendorPage(
          vendorId: entry.vendorId,
          user: entry.user,
          shopName: widget.shopName,
        ),
      ),
    );
    if (result == 'removed') _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(context.l10n.businessMgmtShopVendorsTitle(widget.shopName))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddShopVendorPage(shopId: widget.shopId),
            ),
          );
          if (added == true) _load();
        },
        icon: const Icon(Icons.person_add_outlined),
        label: Text(context.l10n.businessMgmtAddVendor),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(_error!),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _load, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_vendors.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(context.l10n.businessMgmtNoVendorsYet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
        itemCount: _vendors.length,
        itemBuilder: (_, i) {
          final entry = _vendors[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _openEdit(entry),
              leading: ExcludeSemantics(
                child: CircleAvatar(
                  child: Text(entry.user.name.isNotEmpty
                      ? entry.user.name[0].toUpperCase()
                      : '?'),
                ),
              ),
              title: Text(entry.user.fullName),
              subtitle: Text(entry.user.email),
              trailing: PopupMenuButton<_VendorAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: context.l10n.businessMgmtVendorActions,
                onSelected: (action) {
                  switch (action) {
                    case _VendorAction.edit:
                      _openEdit(entry);
                    case _VendorAction.resendInvite:
                      _resendInvite(entry);
                    case _VendorAction.remove:
                      _removeVendor(entry);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _VendorAction.edit,
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(context.l10n.businessMgmtEditVendor),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _VendorAction.resendInvite,
                    child: ListTile(
                      leading: const Icon(Icons.mark_email_unread_outlined),
                      title: Text(context.l10n.businessMgmtResendInvite),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _VendorAction.remove,
                    child: ListTile(
                      leading: const Icon(Icons.person_remove_outlined),
                      title: Text(context.l10n.businessMgmtRemove),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _VendorAction { edit, resendInvite, remove }
