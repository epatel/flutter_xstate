import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class CartContext {
  final int itemCount;
  final double totalPrice;
  final String status;

  const CartContext({
    this.itemCount = 0,
    this.totalPrice = 0.0,
    this.status = 'empty',
  });

  CartContext copyWith({int? itemCount, double? totalPrice, String? status}) =>
      CartContext(
        itemCount: itemCount ?? this.itemCount,
        totalPrice: totalPrice ?? this.totalPrice,
        status: status ?? this.status,
      );
}

// Test events
sealed class CartEvent extends XEvent {}

class AddItemEvent extends CartEvent {
  final double price;
  AddItemEvent(this.price);
  @override
  String get type => 'ADD_ITEM';
}

class UpdateStatusEvent extends CartEvent {
  final String status;
  UpdateStatusEvent(this.status);
  @override
  String get type => 'UPDATE_STATUS';
}

void main() {
  late StateMachine<CartContext, CartEvent> cartMachine;

  setUp(() {
    cartMachine = StateMachine.create<CartContext, CartEvent>(
      (m) => m
        ..context(const CartContext())
        ..initial('active')
        ..state(
          'active',
          (s) => s
            ..on<AddItemEvent>(
              'active',
              actions: [
                (ctx, event) => ctx.copyWith(
                  itemCount: ctx.itemCount + 1,
                  totalPrice: ctx.totalPrice + (event as AddItemEvent).price,
                ),
              ],
            )
            ..on<UpdateStatusEvent>(
              'active',
              actions: [
                (ctx, event) =>
                    ctx.copyWith(status: (event as UpdateStatusEvent).status),
              ],
            ),
        ),
      id: 'cart',
    );
  });

  group('StateMachineSelector', () {
    testWidgets('only rebuilds when selected value changes', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CartContext, CartEvent>(
            machine: cartMachine,
            child: Column(
              children: [
                StateMachineBuilder<CartContext, CartEvent>(
                  builder: (context, state, send) {
                    return Column(
                      children: [
                        ElevatedButton(
                          onPressed: () => send(AddItemEvent(10.0)),
                          child: const Text('Add Item'),
                        ),
                        ElevatedButton(
                          onPressed: () => send(UpdateStatusEvent('updated')),
                          child: const Text('Update Status'),
                        ),
                      ],
                    );
                  },
                ),
                StateMachineSelector<CartContext, CartEvent, int>(
                  selector: (ctx) => ctx.itemCount,
                  builder: (context, count, send) {
                    buildCount++;
                    return Text('Items: $count');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      final initialBuildCount = buildCount;

      // Add item - should rebuild (itemCount changes)
      await tester.tap(find.text('Add Item'));
      await tester.pump();
      expect(buildCount, equals(initialBuildCount + 1));

      // Update status - should NOT rebuild (itemCount unchanged)
      await tester.tap(find.text('Update Status'));
      await tester.pump();
      expect(buildCount, equals(initialBuildCount + 1));

      // Add another item - should rebuild
      await tester.tap(find.text('Add Item'));
      await tester.pump();
      expect(buildCount, equals(initialBuildCount + 2));
    });

    testWidgets('displays selected value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CartContext, CartEvent>(
            machine: cartMachine,
            child: Column(
              children: [
                StateMachineBuilder<CartContext, CartEvent>(
                  builder: (context, state, send) {
                    return ElevatedButton(
                      onPressed: () => send(AddItemEvent(25.0)),
                      child: const Text('Add Item'),
                    );
                  },
                ),
                StateMachineSelector<CartContext, CartEvent, double>(
                  selector: (ctx) => ctx.totalPrice,
                  builder: (context, price, send) {
                    return Text('Total: \$${price.toStringAsFixed(2)}');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Total: \$0.00'), findsOneWidget);

      await tester.tap(find.text('Add Item'));
      await tester.pump();

      expect(find.text('Total: \$25.00'), findsOneWidget);
    });
  });

  group('StateMachineSelector2', () {
    testWidgets('selects two values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CartContext, CartEvent>(
            machine: cartMachine,
            child: Column(
              children: [
                StateMachineBuilder<CartContext, CartEvent>(
                  builder: (context, state, send) {
                    return ElevatedButton(
                      onPressed: () => send(AddItemEvent(15.0)),
                      child: const Text('Add Item'),
                    );
                  },
                ),
                StateMachineSelector2<CartContext, CartEvent, int, double>(
                  selector1: (ctx) => ctx.itemCount,
                  selector2: (ctx) => ctx.totalPrice,
                  builder: (context, count, price, send) {
                    return Text('$count items - \$${price.toStringAsFixed(2)}');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('0 items - \$0.00'), findsOneWidget);

      await tester.tap(find.text('Add Item'));
      await tester.pump();

      expect(find.text('1 items - \$15.00'), findsOneWidget);
    });
  });

  group('StateMachineMatchSelector', () {
    testWidgets('builds based on state match', (tester) async {
      final machine = StateMachine.create<CartContext, CartEvent>(
        (m) => m
          ..context(const CartContext())
          ..initial('loading')
          ..state('loading', (s) => s..on<UpdateStatusEvent>('ready'))
          ..state('ready', (s) {}),
        id: 'cart',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CartContext, CartEvent>(
            machine: machine,
            child: Column(
              children: [
                StateMachineBuilder<CartContext, CartEvent>(
                  builder: (context, state, send) {
                    return ElevatedButton(
                      onPressed: () => send(UpdateStatusEvent('ready')),
                      child: const Text('Ready'),
                    );
                  },
                ),
                StateMachineMatchSelector<CartContext, CartEvent>(
                  stateId: 'loading',
                  matchBuilder: (context, send) => const Text('Loading...'),
                  orElse: (context, send) => const Text('Content'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);

      await tester.tap(find.text('Ready'));
      await tester.pump();

      expect(find.text('Content'), findsOneWidget);
    });
  });

  group('StateMachineSelectorWithState', () {
    testWidgets('provides both state and selected value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CartContext, CartEvent>(
            machine: cartMachine,
            child: StateMachineSelectorWithState<CartContext, CartEvent, int>(
              selector: (ctx) => ctx.itemCount,
              builder: (context, state, count, send) {
                return Column(
                  children: [
                    Text('State: ${state.value}'),
                    Text('Count: $count'),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('State:'), findsOneWidget);
      expect(find.text('Count: 0'), findsOneWidget);
    });
  });
}
