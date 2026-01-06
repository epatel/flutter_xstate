import 'package:flutter_xstate/flutter_xstate.dart';

import '../../actions/cart_actions.dart';
import '../../events/cart_events.dart';
import '../../models/cart_context.dart';

/// Configure the checkout.failed state
///
/// Payment failed. User can:
/// - Retry payment
/// - Continue shopping (preserves cart)
void buildFailedState(StateBuilder<CartContext, CartEvent> s) {
  s.on<RetryPaymentEvent>(
    'checkout.processing',
    actions: [CartActions.clearError],
  );
}
