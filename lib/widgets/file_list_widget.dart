import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import '../models/file_item.dart';
import '../services/tray_window_controller.dart';

class FileListWidget extends StatelessWidget {
  final List<FileItem> files;
  final Function(FileItem) onRemove;

  const FileListWidget({
    super.key,
    required this.files,
    required this.onRemove,
  });

  void _showFileNotFoundSnackBar(BuildContext context, String fileName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"$fileName" was moved, deleted, or no longer exists.',
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
      onRemove(item);
      _showFileNotFoundSnackBar(context, item.name);
      return;
    }
    if (Platform.isMacOS) {
      Process.run('open', [item.path]);
    }
  }

  void _revealInFinder(BuildContext context, FileItem item) {
    if (!item.exists) {
      onRemove(item);
      _showFileNotFoundSnackBar(context, item.name);
      return;
    }
    if (Platform.isMacOS) {
      Process.run('open', ['-R', item.path]);
    }
  }

  void _copyPath(BuildContext context, FileItem item) {
    if (!item.exists) {
      onRemove(item);
      _showFileNotFoundSnackBar(context, item.name);
      return;
    }
    Clipboard.setData(ClipboardData(text: item.path));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Path copied to clipboard',
          style: TextStyle(fontSize: 12),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (files.isEmpty) {
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = files[index];

        return DragItemWidget(
          dragItemProvider: (request) async {
            if (!item.exists) {
              onRemove(item);
              return null;
            }

            final session = request.session;
            TrayWindowController.instance.setDraggingOut(true);

            void onDragEnded() {
              if (!session.dragging.value) {
                session.dragging.removeListener(onDragEnded);
                TrayWindowController.instance.setDraggingOut(false);

                // If the file was moved or deleted by the destination app, remove it from shelf
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (!item.exists) {
                    onRemove(item);
                  }
                });
              }
            }

            session.dragging.addListener(onDragEnded);

            final dragItem = DragItem(
              localData: {'path': item.path},
            );

            // Add native macOS file URI format for Finder, Browser uploaders, Discord, Slack, etc.
            dragItem.add(Formats.fileUri(Uri.file(item.path)));
            // Also provide plain text path as fallback
            dragItem.add(Formats.plainText(item.path));

            return dragItem;
          },
          allowedOperations: () => [
            DropOperation.copy,
            DropOperation.move,
            DropOperation.link,
          ],
          child: DraggableWidget(
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Drag out handle indicator
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.25),
                      ),
                    ),
                    // File type icon badge
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: item.iconColor,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1D1D1F),
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
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.black.withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.3),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.path,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.4)
                                        : Colors.black.withValues(alpha: 0.4),
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
                              Icon(Icons.delete_outline_rounded,
                                  size: 15, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Remove from shelf',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.redAccent)),
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
                            onRemove(item);
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
    );
  }
}
