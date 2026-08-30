import 'dart:io';
import 'package:flutter/material.dart';
import '../services/shortcut_service.dart';
import '../services/startup_service.dart';
import '../services/tray_window_controller.dart';
import '../services/mouse_shake_detector.dart';
import 'shortcut_recorder_widget.dart';

class SettingsSheet extends StatefulWidget {
  final VoidCallback onClearAll;
  final int fileCount;

  const SettingsSheet({
    super.key,
    required this.onClearAll,
    required this.fileCount,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _launchAtStartup = false;
  bool _hasAccessibilityPermission = false;
  bool _isLoading = true;

  ShortcutModel _openPopupShortcut = ShortcutService.instance.openPopupShortcut;
  ShortcutModel _addSelectionShortcut =
      ShortcutService.instance.addSelectionShortcut;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isEnabled = await StartupService.instance.isEnabled();
    final hasPermission = await MouseShakeDetector.instance
        .checkAccessibilityPermission();
    if (mounted) {
      setState(() {
        _launchAtStartup = isEnabled;
        _hasAccessibilityPermission = hasPermission;
        _openPopupShortcut = ShortcutService.instance.openPopupShortcut;
        _addSelectionShortcut = ShortcutService.instance.addSelectionShortcut;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLaunchAtStartup(bool value) async {
    setState(() {
      _launchAtStartup = value;
    });
    await StartupService.instance.setEnabled(value);
  }

  Future<void> _updateOpenPopupShortcut(ShortcutModel shortcut) async {
    setState(() {
      _openPopupShortcut = shortcut;
    });
    await ShortcutService.instance.setOpenPopupShortcut(shortcut);
  }

  Future<void> _updateAddSelectionShortcut(ShortcutModel shortcut) async {
    setState(() {
      _addSelectionShortcut = shortcut;
    });
    await ShortcutService.instance.setAddSelectionShortcut(shortcut);
  }

  Future<void> _resetOpenPopupShortcut() async {
    await _updateOpenPopupShortcut(ShortcutService.defaultOpenPopup);
  }

  Future<void> _resetAddSelectionShortcut() async {
    await _updateAddSelectionShortcut(ShortcutService.defaultAddSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF9F9FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settings & Options',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Keyboard Shortcuts Section
            Text(
              'KEYBOARD SHORTCUTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: [
                  // 1. Open Dropzone Popup
                  ShortcutRecorderWidget(
                    title: 'Open Dropzone',
                    subtitle: 'Toggle menu bar popup window',
                    shortcut: _openPopupShortcut,
                    onChanged: _updateOpenPopupShortcut,
                    onReset: _resetOpenPopupShortcut,
                  ),

                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),

                  // 2. Add Selected Items in Finder
                  ShortcutRecorderWidget(
                    title: 'Add Selected Items',
                    subtitle: 'Send Finder selection to Dropzone',
                    shortcut: _addSelectionShortcut,
                    onChanged: _updateAddSelectionShortcut,
                    onReset: _resetAddSelectionShortcut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Launch at Startup Section
            Text(
              'GENERAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.power_settings_new_rounded,
                        size: 18,
                        color: Color(0xFF007AFF),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Launch at Startup',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1D1D1F),
                            ),
                          ),
                          Text(
                            'Open automatically on login',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Transform.scale(
                          scale: 0.8,
                          child: Switch.adaptive(
                            value: _launchAtStartup,
                            activeTrackColor: const Color(0xFF007AFF),
                            onChanged: _toggleLaunchAtStartup,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Accessibility Permission Section (only show if not granted)
            if (!_hasAccessibilityPermission) ...[
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  await MouseShakeDetector.instance
                      .requestAccessibilityPermission();
                  // Reload settings after a delay to check if permission was granted
                  await Future.delayed(const Duration(seconds: 2));
                  _loadSettings();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFB74D),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.accessibility_new_rounded,
                        size: 20,
                        color: Color(0xFFFF9800),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable VS Code Drag Detection',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1D1D1F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Grant accessibility permission to detect drags from VS Code and other apps',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : Colors.black.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFFFF9800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Clear history button
            if (widget.fileCount > 0) ...[
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  widget.onClearAll();
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_sweep_outlined,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Clear Open Drop Zone Items (${widget.fileCount})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // App Info & Quit Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Open Drop Zone for macOS • v0.1.0',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.35),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    TrayWindowController.instance.hideWindow();
                    exit(0);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded, size: 14),
                  label: const Text(
                    'Quit App',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
