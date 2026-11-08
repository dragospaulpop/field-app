import * as Notifications from 'expo-notifications';
import { type Href, router } from 'expo-router';
import { useEffect } from 'react';
import { Platform } from 'react-native';

// Week 6, step 4: local notifications. The app itself schedules them; no server.
// Step 5 adds push, which shares the permission, the handler and the tap.

/** Notifications on this platform? Not on the web (the browser's are another API). */
export const notificationsWork = Platform.OS !== 'web';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Where a notification's tap goes, from its data: the one place that decides
 * (steps 4 and 5 call it, step 6 tests it). The data carries an id, never the
 * entrance itself; anything else opens nothing.
 */
export function routeForNotification(data: unknown): string | null {
  if (typeof data !== 'object' || data === null) return null;
  const id = (data as Record<string, unknown>).entranceId;
  return typeof id === 'string' && UUID.test(id) ? `/entrances/${id}` : null;
}

// While the app is open a notification is shown too (banner and list), quietly.
if (notificationsWork) {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: false,
      shouldSetBadge: false,
    }),
  });
}

/**
 * At start, on Android: the channel. Android 13+ shows the permission prompt
 * only once a channel exists, and a channel's importance is fixed at creation
 * (after that it is the user's), so choose it here, once.
 */
export async function createChannels() {
  if (Platform.OS !== 'android') return;
  await Notifications.setNotificationChannelAsync('reminders', {
    name: 'Reminders',
    description: 'Reminders you set yourself on an entrance',
    importance: Notifications.AndroidImportance.DEFAULT,
  });
}

/**
 * Ask when the worker wants a notification, never at launch. Returns null when
 * notifications may be shown, else the sentence to show instead.
 */
export async function mayNotify(): Promise<string | null> {
  const now = await Notifications.getPermissionsAsync();
  if (now.granted) return null;
  // Denied twice on Android is final: only the phone's settings can turn it back on.
  if (!now.canAskAgain) return 'Notifications are off for this app: turn them on in the phone’s settings.';
  const asked = await Notifications.requestPermissionsAsync();
  return asked.granted ? null : 'No reminder: notifications are not allowed.';
}

/** "Remind me in 1 minute": inexact (the OS may deliver it a little later), no exact-alarm permission. */
export function remindInOneMinute(entranceId: string, label: string) {
  return Notifications.scheduleNotificationAsync({
    content: { title: 'Back to this entrance', body: label, data: { entranceId } },
    trigger: { type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL, seconds: 60, channelId: 'reminders' },
  });
}

/**
 * Behind the sign-in gate: a tap while the app runs or sleeps (the listener),
 * and the tap that started the app (the last response, read once, then cleared
 * so the next launch does not open it again).
 */
export function useNotificationRouting() {
  useEffect(() => {
    if (!notificationsWork) return;
    const open = (response: Notifications.NotificationResponse | null) => {
      const to = routeForNotification(response?.notification.request.content.data);
      if (!to) return;
      router.push(to as Href);
      Notifications.clearLastNotificationResponse();
    };
    open(Notifications.getLastNotificationResponse());
    const sub = Notifications.addNotificationResponseReceivedListener(open);
    return () => sub.remove();
  }, []);
}
