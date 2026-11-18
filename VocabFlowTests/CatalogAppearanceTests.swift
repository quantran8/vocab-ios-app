import SwiftUI
import XCTest
@testable import VocabFlow

@MainActor
final class CatalogAppearanceTests: XCTestCase {
    func testBackendColourAndSymbolWinAndAnUnknownSymbolFallsBack() async throws {
        let bundledCatalog = try await OfflineVocabAPI().catalog()
        defer { TopicCatalog.update(with: bundledCatalog) }
        let json = """
        [{"id": "c", "slug": "business-work", "title": "Business", "description": null, "color": "#123456",
          "topics": [{"id": "t1", "slug": "finance-billing", "title": "Finance", "description": null, "iosIcon": "creditcard"},
                     {"id": "t2", "slug": "travel", "title": "Travel", "description": null, "iosIcon": "no.such.symbol"},
                     {"id": "t3", "slug": "new-topic", "title": "New", "description": null}]}]
        """
        TopicCatalog.update(with: try JSONDecoder().decode([CatalogCollection].self, from: Data(json.utf8)))

        let collection = try XCTUnwrap(TopicCatalog.collections.first)
        XCTAssertEqual(collection.markHex, 0x123456)
        XCTAssertEqual(CollectionMarkColor.color(for: collection), Color(hex: 0x123456))
        XCTAssertEqual(collection.topics.map(\.systemImage), ["creditcard", "airplane", "tag"])
    }

    func testWithoutAColourTheSlugStillPicksTheMark() throws {
        let collection = VocabCollection(id: "c", name: "IELTS", summary: "", systemImage: "graduationcap", topics: [], slug: "ielts")
        XCTAssertEqual(CollectionMarkColor.color(for: collection), Color.markIELTS)
    }
}
