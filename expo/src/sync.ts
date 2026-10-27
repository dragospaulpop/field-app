import { QueryClient } from '@tanstack/react-query';
import { useEffect } from 'react';
import { pins } from './cloud';
import type { Entrance } from './contract/contract';
import { savePins } from './store';

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
}
