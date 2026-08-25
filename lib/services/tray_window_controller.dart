import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayWindowController with TrayListener, WindowListener {
  static final TrayWindowController instance = TrayWindowController._();
  TrayWindowController._();

  static const double windowWidth = 360.0;
  static const double windowHeight = 540.0;

  bool _isModalOpen = false;
  bool _isDraggingOut = false;
  bool _isInitialized = false;
  VoidCallback? onWindowShow;

  void setModalOpen(bool isOpen) {
    _isModalOpen = isOpen;
  }

  void setDraggingOut(bool isDragging) {
    _isDraggingOut = isDragging;
  }

  Future<void> init() async {
    if (_isInitialized) return;

    trayManager.addListener(this);
    windowManager.addListener(this);

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

    _isInitialized = true;
  }

  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    toggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'open_dropzone') {
      showWindow();
    } else if (menuItem.key == 'quit_app') {
      exit(0);
    }
  }

  @override
  void onWindowBlur() {
    // Dismiss window when user clicks outside, unless a system dialog (like file picker) or drag-out is active
    if (!_isModalOpen && !_isDraggingOut) {
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

  Future<void> hideWindow() async {
    await windowManager.hide();
  }

  Future<void> _positionWindowUnderTray() async {
    try {
      final trayBounds = await trayManager.getBounds();
      double targetX = 100.0;
      double targetY = 30.0;

      if (trayBounds != null) {
        final trayCenterX = trayBounds.left + (trayBounds.width / 2);
        targetX = trayCenterX - (windowWidth / 2);
        targetY = trayBounds.bottom + 6.0;
      }

      // Clamp targetX to visible primary screen if available
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

      await windowManager.setPosition(Offset(targetX, targetY));
    } catch (e) {
      debugPrint('Error positioning window under tray: $e');
    }
  }
}
