import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/user_search_result.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/user_search_field.dart';

class AddGymMemberPage extends StatefulWidget {
  const AddGymMemberPage({super.key, required this.gymId});

  final String gymId;

  @override
  State<AddGymMemberPage> createState() => _AddGymMemberPageState();
}

class _AddGymMemberPageState extends State<AddGymMemberPage> {
  final _api = ApiService();

  /// User ids already members here, hidden from the search results.
  Set<String> _memberUserIds = {};
  bool _loading = true;
  String? _error;
  String? _adding; // user id currently being added

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
      final memberRows = await _api.getMembers(token, gymId: widget.gymId);
      if (mounted) {
        setState(() {
          _memberUserIds =
              memberRows.map((r) => r['user_id'] as String).toSet();
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

  Future<void> _add(UserSearchResult user) async {
    setState(() => _adding = user.id);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.addMember(token, user.id, widget.gymId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _adding = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.businessGymAddMember)),
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
                          onPressed: _load,
                          child: Text(context.l10n.commonRetry)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: UserSearchField(
                    excludeUserIds: _memberUserIds,
                    addingUserId: _adding,
                    onSelect: _add,
                  ),
                ),
    );
  }
}
