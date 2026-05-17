import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'key_data.dart';

/// Displays a radial ring of branch children.
/// Supports continuous swiping and multi-level branching.
class BranchOverlay extends StatefulWidget {
  final BranchNode node;
  final Offset center;
  final double keySize;

  final ValueChanged<String> onCommit;
  final void Function(BranchNode node, Offset newCenter) onDrillDown;
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
  Timer? _drillDownTimer;
  Offset? _lastPointerPos;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _drillDownTimer?.cancel();
    super.dispose();
  }

  List<BranchNode> get children => widget.node.children;

  Offset _getChildOffset(int i, Offset center) {
    final count = children.length;
    final radius = widget.keySize * 1.4;
    final angle = (2 * math.pi / count) * i - math.pi / 2;
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  void _handlePointerMove(Offset globalPos, Offset safeCenter) {
    _lastPointerPos = globalPos;
    int? nextHover;
    double closestDist = widget.keySize * 0.8;

    for (int i = 0; i < children.length; i++) {
      final childPos = _getChildOffset(i, safeCenter);
      final dist = (globalPos - childPos).distance;
      if (dist < closestDist) {
        closestDist = dist;
        nextHover = i;
      }
    }

    if (nextHover != _hoveredIndex) {
      setState(() => _hoveredIndex = nextHover);
      _drillDownTimer?.cancel();

      if (nextHover != null) {
        final child = children[nextHover];
        if (child.children.isNotEmpty) {
          _drillDownTimer = Timer(const Duration(milliseconds: 450), () {
            widget.onDrillDown(child, _getChildOffset(nextHover!, safeCenter));
          });
        }
      }
    }
  }

  void _handlePointerUp() {
    _drillDownTimer?.cancel();
    if (_hoveredIndex != null) {
      widget.onCommit(children[_hoveredIndex!].glyph);
    } else {
      // Check if we are still near the center
      if (_lastPointerPos != null && ( _lastPointerPos! - widget.center).distance < widget.keySize / 2) {
         // Optionally commit the center glyph or just cancel
         widget.onCancel();
      } else {
         widget.onCancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final radius = widget.keySize * 1.4;
      final margin = widget.keySize / 2 + 16;

      double shiftX = 0, shiftY = 0;
      if (widget.center.dx - radius < margin) shiftX = margin - (widget.center.dx - radius);
      else if (widget.center.dx + radius > constraints.maxWidth - margin) shiftX = (constraints.maxWidth - margin) - (widget.center.dx + radius);

      if (widget.center.dy - radius < margin) shiftY = margin - (widget.center.dy - radius);
      else if (widget.center.dy + radius > constraints.maxHeight - margin) shiftY = (constraints.maxHeight - margin) - (widget.center.dy + radius);

      final safeCenter = widget.center + Offset(shiftX, shiftY);

      return Listener(
        onPointerMove: (e) => _handlePointerMove(e.position, safeCenter),
        onPointerUp: (_) => _handlePointerUp(),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            return Stack(
              children: [
                Positioned.fill(child: Container(color: Colors.black26)),
                _buildChip(widget.node.glyph, safeCenter, false, isCenter: true),
                for (int i = 0; i < children.length; i++)
                  _buildChip(children[i].glyph, _getChildOffset(i, safeCenter), _hoveredIndex == i),
              ],
            );
          },
        ),
      );
    });
  }

  Widget _buildChip(String glyph, Offset pos, bool highlighted, {bool isCenter = false}) {
    final size = widget.keySize * (isCenter ? 0.9 : 1.0) * _anim.value;
    final bg = isCenter ? Colors.black87 : highlighted ? Colors.tealAccent : Colors.black54;
    final fg = highlighted ? Colors.black : Colors.white;

    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: highlighted ? Colors.white : Colors.white24, width: highlighted ? 3 : 1),
          boxShadow: highlighted ? [BoxShadow(color: Colors.tealAccent.withValues(alpha: 0.5), blurRadius: 10)] : null,
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
    );
  }
}
