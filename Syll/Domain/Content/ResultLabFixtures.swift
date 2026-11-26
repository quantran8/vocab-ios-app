import Foundation

/// Example results screens for the Practice Lab (`results_lab.json`): the tiles and sheet without a backend.
struct ResultLabFixture: Decodable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let result: PracticeResult
}

enum ResultLabFixtures {
    static func decode(_ data: Data) throws -> [ResultLabFixture] {
        struct File: Decodable { let fixtures: [ResultLabFixture] }
        return try APIClient.decoder.decode(File.self, from: data).fixtures
    }

    /// Lab-only content: a broken file fails loudly, like the other bundled content.
    static func load(bundle: Bundle = .main) -> [ResultLabFixture] {
        do {
            guard let url = bundle.url(forResource: "results_lab", withExtension: "json") else { throw DemoContentError.missingResource }
            return try decode(Data(contentsOf: url))
        } catch {
            fatalError("Results Lab content failed to load: \(error)")
        }
    }
}
