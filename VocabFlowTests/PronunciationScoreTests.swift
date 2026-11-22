import XCTest
@testable import VocabFlow

final class PronunciationScoreTests: XCTestCase {
    private func syllable(_ text: String, _ band: SyllableBand) -> PronunciationSyllable {
        PronunciationSyllable(text: text, band: band)
    }

    // MARK: Decoding

    func testDecodesBandAndSyllables() throws {
        let json = """
        {"assessmentReceiptId":"r1","validity":"valid","passed":false,"accuracyScore":64,"band":"fair",
         "syllables":[{"text":"ap","ipa":"ə","score":90,"band":"good"},{"text":"ci","ipa":"ʃi","score":42,"band":"poor"}]}
        """
        let assessment = try JSONDecoder().decode(RecordingAssessment.self, from: Data(json.utf8))
        XCTAssertEqual(assessment.band, .fair)
        XCTAssertEqual(assessment.syllables?.map(\.text), ["ap", "ci"])
        XCTAssertEqual(assessment.syllables?.last?.score, 42)
        XCTAssertEqual(assessment.syllables?.last?.band, .poor)
        XCTAssertEqual(assessment.scoreBand, .fair)
    }

    func testOlderBackendDecodesWithoutDetail() throws {
        let json = #"{"assessmentReceiptId":"r1","validity":"valid","passed":true,"accuracyScore":92}"#
        let assessment = try JSONDecoder().decode(RecordingAssessment.self, from: Data(json.utf8))
        XCTAssertNil(assessment.band)
        XCTAssertNil(assessment.syllables)
        XCTAssertEqual(assessment.scoreBand, .excellent)
    }

    func testUnknownBandsDecodeLeniently() throws {
        let json = """
        {"assessmentReceiptId":"r1","validity":"valid","passed":true,"accuracyScore":81,"band":"stellar",
         "syllables":[{"text":"ap","band":"great"}]}
        """
        let assessment = try JSONDecoder().decode(RecordingAssessment.self, from: Data(json.utf8))
        XCTAssertEqual(assessment.band, .unknown)
        XCTAssertEqual(assessment.syllables?.first?.band, .unknown)
        // An unknown band falls back to the score's own band.
        XCTAssertEqual(assessment.scoreBand, .good)
    }

    // MARK: Band

    func testNoScoreMeansNoScoredResult() {
        let onDevice = RecordingAssessment(assessmentReceiptId: "on-device", validity: "valid", passed: true, accuracyScore: nil)
        XCTAssertNil(onDevice.scoreBand)
        let invalid = RecordingAssessment(assessmentReceiptId: "r", validity: "invalid", passed: nil, accuracyScore: 70)
        XCTAssertNil(invalid.scoreBand)
    }

    func testFallbackGoodStartsAtThePassMark() {
        XCTAssertEqual(PronunciationBand.fallback(for: 95), .excellent)
        XCTAssertEqual(PronunciationBand.fallback(for: 90), .excellent)
        XCTAssertEqual(PronunciationBand.fallback(for: 80), .good)
        XCTAssertEqual(PronunciationBand.fallback(for: 79.9), .fair)
        XCTAssertEqual(PronunciationBand.fallback(for: 60), .fair)
        XCTAssertEqual(PronunciationBand.fallback(for: 12), .poor)
    }

    // MARK: Coloring

    func testSegmentsFollowTheSyllables() {
        let segments = PronunciationColoring.segments(
            word: "appreciate",
            syllables: [syllable("ap", .good), syllable("pre", .good), syllable("ci", .poor), syllable("ate", .poor)]
        )
        XCTAssertEqual(segments, [
            PronunciationSegment(text: "ap", band: .good),
            PronunciationSegment(text: "pre", band: .good),
            PronunciationSegment(text: "ci", band: .poor),
            PronunciationSegment(text: "ate", band: .poor),
        ])
    }

    func testKeepsTheWordsCaseAndSeparators() {
        let segments = PronunciationColoring.segments(
            word: "Ice-cream",
            syllables: [syllable("ice", .good), syllable("cream", .poor)]
        )
        XCTAssertEqual(segments, [
            PronunciationSegment(text: "Ice", band: .good),
            PronunciationSegment(text: "-", band: nil),
            PronunciationSegment(text: "cream", band: .poor),
        ])
    }

    func testMismatchLeavesTheWordPlain() {
        // A skipped letter.
        XCTAssertNil(PronunciationColoring.segments(word: "appreciate", syllables: [syllable("ap", .good), syllable("ci", .good)]))
        // Letters left over at the end.
        XCTAssertNil(PronunciationColoring.segments(word: "appreciate", syllables: [syllable("ap", .good), syllable("pre", .good)]))
        // Out of order.
        XCTAssertNil(PronunciationColoring.segments(word: "appreciate", syllables: [syllable("pre", .good), syllable("ap", .good)]))
        XCTAssertNil(PronunciationColoring.segments(word: "appreciate", syllables: []))
    }
}
