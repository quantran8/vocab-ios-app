import Foundation

/// The band of a scored recording's overall score. The server picks it; unknown values decode to `.unknown`.
enum PronunciationBand: String, Decodable, Equatable {
    case excellent, good, fair, poor, unknown

    init(from decoder: Decoder) throws {
        self = PronunciationBand(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }

    /// Only for a backend that sends a score without a band. `good` starts at the backend's pass mark (80),
    /// so the title never contradicts `passed`.
    static func fallback(for score: Double) -> PronunciationBand {
        switch score {
        case 90...: .excellent
        case 80..<90: .good
        case 60..<80: .fair
        default: .poor
        }
    }
}

/// Good or not yet, per syllable. The server picks it; unknown values decode to `.unknown` and stay uncoloured.
enum SyllableBand: String, Decodable, Equatable {
    case good, poor, unknown

    init(from decoder: Decoder) throws {
        self = SyllableBand(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
}

/// One syllable of a server-scored recording: its letters in the word, its sounds and its score.
struct PronunciationSyllable: Decodable, Equatable {
    let text: String
    var ipa: String? = nil
    var score: Double? = nil
    let band: SyllableBand
}

/// A run of the prompt word: a syllable with its band, or the text between syllables (`band == nil`).
struct PronunciationSegment: Equatable {
    let text: String
    let band: SyllableBand?
}

enum PronunciationColoring {
    /// Splits `word` along `syllables` in order, keeping the word's own spelling and case.
    /// Nil when the syllables don't spell the word (letters left over or out of order): the word stays plain.
    static func segments(word: String, syllables: [PronunciationSyllable]) -> [PronunciationSegment]? {
        guard !syllables.isEmpty else { return nil }
        var segments: [PronunciationSegment] = []
        var cursor = word.startIndex
        for syllable in syllables {
            guard !syllable.text.isEmpty,
                  let range = word.range(of: syllable.text, options: [.caseInsensitive, .diacriticInsensitive], range: cursor..<word.endIndex)
            else { return nil }
            guard appendGap(word[cursor..<range.lowerBound], to: &segments) else { return nil }
            segments.append(PronunciationSegment(text: String(word[range]), band: syllable.band))
            cursor = range.upperBound
        }
        guard appendGap(word[cursor..<word.endIndex], to: &segments) else { return nil }
        return segments
    }

    /// Spaces, hyphens and apostrophes between syllables stay uncoloured; a skipped letter means a mismatch.
    private static func appendGap(_ gap: Substring, to segments: inout [PronunciationSegment]) -> Bool {
        guard !gap.isEmpty else { return true }
        guard !gap.contains(where: \.isLetter) else { return false }
        segments.append(PronunciationSegment(text: String(gap), band: nil))
        return true
    }
}
