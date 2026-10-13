import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class QuantityInput extends StatelessWidget {
  const QuantityInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = max == null || value < max!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: context.l10n.businessQuantityDecrease,
          icon: const Icon(Icons.remove),
          onPressed: canDecrement ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 48,
          child: Semantics(
            label: context.l10n.businessQuantityValue(value),
            excludeSemantics: true,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: context.l10n.businessQuantityIncrease,
          icon: const Icon(Icons.add),
          onPressed: canIncrement ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
