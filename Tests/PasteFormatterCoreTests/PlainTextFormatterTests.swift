import AppKit
import PasteFormatterCore
import Foundation
import Testing

@Test func preservesDefaultPlainTextWhenParagraphBreakExpansionIsDisabled() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 18

    let input = NSMutableAttributedString(string: "First paragraph\nSecond paragraph")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions(preserveParagraphBreaksInPlainText: false)
    )

    #expect(output == "First paragraph\nSecond paragraph")
}

@Test func expandsParagraphBreaksWhenSourceUsesParagraphSpacing() {
    let firstParagraphStyle = NSMutableParagraphStyle()
    firstParagraphStyle.paragraphSpacing = 14

    let input = NSMutableAttributedString(string: "First paragraph\nSecond paragraph")
    input.addAttribute(
        .paragraphStyle,
        value: firstParagraphStyle,
        range: NSRange(location: 0, length: "First paragraph".count)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "First paragraph\n\nSecond paragraph")
}

@Test func keepsSingleParagraphBreaksWhenNoParagraphSpacingExists() {
    let input = NSAttributedString(string: "First paragraph\nSecond paragraph")

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "First paragraph\nSecond paragraph")
}

@Test func preservesExistingPlainTextContentWhileAddingParagraphBreaks() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 14

    let input = NSMutableAttributedString(string: "\u{2022}\tFirst item\nSecond paragraph")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: "\u{2022}\tFirst item".count)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "\u{2022}\tFirst item\n\nSecond paragraph")
}

