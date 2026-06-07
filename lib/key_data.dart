import 'word_predictor.dart';

/// A node in the keyboard's branch tree.
///
/// Mutable by design so the layout editor can edit glyphs and add/remove/reorder
/// children in place. The runtime keyboard treats trees as read-only and never
/// mutates them; it rebuilds from [buildKeys] or a persisted layout instead.
class BranchNode {
  String glyph;
  List<BranchNode> children;

  BranchNode(this.glyph, {List<BranchNode>? children})
      : children = children ?? <BranchNode>[];

  /// Deep copy — used by the editor so edits don't touch the live tree until saved.
  BranchNode copy() =>
      BranchNode(glyph, children: children.map((c) => c.copy()).toList());

  /// Compact JSON: `g` = glyph, `c` = children (omitted when empty).
  Map<String, dynamic> toJson() => {
        'g': glyph,
        if (children.isNotEmpty) 'c': children.map((c) => c.toJson()).toList(),
      };

  factory BranchNode.fromJson(Map<String, dynamic> json) => BranchNode(
        json['g'] as String,
        children: (json['c'] as List?)
            ?.map((e) => BranchNode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
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
///
/// When [base] is supplied (a user's custom layout), only the dynamic word
/// children are refreshed — the user's chosen glyphs and structure are kept.
List<BranchNode> buildKeys(WordPredictor predictor, {List<BranchNode>? base}) {
  if (!predictor.isLoaded) return base ?? defaultKeys();

  // If the user has a custom layout, refresh predictions in place rather than
  // discarding their tile choices.
  if (base != null) {
    final tree = base.map((n) => n.copy()).toList();
    for (final segment in tree) {
      for (final node in segment.children) {
        _refreshLetterPredictions(node, predictor);
      }
    }
    return tree;
  }

  BranchNode letter(String l, {int words = 6}) {
    final diac = _diacritics[l] ?? const [];
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
    BranchNode('1', children: [
      letter('a', words: 8), BranchNode('A'),
      letter('b'), BranchNode('B'),
      letter('c'), BranchNode('C'),
    ]),
    BranchNode('2', children: [
      letter('d'), BranchNode('D'),
      letter('e', words: 8), BranchNode('E'),
      letter('f'), BranchNode('F'),
    ]),
    BranchNode('3', children: [
      letter('g'), BranchNode('G'),
      letter('h'), BranchNode('H'),
      letter('i', words: 8), BranchNode('I'),
    ]),
    BranchNode('4', children: [
      letter('j'), BranchNode('J'),
      letter('k'), BranchNode('K'),
      letter('l'), BranchNode('L'),
    ]),
    BranchNode('5', children: [
      letter('m'), BranchNode('M'),
      letter('n'), BranchNode('N'),
      letter('o', words: 8), BranchNode('O'),
    ]),
    BranchNode('6', children: [
      letter('p'), BranchNode('P'),
      letter('q'), BranchNode('Q'),
      letter('r'), BranchNode('R'),
      letter('s'), BranchNode('S'),
    ]),
    BranchNode('7', children: [
      letter('t'), BranchNode('T'),
      letter('u', words: 8), BranchNode('U'),
      letter('v'), BranchNode('V'),
    ]),
    BranchNode('8', children: [
      letter('w'), BranchNode('W'),
      letter('x'), BranchNode('X'),
      letter('y'), BranchNode('Y'),
      letter('z'), BranchNode('Z'),
    ]),
    // Segments 9 / * / 0 / ⌫ are data-only; reuse from defaultKeys.
    ...defaultKeys().sublist(8),
  ];
}

/// Letters are single lowercase chars; their first children may be diacritics,
/// the rest are word predictions. We refresh only the word predictions and keep
/// any diacritics the user kept, preserving the user's structure.
void _refreshLetterPredictions(BranchNode node, WordPredictor predictor) {
  final g = node.glyph;
  if (g.length != 1 || !RegExp(r'[a-z]').hasMatch(g)) return;

  final diac = _diacritics[g] ?? const [];
  final keptDiacritics =
      node.children.where((c) => diac.contains(c.glyph)).toList();
  final slots = 6 - keptDiacritics.length;
  if (slots <= 0) return;
  final preds = predictor.topWords(g, count: slots);
  node.children = [
    ...keptDiacritics,
    ...preds.map((w) => BranchNode(w)),
  ];
}

/// The built-in default layout. Returns a fresh, mutable tree on every call so
/// callers (especially the editor) can mutate it freely.
List<BranchNode> defaultKeys() => [
      BranchNode('1', children: [
        BranchNode('a', children: [
          BranchNode('ä'), BranchNode('à'), BranchNode('á'), BranchNode('â'),
          BranchNode('and'), BranchNode('are'), BranchNode('all'),
          BranchNode('about'),
        ]),
        BranchNode('A'),
        BranchNode('b', children: [
          BranchNode('be'), BranchNode('by'), BranchNode('but'),
          BranchNode('been'), BranchNode('back'),
        ]),
        BranchNode('B'),
        BranchNode('c', children: [
          BranchNode('can'), BranchNode('could'), BranchNode('come'),
          BranchNode('call'), BranchNode('came'),
        ]),
        BranchNode('C'),
      ]),
      BranchNode('2', children: [
        BranchNode('d', children: [
          BranchNode('do'), BranchNode('did'), BranchNode('day'),
          BranchNode('down'), BranchNode("don't"),
        ]),
        BranchNode('D'),
        BranchNode('e', children: [
          BranchNode('é'), BranchNode('è'), BranchNode('ê'), BranchNode('ë'),
          BranchNode('each'), BranchNode('even'), BranchNode('every'),
          BranchNode('else'),
        ]),
        BranchNode('E'),
        BranchNode('f', children: [
          BranchNode('for'), BranchNode('from'), BranchNode('first'),
          BranchNode('few'), BranchNode('find'),
        ]),
        BranchNode('F'),
      ]),
      BranchNode('3', children: [
        BranchNode('g', children: [
          BranchNode('get'), BranchNode('go'), BranchNode('good'),
          BranchNode('got'), BranchNode('give'),
        ]),
        BranchNode('G'),
        BranchNode('h', children: [
          BranchNode('have'), BranchNode('has'), BranchNode('had'),
          BranchNode('how'), BranchNode('here'), BranchNode('him'),
        ]),
        BranchNode('H'),
        BranchNode('i', children: [
          BranchNode('í'), BranchNode('ì'), BranchNode('î'), BranchNode('ï'),
          BranchNode('in'), BranchNode('is'), BranchNode('it'), BranchNode('if'),
        ]),
        BranchNode('I'),
      ]),
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
          BranchNode('like'), BranchNode('look'), BranchNode('let'),
          BranchNode('long'), BranchNode('last'),
        ]),
        BranchNode('L'),
      ]),
      BranchNode('5', children: [
        BranchNode('m', children: [
          BranchNode('my'), BranchNode('me'), BranchNode('more'),
          BranchNode('make'), BranchNode('most'), BranchNode('many'),
        ]),
        BranchNode('M'),
        BranchNode('n', children: [
          BranchNode('not'), BranchNode('new'), BranchNode('now'),
          BranchNode('no'), BranchNode('need'), BranchNode('next'),
        ]),
        BranchNode('N'),
        BranchNode('o', children: [
          BranchNode('ó'), BranchNode('ò'), BranchNode('ô'), BranchNode('ö'),
          BranchNode('of'), BranchNode('on'), BranchNode('or'), BranchNode('out'),
        ]),
        BranchNode('O'),
      ]),
      BranchNode('6', children: [
        BranchNode('p', children: [
          BranchNode('put'), BranchNode('part'), BranchNode('place'),
          BranchNode('people'), BranchNode('play'),
        ]),
        BranchNode('P'),
        BranchNode('q', children: [
          BranchNode('quite'), BranchNode('quick'),
        ]),
        BranchNode('Q'),
        BranchNode('r', children: [
          BranchNode('right'), BranchNode('really'), BranchNode('run'),
          BranchNode('read'),
        ]),
        BranchNode('R'),
        BranchNode('s', children: [
          BranchNode('so'), BranchNode('some'), BranchNode('say'),
          BranchNode('still'), BranchNode('such'), BranchNode('same'),
        ]),
        BranchNode('S'),
      ]),
      BranchNode('7', children: [
        BranchNode('t', children: [
          BranchNode('to'), BranchNode('the'), BranchNode('this'),
          BranchNode('that'), BranchNode('they'), BranchNode('there'),
        ]),
        BranchNode('T'),
        BranchNode('u', children: [
          BranchNode('ú'), BranchNode('ù'), BranchNode('û'), BranchNode('ü'),
          BranchNode('up'), BranchNode('us'), BranchNode('use'),
          BranchNode('under'),
        ]),
        BranchNode('U'),
        BranchNode('v', children: [
          BranchNode('very'), BranchNode('value'), BranchNode('view'),
        ]),
        BranchNode('V'),
      ]),
      BranchNode('8', children: [
        BranchNode('w', children: [
          BranchNode('with'), BranchNode('what'), BranchNode('when'),
          BranchNode('were'), BranchNode('would'), BranchNode('will'),
        ]),
        BranchNode('W'),
        BranchNode('x', children: []),
        BranchNode('X'),
        BranchNode('y', children: [
          BranchNode('you'), BranchNode('your'), BranchNode('yes'),
          BranchNode('yet'),
        ]),
        BranchNode('Y'),
        BranchNode('z', children: []),
        BranchNode('Z'),
      ]),
      // Segment 9: sentence-ending punctuation.
      BranchNode('9', children: [
        BranchNode('.'), BranchNode(','), BranchNode('?'),
        BranchNode('!'), BranchNode(';'), BranchNode(':'),
      ]),
      // Grammar (*): structural / inline punctuation.
      BranchNode('*', children: [
        BranchNode("'"), BranchNode('"'), BranchNode('-'),
        BranchNode('—'), BranchNode('…'), BranchNode('('),
        BranchNode(')'), BranchNode('/'),
      ]),
      // Utility (0): space, newline, delete, symbols.
      BranchNode('0', children: [
        BranchNode(' '), BranchNode('\n'), BranchNode('⌫'),
        BranchNode('('), BranchNode(')'), BranchNode('@'),
        BranchNode(r'$'), BranchNode('&'),
      ]),
      // Settings (⌫): tap = ⌫, hold = settings.
      BranchNode('⌫', children: []),
    ];
