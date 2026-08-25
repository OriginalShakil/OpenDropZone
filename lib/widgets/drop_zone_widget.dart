import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/tray_window_controller.dart';

class DropZoneWidget extends StatefulWidget {
  final Function(List<FileItem>) onFilesAdded;

  const DropZoneWidget({
    super.key,
    required this.onFilesAdded,
  });

  @override
  State<DropZoneWidget> createState() => _DropZoneWidgetState();
}

class _DropZoneWidgetState extends State<DropZoneWidget>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onDragEntered() {
    TrayWindowController.instance.setCursorInPopup(true);
    setState(() {
      _isDragging = true;
    });
    _pulseController.repeat(reverse: true);
  }

  void _onDragExited() {
    TrayWindowController.instance.setCursorInPopup(false);
    setState(() {
      _isDragging = false;
    });
    _pulseController.stop();
    _pulseController.reset();
  }

  void _onDragDone(DropDoneDetails details) {
    TrayWindowController.instance.resetAutoOpenedForDrag();
    TrayWindowController.instance.setCursorInPopup(false);
    _onDragExited();
    final items = details.files
        .where((file) => file.path.isNotEmpty)
        .map((file) => FileItem.fromPath(file.path))
        .toList();

    if (items.isNotEmpty) {
      widget.onFilesAdded(items);
    }
  }

  Future<void> _pickFiles() async {
    // Notify controller to avoid closing window when file picker dialog opens
    TrayWindowController.instance.setModalOpen(true);
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.paths.isNotEmpty) {
        final items = result.paths
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .map((path) => FileItem.fromPath(path))
            .toList();

        if (items.isNotEmpty) {
          widget.onFilesAdded(items);
        }
      }
    } finally {
      // Re-enable window blur dismissal after file picker is closed
      TrayWindowController.instance.setModalOpen(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeBorderColor = const Color(0xFF007AFF);
    final inactiveBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.15);

    final activeBgColor = isDark
        ? const Color(0xFF007AFF).withValues(alpha: 0.14)
        : const Color(0xFF007AFF).withValues(alpha: 0.08);

    final inactiveBgColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.02);

    return DropTarget(
      onDragEntered: (_) => _onDragEntered(),
      onDragExited: (_) => _onDragExited(),
      onDragDone: _onDragDone,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: _isDragging ? _scaleAnimation.value : 1.0,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: _isDragging ? activeBgColor : inactiveBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDragging ? activeBorderColor : inactiveBorderColor,
              width: _isDragging ? 2.0 : 1.5,
              strokeAlign: BorderSide.strokeAlignCenter,
            ),
            boxShadow: _isDragging
                ? [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDragging
                      ? const Color(0xFF007AFF)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05)),
                ),
                child: Icon(
                  _isDragging
                      ? Icons.file_download_rounded
                      : Icons.cloud_upload_outlined,
                  size: 28,
                  color: _isDragging
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF1D1D1F)),
                ),
              ),
              const SizedBox(height: 10),
              // Main text
              Text(
                _isDragging ? 'Release to drop files' : 'Drop files here',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isDragging
                      ? const Color(0xFF007AFF)
                      : (isDark ? Colors.white : const Color(0xFF1D1D1F)),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Add any files, images, or folders',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 12),
              // Fallback Browse files button
              TextButton.icon(
                onPressed: _pickFiles,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF1D1D1F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: const Text(
                  'Browse files...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
