import 'word_predictor.dart';

class BranchNode {
  final String glyph;
  final List<BranchNode> children;

  const BranchNode(this.glyph, {this.children = const []});
}

// ── Diacritics table used by both defaultKeys and buildKeys ─────────────────
const Map<String, List<String>> _diacritics = {
  'a': ['ä', 'à', 'á', 'â'],
  'e': ['é', 'è', 'ê', 'ë'],
  'i': ['í', 'ì', 'î', 'ï'],
  'o': ['ó', 'ò', 'ô', 'ö'],
  'u': ['ú', 'ù', 'û', 'ü'],
};

/// Builds a key tree where every letter node's word-children come from
/// [predictor] rather than being hardcoded.  Diacritics are preserved for
/// vowels.  Falls back to [defaultKeys] if the predictor has not been loaded.
List<BranchNode> buildKeys(WordPredictor predictor) {
  if (!predictor.isLoaded) return defaultKeys;

  BranchNode letter(String l, {int words = 6}) {
    final diac = _diacritics[l] ?? [];
    final wordCount = diac.isEmpty ? words : words - diac.length.clamp(0, words);
    final preds = predictor.topWords(l, count: wordCount.clamp(0, words));
    return BranchNode(
      l,
      children: [
        ...diac.map((d) => BranchNode(d)),
        ...preds.map((w) => BranchNode(w)),
      ],
    );
  }

  return [
    // ── Segment 1: a b c ────────────────────────────────────────────────────
    BranchNode('1', children: [
      letter('a', words: 8), BranchNode('A'),
      letter('b'), BranchNode('B'),
      letter('c'), BranchNode('C'),
    ]),
    // ── Segment 2: d e f ────────────────────────────────────────────────────
    BranchNode('2', children: [
      letter('d'), BranchNode('D'),
      letter('e', words: 8), BranchNode('E'),
      letter('f'), BranchNode('F'),
    ]),
    // ── Segment 3: g h i ────────────────────────────────────────────────────
    BranchNode('3', children: [
      letter('g'), BranchNode('G'),
      letter('h'), BranchNode('H'),
      letter('i', words: 8), BranchNode('I'),
    ]),
    // ── Segment 4: j k l ────────────────────────────────────────────────────
    BranchNode('4', children: [
      letter('j'), BranchNode('J'),
      letter('k'), BranchNode('K'),
      letter('l'), BranchNode('L'),
    ]),
    // ── Segment 5: m n o ────────────────────────────────────────────────────
    BranchNode('5', children: [
      letter('m'), BranchNode('M'),
      letter('n'), BranchNode('N'),
      letter('o', words: 8), BranchNode('O'),
    ]),
    // ── Segment 6: p q r s ──────────────────────────────────────────────────
    BranchNode('6', children: [
      letter('p'), BranchNode('P'),
      letter('q'), BranchNode('Q'),
      letter('r'), BranchNode('R'),
      letter('s'), BranchNode('S'),
    ]),
    // ── Segment 7: t u v ────────────────────────────────────────────────────
    BranchNode('7', children: [
      letter('t'), BranchNode('T'),
      letter('u', words: 8), BranchNode('U'),
      letter('v'), BranchNode('V'),
    ]),
    // ── Segment 8: w x y z ──────────────────────────────────────────────────
    BranchNode('8', children: [
      letter('w'), BranchNode('W'),
      letter('x'), BranchNode('X'),
      letter('y'), BranchNode('Y'),
      letter('z'), BranchNode('Z'),
    ]),
    // ── Segments 9 / * / 0 / # are data-only; reuse from defaultKeys ────────
    ...defaultKeys.sublist(8),
  ];
}

