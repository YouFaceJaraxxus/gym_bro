import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/payment.dart';
import '../models/membership.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'shop/order_widgets.dart' show PaymentsConfigCache;

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

  /// Accepts both `12.50` and the Serbian-style `12,50`.
  double? _parseCost(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  String get _locale => Localizations.localeOf(context).toString();

  String _currencySymbol() {
    final currency = PaymentsConfigCache.current.currency.toUpperCase();
    try {
      return NumberFormat.simpleCurrency(locale: _locale, name: currency)
          .currencySymbol;
    } catch (_) {
      return currency;
    }
  }

  Future<void> _openForm({GymMembershipType? type}) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController(text: type?.name ?? '');
    final costCtrl = TextEditingController(
        text: type != null ? type.monthlyCost.toStringAsFixed(2) : '');
    var isActive = type?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(type == null
              ? l10n.businessMgmtNewMembershipType
              : l10n.businessMgmtEditMembershipType),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.businessMgmtName),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: costCtrl,
                  decoration: InputDecoration(
                      labelText: l10n.businessMgmtMonthlyCost,
                      prefixText: '${_currencySymbol()} '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.commonRequired;
                    if (_parseCost(v) == null) return l10n.businessMgmtInvalidNumber;
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.businessMgmtTypeActive),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: Text(l10n.commonSave),
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
        'monthly_cost': _parseCost(costCtrl.text)!,
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
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.businessMgmtDeleteMembershipTypeTitle),
        content: Text(l10n.businessMgmtDeleteMembershipTypeMessage(type.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonDelete)),
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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.businessMgmtMembershipTypesTitle(widget.gymName))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(l10n.businessMgmtAddType),
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
                      FilledButton(
                          onPressed: _load, child: Text(l10n.commonRetry)),
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
                          Text(l10n.businessMgmtNoMembershipTypesYet),
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
                              '${l10n.businessMgmtPerMonthShort(formatMoney(t.monthlyCost, PaymentsConfigCache.current.currency, _locale))}'
                              ' · ${t.isActive ? l10n.businessMgmtTypeActive : l10n.businessMgmtTypeInactive}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: l10n.businessMgmtEditNamed(t.name),
                                  onPressed: () => _openForm(type: t),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Theme.of(context).colorScheme.error),
                                  tooltip: l10n.businessMgmtDeleteNamed(t.name),
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
