import 'package:flutter/services.dart';

/// Thin wrapper around the platform channel to the Android IME service.
/// In demo mode (not running as a system keyboard) calls are silently dropped.
class ImeChannel {
  static const _channel = MethodChannel('com.giantthumbs/ime');

  static bool _imeMode = false;

  /// Called once at startup. If the native side sends setMode('ime'),
  /// we switch into IME mode and route glyphs through [commitText].
  static void init(void Function() onSettingsRequested) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'setMode':
          if (call.arguments['mode'] == 'ime') _imeMode = true;
        case 'openSettings':
          onSettingsRequested();
      }
    });
  }

  /// Send a glyph to the currently focused input field.
  static Future<void> commitText(String text) async {
    if (!_imeMode) return;
    await _channel.invokeMethod('commitText', {'text': text});
  }

  /// Delete the character before the cursor.
  static Future<void> deleteLast() async {
    if (!_imeMode) return;
    await _channel.invokeMethod('deleteLast');
  }

  static bool get isImeMode => _imeMode;
}
