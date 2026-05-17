import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ime_channel.dart';
import 'key_data.dart';
import 'keyboard_view.dart';
import 'settings_screen.dart';
import 'word_predictor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GiantThumbsApp());
}

class GiantThumbsApp extends StatelessWidget {
  const GiantThumbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giant Thumbs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const KeyboardDemoPage(),
    );
  }
}

/// Demo shell that shows the keyboard overlaid on a fake chat background.
/// In production this widget tree would be replaced by the IME service host.
class KeyboardDemoPage extends StatefulWidget {
  const KeyboardDemoPage({super.key});

  @override
  State<KeyboardDemoPage> createState() => _KeyboardDemoPageState();
}

class _KeyboardDemoPageState extends State<KeyboardDemoPage> {
  final List<String> _output = [];
  int _columns = 3;
  double _opacity = 0.40;
  List<BranchNode> _keys = defaultKeys;
  final WordPredictor _predictor = WordPredictor();
  // Accumulates individual letter commits so we know when a word ends.
  String _currentWord = '';

  @override
  void initState() {
    super.initState();
    ImeChannel.init(_openSettings);
    _loadWordPredictor();
  }

  Future<void> _loadWordPredictor() async {
    await _predictor.load(rootBundle);
    if (mounted) {
      setState(() => _keys = buildKeys(_predictor));
    }
  }

  void _onGlyph(String g) {
    if (g == '\u232b') {
      _onDelete();
      return;
    }
    _trackWordBoundary(g);
    // In IME mode, send to the focused field; otherwise show locally.
    if (ImeChannel.isImeMode) {
      ImeChannel.commitText(g);
    } else {
      setState(() => _output.add(g));
      HapticFeedback.lightImpact();
    }
  }

  static const _wordEnders = ' \n.,?!;:';

  /// Tracks word boundaries and updates prediction context accordingly.
  /// Called for every committed glyph before it is sent to the output.
  void _trackWordBoundary(String g) {
    if (g.length > 1) {
      // Multi-char commit from a word-prediction branch — this IS a full word.
      _predictor.updateContext(g);
      _currentWord = '';
      setState(() => _keys = buildKeys(_predictor));
    } else if (_wordEnders.contains(g)) {
      if (_currentWord.isNotEmpty) {
        _predictor.updateContext(_currentWord);
        _currentWord = '';
        setState(() => _keys = buildKeys(_predictor));
      }
      // Clear context after sentence-ending punctuation.
      if ('.?!'.contains(g)) _predictor.clearContext();
    } else {
      _currentWord += g;
    }
  }

  void _onDelete() {
    // Keep the word accumulator in sync with what is actually on screen.
    if (_currentWord.isNotEmpty) {
      _currentWord = _currentWord.substring(0, _currentWord.length - 1);
    }
    if (ImeChannel.isImeMode) {
      ImeChannel.deleteLast();
    } else {
      if (_output.isNotEmpty) {
        setState(() => _output.removeLast());
      }
      HapticFeedback.mediumImpact();
    }
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        columns: _columns,
        opacity: _opacity,
        onSave: (cols, op) {
          setState(() {
            _columns = cols;
            _opacity = op;
          });
          Navigator.of(context).pop();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final typed = _output.join();
    return Scaffold(
      body: Stack(
        children: [
          // Fake background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              ),
            ),
          ),
          Column(
            children: [
              // Output display
              Expanded(
                flex: 2,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        typed.isEmpty ? 'Tap keys below…' : typed,
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Keyboard area
              Expanded(
                flex: 8,
                child: SafeArea(
                  top: false,
                  child: KeyboardView(
                    keys: _keys,
                    columns: _columns,
                    opacity: _opacity,
                    onGlyph: _onGlyph,
                    onSettings: _openSettings,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
