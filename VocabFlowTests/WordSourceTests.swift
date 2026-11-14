import XCTest
@testable import VocabFlow

final class WordSourceTests: XCTestCase {
    private let collection = VocabCollection(
        id: "business", name: "Business", summary: "", systemImage: "briefcase",
        topics: [
            Topic(id: "finance", name: "Finance", systemImage: "banknote", learned: 3, total: 20),
            Topic(id: "unlearned", name: "Unlearned", systemImage: "circle", learned: 0, total: 10),
            Topic(id: "marketing", name: "Marketing", systemImage: "megaphone", learned: 13, total: 20),
        ],
        learned: 16, total: 50
    )

    func testAllAndCustom() {
        XCTAssertNil(WordSource.all.filter(in: [collection]))
        XCTAssertEqual(WordSource.custom.filter(in: [collection]), .customWords)
    }

    func testEveryLearnedTopicIsTheWholeCollection() {
        let source = WordSource.collection(id: "business", topics: ["finance", "marketing"])
        XCTAssertEqual(source.filter(in: [collection]), .collection("business"))
    }

    func testSomeTopicsSendThemInCatalogOrder() {
        let source = WordSource.collection(id: "business", topics: ["marketing"])
        XCTAssertEqual(source.filter(in: [collection]), .topics(["marketing"]))
    }

    func testLearnedTopicsSkipTopicsWithNothingLearned() {
        XCTAssertEqual(collection.learnedTopics.map(\.id), ["finance", "marketing"])
    }
}
