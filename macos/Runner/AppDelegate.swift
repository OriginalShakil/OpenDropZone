import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.servicesProvider = self
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  @objc func dropFilesService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
    var paths: [String] = []

    if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
      paths.append(contentsOf: urls.map { $0.path })
    } else if let filenames = pboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
      paths.append(contentsOf: filenames)
    }

    if !paths.isEmpty {
      DispatchQueue.main.async {
        TrayDragBridge.shared.handleFilesDropped(paths: paths)
      }
    }
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    if !filenames.isEmpty {
      DispatchQueue.main.async {
        TrayDragBridge.shared.handleFilesDropped(paths: filenames)
      }
    }
  }
}
