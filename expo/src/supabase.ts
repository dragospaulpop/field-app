import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
// localStorage for React Native, kept in SQLite (expo-sqlite): where the session lives on the phone.
import 'expo-sqlite/localStorage/install';
import { AppState, Platform } from 'react-native';

// The project's URL and its PUBLISHABLE key, from expo/.env (step 1). Both end
// up inside the app, which is fine: the policies of step 1 are the protection.
const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

/** Not null when expo/.env is missing: the root layout shows it instead of a blank screen. */
export const configError =
  url && key
    ? null
    : 'No Supabase URL or key: copy expo/.env.example to expo/.env, fill in your project’s two values, then restart `bunx expo start`.';

// (Without the two values, a placeholder keeps createClient from throwing while the message shows.)
export const supabase = createClient(
  url ?? 'https://missing.invalid',
  key ?? 'missing',
  {
    auth: {
      storage: localStorage, // keep the session across restarts...
      autoRefreshToken: true, // ...and renew the access token before it expires
      persistSession: true,
      detectSessionInUrl: false, // a phone has no #access_token in a URL
    },
  },
);

// A phone in the background cannot run timers: refresh only in the foreground.
// (The browser keeps the tab's timers going: nothing to do on the web.)
if (Platform.OS !== 'web') {
  AppState.addEventListener('change', (state) => {
    if (state === 'active') supabase.auth.startAutoRefresh();
    else supabase.auth.stopAutoRefresh();
  });
}
