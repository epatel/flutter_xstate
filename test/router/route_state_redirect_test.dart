import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class AuthContext {
  final bool isAuthenticated;
  final bool isEmailVerified;

  const AuthContext({
    this.isAuthenticated = false,
    this.isEmailVerified = false,
  });

  AuthContext copyWith({
    bool? isAuthenticated,
    bool? isEmailVerified,
  }) =>
      AuthContext(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      );
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

class VerifyEmailEvent extends AuthEvent {
  @override
  String get type => 'VERIFY_EMAIL';
}

// Mock GoRouterState for testing
class MockGoRouterState extends Fake implements GoRouterState {
  @override
  final String matchedLocation;

  @override
  final Uri uri;

  MockGoRouterState(String location)
      : matchedLocation = location,
        uri = Uri.parse(location);

  @override
  Object? get extra => null;

  @override
  String? get fullPath => matchedLocation;

  @override
  String? get name => null;

  @override
  Map<String, String> get pathParameters => const {};

  @override
  ValueKey<String> get pageKey => const ValueKey('test');

  @override
  String? get path => matchedLocation;
}

GoRouterState createMockRouterState(String location) {
  return MockGoRouterState(location);
}

void main() {
  late StateMachine<AuthContext, AuthEvent> authMachine;
  late StateMachineActor<AuthContext, AuthEvent> actor;

  setUp(() {
    authMachine = StateMachine.create<AuthContext, AuthEvent>(
      (m) => m
        ..context(const AuthContext())
        ..initial('unauthenticated')
        ..state(
          'unauthenticated',
          (s) => s..on<LoginEvent>('unverified', actions: [
            (ctx, _) => ctx.copyWith(isAuthenticated: true),
          ]),
        )
        ..state(
          'unverified',
          (s) => s..on<VerifyEmailEvent>('authenticated', actions: [
            (ctx, _) => ctx.copyWith(isEmailVerified: true),
          ]),
        )
        ..state('authenticated', (s) => s..on<LogoutEvent>('unauthenticated')),
      id: 'auth',
    );
    actor = authMachine.createActor();
    actor.start();
  });

  tearDown(() {
    actor.dispose();
  });

  group('redirectWhenMatches', () {
    test('redirects when state matches', () {
      final redirect = redirectWhenMatches<AuthContext, AuthEvent>(
        actor,
        stateId: 'unauthenticated',
        redirectTo: '/login',
      );

      final state = createMockRouterState('/home');
      final result = redirect(MockBuildContext(), state);

      expect(result, equals('/login'));
    });

    test('does not redirect when state does not match', () {
      actor.send(LoginEvent());

      final redirect = redirectWhenMatches<AuthContext, AuthEvent>(
        actor,
        stateId: 'unauthenticated',
        redirectTo: '/login',
      );

      final state = createMockRouterState('/home');
      final result = redirect(MockBuildContext(), state);

      expect(result, isNull);
    });

    test('respects exceptPaths', () {
      final redirect = redirectWhenMatches<AuthContext, AuthEvent>(
        actor,
        stateId: 'unauthenticated',
        redirectTo: '/login',
        exceptPaths: ['/public', '/legal'],
      );

      final publicState = createMockRouterState('/public/page');
      expect(redirect(MockBuildContext(), publicState), isNull);

      final homeState = createMockRouterState('/home');
      expect(redirect(MockBuildContext(), homeState), equals('/login'));
    });
  });

  group('redirectWhenNotMatches', () {
    test('redirects when state does not match', () {
      final redirect = redirectWhenNotMatches<AuthContext, AuthEvent>(
        actor,
        stateId: 'authenticated',
        redirectTo: '/login',
      );

      final state = createMockRouterState('/dashboard');
      final result = redirect(MockBuildContext(), state);

      expect(result, equals('/login'));
    });

    test('does not redirect when state matches', () {
      actor.send(LoginEvent());
      actor.send(VerifyEmailEvent());

      final redirect = redirectWhenNotMatches<AuthContext, AuthEvent>(
        actor,
        stateId: 'authenticated',
        redirectTo: '/login',
      );

      final state = createMockRouterState('/dashboard');
      final result = redirect(MockBuildContext(), state);

      expect(result, isNull);
    });
  });

  group('redirectWhenContext', () {
    test('redirects based on context condition', () {
      actor.send(LoginEvent()); // Now in unverified state

      final redirect = redirectWhenContext<AuthContext, AuthEvent>(
        actor,
        condition: (ctx) => !ctx.isEmailVerified,
        redirectTo: '/verify-email',
      );

      final state = createMockRouterState('/dashboard');
      final result = redirect(MockBuildContext(), state);

      expect(result, equals('/verify-email'));
    });

    test('does not redirect when condition is false', () {
      actor.send(LoginEvent());
      actor.send(VerifyEmailEvent());

      final redirect = redirectWhenContext<AuthContext, AuthEvent>(
        actor,
        condition: (ctx) => !ctx.isEmailVerified,
        redirectTo: '/verify-email',
      );

      final state = createMockRouterState('/dashboard');
      final result = redirect(MockBuildContext(), state);

      expect(result, isNull);
    });
  });

  group('combineRedirects', () {
    test('evaluates redirects in order', () {
      final redirect = combineRedirects([
        redirectWhenMatches<AuthContext, AuthEvent>(
          actor,
          stateId: 'unauthenticated',
          redirectTo: '/login',
        ),
        redirectWhenMatches<AuthContext, AuthEvent>(
          actor,
          stateId: 'unverified',
          redirectTo: '/verify',
        ),
      ]);

      // Unauthenticated - should redirect to login
      var state = createMockRouterState('/home');
      expect(redirect(MockBuildContext(), state), equals('/login'));

      // Login - now unverified
      actor.send(LoginEvent());
      state = createMockRouterState('/home');
      expect(redirect(MockBuildContext(), state), equals('/verify'));

      // Verify - no redirect
      actor.send(VerifyEmailEvent());
      state = createMockRouterState('/home');
      expect(redirect(MockBuildContext(), state), isNull);
    });
  });

  group('RedirectBuilder', () {
    test('builds redirect with multiple rules', () {
      final redirect = RedirectBuilder<AuthContext, AuthEvent>(actor)
          .whenMatches('unauthenticated', redirectTo: '/login')
          .whenMatches('unverified', redirectTo: '/verify')
          .exceptPaths(['/public'])
          .build();

      // Check unauthenticated
      var state = createMockRouterState('/home');
      expect(redirect(MockBuildContext(), state), equals('/login'));

      // Check except path
      state = createMockRouterState('/public/page');
      expect(redirect(MockBuildContext(), state), isNull);

      // Login and check unverified
      actor.send(LoginEvent());
      state = createMockRouterState('/dashboard');
      expect(redirect(MockBuildContext(), state), equals('/verify'));
    });

    test('supports context conditions', () {
      actor.send(LoginEvent());

      final redirect = RedirectBuilder<AuthContext, AuthEvent>(actor)
          .whenContext((ctx) => !ctx.isEmailVerified, redirectTo: '/verify')
          .build();

      final state = createMockRouterState('/dashboard');
      expect(redirect(MockBuildContext(), state), equals('/verify'));
    });
  });

  group('RedirectRule', () {
    test('whenMatches evaluates correctly', () {
      final rule = RedirectRule<AuthContext>.whenMatches(
        'unauthenticated',
        redirectTo: '/login',
      );

      expect(rule.evaluate(actor), equals('/login'));

      actor.send(LoginEvent());
      expect(rule.evaluate(actor), isNull);
    });

    test('whenNotMatches evaluates correctly', () {
      final rule = RedirectRule<AuthContext>.whenNotMatches(
        'authenticated',
        redirectTo: '/login',
      );

      expect(rule.evaluate(actor), equals('/login'));

      actor.send(LoginEvent());
      actor.send(VerifyEmailEvent());
      expect(rule.evaluate(actor), isNull);
    });

    test('whenContext evaluates correctly', () {
      actor.send(LoginEvent());

      final rule = RedirectRule<AuthContext>.whenContext(
        (ctx) => !ctx.isEmailVerified,
        redirectTo: '/verify',
      );

      expect(rule.evaluate(actor), equals('/verify'));

      actor.send(VerifyEmailEvent());
      expect(rule.evaluate(actor), isNull);
    });
  });

  group('SnapshotRedirectExtension', () {
    test('creates RedirectBuilder from actor', () {
      final builder = actor.redirect();
      expect(builder, isA<RedirectBuilder<AuthContext, AuthEvent>>());
    });
  });
}

// Mock BuildContext for testing
class MockBuildContext extends Fake implements BuildContext {}
