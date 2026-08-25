# ⚡ Open Drop Zone

<p align="center">
  <img src="assets/icons/OpenDropZone.png" width="128" height="128" alt="Open Drop Zone Logo" style="border-radius: 26px; box-shadow: 0 10px 30px rgba(0,0,0,0.25);" />
</p>

<p align="center">
  <b>A lightning-fast, native macOS drag-and-drop shelf and workspace utility.</b><br>
  Hold, organize, preview, and drag files anywhere across your Mac with zero friction.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS-black?logo=apple&logoColor=white" alt="Platform: macOS" />
  <img src="https://img.shields.io/badge/Framework-Flutter%203-02569B?logo=flutter&logoColor=white" alt="Framework: Flutter" />
  <img src="https://img.shields.io/badge/Native-Swift%20%2F%20AppKit-F05138?logo=swift&logoColor=white" alt="Native: Swift" />
  <img src="https://img.shields.io/badge/Built%20with-Vibe%20Coding-8A2BE2" alt="Vibe Coded" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License: MIT" />
</p>

---

## ✨ A Vibe-Coded Project

> **Open Drop Zone was created through pure vibe coding** — blending modern developer velocity with native macOS AppKit engineering. Built to bring back the sheer joy of fluid desktop interactions, it demonstrates how fast, reactive desktop tools can feel when thoughtful UX design meets deep native OS integrations.

**We invite and encourage all developers, designers, and macOS enthusiasts to fork, improve, polish, and extend Open Drop Zone!** Pull requests and feature ideas are warmly welcomed.

---

## 📖 User Guide

Open Drop Zone sits silently in your macOS menu bar, ready to act as a temporary holding shelf for files, folders, images, screenshots, videos, and documents as you navigate between apps, spaces, and Finder windows.

### 🌟 Key Features

1. **Full-Surface Drag & Drop Target**:
   - Drag files from Finder, your browser, or any application directly onto the menu bar icon or anywhere inside the popup window.
   - The entire window acts as a drop target with instant visual feedback and a glowing macOS frosted overlay.

2. **Send Selected Finder Items Shortcut (`⌃⌥D`)**:
   - Select any files or folders in Finder and hit `Control + Option + D` (or your custom shortcut). They are instantly added to your shelf and the popup unfurls under your tray.

3. **Global Toggle Shortcut (`⌥ Space`)**:
   - Press `Option + Space` anywhere in macOS to toggle the popup window on and off.

4. **Finder Right-Click & Quick Actions**:
   - Right-click any file in Finder and select **Quick Actions → Send to Open Drop Zone** (or **Services → Send to Open Drop Zone**).

5. **4-Column Native Finder Previews**:
   - High-resolution thumbnails for images (`.png`, `.jpg`, `.webp`, `.heic`, `.gif`).
   - Video frame thumbnail extraction for video files (`.mp4`, `.mov`, `.m4v`, `.mkv`, `.avi`, `.webm`).
   - Authentic macOS system icons for application bundles (`.app`), folders, and documents.
   - Minimalist card tiles with hover tooltips showing file name and formatted size.

6. **Rubber-Band Marquee Selection**:
   - Click and drag across any empty space in the grid to draw a frosted blue marquee selection box. All intersecting items are selected in real time.

7. **Native Multi-File Drag-Out**:
   - Select 1 or 50 items and drag them out in a single gesture. External apps and Finder receive all selected files at once.
   - Seamless move support: Moving files to Finder or Trash automatically updates your shelf.

8. **Keyboard Shortcuts & Quick Actions**:
   - `⌘A` — Select all items in shelf.
   - `⌘,` — Toggle Settings & Options.
   - `⎋` (Escape) — Dismiss settings or clear active selection.

9. **Multi-Space & Fullscreen Support**:
   - Floats cleanly across all macOS Desktops, Spaces, and Fullscreen applications. Clicking the menu bar icon always brings the shelf to your current screen.

10. **Launch at Startup**:
    - Optional automatic launch on macOS login via native `SMAppService`.

---

## 🛠️ Developer Guide

Open Drop Zone combines a reactive **Flutter (Desktop macOS)** presentation layer with deep **native Swift & AppKit bridges** using Cocoa channels.

