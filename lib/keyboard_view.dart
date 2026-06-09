import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'key_data.dart';
import 'grid_placement.dart';

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
  /// many keys (1-9, *, 0, ⌫). Shared with the layout editor via
  /// [kKeyboardCellCount].
  static const int cellCount = kKeyboardCellCount;

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
  int get _rows => rowsForColumns(widget.columns);

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
      _activeNodes = placeBranch(
        parent: node,
        parentIndex: parentIndex,
        columns: widget.columns,
      );
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
            childAspectRatio: cellAspectRatio(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              columns: widget.columns,
            ),
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
