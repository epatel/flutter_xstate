/// Tutorial 02: Context and Actions
/// Run with: flutter test test/tutorial/tutorial_02_test.dart

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// Context with Data
// ============================================================================

class CounterContext {
  final int count;
  final List<String> history;

  const CounterContext({this.count = 0, this.history = const []});

  CounterContext copyWith({int? count, List<String>? history}) =>
      CounterContext(
        count: count ?? this.count,
        history: history ?? this.history,
      );

  @override
  String toString() => 'CounterContext(count: $count, history: $history)';
}

// ============================================================================
// Events with Payloads
// ============================================================================

sealed class CounterEvent extends XEvent {}

class IncrementEvent extends CounterEvent {
  final int amount;
  IncrementEvent([this.amount = 1]);

  @override
  String get type => 'INCREMENT';
}

class DecrementEvent extends CounterEvent {
  final int amount;
  DecrementEvent([this.amount = 1]);

  @override
  String get type => 'DECREMENT';
}

class ResetEvent extends CounterEvent {
  @override
  String get type => 'RESET';
}

// ============================================================================
// Machine with Actions
// ============================================================================

final counterMachine = StateMachine.create<CounterContext, CounterEvent>(
  (m) => m
    ..context(const CounterContext())
    ..initial('active')
    ..state(
      'active',
      (s) => s
        // Entry/exit use entry() and exit() methods
        ..entry([
          (ctx, event) {
            print('  [Entry] Entered active state');
            return ctx;
          },
        ])
        ..exit([
          (ctx, event) {
            print('  [Exit] Leaving active state');
            return ctx;
          },
        ])
        ..on<IncrementEvent>(
          'active',
          actions: [
            (ctx, event) {
              final e = event as IncrementEvent;
              final newCount = ctx.count + e.amount;
              print(
                '  [Action] Incrementing by ${e.amount}: ${ctx.count} -> $newCount',
              );
              return ctx.copyWith(
                count: newCount,
                history: [...ctx.history, '+${e.amount}'],
              );
            },
          ],
        )
        ..on<DecrementEvent>(
          'active',
          actions: [
            (ctx, event) {
              final e = event as DecrementEvent;
              final newCount = ctx.count - e.amount;
              print(
                '  [Action] Decrementing by ${e.amount}: ${ctx.count} -> $newCount',
              );
              return ctx.copyWith(
                count: newCount,
                history: [...ctx.history, '-${e.amount}'],
              );
            },
          ],
        )
        ..on<ResetEvent>('idle'),
    )
    ..state(
      'idle',
      (s) => s
        ..entry([
          (ctx, event) {
            print('  [Entry] Counter is now idle, resetting');
            return ctx.copyWith(count: 0, history: []);
          },
        ])
        ..on<IncrementEvent>(
          'active',
          actions: [
            (ctx, event) {
              final e = event as IncrementEvent;
              return ctx.copyWith(count: e.amount, history: ['+${e.amount}']);
            },
          ],
        ),
    ),
  id: 'counter',
);

// ============================================================================
// Demo
// ============================================================================

void main() {
  test('Counter with Context Demo', () {
    print('\n=== Counter with Context Demo ===\n');

    final actor = counterMachine.createActor();

    actor.addListener(() {
      print('  -> Context: ${actor.snapshot.context}');
      print('');
    });

    actor.start();
    print('Started in state: ${actor.snapshot.value}');
    print('Initial context: ${actor.snapshot.context}');
    print('');

    // Increment by default (1)
    print('Sending INCREMENT...');
    actor.send(IncrementEvent());
    expect(actor.snapshot.context.count, equals(1));

    // Increment by 5
    print('Sending INCREMENT(5)...');
    actor.send(IncrementEvent(5));
    expect(actor.snapshot.context.count, equals(6));

    // Decrement by 2
    print('Sending DECREMENT(2)...');
    actor.send(DecrementEvent(2));
    expect(actor.snapshot.context.count, equals(4));

    // Check history
    expect(actor.snapshot.context.history, equals(['+1', '+5', '-2']));

    // Reset
    print('Sending RESET...');
    actor.send(ResetEvent());
    expect(actor.matches('idle'), isTrue);
    expect(actor.snapshot.context.count, equals(0));

    // Resume
    print('Sending INCREMENT(10)...');
    actor.send(IncrementEvent(10));
    expect(actor.matches('active'), isTrue);
    expect(actor.snapshot.context.count, equals(10));

    actor.dispose();
    print('=== Demo Complete ===\n');
  });
}
