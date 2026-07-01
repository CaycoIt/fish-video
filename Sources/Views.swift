import AppKit
import AVKit
import AVFoundation

// MARK: - PlayerTheme

struct PlayerTheme {
    let sidebarBg: NSColor
    let playerBg: NSColor
    let bottomBarBg: NSColor
    let primaryText: NSColor
    let secondaryText: NSColor
    let dimText: NSColor
    let accentText: NSColor
    let isDark: Bool

    static let dark = PlayerTheme(
        sidebarBg: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1.0),
        playerBg: NSColor.black,
        bottomBarBg: NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 0.95),
        primaryText: NSColor.white,
        secondaryText: NSColor.white.withAlphaComponent(0.7),
        dimText: NSColor.white.withAlphaComponent(0.4),
        accentText: NSColor.systemBlue,
        isDark: true
    )

    static let light = PlayerTheme(
        sidebarBg: NSColor(srgbRed: 0.93, green: 0.93, blue: 0.95, alpha: 1.0),
        playerBg: NSColor(srgbRed: 0.88, green: 0.88, blue: 0.9, alpha: 1.0),
        bottomBarBg: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.97, alpha: 0.95),
        primaryText: NSColor.black,
        secondaryText: NSColor.black.withAlphaComponent(0.65),
        dimText: NSColor.black.withAlphaComponent(0.4),
        accentText: NSColor.systemBlue,
        isDark: false
    )

    static func custom(color: NSColor) -> PlayerTheme {
        let luminance = 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent
        let isDark = luminance < 0.5
        return PlayerTheme(
            sidebarBg: color,
            playerBg: color,
            bottomBarBg: color.withAlphaComponent(0.95),
            primaryText: isDark ? NSColor.white : NSColor.black,
            secondaryText: isDark ? NSColor.white.withAlphaComponent(0.7) : NSColor.black.withAlphaComponent(0.65),
            dimText: isDark ? NSColor.white.withAlphaComponent(0.4) : NSColor.black.withAlphaComponent(0.4),
            accentText: NSColor.systemBlue,
            isDark: isDark
        )
    }
}

// MARK: - SortField

enum SortField: Int {
    case nameAsc = 0, nameDesc, dateAsc, dateDesc, sizeAsc, sizeDesc

    var isAscending: Bool { return self == .nameAsc || self == .dateAsc || self == .sizeAsc }
}

// MARK: - ContentViewController (Split View: Playlist + Player)

class ContentViewController: NSSplitViewController {

    let playlistVC = PlaylistViewController()
    let playerVC = PlayerViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        let playlistItem = NSSplitViewItem(viewController: playlistVC)
        playlistItem.canCollapse = false
        playlistItem.preferredThicknessFraction = 0.22
        playlistItem.minimumThickness = 160
        playlistItem.maximumThickness = 800
        playlistItem.holdingPriority = .init(260)

        let playerItem = NSSplitViewItem(viewController: playerVC)
        playerItem.minimumThickness = 380
        playerItem.holdingPriority = .init(250)

        addSplitViewItem(playlistItem)
        addSplitViewItem(playerItem)

        // Make divider visible and draggable
        splitView.dividerStyle = .paneSplitter
        splitView.isVertical = true

