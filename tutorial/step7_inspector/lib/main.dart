/// Step 7: Inspector Panel - Visual Debugging Tools
///
/// Demonstrates:
/// - StateMachineInspectorPanel widget
/// - Live state tree visualization
/// - Transition history timeline
/// - Event sender for testing
/// - InspectorOverlay for floating debug button
///
/// Run with: flutter run -d chrome

import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// CONTEXT - Shopping Cart
// ============================================================================

class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;

  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  CartItem copyWith({int? quantity}) => CartItem(
        id: id,
        name: name,
        price: price,
        quantity: quantity ?? this.quantity,
      );

  double get total => price * quantity;
}

class CartContext {
  final List<CartItem> items;
  final String? promoCode;
  final double discount;
  final String? error;

  const CartContext({
    this.items = const [],
    this.promoCode,
    this.discount = 0,
    this.error,
  });

  CartContext copyWith({
    List<CartItem>? items,
    String? promoCode,
    double? discount,
    String? error,
    bool clearError = false,
    bool clearPromo = false,
  }) =>
      CartContext(
        items: items ?? this.items,
        promoCode: clearPromo ? null : (promoCode ?? this.promoCode),
        discount: discount ?? this.discount,
        error: clearError ? null : (error ?? this.error),
      );

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get total => subtotal * (1 - discount);
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  @override
  String toString() {
    return '''CartContext {
  items: ${items.map((i) => '${i.name} x${i.quantity}').join(', ')}
  subtotal: \$${subtotal.toStringAsFixed(2)}
  discount: ${(discount * 100).toInt()}%
  total: \$${total.toStringAsFixed(2)}
  promoCode: $promoCode
  error: $error
}''';
  }
}

// ============================================================================
// EVENTS
// ============================================================================

sealed class CartEvent extends XEvent {}

class AddItemEvent extends CartEvent {
  final CartItem item;
  AddItemEvent(this.item);

  @override
  String get type => 'ADD_ITEM';
}

class RemoveItemEvent extends CartEvent {
  final String itemId;
  RemoveItemEvent(this.itemId);

  @override
  String get type => 'REMOVE_ITEM';
}

class UpdateQuantityEvent extends CartEvent {
  final String itemId;
  final int quantity;
  UpdateQuantityEvent(this.itemId, this.quantity);

  @override
  String get type => 'UPDATE_QUANTITY';
}

class ApplyPromoEvent extends CartEvent {
  final String code;
  ApplyPromoEvent(this.code);

  @override
  String get type => 'APPLY_PROMO';
}

class RemovePromoEvent extends CartEvent {
  @override
  String get type => 'REMOVE_PROMO';
}

class CheckoutEvent extends CartEvent {
  @override
  String get type => 'CHECKOUT';
}

class PaymentSuccessEvent extends CartEvent {
  @override
  String get type => 'PAYMENT_SUCCESS';
}

class PaymentFailureEvent extends CartEvent {
  final String error;
  PaymentFailureEvent(this.error);

  @override
  String get type => 'PAYMENT_FAILURE';
}

class RetryPaymentEvent extends CartEvent {
  @override
  String get type => 'RETRY_PAYMENT';
}

class ContinueShoppingEvent extends CartEvent {
  @override
  String get type => 'CONTINUE_SHOPPING';
}

class ClearCartEvent extends CartEvent {
  @override
  String get type => 'CLEAR_CART';
}

// ============================================================================
// STATE MACHINE
// ============================================================================

