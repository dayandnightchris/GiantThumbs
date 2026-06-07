import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'key_data.dart';

/// The live keyboard grid.
///
/// Interaction model (instant branch):
///   • Touch a key → its children appear **immediately** (no delay). This is the
///     speed fix: the old 350 ms first-level timer is gone.
///   • Slide to a child and release → commits that child's glyph.
///   • Dwell on a child that has its *own* children (e.g. a letter with word
///     predictions) for [drillDelayMs] → drills one level deeper. Set the delay
///     to 0 to make deeper levels instant too.
class KeyboardView extends StatefulWidget {
  final List<BranchNode> keys;
  final int columns;
  final double opacity;

  /// Delay before drilling into a child that has children. The first branch
  /// level is always instant; this only affects deeper levels.
  final int drillDelayMs;

  final ValueChanged<String> onGlyph;
  final VoidCallback onSettings;

  const KeyboardView({
    super.key,
    required this.keys,
    required this.columns,
    required this.opacity,
    required this.onGlyph,
    required this.onSettings,
    this.drillDelayMs = 220,
  });

  /// Total number of cells in the grid. The top-level layout has exactly this
  /// many keys (1-9, *, 0, ⌫).
  static const int cellCount = 12;

  @override
  State<KeyboardView> createState() => _KeyboardViewState();
}

class _KeyboardViewState extends State<KeyboardView> {
  late List<BranchNode?> _activeNodes;
  final List<List<BranchNode?>> _history = [];

  int? _hoveredIndex;
  Timer? _drillTimer;
  Timer? _settingsTimer;
  bool _isBranching = false;
  bool _settingsOpened = false;

  /// Rows are derived from the column count so the grid always holds exactly
  /// [KeyboardView.cellCount] cells (2 cols → 6 rows, 3 → 4, 4 → 3).
  int get _rows => (KeyboardView.cellCount / widget.columns).ceil();

  @override
  void initState() {
    super.initState();
    _resetNodes();
  }

  @override
  void didUpdateWidget(KeyboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh the base grid if the layout or column count changed while idle.
    if (!_isBranching &&
        (oldWidget.keys != widget.keys ||
            oldWidget.columns != widget.columns)) {
      setState(_resetNodes);
    }
  }

  void _resetNodes() {
    _activeNodes = List<BranchNode?>.from(widget.keys);
    while (_activeNodes.length < KeyboardView.cellCount) {
      _activeNodes.add(null);
    }
    if (_activeNodes.length > KeyboardView.cellCount) {
      _activeNodes = _activeNodes.sublist(0, KeyboardView.cellCount);
    }
  }

  @override
  void dispose() {
    _drillTimer?.cancel();
    _settingsTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent e, BoxConstraints constraints) {
    final index = _getIndexFromOffset(e.localPosition, constraints);
    if (index == null) return;
    final node = _activeNodes[index];
    setState(() => _hoveredIndex = index);

    // Long-press on ⌫ (top-level only) opens settings; a tap is backspace.
    if (!_isBranching && node?.glyph == '⌫') {
      _settingsOpened = false;
      _settingsTimer = Timer(const Duration(milliseconds: 600), () {
        setState(() => _settingsOpened = true);
        widget.onSettings();
      });
    }

    // Instant first-level branch — the heart of the speed fix.
    if (node != null && node.children.isNotEmpty) {
      _branchInto(node, index);
    }
  }

  void _handlePointerMove(PointerMoveEvent e, BoxConstraints constraints) {
    final index = _getIndexFromOffset(e.localPosition, constraints);
    if (index == _hoveredIndex) return;
    setState(() => _hoveredIndex = index);
    _drillTimer?.cancel();
    if (index == null) return;

    final node = _activeNodes[index];
    if (node != null && node.children.isNotEmpty) {
      _scheduleDrill(node, index);
    }
  }

