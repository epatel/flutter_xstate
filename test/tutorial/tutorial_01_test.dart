/// Tutorial 01: Your First State Machine
/// Run with: flutter test test/tutorial/tutorial_01_test.dart

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// Define Events
// ============================================================================

sealed class TrafficLightEvent extends XEvent {}

class TimerEvent extends TrafficLightEvent {
  @override
  String get type => 'TIMER';
}

class EmergencyEvent extends TrafficLightEvent {
  @override
  String get type => 'EMERGENCY';
}

class ResetEvent extends TrafficLightEvent {
  @override
  String get type => 'RESET';
}

// ============================================================================
// Define Context
// ============================================================================

class TrafficLightContext {
  const TrafficLightContext();
}

// ============================================================================
// Create the State Machine
// ============================================================================

final trafficLightMachine =
    StateMachine.create<TrafficLightContext, TrafficLightEvent>(
      (m) => m
        ..context(const TrafficLightContext())
        ..initial('green')
        ..state(
          'green',
          (s) => s
            ..on<TimerEvent>('yellow')
            ..on<EmergencyEvent>('red'),
        )
        ..state(
          'yellow',
          (s) => s
            ..on<TimerEvent>('red')
            ..on<EmergencyEvent>('red'),
        )
        ..state(
          'red',
          (s) => s
            ..on<TimerEvent>('green')
            ..on<ResetEvent>('green'),
        ),
      id: 'trafficLight',
    );

// ============================================================================
// Demo as Test
// ============================================================================

void main() {
  test('Traffic Light State Machine Demo', () {
    print('\n=== Traffic Light State Machine Demo ===\n');

    // Create an actor from the machine
    final actor = trafficLightMachine.createActor();

    // Listen to state changes
    actor.addListener(() {
      print('State changed to: ${actor.snapshot.value}');
    });

    // Start the actor
    actor.start();
    print('Initial state: ${actor.snapshot.value}');
    expect(actor.matches('green'), isTrue);
    print('');

    // Send events to trigger transitions
    print('Sending TIMER event...');
    actor.send(TimerEvent());
    expect(actor.matches('yellow'), isTrue);

    print('Sending TIMER event...');
    actor.send(TimerEvent());
    expect(actor.matches('red'), isTrue);

    print('Sending TIMER event...');
    actor.send(TimerEvent());
    expect(actor.matches('green'), isTrue);

    print('');
    print('Sending EMERGENCY event...');
    actor.send(EmergencyEvent());
    expect(actor.matches('red'), isTrue);

    print('');
    print('Current state matches "red": ${actor.matches("red")}');
    print('Current state matches "green": ${actor.matches("green")}');

    // Clean up
    actor.dispose();

    print('\n=== Demo Complete ===\n');
  });
}
