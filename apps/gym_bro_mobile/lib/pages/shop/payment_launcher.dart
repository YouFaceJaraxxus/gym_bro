import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';

/// Runs a Stripe Checkout round trip:
///
/// 1. asks the API for a Checkout Session ([checkout]),
/// 2. opens it in the browser,
/// 3. when the app comes back (or the `gymbroo://payments/return` link
///    arrives), polls `GET /payments/:id` every 2 s for up to ~30 s until the
///    webhook has settled it,
/// 4. shows a SnackBar and calls [onFinished].
///
/// Returns the final payment, or null if checkout couldn't start.
class PaymentLauncher {
  PaymentLauncher._();

  static const _pollInterval = Duration(seconds: 2);
  static const _maxPolls = 15;

  static Future<Payment?> start(
    BuildContext context, {
    required Future<CheckoutSession> Function(ApiService api, String token)
    checkout,

    /// Shown when the payment succeeds; defaults to a generic message.
    String? successMessage,
    void Function(Payment payment)? onFinished,
  }) async {
    final l10n = context.l10n;
    final api = ApiService();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    void say(String msg) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }

    String token;
    CheckoutSession session;
    try {
      token = await AuthManager.instance.getValidToken();
      session = await checkout(api, token);
    } catch (e) {
      say(_message(e));
      return null;
    }

    // ── Wait for the user to come back from the browser ─────────────────────
    final returned = Completer<String>();
    Timer? resumeTimer;
    final lifecycle = AppLifecycleListener(
      onResume: () {
        // Give the return deep link (which carries success/cancelled) a moment
        // to arrive before falling back to polling.
        resumeTimer?.cancel();
        resumeTimer = Timer(const Duration(milliseconds: 800), () {
          if (!returned.isCompleted) returned.complete('resumed');
        });
      },
    );
    StreamSubscription<Uri>? linkSub;
    try {
      linkSub = AppLinks().uriLinkStream.listen((uri) {
        if (uri.host == 'payments' &&
            uri.queryParameters['payment_id'] == session.paymentId &&
            !returned.isCompleted) {
          returned.complete(uri.queryParameters['status'] ?? 'resumed');
        }
      });
    } catch (_) {
      // Deep links unavailable on this platform; resume polling still works.
    }

    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(session.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      lifecycle.dispose();
      await linkSub?.cancel();
      say(l10n.businessShopCouldNotOpenPaymentPage);
      api.cancelPayment(token, session.paymentId).ignore();
      return null;
    }

    final how = await returned.future;
    resumeTimer?.cancel();
    lifecycle.dispose();
    await linkSub?.cancel();

    // ── The user backed out on the Stripe page ──────────────────────────────
    if (how == 'cancelled') {
      try {
        final cancelled = await api.cancelPayment(
          await AuthManager.instance.getValidToken(),
          session.paymentId,
        );
        say(l10n.businessShopPaymentCancelled);
        onFinished?.call(cancelled);
        return cancelled;
      } catch (_) {
        // Already completed (or the cancel failed): fall through and poll.
      }
    }

    // ── Poll until the webhook settles the payment ──────────────────────────
    var dialogOpen = false;
    var stopped = false;
    if (navigator.mounted) {
      dialogOpen = true;
      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(l10n.businessShopConfirmingPayment)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                stopped = true;
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.commonClose),
            ),
          ],
        ),
      ).whenComplete(() => dialogOpen = false);
    }

    Payment? payment;
    for (var i = 0; i < _maxPolls && !stopped; i++) {
      try {
        payment = await api.getPayment(
          await AuthManager.instance.getValidToken(),
          session.paymentId,
        );
        if (!payment.isPending) break;
      } catch (_) {
        // Transient network error: keep trying until the time is up.
      }
      await Future<void>.delayed(_pollInterval);
    }
    if (dialogOpen && navigator.mounted) navigator.pop();

    if (payment == null) {
      say(l10n.businessShopPaymentNotConfirmedYet);
      return null;
    }
    say(switch (payment.status) {
      PaymentStatus.succeeded =>
        successMessage ?? l10n.businessShopPaymentSuccessful,
      PaymentStatus.failed => l10n.businessShopPaymentFailed,
      PaymentStatus.cancelled => l10n.businessShopPaymentCancelled,
      PaymentStatus.refunded => l10n.businessShopPaymentRefunded,
      PaymentStatus.pending => l10n.businessShopPaymentStillProcessing,
    });
    onFinished?.call(payment);
    return payment;
  }

  static String _message(Object e) =>
      e.toString().replaceFirst('Exception: ', '');
}
