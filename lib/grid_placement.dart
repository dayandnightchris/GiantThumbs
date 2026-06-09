import 'key_data.dart';

/// Shared keyboard-grid geometry and child placement.
///
/// Both the live [KeyboardView] and the layout editor's WYSIWYG grid use these
/// functions so the editor preview is guaranteed identical to what the keyboard
/// actually renders — there is exactly one implementation of "where do a
/// branch's children land".

/// Number of cells in the grid at every level. The top-level layout has exactly
/// this many keys (1-9, *, 0, ⌫).
const int kKeyboardCellCount = 12;

/// Rows derived from the column count so the grid always holds exactly
/// [kKeyboardCellCount] cells (2 cols → 6 rows, 3 → 4, 4 → 3).
int rowsForColumns(int columns) => (kKeyboardCellCount / columns).ceil();

/// Cell aspect ratio for a [kKeyboardCellCount] grid that fills [width]×[height]
/// with [columns]. Guards against unbounded or zero constraints (which can
/// occur during a warm-up layout pass) that would otherwise trip the
/// GridView's `childAspectRatio > 0` assertion.
double cellAspectRatio({
  required double width,
  required double height,
  required int columns,
}) {
  if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
    return 1.0;
  }
  final ratio = (width / columns) / (height / rowsForColumns(columns));
  return ratio.isFinite && ratio > 0 ? ratio : 1.0;
}

// The 8 Moore-neighbour directions, clockwise from straight up, as [dRow, dCol].
// Used as the placement order so children fan radially around the parent.
const List<List<int>> _ringDirs = [
  [-1, 0], // up
  [-1, 1], // up-right
  [0, 1], // right
  [1, 1], // down-right
  [1, 0], // down
  [1, -1], // down-left
  [0, -1], // left
  [-1, -1], // up-left
];

/// The cells immediately adjacent to [parentIndex] (its up-to-8 Moore
/// neighbours), ordered clockwise from straight up. These are where a branch's
/// children should sit so each child is exactly one cell from the parent.
List<int> immediateNeighbors(int parentIndex, int columns) {
  final rows = rowsForColumns(columns);
  final pRow = parentIndex ~/ columns, pCol = parentIndex % columns;
  final out = <int>[];
  for (final d in _ringDirs) {
    final r = pRow + d[0], c = pCol + d[1];
    if (r >= 0 && r < rows && c >= 0 && c < columns) {
      final idx = r * columns + c;
      if (idx < kKeyboardCellCount) out.add(idx);
    }
  }
  return out;
}

/// All cells that are neither the parent nor an immediate neighbour, nearest
/// first. Leaf children spill here when the ring is full.
List<int> outwardCells(int parentIndex, int columns) {
  final ring = immediateNeighbors(parentIndex, columns).toSet();
  final pRow = parentIndex ~/ columns, pCol = parentIndex % columns;
  final out = <int>[];
  for (int i = 0; i < kKeyboardCellCount; i++) {
    if (i == parentIndex || ring.contains(i)) continue;
    out.add(i);
  }
  out.sort((a, b) {
    final aRow = a ~/ columns, aCol = a % columns;
    final bRow = b ~/ columns, bCol = b % columns;
    final aDist = (aRow - pRow) * (aRow - pRow) + (aCol - pCol) * (aCol - pCol);
    final bDist = (bRow - pRow) * (bRow - pRow) + (bCol - pCol) * (bCol - pCol);
    final cmp = aDist.compareTo(bDist);
    return cmp != 0 ? cmp : a.compareTo(b);
  });
  return out;
}

/// Builds the length-[kKeyboardCellCount] grid shown when [parent]'s branch is
/// open: [parent] sits at [parentIndex] and its children fan into the cells
/// around it.
///
/// Children that have their own children (sub-branches) are placed first, into
/// the immediate-neighbour ring, so a sub-branch is always exactly one cell from
/// its parent and reachable in a single hop. Leaf children take the remaining
/// ring cells and then spill outward, nearest-first. Children beyond the
/// available cells are not placed.
List<BranchNode?> placeBranch({
  required BranchNode parent,
  required int parentIndex,
  required int columns,
}) {
  final grid = List<BranchNode?>.filled(kKeyboardCellCount, null);
  grid[parentIndex] = parent;

  final ring = immediateNeighbors(parentIndex, columns);
  final outward = outwardCells(parentIndex, columns);
  var ni = 0, oi = 0;
  int? nextCell() {
    if (ni < ring.length) return ring[ni++];
    if (oi < outward.length) return outward[oi++];
    return null;
  }

  // Sub-branches first → guaranteed ring cells (must stay adjacent to parent).
  for (final child in parent.children) {
    if (child.children.isNotEmpty) {
      final cell = nextCell();
      if (cell != null) grid[cell] = child;
    }
  }
  // Leaves fill the remaining ring cells, then spill outward.
  for (final child in parent.children) {
    if (child.children.isEmpty) {
      final cell = nextCell();
      if (cell != null) grid[cell] = child;
    }
  }
  return grid;
}
