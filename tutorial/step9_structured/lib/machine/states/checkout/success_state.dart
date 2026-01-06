import 'package:flutter_xstate/flutter_xstate.dart';

import '../../actions/cart_actions.dart';
import '../../events/cart_events.dart';
import '../../models/cart_context.dart';

/// Configure the checkout.success state
///
/// Order completed successfully.
/// User can continue shopping (starts fresh).
void buildSuccessState(StateBuilder<CartContext, CartEvent> s) {
  s
    ..entry([CartActions.resetAfterSuccess])
    ..on<ContinueShoppingEvent>('browsing');
}