        // Connect playlist ↔ player
        playlistVC.onSelect = { [weak self] url, index in
            self?.playerVC.play(url: url)
            self?.playlistVC.setCurrentIndex(index)
        }
        playerVC.onAdvance = { [weak self] in
            self?.playlistVC.selectNext()
        }
        playerVC.onPrevious = { [weak self] in
            self?.playlistVC.selectPrevious()
        }
    }

    // MARK: - Menu Actions (forwarded from menu bar)

    @objc func openFolderMenu() {
        playlistVC.openFolder(self)
    }

    @objc func openURLMenu() {
        let alert = NSAlert()
        alert.messageText = "Open URL"
        alert.informativeText = "Enter video URL (supports MP4 / HLS m3u8 / MOV):"
        alert.addButton(withTitle: "Play")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        input.placeholderString = "https://example.com/video.mp4"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let urlStr = input.stringValue.trimmingCharacters(in: .whitespaces)
            guard !urlStr.isEmpty, let url = URL(string: urlStr) else { return }
            playerVC.play(url: url)
        }
    }

    @objc func togglePlayPause() {
        playerVC.togglePlayPause()
    }

    @objc func playNext() {
        playlistVC.selectNext()
    }

    @objc func playPrevious() {
        playlistVC.selectPrevious()
    }

    @objc func setSpeed(_ sender: NSMenuItem) {
        if let speed = sender.representedObject as? Double {
            playerVC.setPlaybackSpeed(speed)
        }
    }

    @objc func forward10() {
        playerVC.forward10()
    }

    @objc func rewind10() {
        playerVC.rewind10()
    }

    @objc func speedUp() {
        playerVC.speedUp()
    }

    @objc func speedDown() {
        playerVC.speedDown()
    }

    // MARK: - Transparent Background

    func setTransparentBackground(_ enabled: Bool) {
        playlistVC.setTransparentBackground(enabled)
        playerVC.setTransparentBackground(enabled)
    }

    func syncPinButton() {
        playerVC.syncPinState()
    }

    func savePlaybackPosition() {
        playerVC.savePlaybackPosition()
    }

    func updateAlphaLabel(_ value: CGFloat) {
        playerVC.updateAlphaLabel(value)
    }

    // MARK: - Theme

    func applyTheme(_ theme: PlayerTheme) {
        playlistVC.applyTheme(theme)
        playerVC.applyTheme(theme)
    }
}

// MARK: - PlaylistViewController

class PlaylistViewController: NSViewController {

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var openButton: NSButton!
    private var titleLabel: NSTextField!
    private var files: [URL] = []
    private var currentIndex: Int = -1

    var onSelect: ((URL, Int) -> Void)?

    private let videoExtensions: Set<String> = [
        "mp4", "mov", "mkv", "avi", "flv", "wmv", "m4v", "webm",
        "mpg", "mpeg", "ts", "m2ts", "vob", "3gp", "rm", "rmvb"
    ]

    private var currentTheme: PlayerTheme = .dark
    private var sortButton: NSPopUpButton!
    private var sortField: SortField = .nameAsc

    override func loadView() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = currentTheme.sidebarBg.cgColor

