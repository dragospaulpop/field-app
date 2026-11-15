import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_repositories.dart';

/// The signed-in user, or null. supabase_flutter keeps the session itself
/// (Android: the app's preferences; web: the browser's localStorage) and
/// refreshes its token, so a restart finds it again. The stream starts with
/// the session it found (the initialSession event).
final authStateProvider = StreamProvider<User?>(
  (ref) => supabase.auth.onAuthStateChange.map((s) => s.session?.user),
);

/// The signed-in worker's id: a UUID, the same as auth.users.id in Postgres.
/// Only read behind the gate in main.dart.
final uidProvider = Provider<String>((ref) => ref.watch(authStateProvider).value!.id);

/// The three calls of the auth adapter. With "Confirm email" off (step 1's
/// config.toml) sign-up returns a session at once; with it on there is a
/// user but no session until the link in the email is opened: say so.
Future<void> signUp(String email, String password) async {
  final res = await supabase.auth.signUp(email: email, password: password);
  if (res.session == null) {
    throw const AuthException('Confirm your email first: open the link Supabase sent you.',
        code: 'email_not_confirmed');
  }
}

Future<void> signIn(String email, String password) =>
    supabase.auth.signInWithPassword(email: email, password: password);

Future<void> signOut() => supabase.auth.signOut();
