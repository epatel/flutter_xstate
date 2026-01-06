import 'package:flutter_xstate/flutter_xstate.dart';

import '../../events/cart_events.dart';
import '../../models/cart_context.dart';
import 'failed_state.dart';
import 'processing_state.dart';
import 'success_state.dart';

/// Configure the checkout compound state
///
/// This is a compound state with three children:
/// - processing: Waiting for payment result
/// - success: Order completed
/// - failed: Payment failed
///
/// The ContinueShoppingEvent is handled at this level,
/// allowing return to browsing from any child state.
void buildCheckoutState(StateBuilder<CartContext, CartEvent> s) {
  s
    ..initial('processing')
    // Handle at parent level - works from any child state
    ..on<ContinueShoppingEvent>('browsing')
    // Child states
    ..state('processing', buildProcessingState)
    ..state('success', buildSuccessState)
    ..state('failed', buildFailedState);
}
