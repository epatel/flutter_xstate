/// Step 10: Navigator 2.0 Integration
///
/// Demonstrates Navigator 2.0 with state machine navigation:
/// - Custom page transitions (fade, slide, scale)
/// - Deep linking with URL parameters
/// - State-to-route mapping
/// - Guards and redirects
/// - Route-scoped machines
///
/// Run with: flutter run -d chrome
///
/// Try deep linking by navigating to:
/// - /login - Login screen
/// - /home - Home screen (redirects to /login if not authenticated)
/// - /profile/123 - Profile with user ID parameter
/// - /settings - Settings screen

import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// CONTEXT
// ============================================================================

class AppContext {
  final bool isAuthenticated;
  final String? userId;
  final String? userName;
  final String? selectedProfileId;
  final String currentTheme;

  const AppContext({
    this.isAuthenticated = false,
    this.userId,
    this.userName,
    this.selectedProfileId,
    this.currentTheme = 'light',
  });

  AppContext copyWith({
    bool? isAuthenticated,
    String? userId,
    String? userName,
    String? selectedProfileId,
    String? currentTheme,
    bool clearProfile = false,
  }) => AppContext(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    selectedProfileId: clearProfile
        ? null
        : (selectedProfileId ?? this.selectedProfileId),
    currentTheme: currentTheme ?? this.currentTheme,
  );
}

// ============================================================================
// EVENTS
// ============================================================================

sealed class AppEvent extends XEvent {}

class LoginEvent extends AppEvent {
  final String userId;
  final String userName;

  LoginEvent({required this.userId, required this.userName});

  @override
  String get type => 'LOGIN';
}

class LogoutEvent extends AppEvent {
  @override
  String get type => 'LOGOUT';
}

class GoHomeEvent extends AppEvent {
  @override
  String get type => 'GO_HOME';
}

class ViewProfileEvent extends AppEvent {
  final String profileId;

  ViewProfileEvent(this.profileId);

  @override
  String get type => 'VIEW_PROFILE';
}

class GoSettingsEvent extends AppEvent {
  @override
  String get type => 'GO_SETTINGS';
}

class BackEvent extends AppEvent {
  @override
  String get type => 'BACK';
}

class ChangeThemeEvent extends AppEvent {
  final String theme;

  ChangeThemeEvent(this.theme);

  @override
  String get type => 'CHANGE_THEME';
}

// ============================================================================
// STATE MACHINE
// ============================================================================

final appMachine = StateMachine.create<AppContext, AppEvent>(
  (m) => m
    ..context(const AppContext())
    ..initial('loggedOut')
    // LOGGED OUT
    ..state(
      'loggedOut',
      (s) => s
        ..on<LoginEvent>(
          'loggedIn.home',
          actions: [
            (ctx, event) {
              final e = event as LoginEvent;
              return ctx.copyWith(
                isAuthenticated: true,
                userId: e.userId,
                userName: e.userName,
              );
            },
          ],
        ),
    )
    // LOGGED IN - Compound state with multiple screens
    ..state(
      'loggedIn',
      (s) => s
        ..initial('home')
        ..on<LogoutEvent>(
          'loggedOut',
          actions: [
            (ctx, _) =>
                ctx.copyWith(isAuthenticated: false, clearProfile: true),
          ],
        )
        // Home screen
        ..state(
          'home',
          (child) => child
            ..on<ViewProfileEvent>(
              'loggedIn.profile',
              actions: [
                (ctx, event) {
                  final e = event as ViewProfileEvent;
                  return ctx.copyWith(selectedProfileId: e.profileId);
                },
              ],
            )
            ..on<GoSettingsEvent>('loggedIn.settings'),
        )
        // Profile screen
        ..state(
          'profile',
          (child) => child
            ..on<BackEvent>(
              'loggedIn.home',
              actions: [(ctx, _) => ctx.copyWith(clearProfile: true)],
            )
            ..on<GoHomeEvent>(
              'loggedIn.home',
              actions: [(ctx, _) => ctx.copyWith(clearProfile: true)],
            ),
        )
        // Settings screen
        ..state(
          'settings',
          (child) => child
            ..on<BackEvent>('loggedIn.home')
            ..on<GoHomeEvent>('loggedIn.home')
            ..on<ChangeThemeEvent>(
              'loggedIn.settings',
              actions: [
                (ctx, event) {
                  final e = event as ChangeThemeEvent;
                  return ctx.copyWith(currentTheme: e.theme);
                },
              ],
            ),
        ),
    ),
  id: 'app',
);

