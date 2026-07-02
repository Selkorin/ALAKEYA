import AppKit
import SwiftUI

// ============================================================
// StatusBarController.swift
// Menu bar icon with a minimal dropdown.
// ============================================================

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var widgetEverShown = false

    var onToggleWidget: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = makeIcon()
        statusItem.button?.toolTip = "Alakeya"
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // ── Menu ──────────────────────────────────────────────

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let widgetItem = NSMenuItem(
            title: widgetEverShown ? "Показать виджет" : "Добавить виджет",
            action: #selector(handleWidgetItem),
            keyEquivalent: "")
        widgetItem.target = self
        menu.addItem(widgetItem)

        let settingsItem = NSMenuItem(
            title: "Настройки",
            action: #selector(handleSettings),
            keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem(
            title: "Выйти",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"))

        return menu
    }

    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in
            menu.items.first?.title = self.widgetEverShown ? "Показать виджет" : "Добавить виджет"
        }
    }

    @objc private func handleWidgetItem() {
        widgetEverShown = true
        onToggleWidget?()
    }

    @objc private func handleSettings() { onOpenSettings?() }

    // ── Icon ──────────────────────────────────────────────

    private func makeIcon() -> NSImage {
        let iconSize = NSSize(width: 18, height: 18)
        guard let url = Bundle.module.url(forResource: "pers_1", withExtension: "png"),
              let source = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "Alakeya")
                ?? NSImage(size: iconSize)
        }

        let icon = NSImage(size: iconSize)
        icon.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: iconSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        icon.unlockFocus()
        icon.isTemplate = false
        return icon
    }
}
