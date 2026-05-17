import 'package:flutter/services.dart';

/// Loads a frequency-ordered word list and an optional bigram table from
/// bundled assets and provides context-aware first-letter word prediction.
///
/// Prediction strategy (same as standard Android keyboards):
///   1. If a previous word is known AND bigrams exist for it, bigram-matched
///      words that start with the requested letter are promoted to the front.
///   2. Remaining slots are filled in corpus-frequency order.
///
/// Replace `assets/wordlist_en.txt` with a fuller list (e.g. the top 10 k
/// entries from Peter Norvig's count_1w.txt) to improve coverage.
/// Add entries to `assets/bigrams_en.txt` to improve context accuracy.
class WordPredictor {
  final Map<String, List<String>> _byFirstLetter = {};
  // bigrams[word1] = ordered list of words that commonly follow word1
  final Map<String, List<String>> _bigrams = {};

  String? _lastWord;

  bool get isLoaded => _byFirstLetter.isNotEmpty;

  /// Load the unigram word list and bigram table from [bundle].
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<void> load(AssetBundle bundle) async {
    if (isLoaded) return;
    await _loadUnigrams(bundle);
    await _loadBigrams(bundle);
  }

  Future<void> _loadUnigrams(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/wordlist_en.txt');
    for (final line in raw.split('\n')) {
      final word = line.trim();
      if (word.isEmpty || word.startsWith('#')) continue;
      if (word.length < 2) continue;
      final key = word[0].toLowerCase();
      (_byFirstLetter[key] ??= []).add(word);
    }
  }

  Future<void> _loadBigrams(AssetBundle bundle) async {
    try {
      final raw = await bundle.loadString('assets/bigrams_en.txt');
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final tab = trimmed.indexOf('\t');
        if (tab < 0) continue;
        final word1 = trimmed.substring(0, tab).trim().toLowerCase();
        final followers = trimmed
            .substring(tab + 1)
            .split(',')
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty)
            .toList();
        _bigrams[word1] = followers;
      }
    } catch (_) {
      // Bigram file is optional; unigram-only prediction still works.
    }
  }

  // ── Context API ─────────────────────────────────────────────────────────────

  /// Call this after each committed word so the next [topWords] call
  /// can promote likely followers.
  void updateContext(String word) {
    _lastWord = word.trim().toLowerCase();
  }

  /// Reset context (e.g. after a sentence-ending punctuation mark).
  void clearContext() => _lastWord = null;

  // ── Prediction API ───────────────────────────────────────────────────────────

  /// Returns up to [count] predicted words whose first letter equals [letter].
  ///
  /// When a [_lastWord] context is set and bigram data is available for it,
  /// bigram-matched candidates are promoted to the front of the list (same
  /// behaviour as standard Android swipe-keyboard suggestions).
  List<String> topWords(String letter, {int count = 6}) {
    final lower = letter.toLowerCase();
    final base = _byFirstLetter[lower] ?? [];

    final followers = _lastWord != null ? (_bigrams[_lastWord!] ?? []) : <String>[];

    if (followers.isEmpty) {
      return base.take(count).toList();
    }

    // Promoted: bigram followers that start with the requested letter
    final promoted = followers
        .where((w) => w.isNotEmpty && w[0].toLowerCase() == lower)
        .toList();

    // Remaining: frequency-ordered base list excluding already-promoted entries
    final promotedSet = promoted.toSet();
    final remaining = base.where((w) => !promotedSet.contains(w));

    return [...promoted, ...remaining].take(count).toList();
  }
}
