import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'models/file_item.dart';
import 'services/startup_service.dart';
import 'services/tray_window_controller.dart';
import 'widgets/drop_zone_widget.dart';
import 'widgets/file_list_widget.dart';
import 'widgets/header_bar.dart';

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

class _DropzoneHomeState extends State<DropzoneHome> {
  final List<FileItem> _files = [];
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    TrayWindowController.instance.onWindowShow = _validateAndSyncFiles;
    _cleanupTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _validateAndSyncFiles();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
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

  void _onClearAll() {
    setState(() {
      _files.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E).withValues(alpha: 0.94)
              : const Color(0xFFF6F6F6).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ),
              ),

              // Subtle bottom footer bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      color: isDark
                          ? const Color(0xFF007AFF)
                          : const Color(0xFF007AFF),
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
    );
  }
}
