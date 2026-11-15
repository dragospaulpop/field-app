import { type Session, type User } from '@supabase/supabase-js';
import { useEffect, useState } from 'react';
import { SESSION_KEY, supabase } from './supabase';

// The auth adapter: the only file (with SignIn) that knows how Supabase signs in.

/** Sign up. With "Confirm email" off (step 1's config.toml) the session comes at once. */
export async function signUp(email: string, password: string) {
  const { data, error } = await supabase.auth.signUp({ email, password });
  if (error) throw error;
  // With "Confirm email" ON there is a user but NO session: the link must be clicked first.
  return { needsConfirmation: data.session === null };
}

export async function signIn(email: string, password: string) {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error; // error.code: 'invalid_credentials', 'email_not_confirmed', ...
}

/** Sign out. Offline with an expired token the client cannot, and keeps the session: then it throws. */
export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error && stored()) throw error; // still signed in (no error once the copy is gone)
}

// The session as the client keeps it (supabase.ts). Offline with an expired access
// token the client cannot renew it and reports null, but keeps this copy until the
// server refuses the refresh token (then it deletes it, and signs out).
const stored = (): Session | null => {
  try {
    return JSON.parse(localStorage.getItem(SESSION_KEY) ?? 'null');
  } catch {
    return null; // a damaged copy counts as none: sign in again
  }
};

/**
 * The session if its access token works now (getSession renews an expired one), else
 * null: offline with an expired token a request would go as anon, so the push waits.
 */
export const liveSession = async () => (await supabase.auth.getSession()).data.session;

/** Runs fn each time the client renews the access token: what waited for one can go. */
export const onTokenRefreshed = (fn: () => void) =>
  supabase.auth.onAuthStateChange((event) => {
    if (event === 'TOKEN_REFRESHED') fn();
  }).data.subscription;

// Who is signed in right now, for code outside React (the push, the banner):
// the same job as Firebase's auth.currentUser.
let current: Session | null = stored();
supabase.auth.onAuthStateChange((_event, s) => {
  current = s ?? stored();
});
export const currentUser = (): User | null => current?.user ?? null;

/** The stored session at once (or undefined while there is none yet), then the session or null (signed out). */
export function useSession(): Session | null | undefined {
  const [session, setSession] = useState<Session | null | undefined>(() => stored() ?? undefined);
  useEffect(() => {
    // Fires at once with the stored session (INITIAL_SESSION), then on every sign-in,
    // sign-out and token refresh.
    const { data } = supabase.auth.onAuthStateChange((_event, s) => setSession(s ?? stored()));
    return () => data.subscription.unsubscribe();
  }, []);
  return session;
}
