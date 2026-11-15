import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'db/database.dart';
import 'firebase_options.dart';
import 'notifications.dart';
import 'push.dart';
import 'providers.dart';
import 'session.dart';
import 'theme/app_theme.dart';

import 'screens/building_screen.dart';
import 'screens/entrance_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/long_list_screen.dart';
import 'screens/map_screen.dart';
import 'screens/route_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/survey_screen.dart';
import 'store.dart';
import 'sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before anything that talks to Supabase: your project's URL and publishable
  // key, from supabase.json (git-ignored), given to the build with
  // flutter run --dart-define-from-file=supabase.json.
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty) {
    throw StateError('No Supabase config: run with --dart-define-from-file=supabase.json');
  }
  await Supabase.initialize(url: url, publishableKey: key);
  final fixtures = await Fixtures.load();
  // The app's truth: SQLite. The buildings come from the fixtures once; the
  // entrances, from the cloud (sync.dart).
  final db = AppDatabase();
  await db.seedIfEmpty(fixtures.buildings);
  _startAt = await lastTab(); // reopen on the tab the app was closed on
  // Step 4: a tap on a notification opens its entrance, while the app runs
  // (the callback) and when the tap started the app (the returned route).
  final launchedFor = await initNotifications((route) => _router.push(route));
  // Step 5: pushes from the office; a tap routes through the same function.
  final pushedFor = await initPush(() => DefaultFirebaseOptions.currentPlatform, (route) => _router.push(route));
  runApp(ProviderScope(
    // Hand the two things main() opened to every provider that asks for them.
    overrides: [
      fixturesProvider.overrideWithValue(fixtures),
      databaseProvider.overrideWithValue(db),
    ],
    child: const FieldApp(),
  ));
  // Opened by TabsShell, once the router is on screen (see there).
  _openOnStart = launchedFor ?? pushedFor;
}

const _tabs = ['/map', '/route', '/inbox'];
var _startAt = _tabs.first;
String? _openOnStart; // the route of the notification that started the app

// A top-level final is created on first use (in FieldApp), after main() has
// read _startAt.
final _router = GoRouter(
  initialLocation: _startAt,
  routes: [
    // The three tabs: each branch keeps its own navigation stack.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => TabsShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/route', builder: (context, state) => const RouteScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/inbox',
            builder: (context, state) => const InboxScreen(),
            routes: [
              GoRoute(
                path: 'conversations/:id',
                builder: (context, state) =>
                    ConversationScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
        ]),
      ],
    ),
    // Outside the shell: these cover the tab bar, like a stack screen.
    // Step 7: the list to measure; never in a release build.
    if (!kReleaseMode) GoRoute(path: '/dev/long-list', builder: (context, state) => const LongListScreen()),
    GoRoute(
      path: '/buildings/:id',
      builder: (context, state) => BuildingScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/entrances/:id',
      builder: (context, state) =>
          EntranceScreen(id: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'survey',
          builder: (context, state) =>
              SurveyScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);

// Step 2: the theme lives in theme/app_theme.dart, one ThemeData per brightness.
final _light = buildTheme(Brightness.light);
final _dark = buildTheme(Brightness.dark);

/// The auth-state gate: no user, no app. Signing in or out rebuilds this.
class FieldApp extends ConsumerWidget {
  const FieldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    if (user.value == null) {
      return MaterialApp(
        title: 'Field app',
        theme: _light,
        darkTheme: _dark,
        home: user.isLoading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : const SignInScreen(),
      );
    }
    // The sync runs while a worker is signed in (SyncScope, sync.dart).
    return SyncScope(
      child: MaterialApp.router(
        title: 'Field app',
        routerConfig: _router,
        theme: _light,
        darkTheme: _dark,
        themeMode: ThemeMode.system, // follow the phone's setting
      ),
    );
  }
}

class TabsShell extends ConsumerWidget {
  const TabsShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The notification that started the app opens its entrance on top of the
    // tabs. Not in main(): a push before the router has read its first
    // location leaves the entrance alone on the stack, and Back closes the app.
    if (_openOnStart case final route?) {
      _openOnStart = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _router.push(route));
    }
    final f = ref.watch(fixturesProvider);
    final unread = f.messages
        .where((m) => m.authorId != f.me && !m.readAt.containsKey(f.me))
        .where((m) => f.conversations
            .any((c) => c.id == m.conversationId && c.participantIds.contains(f.me)))
        .length;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the current tab again goes back to its first screen.
        onDestinationSelected: (i) {
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
          saveLastTab(_tabs[i]);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          const NavigationDestination(icon: Icon(Icons.list_alt), label: 'My route'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.mail_outline),
            ),
            label: 'Inbox',
          ),
        ],
      ),
    );
  }
}
