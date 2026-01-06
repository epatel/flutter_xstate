import '../events/cart_events.dart';
import '../models/cart_context.dart';

/// Static guard methods for cart state machine
///
/// Guards are pure functions that take context and event,
/// returning true if the transition should proceed.
abstract final class CartGuards {
  /// Check if cart has items
  static bool hasItems(CartContext ctx, CartEvent _) {
    return ctx.items.isNotEmpty;
  }

  /// Check if cart is empty
  static bool isEmpty(CartContext ctx, CartEvent _) {
    return ctx.items.isEmpty;
  }

  /// Check if promo code is applied
  static bool hasPromoCode(CartContext ctx, CartEvent _) {
    return ctx.promoCode != null;
  }
}
