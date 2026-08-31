import 'dart:async';
import 'dart:ui';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'models/file_item.dart';
import 'services/shortcut_service.dart';
import 'services/startup_service.dart';
import 'services/tray_window_controller.dart';
import 'services/mouse_shake_detector.dart';
import 'services/preferences_service.dart';
import 'widgets/file_list_widget.dart';
import 'widgets/header_bar.dart';
import 'widgets/popover_container.dart';
import 'widgets/settings_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(
      TrayWindowController.windowWidth,
      TrayWindowController.windowHeight,
    ),
    minimumSize: Size(
      TrayWindowController.windowWidth,
      TrayWindowController.windowHeight,
    ),
    maximumSize: Size(
      TrayWindowController.windowWidth,
      TrayWindowController.windowHeight,
    ),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(true);
    await windowManager.setResizable(false);
    await windowManager.hide();
  });

  // Initialize Services
  await PreferencesService.instance.init();
  await StartupService.instance.init();
  await TrayWindowController.instance.init();
  await ShortcutService.instance.init();
  await MouseShakeDetector.instance.init();

  runApp(const DropzoneApp());
}

class DropzoneApp extends StatelessWidget {
  const DropzoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Drop Zone',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF007AFF),
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: '.AppleSystemUIFont',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF007AFF),
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: '.AppleSystemUIFont',
      ),
      home: const DropzoneHome(),
    );
  }
}

class DropzoneHome extends StatefulWidget {
  const DropzoneHome({super.key});

  @override
  State<DropzoneHome> createState() => _DropzoneHomeState();
}

