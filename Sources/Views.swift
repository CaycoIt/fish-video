import AppKit
import AVKit
import AVFoundation

// MARK: - ContentViewController (Split View: Playlist + Player)

class ContentViewController: NSSplitViewController {

    let playlistVC = PlaylistViewController()
    let playerVC = PlayerViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        let playlistItem = NSSplitViewItem(viewController: playlistVC)
        playlistItem.canCollapse = true
        playlistItem.preferredThicknessFraction = 0.22
        playlistItem.minimumThickness = 160
        playlistItem.maximumThickness = 400

        let playerItem = NSSplitViewItem(viewController: playerVC)

        addSplitViewItem(playlistItem)
        addSplitViewItem(playerItem)

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

    func updateAlphaLabel(_ value: CGFloat) {
        playerVC.updateAlphaLabel(value)
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

    private let darkBg = NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)
    private let sidebarBg = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)

    override func loadView() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = sidebarBg.cgColor

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

            foundFiles.sort { $0.lastPathComponent < $1.lastPathComponent }

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
        if enabled {
            view.layer?.backgroundColor = NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 0.75).cgColor
        } else {
            view.layer?.backgroundColor = sidebarBg.cgColor
        }
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
        cell.configure(index: row + 1, filename: filename, isCurrent: isCurrent)

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

    func configure(index: Int, filename: String, isCurrent: Bool) {
        indexLabel.stringValue = String(format: "%02d", index)
        nameLabel.stringValue = filename

        if isCurrent {
            bgView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            bgView.layer?.borderWidth = 1
            bgView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
            nameLabel.textColor = NSColor.white
            nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            indexLabel.isHidden = true
            playIcon.isHidden = false
        } else {
            bgView.layer?.backgroundColor = NSColor.clear.cgColor
            bgView.layer?.borderWidth = 0
            nameLabel.textColor = NSColor.white.withAlphaComponent(0.6)
            nameLabel.font = .systemFont(ofSize: 12)
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

    private let speedSteps: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

    override func loadView() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        // AVPlayerView
        playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true
        view.addSubview(playerView)

        // Bottom control bar
        bottomBar = NSView()
        bottomBar.wantsLayer = true
        bottomBar.layer?.backgroundColor = NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 0.95).cgColor
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
    }

    // MARK: - Playback

    func play(url: URL) {
        // Remove old time observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        playerView.player = player

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

        // Periodic time observer for time label
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.updateTimeLabel()
        }
    }

    @objc func togglePlayPause() {
        guard let player = player else { return }
        if player.rate > 0 {
            player.pause()
        } else {
            player.play()
            player.rate = currentRate
        }
        updatePlayButton()
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
        }
    }

    @objc func forward10() {
        guard let player = player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let total = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        let target = min(current + 10, total)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateTimeLabel()
    }

    @objc func rewind10() {
        guard let player = player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let target = max(current - 10, 0)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateTimeLabel()
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

    // MARK: - Transparent Background

    func setTransparentBackground(_ enabled: Bool) {
        if enabled {
            view.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            view.layer?.backgroundColor = NSColor.black.cgColor
        }
    }
}
