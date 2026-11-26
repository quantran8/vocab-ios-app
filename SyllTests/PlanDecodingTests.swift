import XCTest
@testable import Syll

final class PlanDecodingTests: XCTestCase {
    private func decodePlan(_ steps: String) throws -> SessionPlan {
        let json = #"{"sessionId":"s1","mode":"daily","expiresAt":"2026-11-03T10:00:00.000Z","steps":[\#(steps)]}"#
        return try APIClient.decoder.decode(SessionPlan.self, from: Data(json.utf8))
    }

    private func decodeTask(_ body: String) throws -> PracticeTask {
        let plan = try decodePlan(#"{"type":"practice","phase":"new_practice","task":{"id":"t1",\#(body)}}"#)
        guard case .practice(_, let task) = plan.steps.first else { throw APIError.invalidResponse }
        return task
    }

    func testEmptyPlanHasNoSession() throws {
        let json = #"{"sessionId":null,"mode":"daily","steps":[]}"#
        let plan = try APIClient.decoder.decode(SessionPlan.self, from: Data(json.utf8))
        XCTAssertNil(plan.sessionID)
        XCTAssertTrue(plan.steps.isEmpty)
    }

    func testDecodesLearnStep() throws {
        let plan = try decodePlan(#"""
        {"type":"learn","id":"l1","card":{"word":"clarify","meaning":"làm rõ","definition":"d",
         "audio":{"url":"https://a.example/x.mp3","locale":"en-US"},"examples":[{"text":"t","translation":"u"}]}}
        """#)
        guard case .learn(let id, let card) = plan.steps[0] else { return XCTFail("Not a learn step") }
        XCTAssertEqual(id, "l1")
        XCTAssertEqual(card.word, "clarify")
        XCTAssertNil(card.ipa)
        XCTAssertNil(card.partOfSpeech)
        XCTAssertNil(card.wordId)
        XCTAssertEqual(card.audio?.locale, "en-US")
    }

    func testDecodesEveryTemplate() throws {
        let text = #""prompt":{"type":"text","text":"x"}"#
        let select = try decodeTask(#""template":"select","variant":"gloss",\#(text),"question":"q","options":[{"id":1,"text":"a"},{"id":2,"text":"b"}],"evaluation":{"correctOptionId":2}"#)
        XCTAssertEqual(select.body, .choice(options: [TaskOption(id: 1, text: "a"), TaskOption(id: 2, text: "b")], sentence: nil, correctOptionID: 2))

        let cloze = try decodeTask(#""template":"cloze_select","variant":"single_blank",\#(text),"sentenceParts":{"before":"a ","after":" b"},"options":[{"id":1,"text":"a"}],"evaluation":{"correctOptionId":1}"#)
        XCTAssertEqual(cloze.body, .choice(options: [TaskOption(id: 1, text: "a")], sentence: SentenceParts(before: "a ", after: " b"), correctOptionID: 1))

        let typing = try decodeTask(#""template":"typing","variant":"meaning_recall",\#(text),"evaluation":{"acceptedResponses":["a"]}"#)
        XCTAssertEqual(typing.body, .typing(accepted: ["a"]))

        let reorder = try decodeTask(#""template":"fly_reorder","variant":"spelling_recall",\#(text),"tiles":[{"id":1,"text":"a"}],"evaluation":{"acceptedResponses":["a"]}"#)
        XCTAssertEqual(reorder.body, .reorder(tiles: [TaskOption(id: 1, text: "a")], accepted: ["a"]))

        let match = try decodeTask(#""template":"match","variant":"meaning_pairs",\#(text),"pairs":{"left":[{"id":1,"text":"a"}],"right":[{"id":5,"text":"b"}]},"evaluation":{"correctPairs":[{"leftId":1,"rightId":5}]}"#)
        XCTAssertEqual(match.body, .match(left: [TaskOption(id: 1, text: "a")], right: [TaskOption(id: 5, text: "b")], correct: [PairKey(leftId: 1, rightId: 5)]))

        let surgery = try decodeTask(#""template":"surgery","variant":"fix_spelling",\#(text),"word":"ab","evaluation":{"wrongGraphemeIndex":1,"replacement":""}"#)
        XCTAssertEqual(surgery.body, .surgery(word: "ab", wrongGraphemeIndex: 1, replacement: ""))

        let recording = try decodeTask(#""template":"recording","variant":"scripted_pronunciation","prompt":{"type":"audio","audio":{"url":"https://a.example/x.mp3","locale":"en-US"}},"assessment":{"kind":"azurePronunciation"},"evaluation":{"acceptedResponses":["a"]}"#)
        XCTAssertEqual(recording.body, .recording(accepted: ["a"]))
        XCTAssertEqual(recording.prompt?.isAudio, true)

        let legacyRecording = try decodeTask(#""template":"recording","variant":"scripted_pronunciation",\#(text),"assessment":{"kind":"azurePronunciation"}"#)
        XCTAssertEqual(legacyRecording.body, .recording(accepted: []))
    }

    func testRecordingMeaningCueIsOptional() throws {
        let base = #""template":"recording","variant":"scripted_pronunciation","prompt":{"type":"text","text":"clarify"},"assessment":{"kind":"azurePronunciation"},"evaluation":{"acceptedResponses":["clarify"]}"#
        let cued = try decodeTask(base + #","meaningCue":{"text":"làm rõ","question":"Which English word means this?"}"#)
        XCTAssertEqual(cued.meaningCue, MeaningCue(text: "làm rõ", question: "Which English word means this?"))
        XCTAssertNil(try decodeTask(base).meaningCue, "A new word's recording, or an older backend, has no cue")
    }

    func testRecordingIPAIsOptionalAndOnlyOnRecording() throws {
        let recording = #""template":"recording","variant":"scripted_pronunciation","prompt":{"type":"text","text":"bass"},"assessment":{"kind":"azurePronunciation"},"evaluation":{"acceptedResponses":["bass"]}"#
        XCTAssertEqual(try decodeTask(recording + #","ipa":"/beɪs/""#).ipa, "/beɪs/")
        XCTAssertNil(try decodeTask(recording).ipa, "A meaning with no IPA, or an older backend, sends none")
        let typing = #""template":"typing","variant":"meaning_recall","prompt":{"type":"text","text":"x"},"evaluation":{"acceptedResponses":["a"]},"ipa":"/x/""#
        XCTAssertNil(try decodeTask(typing).ipa)
    }

    func testMaxRetriesIsOptional() throws {
        let body = #""template":"typing","variant":"meaning_recall","prompt":{"type":"text","text":"x"},"evaluation":{"acceptedResponses":["a"]}"#
        XCTAssertEqual(try decodeTask(body + #","maxRetries":2"#).maxRetries, 2)
        XCTAssertNil(try decodeTask(body).maxRetries, "Sessions issued before the limit stay unlimited")
    }

    func testOnlyClozeMayComeWithoutAPrompt() throws {
        let cloze = try decodeTask(#""template":"cloze_select","variant":"single_blank","sentenceParts":{"before":"a ","after":" b"},"options":[{"id":1,"text":"a"}],"evaluation":{"correctOptionId":1}"#)
        XCTAssertNil(cloze.prompt)
        XCTAssertNil(TaskAttempt(task: cloze, phase: .dueReview).deliveryMode)
        XCTAssertThrowsError(try decodeTask(#""template":"typing","variant":"meaning_recall","evaluation":{"acceptedResponses":["a"]}"#))
    }

    func testPromptHighlightDecodesAndSplits() throws {
        let task = try decodeTask(#""template":"typing","variant":"meaning_recall","prompt":{"type":"text","text":"Sign the contract.","highlight":{"start":9,"end":17}},"evaluation":{"acceptedResponses":["a"]}"#)
        guard case .text(let text, let highlight?)? = task.prompt else { return XCTFail("No highlight") }
        let parts = highlight.split(text)
        XCTAssertEqual(parts?.before, "Sign the ")
        XCTAssertEqual(parts?.word, "contract")
        XCTAssertEqual(parts?.after, ".")
    }

    func testPromptHighlightCountsUTF16Units() {
        XCTAssertEqual(PromptHighlight(start: 3, end: 6).split("👍 pay")?.word, "pay")
    }

    func testPromptHighlightOutsideTheTextIsIgnored() {
        XCTAssertNil(PromptHighlight(start: 2, end: 9).split("short"))
        XCTAssertNil(PromptHighlight(start: 2, end: 2).split("short"))
    }

    func testClozeNeedsItsSentence() {
        XCTAssertThrowsError(try decodeTask(#""template":"cloze_select","variant":"single_blank","options":[{"id":1,"text":"a"}],"evaluation":{"correctOptionId":1}"#))
    }

    func testClozeLineKeepsPunctuationOnTheBlank() {
        let line = ClozeLine(SentenceParts(before: "See the ", after: ". Then pay"))
        XCTAssertEqual(line.wordsBefore, ["See", "the"])
        XCTAssertEqual(line.attachedBefore, "")
        XCTAssertEqual(line.attachedAfter, ".")
        XCTAssertEqual(line.wordsAfter, ["Then", "pay"])
    }

    func testClozeLineHandlesABlankAtEitherEnd() {
        let line = ClozeLine(SentenceParts(before: "", after: " is late"))
        XCTAssertEqual(line.wordsBefore, [])
        XCTAssertEqual(line.attachedAfter, "")
        XCTAssertEqual(line.wordsAfter, ["is", "late"])
        XCTAssertEqual(ClozeLine(SentenceParts(before: "Pay the", after: "")).attachedBefore, "the")
    }

    func testUnknownTemplateFailsThePlan() {
        XCTAssertThrowsError(try decodeTask(#""template":"hologram","variant":"gloss","prompt":{"type":"text","text":"x"}"#))
    }

    func testUnknownVariantFailsThePlan() {
        XCTAssertThrowsError(try decodeTask(#""template":"typing","variant":"gloss","prompt":{"type":"text","text":"x"},"evaluation":{"acceptedResponses":["a"]}"#))
    }

    func testMissingAnswerKeyFailsThePlan() {
        XCTAssertThrowsError(try decodeTask(#""template":"typing","variant":"meaning_recall","prompt":{"type":"text","text":"x"},"evaluation":{}"#))
    }

    func testUnknownPhaseIsOnlyALabel() throws {
        let plan = try decodePlan(#"{"type":"practice","phase":"somethingNew","task":{"id":"t1","template":"recording","variant":"scripted_pronunciation","prompt":{"type":"text","text":"x"}}}"#)
        guard case .practice(let phase, _) = plan.steps[0] else { return XCTFail("Not a practice step") }
        XCTAssertEqual(phase, .other)
    }

    func testNewPracticePhaseIsRecognized() throws {
        let plan = try decodePlan(#"{"type":"practice","phase":"new_practice","task":{"id":"t1","template":"recording","variant":"scripted_pronunciation","prompt":{"type":"text","text":"x"}}}"#)
        guard case .practice(let phase, _) = plan.steps[0] else { return XCTFail("Not a practice step") }
        XCTAssertEqual(phase, .newPractice)
    }

    func testSessionModesUseWireValues() throws {
        let capabilities = PlanRequest.Capabilities(audioPlayback: true, microphone: true)
        let body = try JSONEncoder().encode(PlanRequest(mode: .weakWordsPractice, capabilities: capabilities))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["mode"] as? String, "weak_words_practice")

        let plan = try APIClient.decoder.decode(SessionPlan.self, from: Data(#"{"sessionId":null,"mode":"checkpoint_challenge","steps":[]}"#.utf8))
        XCTAssertEqual(plan.mode, .checkpointChallenge)
    }

    func testRandomPracticeSendsNoSkills() throws {
        let capabilities = PlanRequest.Capabilities(audioPlayback: true, microphone: true)
        let mixed = try PracticeFixtures.json(PlanRequest(mode: .randomPractice, capabilities: capabilities)) as? [String: Any]
        XCTAssertNil(mixed?["skills"])
        XCTAssertNil(mixed?["skill"])
    }

    func testDecodesLearnCardPartOfSpeech() throws {
        let json = #"{"word":"clarify","meaning":"làm rõ","partOfSpeech":"verb","wordId":"w","meaningId":"m"}"#
        let card = try APIClient.decoder.decode(LearnCard.self, from: Data(json.utf8))
        XCTAssertEqual(card.partOfSpeech, "verb")
        XCTAssertEqual(card.wordId, "w")
        XCTAssertEqual(card.meaningId, "m")
    }

    func testPartOfSpeechLabel() {
        var word = VocabularyItem(id: "w", term: "word", meaningVi: "", example: "")
        XCTAssertNil(word.partOfSpeechLabel)
        word.partsOfSpeech = ["new_type"]
        XCTAssertEqual(word.partOfSpeechLabel, "new type")
    }

    func testLearnHomeReportsCheckpointProgress() throws {
        let json = #"{"dueCount":0,"checkpointAvailable":0,"checkpointSessionsDone":3,"checkpointSessionsRequired":7,"learnedTotal":15}"#
        let home = try APIClient.decoder.decode(LearnHome.self, from: Data(json.utf8))
        XCTAssertEqual(home.checkpointSessionsDone, 3)
        XCTAssertEqual(home.checkpointProgress, 3.0 / 7.0, accuracy: 0.0001)
    }

    func testCheckpointProgressStaysWithinRange() {
        let full = LearnHome(dueCount: 0, checkpointAvailable: 0, checkpointSessionsDone: 9, checkpointSessionsRequired: 7, learnedTotal: 0)
        XCTAssertEqual(full.checkpointProgress, 1)
        let unset = LearnHome(dueCount: 0, checkpointAvailable: 0, checkpointSessionsDone: 0, checkpointSessionsRequired: 0, learnedTotal: 0)
        XCTAssertEqual(unset.checkpointProgress, 0)
    }

    func testDecodesWordsResponseShape() throws {
        let json = #"""
        {"wordId":"w","lemma":"clarify","meanings":[{"meaningId":"m",
         "meaning":{"partOfSpeech":"verb","text":"làm rõ","ipa":"/x/","definition":"To make clear.",
          "audio":{"url":"https://example.com/clarify.mp3","locale":"en-US"},
          "examples":[{"text":"Please clarify.","translation":"Hãy làm rõ."}]},
         "learnedAt":"2026-10-30T10:00:00.000Z","nextReviewAt":null}]}
        """#
        let word = try APIClient.decoder.decode(WordProgress.self, from: Data(json.utf8))
        XCTAssertNil(word.meaningCount)
        XCTAssertEqual(word.ipa, "/x/")
        let meaning = word.meanings[0]
        XCTAssertEqual(meaning.meaningId, "m")
        XCTAssertEqual(meaning.meaning.definition, "To make clear.")
        XCTAssertEqual(meaning.meaning.audio?.locale, "en-US")
        XCTAssertEqual(meaning.meaning.examples?.first?.text, "Please clarify.")
    }

    func testDecodesWordDetailSpeakingAndMemory() throws {
        let json = #"""
        {"wordId":"w","lemma":"clarify","needsPractice":true,"meanings":[{"meaningId":"m",
         "meaning":{"partOfSpeech":"verb","text":"làm rõ"},"learnedAt":"2026-10-30T10:00:00.000Z","nextReviewAt":"2026-10-31T10:00:00Z",
         "memory":{"stabilityDays":3.2,"retrievability":0.87,"nextReviewAt":"2026-10-31T10:00:00Z"},
         "speaking":{"status":"fluent","lastScore":88.5,"bestScore":93,"lastAssessedAt":"2026-11-19T10:00:00.000Z"},
         "skills":null,"needsPractice":true},
         {"meaningId":"m2","meaning":{"partOfSpeech":"verb","text":"giải thích"},"learnedAt":null,"nextReviewAt":null,
          "memory":null,"speaking":{"status":"not_tried","lastScore":null,"bestScore":null,"lastAssessedAt":null},"skills":null,"needsPractice":false},
         {"meaningId":"m3","meaning":{"partOfSpeech":"verb","text":"x"},"learnedAt":null,"nextReviewAt":null,
          "speaking":{"status":"mastered"},"needsPractice":false}]}
        """#
        let meanings = try APIClient.decoder.decode(WordDetail.self, from: Data(json.utf8)).meanings
        let meaning = meanings[0]
        XCTAssertEqual(meaning.meaning.text, "làm rõ")
        XCTAssertEqual(meaning.speaking?.status, .fluent)
        XCTAssertEqual(meaning.speaking?.bestScore, 93)
        XCTAssertNotNil(meaning.speaking?.lastAssessedAt)
        XCTAssertEqual(meaning.needsPractice, true)
        XCTAssertEqual(meaning.memory?.retrievability, 0.87)
        XCTAssertEqual(meaning.memory?.stabilityDays, 3.2)
        XCTAssertEqual(meanings[1].speaking, MeaningSpeaking(status: .notTried))
        XCTAssertEqual(meanings[2].speaking?.status, .unknown)
    }

    func testDecodesWordDetailFromAnOlderBackend() throws {
        let json = #"""
        {"wordId":"w","lemma":"clarify","needsPractice":true,"fullyVerified":false,"meanings":[{"meaningId":"m",
         "meaning":{"partOfSpeech":"verb","text":"làm rõ"},"learnedAt":"2026-10-30T10:00:00.000Z","nextReviewAt":"2026-10-31T10:00:00Z",
         "needsPractice":true,"skills":{"reading":{"status":"verified","needsPractice":false},
         "writing":{"status":"verified","needsPractice":true}}}]}
        """#
        let meaning = try APIClient.decoder.decode(WordDetail.self, from: Data(json.utf8)).meanings[0]
        XCTAssertNil(meaning.memory)
        XCTAssertNil(meaning.speaking)
    }

    func testDecodesWordStatsWithAndWithoutFluentWords() throws {
        let stats = try APIClient.decoder.decode(WordStats.self, from: Data(#"{"learnedWords":4,"needPracticeWords":1,"fluentWords":2}"#.utf8))
        XCTAssertEqual(stats.fluentWords, 2)
        XCTAssertNil(try APIClient.decoder.decode(WordStats.self, from: Data(#"{"learnedWords":4,"needPracticeWords":1}"#.utf8)).fluentWords)
    }

    // MARK: Commit summary for the results screen

    private func decodeSummary(_ summary: String) throws -> CommitSummary {
        let json = #"{"sessionId":"s1","summary":\#(summary)}"#
        return try APIClient.decoder.decode(CommitResponse.self, from: Data(json.utf8)).summary
    }

    func testSummaryFromAnOlderBackendHasNoResultBlocks() throws {
        let summary = try decodeSummary(#"{"newWordGoalSlots":2,"reviewedMeanings":1,"practiceTasks":9}"#)
        XCTAssertEqual(summary.practiceTasks, 9)
        XCTAssertNil(summary.review)
        XCTAssertNil(summary.newWords)
        XCTAssertNil(summary.practice)
        // A later backend drops the legacy counts.
        XCTAssertNil(try decodeSummary(#"{"review":null,"newWords":null}"#).practiceTasks)
    }

    func testDailySummaryDecodesGroupsAndSkipsUnknownOnes() throws {
        let summary = try decodeSummary(#"""
        {"review":{"total":2,"groups":{
            "solid":[{"meaningId":"m1","wordId":"w1","lemma":"prevalence","gloss":"tỷ lệ phổ biến","nextReviewAt":"2026-11-25T13:00:00Z","learnedAt":"2026-11-09T12:10:00.000Z"}],
            "relearn":[{"meaningId":"m2","lemma":"chronic","cause":"out_of_tries","struggledAt":"writing"}],
            "shaky":[{"meaningId":"m5","lemma":"budget","cause":"something_new"}],
            "forgotten":[{"oddShape":true}]}},
         "newWords":{"total":1,"groups":{
            "retried":[{"meaningId":"m3","lemma":"fatigue","struggledAt":"grammar"}],
            "revealed":[{"meaningId":"m4","lemma":"immune","struggledAt":"speaking"}]}}}
        """#)
        let review = try XCTUnwrap(summary.review)
        XCTAssertEqual(review.groups[.solid].first?.lemma, "prevalence")
        XCTAssertNotNil(review.groups[.solid].first?.learnedAt)
        XCTAssertEqual(review.groups[.relearn].first?.gloss, "")
        XCTAssertEqual(review.groups[.relearn].first?.cause, .outOfTries)
        // An older session's `writing` is spelling now.
        XCTAssertEqual(review.groups[.relearn].first?.struggledAt, .spelling)
        XCTAssertEqual(review.groups[.shaky].first?.cause, .unknown)
        XCTAssertNil(review.groups[.solid].first?.cause)
        let newWords = try XCTUnwrap(summary.newWords)
        XCTAssertEqual(newWords.groups[.retried].first?.struggledAt, .unknown)
        XCTAssertEqual(newWords.groups[.revealed].first?.struggledAt, .speaking)
        XCTAssertEqual(newWords.groups[.known], [])
    }

    func testPracticeSummaryDecodesWithUnknownSkills() throws {
        let summary = try decodeSummary(#"""
        {"review":null,"newWords":null,
         "practice":{"total":1,"excluded":{"count":2,"reasons":["invalid_recording","something_new"]},
            "groups":{"clean":[{"meaningId":"m1","lemma":"vivid","skill":"grammar"},{"meaningId":"m2","lemma":"budget","skill":null}]}},
         "speaking":null,"skillChanges":null,
         "needPractice":{"before":3,"after":null},
         "countedAsReview":[{"meaningId":"m1","lemma":"vivid","nextReviewAt":"2026-11-22T13:00:00Z"}]}
        """#)
        let practice = try XCTUnwrap(summary.practice)
        XCTAssertEqual(practice.excluded?.count, 2)
        XCTAssertEqual(practice.groups[.clean].first?.skill, .unknown)
        XCTAssertNil(practice.groups[.clean].last?.skill)
        XCTAssertNil(summary.speaking)
        XCTAssertEqual(summary.needPractice, NeedPracticeCount(before: 3, after: nil))
        XCTAssertEqual(summary.countedAsReview?.count, 1)
    }

    func testSpeakingSummaryDecodes() throws {
        let summary = try decodeSummary(#"""
        {"review":null,"newWords":null,
         "speaking":{"total":3,"passed":2,
            "becameFluent":[{"meaningId":"m1","wordId":"w1","lemma":"vivid","gloss":"sống động","status":"fluent","score":91}],
            "slipped":[{"meaningId":"m2","lemma":"budget","gloss":"ngân sách","status":"practicing","score":null}]}}
        """#)
        let speaking = try XCTUnwrap(summary.speaking)
        XCTAssertEqual(speaking.total, 3)
        XCTAssertEqual(speaking.passed, 2)
        XCTAssertEqual(speaking.becameFluent.first?.status, .fluent)
        XCTAssertEqual(speaking.becameFluent.first?.score, 91)
        XCTAssertEqual(speaking.slipped.first?.status, .practicing)
        XCTAssertNil(speaking.slipped.first?.score)
    }

    func testEncodesTheSpeakingPracticeMode() throws {
        let capabilities = PlanRequest.Capabilities(audioPlayback: true, microphone: true)
        let body = try JSONEncoder().encode(PlanRequest(mode: .speakingPractice, capabilities: capabilities))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["mode"] as? String, "speaking_practice")
        XCTAssertEqual(TaskPhase(rawValue: "speaking_practice"), .speakingPractice)
    }
}
