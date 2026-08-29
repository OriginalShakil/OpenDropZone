import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/file_item.dart';
import '../services/tray_window_controller.dart';
import '../services/mouse_shake_detector.dart';

class FileListWidget extends StatefulWidget {
  final List<FileItem> files;
  final Function(FileItem) onRemove;
  final Function(List<FileItem>)? onRemoveMultiple;
  final VoidCallback? onBrowseFiles;

  const FileListWidget({
    super.key,
    required this.files,
    required this.onRemove,
    this.onRemoveMultiple,
    this.onBrowseFiles,
  });

  @override
  State<FileListWidget> createState() => FileListWidgetState();
}

class FileListWidgetState extends State<FileListWidget> {
  static const MethodChannel _dragOutChannel = MethodChannel(
    'dropzone/drag_out',
  );
  static const MethodChannel _iconChannel = MethodChannel('dropzone/file_icon');
  static final Map<String, Uint8List> _iconCache = {};

  final Set<String> _selectedPaths = {};
  bool _isNativeDragging = false;

  // Marquee Selection State
  final GlobalKey _gridAreaKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = {};
  Offset? _marqueeStart;
  Offset? _marqueeCurrent;
  bool _isMarqueeActive = false;

  @override
  void initState() {
    super.initState();
    _dragOutChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDragEnded') {
        _isNativeDragging = false;
        TrayWindowController.instance.setDraggingOut(false);

        // Stop mouse shake detection when drag ends
        MouseShakeDetector.instance.stopMonitoring();

        final args = call.arguments as Map?;
        final draggedPaths =
            (args?['paths'] as List?)?.cast<String>() ??
            _selectedPaths.toList();

        // Allow brief moment for Finder filesystem move to settle
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              for (final path in draggedPaths) {
                if (!File(path).existsSync() && !Directory(path).existsSync()) {
                  widget.files.removeWhere((f) => f.path == path);
                  _selectedPaths.remove(path);
                  _iconCache.remove(path);
                }
              }
            });
          }
        });
      }
    });

    _preloadIcons();
  }

  @override
  void didUpdateWidget(covariant FileListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _preloadIcons();
  }

  void _preloadIcons() async {
    final missingPaths = widget.files
        .map((f) => f.path)
        .where((p) => !_iconCache.containsKey(p))
        .toList();

    if (missingPaths.isEmpty) return;

    try {
      final result = await _iconChannel.invokeMethod<Map>('getFileIcons', {
        'paths': missingPaths,
        'size': 128.0,
      });

      if (result != null && mounted) {
        setState(() {
          result.forEach((key, value) {
            if (value is Uint8List) {
              _iconCache[key as String] = value;
            }
          });
        });
      }
    } catch (_) {}
  }

  Future<Uint8List?> _fetchIcon(String path) async {
    if (_iconCache.containsKey(path)) {
      return _iconCache[path];
    }
    try {
      final bytes = await _iconChannel.invokeMethod<Uint8List>('getFileIcon', {
        'path': path,
        'size': 128.0,
      });
      if (bytes != null) {
        _iconCache[path] = bytes;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _startNativeDrag(List<FileItem> items) async {
    if (_isNativeDragging || _isMarqueeActive) return;
    final validPaths = items.where((f) => f.exists).map((f) => f.path).toList();
    if (validPaths.isEmpty) return;

    debugPrint('🚀 Starting native drag with ${validPaths.length} file(s)');

    _isNativeDragging = true;
    TrayWindowController.instance.setDraggingOut(true);

    // Start mouse shake detection
    MouseShakeDetector.instance.onShakeDetected = () {
      debugPrint('🎊 Shake detected callback! Opening window...');
      // Open the popup when shake is detected
      TrayWindowController.instance.showWindow();
    };
    await MouseShakeDetector.instance.startMonitoring();

    try {
      await _dragOutChannel.invokeMethod('startDraggingFiles', {
        'paths': validPaths,
      });
    } catch (e) {
      debugPrint('Native drag error: $e');
      _isNativeDragging = false;
      TrayWindowController.instance.setDraggingOut(false);
      MouseShakeDetector.instance.stopMonitoring();
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

  void selectAll() {
    setState(() {
      _selectedPaths.addAll(widget.files.map((f) => f.path));
    });
  }

  void clearSelection() {
    setState(() {
      _selectedPaths.clear();
    });
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _openFile(FileItem item) {
    if (!item.exists) {
      widget.onRemove(item);
      _showToast('"${item.name}" was moved or no longer exists.');
      return;
    }
    if (Platform.isMacOS) {
      Process.run('open', [item.path]);
    }
  }

  void _revealInFinder(FileItem item) {
    if (!item.exists) {
      widget.onRemove(item);
      _showToast('"${item.name}" was moved or no longer exists.');
      return;
    }
    if (Platform.isMacOS) {
      Process.run('open', ['-R', item.path]);
    }
  }

  void _copyPath(FileItem item) {
    if (!item.exists) {
      widget.onRemove(item);
      _showToast('"${item.name}" was moved or no longer exists.');
      return;
    }
    Clipboard.setData(ClipboardData(text: item.path));
    _showToast('Path copied to clipboard');
  }

  void _copySelectedPaths() {
    final selectedFiles = widget.files
        .where((f) => _selectedPaths.contains(f.path) && f.exists)
        .toList();
    if (selectedFiles.isEmpty) return;

    final allPaths = selectedFiles.map((f) => f.path).join('\n');
    Clipboard.setData(ClipboardData(text: allPaths));
    _showToast('${selectedFiles.length} file paths copied to clipboard');
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
    clearSelection();
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

  void _showContextMenu(
    BuildContext context,
    Offset globalPosition,
    FileItem item,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final value = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        const PopupMenuItem(
          value: 'open',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.launch_rounded, size: 15),
              SizedBox(width: 8),
              Text('Open File', style: TextStyle(fontSize: 12)),
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
              Text('Reveal in Finder', style: TextStyle(fontSize: 12)),
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
              Text('Copy Path', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        const PopupMenuItem(
          value: 'remove',
          height: 32,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 15,
                color: Colors.redAccent,
              ),
              SizedBox(width: 8),
              Text(
                'Remove from shelf',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ],
    );

    if (!mounted || value == null) return;
    switch (value) {
      case 'open':
        _openFile(item);
        break;
      case 'reveal':
        _revealInFinder(item);
        break;
      case 'copy':
        _copyPath(item);
        break;
      case 'remove':
        widget.onRemove(item);
        break;
    }
  }

  // --- Marquee Selection Logic ---
  void _onMarqueeStart(DragStartDetails details) {
    final gridBox =
        _gridAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return;
    final localPos = gridBox.globalToLocal(details.globalPosition);

    setState(() {
      _marqueeStart = localPos;
      _marqueeCurrent = localPos;
      _isMarqueeActive = true;
    });
  }

  void _onMarqueeUpdate(DragUpdateDetails details) {
    if (!_isMarqueeActive || _marqueeStart == null) return;
    final gridBox =
        _gridAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return;
    final localPos = gridBox.globalToLocal(details.globalPosition);

    setState(() {
      _marqueeCurrent = localPos;
      _updateMarqueeIntersections(gridBox);
    });
  }

  void _onMarqueeEnd(DragEndDetails details) {
    setState(() {
      _isMarqueeActive = false;
      _marqueeStart = null;
      _marqueeCurrent = null;
    });
  }

  void _updateMarqueeIntersections(RenderBox gridBox) {
    if (_marqueeStart == null || _marqueeCurrent == null) return;
    final marqueeRect = Rect.fromPoints(_marqueeStart!, _marqueeCurrent!);

    final newlySelected = <String>{};
    for (final file in widget.files) {
      final key = _itemKeys[file.path];
      final itemBox = key?.currentContext?.findRenderObject() as RenderBox?;
      if (itemBox != null && itemBox.attached) {
        final itemTopLeft = itemBox.localToGlobal(
          Offset.zero,
          ancestor: gridBox,
        );
        final itemRect = itemTopLeft & itemBox.size;
        if (marqueeRect.overlaps(itemRect)) {
          newlySelected.add(file.path);
        }
      }
    }

    _selectedPaths
      ..clear()
      ..addAll(newlySelected);
  }

  Widget _buildNativeIconPreview(FileItem item, bool isDark) {
    if (item.isImage && item.exists) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(item.path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, error, stackTrace) => _buildMemoryOrFallback(item),
        ),
      );
    }

    return _buildMemoryOrFallback(item);
  }

  Widget _buildMemoryOrFallback(FileItem item) {
    if (_iconCache.containsKey(item.path)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Image.memory(
            _iconCache[item.path]!,
            fit: BoxFit.contain,
            width: 54,
            height: 54,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, error, stackTrace) => _buildFallbackIcon(item),
          ),
        ),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _fetchIcon(item.path),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                width: 54,
                height: 54,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, error, stackTrace) =>
                    _buildFallbackIcon(item),
              ),
            ),
          );
        }
        return _buildFallbackIcon(item);
      },
    );
  }

  Widget _buildFallbackIcon(FileItem item) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: item.iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icon, size: 24, color: item.iconColor),
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 30,
                  color: Color(0xFF007AFF),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Drop files anywhere to store',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Drag any files, images, or folders into this window to hold and use them anytime',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.onBrowseFiles != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: widget.onBrowseFiles,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    foregroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF1D1D1F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text(
                    'Browse files...',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
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
                    ? clearSelection
                    : selectAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
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
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.6),
                  onPressed: _copySelectedPaths,
                ),
                const SizedBox(width: 4),
                // Remove Selected
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Remove selected from shelf',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
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
                // Track mouse position for shake detection
                if (_isNativeDragging) {
                  MouseShakeDetector.instance.updateMousePosition(
                    event.position,
                  );
                }

                if (event.buttons == 1 && event.delta.distance > 2.0) {
                  _startNativeDrag(selectedFiles);
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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

        // Marquee-Enabled Finder Icon Grid View
        Expanded(
          child: GestureDetector(
            key: _gridAreaKey,
            behavior: HitTestBehavior.translucent,
            onPanStart: _onMarqueeStart,
            onPanUpdate: _onMarqueeUpdate,
            onPanEnd: _onMarqueeEnd,
            onTap: clearSelection,
            child: Stack(
              children: [
                // Grid of icons
                GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: widget.files.length,
                  itemBuilder: (context, index) {
                    final item = widget.files[index];
                    final isSelected = _selectedPaths.contains(item.path);
                    final itemsToDrag = _getItemsForDrag(item);

                    // Maintain GlobalKey for intersection testing
                    final itemKey = _itemKeys.putIfAbsent(
                      item.path,
                      () => GlobalKey(),
                    );

                    return KeyedSubtree(
                      key: itemKey,
                      child: Tooltip(
                        message: '${item.name}\n${item.formattedSize}',
                        waitDuration: const Duration(milliseconds: 350),
                        child: Listener(
                          onPointerMove: (event) {
                            // Track mouse position for shake detection
                            if (_isNativeDragging) {
                              MouseShakeDetector.instance.updateMousePosition(
                                event.position,
                              );
                            }

                            if (!_isMarqueeActive &&
                                event.buttons == 1 &&
                                event.delta.distance > 2.5) {
                              _startNativeDrag(itemsToDrag);
                            }
                          },
                          child: GestureDetector(
                            onSecondaryTapUp: (details) => _showContextMenu(
                              context,
                              details.globalPosition,
                              item,
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _toggleSelection(item.path),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(
                                            0xFF007AFF,
                                          ).withValues(alpha: 0.16)
                                        : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.03,
                                                )),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF007AFF)
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.08,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.06,
                                                  )),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF007AFF,
                                              ).withValues(alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Column(
                                    children: [
                                      // Native Finder App / File Icon Preview
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: _buildNativeIconPreview(
                                                item,
                                                isDark,
                                              ),
                                            ),

                                            // Selection Indicator Checkmark in top-right corner
                                            if (isSelected)
                                              Positioned(
                                                top: 0,
                                                right: 0,
                                                child: Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Color(
                                                          0xFF007AFF,
                                                        ),
                                                      ),
                                                  child: const Icon(
                                                    Icons.check_rounded,
                                                    size: 13,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // File name title
                                      const SizedBox(height: 4),
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.85,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.75,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Rubber-Band Marquee Selection Box Overlay
                if (_isMarqueeActive &&
                    _marqueeStart != null &&
                    _marqueeCurrent != null)
                  Positioned.fromRect(
                    rect: Rect.fromPoints(_marqueeStart!, _marqueeCurrent!),
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF007AFF,
                          ).withValues(alpha: 0.16),
                          border: Border.all(
                            color: const Color(
                              0xFF007AFF,
                            ).withValues(alpha: 0.85),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