  void _scheduleDrill(BranchNode node, int index) {
    final delay = Duration(milliseconds: widget.drillDelayMs.clamp(0, 2000));
    _drillTimer = Timer(delay, () {
      // Only drill if the finger is still on this cell.
      if (_hoveredIndex == index) _branchInto(node, index);
    });
  }

  void _handlePointerUp(PointerUpEvent e) {
    _drillTimer?.cancel();
    _settingsTimer?.cancel();
    _settingsTimer = null;
    final idx = _hoveredIndex;
    if (idx != null && idx < _activeNodes.length) {
      final node = _activeNodes[idx];
      if (node != null) {
        if (node.glyph == '⌫') {
          // Tap = backspace; a hold already opened settings via the timer.
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

  void _branchInto(BranchNode node, int parentIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBranching = true;
      _history.add(List<BranchNode?>.from(_activeNodes));

      final cols = widget.columns;
      final rows = _rows;
      final newNodes = List<BranchNode?>.filled(KeyboardView.cellCount, null);
      newNodes[parentIndex] = node;

      final pRow = parentIndex ~/ cols;
      final pCol = parentIndex % cols;

      // Build a line of cells radiating from the parent in a given direction.
      List<int> line(int dRow, int dCol) {
        final cells = <int>[];
        int r = pRow + dRow, c = pCol + dCol;
        while (r >= 0 && r < rows && c >= 0 && c < cols) {
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

      final isCorner =
          (pRow == 0 || pRow == rows - 1) && (pCol == 0 || pCol == cols - 1);
      if (isCorner) {
        // Corner keys radiate along three lines: a short horizontal spoke, the
        // corner diagonal, and a long vertical spoke. Keeps children spatially
        // adjacent so muscle memory forms.
        final dRow = pRow == 0 ? 1 : -1;
        final dCol = pCol == 0 ? 1 : -1;
        addCells(line(0, dCol)); // horizontal
        addCells(line(dRow, dCol)); // corner diagonal
        addCells(line(dRow, 0)); // vertical
      } else {
        // Non-corner keys: cardinal spokes longest-first so consecutive
        // children stay cardinally adjacent.
        final spokes = [
          line(0, 1),
          line(1, 0),
          line(0, -1),
          line(-1, 0),
        ]..sort((a, b) => b.length.compareTo(a.length));
        for (final s in spokes) {
          addCells(s);
        }
      }

      // Overflow: any unplaced cells, nearest-first.
      final overflow = <int>[];
      for (int i = 0; i < KeyboardView.cellCount; i++) {
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
    _drillTimer?.cancel();
    _settingsTimer?.cancel();
    _settingsTimer = null;
    _settingsOpened = false;
    setState(() {
      _resetNodes();
      _history.clear();
      _hoveredIndex = null;
      _isBranching = false;
    });
  }

  int? _getIndexFromOffset(Offset localPos, BoxConstraints constraints) {
    final x = localPos.dx, y = localPos.dy;
    if (x < 0 || x > constraints.maxWidth || y < 0 || y > constraints.maxHeight) {
      return null;
    }
    final colWidth = constraints.maxWidth / widget.columns;
    final rowHeight = constraints.maxHeight / _rows;
    final col = (x / colWidth).floor().clamp(0, widget.columns - 1);
    final row = (y / rowHeight).floor().clamp(0, _rows - 1);
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
            childAspectRatio: (constraints.maxWidth / widget.columns) /
                (constraints.maxHeight / _rows),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: KeyboardView.cellCount,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, i) {
            final node = _activeNodes[i];
            final isHovered = _hoveredIndex == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: node == null
                    ? Colors.transparent
                    : isHovered
                        ? Colors.tealAccent.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: widget.opacity),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHovered ? Colors.tealAccent : Colors.white30,
                  width: isHovered ? 2.5 : 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                node?.glyph ?? '',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isHovered ? Colors.tealAccent : Colors.white,
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
