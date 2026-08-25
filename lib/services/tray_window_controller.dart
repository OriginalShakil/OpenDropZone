import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayWindowController with TrayListener, WindowListener {
  static final TrayWindowController instance = TrayWindowController._();
  TrayWindowController._();

  static const double windowWidth = 360.0;
  static const double windowHeight = 540.0;

  static const MethodChannel _channel = MethodChannel('dropzone/tray_drag');

  bool _isModalOpen = false;
  bool _isDraggingOut = false;
  bool _isAutoOpenedForDrag = false;
  bool _isCursorInPopup = false;
  bool _isInitialized = false;

  Timer? _dragAutoCloseTimer;
  double arrowOffset = windowWidth / 2;
  Function(double)? onArrowOffsetChanged;
  VoidCallback? onWindowShow;
  Future<void> Function()? onAnimateOut;
  Function(List<String>)? onFilesReceivedFromTray;

  bool get isAutoOpenedForDrag => _isAutoOpenedForDrag;

  void setModalOpen(bool isOpen) {
    _isModalOpen = isOpen;
  }

  void setDraggingOut(bool isDragging) {
    _isDraggingOut = isDragging;
  }

  void setCursorInPopup(bool inside) {
    _isCursorInPopup = inside;
    if (inside) {
      _cancelDragAutoCloseTimer();
    } else {
      if (_isAutoOpenedForDrag) {
        _startDragAutoCloseTimer(const Duration(milliseconds: 350));
      }
    }
  }

  void resetAutoOpenedForDrag() {
    _isAutoOpenedForDrag = false;
    _cancelDragAutoCloseTimer();
  }

  void _cancelDragAutoCloseTimer() {
    _dragAutoCloseTimer?.cancel();
    _dragAutoCloseTimer = null;
  }

  void _startDragAutoCloseTimer(Duration delay) {
    _cancelDragAutoCloseTimer();
    _dragAutoCloseTimer = Timer(delay, () async {
      if (_isAutoOpenedForDrag && !_isCursorInPopup) {
        _isAutoOpenedForDrag = false;
        await hideWindow();
      }
    });
  }

  Future<void> init() async {
    if (_isInitialized) return;

    trayManager.addListener(this);
    windowManager.addListener(this);

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTrayDragEntered') {
        _cancelDragAutoCloseTimer();
        _isAutoOpenedForDrag = true;
        await showWindow();
      } else if (call.method == 'onTrayDragExited') {
        if (_isAutoOpenedForDrag && !_isCursorInPopup) {
          _startDragAutoCloseTimer(const Duration(milliseconds: 400));
        }
      } else if (call.method == 'onFilesDroppedOnTray') {
        final args = call.arguments as Map?;
        final paths = (args?['paths'] as List?)?.cast<String>() ?? [];
        if (paths.isNotEmpty) {
          _isAutoOpenedForDrag = false;
          _cancelDragAutoCloseTimer();
          onFilesReceivedFromTray?.call(paths);
          await showWindow();
        }
      }
    });

    final iconPath = Platform.isMacOS
        ? 'assets/icons/tray_icon_template.png'
        : 'assets/icons/tray_icon.png';

    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('Dropzone');

    final menu = Menu(
      items: [
        MenuItem(
          key: 'open_dropzone',
          label: 'Open Dropzone',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit_app',
          label: 'Quit Dropzone',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);

    try {
      await _channel.invokeMethod('registerTrayButton');
    } catch (_) {}

    _isInitialized = true;
  }

  void dispose() {
    _cancelDragAutoCloseTimer();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    _isAutoOpenedForDrag = false;
    _cancelDragAutoCloseTimer();
    toggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'open_dropzone') {
      _isAutoOpenedForDrag = false;
      _cancelDragAutoCloseTimer();
      showWindow();
    } else if (menuItem.key == 'quit_app') {
      exit(0);
    }
  }

  @override
  void onWindowBlur() {
    // Dismiss window when user clicks outside, unless a system dialog (like file picker) or drag-out is active
    if (!_isModalOpen && !_isDraggingOut) {
      _isAutoOpenedForDrag = false;
      _cancelDragAutoCloseTimer();
      hideWindow();
    }
  }

  Future<void> toggleWindow() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await hideWindow();
    } else {
      await showWindow();
    }
  }

  Future<void> showWindow() async {
    onWindowShow?.call();
    await _positionWindowUnderTray();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWindow({bool animated = true}) async {
    _cancelDragAutoCloseTimer();
    if (animated && onAnimateOut != null) {
      try {
        await onAnimateOut!.call();
      } catch (_) {}
    }
    await windowManager.hide();
  }

  Future<void> _positionWindowUnderTray() async {
    try {
      final trayBounds = await trayManager.getBounds();
      double targetX = 100.0;
      double targetY = 24.0;
      double computedOffset = windowWidth / 2;

      if (trayBounds != null) {
        final trayCenterX = trayBounds.left + (trayBounds.width / 2);
        targetX = trayCenterX - (windowWidth / 2);
        targetY = trayBounds.bottom - 1.0;

        try {
          final display = await screenRetriever.getPrimaryDisplay();
          final screenWidth = display.size.width;
          if (targetX + windowWidth > screenWidth - 10) {
            targetX = screenWidth - windowWidth - 10;
          }
          if (targetX < 10) {
            targetX = 10;
          }
        } catch (_) {
          // Fallback positioning if screen retrieval fails
        }

        computedOffset = (trayCenterX - targetX).clamp(36.0, windowWidth - 36.0);
      }

      arrowOffset = computedOffset;
      onArrowOffsetChanged?.call(arrowOffset);

      await windowManager.setPosition(Offset(targetX, targetY));
    } catch (e) {
      debugPrint('Error positioning window under tray: $e');
    }
  }
}
