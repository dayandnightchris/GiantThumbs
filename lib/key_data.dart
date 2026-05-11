/// Defines a single branch node in the hold-and-swipe tree.
class BranchNode {
  final String glyph;
  final List<BranchNode> children;

  const BranchNode(this.glyph, {this.children = const []});
}

/// The 4×3 default layout: 12 keys, row-major.
/// Row 0: 1 2 3
/// Row 1: 4 5 6
/// Row 2: 7 8 9
/// Row 3: * 0 #
const List<BranchNode> defaultKeys = [
  BranchNode('1', children: [
    BranchNode('!'), BranchNode('¹'), BranchNode('①'),
  ]),
  BranchNode('2', children: [
    BranchNode('²'), BranchNode('@'), BranchNode('②'),
  ]),
  BranchNode('3', children: [
    BranchNode('³'), BranchNode('#'), BranchNode('③'),
  ]),
  BranchNode('4', children: [
    BranchNode(r'$'), BranchNode('€'), BranchNode('£'),
  ]),
  BranchNode('5', children: [
    BranchNode('%'), BranchNode('‰'), BranchNode('½'),
  ]),
  BranchNode('6', children: [
    BranchNode('^'), BranchNode('&'), BranchNode('*'),
  ]),
  BranchNode('7', children: [
    BranchNode('('), BranchNode('['), BranchNode('{'),
  ]),
  BranchNode('8', children: [
    BranchNode(')'), BranchNode(']'), BranchNode('}'),
  ]),
  BranchNode('9', children: [
    BranchNode('+'), BranchNode('='), BranchNode('~'),
  ]),
  BranchNode('*', children: [   // grammar / punctuation
    BranchNode('.'), BranchNode(','), BranchNode('?'),
    BranchNode('!'), BranchNode(';'), BranchNode(':'),
  ]),
  BranchNode('0', children: [
    BranchNode('-'), BranchNode('_'), BranchNode('/'),
  ]),
  BranchNode('#', children: []), // opens settings — handled in keyboard_view
];
