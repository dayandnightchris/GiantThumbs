import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'key_data.dart';

/// User-tunable keyboard settings, persisted across launches.
class KeyboardSettings {
  int columns;
  double opacity;

  /// Delay before the keyboard drills into a child node that has its own
  /// children (e.g. letter → word predictions). The *first* branch level is
  /// always instant; this only governs deeper levels. 0 = instant everywhere.
  int drillDelayMs;

  KeyboardSettings({
    this.columns = 3,
    this.opacity = 0.40,
    this.drillDelayMs = 220,
  });

  KeyboardSettings copyWith({int? columns, double? opacity, int? drillDelayMs}) =>
      KeyboardSettings(
        columns: columns ?? this.columns,
        opacity: opacity ?? this.opacity,
        drillDelayMs: drillDelayMs ?? this.drillDelayMs,
      );
}

/// Loads and saves keyboard settings and the custom key layout via
/// [SharedPreferences]. All methods are static and safe to call repeatedly.
class LayoutStore {
  static const _kColumns = 'gt_columns';
  static const _kOpacity = 'gt_opacity';
  static const _kDrillDelay = 'gt_drill_delay_ms';
  static const _kLayout = 'gt_layout_json';

  // ── Settings ──────────────────────────────────────────────────────────────

  static Future<KeyboardSettings> loadSettings() async {
    final p = await SharedPreferences.getInstance();
    return KeyboardSettings(
      columns: p.getInt(_kColumns) ?? 3,
      opacity: p.getDouble(_kOpacity) ?? 0.40,
      drillDelayMs: p.getInt(_kDrillDelay) ?? 220,
    );
  }

  static Future<void> saveSettings(KeyboardSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kColumns, s.columns);
    await p.setDouble(_kOpacity, s.opacity);
    await p.setInt(_kDrillDelay, s.drillDelayMs);
  }

  // ── Custom layout ───────────────────────────────────────────────────────────

  /// Returns the user's saved layout, or null if they've never customized it
  /// (in which case the predictor-generated default is used).
  static Future<List<BranchNode>?> loadLayout() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLayout);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => BranchNode.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt layout — fall back to default rather than crashing.
      return null;
    }
  }

  static Future<void> saveLayout(List<BranchNode> layout) async {
    final p = await SharedPreferences.getInstance();
    final raw = jsonEncode(layout.map((n) => n.toJson()).toList());
    await p.setString(_kLayout, raw);
  }

  /// Forget the custom layout and revert to the built-in default.
  static Future<void> clearLayout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLayout);
  }

  static String exportLayout(List<BranchNode> layout) =>
      jsonEncode(layout.map((n) => n.toJson()).toList());

  static List<BranchNode>? importLayout(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => BranchNode.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
