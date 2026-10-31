import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSPanel!
    private var statusItem: NSStatusItem!
    private let monitor = SystemMonitor()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock 아이콘을 숨기고 위젯/메뉴바 모드로 실행
        NSApp.setActivationPolicy(.accessory)
        
        setupWindow()
        setupStatusItem()
    }
    
    private func setupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 340, height: 260),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        
        // 화면 우측 상단 근처에 기본 배치
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let x = visibleFrame.maxX - 360
            let y = visibleFrame.maxY - 280
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        let contentView = WidgetView(
            monitor: monitor,
            onTogglePin: { [weak panel] alwaysOnTop in
                panel?.level = alwaysOnTop ? .floating : .normal
            },
            onToggleDesktop: { [weak panel] pinnedToDesktop in
                panel?.level = pinnedToDesktop ? NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow))) : .floating
            },
            onClose: { [weak panel] in
                panel?.orderOut(nil)
            }
        )
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.orderFront(nil)
        self.window = panel
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CGPU Monitor")
            button.action = #selector(toggleWindow)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "CGPU Monitor 열기 / 닫기", action: #selector(toggleWindow), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "위젯 위치 우측 상단으로 리셋", action: #selector(resetWindowPosition), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
            window.makeKey()
        }
    }
    
    @objc private func resetWindowPosition() {
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let x = visibleFrame.maxX - 360
            let y = visibleFrame.maxY - 280
            window.setFrameOrigin(NSPoint(x: x, y: y))
            window.orderFront(nil)
        }
    }
    
    @objc private func quitApp() {
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
