import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../l10n/l10n.dart';
import '../../models/food_log.dart';
import '../../models/meal_plan.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../food_item_form_page.dart';

final _barcodeRe = RegExp(r'^\d{6,14}$');

/// Full-screen product barcode scanner. Pops with the scanned (or manually
/// entered) code as a String, or null when cancelled.
class BarcodeScanPage extends StatefulWidget {
  /// Defaults to "Scan barcode".
  final String? title;

  const BarcodeScanPage({super.key, this.title});

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, code);
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final raw = b.rawValue?.trim();
      if (raw != null && _barcodeRe.hasMatch(raw)) {
        _finish(raw);
        return;
      }
    }
  }

  Future<void> _manualEntry() async {
    final code = await showManualBarcodeDialog(context);
    if (code != null && mounted) _finish(code);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? l10n.nutritionScanBarcode),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (!state.isInitialized || state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? l10n.nutritionTorchOff : l10n.nutritionTorchOn,
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          IconButton(
            tooltip: l10n.nutritionEnterCodeManually,
            icon: const Icon(Icons.keyboard),
            onPressed: _manualEntry,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(
              error: error,
              onManualEntry: _manualEntry,
            ),
          ),
          // Aiming frame
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.primary, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.nutritionPointCameraAtBarcode,
                    style: TextStyle(color: cs.onSurface),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _manualEntry,
                  icon: const Icon(Icons.keyboard),
                  label: Text(l10n.nutritionEnterCodeManually),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onManualEntry;

  const _ScannerError({required this.error, required this.onManualEntry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final l10n = context.l10n;
    return ColoredBox(
      color: cs.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(denied ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
                  size: 56, color: cs.outline),
              const SizedBox(height: 16),
              Text(
                denied ? l10n.nutritionCameraAccessOff : l10n.nutritionCameraUnavailable,
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? l10n.nutritionCameraAccessOffHint
                    : l10n.nutritionCameraUnavailableHint,
                style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onManualEntry,
                icon: const Icon(Icons.keyboard),
                label: Text(l10n.nutritionEnterCodeManually),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog asking for a 6–14 digit barcode. Returns the code or null.
Future<String?> showManualBarcodeDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final valid = _barcodeRe.hasMatch(controller.text.trim());
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.nutritionEnterBarcode),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 14,
            decoration: InputDecoration(
              labelText: 'EAN / UPC',
              hintText: l10n.nutritionBarcodeExample('3017620422003'),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              if (_barcodeRe.hasMatch(v.trim())) Navigator.pop(ctx, v.trim());
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: valid ? () => Navigator.pop(ctx, controller.text.trim()) : null,
              child: Text(l10n.nutritionLookUp),
            ),
          ],
        );
      },
    ),
  ).whenComplete(controller.dispose);
}

/// Scans a barcode and resolves it to a food item: an existing one, one
/// imported from Open Food Facts, or (when unknown) one the user creates.
/// Returns null when cancelled or on failure (a snackbar explains why).
Future<FoodItem?> scanFoodItem(BuildContext context) async {
  final code = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const BarcodeScanPage()),
  );
  if (code == null || !context.mounted) return null;
  return lookupFoodItemByBarcode(context, code);
}

/// Looks up [code] with a blocking progress dialog. See [scanFoodItem].
Future<FoodItem?> lookupFoodItemByBarcode(BuildContext context, String code) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final cs = Theme.of(context).colorScheme;
  final l10n = context.l10n;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.nutritionLookingUpProduct)),
          ],
        ),
      ),
    ),
  );

  try {
    final token = await AuthManager.instance.getValidToken();
    final result = await ApiService().lookupBarcode(token, code);
    navigator.pop();
    if (result.imported) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.nutritionImportedFromOff(result.item.name)),
      ));
    }
    return result.item;
  } on BarcodeNotFoundException {
    navigator.pop();
    if (!context.mounted) return null;
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.nutritionProductNotFound),
        content: Text(l10n.nutritionProductNotFoundMessage(code)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.nutritionCreateItem)),
        ],
      ),
    );
    if (create != true || !context.mounted) return null;
    return Navigator.push<FoodItem>(
      context,
      MaterialPageRoute(builder: (_) => FoodItemFormPage(initialBarcode: code)),
    );
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(e.toString().replaceFirst('Exception: ', ''), style: TextStyle(color: cs.onError)),
      backgroundColor: cs.error,
    ));
    return null;
  }
}
