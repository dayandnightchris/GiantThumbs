import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'key_data.dart';
import 'layout_store.dart';

/// Full layout editor. Lets the user choose exactly what glyph sits in every
/// tile and branch, add/remove/reorder tiles, and drill into any tile's
/// children to edit the branch tree to any depth.
///
/// Edits a working copy and only persists when the user taps Save, so backing
/// out discards changes.
class LayoutEditorScreen extends StatefulWidget {
  final List<BranchNode> initial;
  final ValueChanged<List<BranchNode>> onSaved;

  const LayoutEditorScreen({
    super.key,
    required this.initial,
    required this.onSaved,
  });

  @override
  State<LayoutEditorScreen> createState() => _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends State<LayoutEditorScreen> {
  /// Virtual root whose children are the 12 top-level tiles.
  late BranchNode _root;

  /// Navigation stack into the tree; the last entry is the node being edited.
  late List<BranchNode> _path;

  @override
  void initState() {
    super.initState();
    _root = BranchNode('', children: widget.initial.map((n) => n.copy()).toList());
    _path = [_root];
  }

  BranchNode get _current => _path.last;
  bool get _atRoot => _path.length == 1;

  String _breadcrumb() {
    if (_atRoot) return 'All tiles';
    return _path.skip(1).map((n) => _label(n.glyph)).join('  ›  ');
  }

  /// Human-readable label for control glyphs.
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

  void _enter(BranchNode node) => setState(() => _path.add(node));

  void _up() {
    if (!_atRoot) setState(() => _path.removeLast());
  }

  void _addTile() {
    setState(() => _current.children.add(BranchNode('')));
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

  @override
  Widget build(BuildContext context) {
    final children = _current.children;
    return Scaffold(
      appBar: AppBar(
        leading: _atRoot
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _up),
        title: const Text('Edit Layout'),
        actions: [
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
          if (children.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No tiles here yet.\nTap + to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: children.length,
                onReorder: _reorder,
                itemBuilder: (context, i) => _tileRow(children[i], i),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTile,
        icon: const Icon(Icons.add),
        label: const Text('Add tile'),
      ),
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
