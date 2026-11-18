import Foundation
import SwiftUI
import os

/// The languages the app's interface is translated into. Learning content is not affected:
/// meanings and explanations follow the backend's `explanationLocale`.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case vietnamese = "vi"
    case english = "en"
    case hindi = "hi"
    case spanish = "es"
    case japanese = "ja"
    case portugueseBrazil = "pt-BR"
    case korean = "ko"
    case chineseTraditional = "zh-Hant"
    case thai = "th"
    case arabic = "ar"
    case indonesian = "id"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    var layoutDirection: LayoutDirection { self == .arabic ? .rightToLeft : .leftToRight }

    /// The value `PUT /me/settings` accepts. The backend localizes the catalog with it.
    var uiLocale: String {
        switch self {
        case .vietnamese: "vi-VN"
        case .english: "en-US"
        case .hindi: "hi-IN"
        case .spanish: "es-MX"
        case .japanese: "ja-JP"
        case .portugueseBrazil: "pt-BR"
        case .korean: "ko-KR"
        case .chineseTraditional: "zh-TW"
        case .thai: "th-TH"
        case .arabic: "ar-SA"
        case .indonesian: "id-ID"
        }
    }

    /// Each language's own name, deliberately not translated so people can always find theirs.
    var nativeName: String {
        switch self {
        case .vietnamese: "Tiếng Việt"
        case .english: "English"
        case .hindi: "हिन्दी"
        case .spanish: "Español"
        case .japanese: "日本語"
        case .portugueseBrazil: "Português (Brasil)"
        case .korean: "한국어"
        case .chineseTraditional: "繁體中文"
        case .thai: "ไทย"
        case .arabic: "العربية"
        case .indonesian: "Bahasa Indonesia"
        }
    }

    /// This language's name written in `language`, so a reader can recognise every row.
    func name(in language: AppLanguage) -> String {
        language.locale.localizedString(forIdentifier: rawValue)?.capitalized(with: language.locale) ?? nativeName
    }

    /// Accepts region-qualified tags such as `vi-VN`. Portuguese maps to the Brazilian
    /// translation and Chinese only matches the traditional script or its regions.
    init?(languageTag: String) {
        let locale = Locale(identifier: languageTag)
        guard let code = locale.language.languageCode?.identifier else { return nil }
        switch code {
        case "pt":
            self = .portugueseBrazil
        case "zh":
            let traditionalRegions = ["TW", "HK", "MO"]
            let isTraditional = locale.language.script?.identifier == "Hant"
                || locale.region.map { traditionalRegions.contains($0.identifier) } == true
            guard isTraditional else { return nil }
            self = .chineseTraditional
        default:
            self.init(rawValue: code)
        }
    }

    /// What iOS picked from the device's languages; the fallback before a choice is made.
    static var device: AppLanguage {
        Bundle.main.preferredLocalizations.first.flatMap(AppLanguage.init(languageTag:)) ?? .english
    }

    /// The language strings are built in right now, readable from any isolation domain
    /// because models and errors build strings too. `AppSettingsStore` is what changes it.
    static var active: AppLanguage {
        get { activeLanguage.withLock { $0 } }
        set { activeLanguage.withLock { $0 = newValue } }
    }

    private static let activeLanguage = OSAllocatedUnfairLock(initialState: device)

    fileprivate static let bundles: [AppLanguage: Bundle] = Dictionary(uniqueKeysWithValues: allCases.map { language in
        (language, Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main)
    })
}

extension Bundle {
    /// Pass to every `String(localized:)`. `Text` follows the `\.locale` environment value, but
    /// `String(localized:)` only follows its bundle, and `Bundle.main` keeps the launch language.
    static var appLanguage: Bundle { AppLanguage.bundles[AppLanguage.active] ?? .main }
}
