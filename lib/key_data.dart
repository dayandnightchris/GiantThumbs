class BranchNode {
  final String glyph;
  final List<BranchNode> children;

  const BranchNode(this.glyph, {this.children = const []});
}

const List<BranchNode> defaultKeys = [
  BranchNode('1', children: [
    BranchNode('a', children: [
      BranchNode('ä'), BranchNode('ā'), BranchNode('á'),
      BranchNode('and'), BranchNode('🙂'), BranchNode('say'),
      BranchNode('andor'),
    ]),
    BranchNode('A'),
    BranchNode('b'), BranchNode('B'),
    BranchNode('c'), BranchNode('C'),
  ]),
  BranchNode('2', children: [
    BranchNode('d'), BranchNode('D'),
    BranchNode('e'), BranchNode('E'),
    BranchNode('f'), BranchNode('F'),
  ]),
  BranchNode('3', children: [
    BranchNode('g'), BranchNode('G'),
    BranchNode('h'), BranchNode('H'),
    BranchNode('i'), BranchNode('I'),
  ]),
  BranchNode('4', children: [
    BranchNode('j'), BranchNode('J'),
    BranchNode('k'), BranchNode('K'),
    BranchNode('l'), BranchNode('L'),
  ]),
  BranchNode('5', children: [
    BranchNode('m'), BranchNode('M'),
    BranchNode('n'), BranchNode('N'),
    BranchNode('o'), BranchNode('O'),
  ]),
  BranchNode('6', children: [
    BranchNode('p'), BranchNode('P'),
    BranchNode('q'), BranchNode('Q'),
    BranchNode('r'), BranchNode('R'),
    BranchNode('s'), BranchNode('S'),
  ]),
  BranchNode('7', children: [
    BranchNode('t'), BranchNode('T'),
    BranchNode('u'), BranchNode('U'),
    BranchNode('v'), BranchNode('V'),
  ]),
  BranchNode('8', children: [
    BranchNode('w'), BranchNode('W'),
    BranchNode('x'), BranchNode('X'),
    BranchNode('y'), BranchNode('Y'),
    BranchNode('z'), BranchNode('Z'),
  ]),
  BranchNode('9', children: [
    BranchNode('.'), BranchNode(','), BranchNode('?'),
    BranchNode('!'), BranchNode(';'), BranchNode(':'),
    BranchNode('"'), BranchNode("'"),
  ]),
  BranchNode('*', children: [
    BranchNode('+'), BranchNode('-'), BranchNode('='),
    BranchNode('/'), BranchNode('\\'), BranchNode('%'),
    BranchNode('<'), BranchNode('>'),
  ]),
  BranchNode('0', children: [
    BranchNode('⌫'), BranchNode(' '), BranchNode('\n'),
    BranchNode('('), BranchNode(')'), BranchNode('@'),
    BranchNode(r'$'), BranchNode('&'),
  ]),
  BranchNode('#', children: []),
];
