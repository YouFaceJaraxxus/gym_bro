import 'package:flutter/material.dart';

// ── Typed confirmation dialog ─────────────────────────────────────────────────

/// Destructive-action confirmation that only enables the action once the user
/// has typed [confirmText] exactly. Pops `true` when confirmed.
class TypedConfirmDialog extends StatefulWidget {
  const TypedConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String confirmText;
  final String actionLabel;

  @override
  State<TypedConfirmDialog> createState() => _TypedConfirmDialogState();
}

class _TypedConfirmDialogState extends State<TypedConfirmDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final matches = _ctrl.text.trim() == widget.confirmText;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          Text('Type ${widget.confirmText} to confirm.'),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: widget.confirmText),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
