import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'key_data.dart';
import 'grid_placement.dart';
import 'layout_store.dart';

/// Which editing surface is shown.
///   • grid — WYSIWYG: the keys are laid out exactly as the real keyboard shows
///     them (same placement algorithm), so editing is spatial and intuitive.
///   • list — the utilitarian list: every tile in a row, with precise
///     drag-to-reorder. Kept as a power-user / accessibility option.
enum _EditMode { grid, list }

/// Full layout editor. Lets the user choose exactly what glyph sits in every
/// tile and branch, add/remove/reorder tiles, and drill into any tile's
/// children to edit the branch tree to any depth.
///
/// Edits a working copy and only persists when the user taps Save, so backing
/// out discards changes.
class LayoutEditorScreen extends StatefulWidget {
  final List<BranchNode> initial;
  final ValueChanged<List<BranchNode>> onSaved;

  /// Column count from the user's settings, so the WYSIWYG grid preview matches
  /// the real keyboard exactly.
  final int columns;

  const LayoutEditorScreen({
    super.key,
    required this.initial,
    required this.onSaved,
    this.columns = 3,
  });

  @override
  State<LayoutEditorScreen> createState() => _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends State<LayoutEditorScreen> {
  /// Virtual root whose children are the 12 top-level tiles.
  late BranchNode _root;

  /// Navigation stack into the tree; the last entry is the node being edited.
  late List<BranchNode> _path;

  _EditMode _mode = _EditMode.grid;

  @override
  void initState() {
    super.initState();
    _root =
        BranchNode('', children: widget.initial.map((n) => n.copy()).toList());
    _path = [_root];
  }

  BranchNode get _current => _path.last;
  bool get _atRoot => _path.length == 1;

  /// Max children that can actually be shown at the current level: the whole
  /// grid at the top, one less inside a branch (the parent occupies a cell).
  int get _maxVisible => _atRoot ? kKeyboardCellCount : kKeyboardCellCount - 1;

  String _breadcrumb() {
    if (_atRoot) return 'All tiles';
    return _path.skip(1).map((n) => _label(n.glyph)).join('  ›  ');
  }

  /// Human-readable label for control glyphs (used in the breadcrumb).
  String _label(String g) {
    switch (g) {
      case ' ':
        return '␣ space';
      case '\n':
        return '⏎ enter';
      case '':
        return '(empty)';
      default:
        return g;
    }
  }

  /// Short glyph label for a grid cell.
  String _cellLabel(String g) {
    if (g == ' ') return '␣';
    if (g == '\n') return '⏎';
    if (g.isEmpty) return '·';
    return g;
  }

  void _enter(BranchNode node) => setState(() => _path.add(node));

  void _up() {
    if (!_atRoot) setState(() => _path.removeLast());
  }

  void _addTile() {
    setState(() => _current.children.add(BranchNode('')));
  }

  /// Append a tile and immediately open its editor — the grid's "+" flow.
  void _addTileAndEdit() {
    final node = BranchNode('');
    setState(() => _current.children.add(node));
    _editCell(node);
  }

  void _delete(int i) {
    setState(() => _current.children.removeAt(i));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _current.children.removeAt(oldIndex);
      _current.children.insert(newIndex, item);
    });
  }

  /// Swap two children by index — the grid's drag-to-rearrange (dropping one
  /// tile on another trades their cells, since cell = list order).
  void _swapChildren(int a, int b) {
    if (a == b || a < 0 || b < 0) return;
    setState(() {
      final list = _current.children;
      final tmp = list[a];
      list[a] = list[b];
      list[b] = tmp;
    });
  }

  Future<void> _save() async {
    final layout = _root.children.map((n) => n.copy()).toList();
    await LayoutStore.saveLayout(layout);
    widget.onSaved(layout);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Layout saved')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset layout?'),
        content: const Text(
            'This replaces your custom layout with the built-in default.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _root = BranchNode('', children: defaultKeys());
        _path = [_root];
      });
    }
  }

  Future<void> _export() async {
    final json = LayoutStore.exportLayout(_root.children);
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layout JSON copied to clipboard')));
    }
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import layout'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Paste exported layout JSON here',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Import')),
        ],
      ),
    );
    if (json == null || json.trim().isEmpty) return;
    final parsed = LayoutStore.importLayout(json.trim());
    if (parsed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not parse that layout JSON')));
      }
      return;
    }
    setState(() {
      _root = BranchNode('', children: parsed);
      _path = [_root];
    });
  }

  // ── Grid model ──────────────────────────────────────────────────────────────

  /// Recomputes the grid currently on screen, reusing the keyboard's own
  /// [placeBranch] so the preview is identical to the live keyboard.
  ///
  /// Walks the navigation path: the top level fills cells row-major; each deeper
  /// level fans the entered node's children out from the cell that node occupied
  /// in the level above (found by identity). Returns the cell list and the cell
  /// holding the drilled-into parent (-1 at the top level).
  ({List<BranchNode?> grid, int parentCell}) _computeGrid() {
    var grid = List<BranchNode?>.filled(kKeyboardCellCount, null);
    for (var i = 0; i < _root.children.length && i < kKeyboardCellCount; i++) {
      grid[i] = _root.children[i];
    }
    var parentCell = -1;
    for (var level = 1; level < _path.length; level++) {
      final node = _path[level];
      var cell = grid.indexOf(node);
      if (cell < 0) cell = 0; // defensive; shouldn't happen
      grid =
          placeBranch(parent: node, parentIndex: cell, columns: widget.columns);
      parentCell = cell;
    }
    return (grid: grid, parentCell: parentCell);
  }

  /// Bottom-sheet editor for a single tile: change its glyph, drill into its
  /// branch, or delete it.
  Future<void> _editCell(BranchNode node) async {
    final controller = TextEditingController(text: node.glyph)
      ..selection = TextSelection.collapsed(offset: node.glyph.length);
    final canDrill = !identical(node, _current);
    final childIndex = _current.children.indexOf(node);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit tile',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              onChanged: (v) => setState(() => node.glyph = v),
              decoration: const InputDecoration(
                labelText: 'Glyph',
                helperText: 'Any text — a letter, word, symbol, space or ⏎',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (canDrill)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _enter(node);
                      },
                      icon: const Icon(Icons.account_tree, size: 18),
                      label: Text('Edit branch (${node.children.length})'),
                    ),
                  ),
                if (canDrill && childIndex >= 0) const SizedBox(width: 12),
                if (childIndex >= 0)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _delete(childIndex);
                    },
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done')),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {}); // reflect any glyph edit
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hidden = _current.children.length - _maxVisible;
    return Scaffold(
      appBar: AppBar(
        leading: _atRoot
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _up),
        title: const Text('Edit Layout'),
        actions: [
          IconButton(
            tooltip: _mode == _EditMode.grid
                ? 'Switch to list view'
                : 'Switch to grid view',
            icon: Icon(
                _mode == _EditMode.grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _mode = _mode == _EditMode.grid
                ? _EditMode.list
                : _EditMode.grid),
          ),
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share),
            onPressed: _export,
          ),
          IconButton(
            tooltip: 'Import',
            icon: const Icon(Icons.download),
            onPressed: _import,
          ),
          IconButton(
            tooltip: 'Reset to default',
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetToDefault,
          ),
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black26,
            child: Text(
              _breadcrumb(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (_mode == _EditMode.grid && hidden > 0)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withValues(alpha: 0.25),
              child: Text(
                '$hidden tile${hidden == 1 ? '' : 's'} won\'t fit — a '
                '${_atRoot ? 'level' : 'branch'} shows at most $_maxVisible. '
                'Remove or move some.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: _mode == _EditMode.grid ? _gridBody() : _listBody(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mode == _EditMode.grid ? _addTileAndEdit : _addTile,
        icon: const Icon(Icons.add),
        label: const Text('Add tile'),
      ),
    );
  }

  // ── Grid body ────────────────────────────────────────────────────────────────

  Widget _gridBody() {
    final cols = widget.columns;
    final result = _computeGrid();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: cellAspectRatio(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              columns: cols,
            ),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: kKeyboardCellCount,
          itemBuilder: (context, i) =>
              _gridCell(result.grid[i], i, result.parentCell),
        ),
      ),
    );
  }

  Widget _gridCell(BranchNode? node, int index, int parentCell) {
    if (node == null) {
      // Empty slot — tap to add a tile to the current branch.
      return GestureDetector(
        onTap: _addTileAndEdit,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add, color: Colors.white24),
        ),
      );
    }

    final isParent = index == parentCell;
    if (isParent) {
      // The node we drilled into: shown for context, editable but not deletable
      // here (delete it from the level above).
      return GestureDetector(
        onTap: () => _editCell(node),
        child: _tile(node, isParent: true),
      );
    }

    final childIndex = _current.children.indexOf(node);
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != childIndex,
      onAcceptWithDetails: (d) => _swapChildren(d.data, childIndex),
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return LongPressDraggable<int>(
          data: childIndex,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
                width: 96, height: 72, child: _tile(node, isParent: false)),
          ),
          childWhenDragging:
              Opacity(opacity: 0.3, child: _tile(node, isParent: false)),
          child: GestureDetector(
            onTap: () => _editCell(node),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: highlighted ? Colors.tealAccent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: _tile(node, isParent: false),
            ),
          ),
        );
      },
    );
  }

  /// A single keyboard-style tile, styled to echo the live keyboard.
  Widget _tile(BranchNode node, {required bool isParent}) {
    return Container(
      decoration: BoxDecoration(
        color: isParent
            ? Colors.tealAccent.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isParent ? Colors.tealAccent : Colors.white30,
          width: isParent ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _cellLabel(node.glyph),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isParent ? Colors.tealAccent : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          if (node.children.isNotEmpty)
            Positioned(
              top: 4,
              right: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${node.children.length}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white70)),
              ),
            ),
        ],
      ),
    );
  }

  // ── List body (utilitarian) ──────────────────────────────────────────────────

  Widget _listBody() {
    final children = _current.children;
    if (children.isEmpty) {
      return const Center(
        child: Text('No tiles here yet.\nTap + to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54)),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: children.length,
      onReorder: _reorder,
      itemBuilder: (context, i) => _tileRow(children[i], i),
    );
  }

  Widget _tileRow(BranchNode node, int i) {
    final childCount = node.children.length;
    return Padding(
      key: ValueKey(node),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: i,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_handle, color: Colors.white38),
            ),
          ),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: node.glyph)
                ..selection =
                    TextSelection.collapsed(offset: node.glyph.length),
              onChanged: (v) => node.glyph = v,
              decoration: const InputDecoration(
                labelText: 'Glyph',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _enter(node),
            icon: const Icon(Icons.account_tree, size: 18),
            label: Text('$childCount'),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _delete(i),
          ),
        ],
      ),
    );
  }
}
