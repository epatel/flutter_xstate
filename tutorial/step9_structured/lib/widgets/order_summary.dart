import 'package:flutter/material.dart';

import '../machine/models/cart_context.dart';

/// Order summary showing subtotal, discount, and total
class OrderSummary extends StatelessWidget {
  final CartContext ctx;

  const OrderSummary({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Subtotal'),
              const Spacer(),
              Text('\$${ctx.subtotal.toStringAsFixed(2)}'),
            ],
          ),
          if (ctx.discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Discount (${(ctx.discount * 100).toInt()}%)',
                  style: const TextStyle(color: Colors.green),
                ),
                const Spacer(),
                Text(
                  '-\$${(ctx.subtotal * ctx.discount).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Spacer(),
              Text(
                '\$${ctx.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
