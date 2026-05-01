import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class AddShopVendorPage extends StatefulWidget {
  const AddShopVendorPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AddShopVendorPage> createState() => _AddShopVendorPageState();
}

class _AddShopVendorPageState extends State<AddShopVendorPage> {
  final _api = ApiService();

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  Set<String> _existingEmails = {};
  bool _loadingEmails = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() => setState(() {}));
    _loadExistingEmails();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEmails() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final vendors = await _api.getShopVendors(token, shopId: widget.shopId);
      final emails = <String>{};
      for (final row in vendors) {
        final e = row['email'] as String?;
        if (e != null) emails.add(e.toLowerCase());
      }
      if (mounted) setState(() { _existingEmails = emails; _loadingEmails = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingEmails = false);
    }
  }

  bool get _emailDuplicate =>
      _existingEmails.contains(_emailCtrl.text.trim().toLowerCase());

  bool get _canSubmit =>
      !_loadingEmails &&
      !_adding &&
      !_emailDuplicate &&
      _emailCtrl.text.trim().isNotEmpty &&
      _nameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _usernameCtrl.text.trim().isNotEmpty;

  Future<void> _add() async {
    setState(() => _adding = true);
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
        setState(() => _adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDuplicate = _emailDuplicate;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Vendor')),
      body: _loadingEmails
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: const OutlineInputBorder(),
                      errorText: isDuplicate ? 'Email already in use' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _canSubmit ? _add : null,
                    style: isDuplicate
                        ? FilledButton.styleFrom(
                            backgroundColor: cs.surfaceContainerHighest,
                            foregroundColor: cs.onSurfaceVariant,
                          )
                        : null,
                    child: _adding
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Add Vendor'),
                  ),
                  if (isDuplicate) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Email already in use',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