final cartMachine = StateMachine.create<CartContext, CartEvent>(
  (m) => m
    ..context(const CartContext())
    ..initial('browsing')

    // BROWSING - Adding items to cart
    ..state(
      'browsing',
      (s) => s
        ..on<AddItemEvent>(null, actions: [
          (ctx, event) {
            final e = event as AddItemEvent;
            final existing = ctx.items.indexWhere((i) => i.id == e.item.id);
            if (existing >= 0) {
              final updated = ctx.items.map((i) {
                if (i.id == e.item.id) {
                  return i.copyWith(quantity: i.quantity + 1);
                }
                return i;
              }).toList();
              return ctx.copyWith(items: updated);
            }
            return ctx.copyWith(items: [...ctx.items, e.item]);
          },
        ])
        ..on<RemoveItemEvent>(null, actions: [
          (ctx, event) {
            final e = event as RemoveItemEvent;
            return ctx.copyWith(
              items: ctx.items.where((i) => i.id != e.itemId).toList(),
            );
          },
        ])
        ..on<UpdateQuantityEvent>(null, actions: [
          (ctx, event) {
            final e = event as UpdateQuantityEvent;
            if (e.quantity <= 0) {
              return ctx.copyWith(
                items: ctx.items.where((i) => i.id != e.itemId).toList(),
              );
            }
            return ctx.copyWith(
              items: ctx.items.map((i) {
                if (i.id == e.itemId) {
                  return i.copyWith(quantity: e.quantity);
                }
                return i;
              }).toList(),
            );
          },
        ])
        ..on<ApplyPromoEvent>(null, actions: [
          (ctx, event) {
            final e = event as ApplyPromoEvent;
            // Simple promo code validation
            if (e.code.toUpperCase() == 'SAVE10') {
              return ctx.copyWith(promoCode: e.code, discount: 0.10, clearError: true);
            } else if (e.code.toUpperCase() == 'SAVE20') {
              return ctx.copyWith(promoCode: e.code, discount: 0.20, clearError: true);
            }
            return ctx.copyWith(error: 'Invalid promo code');
          },
        ])
        ..on<RemovePromoEvent>(null, actions: [
          (ctx, _) => ctx.copyWith(clearPromo: true, discount: 0),
        ])
        ..on<ClearCartEvent>(null, actions: [
          (ctx, _) => ctx.copyWith(items: [], clearPromo: true, discount: 0),
        ])
        ..on<CheckoutEvent>(
          'checkout.processing',
          guard: (ctx, _) => ctx.items.isNotEmpty,
        ),
    )

    // CHECKOUT - Compound state
    ..state(
      'checkout',
      (s) => s
        ..initial('processing')
        ..on<ContinueShoppingEvent>('browsing')

        // Processing payment
        ..state(
          'processing',
          (child) => child
            ..on<PaymentSuccessEvent>('checkout.success')
            ..on<PaymentFailureEvent>('checkout.failed', actions: [
              (ctx, event) {
                final e = event as PaymentFailureEvent;
                return ctx.copyWith(error: e.error);
              },
            ]),
        )

        // Payment succeeded
        ..state(
          'success',
          (child) => child
            ..entry([
              (ctx, _) => ctx.copyWith(items: [], clearPromo: true, discount: 0),
            ])
            ..on<ContinueShoppingEvent>('browsing'),
        )

        // Payment failed
        ..state(
          'failed',
          (child) => child
            ..on<RetryPaymentEvent>('checkout.processing', actions: [
              (ctx, _) => ctx.copyWith(clearError: true),
            ]),
        ),
    ),
  id: 'cart',
);

// ============================================================================
// APP
// ============================================================================

// Global actor reference for the inspector demo
StateMachineActor<CartContext, CartEvent>? _cartActor;

void main() {
  runApp(const InspectorDemoApp());
}

class InspectorDemoApp extends StatelessWidget {
  const InspectorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step 7: Inspector Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: StateMachineProvider<CartContext, CartEvent>(
        machine: cartMachine,
        autoStart: true,
        onCreated: (actor) => _cartActor = actor,
        child: const InspectorDemoScreen(),
      ),
    );
  }
}

class InspectorDemoScreen extends StatefulWidget {
  const InspectorDemoScreen({super.key});

  @override
  State<InspectorDemoScreen> createState() => _InspectorDemoScreenState();
}

