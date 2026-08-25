import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

class StartupService {
  static final StartupService instance = StartupService._();
  StartupService._();

  static const MethodChannel _channel = MethodChannel('dropzone/startup');
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.appName.isEmpty ? 'dropzoneclone' : packageInfo.appName;
      launchAtStartup.setup(
        appName: appName,
        appPath: Platform.resolvedExecutable,
        packageName: packageInfo.packageName,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing launch_at_startup: $e');
    }
  }

  Future<bool> isEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLaunchAtStartupEnabled');
      if (result != null) return result;
    } catch (_) {}

    try {
      return await launchAtStartup.isEnabled();
    } catch (e) {
      debugPrint('Error checking startup status: $e');
      return false;
    }
  }

  Future<bool> setEnabled(bool enable) async {
    try {
      final result = await _channel.invokeMethod<bool>('setLaunchAtStartup', {'enable': enable});
      if (result != null) return result;
    } catch (_) {}

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
