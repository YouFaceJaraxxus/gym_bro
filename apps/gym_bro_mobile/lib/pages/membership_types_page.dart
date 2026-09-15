import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

/// Owner-facing CRUD for a gym's membership plans (e.g. "Basic", "Premium").
class MembershipTypesPage extends StatefulWidget {
  const MembershipTypesPage({super.key, required this.gymId, required this.gymName});

  final String gymId;
  final String gymName;

  @override
  State<MembershipTypesPage> createState() => _MembershipTypesPageState();
}

class _MembershipTypesPageState extends State<MembershipTypesPage> {
  final _api = ApiService();
  List<GymMembershipType> _types = [];
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
      final types = await _api.getGymMembershipTypes(token, gymId: widget.gymId);
      if (mounted) setState(() { _types = types; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _openForm({GymMembershipType? type}) async {
    final nameCtrl = TextEditingController(text: type?.name ?? '');
    final costCtrl = TextEditingController(
        text: type != null ? type.monthlyCost.toStringAsFixed(2) : '');
    var isActive = type?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(type == null ? 'New Membership Type' : 'Edit Membership Type'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: costCtrl,
                  decoration: const InputDecoration(labelText: 'Monthly cost', prefixText: '\$'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      final token = await AuthManager.instance.getValidToken();
      final data = {
        'name': nameCtrl.text.trim(),
        'monthly_cost': double.parse(costCtrl.text.trim()),
        'is_active': isActive,
      };
      if (type == null) {
        await _api.createGymMembershipType(token, {...data, 'gym_id': widget.gymId});
      } else {
        await _api.updateGymMembershipType(token, type.id, data);
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _delete(GymMembershipType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete membership type?'),
        content: Text('This will delete "${type.name}". Existing memberships referencing it will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteGymMembershipType(token, type.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.gymName} · Membership Types')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Type'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _types.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.card_membership_outlined,
                              size: 48, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          const Text('No membership types yet'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: _types.length,
                      itemBuilder: (_, i) {
                        final t = _types[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(t.name),
                            subtitle: Text(
                              '\$${t.monthlyCost.toStringAsFixed(2)}/mo · ${t.isActive ? 'Active' : 'Inactive'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _openForm(type: t),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Theme.of(context).colorScheme.error),
                                  onPressed: () => _delete(t),
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
