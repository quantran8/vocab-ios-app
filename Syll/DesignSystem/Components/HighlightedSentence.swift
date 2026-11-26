import SwiftUI

/// A sentence with one word marked like a highlighter: bold Blue 800 text on a rounded Blue 100 fill
/// (`<mark class="… rounded-md px-1">` in docs/app-redesign-v1.html). Font and the sentence colour come from the
/// environment. iOS 18+ draws the rounded fill with a `TextRenderer`; iOS 17 has no way to round a text
/// background, so it falls back to a square one.
struct HighlightedSentence: View {
    let sentence: String
    /// The marked part of `sentence`; nil shows the sentence unmarked.
    let range: Range<String.Index>?

    /// Marks `term` in the sentence (see `range(of:in:)`).
    init(sentence: String, term: String) {
        self.sentence = sentence
        range = Self.range(of: term, in: sentence)
    }

    /// The first case-insensitive match of `term` as a whole word; failing that, at the start of a word (an inflection:
    /// "run" in "running"); failing that, anywhere. So "in" marks "in", not the end of "train".
    static func range(of term: String, in sentence: String) -> Range<String.Index>? {
        let term = term.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: term)
        for pattern in ["\\b\(escaped)\\b", "\\b\(escaped)"] {
            if let range = sentence.range(of: pattern, options: [.regularExpression, .caseInsensitive]) { return range }
        }
        return sentence.range(of: term, options: .caseInsensitive)
    }

    /// Marks the span the backend located (custom words), rather than searching for it.
    init(sentence: String, locator: TargetLocator?) {
        self.sentence = sentence
        range = locator?.nsRange(in: sentence).flatMap { Range($0, in: sentence) }
    }

    var body: some View {
        if #available(iOS 18.0, *) {
            marked.textRenderer(RoundedHighlightRenderer())
        } else {
            Text(squareMarked)
        }
    }

    @available(iOS 18.0, *)
    private var marked: Text {
        guard let range else { return Text(verbatim: sentence) }
        return Text(verbatim: String(sentence[..<range.lowerBound]))
            + Text(verbatim: String(sentence[range]))
                .bold()
                .foregroundStyle(Color.blue800)
                .customAttribute(HighlightRun())
            + Text(verbatim: String(sentence[range.upperBound...]))
    }

    private var squareMarked: AttributedString {
        var attributed = AttributedString(sentence)
        if let range, let marked = Range<AttributedString.Index>(range, in: attributed) {
            attributed[marked].inlinePresentationIntent = .stronglyEmphasized
            attributed[marked].foregroundColor = Color.blue800
            attributed[marked].backgroundColor = Color.blue100
        }
        return attributed
    }
}

@available(iOS 18.0, *)
private struct HighlightRun: TextAttribute {}

/// Fills a rounded rectangle behind every run tagged `HighlightRun`, `Spacing.xxs` wider on each side (px-1),
/// then draws the text on top.
@available(iOS 18.0, *)
private struct RoundedHighlightRenderer: TextRenderer {
    var displayPadding: EdgeInsets {
        EdgeInsets(top: 0, leading: Spacing.xxs, bottom: 0, trailing: Spacing.xxs)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line where run[HighlightRun.self] != nil {
                let rect = run.typographicBounds.rect.insetBy(dx: -Spacing.xxs, dy: 0)
                context.fill(Path(roundedRect: rect, cornerRadius: Radii.highlight), with: .color(Color.blue100))
            }
        }
        for line in layout {
            context.draw(line)
        }
    }
}
