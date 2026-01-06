import 'package:flutter/material.dart';

import '../machine/events/cart_events.dart';
import '../machine/models/cart_item.dart';

/// Grid of products available for purchase
class ProductGrid extends StatelessWidget {
  final void Function(CartEvent) send;

  const ProductGrid({super.key, required this.send});

  static const _products = [
    CartItem(id: '1', name: 'Widget Pro', price: 29.99),
    CartItem(id: '2', name: 'Gadget Plus', price: 49.99),
    CartItem(id: '3', name: 'Thingamajig', price: 19.99),
    CartItem(id: '4', name: 'Doohickey', price: 39.99),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _products.map((product) {
        return ActionChip(
          avatar: const Icon(Icons.add_shopping_cart, size: 18),
          label: Text('${product.name} \$${product.price.toStringAsFixed(2)}'),
          onPressed: () => send(AddItemEvent(product)),
        );
      }).toList(),
    );
  }
}
