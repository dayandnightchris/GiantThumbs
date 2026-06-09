import 'word_predictor.dart';

/// Action glyphs — these are special-cased by the runtime ([_onGlyph] in
/// main.dart) and performed as commands rather than inserted as text.
const String kGlyphBackspace = '⌫';
const String kGlyphMenu = '☰ menu';
const String kGlyphDeleteWord = '⌫ word';
const String kGlyphDeleteAll = '⌫ all';

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

/// The inline punctuation that lives under the Space key's drill-down.
List<BranchNode> _spacePunctuation() => [
      BranchNode("'"), BranchNode('"'), BranchNode('-'),
      BranchNode('—'), BranchNode('…'), BranchNode('('),
      BranchNode(')'), BranchNode('/'),
    ];

/// Backspace's drill-down: tap still deletes; sliding reaches these actions.
List<BranchNode> _backspaceActions() => [
      BranchNode(kGlyphMenu),
      BranchNode(kGlyphDeleteWord),
      BranchNode(kGlyphDeleteAll),
    ];

/// Builds a key tree where every letter node's word-children come from
/// [predictor] rather than being hardcoded.  Each lowercase letter's branch
/// starts with its uppercase twin, then diacritics (for vowels), then word
/// predictions — so a fast 0 ms swipe can still reach the capital.  Falls back
/// to [defaultKeys] if the predictor has not been loaded.
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

  // upper + diacritics + word predictions, capped at [total] children.
  BranchNode letter(String l, {int total = 8}) {
    final upper = l.toUpperCase();
    final diac = _diacritics[l] ?? const [];
    final wordSlots = (total - 1 - diac.length).clamp(0, total);
    final preds = predictor.topWords(l, count: wordSlots);
    return BranchNode(
      l,
      children: [
        BranchNode(upper),
        ...diac.map((d) => BranchNode(d)),
        ...preds.map((w) => BranchNode(w)),
      ],
    );
  }

  return [
    BranchNode('1', children: [letter('a'), letter('b'), letter('c')]),
    BranchNode('2', children: [letter('d'), letter('e'), letter('f')]),
    BranchNode('3', children: [letter('g'), letter('h'), letter('i')]),
    BranchNode('4', children: [letter('j'), letter('k'), letter('l')]),
    BranchNode('5', children: [letter('m'), letter('n'), letter('o')]),
    BranchNode('6',
        children: [letter('p'), letter('q'), letter('r'), letter('s')]),
    BranchNode('7', children: [letter('t'), letter('u'), letter('v')]),
    BranchNode('8',
        children: [letter('w'), letter('x'), letter('y'), letter('z')]),
    // Segments 9 / space / 0 / ⌫ are data-only; reuse from defaultKeys.
    ...defaultKeys().sublist(8),
  ];
}

/// Letters are single lowercase chars; their first children are the uppercase
/// twin and (for vowels) diacritics, the rest are word predictions. We refresh
/// only the word predictions and keep the uppercase + diacritics in place,
/// preserving the user's structure.
void _refreshLetterPredictions(BranchNode node, WordPredictor predictor) {
  final g = node.glyph;
  if (g.length != 1 || !RegExp(r'[a-z]').hasMatch(g)) return;

  final upper = g.toUpperCase();
  final diac = _diacritics[g] ?? const [];
  // Preserve the uppercase twin and any diacritics, in their existing order.
  final kept = node.children
      .where((c) => c.glyph == upper || diac.contains(c.glyph))
      .toList();
  final slots = 8 - kept.length;
  if (slots <= 0) {
    node.children = kept;
    return;
  }
  final preds = predictor.topWords(g, count: slots);
  node.children = [
    ...kept,
    ...preds.map((w) => BranchNode(w)),
  ];
}

