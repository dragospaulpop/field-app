import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Ask for the location when the user does the thing that needs it — never at
/// launch. Granted: true. Denied once: false, and the next press asks again.
/// Denied for good ("Don't allow" twice on Android 11+): the system will not
/// show its dialog any more, so offer the app's Settings.
Future<bool> ensureLocation(BuildContext context) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (context.mounted) {
      await _offer(context, 'Location is off on this phone', Geolocator.openLocationSettings);
    }
    return false;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    if (context.mounted) {
      await _offer(context, 'Location is off for the field app', Geolocator.openAppSettings);
    }
    return false;
  }
  return permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;
}

Future<void> _offer(BuildContext context, String title, Future<bool> Function() open) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(
            'The field app tags your photos and new pins with where you stand. '
            'You can turn it on in Settings → Permissions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              open();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
