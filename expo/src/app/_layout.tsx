import { QueryClientProvider } from '@tanstack/react-query';
import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useState } from 'react';
import { Text, useColorScheme, View } from 'react-native';
import { KeyboardProvider } from 'react-native-keyboard-controller';
import { SignIn } from '../components/SignIn';
import { openDb } from '../db/db';
import { useSession } from '../auth';
import { configError } from '../supabase';
import { queryClient, useSync } from '../sync';

export default function RootLayout() {
  const [state, setState] = useState<'opening' | 'ready' | Error>('opening');
  const session = useSession();
  useEffect(() => {
    openDb().then(
      () => setState('ready'),
      (e: Error) => setState(e),
    );
  }, []);

  if (configError) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', padding: 24 }}>
        <Text>{configError}</Text>
      </View>
    );
  }
  if (state instanceof Error) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', padding: 24 }}>
        <Text>Could not open the database: {state.message}</Text>
      </View>
    );
  }
  if (state === 'opening' || session === undefined) return null; // a few milliseconds
  // The auth-state gate: no user, no app. Signing in re-renders this layout.
  if (session === null) return <SignIn />;
  return <SignedIn uid={session.user.id} />;
}

/** Everything behind the gate: the sync runs while this is on screen. */
function SignedIn({ uid }: { uid: string }) {
  const scheme = useColorScheme();
  useSync(uid);

  return (
    // TanStack Query's cache (sync.ts) for every screen.
    <QueryClientProvider client={queryClient}>
      {/* keyboard-controller tracks the keyboard for every screen (the survey, step 10). */}
      <KeyboardProvider>
        <ThemeProvider value={scheme === 'dark' ? DarkTheme : DefaultTheme}>
          <Stack>
            <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
            <Stack.Screen name="entrances/[id]" options={{ title: 'Entrance' }} />
            <Stack.Screen name="survey/[id]" options={{ title: 'Survey' }} />
            <Stack.Screen name="conversations/[id]" options={{ title: 'Messages' }} />
          </Stack>
          <StatusBar style="auto" />
        </ThemeProvider>
      </KeyboardProvider>
    </QueryClientProvider>
  );
}
