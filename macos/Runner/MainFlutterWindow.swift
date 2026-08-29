import Cocoa
import FlutterMacOS
import ServiceManagement
import QuickLookThumbnailing
import AVFoundation
import Carbon

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

    // Multi-Space & Multi-Display Support: follow active space and float over fullscreen apps
    self.level = .floating
    self.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
      .ignoresCycle
    ]

    RegisterGeneratedPlugins(registry: flutterViewController)
    TrayDragBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger)
    StartupBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger)
    NativeDragOutBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger, window: self)
    FileIconBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger)
    HotKeyBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger)
    MouseShakeBridge.shared.setup(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

class HotKeyBridge: NSObject {
  static let shared = HotKeyBridge()
  private var channel: FlutterMethodChannel?
  private var hotKeyRefs: [String: EventHotKeyRef] = [:]
  private var hotKeyIds: [UInt32: String] = [:]
  private var hotKeyHandlersInstalled = false

  func setup(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "dropzone/hotkeys", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "registerHotKey" {
        guard let args = call.arguments as? [String: Any],
              let identifier = args["identifier"] as? String,
              let keyCode = args["keyCode"] as? UInt32,
              let modifiers = args["modifiers"] as? UInt32 else {
          result(false)
          return
        }
        let success = self.registerHotKey(identifier: identifier, keyCode: keyCode, modifiers: modifiers)
        result(success)
      } else if call.method == "unregisterHotKey" {
        guard let args = call.arguments as? [String: Any],
              let identifier = args["identifier"] as? String else {
          result(false)
          return
        }
        self.unregisterHotKey(identifier: identifier)
        result(true)
      } else if call.method == "getFinderSelection" {
        let paths = self.getFinderSelectedPaths()
        result(paths)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    installCarbonEventHandler()
  }

  func registerHotKey(identifier: String, keyCode: UInt32, modifiers: UInt32) -> Bool {
    unregisterHotKey(identifier: identifier)

    let id: UInt32 = (identifier == "open_popup") ? 1 : 2
    hotKeyIds[id] = identifier

    var hotKeyRef: EventHotKeyRef?
    var hotKeyID = EventHotKeyID()
    hotKeyID.signature = OSType(0x445A4F4E) // 'DZON'
    hotKeyID.id = id

    var carbonModifiers: UInt32 = 0
    if (modifiers & 1) != 0 { carbonModifiers |= UInt32(controlKey) }
    if (modifiers & 2) != 0 { carbonModifiers |= UInt32(optionKey) }
    if (modifiers & 4) != 0 { carbonModifiers |= UInt32(shiftKey) }
    if (modifiers & 8) != 0 { carbonModifiers |= UInt32(cmdKey) }

    let status = RegisterEventHotKey(
      keyCode,
      carbonModifiers,
      hotKeyID,
      GetEventDispatcherTarget(),
      0,
      &hotKeyRef
    )

    if status == noErr, let ref = hotKeyRef {
      hotKeyRefs[identifier] = ref
      return true
    }
    return false
  }

  func unregisterHotKey(identifier: String) {
    if let ref = hotKeyRefs[identifier] {
      UnregisterEventHotKey(ref)
      hotKeyRefs.removeValue(forKey: identifier)
    }
  }

  private func installCarbonEventHandler() {
    guard !hotKeyHandlersInstalled else { return }
    hotKeyHandlersInstalled = true

    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetEventDispatcherTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
      var hotKeyID = EventHotKeyID()
      let status = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
      )
      if status == noErr {
        HotKeyBridge.shared.handleHotKeyTriggered(id: hotKeyID.id)
      }
      return noErr
    }, 1, &eventType, nil, nil)
  }

  func handleHotKeyTriggered(id: UInt32) {
    guard let identifier = hotKeyIds[id] else { return }
    DispatchQueue.main.async {
      if identifier == "add_finder_selection" {
        let paths = self.getFinderSelectedPaths()
        if !paths.isEmpty {
          TrayDragBridge.shared.handleFilesDropped(paths: paths)
        }
      }
      self.channel?.invokeMethod("onHotKeyTriggered", arguments: ["identifier": identifier])
    }
  }

  func getFinderSelectedPaths() -> [String] {
    let script = """
    tell application id "com.apple.finder"
      set theSelection to selection
      set pathList to {}
      repeat with anItem in theSelection
        try
          set end of pathList to (POSIX path of (anItem as alias))
        end try
      end repeat
      set AppleScript's text item delimiters to linefeed
      return pathList as text
    end tell
    """

    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
      let output = scriptObject.executeAndReturnError(&error)
      if let resultStr = output.stringValue, !resultStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let paths = resultStr.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !paths.isEmpty { return paths }
      }
    }

    // Strategy 2: Fast clipboard copy event simulation
    let pasteboard = NSPasteboard.general
    let src = CGEventSource(stateID: .hidSystemState)
    let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true)
    let cDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
    let cUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
    let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)

    cDown?.flags = .maskCommand
    cUp?.flags = .maskCommand

    cmdDown?.post(tap: .cghidEventTap)
    cDown?.post(tap: .cghidEventTap)
    cUp?.post(tap: .cghidEventTap)
    cmdUp?.post(tap: .cghidEventTap)

    usleep(50000)

    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
      return urls.map { $0.path }
    }

    return []
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