// ============================================================================
// ROUTE CONFIGURATION
// ============================================================================

List<StateRouteConfig<AppContext, AppEvent>> buildRoutes() {
  return [
    // Login route - slides from left so logout feels like "going back"
    StateRouteConfig<AppContext, AppEvent>(
      stateId: 'loggedOut',
      path: '/login',
      pageBuilder: (context, snapshot, params) => StateMachinePage(
        key: const ValueKey('login'),
        stateId: 'loggedOut',
        child: const LoginScreen(),
        transitionBuilder: StateMachineTransitions.slideFromLeft,
      ),
    ),

    // Home route - uses wildcard to match all loggedIn.* states
    // This keeps Home in the page stack when navigating to Profile or Settings,
    // enabling proper back animations (child pages animate out, revealing Home)
    StateRouteConfig<AppContext, AppEvent>(
      stateId: 'loggedIn.*',
      path: '/home',
      pageBuilder: (context, snapshot, params) =>
          StateMachinePage.slideFromRight(
            key: const ValueKey('home'),
            stateId: 'loggedIn.home',
            child: const HomeScreen(),
          ),
      // Redirect to login if not authenticated
      guard: (snapshot, params) => snapshot.context.isAuthenticated,
      redirect: (snapshot, params) {
        if (!snapshot.context.isAuthenticated) {
          return '/login';
        }
        return null;
      },
    ),

    // Profile route - slides in from right, slides out to right on back
    StateRouteConfig<AppContext, AppEvent>(
      stateId: 'loggedIn.profile',
      path: '/profile/:profileId',
      pageBuilder: (context, snapshot, params) =>
          StateMachinePage.slideFromRight(
            key: ValueKey('profile-${params['profileId']}'),
            stateId: 'loggedIn.profile',
            child: ProfileScreen(profileId: params['profileId'] ?? ''),
          ),
      // Convert URL params to event
      paramsToEvent: (params, ctx) {
        final profileId = params['profileId'];
        if (profileId != null) {
          return ViewProfileEvent(profileId);
        }
        return null;
      },
      // Convert context to URL params
      contextToParams: (ctx) => {'profileId': ctx.selectedProfileId ?? ''},
      guard: (snapshot, params) => snapshot.context.isAuthenticated,
    ),

    // Settings route - slides up from bottom (modal style)
    StateRouteConfig<AppContext, AppEvent>(
      stateId: 'loggedIn.settings',
      path: '/settings',
      pageBuilder: (context, snapshot, params) => StateMachinePage.modal(
        key: const ValueKey('settings'),
        stateId: 'loggedIn.settings',
        child: const SettingsScreen(),
      ),
      guard: (snapshot, params) => snapshot.context.isAuthenticated,
    ),
  ];
}

// ============================================================================
// APP
// ============================================================================

void main() {
  runApp(const NavigatorApp());
}

class NavigatorApp extends StatefulWidget {
  const NavigatorApp({super.key});

  @override
  State<NavigatorApp> createState() => _NavigatorAppState();
}

class _NavigatorAppState extends State<NavigatorApp> {
  late final StateMachineActor<AppContext, AppEvent> _actor;
  late final StateMachineNavigator<AppContext, AppEvent> _navigator;

  @override
  void initState() {
    super.initState();
    _actor = appMachine.createActor();
    _actor.start();

    _navigator = StateMachineNavigator<AppContext, AppEvent>(
      actor: _actor,
      routes: buildRoutes(),
      defaultPath: '/login',
    );
  }

  @override
  void dispose() {
    _navigator.dispose();
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StateMachineProviderValue<AppContext, AppEvent>(
      actor: _actor,
      child: StateMachineSelector<AppContext, AppEvent, String>(
        selector: (ctx) => ctx.currentTheme,
        builder: (context, theme, send) {
          return MaterialApp.router(
            title: 'Step 10: Navigator 2.0',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: theme == 'dark'
                    ? Brightness.dark
                    : Brightness.light,
              ),
              useMaterial3: true,
            ),
            routerDelegate: _navigator.routerDelegate,
            routeInformationParser: _navigator.routeInformationParser,
          );
        },
      ),
    );
  }
}

