import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class TestContext {
  final int count;
  final String? data;
  const TestContext({this.count = 0, this.data});
  TestContext copyWith({int? count, String? data}) =>
      TestContext(count: count ?? this.count, data: data ?? this.data);
}

// Test events
sealed class TestEvent extends XEvent {}

class StartEvent extends TestEvent {
  @override
  String get type => 'START';
}

class DataEvent extends TestEvent {
  final String data;
  DataEvent(this.data);
  @override
  String get type => 'DATA';
}

void main() {
  group('InvokeFuture', () {
    test('creates config with id and src', () {
      final config = InvokeFuture<TestContext, TestEvent, String>(
        id: 'fetch',
        src: (ctx, event) => Future.value('data'),
      );

      expect(config.id, equals('fetch'));
    });

    test('invoke returns FutureInvokeResult', () {
      final config = InvokeFuture<TestContext, TestEvent, String>(
        id: 'fetch',
        src: (ctx, event) => Future.value('hello'),
      );

      final result = config.invoke(const TestContext(), StartEvent());

      expect(result, isA<FutureInvokeResult>());
      final futureResult = result as FutureInvokeResult<TestContext, TestEvent, String>;
      expect(futureResult.id, equals('fetch'));
      expect(futureResult.future, isA<Future<String>>());
    });

    test('src receives context and event', () async {
      TestContext? capturedContext;
      TestEvent? capturedEvent;

      final config = InvokeFuture<TestContext, TestEvent, String>(
        id: 'fetch',
        src: (ctx, event) {
          capturedContext = ctx;
          capturedEvent = event;
          return Future.value('done');
        },
      );

      final context = const TestContext(count: 42);
      final event = StartEvent();
      config.invoke(context, event);

      expect(capturedContext?.count, equals(42));
      expect(capturedEvent, equals(event));
    });
  });

  group('InvokeStream', () {
    test('creates config with id and src', () {
      final config = InvokeStream<TestContext, TestEvent, int>(
        id: 'counter',
        src: (ctx, event) => Stream.fromIterable([1, 2, 3]),
      );

      expect(config.id, equals('counter'));
    });

    test('invoke returns StreamInvokeResult', () {
      final config = InvokeStream<TestContext, TestEvent, int>(
        id: 'counter',
        src: (ctx, event) => Stream.fromIterable([1, 2, 3]),
      );

      final result = config.invoke(const TestContext(), StartEvent());

      expect(result, isA<StreamInvokeResult>());
      final streamResult = result as StreamInvokeResult<TestContext, TestEvent, int>;
      expect(streamResult.id, equals('counter'));
      expect(streamResult.stream, isA<Stream<int>>());
    });

    test('stream emits values', () async {
      final config = InvokeStream<TestContext, TestEvent, int>(
        id: 'counter',
        src: (ctx, event) => Stream.fromIterable([1, 2, 3]),
      );

      final result = config.invoke(const TestContext(), StartEvent());
      final streamResult = result as StreamInvokeResult<TestContext, TestEvent, int>;

      final values = await streamResult.stream.toList();
      expect(values, equals([1, 2, 3]));
    });
  });

  group('InvokeMachine', () {
    late StateMachine<TestContext, TestEvent> childMachine;

    setUp(() {
      childMachine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('idle')
          ..state('idle', (s) {}),
        id: 'child',
      );
    });

    test('creates config with id and src', () {
      final config = InvokeMachine<TestContext, TestEvent, TestContext, TestEvent>(
        id: 'child',
        src: (ctx, event) => childMachine,
      );

      expect(config.id, equals('child'));
    });

    test('invoke returns MachineInvokeResult', () {
      final config = InvokeMachine<TestContext, TestEvent, TestContext, TestEvent>(
        id: 'child',
        src: (ctx, event) => childMachine,
      );

      final result = config.invoke(const TestContext(), StartEvent());

      expect(result, isA<MachineInvokeResult>());
      final machineResult = result as MachineInvokeResult<TestContext, TestEvent, TestContext, TestEvent>;
      expect(machineResult.id, equals('child'));
      expect(machineResult.machine, equals(childMachine));
    });

    test('src can customize machine based on context', () {
      final config = InvokeMachine<TestContext, TestEvent, TestContext, TestEvent>(
        id: 'child',
        src: (ctx, event) => childMachine.withContext(
          TestContext(count: ctx.count * 2),
        ),
      );

      final result = config.invoke(const TestContext(count: 5), StartEvent());
      final machineResult = result as MachineInvokeResult<TestContext, TestEvent, TestContext, TestEvent>;

      expect(machineResult.machine.initialContext.count, equals(10));
    });
  });

  group('InvokeCallback', () {
    test('creates config with id and src', () {
      final config = InvokeCallback<TestContext, TestEvent>(
        id: 'callback',
        src: (ctx, event) => (sendBack, receive) => () {},
      );

      expect(config.id, equals('callback'));
    });

    test('invoke returns CallbackInvokeResult', () {
      final config = InvokeCallback<TestContext, TestEvent>(
        id: 'callback',
        src: (ctx, event) => (sendBack, receive) => () {},
      );

      final result = config.invoke(const TestContext(), StartEvent());

      expect(result, isA<CallbackInvokeResult>());
      final callbackResult = result as CallbackInvokeResult<TestContext, TestEvent>;
      expect(callbackResult.id, equals('callback'));
    });

    test('callback can send events back', () {
      final sentEvents = <TestEvent>[];

      final config = InvokeCallback<TestContext, TestEvent>(
        id: 'callback',
        src: (ctx, event) => (sendBack, receive) {
          sendBack(DataEvent('hello'));
          sendBack(DataEvent('world'));
          return () {};
        },
      );

      final result = config.invoke(const TestContext(), StartEvent());
      final callbackResult = result as CallbackInvokeResult<TestContext, TestEvent>;

      callbackResult.factory(
        (event) => sentEvents.add(event),
        (handler) {},
      );

      expect(sentEvents.length, equals(2));
      expect((sentEvents[0] as DataEvent).data, equals('hello'));
      expect((sentEvents[1] as DataEvent).data, equals('world'));
    });

    test('callback receives cleanup function', () {
      var cleaned = false;

      final config = InvokeCallback<TestContext, TestEvent>(
        id: 'callback',
        src: (ctx, event) => (sendBack, receive) {
          return () => cleaned = true;
        },
      );

      final result = config.invoke(const TestContext(), StartEvent());
      final callbackResult = result as CallbackInvokeResult<TestContext, TestEvent>;

      final cleanup = callbackResult.factory(
        (event) {},
        (handler) {},
      );

      expect(cleaned, isFalse);
      cleanup();
      expect(cleaned, isTrue);
    });
  });

  group('InvokeFactory', () {
    test('future creates InvokeFuture', () {
      final config = InvokeFactory.future<TestContext, TestEvent, String>(
        id: 'fetch',
        src: (ctx, event) => Future.value('data'),
      );

      expect(config, isA<InvokeFuture>());
      expect(config.id, equals('fetch'));
    });

    test('stream creates InvokeStream', () {
      final config = InvokeFactory.stream<TestContext, TestEvent, int>(
        id: 'counter',
        src: (ctx, event) => Stream.fromIterable([1, 2, 3]),
      );

      expect(config, isA<InvokeStream>());
      expect(config.id, equals('counter'));
    });

    test('machine creates InvokeMachine', () {
      final childMachine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('idle')
          ..state('idle', (s) {}),
        id: 'child',
      );

      final config = InvokeFactory.machine<TestContext, TestEvent, TestContext, TestEvent>(
        id: 'child',
        src: (ctx, event) => childMachine,
      );

      expect(config, isA<InvokeMachine>());
      expect(config.id, equals('child'));
    });

    test('callback creates InvokeCallback', () {
      final config = InvokeFactory.callback<TestContext, TestEvent>(
        id: 'callback',
        src: (ctx, event) => (sendBack, receive) => () {},
      );

      expect(config, isA<InvokeCallback>());
      expect(config.id, equals('callback'));
    });
  });

  group('invoke shorthand', () {
    test('invoke is a const InvokeFactory', () {
      expect(invoke, isA<InvokeFactory>());
    });
  });
}