class MouseShakeBridge: NSObject {
  static let shared = MouseShakeBridge()
  private var channel: FlutterMethodChannel?
  private var monitor: Any?
  private var isMonitoring = false
  private var updateTimer: Timer?
  private var dragMonitor: Any?

  func setup(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "dropzone/mouse_shake", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "startMonitoring" {
        print("🎯 MouseShakeBridge: Starting monitoring")
        self.startMonitoring()
        result(true)
      } else if call.method == "stopMonitoring" {
        print("🛑 MouseShakeBridge: Stopping monitoring")
        self.stopMonitoring()
        result(true)
      } else if call.method == "startGlobalDragMonitoring" {
        print("🌍 MouseShakeBridge: Starting global drag monitoring")
        self.startGlobalDragMonitoring()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Auto-start global drag monitoring on setup
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.startGlobalDragMonitoring()
    }
  }
  
  func startGlobalDragMonitoring() {
    // Monitor for any drag operation starting (left mouse down + movement)
    dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
      guard let self = self else { return }
      if !self.isMonitoring {
        print("🔍 MouseShakeBridge: Global drag detected, starting shake monitoring")
        self.startMonitoring()
      }
    }
    
    // Also monitor for mouse up to stop monitoring
    NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
      guard let self = self else { return }
      if self.isMonitoring {
        print("🔍 MouseShakeBridge: Mouse released, stopping monitoring")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          self.stopMonitoring()
        }
      }
    }
    
    print("✅ MouseShakeBridge: Global drag monitoring active")
  }

  func startMonitoring() {
    guard !isMonitoring else { return }
    isMonitoring = true

    print("🎬 MouseShakeBridge: Setting up timer with 0.05s interval")
    
    // Monitor global mouse movements using a timer for more reliable tracking during drag
    updateTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
      guard let self = self, self.isMonitoring else { return }
      let location = NSEvent.mouseLocation
      
      DispatchQueue.main.async {
        self.channel?.invokeMethod("onMouseMoved", arguments: [
          "x": location.x,
          "y": location.y
        ])
      }
    }
    
    // Add timer to RunLoop so it fires even during drag operations
    RunLoop.main.add(updateTimer!, forMode: .common)
    
    print("✅ MouseShakeBridge: Timer-based monitoring active, timer created: \(updateTimer != nil)")
  }

  func stopMonitoring() {
    guard isMonitoring else { return }
    isMonitoring = false

    updateTimer?.invalidate()
    updateTimer = nil

    if let monitor = monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
    
    channel?.invokeMethod("onDragEnded", arguments: nil)
    print("✅ MouseShakeBridge: Monitoring stopped")
  }
}