/// The built-in default layout. Returns a fresh, mutable tree on every call so
/// callers (especially the editor) can mutate it freely.
///
/// Each lowercase letter's branch leads with its uppercase twin so capitals are
/// reachable by drilling into the letter (rather than as separate tiles).
List<BranchNode> defaultKeys() => [
      BranchNode('1', children: [
        BranchNode('a', children: [
          BranchNode('A'),
          BranchNode('ä'), BranchNode('à'), BranchNode('á'), BranchNode('â'),
          BranchNode('and'), BranchNode('are'), BranchNode('all'),
        ]),
        BranchNode('b', children: [
          BranchNode('B'),
          BranchNode('be'), BranchNode('by'), BranchNode('but'),
          BranchNode('been'), BranchNode('back'),
        ]),
        BranchNode('c', children: [
          BranchNode('C'),
          BranchNode('can'), BranchNode('could'), BranchNode('come'),
          BranchNode('call'), BranchNode('came'),
        ]),
      ]),
      BranchNode('2', children: [
        BranchNode('d', children: [
          BranchNode('D'),
          BranchNode('do'), BranchNode('did'), BranchNode('day'),
          BranchNode('down'), BranchNode("don't"),
        ]),
        BranchNode('e', children: [
          BranchNode('E'),
          BranchNode('é'), BranchNode('è'), BranchNode('ê'), BranchNode('ë'),
          BranchNode('each'), BranchNode('even'), BranchNode('every'),
        ]),
        BranchNode('f', children: [
          BranchNode('F'),
          BranchNode('for'), BranchNode('from'), BranchNode('first'),
          BranchNode('few'), BranchNode('find'),
        ]),
      ]),
      BranchNode('3', children: [
        BranchNode('g', children: [
          BranchNode('G'),
          BranchNode('get'), BranchNode('go'), BranchNode('good'),
          BranchNode('got'), BranchNode('give'),
        ]),
        BranchNode('h', children: [
          BranchNode('H'),
          BranchNode('have'), BranchNode('has'), BranchNode('had'),
          BranchNode('how'), BranchNode('here'), BranchNode('him'),
        ]),
        BranchNode('i', children: [
          BranchNode('I'),
          BranchNode('í'), BranchNode('ì'), BranchNode('î'), BranchNode('ï'),
          BranchNode('in'), BranchNode('is'), BranchNode('it'),
        ]),
      ]),
      BranchNode('4', children: [
        BranchNode('j', children: [
          BranchNode('J'),
          BranchNode('just'), BranchNode('join'),
        ]),
        BranchNode('k', children: [
          BranchNode('K'),
          BranchNode('know'), BranchNode('keep'), BranchNode('key'),
        ]),
        BranchNode('l', children: [
          BranchNode('L'),
          BranchNode('like'), BranchNode('look'), BranchNode('let'),
          BranchNode('long'), BranchNode('last'),
        ]),
      ]),
      BranchNode('5', children: [
        BranchNode('m', children: [
          BranchNode('M'),
          BranchNode('my'), BranchNode('me'), BranchNode('more'),
          BranchNode('make'), BranchNode('most'), BranchNode('many'),
        ]),
        BranchNode('n', children: [
          BranchNode('N'),
          BranchNode('not'), BranchNode('new'), BranchNode('now'),
          BranchNode('no'), BranchNode('need'), BranchNode('next'),
        ]),
        BranchNode('o', children: [
          BranchNode('O'),
          BranchNode('ó'), BranchNode('ò'), BranchNode('ô'), BranchNode('ö'),
          BranchNode('of'), BranchNode('on'), BranchNode('or'),
        ]),
      ]),
      BranchNode('6', children: [
        BranchNode('p', children: [
          BranchNode('P'),
          BranchNode('put'), BranchNode('part'), BranchNode('place'),
          BranchNode('people'), BranchNode('play'),
        ]),
        BranchNode('q', children: [
          BranchNode('Q'),
          BranchNode('quite'), BranchNode('quick'),
        ]),
        BranchNode('r', children: [
          BranchNode('R'),
          BranchNode('right'), BranchNode('really'), BranchNode('run'),
          BranchNode('read'),
        ]),
        BranchNode('s', children: [
          BranchNode('S'),
          BranchNode('so'), BranchNode('some'), BranchNode('say'),
          BranchNode('still'), BranchNode('such'), BranchNode('same'),
        ]),
      ]),
      BranchNode('7', children: [
        BranchNode('t', children: [
          BranchNode('T'),
          BranchNode('to'), BranchNode('the'), BranchNode('this'),
          BranchNode('that'), BranchNode('they'), BranchNode('there'),
        ]),
        BranchNode('u', children: [
          BranchNode('U'),
          BranchNode('ú'), BranchNode('ù'), BranchNode('û'), BranchNode('ü'),
          BranchNode('up'), BranchNode('us'), BranchNode('use'),
        ]),
        BranchNode('v', children: [
          BranchNode('V'),
          BranchNode('very'), BranchNode('value'), BranchNode('view'),
        ]),
      ]),
      BranchNode('8', children: [
        BranchNode('w', children: [
          BranchNode('W'),
          BranchNode('with'), BranchNode('what'), BranchNode('when'),
          BranchNode('were'), BranchNode('would'), BranchNode('will'),
        ]),
        BranchNode('x', children: [
          BranchNode('X'),
        ]),
        BranchNode('y', children: [
          BranchNode('Y'),
          BranchNode('you'), BranchNode('your'), BranchNode('yes'),
          BranchNode('yet'),
        ]),
        BranchNode('z', children: [
          BranchNode('Z'),
        ]),
      ]),
      // Segment 9: sentence-ending punctuation.
      BranchNode('9', children: [
        BranchNode('.'), BranchNode(','), BranchNode('?'),
        BranchNode('!'), BranchNode(';'), BranchNode(':'),
      ]),
      // Space (replaces the old *): tap inserts a space; its drill-down holds
      // the inline punctuation.
      BranchNode(' ', children: _spacePunctuation()),
      // Utility (0): space, newline, delete, symbols.
      BranchNode('0', children: [
        BranchNode(' '), BranchNode('\n'), BranchNode(kGlyphBackspace),
        BranchNode('('), BranchNode(')'), BranchNode('@'),
        BranchNode(r'$'), BranchNode('&'),
      ]),
      // Backspace: tap = delete; drill-down holds the menu and power-deletes.
      BranchNode(kGlyphBackspace, children: _backspaceActions()),
    ];
