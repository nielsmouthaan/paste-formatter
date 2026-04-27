import AppKit
import Carbon.HIToolbox
import Foundation

struct KeyboardShortcut: Equatable, Sendable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    static let `default` = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(optionKey) | UInt32(cmdKey)
    )

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init?(recording event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.supportedShortcutModifiers)
        let keyCode = UInt32(event.keyCode)
        guard Self.keyEquivalent(for: keyCode) != nil else {
            return nil
        }

        self.init(keyCode: keyCode, carbonModifiers: Self.carbonModifiers(from: modifiers))
    }

    var menuModifierMask: NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []

        if carbonModifiers & UInt32(cmdKey) != 0 {
            mask.insert(.command)
        }

        if carbonModifiers & UInt32(optionKey) != 0 {
            mask.insert(.option)
        }

        if carbonModifiers & UInt32(controlKey) != 0 {
            mask.insert(.control)
        }

        if carbonModifiers & UInt32(shiftKey) != 0 {
            mask.insert(.shift)
        }

        return mask
    }

    var keyEquivalent: String {
        Self.keyEquivalent(for: keyCode) ?? ""
    }

    var displayString: String {
        let modifierGlyphs = [
            (UInt32(controlKey), "⌃"),
            (UInt32(optionKey), "⌥"),
            (UInt32(shiftKey), "⇧"),
            (UInt32(cmdKey), "⌘")
        ]
        .filter { carbonModifiers & $0.0 != 0 }
        .map(\.1)
        .joined()

        return modifierGlyphs + Self.displayKey(for: keyCode)
    }

    var storageToken: String {
        "\(keyCode):\(carbonModifiers)"
    }

    static func fromStorageToken(_ token: String) -> KeyboardShortcut? {
        let components = token.split(separator: ":", omittingEmptySubsequences: false)
        guard
            components.count == 2,
            let keyCode = UInt32(components[0]),
            let carbonModifiers = UInt32(components[1]),
            keyEquivalent(for: keyCode) != nil
        else {
            return nil
        }

        return KeyboardShortcut(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0

        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }

        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        return modifiers
    }

    private static func keyEquivalent(for keyCode: UInt32) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: "a"
        case kVK_ANSI_B: "b"
        case kVK_ANSI_C: "c"
        case kVK_ANSI_D: "d"
        case kVK_ANSI_E: "e"
        case kVK_ANSI_F: "f"
        case kVK_ANSI_G: "g"
        case kVK_ANSI_H: "h"
        case kVK_ANSI_I: "i"
        case kVK_ANSI_J: "j"
        case kVK_ANSI_K: "k"
        case kVK_ANSI_L: "l"
        case kVK_ANSI_M: "m"
        case kVK_ANSI_N: "n"
        case kVK_ANSI_O: "o"
        case kVK_ANSI_P: "p"
        case kVK_ANSI_Q: "q"
        case kVK_ANSI_R: "r"
        case kVK_ANSI_S: "s"
        case kVK_ANSI_T: "t"
        case kVK_ANSI_U: "u"
        case kVK_ANSI_V: "v"
        case kVK_ANSI_W: "w"
        case kVK_ANSI_X: "x"
        case kVK_ANSI_Y: "y"
        case kVK_ANSI_Z: "z"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_ANSI_Minus: "-"
        case kVK_ANSI_Equal: "="
        case kVK_ANSI_LeftBracket: "["
        case kVK_ANSI_RightBracket: "]"
        case kVK_ANSI_Semicolon: ";"
        case kVK_ANSI_Quote: "'"
        case kVK_ANSI_Comma: ","
        case kVK_ANSI_Period: "."
        case kVK_ANSI_Slash: "/"
        case kVK_ANSI_Grave: "`"
        default: nil
        }
    }

    private static func displayKey(for keyCode: UInt32) -> String {
        keyEquivalent(for: keyCode)?.uppercased() ?? "?"
    }
}

private extension NSEvent.ModifierFlags {
    static let supportedShortcutModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
}