        // Header container
        let headerView = NSView()
        headerView.wantsLayer = true
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        // Title label
        titleLabel = NSTextField(labelWithString: "🎬 Playlist")
        titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        // Open folder button
        openButton = NSButton(title: "📁  Open Folder", target: self, action: #selector(openFolder(_:)))
        openButton.bezelStyle = .recessed
        openButton.controlSize = .regular
        openButton.font = .systemFont(ofSize: 12, weight: .medium)
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.wantsLayer = true
        openButton.layer?.cornerRadius = 8
        openButton.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
        headerView.addSubview(openButton)

        // Sort button
        sortButton = NSPopUpButton()
        sortButton.bezelStyle = .inline
        sortButton.controlSize = .small
        sortButton.font = .systemFont(ofSize: 11, weight: .medium)
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        let sortMenu = NSMenu()
        sortMenu.addItem(NSMenuItem(title: "Name ↑", action: #selector(sortChanged(_:)), keyEquivalent: ""))
        sortMenu.addItem(NSMenuItem(title: "Name ↓", action: #selector(sortChanged(_:)), keyEquivalent: ""))
        sortMenu.addItem(NSMenuItem.separator())
        sortMenu.addItem(NSMenuItem(title: "Date ↑", action: #selector(sortChanged(_:)), keyEquivalent: ""))
        sortMenu.addItem(NSMenuItem(title: "Date ↓", action: #selector(sortChanged(_:)), keyEquivalent: ""))
        sortMenu.addItem(NSMenuItem.separator())
        sortMenu.addItem(NSMenuItem(title: "Size ↑", action: #selector(sortChanged(_:)), keyEquivalent: ""))
        sortMenu.addItem(NSMenuItem(title: "Size ↓", action: #selector(sortChanged(_:)), keyEquivalent: ""))
        sortButton.menu = sortMenu
        sortButton.selectItem(at: 0)
        sortButton.target = self
        sortButton.action = #selector(sortChanged(_:))
        headerView.addSubview(sortButton)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)

        // Table view
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.doubleAction = #selector(rowDoubleClicked)
        tableView.target = self
        tableView.selectionHighlightStyle = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.width = 200
        tableView.addTableColumn(column)

        tableView.dataSource = self
        tableView.delegate = self

        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)

        // Layout
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),

            sortButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            sortButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            openButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            openButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            openButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            openButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),

            separator.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 6),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 0),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        self.view = view
    }

    // MARK: - Open Folder

    @objc func openFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Folder"

        if panel.runModal() == .OK, let url = panel.url {
            loadFolder(url)
        }
    }

    private func loadFolder(_ folderURL: URL) {
        titleLabel.stringValue = "Loading..."
        files.removeAll()
        tableView.reloadData()

        DispatchQueue.global(qos: .userInitiated).async {
            var foundFiles: [URL] = []

            guard let enumerator = FileManager.default.enumerator(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { return }

            for case let url as URL in enumerator {
                let ext = url.pathExtension.lowercased()
                if self.videoExtensions.contains(ext) {
                    foundFiles.append(url)
                }
            }

            foundFiles.sort { self.sortFiles($0, $1) }

            DispatchQueue.main.async {
                self.files = foundFiles
                self.titleLabel.stringValue = "\u{1F3AC} Playlist (\(foundFiles.count))"
                self.currentIndex = -1
                self.tableView.reloadData()

                if !foundFiles.isEmpty {
                    self.onSelect?(foundFiles[0], 0)
                }
            }
        }
    }

    // MARK: - Selection

    func setCurrentIndex(_ index: Int) {
        currentIndex = index
        tableView.reloadData()
    }

    func selectNext() {
        guard !files.isEmpty else { return }
        let next = currentIndex + 1
        if next < files.count {
            onSelect?(files[next], next)
        }
    }

    func selectPrevious() {
        guard !files.isEmpty else { return }
        let prev = currentIndex - 1
        if prev >= 0 {
            onSelect?(files[prev], prev)
        }
    }

    @objc private func rowDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < files.count else { return }
        onSelect?(files[row], row)
    }

    // MARK: - Transparent Background

    func setTransparentBackground(_ enabled: Bool) {
        isTransparentBgActive = enabled
        if enabled {
            view.layer?.backgroundColor = currentTheme.sidebarBg.withAlphaComponent(0.75).cgColor
        } else {
            view.layer?.backgroundColor = currentTheme.sidebarBg.cgColor
        }
    }

    private var isTransparentBgActive = false

    // MARK: - Theme

    func applyTheme(_ theme: PlayerTheme) {
        currentTheme = theme
        titleLabel.textColor = theme.primaryText.withAlphaComponent(0.9)
        if !isTransparentBgActive {
            view.layer?.backgroundColor = theme.sidebarBg.cgColor
        }
        tableView.reloadData()
    }

    // MARK: - Sort

    @objc func sortChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard let field = SortField(rawValue: idx) else { return }
        sortField = field
        resortFiles()
    }

    private func resortFiles() {
        guard !files.isEmpty else { return }
        let currentURL = (currentIndex >= 0 && currentIndex < files.count) ? files[currentIndex] : nil
        files.sort { sortFiles($0, $1) }
        if let url = currentURL, let newIndex = files.firstIndex(of: url) {
            currentIndex = newIndex
        }
        tableView.reloadData()
    }

    private func sortFiles(_ a: URL, _ b: URL) -> Bool {
        switch sortField {
        case .nameAsc:
            return a.lastPathComponent < b.lastPathComponent
        case .nameDesc:
            return a.lastPathComponent > b.lastPathComponent
        case .dateAsc:
            let da = fileModDate(a), db = fileModDate(b)
            return da < db
        case .dateDesc:
            let da = fileModDate(a), db = fileModDate(b)
            return da > db
        case .sizeAsc:
            return fileSize(a) < fileSize(b)
        case .sizeDesc:
            return fileSize(a) > fileSize(b)
        }
    }

    private func fileModDate(_ url: URL) -> Date {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attrs[.modificationDate] as? Date {
            return date
        }
        return .distantPast
    }

    private func fileSize(_ url: URL) -> Int64 {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            return size
        }
        return 0
    }
}

// MARK: - Playlist Table View DataSource & Delegate

extension PlaylistViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return files.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("playlistCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? PlaylistCellView
            ?? PlaylistCellView()
        cell.identifier = identifier

        let filename = files[row].lastPathComponent
        let isCurrent = (row == currentIndex)
        cell.configure(index: row + 1, filename: filename, isCurrent: isCurrent, theme: currentTheme)
        cell.toolTip = filename

        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 && row < files.count else { return }
        if row != currentIndex {
            onSelect?(files[row], row)
        }
    }
}

// MARK: - PlaylistCellView (custom cell)

class PlaylistCellView: NSTableCellView {

    private let indexLabel = NSTextField(labelWithString: "")
    private let nameLabel = NSTextField(labelWithString: "")
    private let bgView = NSView()
    private let playIcon = NSTextField(labelWithString: "▶")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        // Background highlight (rounded)
        bgView.wantsLayer = true
        bgView.layer?.cornerRadius = 6
        bgView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bgView)

        // Index number
        indexLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        indexLabel.textColor = NSColor.white.withAlphaComponent(0.3)
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indexLabel)

