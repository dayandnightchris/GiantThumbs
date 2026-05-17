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
  Timer? _settingsTimer;
  bool _isBranching = false;
  bool _settingsOpened = false;

  @override
  void initState() {
    super.initState();
    _activeNodes = List.from(widget.keys);
    while (_activeNodes.length < 12) _activeNodes.add(null);
  }

  @override
  void dispose() {
    _branchTimer?.cancel();
    _settingsTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent e, BoxConstraints constraints) {
    final index = _getIndexFromOffset(e.localPosition, constraints);
    if (index == null) return;
    setState(() {
      _pressedIndex = index;
      _hoveredIndex = index;
    });
    _startBranchTimer(index);
    // Long-press on ⌫ (top-level only) opens settings; tap triggers backspace.
    if (!_isBranching && index < _activeNodes.length && _activeNodes[index]?.glyph == '⌫') {
      _settingsOpened = false;
      _settingsTimer = Timer(const Duration(milliseconds: 600), () {
        setState(() => _settingsOpened = true);
        widget.onSettings();
      });
    }
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
    _settingsTimer?.cancel();
    _settingsTimer = null;
    if (_hoveredIndex != null && _hoveredIndex! < _activeNodes.length) {
      final node = _activeNodes[_hoveredIndex!];
      if (node != null) {
        if (node.glyph == '⌫') {
          // Tap = backspace; hold (600 ms, top-level only) already opened settings via timer.
          if (!_settingsOpened) {
            widget.onGlyph('⌫');
            HapticFeedback.lightImpact();
          }
        } else {
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

      final cols = widget.columns;

      // Build a line of cells from the parent in a given direction.
      List<int> line(int dRow, int dCol) {
        final cells = <int>[];
        int r = pRow + dRow, c = pCol + dCol;
        while (r >= 0 && r < 4 && c >= 0 && c < cols) {
          cells.add(r * cols + c);
          r += dRow;
          c += dCol;
        }
        return cells;
      }

      final candidates = <int>[];
      final placed = <int>{};
      void addCells(List<int> cells) {
        for (final idx in cells) {
          if (placed.add(idx)) candidates.add(idx);
        }
      }

      final isCorner = (pRow == 0 || pRow == 3) && (pCol == 0 || pCol == cols - 1);
      if (isCorner) {
        // Corner keys get three radiating lines:
        //   1. Short horizontal spoke (2 cells)  → first letter pair  (e.g. a, A)
        //   2. Corner diagonal (2 cells)          → second letter pair (e.g. b, B)
        //   3. Long vertical spoke (3 cells)      → third pair + extra (e.g. c, C, …)
        final dRow = pRow == 0 ? 1 : -1;
        final dCol = pCol == 0 ? 1 : -1;
        addCells(line(0, dCol));    // horizontal
        addCells(line(dRow, dCol)); // corner diagonal
        addCells(line(dRow, 0));    // vertical
      } else {
        // Non-corner keys: cardinal spokes longest-first so consecutive
        // children stay cardinally adjacent.
        final spokes = [
          line(0, 1), line(1, 0), line(0, -1), line(-1, 0),
        ]..sort((a, b) => b.length.compareTo(a.length));
        for (final s in spokes) addCells(s);
      }

      // Overflow: any unplaced cells, nearest-first.
      final overflow = <int>[];
      for (int i = 0; i < 12; i++) {
        if (i != parentIndex && !placed.contains(i)) overflow.add(i);
      }
      overflow.sort((a, b) {
        final aRow = a ~/ cols, aCol = a % cols;
        final bRow = b ~/ cols, bCol = b % cols;
        final aDist = (aRow - pRow) * (aRow - pRow) + (aCol - pCol) * (aCol - pCol);
        final bDist = (bRow - pRow) * (bRow - pRow) + (bCol - pCol) * (bCol - pCol);
        return aDist.compareTo(bDist);
      });
      candidates.addAll(overflow);

      final limit = candidates.length < node.children.length
          ? candidates.length
          : node.children.length;
      for (int i = 0; i < limit; i++) {
        newNodes[candidates[i]] = node.children[i];
      }

      _activeNodes = newNodes;
    });
  }

  void _resetGrid() {
    _settingsTimer?.cancel();
    _settingsTimer = null;
    _settingsOpened = false;
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
