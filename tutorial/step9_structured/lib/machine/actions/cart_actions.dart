import '../events/cart_events.dart';
import '../models/cart_context.dart';

/// Static action methods for cart state machine
///
/// Actions are pure functions that take context and event,
/// returning updated context.
abstract final class CartActions {
  /// Add item to cart (or increment quantity if exists)
  static CartContext addItem(CartContext ctx, CartEvent event) {
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
  }

  /// Remove item from cart
  static CartContext removeItem(CartContext ctx, CartEvent event) {
    final e = event as RemoveItemEvent;
    return ctx.copyWith(
      items: ctx.items.where((i) => i.id != e.itemId).toList(),
    );
  }

  /// Update item quantity (removes if quantity <= 0)
  static CartContext updateQuantity(CartContext ctx, CartEvent event) {
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
  }

  /// Apply promo code
  static CartContext applyPromo(CartContext ctx, CartEvent event) {
    final e = event as ApplyPromoEvent;
    // Simple promo code validation
    if (e.code.toUpperCase() == 'SAVE10') {
      return ctx.copyWith(promoCode: e.code, discount: 0.10, clearError: true);
    } else if (e.code.toUpperCase() == 'SAVE20') {
      return ctx.copyWith(promoCode: e.code, discount: 0.20, clearError: true);
    }
    return ctx.copyWith(error: 'Invalid promo code');
  }

  /// Remove promo code
  static CartContext removePromo(CartContext ctx, CartEvent _) {
    return ctx.copyWith(clearPromo: true, discount: 0);
  }

  /// Clear all items from cart
  static CartContext clearCart(CartContext ctx, CartEvent _) {
    return ctx.copyWith(items: [], clearPromo: true, discount: 0);
  }

  /// Record payment error
  static CartContext recordPaymentError(CartContext ctx, CartEvent event) {
    final e = event as PaymentFailureEvent;
    return ctx.copyWith(error: e.error);
  }

  /// Clear error
  static CartContext clearError(CartContext ctx, CartEvent _) {
    return ctx.copyWith(clearError: true);
  }

  /// Reset cart after successful order
  static CartContext resetAfterSuccess(CartContext ctx, CartEvent _) {
    return ctx.copyWith(items: [], clearPromo: true, discount: 0);
  }
}
