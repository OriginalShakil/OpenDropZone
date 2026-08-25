import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/shortcut_service.dart';

class ShortcutRecorderWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final ShortcutModel shortcut;
  final ValueChanged<ShortcutModel> onChanged;
  final VoidCallback onReset;

  const ShortcutRecorderWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.shortcut,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<ShortcutRecorderWidget> createState() => _ShortcutRecorderWidgetState();
}

class _ShortcutRecorderWidgetState extends State<ShortcutRecorderWidget> {
  final FocusNode _focusNode = FocusNode();
  bool _isRecording = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
    });
    _focusNode.requestFocus();
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    _focusNode.unfocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isRecording) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      final key = event.logicalKey;

      // Ignore bare modifier key presses alone
      if (key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight ||
          key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight ||
          key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight ||
          key == LogicalKeyboardKey.metaLeft ||
          key == LogicalKeyboardKey.metaRight) {
        return KeyEventResult.handled;
      }

      // Escape to cancel recording
      if (key == LogicalKeyboardKey.escape &&
          !HardwareKeyboard.instance.isAltPressed &&
          !HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isMetaPressed) {
        _stopRecording();
        return KeyEventResult.handled;
      }

      final macKeyCode = ShortcutService.getMacVirtualKeyCode(key);
      if (macKeyCode != null) {
        var modifiers = 0;
        if (HardwareKeyboard.instance.isControlPressed) modifiers |= 1;
        if (HardwareKeyboard.instance.isAltPressed) modifiers |= 2;
        if (HardwareKeyboard.instance.isShiftPressed) modifiers |= 4;
        if (HardwareKeyboard.instance.isMetaPressed) modifiers |= 8;

        // If no modifiers pressed, default to Option (Alt)
        if (modifiers == 0) {
          modifiers = 2; // Option
        }

        final label = key.keyLabel.isNotEmpty ? key.keyLabel : 'Key';
        final newShortcut = ShortcutModel(
          keyLabel: label,
          keyCode: macKeyCode,
          modifiers: modifiers,
        );

        widget.onChanged(newShortcut);
        _stopRecording();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Shortcut button / Recorder
          Focus(
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _isRecording ? _stopRecording : _startRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? const Color(0xFF007AFF).withValues(alpha: 0.15)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isRecording
                        ? const Color(0xFF007AFF)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.1)),
                    width: _isRecording ? 1.5 : 1.0,
                  ),
                  boxShadow: _isRecording
                      ? [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRecording) ...[
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Type shortcut...',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ] else ...[
                      Text(
                        widget.shortcut.displayString,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Reset button
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            tooltip: 'Reset to default',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.4),
            onPressed: widget.onReset,
          ),
        ],
      ),
    );
  }
}
