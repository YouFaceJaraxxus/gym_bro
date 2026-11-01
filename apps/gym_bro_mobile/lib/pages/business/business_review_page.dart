import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/person_tile.dart';
import 'business_manage_page.dart';
import 'business_widgets.dart';

/// Super users: gyms and shops by review status. Pending applications are
/// approved or rejected (with a reason the owner sees); live ones can be
/// blocked, and blocked or rejected ones approved again.
class BusinessReviewPage extends StatefulWidget {
  const BusinessReviewPage({super.key});

  @override
  State<BusinessReviewPage> createState() => _BusinessReviewPageState();
}

class _BusinessReviewPageState extends State<BusinessReviewPage> {
  final _api = ApiService();

  BusinessStatus _status = BusinessStatus.pending;
  List<BusinessApplication>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = _status;
    setState(() => _items = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final items = await _api.getBusinessReviewQueue(token, status: status);
      if (mounted && status == _status) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _review(BusinessApplication app, BusinessStatus to) async {
    final l10n = context.l10n;
    String? note;
    if (to != BusinessStatus.approved) {
      note = await showDialog<String>(
        context: context,
        builder: (_) => _NoteDialog(
          title: to == BusinessStatus.blocked
              ? l10n.rolesReviewBlockTitle(app.business.name)
              : l10n.rolesReviewRejectTitle(app.business.name),
        ),
      );
      if (note == null) return;
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.reviewBusiness(token, app.business.id, status: to, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.rolesReviewDone(
              app.business.name,
              businessStatusLabel(l10n, to),
            ),
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rolesMenuReviewQueue)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final s in BusinessStatus.values)
                    ChoiceChip(
                      label: Text(businessStatusLabel(l10n, s)),
                      selected: _status == s,
                      onSelected: (_) {
                        if (_status == s) return;
                        setState(() => _status = s);
                        _load();
                      },
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  )
                : items == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: items.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(child: Text(l10n.rolesReviewEmpty)),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: items.length,
                            itemBuilder: (context, i) => _ApplicationCard(
                              app: items[i],
                              onReview: (to) => _review(items[i], to),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app, required this.onReview});

  final BusinessApplication app;
  final ValueChanged<BusinessStatus> onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final b = app.business;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(app.createdAt.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessManagePage(businessId: b.id),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BusinessAvatar(logo: b.logo, hasGym: b.hasGym, hasShop: b.hasShop),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name, style: text.titleMedium),
                        Text(
                          '${businessKindLabel(l10n, b.hasGym, b.hasShop)} · ${b.location}',
                          style: text.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          l10n.rolesReviewApplied(date),
                          style: text.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if ((b.bio ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(b.bio!, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (app.applicantId != null) ...[
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(app.applicantName ?? ''),
                subtitle: Text(
                  [
                    if (app.applicantUsername != null) '@${app.applicantUsername}',
                    ?app.applicantEmail,
                  ].join(' · '),
                ),
                onTap: () => openUserProfile(context, app.applicantId!),
              ),
            ],
            if ((b.reviewNote ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l10n.rolesReviewNote(b.reviewNote!),
                  style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (b.status == BusinessStatus.pending)
                  TextButton(
                    onPressed: () => onReview(BusinessStatus.rejected),
                    child: Text(l10n.rolesReviewReject),
                  ),
                if (b.status == BusinessStatus.approved)
                  TextButton(
                    onPressed: () => onReview(BusinessStatus.blocked),
                    style: TextButton.styleFrom(foregroundColor: cs.error),
                    child: Text(l10n.rolesReviewBlock),
                  ),
                if (b.status != BusinessStatus.approved)
                  FilledButton(
                    onPressed: () => onReview(BusinessStatus.approved),
                    child: Text(
                      b.status == BusinessStatus.blocked
                          ? l10n.rolesReviewUnblock
                          : l10n.rolesReviewApprove,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for the reason the owner will see. Pops the note, or null.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title});

  final String title;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 500,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(
          labelText: l10n.rolesReviewReason,
          helperText: l10n.rolesReviewReasonHint,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _ctrl.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
