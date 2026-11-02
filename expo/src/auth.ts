import { type Session, type User } from '@supabase/supabase-js';
import { useEffect, useState } from 'react';
import { supabase } from './supabase';

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

export const signOut = () => supabase.auth.signOut();

// Who is signed in right now, for code outside React (the push, the banner):
// the same job as Firebase's auth.currentUser.
let current: Session | null = null;
supabase.auth.onAuthStateChange((_event, s) => {
  current = s;
});
export const currentUser = (): User | null => current?.user ?? null;

/** undefined while the stored session is read, then the session or null (signed out). */
export function useSession(): Session | null | undefined {
  const [session, setSession] = useState<Session | null | undefined>(undefined);
  useEffect(() => {
    // Fires at once with the stored session (INITIAL_SESSION), then on every sign-in,
    // sign-out and token refresh.
    const { data } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);
  return session;
}