        // Play icon (only for current)
        playIcon.font = .systemFont(ofSize: 9)
        playIcon.textColor = NSColor.controlAccentColor
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        playIcon.isHidden = true
        addSubview(playIcon)

        // Filename
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.cell?.truncatesLastVisibleLine = true
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            bgView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            bgView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            bgView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            bgView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            indexLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            indexLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 24),

            nameLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            playIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            playIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(index: Int, filename: String, isCurrent: Bool, theme: PlayerTheme) {
        indexLabel.stringValue = String(format: "%02d", index)
        nameLabel.stringValue = filename

        if isCurrent {
            bgView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            bgView.layer?.borderWidth = 1
            bgView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
            nameLabel.textColor = theme.primaryText
            nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            indexLabel.isHidden = true
            playIcon.isHidden = false
        } else {
            bgView.layer?.backgroundColor = NSColor.clear.cgColor
            bgView.layer?.borderWidth = 0
            nameLabel.textColor = theme.secondaryText
            nameLabel.font = .systemFont(ofSize: 12)
            indexLabel.textColor = theme.dimText
            indexLabel.isHidden = false
            playIcon.isHidden = true
        }
    }
}

// MARK: - PlayerViewController

class PlayerViewController: NSViewController {

    private var playerView: AVPlayerView!
    private var player: AVPlayer?
    private var alphaLabel: NSTextField!
    private var timeLabel: NSTextField!
    private var speedLabel: NSTextField!
    private var seekSlider: NSSlider!
    private var bottomBar: NSView!
    private var speedButton: NSPopUpButton!

    var onAdvance: (() -> Void)?
    var onPrevious: (() -> Void)?

    private var currentRate: Float = 1.0
    private var timeObserver: Any?
    private var isUserSeeking = false
    private var currentTheme: PlayerTheme = .dark
    private var isTransparentBgActive = false
    private var keyMonitor: Any?
    private var currentVideoURL: URL?
    private var statusObservation: NSKeyValueObservation?
    private var autoSaveCounter = 0

    private let speedSteps: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

    deinit {
        if let keyMonitor = keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        savePlaybackPosition()
    }

    override func loadView() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = currentTheme.playerBg.cgColor

        // AVPlayerView
        playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true
        view.addSubview(playerView)

