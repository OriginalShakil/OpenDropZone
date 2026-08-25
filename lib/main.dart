import 'dart:async';
import 'dart:ui';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'models/file_item.dart';
import 'services/startup_service.dart';
import 'services/tray_window_controller.dart';
import 'widgets/drop_zone_widget.dart';
import 'widgets/file_list_widget.dart';
import 'widgets/header_bar.dart';
import 'widgets/popover_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(TrayWindowController.windowWidth, TrayWindowController.windowHeight),
    minimumSize: Size(TrayWindowController.windowWidth, TrayWindowController.windowHeight),
    maximumSize: Size(TrayWindowController.windowWidth, TrayWindowController.windowHeight),
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
  await StartupService.instance.init();
  await TrayWindowController.instance.init();

  runApp(const DropzoneApp());
}

class DropzoneApp extends StatelessWidget {
  const DropzoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dropzone',
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
  final List<FileItem> _files = [];
  Timer? _cleanupTimer;
  double _arrowOffset = TrayWindowController.windowWidth / 2;

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

    _slideAnimation = Tween<Offset>(
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
      if (mounted) {
        setState(() {
          _arrowOffset = TrayWindowController.instance.arrowOffset;
        });
      }
      _openAnimController.forward(from: 0.0);
    };

    TrayWindowController.instance.onAnimateOut = () async {
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
        _files.removeWhere((file) => !file.exists);
      });
    }
  }

  void _onFilesAdded(List<FileItem> newItems) {
    setState(() {
      for (final item in newItems) {
        if (item.exists) {
          // Prevent duplicate entries
          _files.removeWhere((f) => f.path == item.path);
          _files.insert(0, item);
        }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final anchorFractionX = (_arrowOffset / TrayWindowController.windowWidth).clamp(0.05, 0.95);
    final alignmentX = anchorFractionX * 2.0 - 1.0;

    final fillColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.88)
        : const Color(0xFFF7F7F8).withValues(alpha: 0.92);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.14);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DropTarget(
        onDragEntered: (_) =>
            TrayWindowController.instance.setCursorInPopup(true),
        onDragExited: (_) =>
            TrayWindowController.instance.setCursorInPopup(false),
        onDragDone: (details) {
          TrayWindowController.instance.resetAutoOpenedForDrag();
          TrayWindowController.instance.setCursorInPopup(false);
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
                    borderWidth: 1.2,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: fillColor,
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header bar
                          HeaderBar(
                            fileCount: _files.length,
                            onClearAll: _onClearAll,
                          ),

                          // Drop zone container
                          DropZoneWidget(
                            onFilesAdded: _onFilesAdded,
                          ),

                          // Recent files title / count header
                          if (_files.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'FILE SHELF (DRAG OUT TO USE)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : Colors.black.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  Text(
                                    '${_files.length} ${_files.length == 1 ? "item" : "items"}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : Colors.black.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Files list
                          Expanded(
                            child: FileListWidget(
                              files: _files,
                              onRemove: _onFileRemoved,
                              onRemoveMultiple: _onFilesRemoved,
                            ),
                          ),

                          // Subtle bottom footer bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.4),
                              border: Border(
                                top: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 13,
                                  color: const Color(0xFF007AFF),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Drag items directly out to Finder, Browser, or Apps',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : Colors.black.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
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
    );
  }
}
