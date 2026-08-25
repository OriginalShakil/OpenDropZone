import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tray_window_controller.dart';

class ShortcutModel {
  final String keyLabel;
  final int keyCode;
  final int modifiers; // 1=Ctrl, 2=Opt, 4=Shift, 8=Cmd

  const ShortcutModel({
    required this.keyLabel,
    required this.keyCode,
    required this.modifiers,
  });

  bool get hasCtrl => (modifiers & 1) != 0;
  bool get hasOpt => (modifiers & 2) != 0;
  bool get hasShift => (modifiers & 4) != 0;
  bool get hasCmd => (modifiers & 8) != 0;

  String get displayString {
    final buffer = StringBuffer();
    if (hasCtrl) buffer.write('⌃ ');
    if (hasOpt) buffer.write('⌥ ');
    if (hasShift) buffer.write('⇧ ');
    if (hasCmd) buffer.write('⌘ ');
    buffer.write(keyLabel.toUpperCase());
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'keyLabel': keyLabel,
        'keyCode': keyCode,
        'modifiers': modifiers,
      };

  factory ShortcutModel.fromJson(Map<String, dynamic> json) {
    return ShortcutModel(
      keyLabel: json['keyLabel'] as String? ?? 'Space',
      keyCode: json['keyCode'] as int? ?? 49,
      modifiers: json['modifiers'] as int? ?? 2,
    );
  }
}

class ShortcutService {
  ShortcutService._();
  static final ShortcutService instance = ShortcutService._();

  static const MethodChannel _hotKeyChannel = MethodChannel('dropzone/hotkeys');

  // Default Shortcuts:
  // 1. Toggle Popup: Option + Space (modifiers: 2, keyCode: 49)
  static const defaultOpenPopup = ShortcutModel(
    keyLabel: 'Space',
    keyCode: 49,
    modifiers: 2,
  );

  // 2. Add Finder Selection: Control + Option + D (modifiers: 3, keyCode: 2)
  static const defaultAddSelection = ShortcutModel(
    keyLabel: 'D',
    keyCode: 2,
    modifiers: 3,
  );

  ShortcutModel _openPopupShortcut = defaultOpenPopup;
  ShortcutModel _addSelectionShortcut = defaultAddSelection;

  ShortcutModel get openPopupShortcut => _openPopupShortcut;
  ShortcutModel get addSelectionShortcut => _addSelectionShortcut;

