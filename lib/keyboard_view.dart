import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'key_data.dart';

class KeyboardView extends StatefulWidget {
  final List<BranchNode> keys;
  final int columns;
  final double opacity;
  final ValueChanged<String> onGlyph;
  final VoidCallback onSettings;

  const KeyboardView({
    super.key,
    required this.keys,
    required this.columns,
    required this.opacity,
    required this.onGlyph,
    required this.onSettings,
  });

  @override
  State<KeyboardView> createState() => _KeyboardViewState();
}

class _KeyboardViewState extends State<KeyboardView> {
  late List<BranchNode?> _activeNodes;
  final List<List<BranchNode?>> _history = [];

  int? _hoveredIndex;
  int? _pressedIndex;
  Timer? _branchTimer;
  bool _isBranching = false;

  @override
  void initState() {
    super.initState();
    _activeNodes = List.from(widget.keys);
    while (_activeNodes.length < 12) _activeNodes.add(null);
  }

  void _handlePointerDown(PointerDownEvent e, BoxConstraints constraints) {
    final index = _getIndexFromOffset(e.localPosition, constraints);
    if (index == null) return;
    setState(() {
      _pressedIndex = index;
      _hoveredIndex = index;
    });
    _startBranchTimer(index);
  }

  void _handlePointerMove(PointerMoveEvent e, BoxConstraints constraints) {
    final index = _getIndexFromOffset(e.localPosition, constraints);
    if (index == _hoveredIndex) return;
    setState(() => _hoveredIndex = index);
    _branchTimer?.cancel();
    if (index != null) _startBranchTimer(index);
  }

  void _handlePointerUp(PointerUpEvent e) {
    _branchTimer?.cancel();
    if (_hoveredIndex != null && _hoveredIndex! < _activeNodes.length) {
      final node = _activeNodes[_hoveredIndex!];
      if (node != null) {
        if (node.glyph == '#') widget.onSettings();
        else {
          widget.onGlyph(node.glyph);
          HapticFeedback.lightImpact();
        }
      }
    }
    _resetGrid();
  }

  void _startBranchTimer(int index) {
    final node = _activeNodes[index];
    if (node == null || node.children.isEmpty) return;
    _branchTimer = Timer(const Duration(milliseconds: 350), () => _branchInto(node, index));
  }

  void _branchInto(BranchNode node, int parentIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBranching = true;
      _history.add(List.from(_activeNodes));

      final newNodes = List<BranchNode?>.filled(12, null);
      newNodes[parentIndex] = node;

      final pRow = parentIndex ~/ widget.columns;
      final pCol = parentIndex % widget.columns;

      // Define patterns of relative offsets for pairs
      // Pair 1: Right, Pair 2: Diag, Pair 3: Down, Pair 4: Misc
      final List<Offset> offsets = [
        const Offset(0, 1), const Offset(0, 2),   // a, A
        const Offset(1, 1), const Offset(2, 2),   // b, B
        const Offset(1, 0), const Offset(2, 0),   // c, C
        const Offset(1, -1), const Offset(2, -2), // misc/D
        const Offset(2, 1), const Offset(1, 2),
      ];

      int childIdx = 0;
      for (var offset in offsets) {
        if (childIdx >= node.children.length) break;

        int targetRow = pRow + offset.dy.toInt();
        int targetCol = pCol + offset.dx.toInt();

        // If off-screen, try to flip the offset (e.g. if too far right, go left)
        if (targetCol >= widget.columns) targetCol = pCol - (targetCol - pCol);
        if (targetCol < 0) targetCol = pCol + (pCol - targetCol);
        if (targetRow >= 4) targetRow = pRow - (targetRow - pRow);
        if (targetRow < 0) targetRow = pRow + (pRow - targetRow);

        // Clamp to valid grid
        targetRow = targetRow.clamp(0, 3);
        targetCol = targetCol.clamp(0, widget.columns - 1);

        int targetIdx = targetRow * widget.columns + targetCol;

        // Don't overwrite parent or already filled slot
        if (targetIdx != parentIndex && newNodes[targetIdx] == null) {
          newNodes[targetIdx] = node.children[childIdx];
          childIdx++;
        }
      }

      // Fill any remaining children in empty spots
      for (int i = 0; i < 12 && childIdx < node.children.length; i++) {
        if (newNodes[i] == null) {
          newNodes[i] = node.children[childIdx];
          childIdx++;
        }
      }

      _activeNodes = newNodes;
    });
  }

  void _resetGrid() {
    setState(() {
      _activeNodes = List.from(widget.keys);
      while (_activeNodes.length < 12) _activeNodes.add(null);
      _history.clear();
      _hoveredIndex = _pressedIndex = null;
      _isBranching = false;
    });
  }

  int? _getIndexFromOffset(Offset localPos, BoxConstraints constraints) {
    final x = localPos.dx, y = localPos.dy;
    if (x < 0 || x > constraints.maxWidth || y < 0 || y > constraints.maxHeight) return null;
    final colWidth = constraints.maxWidth / widget.columns;
    final rowHeight = constraints.maxHeight / 4;
    final col = (x / colWidth).floor().clamp(0, widget.columns - 1);
    final row = (y / rowHeight).floor().clamp(0, 3);
    return row * widget.columns + col;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Listener(
        onPointerDown: (e) => _handlePointerDown(e, constraints),
        onPointerMove: (e) => _handlePointerMove(e, constraints),
        onPointerUp: _handlePointerUp,
        onPointerCancel: (_) => _resetGrid(),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.columns,
            childAspectRatio: (constraints.maxWidth / widget.columns) / (constraints.maxHeight / 4),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 12,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, i) {
            final node = _activeNodes[i];
            final isHovered = _hoveredIndex == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: node == null ? Colors.transparent : isHovered
                  ? Colors.tealAccent.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: widget.opacity),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isHovered ? Colors.tealAccent : Colors.white30, width: isHovered ? 2.5 : 1.0),
              ),
              alignment: Alignment.center,
              child: Text(node?.glyph ?? '', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isHovered ? Colors.tealAccent : Colors.white)),
            );
          },
        ),
      );
    });
  }
}
