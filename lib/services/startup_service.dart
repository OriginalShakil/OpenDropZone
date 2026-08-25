import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

class StartupService {
  static final StartupService instance = StartupService._();
  StartupService._();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.appName.isEmpty ? 'Dropzone' : packageInfo.appName;
      launchAtStartup.setup(
        appName: appName,
        appPath: Platform.resolvedExecutable,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing launch_at_startup: $e');
    }
  }

  Future<bool> isEnabled() async {
    try {
      return await launchAtStartup.isEnabled();
    } catch (e) {
      debugPrint('Error checking startup status: $e');
      return false;
    }
  }

  Future<bool> setEnabled(bool enable) async {
    try {
      if (enable) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      return await isEnabled();
    } catch (e) {
      debugPrint('Error setting startup status: $e');
      return false;
    }
  }
}
