import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Make NSWindow fully transparent with no black background box
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true

    RegisterGeneratedPlugins(registry: flutterViewController)
    TrayDragBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger)
    StartupBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

class StartupBridge: NSObject {
  static let shared = StartupBridge()
  private var channel: FlutterMethodChannel?

  func setup(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "dropzone/startup", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "setLaunchAtStartup" {
        let enable = (call.arguments as? [String: Any])?["enable"] as? Bool ?? false
        let success = self.setLaunchAtStartup(enabled: enable)
        result(success)
      } else if call.method == "isLaunchAtStartupEnabled" {
        result(self.isLaunchAtStartupEnabled())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func setLaunchAtStartup(enabled: Bool) -> Bool {
    if #available(macOS 13.0, *) {
      do {
        if enabled {
          if SMAppService.mainApp.status != .enabled {
            try SMAppService.mainApp.register()
          }
        } else {
          if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
          }
        }
        let isEnabled = SMAppService.mainApp.status == .enabled
        if isEnabled == enabled {
          return isEnabled
        }
        return fallbackSetLoginItem(enabled: enabled)
      } catch {
        print("SMAppService error, using fallback: \(error)")
        return fallbackSetLoginItem(enabled: enabled)
      }
    } else {
      return fallbackSetLoginItem(enabled: enabled)
    }
  }

  func isLaunchAtStartupEnabled() -> Bool {
    if #available(macOS 13.0, *) {
      if SMAppService.mainApp.status == .enabled {
        return true
      }
    }
    return fallbackIsLoginItemEnabled()
  }

  private func fallbackSetLoginItem(enabled: Bool) -> Bool {
    let bundlePath = Bundle.main.bundlePath
    let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "dropzoneclone"
    if enabled {
      let script = "tell application \"System Events\" to make login item at end with properties {path:\"\(bundlePath)\", hidden:false, name:\"\(appName)\"}"
      _ = executeAppleScript(script)
    } else {
      let script = "tell application \"System Events\" to delete (every login item whose name is \"\(appName)\")"
      _ = executeAppleScript(script)
    }
    return fallbackIsLoginItemEnabled()
  }

  private func fallbackIsLoginItemEnabled() -> Bool {
    let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "dropzoneclone"
    let script = "tell application \"System Events\" to get name of every login item"
    if let result = executeAppleScript(script) {
      return result.contains(appName)
    }
    return false
  }

  private func executeAppleScript(_ script: String) -> String? {
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
      let output = scriptObject.executeAndReturnError(&error)
      if error == nil {
        return output.stringValue ?? "true"
      }
    }
    return nil
  }
}

class TrayDragBridge: NSObject {
  static let shared = TrayDragBridge()
  private var channel: FlutterMethodChannel?

  func setup(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "dropzone/tray_drag", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "registerTrayButton" {
        self?.scanAndRegisterStatusBarButtons()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.scanAndRegisterStatusBarButtons()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      self.scanAndRegisterStatusBarButtons()
    }
  }

  func scanAndRegisterStatusBarButtons() {
    for window in NSApp.windows {
      if let button = findStatusBarButton(in: window.contentView) {
        button.registerForDraggedTypes([.fileURL])
      }
    }
  }

  private func findStatusBarButton(in view: NSView?) -> NSStatusBarButton? {
    guard let view = view else { return nil }
    if let btn = view as? NSStatusBarButton {
      return btn
    }
    for subview in view.subviews {
      if let found = findStatusBarButton(in: subview) {
        return found
      }
    }
    return nil
  }

  func handleTrayDragEntered(button: NSStatusBarButton) {
    guard let window = button.window else { return }
    let screenRect = window.convertToScreen(button.frame)
    channel?.invokeMethod("onTrayDragEntered", arguments: [
      "x": screenRect.origin.x,
      "y": screenRect.origin.y,
      "width": screenRect.size.width,
      "height": screenRect.size.height
    ])
  }

  func handleTrayDragExited() {
    channel?.invokeMethod("onTrayDragExited", arguments: nil)
  }

  func handleFilesDropped(paths: [String]) {
    channel?.invokeMethod("onFilesDroppedOnTray", arguments: ["paths": paths])
  }
}

extension NSStatusBarButton {
  open override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    self.registerForDraggedTypes([.fileURL])
  }

  open override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    return true
  }

  open override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
    TrayDragBridge.shared.handleTrayDragEntered(button: self)
    return .copy
  }

  open override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
    return .copy
  }

  open override func draggingExited(_ sender: (any NSDraggingInfo)?) {
    TrayDragBridge.shared.handleTrayDragExited()
  }

  open override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    let pasteboard = sender.draggingPasteboard
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
      let paths = urls.map { $0.path }
      TrayDragBridge.shared.handleFilesDropped(paths: paths)
      return true
    }
    return false
  }
}
