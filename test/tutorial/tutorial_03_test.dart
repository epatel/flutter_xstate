/// Tutorial 03: Guards and Conditional Transitions
/// Run with: flutter test test/tutorial/tutorial_03_test.dart

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// Door Lock System
// ============================================================================

class DoorContext {
  final int failedAttempts;
  final int maxAttempts;
  final String correctPin;

  const DoorContext({
    this.failedAttempts = 0,
    this.maxAttempts = 3,
    this.correctPin = '1234',
  });

  DoorContext copyWith({int? failedAttempts}) => DoorContext(
        failedAttempts: failedAttempts ?? this.failedAttempts,
        maxAttempts: maxAttempts,
        correctPin: correctPin,
      );
}

sealed class DoorEvent extends XEvent {}

class UnlockEvent extends DoorEvent {
  final String pin;
  UnlockEvent(this.pin);

  @override
  String get type => 'UNLOCK';
}

class LockEvent extends DoorEvent {
  @override
  String get type => 'LOCK';
}

class AdminOverrideEvent extends DoorEvent {
  @override
  String get type => 'ADMIN_OVERRIDE';
}

class ResetEvent extends DoorEvent {
  @override
  String get type => 'RESET';
}

// ============================================================================
// Guard Functions
// ============================================================================

bool isPinCorrect(DoorContext ctx, DoorEvent event) {
  if (event is UnlockEvent) {
    return event.pin == ctx.correctPin;
  }
  return false;
}

bool isPinIncorrect(DoorContext ctx, DoorEvent event) => !isPinCorrect(ctx, event);

bool isMaxAttemptsReached(DoorContext ctx, DoorEvent event) =>
    ctx.failedAttempts >= ctx.maxAttempts - 1;

// Combined guard: wrong PIN AND max attempts reached
bool isPinIncorrectAndMaxAttempts(DoorContext ctx, DoorEvent event) =>
    isPinIncorrect(ctx, event) && isMaxAttemptsReached(ctx, event);

// ============================================================================
// Machine with Guards
// ============================================================================

final doorMachine = StateMachine.create<DoorContext, DoorEvent>(
  (m) => m
    ..context(const DoorContext())
    ..initial('locked')
    ..state(
      'locked',
      (s) => s
        ..entry([
          (ctx, _) {
            print('  [Door] LOCKED');
            return ctx;
          },
        ])
        // Correct PIN -> unlocked
        ..on<UnlockEvent>('unlocked', guard: isPinCorrect, actions: [
          (ctx, _) {
            print('  [Door] PIN correct! Unlocking...');
            return ctx.copyWith(failedAttempts: 0);
          },
        ])
        // Wrong PIN + max attempts -> lockout
        ..on<UnlockEvent>(
          'lockout',
          guard: isPinIncorrectAndMaxAttempts,
          actions: [
            (ctx, _) {
              print('  [Door] Wrong PIN! Max attempts - LOCKOUT!');
              return ctx.copyWith(failedAttempts: ctx.failedAttempts + 1);
            },
          ],
        )
        // Wrong PIN -> stay locked
        ..on<UnlockEvent>('locked', guard: isPinIncorrect, actions: [
          (ctx, _) {
            final attempts = ctx.failedAttempts + 1;
            print('  [Door] Wrong PIN! Attempt $attempts/${ctx.maxAttempts}');
            return ctx.copyWith(failedAttempts: attempts);
          },
        ])
        // Admin always works
        ..on<AdminOverrideEvent>('unlocked', actions: [
          (ctx, _) {
            print('  [Door] Admin override!');
            return ctx.copyWith(failedAttempts: 0);
          },
        ]),
    )
    ..state(
      'unlocked',
      (s) => s
        ..entry([
          (ctx, _) {
            print('  [Door] UNLOCKED');
            return ctx;
          },
        ])
        ..on<LockEvent>('locked'),
    )
    ..state(
      'lockout',
      (s) => s
        ..entry([
          (ctx, _) {
            print('  [Door] LOCKOUT MODE');
            return ctx;
          },
        ])
        ..on<AdminOverrideEvent>('locked', actions: [
          (ctx, _) {
            print('  [Door] Admin reset lockout');
            return ctx.copyWith(failedAttempts: 0);
          },
        ])
        ..on<ResetEvent>('locked', actions: [
          (ctx, _) {
            print('  [Door] System reset');
            return ctx.copyWith(failedAttempts: 0);
          },
        ]),
    ),
  id: 'doorLock',
);

// ============================================================================
// Demo
// ============================================================================

void main() {
  test('Door Lock System Demo', () {
    print('\n=== Door Lock System Demo ===\n');

    final actor = doorMachine.createActor();
    actor.start();
    print('');

    // Wrong PIN twice
    print('Attempt 1: Wrong PIN "0000"...');
    actor.send(UnlockEvent('0000'));
    expect(actor.matches('locked'), isTrue);
    expect(actor.snapshot.context.failedAttempts, equals(1));
    print('');

    print('Attempt 2: Wrong PIN "9999"...');
    actor.send(UnlockEvent('9999'));
    expect(actor.matches('locked'), isTrue);
    expect(actor.snapshot.context.failedAttempts, equals(2));
    print('');

    // Correct PIN
    print('Attempt 3: Correct PIN "1234"...');
    actor.send(UnlockEvent('1234'));
    expect(actor.matches('unlocked'), isTrue);
    print('');

    // Lock again
    print('Locking...');
    actor.send(LockEvent());
    expect(actor.matches('locked'), isTrue);
    print('');

    // Trigger lockout
    print('--- Triggering Lockout ---');
    actor.send(UnlockEvent('wrong'));
    print('');
    actor.send(UnlockEvent('wrong'));
    print('');
    actor.send(UnlockEvent('wrong'));
    expect(actor.matches('lockout'), isTrue);
    print('');

    // Can't unlock during lockout
    print('Trying correct PIN during lockout...');
    actor.send(UnlockEvent('1234'));
    expect(actor.matches('lockout'), isTrue); // Still locked out!
    print('Current state: ${actor.snapshot.value}');
    print('');

    // Admin reset
    print('Admin override...');
    actor.send(AdminOverrideEvent());
    expect(actor.matches('locked'), isTrue);
    print('');

    actor.dispose();
    print('=== Demo Complete ===\n');
  });
}