@Test func doesNotExpandParagraphBreaksBetweenItemsInSameTextList() {
    let list = NSTextList(markerFormat: .disc, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 14
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "\u{2022} First item\n\u{2022} Second item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "\u{2022} First item\n\u{2022} Second item")
}

@Test func materializesMissingBulletMarkersForTextListParagraphs() {
    let list = NSTextList(markerFormat: .disc, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "First item\nSecond item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "\u{2022} First item\n\u{2022} Second item")
}

@Test func materializesNumberedTextListParagraphsWithIncrementingCounters() {
    let list = NSTextList(markerFormat: .decimal, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "First item\nSecond item\nThird item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "1. First item\n2. Second item\n3. Third item")
}

@Test func materializesCommonUnorderedTextListMarkerFormats() {
    let cases: [(NSTextList.MarkerFormat, String)] = [
        (.hyphen, "-"),
        (.disc, "\u{2022}"),
        (.circle, "\u{25E6}"),
        (.square, "\u{25AA}"),
        (.box, "\u{25AB}"),
        (.check, "\u{2713}")
    ]

    for (markerFormat, expectedMarker) in cases {
        let output = formattedListOutput(markerFormat: markerFormat, itemCount: 2)

        #expect(output == "\(expectedMarker) First item\n\(expectedMarker) Second item")
    }
}

@Test func materializesCommonOrderedTextListMarkerFormats() {
    let cases: [(NSTextList.MarkerFormat, String)] = [
        (.decimal, "1. First item\n2. Second item\n3. Third item"),
        (NSTextList.MarkerFormat("{decimal})"), "1) First item\n2) Second item\n3) Third item"),
        (.uppercaseAlpha, "A. First item\nB. Second item\nC. Third item"),
        (.lowercaseAlpha, "a. First item\nb. Second item\nc. Third item"),
        (NSTextList.MarkerFormat("{lower-alpha})"), "a) First item\nb) Second item\nc) Third item"),
        (.uppercaseRoman, "I. First item\nII. Second item\nIII. Third item"),
        (.lowercaseRoman, "i. First item\nii. Second item\niii. Third item")
    ]

    for (markerFormat, expectedOutput) in cases {
        let output = formattedListOutput(markerFormat: markerFormat, itemCount: 3)

        #expect(output == expectedOutput)
    }
}

@Test func addsMissingDecimalPunctuationToExistingNumberedMarkers() {
    let list = NSTextList(markerFormat: .decimal, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "1\tFirst item\n2\tSecond item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "1.\tFirst item\n2.\tSecond item")
}

@Test func addsMissingOrderedPunctuationToExistingAlphaAndRomanMarkers() {
    let cases: [(NSTextList.MarkerFormat, String, String)] = [
        (.uppercaseAlpha, "A\tFirst item\nB\tSecond item", "A.\tFirst item\nB.\tSecond item"),
        (.lowercaseAlpha, "a\tFirst item\nb\tSecond item", "a.\tFirst item\nb.\tSecond item"),
        (.uppercaseRoman, "I\tFirst item\nII\tSecond item", "I.\tFirst item\nII.\tSecond item"),
        (.lowercaseRoman, "i\tFirst item\nii\tSecond item", "i.\tFirst item\nii.\tSecond item")
    ]

    for (markerFormat, inputString, expectedOutput) in cases {
        let list = NSTextList(markerFormat: markerFormat, options: 0)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.textLists = [list]

        let input = NSMutableAttributedString(string: inputString)
        input.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: input.length)
        )

        let output = PlainTextFormatter.string(
            from: input,
            options: PasteFormattingOptions()
        )

        #expect(output == expectedOutput)
    }
}

@Test func preservesExistingUnorderedMarkersWhenMarkerFormatNormalizes() {
    let list = NSTextList(markerFormat: .hyphen, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "\u{2043}\tFirst item\n\u{2043}\tSecond item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "\u{2043}\tFirst item\n\u{2043}\tSecond item")
}

@Test func addsMissingOrderedPunctuationAfterIndentedExistingMarkers() {
    let list = NSTextList(markerFormat: .decimal, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "  1\tNested item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "  1.\tNested item")
}

@Test func preservesNestedTextListStructureWithPlainTextIndentation() {
    let numberedList = NSTextList(markerFormat: .decimal, options: 0)
    let bulletList = NSTextList(markerFormat: .hyphen, options: 0)
    let numberedStyle = NSMutableParagraphStyle()
    numberedStyle.textLists = [numberedList]
    let nestedBulletStyle = NSMutableParagraphStyle()
    nestedBulletStyle.textLists = [numberedList, bulletList]

    let input = NSMutableAttributedString(string: "Daily\nasfd\nEjectify\nasdfasdf\nBackup Status")
    input.addAttribute(
        .paragraphStyle,
        value: numberedStyle,
        range: NSRange(location: 0, length: "Daily".count)
    )
    input.addAttribute(
        .paragraphStyle,
        value: nestedBulletStyle,
        range: NSRange(location: "Daily\n".count, length: "asfd".count)
    )
    input.addAttribute(
        .paragraphStyle,
        value: numberedStyle,
        range: NSRange(location: "Daily\nasfd\n".count, length: "Ejectify".count)
    )
    input.addAttribute(
        .paragraphStyle,
        value: nestedBulletStyle,
        range: NSRange(location: "Daily\nasfd\nEjectify\n".count, length: "asdfasdf".count)
    )
    input.addAttribute(
        .paragraphStyle,
        value: numberedStyle,
        range: NSRange(location: "Daily\nasfd\nEjectify\nasdfasdf\n".count, length: "Backup Status".count)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "1. Daily\n  - asfd\n2. Ejectify\n  - asdfasdf\n3. Backup Status")
}

@Test func doesNotAddExtraPeriodToPunctuatedNumberedMarkers() {
    let list = NSTextList(markerFormat: NSTextList.MarkerFormat("{decimal})"), options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "First item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "1) First item")
}

@Test func doesNotMaterializeMissingBulletMarkersWhenListPreservationIsDisabled() {
    let list = NSTextList(markerFormat: .disc, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "First item\nSecond item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions(preserveListsInPlainText: false)
    )

    #expect(output == "First item\nSecond item")
}

@Test func doesNotDuplicateExistingBulletMarkersForTextListParagraphs() {
    let list = NSTextList(markerFormat: .disc, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "\u{2022}\tFirst item\n\u{2022}\tSecond item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "\u{2022}\tFirst item\n\u{2022}\tSecond item")
}

@Test func stillExpandsParagraphBreaksWhenEnteringOrLeavingATextList() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 14

    let list = NSTextList(markerFormat: .disc, options: 0)
    let listStyle = NSMutableParagraphStyle()
    listStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "Intro paragraph\n\u{2022} First item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: "Intro paragraph".count)
    )
    input.addAttribute(
        .paragraphStyle,
        value: listStyle,
        range: NSRange(location: "Intro paragraph\n".count, length: "\u{2022} First item".count)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "Intro paragraph\n\n\u{2022} First item")
}

@Test func normalizesUnicodeLineSeparatorsToPlainNewlines() {
    let input = NSAttributedString(string: "Bien cordialement,\u{2028}Niels")

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "Bien cordialement,\nNiels")
}

private func formattedListOutput(markerFormat: NSTextList.MarkerFormat, itemCount: Int) -> String {
    let list = NSTextList(markerFormat: markerFormat, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.textLists = [list]

    let itemNames = ["First item", "Second item", "Third item"]
    let input = NSMutableAttributedString(string: itemNames.prefix(itemCount).joined(separator: "\n"))
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    return PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )
}
