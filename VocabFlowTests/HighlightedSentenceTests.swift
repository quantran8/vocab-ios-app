import XCTest
@testable import VocabFlow

final class HighlightedSentenceTests: XCTestCase {
    private func marked(_ term: String, in sentence: String) -> String? {
        HighlightedSentence.range(of: term, in: sentence).map { String(sentence[$0]) }
    }

    private func offset(_ term: String, in sentence: String) -> Int? {
        HighlightedSentence.range(of: term, in: sentence).map { sentence.distance(from: sentence.startIndex, to: $0.lowerBound) }
    }

    func testPrefersTheWholeWordOverAMatchInsideAnotherWord() {
        let sentence = "The train will leave in ten minutes."
        XCTAssertEqual(offset("in", in: sentence), 21)
        XCTAssertEqual(marked("in", in: sentence), "in")
    }

    func testIsCaseInsensitive() {
        XCTAssertEqual(marked("in", in: "In the morning."), "In")
    }

    func testFallsBackToTheStartOfAWordForAnInflection() {
        let sentence = "She was running late."
        XCTAssertEqual(marked("run", in: sentence), "run")
        XCTAssertEqual(offset("run", in: sentence), 8)
    }

    func testFallsBackToAnyMatchThenToNone() {
        XCTAssertEqual(marked("happy", in: "She felt unhappy."), "happy")
        XCTAssertNil(HighlightedSentence.range(of: "apple", in: "No fruit here."))
        XCTAssertNil(HighlightedSentence.range(of: " ", in: "Anything."))
    }

    func testMatchesATermWithRegexCharactersLiterally() {
        XCTAssertEqual(marked("a.m.", in: "We open at 9 a.m. sharp."), "a.m.")
    }
}
