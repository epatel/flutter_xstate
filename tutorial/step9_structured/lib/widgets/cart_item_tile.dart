import 'package:flutter/material.dart';

import '../machine/models/cart_item.dart';

/// Single cart item row with quantity controls
class CartItemTile extends StatelessWidget {
  final CartItem item;
  final bool enabled;
  final VoidCallback onRemove;
  final void Function(int) onUpdateQuantity;

  const CartItemTile({
    super.key,
    required this.item,
    required this.enabled,
    required this.onRemove,
    required this.onUpdateQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${item.price.toStringAsFixed(2)} each',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          if (enabled) ...[
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              onPressed: () => onUpdateQuantity(item.quantity - 1),
            ),
            Text('${item.quantity}'),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => onUpdateQuantity(item.quantity + 1),
            ),
          ] else
            Text('x${item.quantity}'),
          const SizedBox(width: 8),
          Text(
            '\$${item.total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (enabled)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
