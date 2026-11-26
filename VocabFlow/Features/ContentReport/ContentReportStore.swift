import Foundation
import Observation

/// Sends content reports (backend FRONTEND_FLOW §18). Reports are feedback for reviewers: they never touch the
/// session, its attempts or its commit. A failed send keeps the draft; resending the same report reuses its key,
/// so the server stores it once.
@Observable
@MainActor
final class ContentReportStore {
    enum Phase: Equatable {
        case editing
        case submitting
        case failed(String)
    }

    private(set) var phase: Phase = .editing

    private let api: VocabAPI
    private let makeID: () -> String
    /// The last request that didn't get an answer; the same report resends it unchanged.
    private var unanswered: ContentReportRequest?
    private var generation = 0

    init(api: VocabAPI, makeID: @escaping () -> String = { UUID().uuidString.lowercased() }) {
        self.api = api
        self.makeID = makeID
    }

    var isSubmitting: Bool { phase == .submitting }

    /// Before each new sheet.
    func begin() {
        phase = .editing
        unanswered = nil
    }

    /// Whether the server took the report (a duplicate of an open one counts).
    func submit(_ target: ContentReportTarget, reason: ContentReportReason, note: String) async -> Bool {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = ContentReportRequest(
            clientReportId: makeID(), source: target.context.source, reason: reason, context: target.context,
            note: trimmed.isEmpty ? nil : String(trimmed.unicodeScalars.prefix(ContentReportRequest.maxNoteLength))
        )
        let request = unanswered.flatMap { $0.isSameReport(as: draft) ? $0 : nil } ?? draft
        let started = generation
        phase = .submitting
        do {
            _ = try await api.submitContentReport(request)
            guard started == generation else { return false }
            unanswered = nil
            phase = .editing
            return true
        } catch {
            guard started == generation else { return false }
            let apiError = error.asAPIError
            // Only an unanswered request may have been stored; any answer means the key is spent.
            unanswered = apiError.isRetryable ? request : nil
            phase = .failed(Self.message(for: apiError))
            return false
        }
    }

    func reset() {
        generation += 1
        phase = .editing
        unanswered = nil
    }

    static func message(for error: APIError) -> String {
        switch error.code {
        case "REPORT_TARGET_OVERRIDDEN":
            String(localized: "This meaning shows your own edit, so it can’t be reported.", bundle: .appLanguage)
        case "REPORT_CONTEXT_UNAVAILABLE":
            String(localized: "This content is no longer available to report.", bundle: .appLanguage)
        case "REPORT_LIMIT_REACHED":
            String(localized: "You’ve sent the most reports for today.", bundle: .appLanguage)
        case "REPORT_IDEMPOTENCY_CONFLICT", "VALIDATION_FAILED":
            String(localized: "This report couldn’t be sent. Please try again.", bundle: .appLanguage)
        default:
            error.userMessage
        }
    }
}
