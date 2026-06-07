import 'package:flutter/material.dart';
import 'layout_store.dart';

class SettingsScreen extends StatefulWidget {
  final KeyboardSettings settings;
  final void Function(KeyboardSettings settings) onSave;
  final VoidCallback onEditLayout;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSave,
    required this.onEditLayout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _columns;
  late double _opacity;
  late double _drillDelay;

  @override
  void initState() {
    super.initState();
    _columns = widget.settings.columns;
    _opacity = widget.settings.opacity;
    _drillDelay = widget.settings.drillDelayMs.toDouble();
  }

  void _save() {
    widget.onSave(KeyboardSettings(
      columns: _columns,
      opacity: _opacity,
      drillDelayMs: _drillDelay.round(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giant Thumbs — Settings'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Layout',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.onEditLayout,
            icon: const Icon(Icons.grid_view),
            label: const Text('Edit key layout…'),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose exactly what glyph goes in every tile and branch.',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 32),

          const Text('Speed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'The first branch is always instant. This sets how long you dwell on '
            'a letter before it opens its word predictions.',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          Row(
            children: [
              const Text('Instant'),
              Expanded(
                child: Slider(
                  value: _drillDelay,
                  min: 0,
                  max: 600,
                  divisions: 12,
                  label: _drillDelay.round() == 0
                      ? 'Instant'
                      : '${_drillDelay.round()} ms',
                  onChanged: (v) => setState(() => _drillDelay = v),
                ),
              ),
              const Text('Relaxed'),
            ],
          ),
          Center(
            child: Text(
              _drillDelay.round() == 0
                  ? 'Drill delay: instant'
                  : 'Drill delay: ${_drillDelay.round()} ms',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 32),

          const Text('Transparency',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          const Text('Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
