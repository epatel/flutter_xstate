/// Step 6: Auth App - Authentication Flow State Machine
///
/// Demonstrates STATE MACHINE PATTERNS (not production auth):
/// - Compound/hierarchical states (loggedOut.idle, loggedOut.submitting, etc.)
/// - Async operations (simulated login)
/// - Error handling and recovery
/// - Loading states
///
/// NOTE: This is a tutorial for learning state machines, NOT a secure auth
/// implementation. For production apps, use proper auth services (Firebase Auth,
/// Auth0, etc.), secure token storage (flutter_secure_storage), HTTPS, input
/// validation, and rate limiting.
///
/// Run with: flutter run -d chrome

import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// CONTEXT
// ============================================================================

class User {
  final String id;
  final String name;
  final String email;

  const User({required this.id, required this.name, required this.email});
}

class AuthContext {
  final String? email;
  final String? token;
  final String? error;
  final User? user;

  const AuthContext({
    this.email,
    this.token,
    this.error,
    this.user,
  });

  AuthContext copyWith({
    String? email,
    String? token,
    String? error,
    User? user,
    bool clearError = false,
    bool clearUser = false,
    bool clearToken = false,
  }) =>
      AuthContext(
        email: email ?? this.email,
        token: clearToken ? null : (token ?? this.token),
        error: clearError ? null : (error ?? this.error),
        user: clearUser ? null : (user ?? this.user),
      );

  bool get isAuthenticated => token != null && user != null;
}

// ============================================================================
// EVENTS
// ============================================================================

sealed class AuthEvent extends XEvent {}

class LoginSubmitEvent extends AuthEvent {
  final String email;
  final String password;

  LoginSubmitEvent({required this.email, required this.password});

  @override
  String get type => 'LOGIN_SUBMIT';
}

class LoginSuccessEvent extends AuthEvent {
  final String token;
  final User user;

  LoginSuccessEvent({required this.token, required this.user});

  @override
  String get type => 'LOGIN_SUCCESS';
}

class LoginFailureEvent extends AuthEvent {
  final String error;

  LoginFailureEvent(this.error);

  @override
  String get type => 'LOGIN_FAILURE';
}

class LogoutEvent extends AuthEvent {
  @override
  String get type => 'LOGOUT';
}

class RetryEvent extends AuthEvent {
  @override
  String get type => 'RETRY';
}

class SessionExpiredEvent extends AuthEvent {
  @override
  String get type => 'SESSION_EXPIRED';
}

// ============================================================================
// STATE MACHINE
// ============================================================================

StateMachineActor<AuthContext, AuthEvent>? _authActor;

void _simulateLogin(String email, String password) {
  Future.delayed(const Duration(milliseconds: 1500), () {
    if (_authActor == null) return;

    if (email == 'test@example.com' && password == 'password') {
      _authActor!.send(LoginSuccessEvent(
        token: 'fake-jwt-token-12345',
        user: User(id: '1', name: 'Test User', email: email),
      ));
    } else {
      _authActor!.send(LoginFailureEvent('Invalid email or password'));
    }
  });
}

final authMachine = StateMachine.create<AuthContext, AuthEvent>(
  (m) => m
    ..context(const AuthContext())
    ..initial('loggedOut')

    // LOGGED OUT - Compound state with children
    ..state(
      'loggedOut',
      (s) => s
        ..initial('idle') // Makes this a compound state
        ..entry([
          (ctx, _) => ctx.copyWith(clearUser: true, clearToken: true),
        ])

        // Child: idle - waiting for login
        ..state(
          'idle',
          (child) => child
            ..on<LoginSubmitEvent>('loggedOut.submitting', actions: [
              (ctx, event) {
                final e = event as LoginSubmitEvent;
                return ctx.copyWith(email: e.email, clearError: true);
              },
            ]),
        )

        // Child: submitting - login in progress
        ..state(
          'submitting',
          (child) => child
            ..entry([
              (ctx, event) {
                if (event is LoginSubmitEvent) {
                  _simulateLogin(event.email, event.password);
                }
                return ctx;
              },
            ])
            ..on<LoginSuccessEvent>('loggedIn', actions: [
              (ctx, event) {
                final e = event as LoginSuccessEvent;
                return ctx.copyWith(token: e.token, user: e.user);
              },
            ])
            ..on<LoginFailureEvent>('loggedOut.error', actions: [
              (ctx, event) {
                final e = event as LoginFailureEvent;
                return ctx.copyWith(error: e.error);
              },
            ]),
        )

        // Child: error - login failed
        ..state(
          'error',
          (child) => child
            ..on<RetryEvent>('loggedOut.idle', actions: [
              (ctx, _) => ctx.copyWith(clearError: true),
            ])
            ..on<LoginSubmitEvent>('loggedOut.submitting', actions: [
              (ctx, event) {
                final e = event as LoginSubmitEvent;
                return ctx.copyWith(email: e.email, clearError: true);
              },
            ]),
        ),
    )

    // LOGGED IN
    ..state(
      'loggedIn',
      (s) => s
        ..on<LogoutEvent>('loggedOut.idle')
        ..on<SessionExpiredEvent>('loggedOut.error', actions: [
          (ctx, _) =>
              ctx.copyWith(error: 'Session expired. Please login again.'),
        ]),
    ),
  id: 'auth',
);

// ============================================================================
// APP
// ============================================================================

void main() {
  runApp(const AuthApp());
}

class AuthApp extends StatelessWidget {
  const AuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step 6: Auth Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: StateMachineProvider<AuthContext, AuthEvent>(
        machine: authMachine,
        autoStart: true,
        onCreated: (actor) => _authActor = actor,
        child: const AuthScreen(),
      ),
    );
  }
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<AuthContext, AuthEvent>(
      builder: (context, state, send) {
        if (state.value.matches('loggedIn')) {
          return HomeScreen(user: state.context.user!, send: send);
        }
        return const LoginScreen();
      },
    );
  }
}

// ============================================================================
// LOGIN SCREEN
// ============================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'test@example.com');
  final _passwordController = TextEditingController(text: 'password');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 6: Auth Flow'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StateMachineBuilder<AuthContext, AuthEvent>(
        builder: (context, state, send) {
          final isLoading = state.value.matches('loggedOut.submitting');
          final hasError = state.value.matches('loggedOut.error');
          final error = state.context.error;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Logo/Icon
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Error message
                if (hasError && error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Email field
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 32),

                // Login button
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            send(LoginSubmitEvent(
                              email: _emailController.text,
                              password: _passwordController.text,
                            ));
                          },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Hint
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hint: test@example.com / password',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // State indicator
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'State: ${state.value}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================

class HomeScreen extends StatelessWidget {
  final User user;
  final SendEvent<AuthEvent> send;

  const HomeScreen({super.key, required this.user, required this.send});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => send(LogoutEvent()),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user.name[0].toUpperCase(),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ),
              const SizedBox(height: 24),

              // Welcome text
              Text(
                'Welcome, ${user.name}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                user.email,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 48),

              // Demo: Session expiry
              OutlinedButton.icon(
                icon: const Icon(Icons.timer_off),
                label: const Text('Simulate Session Expiry'),
                onPressed: () => send(SessionExpiredEvent()),
              ),
              const SizedBox(height: 16),

              // Logout button
              FilledButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                onPressed: () => send(LogoutEvent()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
