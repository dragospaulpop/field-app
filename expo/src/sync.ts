import { QueryClient } from '@tanstack/react-query';
import { addNetworkStateListener } from 'expo-network';
import { FirebaseError } from 'firebase/app';
import { useEffect } from 'react';
import { AppState } from 'react-native';
import { pins, surveys } from './cloud';
import { type Entrance, EntranceSurvey } from './contract/contract';
import { markSent, outbox, savePins } from './store';

/** Server state: what the cloud says right now. Screens still read SQLite. */
export const queryClient = new QueryClient();
export const myPinsKey = (uid: string) => ['pins', uid] as const;

/**
 * The pull, while a worker is signed in: one Firestore listener on my pins.
 * Every snapshot goes to SQLite (the truth on the phone) and into TanStack
 * Query's cache with setQueryData, so the banner shows the cloud's count
 * without a second request.
 */
export function useSync(uid: string) {
  useEffect(() => {
    const stop = pins.watchMine(
      uid,
      (list: Entrance[]) => {
        queryClient.setQueryData(myPinsKey(uid), list);
        savePins(list).catch((e) => console.warn('savePins', e));
      },
      (e) => console.warn('pins listener', e),
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
 * The outbox push: every unsent survey goes up as surveys/{entranceId} with
 * setDoc. The id is the survey's own, so a second push (the app was killed
 * before it heard "ok") overwrites the same document: idempotent. Offline,
 * setDoc waits until the network is back; SQLite keeps the survey meanwhile.
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
        // permission-denied: the rules refused it (the pin is no longer mine).
        await markSent(e.id, e.updatedAt, err instanceof FirebaseError ? err.code : String(err));
      }
    }
  } finally {
    pushing = false;
  }
}