// ============================================================================
// LOGIN SCREEN
// ============================================================================

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 10: Navigator 2.0'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.navigation_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Navigator 2.0 Demo',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'State-driven navigation with custom transitions',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              StateMachineBuilder<AppContext, AppEvent>(
                builder: (context, state, send) {
                  return FilledButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In as Demo User'),
                    onPressed: () {
                      send(LoginEvent(userId: 'demo', userName: 'Demo User'));
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
              _buildStateCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard(BuildContext context) {
    return StateMachineBuilder<AppContext, AppEvent>(
      builder: (context, state, send) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'Current State',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${state.value}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<AppContext, AppEvent>(
      builder: (context, state, send) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Welcome, ${state.context.userName}'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () => send(GoSettingsEvent()),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () => send(LogoutEvent()),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Navigation Features',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This demo shows state-driven navigation with:\n'
                        '• Custom page transitions\n'
                        '• Deep linking with URL parameters\n'
                        '• Guards that redirect to login\n'
                        '• State-to-route synchronization',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Profile links
              Text(
                'View Profiles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _ProfileTile(
                profileId: '1',
                name: 'Alice Johnson',
                role: 'Developer',
                onTap: () => send(ViewProfileEvent('1')),
              ),
              _ProfileTile(
                profileId: '2',
                name: 'Bob Smith',
                role: 'Designer',
                onTap: () => send(ViewProfileEvent('2')),
              ),
              _ProfileTile(
                profileId: '3',
                name: 'Carol Williams',
                role: 'Manager',
                onTap: () => send(ViewProfileEvent('3')),
              ),
              const SizedBox(height: 24),

              // State display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current State',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.value}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Text('URL', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    const Text(
                      '/home',
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final String profileId;
  final String name;
  final String role;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.profileId,
    required this.name,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(name[0])),
        title: Text(name),
        subtitle: Text(role),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ============================================================================
// PROFILE SCREEN
// ============================================================================

class ProfileScreen extends StatelessWidget {
  final String profileId;

  const ProfileScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    // Mock profile data
    final profiles = {
      '1': {
        'name': 'Alice Johnson',
        'role': 'Developer',
        'bio': 'Full-stack developer with 5 years of experience.',
      },
      '2': {
        'name': 'Bob Smith',
        'role': 'Designer',
        'bio': 'UI/UX designer passionate about user experience.',
      },
      '3': {
        'name': 'Carol Williams',
        'role': 'Manager',
        'bio': 'Project manager leading cross-functional teams.',
      },
    };

    final profile =
        profiles[profileId] ??
        {'name': 'Unknown', 'role': 'N/A', 'bio': 'Profile not found.'};

    return StateMachineBuilder<AppContext, AppEvent>(
      builder: (context, state, send) {
        return Scaffold(
          appBar: AppBar(
            title: Text(profile['name']!),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => send(BackEvent()),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    profile['name']![0],
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                Text(
                  profile['name']!,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  profile['role']!,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                // Bio
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(profile['bio']!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Deep link info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Deep Link',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '/profile/$profileId',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This page can be accessed directly via URL!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// SETTINGS SCREEN
// ============================================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<AppContext, AppEvent>(
      builder: (context, state, send) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => send(BackEvent()),
            ),
          ),
          body: ListView(
            children: [
              // Theme switcher
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Theme'),
                subtitle: Text(
                  state.context.currentTheme == 'dark'
                      ? 'Dark mode'
                      : 'Light mode',
                ),
                trailing: Switch(
                  value: state.context.currentTheme == 'dark',
                  onChanged: (value) {
                    send(ChangeThemeEvent(value ? 'dark' : 'light'));
                  },
                ),
              ),
              const Divider(),

              // Account info
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Account'),
                subtitle: Text(state.context.userName ?? 'Unknown'),
              ),
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('User ID'),
                subtitle: Text(state.context.userId ?? 'Unknown'),
              ),
              const Divider(),

              // Transition demo
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.animation,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Page Transitions',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This settings page uses a modal (slide from bottom) '
                          'transition, while profile pages use a shared axis '
                          'horizontal transition, and home uses slide from right.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Logout
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  onPressed: () => send(LogoutEvent()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
