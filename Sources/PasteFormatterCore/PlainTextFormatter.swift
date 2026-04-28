import AppKit
import Foundation

public enum PlainTextFormatter {
    public static func string(
        from input: NSAttributedString,
        options: PasteFormattingOptions
    ) -> String {
        let normalizedPlainText = normalizedLineSeparators(in: input.string)

        guard options.preserveParagraphBreaksInPlainText else {
            return normalizedPlainText
        }

        let source = input.string as NSString
        guard source.length > 0 else {
            return ""
        }

        let result = NSMutableString(string: normalizedPlainText)
        var insertedCharacters = 0
        var location = 0
        var listState = PlainTextListState()

        while location < source.length {
            let paragraphRange = source.paragraphRange(for: NSRange(location: location, length: 0))
            let paragraphStyle = input.attribute(
                .paragraphStyle,
                at: paragraphRange.location,
                effectiveRange: nil
            ) as? NSParagraphStyle
            let currentListSignature = textListSignature(for: paragraphStyle)

            if usesExpandedParagraphBreak(beforeParagraphAt: paragraphRange.location, in: input) {
                let insertionIndex = paragraphRange.location + insertedCharacters
                result.insert("\n", at: insertionIndex)
                insertedCharacters += 1
            }

            if options.preserveListsInPlainText, currentListSignature != nil {
                let itemNumber = listState.nextItemNumber(for: paragraphStyle)
                if let markerInsertion = listMarkerInsertion(
                    in: input,
                    paragraphRange: paragraphRange,
                    itemNumber: itemNumber
                ) {
                    result.insert(
                        markerInsertion.text,
                        at: paragraphRange.location + markerInsertion.offset + insertedCharacters
                    )
                    insertedCharacters += (markerInsertion.text as NSString).length
                }
            } else {
                listState.reset()
            }

            location = NSMaxRange(paragraphRange)
        }

        return result as String
    }

    private static func normalizedLineSeparators(in string: String) -> String {
        string
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
    }

    private static func usesExpandedParagraphBreak(
        beforeParagraphAt location: Int,
        in input: NSAttributedString
    ) -> Bool {
        guard input.length > 0, location > 0 else {
            return false
        }

        let source = input.string as NSString
        let previousParagraphStart = source.paragraphRange(for: NSRange(location: location - 1, length: 0)).location
        let currentParagraphStart = source.paragraphRange(
            for: NSRange(location: min(location, max(source.length - 1, 0)), length: 0)
        ).location

        let previousStyle = input.attribute(
            .paragraphStyle,
            at: previousParagraphStart,
            effectiveRange: nil
        ) as? NSParagraphStyle

        let currentStyle = input.attribute(
            .paragraphStyle,
            at: currentParagraphStart,
            effectiveRange: nil
        ) as? NSParagraphStyle

        if isWithinSameTextList(previousStyle: previousStyle, currentStyle: currentStyle) {
            return false
        }

        return (previousStyle?.paragraphSpacing ?? 0) > 0 || (currentStyle?.paragraphSpacingBefore ?? 0) > 0
    }

    private static func isWithinSameTextList(
        previousStyle: NSParagraphStyle?,
        currentStyle: NSParagraphStyle?
    ) -> Bool {
        let previousSignature = textListSignature(for: previousStyle)
        let currentSignature = textListSignature(for: currentStyle)

        return previousSignature != nil && previousSignature == currentSignature
    }

    private static func textListSignature(for style: NSParagraphStyle?) -> String? {
        guard let textLists = style?.textLists, !textLists.isEmpty else {
            return nil
        }

        return textLists
            .map { "\($0.markerFormat)" }
            .joined(separator: "|")
    }

    private static func listMarkerInsertion(
        in input: NSAttributedString,
        paragraphRange: NSRange,
        itemNumber: Int
    ) -> PlainTextInsertion? {
        guard
            let paragraphStyle = input.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle,
            let textList = paragraphStyle.textLists.last
        else {
            return nil
        }

        let source = input.string as NSString
        let paragraphText = source.substring(with: paragraphRange)
        let trimmedParagraphText = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawMarker = textList.marker(forItemNumber: itemNumber)
        let marker = normalizedMarker(rawMarker, for: textList)

        guard !trimmedParagraphText.isEmpty else {
            return nil
        }

        if trimmedParagraphText.hasPrefix(marker) {
            return nil
        }

        if let suffixInsertion = missingMarkerSuffixInsertion(
            in: paragraphText,
            rawMarker: rawMarker,
            normalizedMarker: marker
        ) {
            return suffixInsertion
        }

        if trimmedParagraphText.hasPrefix(rawMarker) {
            return nil
        }

        let level = paragraphStyle.textLists.count
        let indentation = String(repeating: "  ", count: max(level - 1, 0))
        return PlainTextInsertion(text: "\(indentation)\(marker) ", offset: 0)
    }

    private static func missingMarkerSuffixInsertion(
        in paragraphText: String,
        rawMarker: String,
        normalizedMarker: String
    ) -> PlainTextInsertion? {
        guard
            normalizedMarker.hasPrefix(rawMarker),
            normalizedMarker != rawMarker,
            let contentStart = paragraphText.firstIndex(where: { !$0.isWhitespace && !$0.isNewline })
        else {
            return nil
        }

        let content = paragraphText[contentStart...]

        guard content.hasPrefix(rawMarker) else {
            return nil
        }

        let markerEnd = content.index(content.startIndex, offsetBy: rawMarker.count)
        guard markerEnd < content.endIndex, content[markerEnd].isWhitespace else {
            return nil
        }

        let suffix = String(normalizedMarker.dropFirst(rawMarker.count))
        let offset = paragraphText.utf16.distance(from: paragraphText.startIndex, to: markerEnd)
        return PlainTextInsertion(text: suffix, offset: offset)
    }

    private static func normalizedMarker(_ marker: String, for textList: NSTextList) -> String {
        let markerFormat = "\(textList.markerFormat)"

        if markerFormat.contains("hyphen") || marker == "\u{2043}" {
            return "-"
        }

        if markerFormat.contains("decimal")
            || markerFormat.contains("alpha")
            || markerFormat.contains("roman"),
            !markerHasTrailingPunctuation(marker) {
            return "\(marker)."
        }

        return marker
    }

    private static func markerHasTrailingPunctuation(_ marker: String) -> Bool {
        guard let last = marker.last else {
            return false
        }

        return [".", ")", ":", ";"].contains(last)
    }
}

private struct PlainTextInsertion {
    let text: String
    let offset: Int
}

private struct PlainTextListState {
    private var previousSignatures: [String] = []
    private var counters: [Int] = []

    mutating func nextItemNumber(for style: NSParagraphStyle?) -> Int {
        guard let signatures = textListSignatures(for: style), !signatures.isEmpty else {
            reset()
            return 0
        }

        let level = signatures.count
        let commonPrefixLength = zip(previousSignatures, signatures).prefix { previous, current in
            previous == current
        }.count

        if commonPrefixLength < level {
            counters = Array(counters.prefix(commonPrefixLength))
            while counters.count < level {
                counters.append(0)
            }
            counters[level - 1] = 1
        } else {
            counters = Array(counters.prefix(level))
            counters[level - 1] += 1
        }

        previousSignatures = signatures
        return counters[level - 1]
    }

    mutating func reset() {
        previousSignatures = []
        counters = []
    }

    private func textListSignatures(for style: NSParagraphStyle?) -> [String]? {
        guard let textLists = style?.textLists, !textLists.isEmpty else {
            return nil
        }

        return textLists.map { "\($0.markerFormat)" }
    }
}
