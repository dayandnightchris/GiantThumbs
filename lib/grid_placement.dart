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

/// The ordered list of candidate cell indices a branch's children fill when the
/// user opens the branch of the key at [parentIndex], for the given [columns].
/// The parent's own cell is excluded. Order matches the keyboard exactly:
/// `children[i]` is placed in `result[i]`.
///
/// Corner parents radiate along three lines (a horizontal spoke, the corner
/// diagonal, and a vertical spoke); edge/center parents radiate along cardinal
/// spokes longest-first; any cells still unplaced follow nearest-first. This
/// keeps a parent's children spatially adjacent so muscle memory forms.
List<int> branchCandidateCells({
  required int parentIndex,
  required int columns,
}) {
  final cols = columns;
  final rows = rowsForColumns(columns);
  final pRow = parentIndex ~/ cols;
  final pCol = parentIndex % cols;

  // Build a line of cells radiating from the parent in a given direction.
  List<int> line(int dRow, int dCol) {
    final cells = <int>[];
    int r = pRow + dRow, c = pCol + dCol;
    while (r >= 0 && r < rows && c >= 0 && c < cols) {
      final idx = r * cols + c;
      if (idx < kKeyboardCellCount) cells.add(idx);
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
    final dRow = pRow == 0 ? 1 : -1;
    final dCol = pCol == 0 ? 1 : -1;
    addCells(line(0, dCol)); // horizontal
    addCells(line(dRow, dCol)); // corner diagonal
    addCells(line(dRow, 0)); // vertical
  } else {
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
  for (int i = 0; i < kKeyboardCellCount; i++) {
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
  return candidates;
}

/// Builds the length-[kKeyboardCellCount] grid shown when [parent]'s branch is
/// open: [parent] sits at [parentIndex] and its children fan out into the
/// candidate cells. Cells with no content are null. Children beyond the
/// available candidate cells are not placed — a branch can show at most
/// [kKeyboardCellCount] − 1 children.
List<BranchNode?> placeBranch({
  required BranchNode parent,
  required int parentIndex,
  required int columns,
}) {
  final grid = List<BranchNode?>.filled(kKeyboardCellCount, null);
  grid[parentIndex] = parent;
  final candidates =
      branchCandidateCells(parentIndex: parentIndex, columns: columns);
  final limit = candidates.length < parent.children.length
      ? candidates.length
      : parent.children.length;
  for (int i = 0; i < limit; i++) {
    grid[candidates[i]] = parent.children[i];
  }
  return grid;
}
