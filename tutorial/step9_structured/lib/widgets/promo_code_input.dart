import 'package:flutter/material.dart';

/// Promo code input field with apply/remove functionality
class PromoCodeInput extends StatefulWidget {
  final String? currentCode;
  final void Function(String) onApply;
  final VoidCallback onRemove;

  const PromoCodeInput({
    super.key,
    this.currentCode,
    required this.onApply,
    required this.onRemove,
  });

  @override
  State<PromoCodeInput> createState() => _PromoCodeInputState();
}

class _PromoCodeInputState extends State<PromoCodeInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (widget.currentCode != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text(
              'Promo: ${widget.currentCode}',
              style: const TextStyle(color: Colors.green),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Promo code (try SAVE10 or SAVE20)',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              widget.onApply(_controller.text);
              _controller.clear();
            }
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
