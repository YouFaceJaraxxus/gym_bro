// Push notifications (Firebase Cloud Messaging).
//
// Push is OFF unless the app is built with all four Firebase dart-defines
// (values from Firebase console → Project settings → Your apps; use the
// Android app's values for Android builds and the iOS app's for iOS):
//
//   --dart-define=FIREBASE_API_KEY=...             (apiKey / API_KEY)
//   --dart-define=FIREBASE_APP_ID=...              (mobilesdk_app_id / GOOGLE_APP_ID)
//   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... (project_number / GCM_SENDER_ID)
//   --dart-define=FIREBASE_PROJECT_ID=...          (project_id)
//   --dart-define=FIREBASE_IOS_BUNDLE_ID=...       (optional, iOS only)
//
// or put them in a JSON file and pass --dart-define-from-file=firebase.json.
// Without them nothing Firebase-related runs and the app works as before
// (in-app notifications only). The API side needs FCM_SERVICE_ACCOUNT_B64
// (see apps/gym_bro_api/.env.template) to actually send pushes.
//
// iOS additionally needs the Push Notifications capability and an APNs key
// uploaded to Firebase; Android 13+ asks for the notification permission at
// the first registration.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/app_localizations.dart';
import 'api_service.dart';
import 'auth_manager.dart';
import 'notification_router.dart';
import 'settings_service.dart';

/// Registers this device for push, shows pushes that arrive while the app is
/// in the foreground, and routes taps through [NotificationRouter].
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  /// Strings for the app language (or the device's), resolved outside any
  /// widget tree.
  static AppLocalizations _l10n() {
    final locale =
        SettingsService.instance.locale.value ??
        PlatformDispatcher.instance.locale;
    return lookupAppLocalizations(
      locale.languageCode == 'sr'
          ? const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn')
          : const Locale('en'),
    );
  }

  /// Matches the channel the API puts on Android pushes (_shared/notify.ts).
  /// The name is the brand; the description follows the app language
  /// (Android updates it whenever the channel is re-created).
  static AndroidNotificationChannel get _androidChannel =>
      AndroidNotificationChannel(
        'gym_bro_default',
        'Gym Bro',
        description: _l10n().shellPushChannelDescription,
        importance: Importance.high,
      );

  /// True when the build has every Firebase dart-define.
  static bool get isConfigured =>
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  late final _api =
      ApiService(); // lazy: constructing it starts offline monitoring
  final _local = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  Future<bool>? _initFuture;
  String? _registeredToken;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Sets up Firebase and the notification listeners. Safe to call more than
  /// once; does nothing (and returns false) when push isn't configured.
  /// Doesn't ask for permission — that happens on the first registration.
  Future<bool> init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    return _initFuture ??= _init();
  }

  Future<bool> _init() async {
    if (!isConfigured) return false;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          iosBundleId: _iosBundleId.isEmpty ? null : _iosBundleId,
        ),
      );

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _openPayload(response.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      final messaging = FirebaseMessaging.instance;
      // iOS shows foreground pushes through flutter_local_notifications
      // instead, so the system banner doesn't appear twice.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);

      // Cold start from a tapped push (FCM or a local notification).
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openMessage(initial);
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _openPayload(launch!.notificationResponse?.payload);
      }
      return true;
    } catch (e) {
      debugPrint('PushService: Firebase init failed, push disabled: $e');
      return false;
    }
  }

  /// Asks for permission (first time only) and registers this device's FCM
  /// token for the signed-in user, then keeps it registered when FCM rotates
  /// it. Skipped while impersonating.
  Future<void> registerCurrentUser() async {
    final navKey = _navigatorKey;
    if (navKey == null || !await init(navKey)) return;
    if (!AuthManager.instance.hasSession ||
        AuthManager.instance.isImpersonating) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;

    if (Platform.isIOS) {
      // The FCM token needs the APNs token, which can lag a moment behind.
      for (var i = 0; i < 5 && await messaging.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    final token = await messaging.getToken();
    if (token != null) await _register(token);

    _tokenRefreshSub ??= messaging.onTokenRefresh.listen((t) {
      if (AuthManager.instance.hasSession &&
          !AuthManager.instance.isImpersonating) {
        _register(t).catchError((Object e) {
          debugPrint('PushService: token refresh registration failed: $e');
        });
      }
    });
  }

  /// Removes this device's token from the signed-in user (logout, or before
  /// impersonating). Best effort; never throws.
  Future<void> unregister() async {
    var token = _registeredToken;
    _registeredToken = null;
    if (!AuthManager.instance.hasSession) return;
    // Registration may still be in flight (e.g. logout right after launch).
    if (token == null && await (_initFuture ?? Future.value(false))) {
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
    }
    if (token == null) return;
    try {
      final apiToken = await AuthManager.instance.getValidToken();
      await _api.unregisterDevice(apiToken, token);
    } catch (e) {
      debugPrint('PushService: unregister failed: $e');
    }
  }

  Future<void> _register(String token) async {
    final apiToken = await AuthManager.instance.getValidToken();
    await _api.registerDevice(
      apiToken,
      deviceToken: token,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
    _registeredToken = token;
  }

  // ── Incoming messages ───────────────────────────────────────────────────────

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final channel = _androidChannel;
    await _local.show(
      id:
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _openMessage(RemoteMessage message) => _route(message.data);

  void _openPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _route(jsonDecode(payload) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('PushService: bad notification payload: $e');
    }
  }

  /// Push data is `{type, notification_id, metadata: "<json string>"}`.
  void _route(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return;
    Map<String, dynamic> metadata = const {};
    final raw = data['metadata'];
    if (raw is String && raw.isNotEmpty) {
      try {
        metadata = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    } else if (raw is Map) {
      metadata = Map<String, dynamic>.from(raw);
    }
    _openWhenReady(type, metadata);
  }

  /// Waits for the navigator and a signed-in profile (cold start restores the
  /// session first), then opens the target screen.
  Future<void> _openWhenReady(
    String type,
    Map<String, dynamic> metadata,
  ) async {
    for (var i = 0; i < 40; i++) {
      final context = _navigatorKey?.currentContext;
      if (context != null && AuthManager.instance.profile != null) {
        // Give the home route a frame to settle after a cold start.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final ctx = _navigatorKey?.currentContext;
        if (ctx != null && ctx.mounted) {
          await NotificationRouter.open(ctx, type, metadata);
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}