        // Bottom control bar
        bottomBar = NSView()
        bottomBar.wantsLayer = true
        bottomBar.layer?.backgroundColor = currentTheme.bottomBarBg.cgColor
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        // Previous button
        let prevButton = NSButton(image: NSImage(systemSymbolName: "backward.end.fill", accessibilityDescription: "Previous")!, target: self, action: #selector(previous))
        prevButton.bezelStyle = .inline
        prevButton.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(prevButton)

        // Rewind 10s button
        let rewindButton = NSButton(image: NSImage(systemSymbolName: "gobackward.10", accessibilityDescription: "Rewind 10s")!, target: self, action: #selector(rewind10))
        rewindButton.bezelStyle = .inline
        rewindButton.contentTintColor = NSColor.white.withAlphaComponent(0.8)
        rewindButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(rewindButton)

        // Play/Pause button
        let playButton = NSButton(image: NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")!, target: self, action: #selector(togglePlayPause))
        playButton.bezelStyle = .inline
        playButton.contentTintColor = .white
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.identifier = NSUserInterfaceItemIdentifier("playButton")
        bottomBar.addSubview(playButton)

        // Forward 10s button
        let forwardButton = NSButton(image: NSImage(systemSymbolName: "goforward.10", accessibilityDescription: "Forward 10s")!, target: self, action: #selector(forward10))
        forwardButton.bezelStyle = .inline
        forwardButton.contentTintColor = NSColor.white.withAlphaComponent(0.8)
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(forwardButton)

        // Next button
        let nextButton = NSButton(image: NSImage(systemSymbolName: "forward.end.fill", accessibilityDescription: "Next")!, target: self, action: #selector(next))
        nextButton.bezelStyle = .inline
        nextButton.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(nextButton)

        // Speed selector
        speedButton = NSPopUpButton()
        speedButton.addItems(withTitles: ["0.5x", "0.75x", "1.0x", "1.25x", "1.5x", "2.0x", "3.0x"])
        speedButton.selectItem(withTitle: "1.0x")
        speedButton.target = self
        speedButton.action = #selector(speedChanged)
        speedButton.translatesAutoresizingMaskIntoConstraints = false
        speedButton.bezelStyle = .inline
        bottomBar.addSubview(speedButton)

        // Speed label
        speedLabel = NSTextField(labelWithString: "1.0x")
        speedLabel.textColor = NSColor.systemBlue
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(speedLabel)

        // Seek slider
        seekSlider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: self, action: #selector(sliderChanged))
        seekSlider.isContinuous = true
        seekSlider.controlSize = .small
        seekSlider.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(seekSlider)

        // Alpha label
        alphaLabel = NSTextField(labelWithString: "Opacity 100%")
        alphaLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        alphaLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        alphaLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(alphaLabel)

        // Time label
        timeLabel = NSTextField(labelWithString: "00:00 / 00:00")
        timeLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(timeLabel)

        // Pin (Always on Top) button
        let pinButton = NSButton(image: NSImage(systemSymbolName: "pin", accessibilityDescription: "Always on Top")!, target: self, action: #selector(togglePin))
        pinButton.bezelStyle = .inline
        pinButton.contentTintColor = NSColor.white.withAlphaComponent(0.4)
        pinButton.translatesAutoresizingMaskIntoConstraints = false
        pinButton.identifier = NSUserInterfaceItemIdentifier("pinButton")
        bottomBar.addSubview(pinButton)

        // Layout
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Bottom bar items
        NSLayoutConstraint.activate([
            prevButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            prevButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            rewindButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 10),
            rewindButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            playButton.leadingAnchor.constraint(equalTo: rewindButton.trailingAnchor, constant: 10),
            playButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            forwardButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 10),
            forwardButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            nextButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 10),
            nextButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            speedButton.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 16),
            speedButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            speedLabel.leadingAnchor.constraint(equalTo: speedButton.trailingAnchor, constant: 6),
            speedLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            seekSlider.leadingAnchor.constraint(equalTo: speedLabel.trailingAnchor, constant: 16),
            seekSlider.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            seekSlider.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -12),

            timeLabel.trailingAnchor.constraint(equalTo: alphaLabel.leadingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            alphaLabel.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor, constant: -10),
            alphaLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            pinButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            pinButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
        ])

        self.view = view

        startKeyMonitor()
    }

