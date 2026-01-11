import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class CheckoutContext {
  final int step;
  final double total;

  const CheckoutContext({this.step = 1, this.total = 0.0});

  CheckoutContext copyWith({int? step, double? total}) =>
      CheckoutContext(step: step ?? this.step, total: total ?? this.total);
}

// Test events
sealed class CheckoutEvent extends XEvent {}

class NextStepEvent extends CheckoutEvent {
  @override
  String get type => 'NEXT_STEP';
}

class AddItemEvent extends CheckoutEvent {
  final double price;
  AddItemEvent(this.price);
  @override
  String get type => 'ADD_ITEM';
}

void main() {
  late StateMachine<CheckoutContext, CheckoutEvent> checkoutMachine;

  setUp(() {
    checkoutMachine = StateMachine.create<CheckoutContext, CheckoutEvent>(
      (m) => m
        ..context(const CheckoutContext())
        ..initial('cart')
        ..state(
          'cart',
          (s) => s
            ..on<NextStepEvent>('shipping')
            ..on<AddItemEvent>(
              'cart',
              actions: [
                (ctx, event) => ctx.copyWith(
                  total: ctx.total + (event as AddItemEvent).price,
                ),
              ],
            ),
        )
        ..state('shipping', (s) => s..on<NextStepEvent>('payment'))
        ..state('payment', (s) => s..on<NextStepEvent>('complete'))
        ..state('complete', (s) => s..final_()),
      id: 'checkout',
    );
  });

  group('RouteScopedMachine', () {
    testWidgets('creates actor scoped to route', (tester) async {
      StateMachineActor<CheckoutContext, CheckoutEvent>? capturedActor;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                RouteScopedMachine<CheckoutContext, CheckoutEvent>(
                  machine: checkoutMachine,
                  builder: (context, actor) {
                    capturedActor = actor;
                    return Text('Step: ${actor.snapshot.context.step}');
                  },
                ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(capturedActor, isNotNull);
      expect(capturedActor!.started, isTrue);
      expect(capturedActor!.matches('cart'), isTrue);

      router.dispose();
    });

    testWidgets('calls onCreated callback', (tester) async {
      bool onCreatedCalled = false;
      bool wasStartedWhenCreated = true;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                RouteScopedMachine<CheckoutContext, CheckoutEvent>(
                  machine: checkoutMachine,
                  onCreated: (actor) {
                    onCreatedCalled = true;
                    wasStartedWhenCreated = actor.started;
                  },
                  builder: (context, actor) => const SizedBox(),
                ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(onCreatedCalled, isTrue);
      expect(wasStartedWhenCreated, isFalse);

      router.dispose();
    });

    testWidgets('respects autoStart = false', (tester) async {
      StateMachineActor<CheckoutContext, CheckoutEvent>? capturedActor;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                RouteScopedMachine<CheckoutContext, CheckoutEvent>(
                  machine: checkoutMachine,
                  autoStart: false,
                  builder: (context, actor) {
                    capturedActor = actor;
                    return const SizedBox();
                  },
                ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(capturedActor!.started, isFalse);

      router.dispose();
    });

    testWidgets('disposes actor when route is exited', (tester) async {
      StateMachineActor<CheckoutContext, CheckoutEvent>? capturedActor;
      bool onDisposedCalled = false;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ElevatedButton(
              onPressed: () => GoRouter.of(context).go('/checkout'),
              child: const Text('Go to Checkout'),
            ),
          ),
          GoRoute(
            path: '/checkout',
            builder: (context, state) =>
                RouteScopedMachine<CheckoutContext, CheckoutEvent>(
                  machine: checkoutMachine,
                  onDisposed: (actor) {
                    onDisposedCalled = true;
                  },
                  builder: (context, actor) {
                    capturedActor = actor;
                    return ElevatedButton(
                      onPressed: () => GoRouter.of(context).go('/'),
                      child: const Text('Go Back'),
                    );
                  },
                ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Navigate to checkout
      await tester.tap(find.text('Go to Checkout'));
      await tester.pumpAndSettle();

      expect(capturedActor, isNotNull);
      expect(capturedActor!.stopped, isFalse);

      // Navigate back
      await tester.tap(find.text('Go Back'));
      await tester.pumpAndSettle();

      expect(onDisposedCalled, isTrue);
      expect(capturedActor!.stopped, isTrue);

      router.dispose();
    });

    testWidgets('restores from initial snapshot', (tester) async {
      final initialSnapshot = StateSnapshot<CheckoutContext>(
        value: const AtomicStateValue('shipping'),
        context: const CheckoutContext(step: 2, total: 50.0),
        event: const InitEvent(),
      );

      StateMachineActor<CheckoutContext, CheckoutEvent>? capturedActor;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                RouteScopedMachine<CheckoutContext, CheckoutEvent>(
                  machine: checkoutMachine,
                  initialSnapshot: initialSnapshot,
                  builder: (context, actor) {
                    capturedActor = actor;
                    return Text('Total: ${actor.snapshot.context.total}');
                  },
                ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(capturedActor!.matches('shipping'), isTrue);
      expect(capturedActor!.snapshot.context.total, equals(50.0));
      expect(find.text('Total: 50.0'), findsOneWidget);

      router.dispose();
    });
  });

  group('StateMachineRoute', () {
    testWidgets('creates route with scoped machine', (tester) async {
      StateMachineActor<CheckoutContext, CheckoutEvent>? capturedActor;

      final router = GoRouter(
        routes: [
          StateMachineRoute<CheckoutContext, CheckoutEvent>(
            path: '/',
            machine: checkoutMachine,
            builder: (context, routerState, actor) {
              capturedActor = actor;
              return Text('State: ${actor.snapshot.value}');
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(capturedActor, isNotNull);
      expect(capturedActor!.started, isTrue);
      expect(find.textContaining('cart'), findsOneWidget);

      router.dispose();
    });
  });

  group('RouteStateMachineContext extension', () {
    testWidgets('routerState extension provides access', (tester) async {
      GoRouterState? capturedState;

      final router = GoRouter(
        initialLocation: '/test',
        routes: [
          GoRoute(
            path: '/test',
            builder: (context, state) => Builder(
              builder: (context) {
                capturedState = context.routerState;
                return const Text('Test Page');
              },
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(capturedState, isNotNull);
      expect(capturedState!.matchedLocation, equals('/test'));

      router.dispose();
    });
  });
}
