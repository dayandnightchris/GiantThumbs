import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ime_channel.dart';
import 'key_data.dart';
import 'keyboard_view.dart';
import 'layout_editor_screen.dart';
import 'layout_store.dart';
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

  KeyboardSettings _settings = KeyboardSettings();

  /// The user's custom layout, or null when they use the predictor-built
  /// default. Word predictions are layered on top of this at runtime.
  List<BranchNode>? _customLayout;

  List<BranchNode> _keys = defaultKeys();
  final WordPredictor _predictor = WordPredictor();

  // Accumulates individual letter commits so we know when a word ends.
  String _currentWord = '';

  @override
  void initState() {
    super.initState();
    ImeChannel.init(_openSettings);
    // Rebuild into keyboard-only mode the moment the IME host connects.
    ImeChannel.imeMode.addListener(_onImeModeChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    ImeChannel.imeMode.removeListener(_onImeModeChanged);
    super.dispose();
  }

  void _onImeModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    // Settings/layout persistence may be unavailable (e.g. in widget tests);
    // fall back to defaults rather than crashing startup.
    KeyboardSettings settings = KeyboardSettings();
    List<BranchNode>? layout;
    try {
      settings = await LayoutStore.loadSettings();
      layout = await LayoutStore.loadLayout();
    } catch (_) {
      // Keep defaults.
    }
    await _predictor.load(rootBundle);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _customLayout = layout;
      _keys = buildKeys(_predictor, base: _customLayout);
    });
  }

  void _rebuildKeys() {
    setState(() => _keys = buildKeys(_predictor, base: _customLayout));
  }

  void _onGlyph(String g) {
    switch (g) {
      case kGlyphBackspace:
        _onDelete();
        return;
      case kGlyphMenu:
        _openSettings();
        return;
      case kGlyphDeleteWord:
        _onDeleteWord();
        return;
      case kGlyphDeleteAll:
        _onDeleteAll();
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
      _rebuildKeys();
    } else if (_wordEnders.contains(g)) {
      if (_currentWord.isNotEmpty) {
        _predictor.updateContext(_currentWord);
        _currentWord = '';
        _rebuildKeys();
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

  void _onDeleteWord() {
    _currentWord = '';
    if (ImeChannel.isImeMode) {
      ImeChannel.deleteWord();
    } else {
      // Demo: drop trailing space tokens then one word token.
      setState(() {
        while (_output.isNotEmpty && _output.last.trim().isEmpty) {
          _output.removeLast();
        }
        if (_output.isNotEmpty) _output.removeLast();
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _onDeleteAll() {
    _currentWord = '';
    if (ImeChannel.isImeMode) {
      ImeChannel.deleteAll();
    } else {
      setState(() => _output.clear());
      HapticFeedback.mediumImpact();
    }
  }

  void _openSettings() {
    // Inside the IME window there's no room for a full settings screen — bounce
    // out to the standalone app instead.
    if (ImeChannel.isImeMode) {
      ImeChannel.launchHostApp();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        settings: _settings,
        onSave: (s) async {
          await LayoutStore.saveSettings(s);
          if (!mounted) return;
          setState(() => _settings = s);
          Navigator.of(context).pop();
        },
        onEditLayout: _openLayoutEditor,
      ),
    ));
  }

  void _openLayoutEditor() {
    // Edit the current effective layout (custom if set, otherwise the default
    // structure without runtime predictions).
    final base = _customLayout ?? defaultKeys();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LayoutEditorScreen(
        initial: base,
        columns: _settings.columns,
        onSaved: (layout) {
          setState(() => _customLayout = layout);
          _rebuildKeys();
        },
      ),
    ));
  }

  /// Background gradient shared by the demo shell and the IME keyboard.
  static const _backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
  );

  Widget _buildKeyboard() => KeyboardView(
        keys: _keys,
        columns: _settings.columns,
        opacity: _settings.opacity,
        drillDelayMs: _settings.drillDelayMs,
        onGlyph: _onGlyph,
      );

  @override
  Widget build(BuildContext context) {
    // System-keyboard mode: render only the keyboard with a transparent
    // background so the host app shows through the gaps between keys (the keys
    // themselves honour the opacity setting). The native service sizes the
    // window. No demo output box.
    if (ImeChannel.isImeMode) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(top: false, child: _buildKeyboard()),
      );
    }

    final typed = _output.join();
    return Scaffold(
      body: Stack(
        children: [
          // Fake background gradient
          Container(
            decoration: const BoxDecoration(gradient: _backgroundGradient),
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
                child: SafeArea(top: false, child: _buildKeyboard()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
