import 'package:flutter/material.dart';

class HeaderBar extends StatelessWidget {
  final int fileCount;
  final VoidCallback onClearAll;
  final VoidCallback? onAddFiles;
  final VoidCallback? onOpenSettings;

  const HeaderBar({
    super.key,
    required this.fileCount,
    required this.onClearAll,
    this.onAddFiles,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          // App Logo / Icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.archive_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          // App Title
          Text(
            'Dropzone',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1D1D1F),
              letterSpacing: -0.2,
            ),
          ),
          if (fileCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$fileCount',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
          ],
          const Spacer(),
          // Add files "+" button
          if (onAddFiles != null) ...[
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              tooltip: 'Add files...',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.75)
                  : Colors.black.withValues(alpha: 0.75),
              onPressed: onAddFiles,
            ),
            const SizedBox(width: 2),
          ],
          // Clear all button if files present
          if (fileCount > 0) ...[
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onClearAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          // Settings button (⌘,)
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18),
            tooltip: 'Settings (⌘,)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black.withValues(alpha: 0.7),
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}
