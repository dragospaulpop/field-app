import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'contract/contract.dart' show Entrance;

final notifications = FlutterLocalNotificationsPlugin();

/// Step 4: the one place that decides where a notification goes. Pure: a
/// notification's data in, the app's route out (null: nowhere, stay put).
/// Step 5's pushes carry the same data; step 6 tests this function alone.
String? routeForNotification(Map<String, dynamic> data) {
  final id = data['entranceId'];
  return id is String && id.isNotEmpty ? '/entrances/$id' : null;
}

/// The payload travels as a string (JSON); a broken one goes nowhere.
String? _routeFor(String? payload) {
  if (payload == null) return null;
  try {
    return routeForNotification(jsonDecode(payload) as Map<String, dynamic>);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

/// The channel the worker would mute: "remind me later" notifications.
/// Its importance is fixed the first time it is created: choose it now.
const remindersChannel = AndroidNotificationChannel(
  'reminders',
  'Reminders',
  description: 'The reminders you ask for on an entrance.',
  importance: Importance.high,
);

AndroidFlutterLocalNotificationsPlugin? get _android =>
    notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

/// Once, in main(): the plugin, the time zones, the channel, and the tap.
/// Returns the route of the notification that STARTED the app (cold start),
/// if any: onDidReceiveNotificationResponse does not see that tap.
Future<String?> initNotifications(void Function(String route) open) async {
  if (kIsWeb) return null; // phone-only in this course (the button says so)
  // The time zone database. tz.local stays UTC: right for "in a minute",
  // wrong for "tomorrow at 9" (that needs the phone's zone, flutter_timezone).
  tzdata.initializeTimeZones();
  await notifications.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    // A tap while the app runs, in the foreground or in the background.
    onDidReceiveNotificationResponse: (response) {
      if (_routeFor(response.payload) case final route?) open(route);
    },
  );
  // The channel exists before anyone is asked: Android 13 shows no prompt
  // for an app without a channel.
  await _android?.createNotificationChannel(remindersChannel);
  final launch = await notifications.getNotificationAppLaunchDetails();
  return launch?.didNotificationLaunchApp ?? false ? _routeFor(launch!.notificationResponse?.payload) : null;
}

/// "Remind me in 1 minute": ask for the permission in context (the first
/// time the worker wants a notification), then schedule. Returns what the
/// worker reads.
Future<String> remindInAMinute(Entrance e) async {
  if (kIsWeb) return 'Reminders are phone-only: open the app on your phone.';
  // Android 13+: POST_NOTIFICATIONS, a runtime permission. Denied twice, the
  // system stops asking: then only the app's settings can turn it on.
  final allowed = await _android?.requestNotificationsPermission() ?? false;
  if (!allowed) return 'Notifications are off for this app: turn them on in Settings › Apps › field_app.';
  await notifications.zonedSchedule(
    id: e.id.hashCode & 0x7fffffff, // one reminder per entrance: a new one replaces the old
    scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
    // Inexact: Android may deliver it a little late (Doze); exact alarms
    // need a permission a survey app should not ask for.
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    title: 'Back to ${e.street} ${e.number}',
    body: '${e.entranceName}: you asked for a reminder.',
    payload: jsonEncode({'entranceId': e.id}),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        remindersChannel.id,
        remindersChannel.name,
        channelDescription: remindersChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
  return 'Reminder set: in about a minute.';
}
