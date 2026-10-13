import 'package:flutter/material.dart';

import 'models.dart';

/// Renders a card's image_ref, falling back to a stable suit symbol when the
/// reference is missing, invalid, or the asset/URL cannot be loaded.
class CardImage extends StatelessWidget {
  const CardImage({
    super.key,
    required this.imageRef,
    required this.suit,
    this.size = 48,
  });

  final String? imageRef;
  final Suit suit;
  final double size;

  static bool isSupportedRef(String ref) {
    return ref.startsWith('assets/') ||
        ref.startsWith('https://') ||
        ref.startsWith('http://');
  }

  @override
  Widget build(BuildContext context) {
    final ref = imageRef;
    Widget child;
    if (ref == null || !isSupportedRef(ref)) {
      child = _fallback();
    } else if (ref.startsWith('assets/')) {
      child = Image.asset(
        ref,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Asset image failed for "$ref": $error');
          return _fallback();
        },
      );
    } else {
      child = Image.network(
        ref,
        fit: BoxFit.cover,
        loadingBuilder: (context, image, progress) {
          if (progress == null) return image;
          return const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Network image failed for "$ref": $error');
          return _fallback();
        },
      );
    }
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: child,
      ),
    );
  }

  Widget _fallback() {
    final isRed = suit == Suit.hearts || suit == Suit.diamonds;
    return Semantics(
      label: '${suit.label} placeholder image',
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(
          suit.symbol,
          style: TextStyle(
            fontSize: size * 0.55,
            color: isRed ? Colors.red.shade700 : Colors.black87,
          ),
        ),
      ),
    );
  }
}
