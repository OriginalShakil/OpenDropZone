import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/file_item.dart';
import '../services/tray_window_controller.dart';

class FileListWidget extends StatefulWidget {
  final List<FileItem> files;
  final Function(FileItem) onRemove;
  final Function(List<FileItem>)? onRemoveMultiple;

  const FileListWidget({
    super.key,
    required this.files,
    required this.onRemove,
    this.onRemoveMultiple,
  });

  @override
  State<FileListWidget> createState() => _FileListWidgetState();
}

class _FileListWidgetState extends State<FileListWidget> {
  static const MethodChannel _dragOutChannel = MethodChannel('dropzone/drag_out');
  final Set<String> _selectedPaths = {};
  bool _isNativeDragging = false;

  @override
  void initState() {
    super.initState();
    _dragOutChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDragEnded') {
        _isNativeDragging = false;
        TrayWindowController.instance.setDraggingOut(false);
        final args = call.arguments as Map?;
        final draggedPaths = (args?['paths'] as List?)?.cast<String>() ?? _selectedPaths.toList();

        // Allow brief moment for Finder filesystem move to settle
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              for (final path in draggedPaths) {
                if (!File(path).existsSync() && !Directory(path).existsSync()) {
                  widget.files.removeWhere((f) => f.path == path);
                  _selectedPaths.remove(path);
                }
              }
            });
          }
        });
      }
    });
  }

  void _startNativeDrag(List<FileItem> items) async {
    if (_isNativeDragging) return;
    final validPaths = items.where((f) => f.exists).map((f) => f.path).toList();
    if (validPaths.isEmpty) return;

    _isNativeDragging = true;
    TrayWindowController.instance.setDraggingOut(true);

    try {
      await _dragOutChannel.invokeMethod('startDraggingFiles', {
        'paths': validPaths,
      });
    } catch (e) {
      debugPrint('Native drag error: $e');
      _isNativeDragging = false;
      TrayWindowController.instance.setDraggingOut(false);
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPaths.addAll(widget.files.map((f) => f.path));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPaths.clear();
    });
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 12),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _openFile(BuildContext context, FileItem item) {
    if (!item.exists) {
      widget.onRemove(item);
      _showToast(context, '"${item.name}" was moved or no longer exists.');
      return;
    }
    if (Platform.isMacOS) {
      Process.run('open', [item.path]);
    }
  }

  void _revealInFinder(BuildContext context, FileItem item) {
    if (!item.exists) {
      widget.onRemove(item);
      _showToast(context, '"${item.name}" was moved or no longer exists.');
      return;
    }
    if (Platform.isMacOS) {
      Process.run('open', ['-R', item.path]);
    }
  }

  void _copyPath(BuildContext context, FileItem item) {
    if (!item.exists) {
      widget.onRemove(item);
      _showToast(context, '"${item.name}" was moved or no longer exists.');
      return;
    }
    Clipboard.setData(ClipboardData(text: item.path));
    _showToast(context, 'Path copied to clipboard');
  }

  void _copySelectedPaths(BuildContext context) {
    final selectedFiles = widget.files
        .where((f) => _selectedPaths.contains(f.path) && f.exists)
        .toList();
    if (selectedFiles.isEmpty) return;

    final allPaths = selectedFiles.map((f) => f.path).join('\n');
    Clipboard.setData(ClipboardData(text: allPaths));
    _showToast(context, '${selectedFiles.length} file paths copied to clipboard');
  }

  void _removeSelected() {
    final selectedFiles = widget.files
        .where((f) => _selectedPaths.contains(f.path))
        .toList();
    if (widget.onRemoveMultiple != null) {
      widget.onRemoveMultiple!(selectedFiles);
    } else {
      for (final f in selectedFiles) {
        widget.onRemove(f);
      }
    }
    _clearSelection();
  }

  List<FileItem> _getItemsForDrag(FileItem currentItem) {
    if (_selectedPaths.contains(currentItem.path)) {
      final selected = widget.files
          .where((f) => _selectedPaths.contains(f.path) && f.exists)
          .toList();
      return selected.isNotEmpty ? selected : [currentItem];
    }
    return [currentItem];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Prune selection if files were removed
    final currentPaths = widget.files.map((f) => f.path).toSet();
    _selectedPaths.removeWhere((p) => !currentPaths.contains(p));

    if (widget.files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 36,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 8),
              Text(
                'No files stored in shelf yet',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.35),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Drop files above to hold and drag them out anytime',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.25),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final selectedCount = _selectedPaths.length;
    final selectedFiles = widget.files
        .where((f) => _selectedPaths.contains(f.path) && f.exists)
        .toList();

    return Column(
      children: [
        // Multi-Selection Action Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              // Select / Deselect All Button
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: selectedCount == widget.files.length
                    ? _clearSelection
                    : _selectAll,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        selectedCount == widget.files.length
                            ? Icons.check_box_rounded
                            : (selectedCount > 0
                                ? Icons.indeterminate_check_box_rounded
                                : Icons.check_box_outline_blank_rounded),
                        size: 14,
                        color: selectedCount > 0
                            ? const Color(0xFF007AFF)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.4)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedCount > 0
                            ? '$selectedCount selected'
                            : 'Select All',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selectedCount > 0
                              ? const Color(0xFF007AFF)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.black.withValues(alpha: 0.4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              if (selectedCount > 0) ...[
                // Copy Selected Paths
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  tooltip: 'Copy selected paths',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.6),
                  onPressed: () => _copySelectedPaths(context),
                ),
                const SizedBox(width: 4),
                // Remove Selected
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 15, color: Colors.redAccent),
                  tooltip: 'Remove selected from shelf',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: _removeSelected,
                ),
              ],
            ],
          ),
        ),

        // Multi-Item Batch Drag Handle (Shown when 2+ files selected)
        if (selectedCount >= 2)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Listener(
              onPointerMove: (event) {
                if (event.buttons == 1 && event.delta.distance > 2.0) {
                  _startNativeDrag(selectedFiles);
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF007AFF).withValues(alpha: 0.18),
                        const Color(0xFF5856D6).withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.drag_indicator_rounded,
                        size: 16,
                        color: Color(0xFF007AFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Drag all $selectedCount selected files out',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Files List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            itemCount: widget.files.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = widget.files[index];
              final isSelected = _selectedPaths.contains(item.path);
              final itemsToDrag = _getItemsForDrag(item);

              return Listener(
                onPointerMove: (event) {
                  if (event.buttons == 1 && event.delta.distance > 2.5) {
                    _startNativeDrag(itemsToDrag);
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _toggleSelection(item.path),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF007AFF).withValues(alpha: 0.12)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF007AFF)
                                  .withValues(alpha: 0.5)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          // Selection Checkbox
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: isSelected
                                  ? const Color(0xFF007AFF)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.2)),
                            ),
                          ),
                          // File type icon badge
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: item.iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.icon,
                              size: 17,
                              color: item.iconColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // File details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFF007AFF)
                                              : (isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1D1D1F)),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      item.formattedSize,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.5)
                                            : Colors.black
                                                .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    Text(
                                      ' • ',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.3)
                                            : Colors.black
                                                .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item.path,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.4)
                                              : Colors.black
                                                  .withValues(alpha: 0.4),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Actions menu
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              size: 18,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.black.withValues(alpha: 0.6),
                            ),
                            tooltip: 'File options',
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'open',
                                height: 32,
                                child: Row(
                                  children: [
                                    Icon(Icons.launch_rounded, size: 15),
                                    SizedBox(width: 8),
                                    Text('Open File',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'reveal',
                                height: 32,
                                child: Row(
                                  children: [
                                    Icon(Icons.folder_outlined, size: 15),
                                    SizedBox(width: 8),
                                    Text('Reveal in Finder',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'copy',
                                height: 32,
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_rounded, size: 15),
                                    SizedBox(width: 8),
                                    Text('Copy Path',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(height: 8),
                              const PopupMenuItem(
                                value: 'remove',
                                height: 32,
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 15, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Remove from shelf',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              switch (value) {
                                case 'open':
                                  _openFile(context, item);
                                  break;
                                case 'reveal':
                                  _revealInFinder(context, item);
                                  break;
                                case 'copy':
                                  _copyPath(context, item);
                                  break;
                                case 'remove':
                                  widget.onRemove(item);
                                  break;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
