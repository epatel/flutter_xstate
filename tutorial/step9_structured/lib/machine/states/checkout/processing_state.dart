import 'package:flutter_xstate/flutter_xstate.dart';

import '../../actions/cart_actions.dart';
import '../../events/cart_events.dart';
import '../../models/cart_context.dart';

/// Configure the checkout.processing state
///
/// This state waits for payment result:
/// - Success -> checkout.success
/// - Failure -> checkout.failed
void buildProcessingState(StateBuilder<CartContext, CartEvent> s) {
  s
    ..on<PaymentSuccessEvent>('checkout.success')
    ..on<PaymentFailureEvent>(
      'checkout.failed',
      actions: [CartActions.recordPaymentError],
    );
}
