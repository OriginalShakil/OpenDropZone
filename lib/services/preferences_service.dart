import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app preferences and settings
class PreferencesService {
  static final PreferencesService instance = PreferencesService._();
  PreferencesService._();

  static const String _keyShakeDurationSeconds = 'shake_duration_seconds';
  static const String _keyRemoveAfterDragOut = 'remove_after_drag_out';

  // Default values
  static const double defaultShakeDurationSeconds = 1.0;
  static const bool defaultRemoveAfterDragOut = false;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get shake duration in seconds (0.1 to 3.0 seconds)
  Future<double> getShakeDurationSeconds() async {
    _prefs ??= await SharedPreferences.getInstance();
    final val = _prefs?.getDouble(_keyShakeDurationSeconds) ??
        defaultShakeDurationSeconds;
    return val.clamp(0.1, 3.0);
  }

  /// Set shake duration in seconds (0.1 to 3.0 seconds)
  Future<void> setShakeDurationSeconds(double seconds) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setDouble(_keyShakeDurationSeconds, seconds.clamp(0.1, 3.0));
  }

  /// Get whether to remove items after drag-out
  Future<bool> getRemoveAfterDragOut() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs?.getBool(_keyRemoveAfterDragOut) ?? defaultRemoveAfterDragOut;
  }

  /// Set whether to remove items after drag-out
  Future<void> setRemoveAfterDragOut(bool remove) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_keyRemoveAfterDragOut, remove);
  }
}
