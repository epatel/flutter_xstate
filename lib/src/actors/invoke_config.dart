import 'dart:async';

import 'package:meta/meta.dart';

import '../core/state_machine.dart';
import '../events/x_event.dart';

/// Base class for invoke configurations.
///
/// Invoke allows a state to run an asynchronous service while it's active.
/// The service can be:
/// - A [Future] (Promise)
/// - A [Stream] (Observable)
/// - A child [StateMachine]
///
/// When the service completes or emits values, events are sent to the
/// parent machine.
@immutable
abstract class InvokeConfig<TContext, TEvent extends XEvent> {
  /// Unique identifier for this invocation.
  final String id;

  const InvokeConfig({required this.id});

  /// Create the service to invoke.
  ///
  /// Called when entering the state that has this invoke.
  InvokeResult<TContext, TEvent> invoke(TContext context, TEvent event);
}

/// Result of starting an invocation.
sealed class InvokeResult<TContext, TEvent extends XEvent> {
  const InvokeResult();
}

/// Result for a Future-based invocation.
class FutureInvokeResult<TContext, TEvent extends XEvent, TData>
    extends InvokeResult<TContext, TEvent> {
  /// The future to await.
  final Future<TData> future;

  /// Unique ID for this invocation.
  final String id;

  const FutureInvokeResult({
    required this.future,
    required this.id,
  });
}

/// Result for a Stream-based invocation.
class StreamInvokeResult<TContext, TEvent extends XEvent, TData>
    extends InvokeResult<TContext, TEvent> {
  /// The stream to listen to.
  final Stream<TData> stream;

  /// Unique ID for this invocation.
  final String id;

  const StreamInvokeResult({
    required this.stream,
    required this.id,
  });
}

/// Result for a Machine-based invocation.
class MachineInvokeResult<TContext, TEvent extends XEvent, TChildContext,
    TChildEvent extends XEvent> extends InvokeResult<TContext, TEvent> {
  /// The machine to spawn.
  final StateMachine<TChildContext, TChildEvent> machine;

  /// Unique ID for this invocation.
  final String id;

  const MachineInvokeResult({
    required this.machine,
    required this.id,
  });
}

/// Configuration for invoking a Future.
///
/// The Future is awaited while the state is active. When it completes:
/// - On success: A [DoneInvokeEvent] is sent with the result
/// - On error: An [ErrorInvokeEvent] is sent with the error
///
/// If the state is exited before the Future completes, the invocation
/// is cancelled (the result is ignored).
///
/// Example:
/// ```dart
/// state('loading', (s) => s
///   ..invoke([
///     InvokeFuture(
///       id: 'fetchData',
///       src: (ctx, _) => api.fetchData(ctx.userId),
///     ),
///   ])
///   ..on<DoneInvokeEvent<Data>>('success', actions: [
///     (ctx, event) => ctx.copyWith(data: event.data),
///   ])
///   ..on<ErrorInvokeEvent>('error', actions: [
///     (ctx, event) => ctx.copyWith(error: event.error),
///   ])
/// )
/// ```
class InvokeFuture<TContext, TEvent extends XEvent, TData>
    extends InvokeConfig<TContext, TEvent> {
  /// Factory function that creates the Future.
  final Future<TData> Function(TContext context, TEvent event) src;

  const InvokeFuture({
    required super.id,
    required this.src,
  });

  @override
  InvokeResult<TContext, TEvent> invoke(TContext context, TEvent event) {
    return FutureInvokeResult<TContext, TEvent, TData>(
      future: src(context, event),
      id: id,
    );
  }
}

/// Configuration for invoking a Stream.
///
/// The Stream is listened to while the state is active. For each emission:
/// - A custom event can be sent using [onEmit]
/// - Or a [DoneInvokeEvent] is sent with the data
///
/// When the Stream completes or errors:
/// - On done: A [DoneInvokeEvent] is sent (if [onDone] is provided)
/// - On error: An [ErrorInvokeEvent] is sent with the error
///
/// If the state is exited, the subscription is cancelled.
///
/// Example:
/// ```dart
/// state('streaming', (s) => s
///   ..invoke([
///     InvokeStream(
///       id: 'priceUpdates',
///       src: (ctx, _) => priceService.watchPrices(ctx.symbols),
///     ),
///   ])
///   ..on<DoneInvokeEvent<Price>>('streaming', actions: [
///     (ctx, event) => ctx.copyWith(
///       prices: {...ctx.prices, event.data.symbol: event.data},
///     ),
///   ])
/// )
/// ```
class InvokeStream<TContext, TEvent extends XEvent, TData>
    extends InvokeConfig<TContext, TEvent> {
  /// Factory function that creates the Stream.
  final Stream<TData> Function(TContext context, TEvent event) src;

  const InvokeStream({
    required super.id,
    required this.src,
  });

  @override
  InvokeResult<TContext, TEvent> invoke(TContext context, TEvent event) {
    return StreamInvokeResult<TContext, TEvent, TData>(
      stream: src(context, event),
      id: id,
    );
  }
}

