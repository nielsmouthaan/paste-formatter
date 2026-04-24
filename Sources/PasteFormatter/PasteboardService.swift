import AppKit
import PasteFormatterCore
import Foundation

enum ClipboardPayload {
    case attributed(NSAttributedString)
    case plainText(String)
}

struct PasteboardSnapshot {
    fileprivate let items: [PasteboardItemSnapshot]
}

struct PasteboardWriteReceipt {
    let changeCount: Int
    let ownershipToken: String
}

fileprivate struct PasteboardItemSnapshot {
    let entries: [PasteboardEntrySnapshot]

    init(item: NSPasteboardItem) {
        self.entries = item.types.compactMap { type in
            if let data = item.data(forType: type) {
                return PasteboardEntrySnapshot(type: type, value: .data(data))
            }

            if let string = item.string(forType: type) {
                return PasteboardEntrySnapshot(type: type, value: .string(string))
            }

            if let propertyList = item.propertyList(forType: type) {
                return PasteboardEntrySnapshot(type: type, value: .propertyList(propertyList))
            }

            return nil
        }
    }

    func makeItem() -> NSPasteboardItem {
        let item = NSPasteboardItem()

        for entry in entries {
            switch entry.value {
            case .data(let data):
                item.setData(data, forType: entry.type)
            case .string(let string):
                item.setString(string, forType: entry.type)
            case .propertyList(let propertyList):
                item.setPropertyList(propertyList, forType: entry.type)
            }
        }

        return item
    }
}

fileprivate struct PasteboardEntrySnapshot {
    enum Value {
        case data(Data)
        case string(String)
        case propertyList(Any)
    }

    let type: NSPasteboard.PasteboardType
    let value: Value
}

@MainActor
struct PasteboardService {
    private static let ownershipTokenType = NSPasteboard.PasteboardType(
        "\(Bundle.main.bundleIdentifier ?? "paste-formatter").temporary-content"
    )
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func captureSnapshot() -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map(PasteboardItemSnapshot.init)
        return PasteboardSnapshot(items: items)
    }

    func readCurrentContents() -> ClipboardPayload? {
        if let attributed = readAttributedString(for: .rtf, documentType: .rtf) {
            return .attributed(attributed)
        }

        if let attributed = readAttributedString(for: .html, documentType: .html) {
            return .attributed(attributed)
        }

        if let string = pasteboard.string(forType: .string) {
            return .plainText(string)
        }

        return nil
    }

    @discardableResult
    func write(_ payload: ClipboardPayload, options: PasteFormattingOptions) -> PasteboardWriteReceipt? {
        pasteboard.clearContents()
        let ownershipToken = UUID().uuidString

        switch payload {
        case .attributed(let attributedString):
            let fullRange = NSRange(location: 0, length: attributedString.length)

            guard let rtfData = try? attributedString.data(
                from: fullRange,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) else {
                return nil
            }

            let plainText = PlainTextFormatter.string(from: attributedString, options: options)
            let wroteRichText = pasteboard.setData(rtfData, forType: .rtf)
            let wrotePlainText = pasteboard.setString(plainText, forType: .string)
            let wroteOwnershipToken = pasteboard.setString(ownershipToken, forType: Self.ownershipTokenType)
            return wroteRichText && wrotePlainText && wroteOwnershipToken
                ? PasteboardWriteReceipt(changeCount: pasteboard.changeCount, ownershipToken: ownershipToken)
                : nil

        case .plainText(let string):
            let wrotePlainText = pasteboard.setString(string, forType: .string)
            let wroteOwnershipToken = pasteboard.setString(ownershipToken, forType: Self.ownershipTokenType)
            return wrotePlainText && wroteOwnershipToken
                ? PasteboardWriteReceipt(changeCount: pasteboard.changeCount, ownershipToken: ownershipToken)
                : nil
        }
    }

    @discardableResult
    func restoreSnapshot(_ snapshot: PasteboardSnapshot, ifMatches receipt: PasteboardWriteReceipt) -> Bool {
        guard pasteboard.changeCount == receipt.changeCount else {
            return false
        }

        guard pasteboard.string(forType: Self.ownershipTokenType) == receipt.ownershipToken else {
            return false
        }

        pasteboard.clearContents()

        guard !snapshot.items.isEmpty else {
            return true
        }

        let items = snapshot.items.map { $0.makeItem() }
        return pasteboard.writeObjects(items)
    }

    private func readAttributedString(
        for pasteboardType: NSPasteboard.PasteboardType,
        documentType: NSAttributedString.DocumentType
    ) -> NSAttributedString? {
        guard let data = pasteboard.data(forType: pasteboardType) else {
            return nil
        }

        var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: documentType
        ]

        if documentType == .html {
            options[.characterEncoding] = String.Encoding.utf8.rawValue
        }

        return try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        )
    }
}
