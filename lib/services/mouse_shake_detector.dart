import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'tray_window_controller.dart';

/// Detects mouse shaking behavior during drag operations.
/// Opens the popup when the user shakes the mouse for a sustained period.
class MouseShakeDetector {
  static final MouseShakeDetector instance = MouseShakeDetector._();
  MouseShakeDetector._();

  static const MethodChannel _channel = MethodChannel('dropzone/mouse_shake');

  bool _isMonitoring = false;
  Timer? _shakeTimer;
  Timer? _resetTimer;

  final List<Offset> _recentPositions = [];
  DateTime? _shakeStartTime;
  bool _isShaking = false;

  // Shake detection parameters - MORE LENIENT
  static const int _positionHistorySize = 10;
  static const double _shakeThreshold = 200.0; // Total movement in window
  static const int _minDirectionChanges = 2; // Just 2 direction changes needed
  static const Duration _shakeDuration = Duration(
    milliseconds: 600,
  ); // 0.6 seconds
  static const Duration _resetDelay = Duration(
    milliseconds: 400,
  ); // Reset if no movement

  VoidCallback? onShakeDetected;

  Future<void> init() async {
    try {
      _channel.setMethodCallHandler(_handleMethodCall);

      // Set up callback to open popup on shake detection
      onShakeDetected = () {
        debugPrint('🎊 Global shake detected! Opening popup...');
        TrayWindowController.instance.showWindow();
      };

      // Check accessibility permission status
      final hasPermission = await checkAccessibilityPermission();
      if (!hasPermission) {
        debugPrint(
          '⚠️ MouseShakeDetector: No accessibility permission. Drag detection from VS Code and other apps will be limited.',
        );
        debugPrint(
          '💡 Call requestAccessibilityPermission() to prompt the user.',
        );
      }

      // Start global drag monitoring - detects ANY drag operation system-wide
      await _channel.invokeMethod('startGlobalDragMonitoring');
      debugPrint(
        '🌍 MouseShakeDetector: Global drag monitoring enabled (accessibility: $hasPermission)',
      );
    } catch (e) {
      debugPrint('⚠️ MouseShakeDetector: Platform channel setup failed: $e');
      // Platform-specific channel might not be available
    }
  }