/// Configuration for invoking a child state machine.
///
/// The child machine is started when entering the state and stopped when
/// exiting. Events can be sent between parent and child.
///
/// Example:
/// ```dart
/// state('checkout', (s) => s
///   ..invoke([
///     InvokeMachine(
///       id: 'payment',
///       src: (ctx, _) => paymentMachine.withContext(
///         PaymentContext(amount: ctx.total),
///       ),
///     ),
///   ])
///   ..on<DoneInvokeEvent<PaymentResult>>('complete', actions: [
///     (ctx, event) => ctx.copyWith(paymentId: event.data.id),
///   ])
/// )
/// ```
class InvokeMachine<TContext, TEvent extends XEvent, TChildContext,
    TChildEvent extends XEvent> extends InvokeConfig<TContext, TEvent> {
  /// Factory function that creates/configures the machine.
  final StateMachine<TChildContext, TChildEvent> Function(
    TContext context,
    TEvent event,
  ) src;

  const InvokeMachine({
    required super.id,
    required this.src,
  });

  @override
  InvokeResult<TContext, TEvent> invoke(TContext context, TEvent event) {
    return MachineInvokeResult<TContext, TEvent, TChildContext, TChildEvent>(
      machine: src(context, event),
      id: id,
    );
  }
}

/// Configuration for invoking a callback-based actor.
///
/// The callback receives send and receive functions that can be used
/// for bidirectional communication with the parent.
///
/// Example:
/// ```dart
/// state('connected', (s) => s
///   ..invoke([
///     InvokeCallback(
///       id: 'websocket',
///       src: (ctx, event) => (sendBack, receive) {
///         final socket = WebSocket.connect(ctx.url);
///         socket.listen((data) => sendBack(DataReceivedEvent(data)));
///         receive((event) {
///           if (event is SendDataEvent) socket.send(event.data);
///         });
///         return () => socket.close();
///       },
///     ),
///   ])
/// )
/// ```
class InvokeCallback<TContext, TEvent extends XEvent>
    extends InvokeConfig<TContext, TEvent> {
  /// Factory function that creates the callback.
  ///
  /// The callback receives:
  /// - [sendBack]: Function to send events to the parent
  /// - [receive]: Function to receive events from the parent
  ///
  /// Returns a cleanup function that's called when the state exits.
  final void Function() Function(
    void Function(TEvent event) sendBack,
    void Function(void Function(TEvent event) handler) receive,
  ) Function(TContext context, TEvent event) src;

  const InvokeCallback({
    required super.id,
    required this.src,
  });

  @override
  InvokeResult<TContext, TEvent> invoke(TContext context, TEvent event) {
    // Callback invocations are handled specially by the actor
    return CallbackInvokeResult<TContext, TEvent>(
      factory: src(context, event),
      id: id,
    );
  }
}

/// Result for a callback-based invocation.
class CallbackInvokeResult<TContext, TEvent extends XEvent>
    extends InvokeResult<TContext, TEvent> {
  /// The callback factory.
  final void Function() Function(
    void Function(TEvent event) sendBack,
    void Function(void Function(TEvent event) handler) receive,
  ) factory;

  /// Unique ID for this invocation.
  final String id;

  const CallbackInvokeResult({
    required this.factory,
    required this.id,
  });
}

/// Helper to create invoke configurations.
///
/// Usage:
/// ```dart
/// state('loading', (s) => s
///   ..invoke([
///     invoke.future<Data>(
///       id: 'fetch',
///       src: (ctx, _) => api.fetch(),
///     ),
///   ])
/// )
/// ```
class InvokeFactory {
  const InvokeFactory._();

  /// Create a Future-based invoke.
  static InvokeFuture<TContext, TEvent, TData>
      future<TContext, TEvent extends XEvent, TData>({
    required String id,
    required Future<TData> Function(TContext context, TEvent event) src,
  }) {
    return InvokeFuture<TContext, TEvent, TData>(id: id, src: src);
  }

  /// Create a Stream-based invoke.
  static InvokeStream<TContext, TEvent, TData>
      stream<TContext, TEvent extends XEvent, TData>({
    required String id,
    required Stream<TData> Function(TContext context, TEvent event) src,
  }) {
    return InvokeStream<TContext, TEvent, TData>(id: id, src: src);
  }

  /// Create a Machine-based invoke.
  static InvokeMachine<TContext, TEvent, TChildContext, TChildEvent> machine<
      TContext,
      TEvent extends XEvent,
      TChildContext,
      TChildEvent extends XEvent>({
    required String id,
    required StateMachine<TChildContext, TChildEvent> Function(
      TContext context,
      TEvent event,
    ) src,
  }) {
    return InvokeMachine<TContext, TEvent, TChildContext, TChildEvent>(
      id: id,
      src: src,
    );
  }

  /// Create a callback-based invoke.
  static InvokeCallback<TContext, TEvent>
      callback<TContext, TEvent extends XEvent>({
    required String id,
    required void Function() Function(
      void Function(TEvent event) sendBack,
      void Function(void Function(TEvent event) handler) receive,
    ) Function(TContext context, TEvent event)
        src,
  }) {
    return InvokeCallback<TContext, TEvent>(id: id, src: src);
  }
}

/// Shorthand for InvokeFactory.
const invoke = InvokeFactory._();
