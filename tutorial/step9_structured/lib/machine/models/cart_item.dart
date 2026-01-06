/// Cart item model
class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;

  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  CartItem copyWith({int? quantity}) => CartItem(
    id: id,
    name: name,
    price: price,
    quantity: quantity ?? this.quantity,
  );

  double get total => price * quantity;
}
