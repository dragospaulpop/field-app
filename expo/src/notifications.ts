import * as Notifications from 'expo-notifications';
import { type Href, router } from 'expo-router';
import { useEffect } from 'react';
import { Platform } from 'react-native';
import { supabase } from './supabase';

// Week 6, step 4: local notifications. The app itself schedules them; no server.
// Step 5 adds push over FCM, which shares the permission, the handler and the tap.

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
  // Step 5: the office's pushes (the sender names this channel). HIGH: a heads-up banner.
  await Notifications.setNotificationChannelAsync('assignments', {
    name: 'Assignments',
    description: 'An entrance the office assigned to you',
    importance: Notifications.AndroidImportance.HIGH,
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
 * Behind the sign-in gate: the most recent tap on a notification, whether it
 * came while the app ran, slept, or started the app. Step 5 changed this from
 * a listener plus getLastNotificationResponse() read once at mount: a push that
 * STARTED the app reached it after that first read (the test's app opened on
 * the map). The hook re-renders whenever a new tap arrives, so it covers all three.
 */
function useRouting() {
  const last = Notifications.useLastNotificationResponse();
  useEffect(() => {
    const to = routeForNotification(last?.notification.request.content.data);
    if (!to) return;
    router.push(to as Href);
    Notifications.clearLastNotificationResponse(); // or the next launch opens it again
  }, [last]);
}

// The hook throws on the web ("not available on web"): there, nothing to route.
export const useNotificationRouting = notificationsWork ? useRouting : () => {};

// Step 5: this phone's FCM address, while a worker is signed in on it.
let pushToken: string | null = null;

async function registerPushToken(token: string) {
  pushToken = token;
  // The only way to write the table: the function files the row under auth.uid()
  // (and moves it, if another worker used this phone before).
  const { error } = await supabase.rpc('register_push_token', { p_token: token, p_platform: 'android' });
  if (error) console.warn('register_push_token', error.code, error.message);
}

/**
 * After sign-in: ask for the permission (an assignment is worth a notification,
 * so this is the moment), then store the phone's FCM address under the worker,
 * and again whenever FCM gives the phone a new one.
 */
export function usePushRegistration(uid: string) {
  useEffect(() => {
    if (Platform.OS !== 'android') return; // the web and iOS are not built here
    (async () => {
      const no = await mayNotify();
      if (no) console.warn('push: notifications not allowed; the address is stored anyway');
      // The NATIVE token (FCM's), not an Expo push token: our sender talks to FCM itself.
      const { data } = await Notifications.getDevicePushTokenAsync();
      await registerPushToken(data);
    })().catch((e) => console.warn('push token', e));
    const sub = Notifications.addPushTokenListener((t) => registerPushToken(t.data));
    return () => sub.remove();
  }, [uid]);
}

/**
 * Before signing out: this phone stops receiving the worker's pushes (its own
 * row only). Returns null when that is done, else the sentence to show instead
 * of signing out: signed out with the row still there, this phone would keep
 * receiving the worker's pushes, and nobody could delete the row any more.
 */
export async function forgetPushToken(): Promise<string | null> {
  if (Platform.OS !== 'android') return null;
  // No address yet this session (registration still running, or it failed): ask for it.
  // If the library cannot say (no Play services), this phone never filed a row either.
  pushToken ??= await Notifications.getDevicePushTokenAsync().then(
    (t) => t.data,
    () => null,
  );
  if (!pushToken) return null; // this phone has no address: nothing to forget
  // No usable token: the delete would go as anon and be refused. safeSignOut checks
  // first (and says why); this is the belt.
  if (!(await supabase.auth.getSession()).data.session) return 'Not signed out: your sign-in is not ready yet. Try again in a minute.';
  const { error } = await supabase.from('push_tokens').delete().eq('token', pushToken);
  if (error) return `Not signed out: this phone would keep receiving your pushes (${error.message}). Try again.`;
  pushToken = null;
  return null;
}
