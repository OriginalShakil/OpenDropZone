import Cocoa
import FlutterMacOS
import ServiceManagement
import QuickLookThumbnailing
import AVFoundation

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
    NativeDragOutBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger, window: self)
    FileIconBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

class FileIconBridge: NSObject {
  static let shared = FileIconBridge()
  private var channel: FlutterMethodChannel?

  func setup(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "dropzone/file_icon", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "getFileIcon" {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(nil)
          return
        }
        let size = CGFloat((args["size"] as? Double) ?? 128.0)
        self.generateThumbnail(path: path, size: size) { data in
          result(data)
        }
      } else if call.method == "getFileIcons" {
        guard let args = call.arguments as? [String: Any],
              let paths = args["paths"] as? [String] else {
          result([:])
          return
        }
        let size = CGFloat((args["size"] as? Double) ?? 128.0)
        self.generateThumbnails(paths: paths, size: size) { dict in
          result(dict)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func generateThumbnails(paths: [String], size: CGFloat, completion: @escaping ([String: FlutterStandardTypedData]) -> Void) {
    let group = DispatchGroup()
    var results: [String: FlutterStandardTypedData] = [:]
    let lock = NSLock()

    for path in paths {
      group.enter()
      generateThumbnail(path: path, size: size) { data in
        if let data = data {
          lock.lock()
          results[path] = FlutterStandardTypedData(bytes: data)
          lock.unlock()
        }
        group.leave()
      }
    }

    group.notify(queue: .main) {
      completion(results)
    }
  }

  func generateThumbnail(path: String, size: CGFloat, completion: @escaping (Data?) -> Void) {
    guard FileManager.default.fileExists(atPath: path) else {
      completion(nil)
      return
    }

    let url = URL(fileURLWithPath: path)
    let ext = url.pathExtension.lowercased()

    // 1. Direct fast load for images (PNG, JPG, JPEG, WEBP, GIF, HEIC, TIFF, BMP, ICO)
    let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "tif", "bmp", "ico"]
    if imageExtensions.contains(ext) {
      if let image = NSImage(contentsOfFile: path) {
        if let pngData = self.resizeAndConvertToPNG(image: image, targetSize: NSSize(width: size, height: size)) {
          completion(pngData)
          return
        }
      }
    }

    // 2. Video thumbnail generation for video files (MP4, MOV, M4V, MKV, AVI, WEBM)
    let videoExtensions = ["mp4", "mov", "m4v", "mkv", "avi", "webm"]
    if videoExtensions.contains(ext) {
      DispatchQueue.global(qos: .userInitiated).async {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: size * 2, height: size * 2)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        do {
          let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
          let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
          if let pngData = self.resizeAndConvertToPNG(image: nsImage, targetSize: NSSize(width: size, height: size)) {
            DispatchQueue.main.async {
              completion(pngData)
            }
            return
          }
        } catch {
          // Fallback to QuickLook
        }

        DispatchQueue.main.async {
          self.quickLookOrSystemIcon(url: url, path: path, size: size, completion: completion)
        }
      }
      return
    }

    // 3. For all other files (PDF, docx, apps, folders), use QuickLook thumbnail or system icon
    quickLookOrSystemIcon(url: url, path: path, size: size, completion: completion)
  }

  private func quickLookOrSystemIcon(url: URL, path: String, size: CGFloat, completion: @escaping (Data?) -> Void) {
    if #available(macOS 10.15, *) {
      let request = QLThumbnailGenerator.Request(
        fileAt: url,
        size: CGSize(width: size, height: size),
        scale: NSScreen.main?.backingScaleFactor ?? 2.0,
        representationTypes: .all
      )

      QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] (thumbnail, error) in
        guard let self = self else { return }
        if let thumbnail = thumbnail {
          let nsImage = NSImage(cgImage: thumbnail.cgImage, size: NSSize(width: size, height: size))
          if let pngData = self.resizeAndConvertToPNG(image: nsImage, targetSize: NSSize(width: size, height: size)) {
            DispatchQueue.main.async {
              completion(pngData)
            }
            return
          }
        }
        DispatchQueue.main.async {
          completion(self.getSystemIcon(path: path, size: size))
        }
      }
    } else {
      completion(getSystemIcon(path: path, size: size))
    }
  }

  private func getSystemIcon(path: String, size: CGFloat) -> Data? {
    let image = NSWorkspace.shared.icon(forFile: path)
    return resizeAndConvertToPNG(image: image, targetSize: NSSize(width: size, height: size))
  }

  private func resizeAndConvertToPNG(image: NSImage, targetSize: NSSize) -> Data? {
    let newImage = NSImage(size: targetSize)
    newImage.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: targetSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    newImage.unlockFocus()

    guard let tiffData = newImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
      return nil
    }
    return pngData
  }
}

class NativeDragOutBridge: NSObject, NSDraggingSource {
  static let shared = NativeDragOutBridge()
  private var channel: FlutterMethodChannel?
  weak var window: NSWindow?
  private var currentDraggingPaths: [String] = []

  func setup(messenger: FlutterBinaryMessenger, window: NSWindow?) {
    self.window = window
    channel = FlutterMethodChannel(name: "dropzone/drag_out", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "startDraggingFiles" {
        guard let args = call.arguments as? [String: Any],
              let paths = args["paths"] as? [String],
              !paths.isEmpty else {
          result(false)
          return
        }
        let success = self.startDragging(paths: paths)
        result(success)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func startDragging(paths: [String]) -> Bool {
    guard let window = self.window,
          let contentView = window.contentView else {
      return false
    }

    self.currentDraggingPaths = paths
    let fileURLs = paths.compactMap { URL(fileURLWithPath: $0) }
    if fileURLs.isEmpty { return false }

    let mouseLocation = window.mouseLocationOutsideOfEventStream
    let viewPoint = contentView.convert(mouseLocation, from: nil)

    var draggingItems: [NSDraggingItem] = []
    for (index, url) in fileURLs.enumerated() {
      let item = NSDraggingItem(pasteboardWriter: url as NSURL)
      let icon = NSWorkspace.shared.icon(forFile: url.path)
      let iconSize = NSSize(width: 36, height: 36)
      let offset = CGFloat(min(index * 4, 20))
      let frame = NSRect(
        x: viewPoint.x - 18 + offset,
        y: viewPoint.y - 18 - offset,
        width: iconSize.width,
        height: iconSize.height
      )
      item.setDraggingFrame(frame, contents: icon)
      draggingItems.append(item)
    }

    let currentEvent = NSApp.currentEvent
    let dragEvent: NSEvent
    if let event = currentEvent, event.type == .leftMouseDragged || event.type == .leftMouseDown {
      dragEvent = event
    } else {
      dragEvent = NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: mouseLocation,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1.0
      ) ?? NSEvent()
    }

    contentView.beginDraggingSession(with: draggingItems, event: dragEvent, source: self)
    return true
  }

  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    // Primary move operation so Finder relocates the files instead of duplicating/copying them
    return [.move, .generic, .copy]
  }

  func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    let isMove = operation.contains(.move) || operation == .move || operation == .delete
    channel?.invokeMethod("onDragEnded", arguments: [
      "operation": isMove ? "move" : "copy",
      "paths": currentDraggingPaths
    ])
    currentDraggingPaths = []
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