    // MARK: - Playback

    func play(url: URL) {
        // 保存上一个视频的播放进度
        savePlaybackPosition()

        // Remove old time observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        playerView.player = player
        currentVideoURL = url

        // Observe end of video for auto-advance
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        player?.play()
        player?.rate = currentRate
        updatePlayButton()

        // 恢复播放进度（用 KVO 等播放器就绪）
        restorePlaybackPosition(for: url, item: item)

        // Periodic time observer for time label + auto save
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.updateTimeLabel()
            // 每 5 秒自动保存一次进度（10 ticks × 0.5s）
            self?.autoSaveCounter += 1
            if self?.autoSaveCounter ?? 0 >= 10 {
                self?.autoSaveCounter = 0
                self?.savePlaybackPosition()
            }
        }
    }

    @objc func togglePlayPause() {
        guard let player = player else { return }
        if player.rate > 0 {
            player.pause()
            savePlaybackPosition()
        } else {
            player.play()
            player.rate = currentRate
        }
        updatePlayButton()
    }

    func startKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 空格键 keyCode = 49
            if event.keyCode == 49 {
                self?.togglePlayPause()
                return nil
            }
            return event
        }
    }

    @objc func next() {
        onAdvance?()
    }

    @objc func previous() {
        onPrevious?()
    }

    // MARK: - Seek

    @objc func sliderChanged() {
        isUserSeeking = true
        guard let player = player else { return }
        let total = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        guard total > 0 else { return }
        let target = seekSlider.doubleValue
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isUserSeeking = false
            self?.savePlaybackPosition()
        }
    }

    @objc func forward10() {
        guard let player = player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let total = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        let target = min(current + 10, total)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateTimeLabel()
        savePlaybackPosition()
    }

    @objc func rewind10() {
        guard let player = player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let target = max(current - 10, 0)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateTimeLabel()
        savePlaybackPosition()
    }

    // MARK: - Speed Cycle

    @objc func speedUp() {
        let current = Double(currentRate)
        if let idx = speedSteps.firstIndex(where: { abs($0 - current) < 0.01 }) {
            let next = min(idx + 1, speedSteps.count - 1)
            setPlaybackSpeed(speedSteps[next])
        } else {
            setPlaybackSpeed(1.25)
        }
    }

    @objc func speedDown() {
        let current = Double(currentRate)
        if let idx = speedSteps.firstIndex(where: { abs($0 - current) < 0.01 }) {
            let prev = max(idx - 1, 0)
            setPlaybackSpeed(speedSteps[prev])
        } else {
            setPlaybackSpeed(0.75)
        }
    }

    @objc func playerDidFinish() {
        // 视频播放结束，清除保存的进度
        if let url = currentVideoURL {
            UserDefaults.standard.removeObject(forKey: "playback_\(url.path)")
        }
        DispatchQueue.main.async { [weak self] in
            self?.onAdvance?()
        }
    }

    // MARK: - Speed

    @objc func speedChanged() {
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
        let index = speedButton.indexOfSelectedItem
        if index >= 0 && index < speeds.count {
            setPlaybackSpeed(Double(speeds[index]))
        }
    }

    func setPlaybackSpeed(_ speed: Double) {
        currentRate = Float(speed)
        player?.rate = currentRate
        speedLabel.stringValue = String(format: "%gx", speed)
        speedButton.selectItem(withTitle: String(format: "%gx", speed))
    }

    // MARK: - Helpers

    private func updatePlayButton() {
        if let button = bottomBar.subviews.first(where: { $0.identifier?.rawValue == "playButton" }) as? NSButton {
            if player?.rate ?? 0 > 0 {
                button.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause")
            } else {
                button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
            }
        }
    }

    // MARK: - Pin (Always on Top)

    @objc func togglePin() {
        guard let window = view.window else { return }
        if window.level == .floating {
            window.level = .normal
        } else {
            window.level = .floating
        }
        updatePinButton()
    }

    private func updatePinButton() {
        if let button = bottomBar.subviews.first(where: { $0.identifier?.rawValue == "pinButton" }) as? NSButton {
            if view.window?.level == .floating {
                button.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
                button.contentTintColor = NSColor.systemBlue
            } else {
                button.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Not pinned")
                button.contentTintColor = NSColor.white.withAlphaComponent(0.4)
            }
        }
    }

    func syncPinState() {
        updatePinButton()
    }

    func updateAlphaLabel(_ value: CGFloat) {
        let percent = Int(value * 100)
        alphaLabel.stringValue = "Opacity \(percent)%"
    }

    // MARK: - Time Display

    private func updateTimeLabel() {
        guard let player = player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let total = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        guard total.isFinite && total > 0 else { return }
        timeLabel.stringValue = "\(formatTime(current)) / \(formatTime(total))"
        if !isUserSeeking {
            seekSlider.maxValue = total
            seekSlider.doubleValue = current
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Playback Memory

    func savePlaybackPosition() {
        guard let url = currentVideoURL, let player = player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let total = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        // 跳过无效时长或已接近结尾的视频
        guard total.isFinite, total > 0, current > 3, current < total - 5 else { return }
        UserDefaults.standard.set(current, forKey: "playback_\(url.path)")
    }

    private func restorePlaybackPosition(for url: URL, item: AVPlayerItem) {
        let key = "playback_\(url.path)"
        guard let saved = UserDefaults.standard.object(forKey: key) as? Double, saved > 3 else { return }

        // 用 KVO 等待播放器就绪后再 seek
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            let total = CMTimeGetSeconds(item.duration)
            // 确保保存的位置不超过视频总时长
            guard total.isFinite, total > 0, saved < total - 5 else {
                UserDefaults.standard.removeObject(forKey: key)
                return
            }
            DispatchQueue.main.async {
                self?.player?.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
                self?.showToast("▶️ 已恢复到 \(self?.formatTime(saved) ?? "")")
            }
        }
    }

    private var toastLabel: NSTextField?

    private func showToast(_ text: String) {
        // 移除旧 toast
        toastLabel?.removeFromSuperview()

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        label.isBezeled = false
        label.wantsLayer = true
        label.layer?.cornerRadius = 8
        label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        label.sizeToFit()
        // 加内边距
        var frame = label.frame
        frame.size.width += 24
        frame.size.height += 12
        label.frame = frame

        // 居中显示
        if let pv = view.window?.contentView {
            label.frame.origin = NSPoint(
                x: (pv.bounds.width - frame.width) / 2,
                y: pv.bounds.height / 2
            )
            pv.addSubview(label)
        }

        toastLabel = label

        // 1.5 秒后淡出移除
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                label.animator().alphaValue = 0
            }, completionHandler: {
                label.removeFromSuperview()
                self?.toastLabel = nil
            })
        }
    }

    // MARK: - Transparent Background

    func setTransparentBackground(_ enabled: Bool) {
        isTransparentBgActive = enabled
        if enabled {
            view.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            view.layer?.backgroundColor = currentTheme.playerBg.cgColor
        }
    }

    // MARK: - Theme

    func applyTheme(_ theme: PlayerTheme) {
        currentTheme = theme
        if !isTransparentBgActive {
            view.layer?.backgroundColor = theme.playerBg.cgColor
        }
        bottomBar.layer?.backgroundColor = theme.bottomBarBg.cgColor
        speedLabel.textColor = theme.accentText
        alphaLabel.textColor = theme.dimText
        timeLabel.textColor = theme.secondaryText
        for subview in bottomBar.subviews {
            guard let button = subview as? NSButton else { continue }
            let id = button.identifier?.rawValue
            if id == "playButton" {
                button.contentTintColor = theme.primaryText
            } else if id == "pinButton" {
                updatePinButton()
            } else {
                button.contentTintColor = theme.secondaryText
            }
        }
    }
}
