import AppKit
import SwiftUI
import ServiceManagement

private enum DefaultsKey {
    static let windowX = "cgpu_window_x"
    static let windowY = "cgpu_window_y"
    static let widgetMode = "cgpu_widget_mode"
    static let isOpaque = "cgpu_is_opaque"
    static let isAlwaysOnTop = "cgpu_is_always_on_top"
    static let language = "cgpu_language"
}

private let appDefaults: UserDefaults = {
    return UserDefaults(suiteName: "com.cgpu.monitor") ?? UserDefaults.standard
}()

// 화면 최상단(메뉴바 바로 아래)까지 걸림 없이 자유롭게 이동할 수 있는 전용 패널
final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen = screen else { return frameRect }
        var rect = frameRect
        let visible = screen.visibleFrame
        
        if rect.maxY > visible.maxY {
            rect.origin.y = visible.maxY - rect.height
        }
        if rect.origin.y < visible.minY {
            rect.origin.y = visible.minY
        }
        return rect
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: WidgetPanel!
    private var statusItem: NSStatusItem!
    private let monitor = SystemMonitor()
    
    // 모드 및 상태 관리 (기본값 설정 후 UserDefaults에서 복원)
    private var currentMode: WidgetMode = .standard
    private var isAlwaysOnTop: Bool = true
    private var isOpaque: Bool = false
    private var currentLanguage: AppLanguage = .en
    private var currentConfig: MetricConfig = MetricConfig.load()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        loadSavedState()
        setupWindow()
        setupStatusMenu()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let win = self.window else { return }
            win.orderFrontRegardless()
            win.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        saveCurrentState()
    }
    
    private func loadSavedState() {
        self.currentConfig = MetricConfig.load()
        if appDefaults.object(forKey: DefaultsKey.widgetMode) != nil {
            let savedModeRaw = appDefaults.integer(forKey: DefaultsKey.widgetMode)
            if let savedMode = WidgetMode(rawValue: savedModeRaw) {
                self.currentMode = savedMode
            }
        }
        if appDefaults.object(forKey: DefaultsKey.isOpaque) != nil {
            self.isOpaque = appDefaults.bool(forKey: DefaultsKey.isOpaque)
        }
        if appDefaults.object(forKey: DefaultsKey.isAlwaysOnTop) != nil {
            self.isAlwaysOnTop = appDefaults.bool(forKey: DefaultsKey.isAlwaysOnTop)
        }
        if let savedLangRaw = appDefaults.string(forKey: DefaultsKey.language),
           let savedLang = AppLanguage(rawValue: savedLangRaw) {
            self.currentLanguage = savedLang
        }
    }
    
    private func saveCurrentState() {
        guard let window = self.window else { return }
        let frame = window.frame
        appDefaults.set(Double(frame.origin.x), forKey: DefaultsKey.windowX)
        appDefaults.set(Double(frame.origin.y), forKey: DefaultsKey.windowY)
        appDefaults.set(currentMode.rawValue, forKey: DefaultsKey.widgetMode)
        appDefaults.set(isOpaque, forKey: DefaultsKey.isOpaque)
        appDefaults.set(isAlwaysOnTop, forKey: DefaultsKey.isAlwaysOnTop)
        appDefaults.set(currentLanguage.rawValue, forKey: DefaultsKey.language)
        currentConfig.save()
        appDefaults.synchronize()
    }
    
    // NSWindowDelegate: 드래그 이동 시 위치 자동 기억
    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in
            self.saveCurrentState()
        }
    }
    
    private func setupWindow() {
        let initialSize = windowSize(for: currentMode)
        var initialFrame: NSRect
        
        // 이전 위치 복원
        if appDefaults.object(forKey: DefaultsKey.windowX) != nil &&
           appDefaults.object(forKey: DefaultsKey.windowY) != nil {
            let savedX = appDefaults.double(forKey: DefaultsKey.windowX)
            let savedY = appDefaults.double(forKey: DefaultsKey.windowY)
            let candidate = NSRect(x: savedX, y: savedY, width: initialSize.width, height: initialSize.height)
            
            // 모니터 해상도/연결 변경 시 화면 내 가시성 검증
            var isVisible = false
            for screen in NSScreen.screens {
                if screen.visibleFrame.intersects(candidate) {
                    isVisible = true
                    break
                }
            }
            if isVisible {
                initialFrame = candidate
            } else {
                let screen = NSScreen.main ?? NSScreen.screens.first!
                let visibleFrame = screen.visibleFrame
                let x = visibleFrame.midX - (initialSize.width / 2)
                let y = visibleFrame.maxY - initialSize.height
                initialFrame = NSRect(x: x, y: y, width: initialSize.width, height: initialSize.height)
            }
        } else {
            let screen = NSScreen.main ?? NSScreen.screens.first!
            let visibleFrame = screen.visibleFrame
            let x = visibleFrame.midX - (initialSize.width / 2)
            let y = visibleFrame.maxY - initialSize.height
            initialFrame = NSRect(x: x, y: y, width: initialSize.width, height: initialSize.height)
        }
        
        let panel = WidgetPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = isAlwaysOnTop ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        
        let modeBinding = Binding<WidgetMode>(
            get: { [weak self] in self?.currentMode ?? .standard },
            set: { [weak self] newMode in
                self?.setMode(newMode)
            }
        )
        
        let pinBinding = Binding<Bool>(
            get: { [weak self] in self?.isAlwaysOnTop ?? true },
            set: { [weak self] newValue in
                self?.isAlwaysOnTop = newValue
                self?.window.level = newValue ? .floating : .normal
                self?.saveCurrentState()
            }
        )
        
        let opaqueBinding = Binding<Bool>(
            get: { [weak self] in self?.isOpaque ?? false },
            set: { [weak self] newValue in
                self?.isOpaque = newValue
                self?.saveCurrentState()
                self?.setupStatusMenu()
            }
        )
        
        let languageBinding = Binding<AppLanguage>(
            get: { [weak self] in self?.currentLanguage ?? .en },
            set: { [weak self] newLang in
                self?.setLanguage(newLang)
            }
        )
        
        let configBinding = Binding<MetricConfig>(
            get: { [weak self] in self?.currentConfig ?? MetricConfig() },
            set: { [weak self] newConfig in
                self?.updateConfig(newConfig)
            }
        )
        
        let contentView = WidgetView(
            monitor: monitor,
            mode: modeBinding,
            isAlwaysOnTop: pinBinding,
            isOpaque: opaqueBinding,
            language: languageBinding,
            config: configBinding,
            onModeChange: { [weak self] newMode in
                self?.setMode(newMode)
            },
            onTogglePin: { [weak self] alwaysOnTop in
                self?.isAlwaysOnTop = alwaysOnTop
                self?.window.level = alwaysOnTop ? .floating : .normal
                self?.saveCurrentState()
            },
            onToggleDesktop: { [weak panel] pinnedToDesktop in
                panel?.level = pinnedToDesktop ? NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow))) : .floating
            },
            onLanguageChange: { [weak self] newLang in
                self?.setLanguage(newLang)
            },
            onConfigChange: { [weak self] newConfig in
                self?.updateConfig(newConfig)
            },
            onOpenAbout: { [weak self] in
                self?.showAboutPanel()
            },
            onClose: { [weak panel] in
                panel?.orderOut(nil)
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = NSRect(origin: .zero, size: initialSize)
        panel.contentView = hostingView
        
        panel.setFrame(initialFrame, display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        
        self.window = panel
    }
    
    private func windowSize(for mode: WidgetMode, config: MetricConfig? = nil) -> NSSize {
        let cfg = config ?? self.currentConfig
        switch mode {
        case .standard:
            let rows = max(1, (cfg.enabledCount + 1) / 2)
            return NSSize(width: 360, height: CGFloat(105 + rows * 95))
        case .compact:
            let width = max(280, CGFloat(80 + cfg.enabledCount * 55))
            return NSSize(width: width, height: 125)
        case .minimal:
            var width: CGFloat = 136
            if cfg.showCPU { width += 63 }
            if cfg.showGPU { width += 63 }
            if cfg.showRAM { width += 66 }
            if cfg.showDisk { width += 63 }
            if cfg.showNetwork { width += 78 }
            if cfg.showBattery { width += 61 }
            return NSSize(width: max(280, width), height: 28)
        }
    }
    
    public func updateConfig(_ newConfig: MetricConfig) {
        self.currentConfig = newConfig
        self.currentConfig.save()
        setupStatusMenu()
        applyCurrentWindowSize(animate: true)
    }
    
    private func applyCurrentWindowSize(animate: Bool = true) {
        guard let window = self.window else { return }
        let targetSize = windowSize(for: currentMode)
        var newFrame = window.frame
        
        let heightDiff = targetSize.height - newFrame.size.height
        let widthDiff = targetSize.width - newFrame.size.width
        newFrame.origin.y -= heightDiff
        newFrame.origin.x -= (widthDiff / 2)
        newFrame.size = targetSize
        
        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if newFrame.maxX > visible.maxX { newFrame.origin.x = visible.maxX - newFrame.width }
            if newFrame.minX < visible.minX { newFrame.origin.x = visible.minX }
            if newFrame.maxY > visible.maxY { newFrame.origin.y = visible.maxY - newFrame.height }
            if newFrame.minY < visible.minY { newFrame.origin.y = visible.minY }
        }
        
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
        }
    }
    
    public func setMode(_ newMode: WidgetMode) {
        guard self.window != nil, currentMode != newMode else { return }
        currentMode = newMode
        saveCurrentState()
        setupStatusMenu()
        applyCurrentWindowSize(animate: true)
    }
    
    public func setLanguage(_ newLang: AppLanguage) {
        guard currentLanguage != newLang else { return }
        currentLanguage = newLang
        saveCurrentState()
        setupStatusMenu()
    }
    
    private func setupStatusMenu() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CGPU Monitor")
                button.title = " CGPU"
                button.action = #selector(toggleWindow)
                button.target = self
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
        }
        
        let lang = currentLanguage
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: L10n.tr("Show in Center", "화면 중앙에 띄우기", for: lang), action: #selector(showAndCenterWindow), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: L10n.tr("Snap to Top (Under Menu Bar)", "화면 최상단(메뉴바 밑)으로 붙이기", for: lang), action: #selector(snapToTopCenter), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        
        let standardItem = NSMenuItem(title: L10n.tr("Standard Size", "보통 크기 (Standard)", for: lang), action: #selector(selectStandardMode), keyEquivalent: "1")
        standardItem.state = (currentMode == .standard) ? .on : .off
        menu.addItem(standardItem)
        
        let compactItem = NSMenuItem(title: L10n.tr("Compact Size", "작은 크기 (Compact)", for: lang), action: #selector(selectCompactMode), keyEquivalent: "2")
        compactItem.state = (currentMode == .compact) ? .on : .off
        menu.addItem(compactItem)
        
        let minimalItem = NSMenuItem(title: L10n.tr("Minimal Bar (Title Bar Height)", "완전 한줄 (Minimal)", for: lang), action: #selector(selectMinimalMode), keyEquivalent: "3")
        minimalItem.state = (currentMode == .minimal) ? .on : .off
        menu.addItem(minimalItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let opaqueItem = NSMenuItem(title: L10n.tr("Opaque Solid Background", "불투명 배경 사용", for: lang), action: #selector(toggleOpaque), keyEquivalent: "o")
        opaqueItem.state = isOpaque ? .on : .off
        menu.addItem(opaqueItem)
        
        let loginItem = NSMenuItem(title: L10n.tr("Launch at Login", "로그인 시 자동 실행", for: lang), action: #selector(toggleLaunchAtLogin), keyEquivalent: "l")
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 표시 메트릭 설정 서브메뉴
        let metricsSubmenu = NSMenu()
        
        let cpuItem = NSMenuItem(title: "CPU", action: #selector(toggleMetricCPU), keyEquivalent: "")
        cpuItem.state = currentConfig.showCPU ? .on : .off
        metricsSubmenu.addItem(cpuItem)
        
        let gpuItem = NSMenuItem(title: "GPU", action: #selector(toggleMetricGPU), keyEquivalent: "")
        gpuItem.state = currentConfig.showGPU ? .on : .off
        metricsSubmenu.addItem(gpuItem)
        
        let ramItem = NSMenuItem(title: "RAM", action: #selector(toggleMetricRAM), keyEquivalent: "")
        ramItem.state = currentConfig.showRAM ? .on : .off
        metricsSubmenu.addItem(ramItem)
        
        let diskItem = NSMenuItem(title: L10n.tr("SSD (Disk)", "SSD (디스크)", for: lang), action: #selector(toggleMetricDisk), keyEquivalent: "")
        diskItem.state = currentConfig.showDisk ? .on : .off
        metricsSubmenu.addItem(diskItem)
        
        let netItem = NSMenuItem(title: L10n.tr("Network", "네트워크", for: lang), action: #selector(toggleMetricNet), keyEquivalent: "")
        netItem.state = currentConfig.showNetwork ? .on : .off
        metricsSubmenu.addItem(netItem)
        
        let batItem = NSMenuItem(title: L10n.tr("Battery", "배터리", for: lang), action: #selector(toggleMetricBattery), keyEquivalent: "")
        batItem.state = currentConfig.showBattery ? .on : .off
        metricsSubmenu.addItem(batItem)
        
        let metricsMenuItem = NSMenuItem(title: L10n.tr("Displayed Metrics", "표시 항목 설정", for: lang), action: nil, keyEquivalent: "")
        metricsMenuItem.submenu = metricsSubmenu
        menu.addItem(metricsMenuItem)
        
        // 언어 서브메뉴
        let langSubmenu = NSMenu()
        let enItem = NSMenuItem(title: "English", action: #selector(selectEnglish), keyEquivalent: "")
        enItem.state = (currentLanguage == .en) ? .on : .off
        langSubmenu.addItem(enItem)
        
        let koItem = NSMenuItem(title: "한국어 (Korean)", action: #selector(selectKorean), keyEquivalent: "")
        koItem.state = (currentLanguage == .ko) ? .on : .off
        langSubmenu.addItem(koItem)
        
        let langMenuItem = NSMenuItem(title: L10n.tr("Language (언어)", "언어 (Language)", for: lang), action: nil, keyEquivalent: "")
        langMenuItem.submenu = langSubmenu
        menu.addItem(langMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 정보 (About CGPU Monitor)
        let aboutItem = NSMenuItem(title: L10n.tr("About CGPU Monitor", "CGPU Monitor 정보", for: lang), action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        menu.addItem(aboutItem)
        
        // 개발자 정보 (Author: krazyeom & Version)
        let authorItem = NSMenuItem(title: "\(AppVersion.fullDisplay) (by krazyeom)", action: #selector(openAuthorGithub), keyEquivalent: "")
        authorItem.image = NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: "Author")
        menu.addItem(authorItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.tr("Quit", "종료", for: lang), action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func showAboutPanel() {
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "CGPU Monitor",
            .applicationVersion: "Version \(AppVersion.version) (Build \(AppVersion.build))",
            .version: AppVersion.version,
            .credits: NSAttributedString(
                string: "Developed by krazyeom\nGitHub: https://github.com/krazyeom/cgpu\nLicensed under MIT License"
            ),
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright © 2026 krazyeom. All rights reserved."
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func toggleMetricCPU() { var c = currentConfig; c.toggle(.cpu); updateConfig(c) }
    @objc private func toggleMetricGPU() { var c = currentConfig; c.toggle(.gpu); updateConfig(c) }
    @objc private func toggleMetricRAM() { var c = currentConfig; c.toggle(.ram); updateConfig(c) }
    @objc private func toggleMetricDisk() { var c = currentConfig; c.toggle(.disk); updateConfig(c) }
    @objc private func toggleMetricNet() { var c = currentConfig; c.toggle(.network); updateConfig(c) }
    @objc private func toggleMetricBattery() { var c = currentConfig; c.toggle(.battery); updateConfig(c) }
    
    @objc private func openAuthorGithub() {
        if let url = URL(string: "https://github.com/krazyeom/cgpu") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func selectEnglish() { setLanguage(.en) }
    @objc private func selectKorean() { setLanguage(.ko) }
    
    @objc private func snapToTopCenter() {
        guard let window = self.window else { return }
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            let curSize = windowSize(for: currentMode)
            let x = visibleFrame.midX - (curSize.width / 2)
            let y = visibleFrame.maxY - curSize.height
            window.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: curSize), display: true, animate: true)
            saveCurrentState()
        }
    }
    
    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let bundlePath = Bundle.main.bundlePath
            let enable = (SMAppService.mainApp.status != .enabled)
            if enable {
                let script = "tell application \"System Events\" to make login item at end with properties {path:\"\(bundlePath)\", hidden:false}"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            } else {
                let script = "tell application \"System Events\" to delete (login items whose path is \"\(bundlePath)\")"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
        }
        setupStatusMenu()
    }
    
    @objc private func toggleOpaque() {
        isOpaque.toggle()
        saveCurrentState()
        setupStatusMenu()
    }
    
    @objc private func selectStandardMode() { setMode(.standard) }
    @objc private func selectCompactMode() { setMode(.compact) }
    @objc private func selectMinimalMode() { setMode(.minimal) }
    
    @objc private func toggleWindow() {
        guard let window = self.window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showAndCenterWindow()
        }
    }
    
    @objc private func showAndCenterWindow() {
        guard let window = self.window else { return }
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            let curSize = windowSize(for: currentMode)
            let x = visibleFrame.midX - (curSize.width / 2)
            let y = visibleFrame.midY + 40
            window.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: curSize), display: true, animate: true)
            saveCurrentState()
        }
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        saveCurrentState()
        NSApp.terminate(nil)
    }
}

@main
enum CGPUMonitorMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
