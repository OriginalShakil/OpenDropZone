import 'dart:io';
import 'package:flutter/material.dart';
import '../services/startup_service.dart';
import '../services/tray_window_controller.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isEnabled = await StartupService.instance.isEnabled();
    if (mounted) {
      setState(() {
        _launchAtStartup = isEnabled;
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
          const SizedBox(height: 14),

          // Launch at Startup toggle
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
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 18,
                      color: const Color(0xFF007AFF),
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
                            color:
                                isDark ? Colors.white : const Color(0xFF1D1D1F),
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

          // Clear history button
          if (widget.fileCount > 0) ...[
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                widget.onClearAll();
                Navigator.of(context).pop();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      'Clear Dropzone Items (${widget.fileCount})',
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
                'Dropzone for macOS • v0.1.0',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }
}
