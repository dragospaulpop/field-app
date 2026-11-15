import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthRetryableFetchException;

import '../auth.dart';

/// A Supabase Auth error code, said the way a worker understands it.
String messageFor(Object e) {
  // No answer at all (offline, a timeout) is its own exception, with no code.
  if (e is AuthRetryableFetchException) return 'No connection: signing in needs the network.';
  final code = e is AuthException ? (e.code ?? '') : '';
  return switch (code) {
    'invalid_credentials' => 'Wrong email or password.',
    'email_address_invalid' || 'validation_failed' => 'That is not an email address.',
    'user_already_exists' || 'email_exists' => 'This email already has an account: sign in instead.',
    'weak_password' => 'The password needs at least 6 characters.',
    'email_not_confirmed' => 'Confirm your email first: open the link Supabase sent you.',
    _ => 'Could not sign in (${code.isEmpty ? e : code}).',
  };
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // No navigation here: onAuthStateChange (auth.dart) swaps the screen.
  Future<void> _run(Future<void> Function(String email, String password) how) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await how(_email.text.trim(), _password.text);
    } catch (e) {
      setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 48),
          Text('Field app — sign in', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _run(signIn),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(spacing: 12, children: [
              FilledButton(
                onPressed: () => _run(signIn),
                child: const Text('Sign in'),
              ),
              OutlinedButton(
                onPressed: () => _run(signUp),
                child: const Text('Create account'),
              ),
            ]),
        ]),
      ),
    );
  }
}
