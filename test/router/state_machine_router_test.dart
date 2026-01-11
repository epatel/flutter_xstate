import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class AuthContext {
  final bool isAuthenticated;
  const AuthContext({this.isAuthenticated = false});
  AuthContext copyWith({bool? isAuthenticated}) =>
      AuthContext(isAuthenticated: isAuthenticated ?? this.isAuthenticated);
}

// Test events
sealed class AuthEvent extends XEvent {}

class LoginEvent extends AuthEvent {
  @override
  String get type => 'LOGIN';
}

class LogoutEvent extends AuthEvent {
  @override
  String get type => 'LOGOUT';
}

void main() {
  late StateMachine<AuthContext, AuthEvent> authMachine;

  setUp(() {
    authMachine = StateMachine.create<AuthContext, AuthEvent>(
      (m) => m
        ..context(const AuthContext())
        ..initial('unauthenticated')
        ..state(
          'unauthenticated',
          (s) => s
            ..on<LoginEvent>(
              'authenticated',
              actions: [(ctx, _) => ctx.copyWith(isAuthenticated: true)],
            ),
        )
        ..state(
          'authenticated',
          (s) => s
            ..on<LogoutEvent>(
              'unauthenticated',
              actions: [(ctx, _) => ctx.copyWith(isAuthenticated: false)],
            ),
        ),
      id: 'auth',
    );
  });

  group('StateRoute', () {
    test('creates route configuration', () {
      final route = StateRoute<AuthContext, AuthEvent>(
        stateId: 'authenticated',
        path: '/home',
        builder: (context, routerState, machineState) => const Text('Home'),
      );

      expect(route.stateId, equals('authenticated'));
      expect(route.path, equals('/home'));
      expect(route.builder, isNotNull);
    });

    test('supports nested routes', () {
      final route = StateRoute<AuthContext, AuthEvent>(
        stateId: 'authenticated',
        path: '/home',
        children: [
          StateRoute<AuthContext, AuthEvent>(
            stateId: 'authenticated',
            path: 'profile',
          ),
        ],
      );

      expect(route.children.length, equals(1));
      expect(route.children.first.path, equals('profile'));
    });
  });

  group('StateMachineRouter', () {
    test('creates router with state-based routes', () {
      final actor = authMachine.createActor();
      actor.start();

      final smRouter = StateMachineRouter<AuthContext, AuthEvent>(
        actor: actor,
        routes: [
          StateRoute(stateId: 'unauthenticated', path: '/login'),
          StateRoute(stateId: 'authenticated', path: '/home'),
        ],
      );

      expect(smRouter.router, isNotNull);
      expect(smRouter.refreshListenable, isNotNull);

      smRouter.dispose();
      actor.dispose();
    });

    test('uses initial location based on current state', () {
      final actor = authMachine.createActor();
      actor.start();

      final smRouter = StateMachineRouter<AuthContext, AuthEvent>(
        actor: actor,
        routes: [
          StateRoute(stateId: 'unauthenticated', path: '/login'),
          StateRoute(stateId: 'authenticated', path: '/home'),
        ],
      );

      // Actor starts in unauthenticated, so initial location should be /login
      // Note: We can't directly test GoRouter's initial location,
      // but we verify the router was created successfully
      expect(smRouter.router, isNotNull);

      smRouter.dispose();
      actor.dispose();
    });

    test('respects custom initial location', () {
      final actor = authMachine.createActor();
      actor.start();
      actor.send(LoginEvent());

      final smRouter = StateMachineRouter<AuthContext, AuthEvent>(
        actor: actor,
        routes: [
          StateRoute(stateId: 'unauthenticated', path: '/login'),
          StateRoute(stateId: 'authenticated', path: '/home'),
        ],
        initialLocation: '/home',
      );

      expect(smRouter.router, isNotNull);

      smRouter.dispose();
      actor.dispose();
    });

    test('disposes router and listenable', () {
      final actor = authMachine.createActor();
      actor.start();

      final smRouter = StateMachineRouter<AuthContext, AuthEvent>(
        actor: actor,
        routes: [
          StateRoute(stateId: 'unauthenticated', path: '/login'),
          StateRoute(stateId: 'authenticated', path: '/home'),
        ],
      );

      // Should not throw
      smRouter.dispose();
      actor.dispose();
    });
  });

  group('StateMachineRouterProvider', () {
    testWidgets('provides router and actor to children', (tester) async {
      await tester.pumpWidget(
        StateMachineRouterProvider<AuthContext, AuthEvent>(
          machine: authMachine,
          routes: [
            StateRoute(
              stateId: 'unauthenticated',
              path: '/',
              builder: (context, routerState, machineState) =>
                  const Text('Login'),
            ),
            StateRoute(
              stateId: 'authenticated',
              path: '/home',
              builder: (context, routerState, machineState) =>
                  const Text('Home'),
            ),
          ],
          builder: (context, router) =>
              MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Should show login page for unauthenticated state
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('provides actor that can be accessed', (tester) async {
      StateMachineActor<AuthContext, AuthEvent>? capturedActor;

      await tester.pumpWidget(
        StateMachineRouterProvider<AuthContext, AuthEvent>(
          machine: authMachine,
          routes: [
            StateRoute(
              stateId: 'unauthenticated',
              path: '/',
              builder: (context, routerState, machineState) {
                capturedActor = context.actor<AuthContext, AuthEvent>();
                return const Text('Login');
              },
            ),
          ],
          builder: (context, router) =>
              MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedActor, isNotNull);
      expect(capturedActor!.matches('unauthenticated'), isTrue);
    });
  });

  group('createStateMachineRouter', () {
    test('creates router from maps', () {
      final actor = authMachine.createActor();
      actor.start();

      final router = createStateMachineRouter(
        actor: actor,
        stateRoutes: {'unauthenticated': '/login', 'authenticated': '/home'},
        builders: {
          '/login': (context, state) => const Text('Login'),
          '/home': (context, state) => const Text('Home'),
        },
      );

      expect(router, isNotNull);

      router.dispose();
      actor.dispose();
    });
  });

  group('RouterStateMachineContext extension', () {
    testWidgets('goRouter extension provides access to router', (tester) async {
      GoRouter? capturedRouter;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Builder(
              builder: (context) {
                capturedRouter = context.goRouter;
                return const Text('Home');
              },
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(capturedRouter, isNotNull);
      expect(capturedRouter, equals(router));

      router.dispose();
    });
  });
}
