import 'package:flutter/material.dart';
import '../models/shop_item.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/quantity_input.dart';

class ShopItemFormPage extends StatefulWidget {
  const ShopItemFormPage(
      {super.key, required this.shopId, this.item});

  final String shopId;

  /// Null = create mode, non-null = edit mode.
  final ShopItem? item;

  @override
  State<ShopItemFormPage> createState() => _ShopItemFormPageState();
}

class _ShopItemFormPageState extends State<ShopItemFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;

  late ShopItemType _type;
  late int _quantity;
  late bool _isActive;
  DateTime? _activeUntil;

  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _nameCtrl = TextEditingController(text: it?.name ?? '');
    _descCtrl = TextEditingController(text: it?.description ?? '');
    _priceCtrl = TextEditingController(
        text: it != null ? it.price.toStringAsFixed(2) : '');
    _type = it?.type ?? ShopItemType.equipment;
    _quantity = it?.quantity ?? 1;
    _isActive = it?.isActive ?? true;
    _activeUntil = it?.activeUntil;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _activeUntil ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _activeUntil = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await AuthManager.instance.getValidToken();
      final data = <String, dynamic>{
        'shop_id': widget.shopId,
        'type': _type.apiValue,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text.trim()),
        'quantity': _quantity,
        'is_active': _isActive,
        'active_until': _activeUntil?.toIso8601String(),
      };

      if (_isEditing) {
        // shop_id is immutable — strip it from the update payload
        data.remove('shop_id');
        await _api.updateShopItem(token, widget.item!.id, data);
      } else {
        await _api.createShopItem(token, data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit Item' : 'New Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration:
                    const InputDecoration(labelText: 'Price', prefixText: '\$'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Quantity'),
                  const SizedBox(width: 16),
                  QuantityInput(
                    value: _quantity,
                    onChanged: (v) => setState(() => _quantity = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ShopItemType>(
                key: ValueKey(_type),
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final t in ShopItemType.values)
                    DropdownMenuItem(
                        value: t, child: Text(t.displayName)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active until'),
                subtitle: Text(_activeUntil == null
                    ? 'No expiry'
                    : '${_activeUntil!.year}-'
                        '${_activeUntil!.month.toString().padLeft(2, '0')}-'
                        '${_activeUntil!.day.toString().padLeft(2, '0')}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_activeUntil != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            setState(() => _activeUntil = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
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
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'Save Changes' : 'Add Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
