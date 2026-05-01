import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class InviteAcceptPage extends StatefulWidget {
  const InviteAcceptPage({super.key, required this.notification});

  final AppNotification notification;

  @override
  State<InviteAcceptPage> createState() => _InviteAcceptPageState();
}

class _InviteAcceptPageState extends State<InviteAcceptPage> {
  final _api = ApiService();
  bool _loading = false;

  AppNotification get _n => widget.notification;

  String get _entityName => _n.entityName ?? 'the organisation';

  String get _roleLabel {
    if (_n.type == NotificationType.vendorShopInvite) return 'Vendor';
    return switch (_n.employeeType) {
      'employee_trainer' => 'Employee Trainer',
      _ => 'Employee',
    };
  }

  String get _locationLabel =>
      _n.type == NotificationType.vendorShopInvite ? 'shop' : 'gym';

  Future<void> _respond(bool accept) async {
    setState(() => _loading = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      if (accept) {
        await _api.acceptInvite(token, _n.id);
      } else {
        await _api.declineInvite(token, _n.id);
      }
      if (mounted) Navigator.pop(context, accept);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _n.inviteStatus;

    final alreadyActed = status == InviteStatus.accepted ||
        status == InviteStatus.declined;

    return Scaffold(
      appBar: AppBar(title: const Text('Invitation')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _n.type == NotificationType.vendorShopInvite
                  ? Icons.storefront_outlined
                  : Icons.fitness_center_outlined,
              size: 64,
              color: cs.primary,
            ),
            const SizedBox(height: 24),
            Text(
              _n.title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You have been invited to work at $_entityName as $_roleLabel.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (_n.body != null && _n.body != _n.title) ...[
              const SizedBox(height: 8),
              Text(
                _n.body!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 40),
            if (alreadyActed) ...[
              _StatusBadge(
                accepted: status == InviteStatus.accepted,
                entityName: _entityName,
                roleLabel: _roleLabel,
                locationLabel: _locationLabel,
              ),
            ] else if (_loading) ...[
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              FilledButton.icon(
                onPressed: () => _respond(true),
                icon: const Icon(Icons.check),
                label: Text('Accept — join $_entityName'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _respond(false),
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool accepted;
  final String entityName;
  final String roleLabel;
  final String locationLabel;

  const _StatusBadge({
    required this.accepted,
    required this.entityName,
    required this.roleLabel,
    required this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: accepted
            ? cs.primaryContainer
            : cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            accepted ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: accepted ? cs.onPrimaryContainer : cs.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              accepted
                  ? 'You joined $entityName as $roleLabel'
                  : 'You declined this invitation',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: accepted
                        ? cs.onPrimaryContainer
                        : cs.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
