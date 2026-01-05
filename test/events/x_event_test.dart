import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Custom event for testing
class CustomEvent extends XEvent {
  final String payload;

  const CustomEvent(this.payload);

  @override
  String get type => 'CUSTOM';
}

void main() {
  group('SimpleEvent', () {
    test('stores type', () {
      const event = SimpleEvent('CLICK');
      expect(event.type, equals('CLICK'));
    });

    test('equality works correctly', () {
      const event1 = SimpleEvent('CLICK');
      const event2 = SimpleEvent('CLICK');
      const event3 = SimpleEvent('SUBMIT');

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('hashCode is consistent', () {
      const event1 = SimpleEvent('CLICK');
      const event2 = SimpleEvent('CLICK');

      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('toString returns readable format', () {
      const event = SimpleEvent('CLICK');
      expect(event.toString(), equals('XEvent(CLICK)'));
    });
  });

  group('InitEvent', () {
    test('has correct type', () {
      const event = InitEvent();
      expect(event.type, equals('xstate.init'));
    });
  });

  group('DoneStateEvent', () {
    test('has correct type', () {
      const event = DoneStateEvent();
      expect(event.type, equals('xstate.done.state'));
    });

    test('stores output', () {
      const event = DoneStateEvent(output: 'result');
      expect(event.output, equals('result'));
    });
  });

  group('DoneInvokeEvent', () {
    test('has correct type with invokeId', () {
      const event = DoneInvokeEvent<String>(
        invokeId: 'fetch',
        data: 'response',
      );
      expect(event.type, equals('xstate.done.invoke.fetch'));
    });

    test('stores data', () {
      const event = DoneInvokeEvent<int>(
        invokeId: 'calculate',
        data: 42,
      );
      expect(event.data, equals(42));
    });
  });

  group('ErrorInvokeEvent', () {
    test('has correct type with invokeId', () {
      final event = ErrorInvokeEvent(
        invokeId: 'fetch',
        error: Exception('Failed'),
      );
      expect(event.type, equals('xstate.error.invoke.fetch'));
    });

    test('stores error and stackTrace', () {
      final error = Exception('Failed');
      final stackTrace = StackTrace.current;
      final event = ErrorInvokeEvent(
        invokeId: 'fetch',
        error: error,
        stackTrace: stackTrace,
      );

      expect(event.error, equals(error));
      expect(event.stackTrace, equals(stackTrace));
    });
  });

  group('Custom XEvent', () {
    test('subclass works correctly', () {
      const event = CustomEvent('data');
      expect(event.type, equals('CUSTOM'));
      expect(event.payload, equals('data'));
    });
  });
}
