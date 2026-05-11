import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'key_data.dart';

/// Displays a radial ring of branch children around a center point.
/// The user can swipe onto a child to select it (or hold to go deeper).
class BranchOverlay extends StatefulWidget {
  final BranchNode node;
  final Offset center;
  final double keySize;

  /// Called when a leaf glyph is committed (tap-up on a branch child).
  final ValueChanged<String> onCommit;

  /// Called when a branch child is held long enough to expand further.
  final ValueChanged<BranchNode> onDrillDown;

  /// Called when the user lifts outside all children (cancel).
  final VoidCallback onCancel;

  const BranchOverlay({
    super.key,
    required this.node,
    required this.center,
    required this.keySize,
    required this.onCommit,
    required this.onDrillDown,
    required this.onCancel,
  });

  @override
  State<BranchOverlay> createState() => _BranchOverlayState();
}

class _BranchOverlayState extends State<BranchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  List<BranchNode> get children => widget.node.children;

  Offset _childOffset(int i) {
    final count = children.length;
    final radius = widget.keySize * 1.3;
    final angle = (2 * math.pi / count) * i - math.pi / 2;
    return Offset(
      widget.center.dx + radius * math.cos(angle),
      widget.center.dy + radius * math.sin(angle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Stack(
          children: [
            // Dim background tap-catcher
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onCancel,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Centre label (parent glyph)
            _buildChip(widget.node.glyph, widget.center, false,
                isCenter: true),
            // Child glyphs
            for (int i = 0; i < children.length; i++)
              _buildChip(
                children[i].glyph,
                _childOffset(i),
                _hoveredIndex == i,
              ),
          ],
        );
      },
    );
  }

  Widget _buildChip(String glyph, Offset pos, bool highlighted,
      {bool isCenter = false}) {
    final size = widget.keySize * _anim.value;
    final bg = isCenter
        ? Colors.black54
        : highlighted
            ? Colors.white
            : Colors.black45;
    final fg = highlighted ? Colors.black : Colors.white;
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      width: size,
      height: size,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex =
            isCenter ? null : children.indexWhere((c) => c.glyph == glyph)),
        child: GestureDetector(
          onTap: isCenter ? null : () => widget.onCommit(glyph),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: highlighted ? Colors.white : Colors.white30,
                width: highlighted ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              glyph,
              style: TextStyle(
                fontSize: size * 0.4,
                color: fg,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
