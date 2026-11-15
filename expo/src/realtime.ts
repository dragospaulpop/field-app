import type { RealtimeChannel } from '@supabase/supabase-js';
import { useEffect, useState } from 'react';
import { AppState } from 'react-native';
import { currentUser } from './auth';
import { supabase } from './supabase';

// Week 6, step 3: Supabase Realtime, two of its three features.
// Postgres Changes: the office changed one of my entrances (a knock on the door).
// Presence: who else is on this building right now (a hint, never the truth).

/**
 * Listen for changes to my entrances. The event is a KNOCK, not the data: on
 * any event (and on every (re)join, which may follow missed events) the caller
 * runs the usual pull. The event's row is never written anywhere.
 * Returns the function that leaves the channel; its promise resolves once it has left.
 */
export function watchEntrances(uid: string, onKnock: () => void): () => Promise<unknown> {
  const channel = supabase
    .channel(`entrances:${uid}`)
    .on(
      'postgres_changes',
      // The filter runs on the server; RLS then checks each event for me too.
      { event: '*', schema: 'public', table: 'entrances', filter: `assigned_to=eq.${uid}` },
      () => onKnock(),
    )
    .subscribe((status, err) => {
      if (status === 'SUBSCRIBED') onKnock();
      else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') console.warn('entrances channel', status, err?.cause ?? err);
    });
  return () => supabase.removeChannel(channel);
}

/** What each phone tracks on a building's channel. */
type Meta = { userId: string; email: string; since: string };
export type Person = Meta & { devices: number };

/**
 * The people on a building, rebuilt from the WHOLE presence state: one entry
 * per userId (one person on two devices is two presence keys, one person here).
 */
export function peopleFrom(state: Record<string, Meta[]>): Person[] {
  const byUser = new Map<string, Person>();
  for (const meta of Object.values(state).flat()) {
    const known = byUser.get(meta.userId);
    if (!known) byUser.set(meta.userId, { userId: meta.userId, email: meta.email, since: meta.since, devices: 1 });
    else {
      known.devices += 1;
      if (meta.since < known.since) known.since = meta.since; // here since the first device came
    }
  }
  return [...byUser.values()].sort((a, b) => a.email.localeCompare(b.email));
}

export type PresenceStatus = 'joining' | 'here' | 'refused' | 'away';

/**
 * Join the building's private channel while the screen is open and the app is
 * in the foreground; leave it when either ends, so the others see a leave
 * instead of a ghost.
 */
export function usePresence(buildingId: string) {
  const [people, setPeople] = useState<Person[]>([]);
  const [status, setStatus] = useState<PresenceStatus>('joining');

  useEffect(() => {
    const me = currentUser();
    if (!me) return;
    let channel: RealtimeChannel | null = null;
    // Leaving takes a moment, and until it is done supabase.channel(topic) hands
    // back the channel that is still leaving (subscribing it does nothing):
    // a join waits for the last leave.
    let left: Promise<unknown> = Promise.resolve();
    let closed = false;

    const join = () => {
      setStatus('joining');
      left.then(() => {
        if (closed || channel) return; // the screen closed, or already joined
        // private: the server asks the policies on realtime.messages (step 3's migration).
        const ch = supabase.channel(`building:${buildingId}`, { config: { private: true } });
        channel = ch;
        ch.on('presence', { event: 'sync' }, () => setPeople(peopleFrom(ch.presenceState<Meta>())));
        // The worker's token must reach Realtime before a private join.
        supabase.realtime
          .setAuth()
          .then(() => {
            // Left while the token was on its way: subscribing now would track a
            // presence nobody removes.
            if (channel !== ch) return;
            ch.subscribe(async (s, err) => {
              if (s === 'SUBSCRIBED') {
                setStatus('here');
                // Only after SUBSCRIBED; one call per join (Presence is not for fast updates).
                await ch.track({ userId: me.id, email: me.email ?? '', since: new Date().toISOString() });
              } else if (s === 'CHANNEL_ERROR') {
                console.warn('building channel refused', err?.cause ?? err);
                setStatus('refused');
                left = supabase.removeChannel(ch); // no retries for a door that stays shut
                if (channel === ch) channel = null;
              } else if (s === 'TIMED_OUT') console.warn('building channel timed out', err);
            });
          })
          .catch((e) => console.warn('building channel', e));
      });
    };

    // Removing the channel unsubscribes, which is a leave for everyone else.
    const leave = () => {
      if (!channel) return;
      left = supabase.removeChannel(channel);
      channel = null;
      setPeople([]);
      setStatus('away');
    };

    join();
    const sub = AppState.addEventListener('change', (s) => {
      if (s === 'active' && !channel) join();
      else if (s === 'background') leave();
    });
    return () => {
      closed = true;
      sub.remove();
      leave();
    };
  }, [buildingId]);

  return { people, status };
}
