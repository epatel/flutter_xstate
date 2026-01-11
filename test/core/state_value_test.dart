import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

void main() {
  group('AtomicStateValue', () {
    test('matches its own id', () {
      const value = AtomicStateValue('idle');
      expect(value.matches('idle'), isTrue);
    });

    test('does not match different id', () {
      const value = AtomicStateValue('idle');
      expect(value.matches('active'), isFalse);
    });

    test('activeStates returns single id', () {
      const value = AtomicStateValue('idle');
      expect(value.activeStates, equals(['idle']));
    });

    test('equality works correctly', () {
      const value1 = AtomicStateValue('idle');
      const value2 = AtomicStateValue('idle');
      const value3 = AtomicStateValue('active');

      expect(value1, equals(value2));
      expect(value1, isNot(equals(value3)));
    });

    test('hashCode is consistent', () {
      const value1 = AtomicStateValue('idle');
      const value2 = AtomicStateValue('idle');

      expect(value1.hashCode, equals(value2.hashCode));
    });

    test('toString returns readable format', () {
      const value = AtomicStateValue('idle');
      expect(value.toString(), equals('StateValue(idle)'));
    });
  });

  group('CompoundStateValue', () {
    test('matches parent id', () {
      const value = CompoundStateValue('traffic', AtomicStateValue('green'));
      expect(value.matches('traffic'), isTrue);
    });

    test('matches child id directly', () {
      const value = CompoundStateValue('traffic', AtomicStateValue('green'));
      expect(value.matches('green'), isTrue);
    });

    test('matches with dot notation', () {
      const value = CompoundStateValue('traffic', AtomicStateValue('green'));
      expect(value.matches('traffic.green'), isTrue);
    });

    test('does not match non-existent state', () {
      const value = CompoundStateValue('traffic', AtomicStateValue('green'));
      expect(value.matches('red'), isFalse);
      expect(value.matches('traffic.red'), isFalse);
    });

    test('activeStates includes parent and prefixed child', () {
      const value = CompoundStateValue('traffic', AtomicStateValue('green'));
      expect(value.activeStates, equals(['traffic', 'traffic.green']));
    });

    test('nested compound states work correctly', () {
      const value = CompoundStateValue(
        'app',
        CompoundStateValue('dashboard', AtomicStateValue('overview')),
      );

      expect(value.matches('app'), isTrue);
      expect(value.matches('dashboard'), isTrue);
      expect(value.matches('overview'), isTrue);
      expect(value.matches('app.dashboard'), isTrue);
      expect(value.matches('app.dashboard.overview'), isTrue);
    });

    test('equality works correctly', () {
      const value1 = CompoundStateValue('a', AtomicStateValue('b'));
      const value2 = CompoundStateValue('a', AtomicStateValue('b'));
      const value3 = CompoundStateValue('a', AtomicStateValue('c'));

      expect(value1, equals(value2));
      expect(value1, isNot(equals(value3)));
    });
  });

  group('ParallelStateValue', () {
    test('matches parent id', () {
      const value = ParallelStateValue('player', {
        'audio': AtomicStateValue('playing'),
        'video': AtomicStateValue('visible'),
      });
      expect(value.matches('player'), isTrue);
    });

    test('matches region states', () {
      const value = ParallelStateValue('player', {
        'audio': AtomicStateValue('playing'),
        'video': AtomicStateValue('visible'),
      });
      expect(value.matches('playing'), isTrue);
      expect(value.matches('visible'), isTrue);
    });

    test('matches with full dot notation', () {
      const value = ParallelStateValue('player', {
        'audio': AtomicStateValue('playing'),
        'video': AtomicStateValue('visible'),
      });
      expect(value.matches('player.audio.playing'), isTrue);
      expect(value.matches('player.video.visible'), isTrue);
    });

    test('does not match non-existent state', () {
      const value = ParallelStateValue('player', {
        'audio': AtomicStateValue('playing'),
      });
      expect(value.matches('paused'), isFalse);
      expect(value.matches('player.audio.paused'), isFalse);
    });

    test('activeStates includes all regions', () {
      const value = ParallelStateValue('player', {
        'audio': AtomicStateValue('playing'),
        'video': AtomicStateValue('visible'),
      });
      final states = value.activeStates;

      expect(states, contains('player'));
      expect(states, contains('player.audio.playing'));
      expect(states, contains('player.video.visible'));
    });

    test('equality works correctly', () {
      const value1 = ParallelStateValue('p', {'a': AtomicStateValue('x')});
      const value2 = ParallelStateValue('p', {'a': AtomicStateValue('x')});
      const value3 = ParallelStateValue('p', {'a': AtomicStateValue('y')});

      expect(value1, equals(value2));
      expect(value1, isNot(equals(value3)));
    });
  });
}
