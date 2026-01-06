import 'package:flutter/material.dart';

/// Status banner showing current cart/checkout state
class StatusBanner extends StatelessWidget {
  final bool isBrowsing;
  final bool isProcessing;
  final bool isSuccess;
  final bool isFailed;
  final String? error;

  const StatusBanner({
    super.key,
    required this.isBrowsing,
    required this.isProcessing,
    required this.isSuccess,
    required this.isFailed,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    if (isSuccess) {
      color = Colors.green;
      icon = Icons.check_circle;
      text = 'Order placed successfully!';
    } else if (isFailed) {
      color = Colors.red;
      icon = Icons.error;
      text = error ?? 'Payment failed';
    } else if (isProcessing) {
      color = Colors.orange;
      icon = Icons.hourglass_empty;
      text = 'Processing...';
    } else {
      color = Colors.blue;
      icon = Icons.shopping_bag;
      text = 'Shopping';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
