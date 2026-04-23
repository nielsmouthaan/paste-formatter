import AppKit
import PasteFormatterCore
import Foundation
import ServiceManagement

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let settingsStore: SettingsStore
    private let pasteboardService: PasteboardService
    private let pasteExecutor: PasteActionExecutor
    private let launchAtLoginService: LaunchAtLoginService
    private let applyShortcut: @MainActor (KeyboardShortcut) -> Bool
    private let shortcutRecorder = KeyboardShortcutRecorder()
    private let repositoryURL = URL(string: "https://github.com/nielsmouthaan/paste-formatter")!

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private lazy var pasteItem: NSMenuItem = {
        let item = NSMenuItem(title: "Paste", action: #selector(handlePasteMenuItem), keyEquivalent: "v")
        item.keyEquivalentModifierMask = [.control, .option, .command]
        item.target = self
        return item
    }()

    private lazy var preserveFontItem = makeToggleItem(
        title: "Preserve font",
        action: #selector(togglePreserveFont)
    )

    private lazy var preserveColorsItem = makeToggleItem(
        title: "Preserve colors",
        action: #selector(togglePreserveColors)
    )

    private lazy var preserveLinksItem = makeToggleItem(
        title: "Preserve links",
        action: #selector(togglePreserveLinks)
    )

    private lazy var preserveListsInPlainTextItem = makeToggleItem(
        title: "Preserve lists in plain text",
        action: #selector(togglePreserveListsInPlainText)
    )

    private lazy var preserveParagraphBreaksInPlainTextItem = makeToggleItem(
        title: "Preserve paragraph breaks in plain text",
        action: #selector(togglePreserveParagraphBreaksInPlainText)
    )

    private lazy var launchAtLoginItem = makeToggleItem(
        title: "Launch at login",
        action: #selector(toggleLaunchAtLogin)
    )

    private lazy var keyboardShortcutItem = makeActionItem(
        title: "Change keyboard shortcut…",
        action: #selector(customizeShortcut)
    )

    init(
        settingsStore: SettingsStore,
        pasteboardService: PasteboardService,
        pasteExecutor: PasteActionExecutor,
        launchAtLoginService: LaunchAtLoginService,
        applyShortcut: @escaping @MainActor (KeyboardShortcut) -> Bool
    ) {
        self.settingsStore = settingsStore
        self.pasteboardService = pasteboardService
        self.pasteExecutor = pasteExecutor
        self.launchAtLoginService = launchAtLoginService
        self.applyShortcut = applyShortcut
    }

    func start() {
        configureStatusItem()
        configureMenu()
        refreshMenuState()
    }

    func performFormattedPaste() {
        guard let payload = pasteboardService.readCurrentContents() else {
            NSSound.beep()
            presentAlert(
                title: "Nothing to paste",
                message: "Paste Formatter only handles plain text, RTF, and HTML clipboard content."
            )
            return
        }

        let originalClipboard = pasteboardService.captureSnapshot()
        let temporaryClipboardWriteReceipt: PasteboardWriteReceipt?
        let options = settingsStore.options
        switch payload {
        case .attributed(let attributedString):
            let cleaned = RichTextCleaner.clean(attributedString, options: options)
            temporaryClipboardWriteReceipt = pasteboardService.write(.attributed(cleaned), options: options)
        case .plainText(let string):
            temporaryClipboardWriteReceipt = pasteboardService.write(.plainText(string), options: options)
        }

        guard let temporaryClipboardWriteReceipt else {
            NSSound.beep()
            presentAlert(
                title: "Paste failed",
                message: "Paste Formatter could not write the transformed content back to the clipboard."
            )
            return
        }

        Task { @MainActor [weak self, pasteExecutor] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self else {
                return
            }

            if pasteExecutor.executePaste() {
                Task { @MainActor [pasteboardService] in
                    try? await Task.sleep(for: .seconds(1))
                    _ = pasteboardService.restoreSnapshot(
                        originalClipboard,
                        ifMatches: temporaryClipboardWriteReceipt
                    )
                }
            } else {
                self.presentAlert(
                    title: "Accessibility permission required",
                    message: "Grant Accessibility permissions in System Settings to allow Paste Formatter to paste."
                )
            }
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste Formatter") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "Paste"
        }

        button.toolTip = "Paste Formatter"
    }

    private func configureMenu() {
        menu.removeAllItems()
        menu.delegate = self
        menu.addItem(pasteItem)
        menu.addItem(.separator())
        menu.addItem(preserveFontItem)
        menu.addItem(preserveColorsItem)
        menu.addItem(preserveLinksItem)
        menu.addItem(preserveListsInPlainTextItem)
        menu.addItem(preserveParagraphBreaksInPlainTextItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
        menu.addItem(keyboardShortcutItem)
        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About Paste Formatter", action: #selector(handleAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit Paste Formatter", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func refreshMenuState() {
        let options = settingsStore.options
        let shortcut = settingsStore.keyboardShortcut

        preserveFontItem.state = options.preserveFont ? .on : .off
        preserveColorsItem.state = options.preserveColors ? .on : .off
        preserveLinksItem.state = options.preserveLinks ? .on : .off
        preserveListsInPlainTextItem.state = options.preserveListsInPlainText ? .on : .off
        preserveParagraphBreaksInPlainTextItem.state = options.preserveParagraphBreaksInPlainText ? .on : .off
        pasteItem.keyEquivalent = shortcut.keyEquivalent
        pasteItem.keyEquivalentModifierMask = shortcut.menuModifierMask

        switch launchAtLoginService.status {
        case .enabled:
            launchAtLoginItem.title = "Launch at login"
            launchAtLoginItem.state = .on
        case .requiresApproval:
            launchAtLoginItem.title = "Launch at login (needs approval)"
            launchAtLoginItem.state = .on
        case .notRegistered, .notFound:
            launchAtLoginItem.title = "Launch at login"
            launchAtLoginItem.state = .off
        @unknown default:
            launchAtLoginItem.title = "Launch at login"
            launchAtLoginItem.state = .off
        }
    }

    private func makeToggleItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func makeActionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func updateOptions(_ mutate: (inout PasteFormattingOptions) -> Void) {
        var options = settingsStore.options
        mutate(&options)
        settingsStore.options = options
        refreshMenuState()
    }

    private func setKeyboardShortcut(_ shortcut: KeyboardShortcut) {
        guard applyShortcut(shortcut) else {
            NSSound.beep()
            presentAlert(
                title: "Shortcut unavailable",
                message: "Paste Formatter could not register that keyboard shortcut. Try a different combination."
            )
            return
        }

        settingsStore.keyboardShortcut = shortcut
        refreshMenuState()
    }

    private func presentAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuState()
    }

    @objc private func handlePasteMenuItem() {
        performFormattedPaste()
    }

    @objc private func togglePreserveFont() {
        updateOptions { options in
            options.preserveFont.toggle()
        }
    }

    @objc private func togglePreserveColors() {
        updateOptions { options in
            options.preserveColors.toggle()
        }
    }

    @objc private func togglePreserveLinks() {
        updateOptions { options in
            options.preserveLinks.toggle()
        }
    }

    @objc private func togglePreserveListsInPlainText() {
        updateOptions { options in
            options.preserveListsInPlainText.toggle()
        }
    }

    @objc private func togglePreserveParagraphBreaksInPlainText() {
        updateOptions { options in
            options.preserveParagraphBreaksInPlainText.toggle()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let targetState = !launchAtLoginService.isEnabled
        let result = launchAtLoginService.setEnabled(targetState)

        switch result {
        case .success:
            refreshMenuState()

            if launchAtLoginService.status == .requiresApproval {
                presentAlert(
                    title: "Approval needed",
                    message: "Paste Formatter was registered as a login item, but macOS still requires approval in System Settings > General > Login Items."
                )
            }
        case .failure(let error):
            NSSound.beep()
            presentAlert(
                title: "Could not update login item",
                message: error.localizedDescription
            )
            refreshMenuState()
        }
    }

    @objc private func customizeShortcut() {
        guard let shortcut = shortcutRecorder.recordShortcut(current: settingsStore.keyboardShortcut) else {
            return
        }

        setKeyboardShortcut(shortcut)
    }

    @objc private func handleAbout() {
        NSWorkspace.shared.open(repositoryURL)
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
