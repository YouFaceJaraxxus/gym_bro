import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'business_profile_page.dart';
import 'business_widgets.dart';

/// Find gyms and shops by name or location, optionally just one kind.
class BusinessSearchPage extends StatefulWidget {
  const BusinessSearchPage({super.key});

  @override
  State<BusinessSearchPage> createState() => _BusinessSearchPageState();
}

class _BusinessSearchPageState extends State<BusinessSearchPage> {
  final _api = ApiService();
  final _query = TextEditingController();
  Timer? _debounce;

  /// 'gym', 'shop' or null for both.
  String? _side;
  List<Business>? _results;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final request = ++_request;
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.searchBusinesses(
        token,
        query: _query.text.trim(),
        side: _side,
      );
      if (mounted && request == _request) {
        setState(() {
          _results = results;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rolesSearchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              controller: _query,
              hintText: l10n.rolesSearchHint,
              leading: const Icon(Icons.search),
              onChanged: _onQueryChanged,
              elevation: const WidgetStatePropertyAll(0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                for (final (side, label) in [
                  (null, l10n.rolesSearchAll),
                  ('gym', l10n.rolesKindGym),
                  ('shop', l10n.rolesKindShop),
                ]) ...[
                  ChoiceChip(
                    label: Text(label),
                    selected: _side == side,
                    onSelected: (_) {
                      setState(() => _side = side);
                      _search();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!))
                : results == null
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty
                ? Center(child: Text(l10n.rolesSearchEmpty))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final b = results[i];
                      return ListTile(
                        leading: BusinessAvatar(
                          logo: b.logo,
                          hasGym: b.hasGym,
                          hasShop: b.hasShop,
                        ),
                        title: Text(b.name),
                        subtitle: Text(
                          '${businessKindLabel(l10n, b.hasGym, b.hasShop)} · ${b.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BusinessProfilePage(businessId: b.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
