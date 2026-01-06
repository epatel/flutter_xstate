import 'package:flutter_xstate/flutter_xstate.dart';

import '../actions/cart_actions.dart';
import '../events/cart_events.dart';
import '../guards/cart_guards.dart';
import '../models/cart_context.dart';

/// Configure the browsing state
///
/// This is the main shopping state where users can:
/// - Add/remove items
/// - Update quantities
/// - Apply promo codes
/// - Proceed to checkout
void buildBrowsingState(StateBuilder<CartContext, CartEvent> s) {
  s
    ..on<AddItemEvent>(null, actions: [CartActions.addItem])
    ..on<RemoveItemEvent>(null, actions: [CartActions.removeItem])
    ..on<UpdateQuantityEvent>(null, actions: [CartActions.updateQuantity])
    ..on<ApplyPromoEvent>(null, actions: [CartActions.applyPromo])
    ..on<RemovePromoEvent>(null, actions: [CartActions.removePromo])
    ..on<ClearCartEvent>(null, actions: [CartActions.clearCart])
    ..on<CheckoutEvent>('checkout.processing', guard: CartGuards.hasItems);
}
