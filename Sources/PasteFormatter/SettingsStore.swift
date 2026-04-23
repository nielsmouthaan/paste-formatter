import PasteFormatterCore
import Foundation

final class SettingsStore {
    private enum Keys {
        static let preserveFont = "preserveFont"
        static let preserveColors = "preserveColors"
        static let preserveLinks = "preserveLinks"
        static let preserveListsInPlainText = "preserveListsInPlainText"
        static let preserveParagraphBreaksInPlainText = "preserveParagraphBreaksInPlainText"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.userDefaults.register(defaults: [
            Keys.preserveFont: false,
            Keys.preserveColors: false,
            Keys.preserveLinks: true,
            Keys.preserveListsInPlainText: true,
            Keys.preserveParagraphBreaksInPlainText: true,
            Keys.shortcutKeyCode: KeyboardShortcut.default.keyCode,
            Keys.shortcutModifiers: KeyboardShortcut.default.carbonModifiers
        ])
    }

    var options: PasteFormattingOptions {
        get {
            PasteFormattingOptions(
                preserveFont: userDefaults.bool(forKey: Keys.preserveFont),
                preserveColors: userDefaults.bool(forKey: Keys.preserveColors),
                preserveLinks: userDefaults.bool(forKey: Keys.preserveLinks),
                preserveListsInPlainText: userDefaults.bool(forKey: Keys.preserveListsInPlainText),
                preserveParagraphBreaksInPlainText: userDefaults.bool(forKey: Keys.preserveParagraphBreaksInPlainText)
            )
        }
        set {
            userDefaults.set(newValue.preserveFont, forKey: Keys.preserveFont)
            userDefaults.set(newValue.preserveColors, forKey: Keys.preserveColors)
            userDefaults.set(newValue.preserveLinks, forKey: Keys.preserveLinks)
            userDefaults.set(newValue.preserveListsInPlainText, forKey: Keys.preserveListsInPlainText)
            userDefaults.set(
                newValue.preserveParagraphBreaksInPlainText,
                forKey: Keys.preserveParagraphBreaksInPlainText
            )
        }
    }

    var keyboardShortcut: KeyboardShortcut {
        get {
            let keyCode = userDefaults.object(forKey: Keys.shortcutKeyCode) as? NSNumber
            let modifiers = userDefaults.object(forKey: Keys.shortcutModifiers) as? NSNumber

            guard
                let keyCode,
                let modifiers,
                KeyboardShortcut.fromStorageToken("\(keyCode.uint32Value):\(modifiers.uint32Value)") != nil
            else {
                return .default
            }

            return KeyboardShortcut(
                keyCode: keyCode.uint32Value,
                carbonModifiers: modifiers.uint32Value
            )
        }
        set {
            userDefaults.set(newValue.keyCode, forKey: Keys.shortcutKeyCode)
            userDefaults.set(newValue.carbonModifiers, forKey: Keys.shortcutModifiers)
        }
    }
}