class _DropzoneHomeState extends State<DropzoneHome>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FileListWidgetState> _fileListKey =
      GlobalKey<FileListWidgetState>();
  final List<FileItem> _files = [];
  Timer? _cleanupTimer;
  double _arrowOffset = TrayWindowController.windowWidth / 2;
  bool _isDragOverPopup = false;
  bool _isSettingsOpen = false;

  late AnimationController _openAnimController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _openAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: _openAnimController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _openAnimController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0.0, -0.04),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _openAnimController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _openAnimController.value = 1.0;

    _arrowOffset = TrayWindowController.instance.arrowOffset;

    TrayWindowController.instance.onArrowOffsetChanged = (offset) {
      if (mounted) {
        setState(() {
          _arrowOffset = offset;
        });
      }
    };

    TrayWindowController.instance.onWindowShow = () {
      _validateAndSyncFiles();
      _fileListKey.currentState?.clearSelection();
      if (mounted) {
        setState(() {
          _arrowOffset = TrayWindowController.instance.arrowOffset;
        });
      }
      _openAnimController.forward(from: 0.0);
    };

    TrayWindowController.instance.onAnimateOut = () async {
      if (_isSettingsOpen && mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        _isSettingsOpen = false;
      }
      await _openAnimController.reverse();
    };

    TrayWindowController.instance.onFilesReceivedFromTray = (paths) {
      final items = paths
          .where((p) => p.isNotEmpty)
          .map((p) => FileItem.fromPath(p))
          .toList();
      if (items.isNotEmpty) {
        _onFilesAdded(items);
      }
    };

    _cleanupTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _validateAndSyncFiles();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _openAnimController.dispose();
    super.dispose();
  }

  void _validateAndSyncFiles() {
    if (!mounted) return;
    final hasMissing = _files.any((f) => !f.exists);
    if (hasMissing) {
      setState(() {
        _files.removeWhere((f) => !f.exists);
      });
    }
  }

  void _onFilesAdded(List<FileItem> newFiles) {
    setState(() {
      for (final newFile in newFiles) {
        final existingIndex = _files.indexWhere((f) => f.path == newFile.path);
        if (existingIndex != -1) {
          _files.removeAt(existingIndex);
        }
        _files.insert(0, newFile);
      }
    });
  }

  void _onFileRemoved(FileItem item) {
    setState(() {
      _files.removeWhere((f) => f.path == item.path);
    });
  }

  void _onFilesRemoved(List<FileItem> items) {
    setState(() {
      final pathsToRemove = items.map((f) => f.path).toSet();
      _files.removeWhere((f) => pathsToRemove.contains(f.path));
    });
  }

  void _onClearAll() {
    setState(() {
      _files.clear();
    });
  }

  void _toggleSettings() {
    if (_isSettingsOpen) {
      _closeSettings();
    } else {
      _openSettings();
    }
  }

  void _closeSettings() {
    if (_isSettingsOpen && mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
      setState(() {
        _isSettingsOpen = false;
      });
    }
  }

  void _openSettings() async {
    if (_isSettingsOpen) return;
    setState(() {
      _isSettingsOpen = true;
    });

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          SettingsSheet(onClearAll: _onClearAll, fileCount: _files.length),
    );

    if (mounted) {
      setState(() {
        _isSettingsOpen = false;
      });
    }
  }

  Future<void> _pickFiles() async {
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
          _onFilesAdded(items);
        }
      }
    } finally {
      TrayWindowController.instance.setModalOpen(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final anchorFractionX = (_arrowOffset / TrayWindowController.windowWidth)
        .clamp(0.05, 0.95);
    final alignmentX = anchorFractionX * 2.0 - 1.0;

    final fillColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.88)
        : const Color(0xFFF7F7F8).withValues(alpha: 0.92);

    final borderColor = _isDragOverPopup
        ? const Color(0xFF007AFF)
        : (isDark
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.14));

    return CallbackShortcuts(
      bindings: {
        // Command + A: Select all items
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () {
          _fileListKey.currentState?.selectAll();
        },
        // Command + ,: Toggle Settings
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () {
          _toggleSettings();
        },
        // Escape: Close settings or clear selection
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSettingsOpen) {
            _closeSettings();
          } else {
            _fileListKey.currentState?.clearSelection();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DropTarget(
            onDragEntered: (_) {
              TrayWindowController.instance.setCursorInPopup(true);
              setState(() {
                _isDragOverPopup = true;
              });
            },
            onDragExited: (_) {
              TrayWindowController.instance.setCursorInPopup(false);
              setState(() {
                _isDragOverPopup = false;
              });
            },
            onDragDone: (details) {
              TrayWindowController.instance.resetAutoOpenedForDrag();
              TrayWindowController.instance.setCursorInPopup(false);
              setState(() {
                _isDragOverPopup = false;
              });
              final items = details.files
                  .where((f) => f.path.isNotEmpty)
                  .map((f) => FileItem.fromPath(f.path))
                  .toList();
              if (items.isNotEmpty) {
                _onFilesAdded(items);
              }
            },
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  alignment: Alignment(alignmentX, -1.0),
                  child: ClipPath(
                    clipper: PopoverClipper(
                      arrowOffset: _arrowOffset,
                      arrowWidth: 20.0,
                      arrowHeight: 10.0,
                      cornerRadius: 16.0,
                    ),
                    child: CustomPaint(
                      foregroundPainter: PopoverBorderPainter(
                        arrowOffset: _arrowOffset,
                        arrowWidth: 20.0,
                        arrowHeight: 10.0,
                        cornerRadius: 16.0,
                        borderColor: borderColor,
                        borderWidth: _isDragOverPopup ? 2.0 : 1.2,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          color: fillColor,
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Stack(
                            children: [
                              // Main Body: Header + Full-Height File Grid
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Header bar
                                  HeaderBar(
                                    fileCount: _files.length,
                                    onClearAll: _onClearAll,
                                    onAddFiles: _pickFiles,
                                    onOpenSettings: _toggleSettings,
                                  ),

                                  // Full height files grid
                                  Expanded(
                                    child: FileListWidget(
                                      key: _fileListKey,
                                      files: _files,
                                      onRemove: _onFileRemoved,
                                      onRemoveMultiple: _onFilesRemoved,
                                      onBrowseFiles: _pickFiles,
                                    ),
                                  ),
                                ],
                              ),

                              // Full-window drag-hover frosted overlay
                              if (_isDragOverPopup)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF007AFF,
                                        ).withValues(alpha: 0.16),
                                      ),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 4,
                                          sigmaY: 4,
                                        ),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(
                                                      0xFF1E1E1E,
                                                    ).withValues(alpha: 0.94)
                                                  : Colors.white.withValues(
                                                      alpha: 0.96,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.25),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF007AFF,
                                                ).withValues(alpha: 0.5),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.add_to_photos_rounded,
                                                  color: Color(0xFF007AFF),
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Drop files into shelf',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1D1D1F,
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
