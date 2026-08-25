import Cocoa
import FlutterMacOS

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

    super.awakeFromNib()
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
