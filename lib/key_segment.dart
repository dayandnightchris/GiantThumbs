import 'package:flutter/material.dart';
import 'key_data.dart';

/// A single large transparent key cell.
/// - Tap → emits [node.glyph]
/// - Long-press → triggers [onHold] so parent can show branch overlay
class KeySegment extends StatefulWidget {
  final BranchNode node;
  final double opacity;
  final ValueChanged<String> onTap;
  final void Function(BranchNode node, Offset globalCenter) onHold;

  const KeySegment({
    super.key,
    required this.node,
    required this.opacity,
    required this.onTap,
    required this.onHold,
  });

  @override
  State<KeySegment> createState() => _KeySegmentState();
}

class _KeySegmentState extends State<KeySegment> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onTap(widget.node.glyph),
      onLongPressStart: (details) {
        widget.onHold(widget.node, details.globalPosition);
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: widget.opacity),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.node.glyph,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}
