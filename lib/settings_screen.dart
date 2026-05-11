import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final int columns;
  final double opacity;
  final void Function(int columns, double opacity) onSave;

  const SettingsScreen({
    super.key,
    required this.columns,
    required this.opacity,
    required this.onSave,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _columns;
  late double _opacity;

  @override
  void initState() {
    super.initState();
    _columns = widget.columns;
    _opacity = widget.opacity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giant Thumbs — Settings'),
        actions: [
          TextButton(
            onPressed: () => widget.onSave(_columns, _opacity),
            child: const Text('Save', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Layout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Columns: '),
              const SizedBox(width: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 4, label: Text('4')),
                ],
                selected: {_columns},
                onSelectionChanged: (s) => setState(() => _columns = s.first),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Transparency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Opaque'),
              Expanded(
                child: Slider(
                  value: _opacity,
                  min: 0.05,
                  max: 0.95,
                  divisions: 18,
                  label: '${(_opacity * 100).round()}%',
                  onChanged: (v) => setState(() => _opacity = v),
                ),
              ),
              const Text('Transparent'),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Key opacity: ${(_opacity * 100).round()}%',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 32),

          // Key preview
          const Text('Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_columns, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: _opacity),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white38),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