const List<BranchNode> defaultKeys = [
  // ── Segment 1: a b c ──────────────────────────────────────────────────────
  BranchNode('1', children: [
    BranchNode('a', children: [
      BranchNode('ä'), BranchNode('à'), BranchNode('á'), BranchNode('â'),
      BranchNode('and'), BranchNode('are'), BranchNode('all'), BranchNode('about'),
    ]),
    BranchNode('A'),
    BranchNode('b', children: [
      BranchNode('be'), BranchNode('by'), BranchNode('but'), BranchNode('been'), BranchNode('back'),
    ]),
    BranchNode('B'),
    BranchNode('c', children: [
      BranchNode('can'), BranchNode('could'), BranchNode('come'), BranchNode('call'), BranchNode('came'),
    ]),
    BranchNode('C'),
  ]),
  // ── Segment 2: d e f ──────────────────────────────────────────────────────
  BranchNode('2', children: [
    BranchNode('d', children: [
      BranchNode('do'), BranchNode('did'), BranchNode('day'), BranchNode('down'), BranchNode("don't"),
    ]),
    BranchNode('D'),
    BranchNode('e', children: [
      BranchNode('é'), BranchNode('è'), BranchNode('ê'), BranchNode('ë'),
      BranchNode('each'), BranchNode('even'), BranchNode('every'), BranchNode('else'),
    ]),
    BranchNode('E'),
    BranchNode('f', children: [
      BranchNode('for'), BranchNode('from'), BranchNode('first'), BranchNode('few'), BranchNode('find'),
    ]),
    BranchNode('F'),
  ]),
  // ── Segment 3: g h i ──────────────────────────────────────────────────────
  BranchNode('3', children: [
    BranchNode('g', children: [
      BranchNode('get'), BranchNode('go'), BranchNode('good'), BranchNode('got'), BranchNode('give'),
    ]),
    BranchNode('G'),
    BranchNode('h', children: [
      BranchNode('have'), BranchNode('has'), BranchNode('had'), BranchNode('how'), BranchNode('here'), BranchNode('him'),
    ]),
    BranchNode('H'),
    BranchNode('i', children: [
      BranchNode('í'), BranchNode('ì'), BranchNode('î'), BranchNode('ï'),
      BranchNode('in'), BranchNode('is'), BranchNode('it'), BranchNode('if'),
    ]),
    BranchNode('I'),
  ]),
  // ── Segment 4: j k l ──────────────────────────────────────────────────────
  BranchNode('4', children: [
    BranchNode('j', children: [
      BranchNode('just'), BranchNode('join'),
    ]),
    BranchNode('J'),
    BranchNode('k', children: [
      BranchNode('know'), BranchNode('keep'), BranchNode('key'),
    ]),
    BranchNode('K'),
    BranchNode('l', children: [
      BranchNode('like'), BranchNode('look'), BranchNode('let'), BranchNode('long'), BranchNode('last'),
    ]),
    BranchNode('L'),
  ]),
  // ── Segment 5: m n o ──────────────────────────────────────────────────────
  BranchNode('5', children: [
    BranchNode('m', children: [
      BranchNode('my'), BranchNode('me'), BranchNode('more'), BranchNode('make'), BranchNode('most'), BranchNode('many'),
    ]),
    BranchNode('M'),
    BranchNode('n', children: [
      BranchNode('not'), BranchNode('new'), BranchNode('now'), BranchNode('no'), BranchNode('need'), BranchNode('next'),
    ]),
    BranchNode('N'),
    BranchNode('o', children: [
      BranchNode('ó'), BranchNode('ò'), BranchNode('ô'), BranchNode('ö'),
      BranchNode('of'), BranchNode('on'), BranchNode('or'), BranchNode('out'),
    ]),
    BranchNode('O'),
  ]),
  // ── Segment 6: p q r s ────────────────────────────────────────────────────
  BranchNode('6', children: [
    BranchNode('p', children: [
      BranchNode('put'), BranchNode('part'), BranchNode('place'), BranchNode('people'), BranchNode('play'),
    ]),
    BranchNode('P'),
    BranchNode('q', children: [
      BranchNode('quite'), BranchNode('quick'),
    ]),
    BranchNode('Q'),
    BranchNode('r', children: [
      BranchNode('right'), BranchNode('really'), BranchNode('run'), BranchNode('read'),
    ]),
    BranchNode('R'),
    BranchNode('s', children: [
      BranchNode('so'), BranchNode('some'), BranchNode('say'), BranchNode('still'), BranchNode('such'), BranchNode('same'),
    ]),
    BranchNode('S'),
  ]),
  // ── Segment 7: t u v ──────────────────────────────────────────────────────
  BranchNode('7', children: [
    BranchNode('t', children: [
      BranchNode('to'), BranchNode('the'), BranchNode('this'), BranchNode('that'), BranchNode('they'), BranchNode('there'),
    ]),
    BranchNode('T'),
    BranchNode('u', children: [
      BranchNode('ú'), BranchNode('ù'), BranchNode('û'), BranchNode('ü'),
      BranchNode('up'), BranchNode('us'), BranchNode('use'), BranchNode('under'),
    ]),
    BranchNode('U'),
    BranchNode('v', children: [
      BranchNode('very'), BranchNode('value'), BranchNode('view'),
    ]),
    BranchNode('V'),
  ]),
  // ── Segment 8: w x y z ────────────────────────────────────────────────────
  BranchNode('8', children: [
    BranchNode('w', children: [
      BranchNode('with'), BranchNode('what'), BranchNode('when'), BranchNode('were'), BranchNode('would'), BranchNode('will'),
    ]),
    BranchNode('W'),
    BranchNode('x', children: []),
    BranchNode('X'),
    BranchNode('y', children: [
      BranchNode('you'), BranchNode('your'), BranchNode('yes'), BranchNode('yet'),
    ]),
    BranchNode('Y'),
    BranchNode('z', children: []),
    BranchNode('Z'),
  ]),
  // ── Segment 9: sentence-ending punctuation ────────────────────────────────
  BranchNode('9', children: [
    BranchNode('.'), BranchNode(','), BranchNode('?'),
    BranchNode('!'), BranchNode(';'), BranchNode(':'),
  ]),
  // ── Grammar (*): structural / inline punctuation ──────────────────────────
  BranchNode('*', children: [
    BranchNode("'"), BranchNode('"'), BranchNode('-'),
    BranchNode('—'), BranchNode('…'), BranchNode('('),
    BranchNode(')'), BranchNode('/'),
  ]),
  // ── Utility (0): space, newline, delete, symbols ──────────────────────────
  BranchNode('0', children: [
    BranchNode(' '), BranchNode('\n'), BranchNode('⌫'),
    BranchNode('('), BranchNode(')'), BranchNode('@'),
    BranchNode(r'$'), BranchNode('&'),
  ]),
  // ── Settings (⌫): tap = ⌫, hold = settings ─────────────────────────────
  BranchNode('⌫', children: []),
];
