import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'key_data.dart';
import 'keyboard_view.dart';
import 'settings_screen.dart';

void main() {
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

  void _onGlyph(String g) {
    setState(() => _output.add(g));
    HapticFeedback.lightImpact();
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
                flex: 3,
                child: KeyboardView(
                  keys: defaultKeys,
                  columns: _columns,
                  opacity: _opacity,
                  onGlyph: _onGlyph,
                  onSettings: _openSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