  /// Check if the app has accessibility permission
  Future<bool> checkAccessibilityPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'checkAccessibilityPermission',
      );
      return result ?? false;
    } catch (e) {
      debugPrint(
        '⚠️ MouseShakeDetector: Failed to check accessibility permission: $e',
      );
      return false;
    }
  }

  /// Request accessibility permission from the user
  Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
      debugPrint(
        '🔐 MouseShakeDetector: Accessibility permission dialog shown',
      );
    } catch (e) {
      debugPrint(
        '⚠️ MouseShakeDetector: Failed to request accessibility permission: $e',
      );
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('📞 MouseShakeDetector: Received method call: ${call.method}');
    if (call.method == 'onMouseMoved') {
      // Auto-enable monitoring when we start receiving positions
      if (!_isMonitoring) {
        _isMonitoring = true;
        _recentPositions.clear();
        _shakeStartTime = null;
        _isShaking = false;
        debugPrint(
          '🎯 MouseShakeDetector: Auto-enabled monitoring from mouse events',
        );
      }

      final args = call.arguments as Map?;
      if (args != null) {
        final x = (args['x'] as num?)?.toDouble() ?? 0.0;
        final y = (args['y'] as num?)?.toDouble() ?? 0.0;
        debugPrint('🖱️ Flutter received mouse moved: ($x, $y)');
        _onMouseMoved(Offset(x, y));
      }
    } else if (call.method == 'onDragEnded') {
      debugPrint('🏁 Drag ended from native');
      stopMonitoring();
    }
  }

  /// Start monitoring mouse movements during drag
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _recentPositions.clear();
    _shakeStartTime = null;
    _isShaking = false;

    debugPrint('🎯 MouseShakeDetector: Started monitoring');

    try {
      await _channel.invokeMethod('startMonitoring');
      debugPrint('✅ MouseShakeDetector: Native monitoring started');
    } catch (e) {
      debugPrint(
        '⚠️ MouseShakeDetector: Native monitoring failed, using fallback: $e',
      );
      // Fallback: monitoring will work through manual position updates
    }
  }

  /// Stop monitoring mouse movements
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    debugPrint('🛑 MouseShakeDetector: Stopped monitoring');

    _isMonitoring = false;
    _recentPositions.clear();
    _shakeStartTime = null;
    _isShaking = false;
    _shakeTimer?.cancel();
    _resetTimer?.cancel();

    try {
      await _channel.invokeMethod('stopMonitoring');
    } catch (e) {
      // Ignore
    }
  }

  /// Manually update mouse position (fallback for when platform channel isn't available)
  void updateMousePosition(Offset position) {
    if (_isMonitoring) {
      _onMouseMoved(position);
    }
  }

  void _onMouseMoved(Offset position) {
    if (!_isMonitoring) return;

    // Reset the "no movement" timer
    _resetTimer?.cancel();
    _resetTimer = Timer(_resetDelay, () {
      // If no movement for a while, reset shake detection
      if (_isShaking) {
        debugPrint('⏸️ MouseShakeDetector: No movement, resetting shake');
      }
      _shakeStartTime = null;
      _isShaking = false;
    });

    // Add to position history
    _recentPositions.add(position);
    if (_recentPositions.length > _positionHistorySize) {
      _recentPositions.removeAt(0);
    }

    // Need at least a few positions to detect shaking
    if (_recentPositions.length < 4) return;

    // Check if current movement pattern indicates shaking
    final isCurrentlyShaking = _detectShakePattern();

    if (isCurrentlyShaking) {
      if (!_isShaking) {
        // Just started shaking
        _isShaking = true;
        _shakeStartTime = DateTime.now();

        debugPrint(
          '🔥 MouseShakeDetector: Shaking started! Will trigger in ${_shakeDuration.inMilliseconds}ms',
        );

        // Start timer to check if shaking continues for required duration
        _shakeTimer?.cancel();
        _shakeTimer = Timer(_shakeDuration, () {
          if (_isShaking && _shakeStartTime != null) {
            final elapsed = DateTime.now().difference(_shakeStartTime!);
            if (elapsed >= _shakeDuration) {
              // Sustained shaking detected!
              debugPrint(
                '🎉 MouseShakeDetector: SHAKE DETECTED! Opening popup...',
              );
              onShakeDetected?.call();
              stopMonitoring();
            }
          }
        });
      }
    } else {
      // Not shaking anymore, reset
      if (_isShaking) {
        debugPrint('⏸️ MouseShakeDetector: Shaking stopped, resetting');
        _isShaking = false;
        _shakeStartTime = null;
        _shakeTimer?.cancel();
      }
    }
  }

  /// Detect if the recent position history shows a shaking pattern
  bool _detectShakePattern() {
    if (_recentPositions.length < 4) return false;

    // Calculate direction changes and total movement
    int directionChangesX = 0;
    int directionChangesY = 0;
    double totalMovement = 0.0;

    for (int i = 1; i < _recentPositions.length; i++) {
      final prev = _recentPositions[i - 1];
      final curr = _recentPositions[i];
      final delta = curr - prev;

      totalMovement += delta.distance;

      // Check for direction changes
      if (i >= 2) {
        final prevDelta = _recentPositions[i - 1] - _recentPositions[i - 2];

        // X-axis direction change
        if (prevDelta.dx.sign != delta.dx.sign && delta.dx.abs() > 10.0) {
          directionChangesX++;
        }
        // Y-axis direction change
        if (prevDelta.dy.sign != delta.dy.sign && delta.dy.abs() > 10.0) {
          directionChangesY++;
        }
      }
    }

    final totalDirectionChanges = directionChangesX + directionChangesY;

    // Shaking: enough movement + direction changes
    final hasEnoughDirectionChanges =
        totalDirectionChanges >= _minDirectionChanges;
    final hasEnoughMovement = totalMovement > _shakeThreshold;

    final isShaking = hasEnoughDirectionChanges && hasEnoughMovement;

    // Log detection status when we have full history
    if (_recentPositions.length >= _positionHistorySize) {
      debugPrint(
        '📊 Shake check: DirChanges=$totalDirectionChanges/$_minDirectionChanges, Movement=${totalMovement.toStringAsFixed(0)}/${_shakeThreshold.toStringAsFixed(0)} → ${isShaking ? "✅ SHAKING!" : "❌"}',
      );
    }

    return isShaking;
  }

  void dispose() {
    stopMonitoring();
    _shakeTimer?.cancel();
    _resetTimer?.cancel();
  }
}
