import 'package:flutter/material.dart';
import 'key_data.dart';
import 'key_segment.dart';
import 'branch_overlay.dart';

/// The main keyboard surface: configurable columns × rows of [KeySegment]s
/// plus the branch overlay system.
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
  // Branch stack: each entry is a (node, globalCenter) pair
  final List<_BranchEntry> _branchStack = [];

  void _onHold(BranchNode node, Offset globalCenter) {
    if (node.children.isEmpty) return; // nothing to branch into
    setState(() {
      _branchStack.clear();
      _branchStack.add(_BranchEntry(node, globalCenter));
    });
  }

  void _onBranchCommit(String glyph) {
    setState(() => _branchStack.clear());
    widget.onGlyph(glyph);
  }

  void _onBranchDrillDown(BranchNode node, Offset center) {
    if (node.children.isEmpty) {
      _onBranchCommit(node.glyph);
      return;
    }
    setState(() => _branchStack.add(_BranchEntry(node, center)));
  }

  void _onBranchCancel() {
    setState(() {
      if (_branchStack.isNotEmpty) _branchStack.removeLast();
    });
  }

  void _onKeyTap(String glyph) {
    if (glyph == '#') {
      widget.onSettings();
      return;
    }
    widget.onGlyph(glyph);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = widget.columns;
      final rows = (widget.keys.length / cols).ceil();
      final keyW = constraints.maxWidth / cols;
      final keyH = constraints.maxHeight / rows;
      final keySize = (keyW < keyH ? keyW : keyH) * 0.85;

      return Stack(
        children: [
          // Key grid
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: keyW / keyH,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: widget.keys.length,
            padding: const EdgeInsets.all(4),
            itemBuilder: (ctx, i) {
              final node = widget.keys[i];
              return KeySegment(
                node: node,
                opacity: widget.opacity,
                onTap: _onKeyTap,
                onHold: (n, center) => _onHold(n, center),
              );
            },
          ),

          // Branch overlays (layered, deepest on top)
          if (_branchStack.isNotEmpty)
            Positioned.fill(
              child: _BranchLayer(
                stack: _branchStack,
                keySize: keySize,
                onCommit: _onBranchCommit,
                onDrillDown: _onBranchDrillDown,
                onCancel: _onBranchCancel,
              ),
            ),
        ],
      );
    });
  }
}

class _BranchEntry {
  final BranchNode node;
  final Offset center;
  _BranchEntry(this.node, this.center);
}

/// Renders the topmost branch overlay and handles pointer routing.
class _BranchLayer extends StatefulWidget {
  final List<_BranchEntry> stack;
  final double keySize;
  final ValueChanged<String> onCommit;
  final void Function(BranchNode, Offset) onDrillDown;
  final VoidCallback onCancel;

  const _BranchLayer({
    required this.stack,
    required this.keySize,
    required this.onCommit,
    required this.onDrillDown,
    required this.onCancel,
  });

  @override
  State<_BranchLayer> createState() => _BranchLayerState();
}

class _BranchLayerState extends State<_BranchLayer> {
  @override
  Widget build(BuildContext context) {
    final entry = widget.stack.last;
    return BranchOverlay(
      node: entry.node,
      center: entry.center,
      keySize: widget.keySize,
      onCommit: widget.onCommit,
      onDrillDown: (node) => widget.onDrillDown(node, entry.center),
      onCancel: widget.onCancel,
    );
  }
}
