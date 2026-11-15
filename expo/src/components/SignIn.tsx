import { isAuthError, isAuthRetryableFetchError } from '@supabase/supabase-js';
import { useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
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

  const input = [styles.input, { color: colors.text, borderColor: colors.muted }];
  return (
    <View style={[styles.screen, { backgroundColor: colors.background }]}>
      <Text style={[styles.title, { color: colors.text }]}>Field app — sign in</Text>
      <TextInput
        style={input}
        placeholder="Email"
        placeholderTextColor={colors.muted}
        autoCapitalize="none"
        autoComplete="email"
        keyboardType="email-address"
        value={email}
        onChangeText={setEmail}
      />
      <TextInput
        style={input}
        placeholder="Password"
        placeholderTextColor={colors.muted}
        secureTextEntry
        autoComplete="password"
        value={password}
        onChangeText={setPassword}
        onSubmitEditing={() => run('in')}
      />
      {error && <Text style={styles.error}>{error}</Text>}
      {busy ? (
        <ActivityIndicator />
      ) : (
        <View style={styles.row}>
          <Pressable
            accessibilityRole="button"
            style={[styles.button, { backgroundColor: colors.primary }]}
            onPress={() => run('in')}
          >
            <Text style={{ color: colors.onPrimary, fontWeight: '700' }}>Sign in</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            style={[styles.button, { borderColor: colors.primary, borderWidth: 1 }]}
            onPress={() => run('up')}
          >
            <Text style={{ color: colors.primary, fontWeight: '700' }}>Create account</Text>
          </Pressable>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, justifyContent: 'center', padding: 24, gap: 12 },
  title: { fontSize: 22, fontWeight: '700', marginBottom: 8 },
  input: { borderWidth: 1, borderRadius: 8, paddingHorizontal: 12, minHeight: 48, fontSize: 16 },
  error: { color: '#dc2626' },
  row: { flexDirection: 'row', gap: 12 },
  button: { flex: 1, minHeight: 48, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
});