### 🏛️ Architecture Overview

```
dropzoneclone/
├── lib/
│   ├── main.dart                       # App entry point, hotkey listeners & popover window
│   ├── models/
│   │   └── file_item.dart              # File metadata & formatting model
│   ├── services/
│   │   ├── shortcut_service.dart       # Hotkey management, keycode mapping & storage
│   │   ├── startup_service.dart        # Launch at startup bridge
│   │   └── tray_window_controller.dart # Popover positioning, window lifecycle & tray events
│   └── widgets/
│       ├── file_list_widget.dart       # 4-col grid, marquee selection & drag detector
│       ├── header_bar.dart             # App branding, clear & action controls
│       ├── popover_container.dart      # Custom curved notch clipper & glassmorphism backdrop
│       ├── settings_sheet.dart         # Preferences, launch toggle & shortcut recorder
│       └── shortcut_recorder_widget.dart # Interactive macOS shortcut capture component
└── macos/Runner/
    ├── MainFlutterWindow.swift         # AppKit bridges (Drag-out, HotKeys, Finder AppleScript, QuickLook)
    ├── AppDelegate.swift               # NSServices ("Send to Open Drop Zone") & OpenFiles handler
    ├── Info.plist                      # NSServices declaration & Apple Events descriptions
    ├── DebugProfile.entitlements       # Apple Events sandbox exceptions
    └── Release.entitlements            # Release sandbox entitlements
```

### ⚡ Native Bridges (Swift & AppKit)

- **`HotKeyBridge`**: Uses Carbon `RegisterEventHotKey` for instantaneous system-wide global shortcut interception without requiring Accessibility permissions. Queries active Finder selections via `tell application id "com.apple.finder"` with fallback clipboard pasteboard extraction.
- **`NativeDragOutBridge`**: Implements `NSDraggingSource` and calls `contentView.beginDraggingSession(with: draggingItems)` to allow true multi-file drag-out into external macOS applications.
- **`FileIconBridge`**: Generates high-res previews using `AVAssetImageGenerator` for videos, `QLThumbnailGenerator` for documents, and `NSWorkspace.shared.icon(forFile:)` for application bundles.
- **`TrayDragBridge`**: Hooks into `NSStatusBarButton` to intercept dragging hover states and file drops directly on the menu bar icon.
- **`StartupBridge`**: Registers macOS login items using `SMAppService.mainApp` with AppleScript fallback for older macOS releases.

---

## 🚀 Getting Started (Development)

### Prerequisites
- macOS 11.0 (Big Sur) or later
- [Flutter SDK](https://docs.flutter.dev/get-started/install/macos) (v3.11+ recommended)
- Xcode 14+ with Command Line Tools
- CocoaPods (`sudo gem install cocoapods`)

### Build & Run Locally

1. **Clone the repository**:
   ```bash
   git clone https://github.com/OriginalShakil/OpenDropZone.git
   cd OpenDropZone
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Install macOS CocoaPods**:
   ```bash
   cd macos && pod install && cd ..
   ```

4. **Run in Debug Mode**:
   ```bash
   flutter run -d macos
   ```

5. **Build Release Application**:
   ```bash
   flutter build macos --release
   ```
   The compiled `.app` will be located in `build/macos/Build/Products/Release/Open Drop Zone.app`.

---

## 🤝 Contributing & Extending

Open Drop Zone was built with modern open-source collaboration in mind. Some exciting ideas to contribute:
- [ ] **Drop Actions / Plugins** (e.g. Upload to Imgur, Resize Image, Convert to PDF, AirDrop).
- [ ] **Grid customization** (Adjust column count, thumbnail sizing).
- [ ] **iCloud / Local Shelf Sync**.
- [ ] **History & Search bar**.
- [ ] **Custom sound effects** on drop and drag-out.

### How to Contribute:
1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/awesome-feature`).
3. Commit your changes (`git commit -m 'Add awesome feature'`).
4. Push to the branch (`git push origin feature/awesome-feature`).
5. Open a **Pull Request**!

---

## 📄 License

Open Drop Zone is open-source software licensed under the [MIT License](LICENSE).
Feel free to use, modify, and distribute as you see fit.