  Future<void> init() async {
    _hotKeyChannel.setMethodCallHandler((call) async {
      if (call.method == 'onHotKeyTriggered') {
        final identifier = call.arguments?['identifier'] as String?;
        if (identifier == 'open_popup') {
          TrayWindowController.instance.toggleWindow();
        } else if (identifier == 'add_finder_selection') {
          // Swift handles getting the Finder selection and passing to TrayDragBridge
          await TrayWindowController.instance.showWindow();
        }
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final openJson = prefs.getString('hotkey_open_popup');
      if (openJson != null) {
        _openPopupShortcut = ShortcutModel.fromJson(jsonDecode(openJson));
      }

      final addJson = prefs.getString('hotkey_add_finder_selection');
      if (addJson != null) {
        _addSelectionShortcut = ShortcutModel.fromJson(jsonDecode(addJson));
      }
    } catch (_) {}

    await _applyHotKeys();
  }

  Future<void> setOpenPopupShortcut(ShortcutModel shortcut) async {
    _openPopupShortcut = shortcut;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hotkey_open_popup', jsonEncode(shortcut.toJson()));
    } catch (_) {}
    await _applyHotKey('open_popup', _openPopupShortcut);
  }

  Future<void> setAddSelectionShortcut(ShortcutModel shortcut) async {
    _addSelectionShortcut = shortcut;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'hotkey_add_finder_selection', jsonEncode(shortcut.toJson()));
    } catch (_) {}
    await _applyHotKey('add_finder_selection', _addSelectionShortcut);
  }

  Future<void> resetToDefaults() async {
    await setOpenPopupShortcut(defaultOpenPopup);
    await setAddSelectionShortcut(defaultAddSelection);
  }

  Future<void> _applyHotKeys() async {
    await _applyHotKey('open_popup', _openPopupShortcut);
    await _applyHotKey('add_finder_selection', _addSelectionShortcut);
  }

  Future<void> _applyHotKey(String identifier, ShortcutModel shortcut) async {
    try {
      await _hotKeyChannel.invokeMethod('registerHotKey', {
        'identifier': identifier,
        'keyCode': shortcut.keyCode,
        'modifiers': shortcut.modifiers,
      });
    } catch (e) {
      debugPrint('Failed to register global hotkey $identifier: $e');
    }
  }

  /// Map Flutter LogicalKeyboardKey to macOS Virtual KeyCode
  static int? getMacVirtualKeyCode(LogicalKeyboardKey key) {
    return _keyToVirtualCode[key];
  }

  static final Map<LogicalKeyboardKey, int> _keyToVirtualCode = {
    LogicalKeyboardKey.keyA: 0,
    LogicalKeyboardKey.keyS: 1,
    LogicalKeyboardKey.keyD: 2,
    LogicalKeyboardKey.keyF: 3,
    LogicalKeyboardKey.keyH: 4,
    LogicalKeyboardKey.keyG: 5,
    LogicalKeyboardKey.keyZ: 6,
    LogicalKeyboardKey.keyX: 7,
    LogicalKeyboardKey.keyC: 8,
    LogicalKeyboardKey.keyV: 9,
    LogicalKeyboardKey.keyB: 11,
    LogicalKeyboardKey.keyQ: 12,
    LogicalKeyboardKey.keyW: 13,
    LogicalKeyboardKey.keyE: 14,
    LogicalKeyboardKey.keyR: 15,
    LogicalKeyboardKey.keyY: 16,
    LogicalKeyboardKey.keyT: 17,
    LogicalKeyboardKey.digit1: 18,
    LogicalKeyboardKey.digit2: 19,
    LogicalKeyboardKey.digit3: 20,
    LogicalKeyboardKey.digit4: 21,
    LogicalKeyboardKey.digit6: 22,
    LogicalKeyboardKey.digit5: 23,
    LogicalKeyboardKey.equal: 24,
    LogicalKeyboardKey.digit9: 25,
    LogicalKeyboardKey.digit7: 26,
    LogicalKeyboardKey.minus: 27,
    LogicalKeyboardKey.digit8: 28,
    LogicalKeyboardKey.digit0: 29,
    LogicalKeyboardKey.bracketRight: 30,
    LogicalKeyboardKey.keyO: 31,
    LogicalKeyboardKey.keyU: 32,
    LogicalKeyboardKey.bracketLeft: 33,
    LogicalKeyboardKey.keyI: 34,
    LogicalKeyboardKey.keyP: 35,
    LogicalKeyboardKey.keyL: 37,
    LogicalKeyboardKey.keyJ: 38,
    LogicalKeyboardKey.quote: 39,
    LogicalKeyboardKey.keyK: 40,
    LogicalKeyboardKey.semicolon: 41,
    LogicalKeyboardKey.backslash: 42,
    LogicalKeyboardKey.comma: 43,
    LogicalKeyboardKey.slash: 44,
    LogicalKeyboardKey.keyN: 45,
    LogicalKeyboardKey.keyM: 46,
    LogicalKeyboardKey.period: 47,
    LogicalKeyboardKey.tab: 48,
    LogicalKeyboardKey.space: 49,
    LogicalKeyboardKey.backquote: 50,
    LogicalKeyboardKey.delete: 51,
    LogicalKeyboardKey.escape: 53,
    LogicalKeyboardKey.f1: 122,
    LogicalKeyboardKey.f2: 120,
    LogicalKeyboardKey.f3: 99,
    LogicalKeyboardKey.f4: 118,
    LogicalKeyboardKey.f5: 96,
    LogicalKeyboardKey.f6: 97,
    LogicalKeyboardKey.f7: 98,
    LogicalKeyboardKey.f8: 100,
    LogicalKeyboardKey.f9: 101,
    LogicalKeyboardKey.f10: 109,
    LogicalKeyboardKey.f11: 103,
    LogicalKeyboardKey.f12: 111,
  };
}
