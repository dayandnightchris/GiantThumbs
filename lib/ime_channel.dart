import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around the platform channel to the Android IME service.
/// In demo mode (not running as a system keyboard) calls are silently dropped.
class ImeChannel {
  static const _channel = MethodChannel('com.giantthumbs/ime');

  static bool _imeMode = false;

  /// True when running as a system keyboard (IME). Listenable so the UI can
  /// switch to a keyboard-only layout the moment the IME host connects.
  static final ValueNotifier<bool> imeMode = ValueNotifier<bool>(false);

  /// Called once at startup. If the native side sends setMode('ime'),
  /// we switch into IME mode and route glyphs through [commitText].
  static void init(void Function() onSettingsRequested) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'setMode':
          if (call.arguments['mode'] == 'ime') {
            _imeMode = true;
            imeMode.value = true;
          }
        case 'openSettings':
          onSettingsRequested();
      }
    });
    // Tell the native IME host the Dart handler is registered, so it can hand us
    // the mode without racing startup. Harmless MissingPluginException when
    // running as the standalone app (no native handler) — we ignore it.
    _channel.invokeMethod('imeClientReady').catchError((_) => null);
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

  /// Launch the full Giant Thumbs app — used to reach settings/the layout editor
  /// from inside the IME, where pushing a route into the small keyboard window
  /// would be awkward.
  static Future<void> launchHostApp() async {
    try {
      await _channel.invokeMethod('launchHostApp');
    } catch (_) {
      // No host available (standalone app already in foreground) — ignore.
    }
  }

  static bool get isImeMode => _imeMode;
}
