import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class AuthContext {
  final bool isAuthenticated;
  final String? userId;

  const AuthContext({this.isAuthenticated = false, this.userId});

  AuthContext copyWith({bool? isAuthenticated, String? userId}) => AuthContext(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    userId: userId ?? this.userId,
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

class UpdateUserEvent extends AuthEvent {
  final String userId;
  UpdateUserEvent(this.userId);
  @override
  String get type => 'UPDATE_USER';
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
              actions: [
                (ctx, _) => ctx.copyWith(isAuthenticated: false, userId: null),
              ],
            )
            ..on<UpdateUserEvent>(
              'authenticated',
              actions: [
                (ctx, event) =>
                    ctx.copyWith(userId: (event as UpdateUserEvent).userId),
              ],
            ),
        ),
      id: 'auth',
    );
  });

  group('StateMachineRefreshListenable', () {
    test('notifies on state change', () {
      final actor = authMachine.createActor();
      actor.start();

      final listenable = StateMachineRefreshListenable(actor);
      int notifyCount = 0;
      listenable.addListener(() => notifyCount++);

      expect(notifyCount, equals(0));

      actor.send(LoginEvent());
      expect(notifyCount, equals(1));

      actor.send(LogoutEvent());
      expect(notifyCount, equals(2));

      listenable.dispose();
      actor.dispose();
    });

    test('respects shouldNotify filter', () {
      final actor = authMachine.createActor();
      actor.start();

      final listenable = StateMachineRefreshListenable(
        actor,
        shouldNotify: (previous, current) =>
            previous.value.toString() != current.value.toString(),
      );
      int notifyCount = 0;
      listenable.addListener(() => notifyCount++);

      // State change - should notify
      actor.send(LoginEvent());
      expect(notifyCount, equals(1));

      // Context-only change (same state) - should NOT notify
      actor.send(UpdateUserEvent('user123'));
      expect(notifyCount, equals(1));

      // State change - should notify
      actor.send(LogoutEvent());
      expect(notifyCount, equals(2));

      listenable.dispose();
      actor.dispose();
    });

    test('disposes properly', () {
      final actor = authMachine.createActor();
      actor.start();

      final listenable = StateMachineRefreshListenable(actor);
      int notifyCount = 0;
      listenable.addListener(() => notifyCount++);

      listenable.dispose();

      // Should not notify after dispose
      actor.send(LoginEvent());
      expect(notifyCount, equals(0));

      actor.dispose();
    });
  });

  group('MultiStateMachineRefreshListenable', () {
    test('notifies on any actor change', () {
      final actor1 = authMachine.createActor();
      actor1.start();

      final actor2 = authMachine.createActor();
      actor2.start();

      final listenable = MultiStateMachineRefreshListenable([actor1, actor2]);
      int notifyCount = 0;
      listenable.addListener(() => notifyCount++);

      actor1.send(LoginEvent());
      expect(notifyCount, equals(1));

      actor2.send(LoginEvent());
      expect(notifyCount, equals(2));

      listenable.dispose();
      actor1.dispose();
      actor2.dispose();
    });
  });

  group('StateMachineValueRefreshListenable', () {
    test('notifies only when selected value changes', () {
      final actor = authMachine.createActor();
      actor.start();

      final listenable =
          StateMachineValueRefreshListenable<AuthContext, AuthEvent, bool>(
            actor,
            selector: (ctx) => ctx.isAuthenticated,
          );
      int notifyCount = 0;
      listenable.addListener(() => notifyCount++);

      // Initial notification
      actor.send(LoginEvent());
      expect(notifyCount, equals(1));

      // Same value (already authenticated) - context change only
      actor.send(UpdateUserEvent('user123'));
      expect(notifyCount, equals(1)); // Should NOT notify

      // Value changes (logout)
      actor.send(LogoutEvent());
      expect(notifyCount, equals(2));

      listenable.dispose();
      actor.dispose();
    });

    test('uses custom equality', () {
      final actor = authMachine.createActor();
      actor.start();
      actor.send(LoginEvent());

      final listenable =
          StateMachineValueRefreshListenable<AuthContext, AuthEvent, String?>(
            actor,
            selector: (ctx) => ctx.userId,
            equals: (prev, curr) => prev == curr,
          );
      int notifyCount = 0;
      listenable.addListener(() => notifyCount++);

      actor.send(UpdateUserEvent('user1'));
      expect(notifyCount, equals(1));

      actor.send(UpdateUserEvent('user2'));
      expect(notifyCount, equals(2));

      // Same user - should not notify
      actor.send(UpdateUserEvent('user2'));
      expect(notifyCount, equals(2));

      listenable.dispose();
      actor.dispose();
    });
  });

  group('StateMachineStateRefreshListenable', () {
    test('notifies only on state value changes', () {
      final actor = authMachine.createActor();
      actor.start();

      final listenable = StateMachineStateRefreshListenable(actor);
      int notifyCount = 0;
      listenable.addListener(() => notifyCount++);

      // State change
      actor.send(LoginEvent());
      expect(notifyCount, equals(1));

      // Context-only change
      actor.send(UpdateUserEvent('user123'));
      expect(notifyCount, equals(1)); // Should NOT notify

      // State change
      actor.send(LogoutEvent());
      expect(notifyCount, equals(2));

      listenable.dispose();
      actor.dispose();
    });
  });
}
