import 'package:flutter_xstate/flutter_xstate.dart';

import 'events/cart_events.dart';
import 'models/cart_context.dart';
import 'states/browsing_state.dart';
import 'states/checkout/checkout_state.dart';

/// Shopping cart state machine
///
/// This machine demonstrates modular state organization:
/// - States are defined in separate files
/// - Actions and guards are extracted to dedicated classes
/// - Compound states (checkout) have their children in a subfolder
///
/// State hierarchy:
/// ```
/// cart (root)
/// ├── browsing (initial)
/// └── checkout (compound)
///     ├── processing (initial)
///     ├── success
///     └── failed
/// ```
final cartMachine = StateMachine.create<CartContext, CartEvent>(
  (m) => m
    ..context(const CartContext())
    ..initial('browsing')
    ..state('browsing', buildBrowsingState)
    ..state('checkout', buildCheckoutState),
  id: 'cart',
);
