import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notifications.dart';
import 'supabase_repositories.dart';

/// Step 5: the channel of the office's pushes. The Edge Function names it
/// (android.notification.channel_id); the app creates it at start.
const assignmentsChannel = AndroidNotificationChannel(
  'assignments',
  'Assignments',
  description: 'When the office assigns you an entrance.',
  importance: Importance.high,
);

/// A message that arrives while the app is not running goes here, in its own
/// isolate: top-level, and kept in release builds by the pragma. Our pushes
/// are notification messages: Android shows them by itself, so there is
/// nothing to do; the tap is handled at start (getInitialMessage).
@pragma('vm:entry-point')
Future<void> onBackgroundPush(RemoteMessage message) async {}

/// Once, in main(), after initNotifications. Returns the route of the push
/// whose tap STARTED the app, if any. The options come from main.dart, the
/// only file that imports the git-ignored firebase_options.dart: the tests
/// (which import sync.dart, which imports this file) compile without it.
Future<String?> initPush(FirebaseOptions Function() options, void Function(String route) open) async {
  if (kIsWeb) return null; // phone-only in this course
  await Firebase.initializeApp(options: options());
  FirebaseMessaging.onBackgroundMessage(onBackgroundPush);
  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(assignmentsChannel);
  // A tap while the app was in the background.
  FirebaseMessaging.onMessageOpenedApp.listen((m) {
    if (routeForNotification(m.data) case final route?) open(route);
  });
  // In the foreground FCM shows nothing: show it with step 4's plugin. Its
  // tap goes through step 4's callback, with the same data.
  FirebaseMessaging.onMessage.listen((m) {
    final n = m.notification;
    if (n == null) return;
    notifications.show(
      id: m.hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      payload: jsonEncode(m.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(assignmentsChannel.id, assignmentsChannel.name,
            channelDescription: assignmentsChannel.description, importance: Importance.high, priority: Priority.high),
      ),
    );
  });
  final first = await FirebaseMessaging.instance.getInitialMessage();
  return first == null ? null : routeForNotification(first.data);
}

StreamSubscription<String>? _refresh;
String? _token; // this phone's address, as registered in this session

/// After sign-in: this phone's FCM address goes to push_tokens, now and
/// whenever FCM changes it. Only through the RPC: it moves a row that
/// belonged to the previous worker on this phone.
Future<void> registerThisPhone() async {
  if (kIsWeb) return;
  try {
    // Android 13+: the notification permission (the same as step 4's).
    await FirebaseMessaging.instance.requestPermission();
    // firebase_messaging 17 marks the token API deprecated in favour of
    // Firebase Installation IDs (register / onRegistered). Our sender sends
    // to message.token, which takes this registration token: keep it until
    // the sender moves to FIDs.
    // ignore: deprecated_member_use
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _register(token);
    // ignore: deprecated_member_use
    _refresh ??= FirebaseMessaging.instance.onTokenRefresh.listen(_register);
  } catch (e) {
    debugPrint('push registration failed: $e'); // offline: the next start tries again
  }
}

Future<void> _register(String token) async {
  await supabase.rpc('register_push_token', params: {'p_token': token, 'p_platform': 'android'});
  _token = token;
}

/// Before sign-out: this phone's row goes, or this phone would keep receiving
/// the worker's pushes. Throws when it cannot (offline, a server error): the
/// caller then keeps the worker signed in, and the token stays in memory.
Future<void> forgetThisPhone() async {
  if (kIsWeb) return;
  // Never registered in this session (it failed at sign-in): ask FCM. If FCM
  // cannot answer (no Play services), this phone filed no row: sign out anyway.
  // ignore: deprecated_member_use
  final token = _token ?? await FirebaseMessaging.instance.getToken().catchError((_) => null);
  if (token != null) await supabase.from('push_tokens').delete().eq('token', token);
  await _refresh?.cancel();
  _refresh = null;
  _token = null;
}
