import SwiftUI
import UIKit

// System San Francisco; identity comes from weight. Sizes follow docs/app-redesign-v1.html and
// scale with Dynamic Type (sizes without an exact text style scale relative to the nearest one).
enum Typography {
    /// Screen titles: 34 extrabold, tracking `displayTracking`.
    static let display = Font.system(.largeTitle, weight: .heavy)
    /// Sheet titles: 26 extrabold, tracking `sheetTracking`.
    static var sheetTitle: Font { scaled(26, .heavy, relativeTo: .title1) }
    /// Section headers inside a screen ("Đang học", "Luyện tập"): 19 bold.
    static var sectionTitle: Font { scaled(19, .bold, relativeTo: .title3) }
    /// Onboarding step questions: 28 extrabold, tracking `sheetTracking`.
    static let stepTitle = Font.system(.title, weight: .heavy)
    /// Practice question line and feedback titles: 22 bold.
    static let screenTitle = Font.system(.title2, weight: .bold)
    static let headerTitle = Font.system(.title2, weight: .bold)
    /// Feedback panel title: 19 extrabold.
    static var feedbackTitle: Font { scaled(19, .heavy, relativeTo: .title3) }
    /// Practice text prompt: 36 extrabold.
    static var challengeTerm: Font { scaled(36, .heavy, relativeTo: .largeTitle) }
    /// Word intro hero: 44 extrabold, tracking -1.6.
    static var wordHero: Font { scaled(44, .heavy, relativeTo: .largeTitle) }
    /// Word detail / add word hero: 36–38 extrabold.
    static var wordTitle: Font { scaled(38, .heavy, relativeTo: .largeTitle) }
    static let sentence = Font.system(.title2, weight: .bold)
    /// Base text: 16.
    static let body = Font.system(.callout)
    static let emphasis = Font.system(.callout, weight: .bold)
    /// Secondary lines, links, messages: 15.
    static let secondary = Font.system(.subheadline)
    /// Row subtitles, captions: 13.
    static let micro = Font.system(.footnote)
    /// Pills and eyebrows: 12.
    static let caption = Font.system(.caption)
    static let eyebrow = Font.system(.caption, weight: .bold)
    static let tile = Font.system(.callout, weight: .semibold)
    static let tileLarge = Font.system(.title3, weight: .semibold)
    /// Word introduction values; definition and example use `body`.
    /// IPA under the word on word detail / add word: 19.
    static var ipaHero: Font { scaled(19, .regular, relativeTo: .title3) }
    /// IPA line inside a meaning card: 17.
    static let ipaCard = Font.system(.body)
    static let wordClass = Font.system(.headline, weight: .semibold)
    /// The meaning on the word card: 26 extrabold.
    static var wordMeaning: Font { scaled(26, .heavy, relativeTo: .title1) }
    /// Match tiles and Match Madness: 19.
    static var choice: Font { scaled(19, .regular, relativeTo: .title3) }
    /// Select answer tiles (one answer per row, so room for a larger face): 22.
    static let choiceOption = Font.system(.title2)
    /// Big numbers in stat cards: 30 extrabold.
    static var stat: Font { scaled(30, .heavy, relativeTo: .title1) }
    /// The overall score inside a scored read-aloud's ring: 56 extrabold.
    static var scoreHero: Font { scaled(56, .heavy, relativeTo: .largeTitle) }
    /// Secondary figures beside a big stat: 19 extrabold.
    static var statSmall: Font { scaled(19, .heavy, relativeTo: .title3) }
    /// Button labels: 16 bold.
    static let action = Font.system(.callout, weight: .bold)
    static let actionSmall = Font.system(.subheadline, weight: .bold)
    static let tab = Font.system(.caption2, weight: .semibold)
    static let wordmark = Font.system(.title2, weight: .black)

    static let displayTracking: CGFloat = -1.2
    static let sheetTracking: CGFloat = -0.8
    static let tightTracking: CGFloat = -0.6
    static let eyebrowTracking: CGFloat = 1.2

    private static func scaled(_ size: CGFloat, _ weight: Font.Weight, relativeTo style: UIFont.TextStyle) -> Font {
        .system(size: UIFontMetrics(forTextStyle: style).scaledValue(for: size), weight: weight)
    }
}
