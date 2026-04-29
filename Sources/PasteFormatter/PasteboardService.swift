import AppKit
import PasteFormatterCore
import Foundation
import UniformTypeIdentifiers

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

    var hasContents: Bool {
        guard let items = pasteboard.pasteboardItems else {
            return false
        }

        return items.contains { !$0.types.isEmpty }
    }

    func readCurrentContents() -> ClipboardPayload? {
        guard !prefersNativePaste else {
            return nil
        }

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
        let ownershipToken = UUID().uuidString
        guard let item = makePasteboardItem(
            for: payload,
            options: options,
            ownershipToken: ownershipToken
        ) else {
            return nil
        }

        let snapshot = captureSnapshot()
        pasteboard.clearContents()

        guard pasteboard.writeObjects([item]) else {
            restoreSnapshot(snapshot)
            return nil
        }

        return PasteboardWriteReceipt(changeCount: pasteboard.changeCount, ownershipToken: ownershipToken)
    }

    private func makePasteboardItem(
        for payload: ClipboardPayload,
        options: PasteFormattingOptions,
        ownershipToken: String
    ) -> NSPasteboardItem? {
        let item = NSPasteboardItem()

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
            let wroteRichText = item.setData(rtfData, forType: .rtf)
            let wrotePlainText = item.setString(plainText, forType: .string)
            let wroteOwnershipToken = item.setString(ownershipToken, forType: Self.ownershipTokenType)
            return wroteRichText && wrotePlainText && wroteOwnershipToken ? item : nil

        case .plainText(let string):
            let wrotePlainText = item.setString(string, forType: .string)
            let wroteOwnershipToken = item.setString(ownershipToken, forType: Self.ownershipTokenType)
            return wrotePlainText && wroteOwnershipToken ? item : nil
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

    @discardableResult
    private func restoreSnapshot(_ snapshot: PasteboardSnapshot) -> Bool {
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

    private var prefersNativePaste: Bool {
        guard let items = pasteboard.pasteboardItems else {
            return false
        }

        return items.contains { item in
            item.types.contains { type in
                guard let uniformType = UTType(type.rawValue) else {
                    return false
                }

                return uniformType.conforms(to: .image)
                    || uniformType.conforms(to: .pdf)
                    || uniformType.conforms(to: .fileURL)
            }
        }
    }
}
