import 'package:flutter_xstate/flutter_xstate.dart';

import '../models/cart_item.dart';

/// Base class for all cart events
sealed class CartEvent extends XEvent {}

/// Add an item to the cart
class AddItemEvent extends CartEvent {
  final CartItem item;
  AddItemEvent(this.item);

  @override
  String get type => 'ADD_ITEM';
}

/// Remove an item from the cart
class RemoveItemEvent extends CartEvent {
  final String itemId;
  RemoveItemEvent(this.itemId);

  @override
  String get type => 'REMOVE_ITEM';
}

/// Update item quantity
class UpdateQuantityEvent extends CartEvent {
  final String itemId;
  final int quantity;
  UpdateQuantityEvent(this.itemId, this.quantity);

  @override
  String get type => 'UPDATE_QUANTITY';
}

/// Apply a promo code
class ApplyPromoEvent extends CartEvent {
  final String code;
  ApplyPromoEvent(this.code);

  @override
  String get type => 'APPLY_PROMO';
}

/// Remove the applied promo code
class RemovePromoEvent extends CartEvent {
  @override
  String get type => 'REMOVE_PROMO';
}

/// Start checkout process
class CheckoutEvent extends CartEvent {
  @override
  String get type => 'CHECKOUT';
}

/// Payment completed successfully
class PaymentSuccessEvent extends CartEvent {
  @override
  String get type => 'PAYMENT_SUCCESS';
}

/// Payment failed
class PaymentFailureEvent extends CartEvent {
  final String error;
  PaymentFailureEvent(this.error);

  @override
  String get type => 'PAYMENT_FAILURE';
}

/// Retry payment after failure
class RetryPaymentEvent extends CartEvent {
  @override
  String get type => 'RETRY_PAYMENT';
}

/// Return to browsing
class ContinueShoppingEvent extends CartEvent {
  @override
  String get type => 'CONTINUE_SHOPPING';
}

/// Clear all items from cart
class ClearCartEvent extends CartEvent {
  @override
  String get type => 'CLEAR_CART';
}
