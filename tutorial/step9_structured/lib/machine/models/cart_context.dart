import 'cart_item.dart';

/// Shopping cart context - holds all cart state data
class CartContext {
  final List<CartItem> items;
  final String? promoCode;
  final double discount;
  final String? error;

  const CartContext({
    this.items = const [],
    this.promoCode,
    this.discount = 0,
    this.error,
  });

  CartContext copyWith({
    List<CartItem>? items,
    String? promoCode,
    double? discount,
    String? error,
    bool clearError = false,
    bool clearPromo = false,
  }) => CartContext(
    items: items ?? this.items,
    promoCode: clearPromo ? null : (promoCode ?? this.promoCode),
    discount: discount ?? this.discount,
    error: clearError ? null : (error ?? this.error),
  );

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get total => subtotal * (1 - discount);
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  @override
  String toString() {
    return '''CartContext {
  items: ${items.map((i) => '${i.name} x${i.quantity}').join(', ')}
  subtotal: \$${subtotal.toStringAsFixed(2)}
  discount: ${(discount * 100).toInt()}%
  total: \$${total.toStringAsFixed(2)}
  promoCode: $promoCode
  error: $error
}''';
  }
}
