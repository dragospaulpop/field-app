import { isAuthError, isAuthRetryableFetchError } from '@supabase/supabase-js';
import { useState } from 'react';
import { ActivityIndicator, Pressable, Text, TextInput, View } from 'react-native';
import { signIn, signUp } from '../auth';
import { useColors } from '../theme';

/** A Supabase Auth error, said the way a worker understands it (by its code, never its text). */
function messageFor(e: unknown): string {
  // No answer at all (no network, a wrong URL in .env): a "retryable fetch" error.
  if (isAuthRetryableFetchError(e)) return 'No connection: signing in needs the network.';
  if (!isAuthError(e)) return `Could not sign in (${String(e)}).`;
  switch (e.code) {
    case 'invalid_credentials':
      return 'Wrong email or password.';
    case 'validation_failed':
    case 'email_address_invalid':
      return 'That is not an email address.';
    case 'user_already_exists':
    case 'email_exists':
      return 'This email already has an account: sign in instead.';
    case 'weak_password':
      return 'The password needs at least 6 characters.';
    case 'email_not_confirmed':
      return 'Confirm your email first: open the link Supabase sent you.';
    default:
      return `Could not sign in (${e.code ?? e.message}).`;
  }
}

export function SignIn() {
  const colors = useColors();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // No navigation here: onAuthStateChange in the root layout swaps the screen.
  const run = async (how: 'in' | 'up') => {
    setBusy(true);
    setError(null);
    try {
      if (how === 'in') await signIn(email.trim(), password);
      else if ((await signUp(email.trim(), password)).needsConfirmation) {
        setError('Account made: open the link in your email, then sign in.');
      }
    } catch (e) {
      setError(messageFor(e));
    } finally {
      setBusy(false);
    }
  };

  // Step 2: classNames from the theme (global.css). A placeholder's color is a
  // prop, not a style, so it takes the value (useColors).
  const input = 'min-h-12 rounded-lg border border-muted px-3 text-base text-on-surface';
  return (
    <View className="flex-1 justify-center gap-3 bg-background p-6">
      <Text className="mb-2 text-[22px] font-bold text-on-surface">Field app — sign in</Text>
      <TextInput
        className={input}
        placeholder="Email"
        placeholderTextColor={colors.muted}
        autoCapitalize="none"
        autoComplete="email"
        keyboardType="email-address"
        value={email}
        onChangeText={setEmail}
      />
      <TextInput
        className={input}
        placeholder="Password"
        placeholderTextColor={colors.muted}
        secureTextEntry
        autoComplete="password"
        value={password}
        onChangeText={setPassword}
        onSubmitEditing={() => run('in')}
      />
      {error && <Text className="text-error">{error}</Text>}
      {busy ? (
        <ActivityIndicator color={colors.primary} />
      ) : (
        <View className="flex-row gap-3">
          <Pressable
            accessibilityRole="button"
            className="min-h-12 flex-1 items-center justify-center rounded-lg bg-primary active:opacity-70"
            onPress={() => run('in')}
          >
            <Text className="font-bold text-on-primary">Sign in</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            className="min-h-12 flex-1 items-center justify-center rounded-lg border border-primary active:opacity-70"
            onPress={() => run('up')}
          >
            <Text className="font-bold text-primary">Create account</Text>
          </Pressable>
        </View>
      )}
    </View>
  );
}
