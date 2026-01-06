import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

import '../machine/cart_machine.dart';
import '../machine/events/cart_events.dart';
import '../machine/models/cart_context.dart';
import '../machine/models/cart_item.dart';
import 'cart_view.dart';

/// Main demo screen with inspector panel toggle
class InspectorDemoScreen extends StatefulWidget {
  final StateMachineActor<CartContext, CartEvent> actor;

  const InspectorDemoScreen({super.key, required this.actor});

  @override
  State<InspectorDemoScreen> createState() => _InspectorDemoScreenState();
}

class _InspectorDemoScreenState extends State<InspectorDemoScreen> {
  bool _showInspector = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 9: Structured Project'),
        actions: [
          IconButton(
            icon: Icon(
              _showInspector ? Icons.visibility_off : Icons.visibility,
            ),
            tooltip: _showInspector ? 'Hide Inspector' : 'Show Inspector',
            onPressed: () => setState(() => _showInspector = !_showInspector),
          ),
        ],
      ),
      body: Row(
        children: [
          // Main app content
          const Expanded(flex: 2, child: CartView()),
          // Inspector panel
          if (_showInspector)
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(8),
                child: StateMachineInspectorPanel<CartContext, CartEvent>(
                  actor: widget.actor,
                  machine: cartMachine,
                  eventBuilders: {
                    'ADD_ITEM': () => AddItemEvent(
                      const CartItem(
                        id: 'test',
                        name: 'Test Item',
                        price: 9.99,
                      ),
                    ),
                    'CLEAR_CART': () => ClearCartEvent(),
                    'CHECKOUT': () => CheckoutEvent(),
                    'PAYMENT_SUCCESS': () => PaymentSuccessEvent(),
                    'PAYMENT_FAILURE': () =>
                        PaymentFailureEvent('Card declined'),
                    'RETRY_PAYMENT': () => RetryPaymentEvent(),
                    'CONTINUE': () => ContinueShoppingEvent(),
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
