import { QueryClient } from '@tanstack/react-query';
import { addNetworkStateListener } from 'expo-network';
import { useEffect } from 'react';
import { AppState } from 'react-native';
import { pins, surveys } from './cloud';
import { type Entrance, EntranceSurvey } from './contract/contract';
import { signOut } from './auth';
import { markSent, outbox, savePins, unsentSurveys } from './store';

/** Server state: what the cloud says right now. Screens still read SQLite. */
export const queryClient = new QueryClient();
export const myPinsKey = (uid: string) => ['pins', uid] as const;

/**
 * The pull, while a worker is signed in: my pins from Postgres (now, on
 * foreground, after every push). Every answer goes to SQLite (the truth on the
 * phone) and into TanStack Query's cache with setQueryData, so the banner
 * shows the cloud's count without a second request.
 */
export function useSync(uid: string) {
  useEffect(() => {
    const stop = pins.watchMine(
      uid,
      (list: Entrance[]) => {
        queryClient.setQueryData(myPinsKey(uid), list);
        savePins(list).catch((e) => console.warn('savePins', e));
      },
      (e) => console.warn('pins pull', e),
    );
    return stop; // signing out unmounts the hook: the listener stops
  }, [uid]);

  // The push, at three moments: now, when the app comes back to the
  // foreground, and when the network comes back. (And on "Sync now".)
  useEffect(() => {
    pushSurveys(uid);
    const foreground = AppState.addEventListener('change', (state) => {
      if (state === 'active') pushSurveys(uid);
    });
    const network = addNetworkStateListener((state) => {
      if (state.isConnected) pushSurveys(uid);
    });
    return () => {
      foreground.remove();
      network.remove();
    };
  }, [uid]);
}

let pushing = false;

/**
 * The outbox push: every unsent survey updates its entrance's row. The row is
 * named by the entrance's UUID, so a second push (the app was killed before it
 * heard "ok") writes the same values again: idempotent. Offline, the request
 * fails; the survey stays in SQLite and goes at the next push. Then a pull.
 */
export async function pushSurveys(uid: string) {
  if (pushing) return; // one push at a time
  pushing = true;
  try {
    for (const e of await outbox()) {
      try {
        await surveys.push({
          // The contract's survey schema picks the surveyed fields (and checks them).
          ...EntranceSurvey.parse(e),
          id: e.id,
          surveyStatus: e.surveyStatus,
          surveyedBy: uid,
          surveyedAt: e.surveyedAt ?? e.updatedAt,
          updatedAt: e.updatedAt,
        });
        await markSent(e.id, e.updatedAt, null);
      } catch (err) {
        // A refusal (the pin is no longer mine, a grant is missing) or no network.
        await markSent(e.id, e.updatedAt, err instanceof Error ? err.message : String(err));
      }
    }
  } finally {
    pushing = false;
  }
  pins.refresh(); // and ask for my pins again: the office may have changed them
}

/**
 * Sign out, unless this phone still holds unsent work: SQLite is the phone's,
 * not the worker's, so the next worker to sign in here would inherit it.
 * Returns the reason it refused, or null when it signed out.
 */
export async function safeSignOut(): Promise<string | null> {
  const n = await unsentSurveys();
  if (n > 0) return `${n} ${n === 1 ? 'survey' : 'surveys'} not sent yet: Sync now first.`;
  await signOut();
  return null;
}
