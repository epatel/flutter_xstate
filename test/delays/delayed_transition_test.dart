import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class TimerContext {
  final int ticks;
  final bool expired;

  const TimerContext({this.ticks = 0, this.expired = false});

  TimerContext copyWith({int? ticks, bool? expired}) => TimerContext(
        ticks: ticks ?? this.ticks,
        expired: expired ?? this.expired,
      );
}

// Test events
sealed class TimerEvent extends XEvent {}

class TickEvent extends TimerEvent {
  @override
  String get type => 'TICK';
}

class ExpireEvent extends TimerEvent {
  @override
  String get type => 'EXPIRE';
}

void main() {
  group('DelayedTransitionConfig', () {
    test('creates delayed transition config', () {
      final config = DelayedTransitionConfig<TimerContext, TimerEvent>(
        delay: const Duration(seconds: 5),
        target: 'expired',
      );

      expect(config.delay, equals(const Duration(seconds: 5)));
      expect(config.target, equals('expired'));
      expect(config.guard, isNull);
      expect(config.actions, isEmpty);
    });

    test('supports guard condition', () {
      final config = DelayedTransitionConfig<TimerContext, TimerEvent>(
        delay: const Duration(seconds: 5),
        target: 'expired',
        guard: (ctx) => ctx.ticks > 10,
      );

      expect(config.guard, isNotNull);
      expect(config.guard!(const TimerContext(ticks: 5)), isFalse);
      expect(config.guard!(const TimerContext(ticks: 15)), isTrue);
    });

    test('supports actions', () {
      final config = DelayedTransitionConfig<TimerContext, TimerEvent>(
        delay: const Duration(seconds: 5),
        target: 'expired',
        actions: [
          (ctx, _) => ctx.copyWith(expired: true),
        ],
      );

      expect(config.actions.length, equals(1));
    });
  });

  group('PeriodicTransitionConfig', () {
    test('creates periodic transition config', () {
      final config = PeriodicTransitionConfig<TimerContext, TimerEvent>(
        interval: const Duration(seconds: 1),
        eventFactory: (_) => TickEvent(),
      );

      expect(config.interval, equals(const Duration(seconds: 1)));
      expect(config.fireImmediately, isFalse);
    });

    test('supports fireImmediately', () {
      final config = PeriodicTransitionConfig<TimerContext, TimerEvent>(
        interval: const Duration(seconds: 1),
        eventFactory: (_) => TickEvent(),
        fireImmediately: true,
      );

      expect(config.fireImmediately, isTrue);
    });
  });

  group('DelayedTransitionManager', () {
    test('starts delayed transitions', () async {
      final events = <XEvent>[];
      final manager = DelayedTransitionManager<TimerContext, TimerEvent>(
        (event) => events.add(event),
      );

      manager.addDelayed(DelayedTransitionConfig(
        delay: const Duration(milliseconds: 50),
        target: 'expired',
        id: 'timeout',
      ));

      manager.startTransitions(const TimerContext());

      expect(events, isEmpty);
      expect(manager.isTimerActive('timeout'), isTrue);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, equals(1));
      expect(events.first, isA<DelayedTransitionEvent>());
      expect((events.first as DelayedTransitionEvent).target, equals('expired'));

      manager.dispose();
    });

    test('starts periodic transitions', () async {
      final events = <XEvent>[];
      final manager = DelayedTransitionManager<TimerContext, TimerEvent>(
        (event) => events.add(event),
      );

      manager.addPeriodic(PeriodicTransitionConfig(
        interval: const Duration(milliseconds: 30),
        eventFactory: (_) => TickEvent(),
        id: 'ticker',
      ));

      manager.startTransitions(const TimerContext());

      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.every((e) => e is TickEvent), isTrue);

      manager.dispose();
    });

    test('fires immediately when configured', () async {
      final events = <XEvent>[];
      final manager = DelayedTransitionManager<TimerContext, TimerEvent>(
        (event) => events.add(event),
      );

      manager.addPeriodic(PeriodicTransitionConfig(
        interval: const Duration(seconds: 10),
        eventFactory: (_) => TickEvent(),
        fireImmediately: true,
      ));

      manager.startTransitions(const TimerContext());

      expect(events.length, equals(1));

      manager.dispose();
    });

    test('respects guard conditions', () async {
      final events = <XEvent>[];
      final manager = DelayedTransitionManager<TimerContext, TimerEvent>(
        (event) => events.add(event),
      );

      manager.addDelayed(DelayedTransitionConfig(
        delay: const Duration(milliseconds: 10),
        target: 'expired',
        guard: (ctx) => ctx.ticks > 5,
      ));

      // Guard fails, timer should not start
      manager.startTransitions(const TimerContext(ticks: 3));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(events, isEmpty);

      manager.dispose();
    });

    test('cancels specific timer', () async {
      final events = <XEvent>[];
      final manager = DelayedTransitionManager<TimerContext, TimerEvent>(
        (event) => events.add(event),
      );

      manager.addDelayed(DelayedTransitionConfig(
        delay: const Duration(milliseconds: 100),
        target: 'expired',
        id: 'timeout',
      ));

      manager.startTransitions(const TimerContext());
      expect(manager.isTimerActive('timeout'), isTrue);

      manager.cancelTimer('timeout');
      expect(manager.isTimerActive('timeout'), isFalse);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(events, isEmpty);

      manager.dispose();
    });

    test('cancels all timers', () async {
      final manager = DelayedTransitionManager<TimerContext, TimerEvent>(
        (_) {},
      );

      manager.addDelayed(DelayedTransitionConfig(
        delay: const Duration(seconds: 1),
        target: 'state1',
        id: 'timer1',
      ));
      manager.addDelayed(DelayedTransitionConfig(
        delay: const Duration(seconds: 2),
        target: 'state2',
        id: 'timer2',
      ));

      manager.startTransitions(const TimerContext());
      expect(manager.activeTimerIds, equals({'timer1', 'timer2'}));

      manager.cancelAll();
      expect(manager.activeTimerIds, isEmpty);

      manager.dispose();
    });
  });

  group('Helper functions', () {
    test('after creates DelayedTransitionConfig', () {
      final config = after<TimerContext, TimerEvent>(
        const Duration(seconds: 5),
        'expired',
        id: 'timeout',
      );

      expect(config.delay, equals(const Duration(seconds: 5)));
      expect(config.target, equals('expired'));
      expect(config.id, equals('timeout'));
    });

    test('every creates PeriodicTransitionConfig', () {
      final config = every<TimerContext, TimerEvent>(
        const Duration(seconds: 1),
        (_) => TickEvent(),
        id: 'ticker',
        fireImmediately: true,
      );

      expect(config.interval, equals(const Duration(seconds: 1)));
      expect(config.id, equals('ticker'));
      expect(config.fireImmediately, isTrue);
    });
  });

  group('DelayedTransitionEvent', () {
    test('has correct type', () {
      final event = DelayedTransitionEvent(target: 'expired');
      expect(event.type, equals('xstate.delayed.expired'));
    });

    test('includes transition ID', () {
      final event = DelayedTransitionEvent(
        target: 'expired',
        transitionId: 'timeout',
      );
      expect(event.transitionId, equals('timeout'));
    });
  });
}
