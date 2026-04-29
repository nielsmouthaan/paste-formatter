import AppKit
@testable import PasteFormatter
import PasteFormatterCore
import Foundation
import Testing

@MainActor
@Test func restoresOriginalClipboardWhenTemporaryContentIsStillPresent() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteFormatterTests.\(UUID().uuidString)"))
    let service = PasteboardService(pasteboard: pasteboard)

    pasteboard.clearContents()
    #expect(pasteboard.setString("Original clipboard", forType: .string))

    let snapshot = service.captureSnapshot()

    let temporaryReceipt = service.write(
        .plainText("Temporary clipboard"),
        options: PasteFormattingOptions()
    )

    #expect(temporaryReceipt != nil)
    #expect(pasteboard.string(forType: .string) == "Temporary clipboard")

    let restored = service.restoreSnapshot(snapshot, ifMatches: temporaryReceipt!)

    #expect(restored)
    #expect(pasteboard.string(forType: .string) == "Original clipboard")
}

@MainActor
@Test func doesNotRestoreClipboardIfItChangedAfterTemporaryPaste() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteFormatterTests.\(UUID().uuidString)"))
    let service = PasteboardService(pasteboard: pasteboard)

    pasteboard.clearContents()
    #expect(pasteboard.setString("Original clipboard", forType: .string))

    let snapshot = service.captureSnapshot()

    let temporaryReceipt = service.write(
        .plainText("Temporary clipboard"),
        options: PasteFormattingOptions()
    )

    #expect(temporaryReceipt != nil)
    pasteboard.clearContents()
    #expect(pasteboard.setString("User changed clipboard", forType: .string))

    let restored = service.restoreSnapshot(snapshot, ifMatches: temporaryReceipt!)

    #expect(!restored)
    #expect(pasteboard.string(forType: .string) == "User changed clipboard")
}

@MainActor
@Test func doesNotClearClipboardWhenAttributedContentCannotBeSerialized() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteFormatterTests.\(UUID().uuidString)"))
    let service = PasteboardService(pasteboard: pasteboard)

    pasteboard.clearContents()
    #expect(pasteboard.setString("Original clipboard", forType: .string))

    let temporaryReceipt = service.write(
        .attributed(FailingAttributedString(value: "Temporary clipboard")),
        options: PasteFormattingOptions()
    )

    #expect(temporaryReceipt == nil)
    #expect(pasteboard.string(forType: .string) == "Original clipboard")
}

@MainActor
@Test func emptyPasteboardDoesNotHaveContents() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteFormatterTests.\(UUID().uuidString)"))
    let service = PasteboardService(pasteboard: pasteboard)

    pasteboard.clearContents()

    #expect(!service.hasContents)
    #expect(service.readCurrentContents() == nil)
}

@MainActor
@Test func unsupportedPasteboardTypeStillCountsAsContents() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteFormatterTests.\(UUID().uuidString)"))
    let service = PasteboardService(pasteboard: pasteboard)
    let item = NSPasteboardItem()

    item.setData(Data([0, 1, 2, 3]), forType: NSPasteboard.PasteboardType("com.example.unsupported"))
    pasteboard.clearContents()
    #expect(pasteboard.writeObjects([item]))

    #expect(service.hasContents)
    #expect(service.readCurrentContents() == nil)
}

private final class FailingAttributedString: NSAttributedString {
    private let value: String

    init(value: String) {
        self.value = value
        super.init()
    }

    required init?(coder: NSCoder) {
        nil
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        nil
    }

    override var string: String {
        value
    }

    override func attributes(
        at location: Int,
        effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        [:]
    }

    override func data(
        from range: NSRange,
        documentAttributes dict: [NSAttributedString.DocumentAttributeKey: Any] = [:]
    ) throws -> Data {
        throw CocoaError(.fileWriteUnknown)
    }
}

@MainActor
@Test func imageClipboardWithHTMLPrefersNativePaste() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteFormatterTests.\(UUID().uuidString)"))
    let service = PasteboardService(pasteboard: pasteboard)
    let item = NSPasteboardItem()

    item.setData(Data([0, 1, 2, 3]), forType: .png)
    item.setString("<img src=\"image.png\">", forType: .html)
    pasteboard.clearContents()
    #expect(pasteboard.writeObjects([item]))

    #expect(service.hasContents)
    #expect(service.readCurrentContents() == nil)
}
