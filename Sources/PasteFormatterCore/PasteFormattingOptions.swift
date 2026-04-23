import Foundation

public struct PasteFormattingOptions: Sendable, Equatable {
    public var preserveFont: Bool
    public var preserveColors: Bool
    public var preserveLinks: Bool
    public var preserveListsInPlainText: Bool
    public var preserveParagraphBreaksInPlainText: Bool

    public init(
        preserveFont: Bool = false,
        preserveColors: Bool = false,
        preserveLinks: Bool = true,
        preserveListsInPlainText: Bool = true,
        preserveParagraphBreaksInPlainText: Bool = true
    ) {
        self.preserveFont = preserveFont
        self.preserveColors = preserveColors
        self.preserveLinks = preserveLinks
        self.preserveListsInPlainText = preserveListsInPlainText
        self.preserveParagraphBreaksInPlainText = preserveParagraphBreaksInPlainText
    }
}