class _InspectorDemoScreenState extends State<InspectorDemoScreen> {
  bool _showInspector = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 7: Inspector Panel'),
        actions: [
          IconButton(
            icon: Icon(_showInspector ? Icons.visibility_off : Icons.visibility),
            tooltip: _showInspector ? 'Hide Inspector' : 'Show Inspector',
            onPressed: () => setState(() => _showInspector = !_showInspector),
          ),
        ],
      ),
      body: Row(
        children: [
          // Main app content
          Expanded(
            flex: 2,
            child: _CartView(),
          ),
          // Inspector panel
          if (_showInspector && _cartActor != null)
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(8),
                child: StateMachineInspectorPanel<CartContext, CartEvent>(
                  actor: _cartActor!,
                  machine: cartMachine,
                  eventBuilders: {
                    'ADD_ITEM': () => AddItemEvent(const CartItem(
                          id: 'test',
                          name: 'Test Item',
                          price: 9.99,
                        )),
                    'CLEAR_CART': () => ClearCartEvent(),
                    'CHECKOUT': () => CheckoutEvent(),
                    'PAYMENT_SUCCESS': () => PaymentSuccessEvent(),
                    'PAYMENT_FAILURE': () => PaymentFailureEvent('Card declined'),
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

// ============================================================================
// CART VIEW
// ============================================================================

class _CartView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<CartContext, CartEvent>(
      builder: (context, state, send) {
        final ctx = state.context;
        final isBrowsing = state.value.matches('browsing');
        final isProcessing = state.value.matches('checkout.processing');
        final isSuccess = state.value.matches('checkout.success');
        final isFailed = state.value.matches('checkout.failed');

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status banner
              _StatusBanner(
                isBrowsing: isBrowsing,
                isProcessing: isProcessing,
                isSuccess: isSuccess,
                isFailed: isFailed,
                error: ctx.error,
              ),
              const SizedBox(height: 16),

              // Product list (only when browsing)
              if (isBrowsing) ...[
                Text('Products', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _ProductGrid(send: send),
                const SizedBox(height: 24),
              ],

              // Cart items
              Row(
                children: [
                  Text('Cart', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (ctx.items.isNotEmpty && isBrowsing)
                    TextButton.icon(
                      onPressed: () => send(ClearCartEvent()),
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (ctx.items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text('Cart is empty',
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                )
              else
                ...ctx.items.map((item) => _CartItemTile(
                      item: item,
                      enabled: isBrowsing,
                      onRemove: () => send(RemoveItemEvent(item.id)),
                      onUpdateQuantity: (q) =>
                          send(UpdateQuantityEvent(item.id, q)),
                    )),

              // Promo code (only when browsing with items)
              if (isBrowsing && ctx.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                _PromoCodeInput(
                  currentCode: ctx.promoCode,
                  onApply: (code) => send(ApplyPromoEvent(code)),
                  onRemove: () => send(RemovePromoEvent()),
                ),
              ],

              // Totals
              if (ctx.items.isNotEmpty || isSuccess) ...[
                const SizedBox(height: 16),
                _OrderSummary(ctx: ctx),
              ],

              // Actions
              const SizedBox(height: 24),
              if (isBrowsing && ctx.items.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => send(CheckoutEvent()),
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: const Text('Checkout'),
                  ),
                ),

              if (isProcessing)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processing payment...'),
                    ],
                  ),
                ),

              if (isFailed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => send(RetryPaymentEvent()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Payment'),
                  ),
                ),

              if (isSuccess || isFailed) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => send(ContinueShoppingEvent()),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Continue Shopping'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isBrowsing;
  final bool isProcessing;
  final bool isSuccess;
  final bool isFailed;
  final String? error;

  const _StatusBanner({
    required this.isBrowsing,
    required this.isProcessing,
    required this.isSuccess,
    required this.isFailed,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    if (isSuccess) {
      color = Colors.green;
      icon = Icons.check_circle;
      text = 'Order placed successfully!';
    } else if (isFailed) {
      color = Colors.red;
      icon = Icons.error;
      text = error ?? 'Payment failed';
    } else if (isProcessing) {
      color = Colors.orange;
      icon = Icons.hourglass_empty;
      text = 'Processing...';
    } else {
      color = Colors.blue;
      icon = Icons.shopping_bag;
      text = 'Shopping';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final void Function(CartEvent) send;

  const _ProductGrid({required this.send});

  static const _products = [
    CartItem(id: '1', name: 'Widget Pro', price: 29.99),
    CartItem(id: '2', name: 'Gadget Plus', price: 49.99),
    CartItem(id: '3', name: 'Thingamajig', price: 19.99),
    CartItem(id: '4', name: 'Doohickey', price: 39.99),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _products.map((product) {
        return ActionChip(
          avatar: const Icon(Icons.add_shopping_cart, size: 18),
          label: Text('${product.name} \$${product.price.toStringAsFixed(2)}'),
          onPressed: () => send(AddItemEvent(product)),
        );
      }).toList(),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final bool enabled;
  final VoidCallback onRemove;
  final void Function(int) onUpdateQuantity;

  const _CartItemTile({
    required this.item,
    required this.enabled,
    required this.onRemove,
    required this.onUpdateQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '\$${item.price.toStringAsFixed(2)} each',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          if (enabled) ...[
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              onPressed: () => onUpdateQuantity(item.quantity - 1),
            ),
            Text('${item.quantity}'),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => onUpdateQuantity(item.quantity + 1),
            ),
          ] else
            Text('x${item.quantity}'),
          const SizedBox(width: 8),
          Text(
            '\$${item.total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (enabled)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _PromoCodeInput extends StatefulWidget {
  final String? currentCode;
  final void Function(String) onApply;
  final VoidCallback onRemove;

  const _PromoCodeInput({
    this.currentCode,
    required this.onApply,
    required this.onRemove,
  });

  @override
  State<_PromoCodeInput> createState() => _PromoCodeInputState();
}

class _PromoCodeInputState extends State<_PromoCodeInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (widget.currentCode != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text(
              'Promo: ${widget.currentCode}',
              style: const TextStyle(color: Colors.green),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Promo code (try SAVE10 or SAVE20)',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              widget.onApply(_controller.text);
              _controller.clear();
            }
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _OrderSummary extends StatelessWidget {
  final CartContext ctx;

  const _OrderSummary({required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Subtotal'),
              const Spacer(),
              Text('\$${ctx.subtotal.toStringAsFixed(2)}'),
            ],
          ),
          if (ctx.discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Discount (${(ctx.discount * 100).toInt()}%)',
                    style: const TextStyle(color: Colors.green)),
                const Spacer(),
                Text(
                  '-\$${(ctx.subtotal * ctx.discount).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              Text(
                '\$${ctx.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
