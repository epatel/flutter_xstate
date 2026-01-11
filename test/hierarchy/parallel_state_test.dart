import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class TestContext {
  final List<String> log;

  const TestContext({this.log = const []});

  TestContext addLog(String message) => TestContext(log: [...log, message]);
}

// Test events
sealed class TestEvent extends XEvent {}

class PlayEvent extends TestEvent {
  @override
  String get type => 'PLAY';
}

class PauseEvent extends TestEvent {
  @override
  String get type => 'PAUSE';
}

class MuteEvent extends TestEvent {
  @override
  String get type => 'MUTE';
}

class UnmuteEvent extends TestEvent {
  @override
  String get type => 'UNMUTE';
}

void main() {
  group('Parallel States', () {
    test('parallel state has all regions active initially', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('player')
          ..state(
            'player',
            (s) => s
              ..parallel()
              ..state(
                'playback',
                (s) => s
                  ..initial('paused')
                  ..state('paused', (s) {})
                  ..state('playing', (s) {}),
              )
              ..state(
                'volume',
                (s) => s
                  ..initial('unmuted')
                  ..state('unmuted', (s) {})
                  ..state('muted', (s) {}),
              ),
          ),
        id: 'test',
      );

      final state = machine.initialState;

      // All regions should be active
      expect(state.matches('player'), isTrue);
      expect(state.matches('paused'), isTrue);
      expect(state.matches('unmuted'), isTrue);
    });

    test('ParallelStateValue matches correctly', () {
      const value = ParallelStateValue('player', {
        'playback': CompoundStateValue('playback', AtomicStateValue('playing')),
        'volume': CompoundStateValue('volume', AtomicStateValue('muted')),
      });

      expect(value.matches('player'), isTrue);
      expect(value.matches('playing'), isTrue);
      expect(value.matches('muted'), isTrue);
      expect(value.matches('paused'), isFalse);
      expect(value.matches('unmuted'), isFalse);
    });

    test('activeStates includes all regions', () {
      const value = ParallelStateValue('player', {
        'playback': AtomicStateValue('playing'),
        'volume': AtomicStateValue('muted'),
      });

      final active = value.activeStates;

      expect(active, contains('player'));
      expect(active, contains('player.playback.playing'));
      expect(active, contains('player.volume.muted'));
    });

    test('parallel states equality works', () {
      const value1 = ParallelStateValue('p', {
        'a': AtomicStateValue('x'),
        'b': AtomicStateValue('y'),
      });

      const value2 = ParallelStateValue('p', {
        'a': AtomicStateValue('x'),
        'b': AtomicStateValue('y'),
      });

      const value3 = ParallelStateValue('p', {
        'a': AtomicStateValue('x'),
        'b': AtomicStateValue('z'),
      });

      expect(value1, equals(value2));
      expect(value1, isNot(equals(value3)));
    });
  });

  group('Parallel State with Nested Compound', () {
    test('correctly initializes nested compound states in regions', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('player')
          ..state(
            'player',
            (s) => s
              ..parallel()
              ..state(
                'playback',
                (s) => s
                  ..initial('idle')
                  ..state('idle', (s) => s..on<PlayEvent>('playing'))
                  ..state(
                    'playing',
                    (s) => s
                      ..initial('normal')
                      ..state('normal', (s) {})
                      ..state('fast', (s) {}),
                  ),
              )
              ..state(
                'audio',
                (s) => s
                  ..initial('unmuted')
                  ..state('unmuted', (s) {})
                  ..state('muted', (s) {}),
              ),
          ),
        id: 'test',
      );

      final state = machine.initialState;

      expect(state.matches('player'), isTrue);
      expect(state.matches('idle'), isTrue);
      expect(state.matches('unmuted'), isTrue);
    });
  });
}
