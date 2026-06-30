import AppKit
import AVKit
import AVFoundation

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var contentController: ContentViewController?
    private var isTransparentBg = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        contentController = ContentViewController()

        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window?.title = "MoYuPlayer"
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.appearance = NSAppearance(named: .darkAqua)
        window?.contentViewController = contentController
        window?.center()
        window?.minSize = NSSize(width: 600, height: 400)
        window?.makeKeyAndOrderFront(nil)
        window?.alphaValue = 1.0
        window?.isMovableByWindowBackground = true
        window?.backgroundColor = NSColor.black

        setupMenuBar()

        NSApp.setActivationPolicy(.regular)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About MoYuPlayer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "Open Folder...", action: #selector(ContentViewController.openFolderMenu), keyEquivalent: "o"))
        fileMenu.addItem(NSMenuItem(title: "Open URL...", action: #selector(ContentViewController.openURLMenu), keyEquivalent: "u"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let topItem = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "t")
        viewMenu.addItem(topItem)
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(NSMenuItem(title: "Transparency +", action: #selector(increaseTransparency), keyEquivalent: "]"))
        viewMenu.addItem(NSMenuItem(title: "Transparency -", action: #selector(decreaseTransparency), keyEquivalent: "["))
        viewMenu.addItem(NSMenuItem(title: "Reset Transparency", action: #selector(resetTransparency), keyEquivalent: "0"))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(NSMenuItem(title: "Transparent Background", action: #selector(toggleTransparentBackground), keyEquivalent: "b"))
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Playback menu
        let playbackMenuItem = NSMenuItem()
        let playbackMenu = NSMenu(title: "Playback")
        playbackMenu.addItem(NSMenuItem(title: "Play/Pause", action: #selector(ContentViewController.togglePlayPause), keyEquivalent: " "))
        playbackMenu.addItem(NSMenuItem(title: "Next", action: #selector(ContentViewController.playNext), keyEquivalent: "\u{2192}"))
        playbackMenu.addItem(NSMenuItem(title: "Previous", action: #selector(ContentViewController.playPrevious), keyEquivalent: "\u{2190}"))
        playbackMenu.addItem(NSMenuItem.separator())

        // Seek controls (no modifier = arrow keys alone)
        let forwardItem = NSMenuItem(title: "Forward 10s", action: #selector(ContentViewController.forward10), keyEquivalent: "\u{2192}")
        forwardItem.keyEquivalentModifierMask = []
        playbackMenu.addItem(forwardItem)

        let rewindItem = NSMenuItem(title: "Rewind 10s", action: #selector(ContentViewController.rewind10), keyEquivalent: "\u{2190}")
        rewindItem.keyEquivalentModifierMask = []
        playbackMenu.addItem(rewindItem)

        playbackMenu.addItem(NSMenuItem.separator())

        // Speed cycle (no modifier = bracket keys alone)
        let speedUpItem = NSMenuItem(title: "Speed Up", action: #selector(ContentViewController.speedUp), keyEquivalent: "]")
        speedUpItem.keyEquivalentModifierMask = []
        playbackMenu.addItem(speedUpItem)

        let speedDownItem = NSMenuItem(title: "Speed Down", action: #selector(ContentViewController.speedDown), keyEquivalent: "[")
        speedDownItem.keyEquivalentModifierMask = []
        playbackMenu.addItem(speedDownItem)

        playbackMenu.addItem(NSMenuItem.separator())

        let speedMenu = NSMenu(title: "Speed")
        for speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0] {
            let item = NSMenuItem(title: "\(speed)x", action: #selector(ContentViewController.setSpeed(_:)), keyEquivalent: "")
            item.target = contentController
            item.representedObject = speed
            speedMenu.addItem(item)
        }
        let speedMenuItem = NSMenuItem(title: "Set Speed", action: nil, keyEquivalent: "")
        speedMenuItem.submenu = speedMenu
        playbackMenu.addItem(speedMenuItem)
        playbackMenuItem.submenu = playbackMenu
        mainMenu.addItem(playbackMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Window Actions

    @objc func toggleAlwaysOnTop() {
        guard let window = window else { return }
        if window.level == .floating {
            window.level = .normal
        } else {
            window.level = .floating
        }
        contentController?.syncPinButton()
    }

    @objc func increaseTransparency() {
        guard let window = window else { return }
        window.alphaValue = max(0.2, window.alphaValue - 0.1)
        contentController?.updateAlphaLabel(window.alphaValue)
    }

    @objc func decreaseTransparency() {
        guard let window = window else { return }
        window.alphaValue = min(1.0, window.alphaValue + 0.1)
        contentController?.updateAlphaLabel(window.alphaValue)
    }

    @objc func resetTransparency() {
        window?.alphaValue = 1.0
        contentController?.updateAlphaLabel(1.0)
    }

    // MARK: - Transparent Background

    @objc func toggleTransparentBackground() {
        guard let window = window else { return }
        isTransparentBg = !isTransparentBg

        if isTransparentBg {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
        } else {
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = true
        }

        contentController?.setTransparentBackground(isTransparentBg)
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
