import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

import '../machine/events/cart_events.dart';
import '../machine/models/cart_context.dart';
import 'cart_item_tile.dart';
import 'order_summary.dart';
import 'product_grid.dart';
import 'promo_code_input.dart';
import 'status_banner.dart';

/// Main cart view widget
class CartView extends StatelessWidget {
  const CartView({super.key});

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
              StatusBanner(
                isBrowsing: isBrowsing,
                isProcessing: isProcessing,
                isSuccess: isSuccess,
                isFailed: isFailed,
                error: ctx.error,
              ),
              const SizedBox(height: 16),

              // Product list (only when browsing)
              if (isBrowsing) ...[
                Text(
                  'Products',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ProductGrid(send: send),
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
                _buildEmptyCart()
              else
                ...ctx.items.map(
                  (item) => CartItemTile(
                    item: item,
                    enabled: isBrowsing,
                    onRemove: () => send(RemoveItemEvent(item.id)),
                    onUpdateQuantity: (q) =>
                        send(UpdateQuantityEvent(item.id, q)),
                  ),
                ),

              // Promo code (only when browsing with items)
              if (isBrowsing && ctx.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                PromoCodeInput(
                  currentCode: ctx.promoCode,
                  onApply: (code) => send(ApplyPromoEvent(code)),
                  onRemove: () => send(RemovePromoEvent()),
                ),
              ],

              // Totals
              if (ctx.items.isNotEmpty || isSuccess) ...[
                const SizedBox(height: 16),
                OrderSummary(ctx: ctx),
              ],

              // Actions
              const SizedBox(height: 24),
              _buildActions(
                context,
                send: send,
                isBrowsing: isBrowsing,
                isProcessing: isProcessing,
                isSuccess: isSuccess,
                isFailed: isFailed,
                hasItems: ctx.items.isNotEmpty,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text('Cart is empty', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context, {
    required void Function(CartEvent) send,
    required bool isBrowsing,
    required bool isProcessing,
    required bool isSuccess,
    required bool isFailed,
    required bool hasItems,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isBrowsing && hasItems)
          FilledButton.icon(
            onPressed: () => send(CheckoutEvent()),
            icon: const Icon(Icons.shopping_cart_checkout),
            label: const Text('Checkout'),
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
          FilledButton.icon(
            onPressed: () => send(RetryPaymentEvent()),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Payment'),
          ),

        if (isSuccess || isFailed) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => send(ContinueShoppingEvent()),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Continue Shopping'),
          ),
        ],
      ],
    );
  }
}
