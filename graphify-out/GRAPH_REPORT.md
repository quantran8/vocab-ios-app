# Graph Report - ios_app  (2026-11-22)

## Corpus Check
- 270 files · ~224,642 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 13 file(s) not represented in the graph (top: (none) 2, .riv 2, .xcstrings 2)

## Summary
- 5127 nodes · 12914 edges · 223 communities (193 shown, 30 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 2150 edges (avg confidence: 0.84)
- Token cost: 773,720 input · 0 output

## Community Hubs (Navigation)
- Learner Store & API Surface
- API Wire Helpers & Fixtures
- Ranking & Leaderboard Models
- Controls & Profile UI
- Practice Session Store (Daily Flow)
- Live Vocab API Client
- Plan Decoding & Lab Templates
- Local Learning Progress
- Auth & Social Sign-In
- Primary Button Styles
- Custom Word Store
- Localization & Languages
- Add Word Screen
- Selection Controls
- Match Madness Engine
- Learning Plan Preferences
- Task Attempt Rules
- Landing Page v3
- Typography & Syllie Reactions
- Word Meaning & Learn Card
- Custom Word Model
- Demo Session Views (Learn/Build)
- Challenge Run Wire Models
- Result Summary Models
- Challenge Map View
- Audio Recording & Session
- Speech Synthesis & Wave Icon
- Intro Motion Presentation
- Sheets & App Settings
- Ranking View & Public Profile
- Result Detail Sheet
- Onboarding Flow
- Reorder Task View
- Challenge Map Models & iOS Notes
- Landing Page v2
- Review Load Choice
- Practice Session Store Tests
- Plan Controls UI
- Motion Tokens
- Challenge Run Store
- Demo Session Reducer
- Surgery Task View
- Answer Evaluation (Demo)
- App Root & Routing
- Audio Playback & Scoring
- Random Practice View
- Cloze Task View
- Task Event
- My Words View
- Placement Test Store Tests
- Home View
- Main Shell View
- Practice Audio
- Session Store
- 03 BACKEND
- Challenge Run Models
- Onboarding Store
- Practice Session Store Tests (2)
- Motion Coordinator
- Challenge Map Store
- Syllie View
- Session Reducer Tests
- Session Result
- Challenge Run Store Tests
- APIClient
- Match Madness Game View
- Topic Catalog
- Content Validator
- Journey Snake Layout
- Result Summary Models (2)
- Pronunciation Score
- Recall View
- Onboarding Store Tests
- Session Celebration View
- 02 FRONTEND
- Word Source Tests
- Word Intro Content
- Word Stack Board
- Journey View
- Plan Decoding Tests
- Token Store
- Password Policy
- Decorations
- Journey
- Scope Review Load Tests
- Task Attempt Tests
- Challenge Results View
- Practice Session View
- Result Tile View
- Pronunciation Result Views
- generate
- Task Scaffold
- 01 APP CONCEPT
- Step Action Bar
- Home Syllie View
- Custom Word
- Task Attempt
- APIError
- App Settings Store
- Pronunciation Score (2)
- Practice Results View
- Auth View
- Challenge Run Store (2)
- Challenge Map Models
- Practice Task
- Result Summary Models (3)
- Result Summary Models (4)
- Custom Words View
- Practice Session View (2)
- Session Celebration View (2)
- Recording Task View
- Challenge Components
- Practice Result
- Build Interaction State
- index
- Match Task View
- Draggable Word Tile
- Custom Word Edit View
- Journey Node View
- Journey Tests
- Spec: Session Result Statistics v1
- Feedback Haptics
- app redesign v1
- Result Sheet Model
- app redesign v1 (2)
- color palette v2
- Flow Header
- Highlighted Sentence
- Syllie Artboard View
- System Back Button
- Form Fields
- Practice Task (2)
- Task Event (2)
- Sign Up View
- Practice Fixtures
- Syllie View (2)
- Custom Word (2)
- Challenge Run Store (3)
- Choice Task View
- Recording Task View (2)
- Word Tile
- Feedback Banner
- Challenge Board Ordering
- Result Summary Models (5)
- Auth Components
- Vocab API
- Learner Words Tests
- AUTH SETUP
- app redesign v1 (3)
- Word Intro Content (2)
- Vocabulary Item
- Transcript Matcher Tests
- Template Parts
- Journey Segment Strip
- Result Sheet Model (2)
- Lab Library Tests
- Custom Word (3)
- Feedback Haptics (2)
- inky idle
- Practice Session Store
- Flow Layout
- Highlighted Sentence Tests
- Symbol Motion
- Practice Task (3)
- Challenge Components (2)
- APIClient Tests
- App Language Tests
- app redesign v1 (4)
- Confirm Sheet
- 02 FRONTEND (2)
- Challenge Home Card
- Demo Content Repository
- Learning Preferences
- Task Scaffold (2)
- Change Password Sheet
- Placement Test Store
- Placement Test View
- Practice Result (2)
- app redesign v1 (5)
- APIClient Tests (2)
- Primary Button
- Word Tile (2)
- Challenge Board Slots Tests
- Custom Word (4)
- Session Reducer
- 03 BACKEND (2)
- Shake Effect
- Demo Seed
- Practice Task (4)
- Controls
- Controls (2)
- Attempt
- Task Attempt (2)
- Practice Session Store (2)
- Practice Result (3)
- Syllie Preview View
- color palette v2 (2)
- README
- Progress Track
- Hint Control
- Recall Input
- Practice Task (5)
- Result Summary Models (6)
- Practice Result (4)
- CLAUDE
- app redesign v1 (6)
- app redesign v1 (7)
- color palette v2 (3)
- 04 CHALLENGE IOS NOTES
- Practice Task (6)
- Practice Task (7)
- Result Sheet Model (3)
- Drop Slot
- Custom Word (5)
- Journey (2)
- Choice Task View (2)
- Match Madness Engine (2)
- Word Meaning Views
- .mcp
- DESIGN SYSTEM

## God Nodes (most connected - your core abstractions)
1. `PracticeSessionStore` - 142 edges
2. `Typography` - 111 edges
3. `StubVocabAPI` - 110 edges
4. `TaskAttempt` - 109 edges
5. `VocabAPI` - 74 edges
6. `LiveVocabAPI` - 73 edges
7. `ChallengeRunStore` - 72 edges
8. `PrimaryButton` - 57 edges
9. `APIClient` - 57 edges
10. `LearningPreferences` - 55 edges

## Surprising Connections (you probably didn't know these)
- `Bottom feedback panel states` --references--> `TaskScaffold`  [INFERRED]
  docs/DESIGN_SYSTEM.md → VocabFlow/Features/Practice/Tasks/TaskScaffold.swift
- `403 WRONG_PASSWORD (not 401)` --conceptually_related_to--> `APIClient`  [INFERRED]
  docs/AUTH_SETUP.md → VocabFlow/Networking/APIClient.swift
- `Borders and depth edges (no shadows on cards)` --references--> `FlowHeader`  [AMBIGUOUS]
  docs/DESIGN_SYSTEM.md → VocabFlow/DesignSystem/Components/FlowHeader.swift
- `MatchMadness engine/backend parity` --rationale_for--> `MatchMadnessEngine`  [EXTRACTED]
  CLAUDE.md → VocabFlow/Domain/Challenge/MatchMadnessEngine.swift
- `Legacy demo engine (Learn → Build → Recall)` --references--> `SessionReducer`  [EXTRACTED]
  docs/syll/02_FRONTEND.md → VocabFlow/Domain/Learning/SessionReducer.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Session results pipeline (server groups -> tiles -> detail sheet)** — spec__session_result_statistics_v1_commit_summary_response, vocabflow_domain_practice_practicetask_commitsummary, vocabflow_features_practice_results_practiceresult_resulttiles, vocabflow_features_practice_results_sessionresultdetailsheet_sessionresultdetailsheet, docs_design_system_results_screen [INFERRED 0.85]
- **Password rules kept in sync across app, backend and Supabase** — docs_auth_setup_password_rules, vocabflow_features_auth_passwordpolicy_passwordpolicy, docs_auth_setup_supabase [EXTRACTED 1.00]
- **App, DESIGN_SYSTEM.md and app-redesign-v1.html kept in sync** — claude_three_sources_in_sync, docs_design_system_doc, vocabflow_designsystem_tokens_colors, docs_design_system_role_tokens [INFERRED 0.85]
- **Plan → attempt → commit → re-grade pipeline** — docs_syll_03_backend_session_planner, docs_syll_02_frontend_plan_decode, docs_syll_02_frontend_task_attempt_rules, docs_syll_02_frontend_commit_byte_identical, docs_syll_03_backend_session_commit, docs_syll_03_backend_practice_evaluator [INFERRED 0.85]
- **Commit produces memory signals, SRS schedule and skill evidence** — docs_syll_03_backend_session_commit, docs_syll_03_backend_memory_signals, docs_syll_03_backend_srs_scheduler, docs_syll_03_backend_skill_verification [EXTRACTED 1.00]
- **Match Madness backend parity (engine, ordering, slots, parity tests)** — docs_syll_04_challenge_ios_notes_backend_parity_rule, docs_syll_04_challenge_ios_notes_fixed_slot_board, docs_syll_04_challenge_ios_notes_refill_rule, docs_syll_04_challenge_ios_notes_recheck_procedure, vocabflow_domain_challenge_matchmadnessengine_matchmadnessengine, vocabflow_domain_challenge_challengeboardordering_challengeboardordering [EXTRACTED 1.00]
- **Daily session flow: preview → tasks → celebration → summary → details** — docs_app_redesign_v1_screen_home, docs_app_redesign_v1_screen_review_preview, docs_app_redesign_v1_screen_select_task, docs_app_redesign_v1_screen_review_finished, docs_app_redesign_v1_screen_word_intro, docs_app_redesign_v1_screen_celebration, docs_app_redesign_v1_screen_results_summary, docs_app_redesign_v1_screen_result_detail_sheet [EXTRACTED 1.00]
- **Onboarding steps** — docs_app_redesign_v1_screen_ob_welcome, docs_app_redesign_v1_screen_ob_level, docs_app_redesign_v1_screen_placement_test, docs_app_redesign_v1_screen_ob_collection, docs_app_redesign_v1_screen_ob_topics, docs_app_redesign_v1_screen_ob_routine, docs_app_redesign_v1_screen_ob_ready [EXTRACTED 1.00]
- **Task templates sharing the scaffold (question, prompt, content, Syllie panel)** — docs_app_redesign_v1_task_cloze, docs_app_redesign_v1_task_typing, docs_app_redesign_v1_task_reorder, docs_app_redesign_v1_task_match, docs_app_redesign_v1_task_surgery, docs_app_redesign_v1_task_recording, docs_app_redesign_v1_screen_select_task, docs_app_redesign_v1_feedback_panel [EXTRACTED 1.00]
- **Syll Ink palette ramps (Ink, Blue, Green, Coral, Sun)** — docs_color_palette_v2_ink_ramp, docs_color_palette_v2_blue_ramp, docs_color_palette_v2_green_ramp, docs_color_palette_v2_coral_ramp, docs_color_palette_v2_sun_ramp [EXTRACTED 1.00]
- **Button colour roles (general Ink, practice Blue, feedback Green/Coral)** — docs_color_palette_v2_primary_action, docs_color_palette_v2_practice_action, docs_color_palette_v2_feedback_buttons, docs_color_palette_v2_button_44pt [EXTRACTED 1.00]
- **Landing value propositions strip** — landing_index_five_minutes, landing_index_seven_task_types, landing_index_spaced_review, landing_index_bilingual [EXTRACTED 1.00]
- **Daily session flow: review, new words, practice** — landing_v2_step_review, landing_v2_step_new_words, landing_v2_step_practice, landing_v2_word_intro [EXTRACTED 1.00]
- **Hero demo: select, cloze, match, celebrate** — landing_v2_tpl_select, landing_v2_tpl_cloze, landing_v2_tpl_match, landing_v2_celebrate_results [EXTRACTED 1.00]
- **Personalization: level, routine, home** — landing_v2_level_picker, landing_v2_routine, landing_v2_home_replica [INFERRED 0.85]
- **Daily smart learning loop: review → new words → pronunciation → weak practice** — landing_v3_spaced_review, landing_v3_review_before_new, landing_v3_pronunciation_scoring, landing_v3_weak_words_practice [EXTRACTED 1.00]
- **Personal session building: collection → topics → own words → today's session** — landing_v3_goal_collections, landing_v3_topic_selection, landing_v3_custom_words, landing_v3_today_session_preview [EXTRACTED 1.00]
- **Reasons to open app daily** — landing_v3_syllie_companion, landing_v3_home_syllie, landing_v3_instant_feedback, landing_v3_session_celebration, landing_v3_no_pressure [EXTRACTED 1.00]
- **Black-cloud Syllie asset family (design sources and shipped icons)** — design_inky_inky_idle, design_inky_inky_idle_v2, design_inky_app_icon, vocabflow_resources_assets_xcassets_appicon_appiconset_appicon_1024, vocabflow_resources_assets_xcassets_brandicon_imageset_brandicon_3x, vocabflow_resources_assets_xcassets_launchsylliev2_imageset_launchsylliev2_3x [INFERRED 0.95]
- **SVGs sharing the identical gradient/filter shading recipe** — design_inky_inky_idle, design_inky_inky_idle_v2, design_inky_app_icon, design_inky_inky_idle_soft_3d_shading [EXTRACTED 1.00]

## Communities (223 total, 30 thin omitted)

### Community 0 - "Learner Store & API Surface"
Cohesion: 0.04
Nodes (36): LearnerStore, .shouldOfferReviewChoice, CatalogCollection, CatalogTopic, CheckpointChallenge, LearnHome, .checkpointProgress, LearningScope (+28 more)

### Community 1 - "API Wire Helpers & Fixtures"
Cohesion: 0.04
Nodes (23): String, .trimmed, CommitStatus, AvatarStyle, LeaderboardView, around, top, PublicProfile (+15 more)

### Community 2 - "Ranking & Leaderboard Models"
Cohesion: 0.05
Nodes (52): CommitLP, CommitRanking, CommitTier, Leaderboard, LeaderboardRow, .id, LPBreakdown, MyRanking (+44 more)

### Community 3 - "Controls & Profile UI"
Cohesion: 0.05
Nodes (49): CardDivider, .body, CardRow, .body, IconBadge, .body, .colors, IconButton (+41 more)

### Community 4 - "Practice Session Store (Daily Flow)"
Cohesion: 0.04
Nodes (40): Daily chain pendingReviewSummary merge, DailyLessonStatus (Home Daily Lesson card), Review-only session, Merging two daily commits (pendingReviewSummary), PlanStep, .isDueReview, learn, practice (+32 more)

### Community 5 - "Live Vocab API Client"
Cohesion: 0.07
Nodes (15): CustomWordQuery, LiveVocabAPI, Credentials, IDTokenCredentials, LearnerReport, Levels, PasswordChange, PasswordReset (+7 more)

### Community 6 - "Plan Decoding & Lab Templates"
Cohesion: 0.05
Nodes (49): LabLibrary, ValidationError, duplicateTaskID, emptyTemplate, missingTemplate, templateMismatch, LabTemplate, AudioClip (+41 more)

### Community 7 - "Local Learning Progress"
Cohesion: 0.07
Nodes (21): LearnedWord, LearningProgress, TodayStatus, .fraction, Mode, completed, learning, rest (+13 more)

### Community 8 - "Auth & Social Sign-In"
Cohesion: 0.05
Nodes (19): AuthenticationServices, CryptoKit, .body, AuthStore, Phase, launching, signedIn, signedOut (+11 more)

### Community 9 - "Primary Button Styles"
Cohesion: 0.07
Nodes (46): .screen, .body, ActionButtonLabel, .body, ActionButtonStyle, .depth, .depthColor, .face (+38 more)

### Community 10 - "Custom Word Store"
Cohesion: 0.06
Nodes (17): CustomWordStore, .isPlayingAudio, .lastContext, ListPhase, failed, loading, ready, LookupPhase (+9 more)

### Community 11 - "Localization & Languages"
Cohesion: 0.05
Nodes (40): Arabic RTL layout (leading/trailing only), Target markets and required languages, Eleven supported languages (vi, en, hi, es, ja, pt-BR, ko, zh-Hant, th, ar, id), Machine translations need native review, Arabic RTL review, uiLocale sent to backend, os, ResultLabFixture (+32 more)

### Community 12 - "Add Word Screen"
Cohesion: 0.08
Nodes (36): AddedConfirmation, AddWordHeader, AddWordScaffold, .body, AddWordView, .stageView, CenteredStage, .body (+28 more)

### Community 13 - "Selection Controls"
Cohesion: 0.06
Nodes (43): .body, IconButtonLabel, .body, .body, SelectionMark, .body, Eyebrow, .body (+35 more)

### Community 14 - "Match Madness Engine"
Cohesion: 0.09
Nodes (17): ChallengePairOccurrence, .id, MatchMadnessAction, tapMeaning, tapWord, MatchMadnessEngine, .goal, MatchMadnessFeedback (+9 more)

### Community 15 - "Learning Plan Preferences"
Cohesion: 0.06
Nodes (18): LearningPreferences, .effectiveReviewsPerSession, .hasAllTopics, .isComplete, .isEveryDay, .reminderDate, .weeklySessionGoal, InMemoryPreferencesStore (+10 more)

### Community 16 - "Task Attempt Rules"
Cohesion: 0.09
Nodes (16): TaskAttempt, .acceptedAnswer, .allPairsText, .bankTiles, .canAnswer, .canRecordAgain, .canReveal, .canUseHint (+8 more)

### Community 17 - "Landing Page v3"
Cohesion: 0.06
Nodes (43): Brand promise: Học đúng từ, nhớ thật lâu (Learn the right words, remember for long), Levels A1–C2 with optional placement test, 03 Craft section: Cảm nhận được ngay từ cú chạm đầu tiên, CTA: Tải Syll / App Store download, CTA: Xem cách Syll dạy (see how Syll teaches), Custom words: add any word, Syll adds pronunciation & example, editable private meaning, Daily routine: user picks new words/day, days, reminder time, FAQ section: Trước khi bắt đầu (+35 more)

### Community 18 - "Typography & Syllie Reactions"
Cohesion: 0.06
Nodes (32): .body, .body, SyllieReactionView, .body, Typography, .challengeTerm, .choice, .feedbackTitle (+24 more)

### Community 19 - "Word Meaning & Learn Card"
Cohesion: 0.07
Nodes (27): LearnCardStep, .body, ExpandChevron, .body, MeaningFields, .body, MemoryStrengthRow, .body (+19 more)

### Community 20 - "Custom Word Model"
Cohesion: 0.09
Nodes (21): NaturalLanguage, CustomWordEditDraft, .edits, Example, .isRewritten, .isUnchanged, .isValid, CustomWordEdits (+13 more)

### Community 21 - "Demo Session Views (Learn/Build)"
Cohesion: 0.08
Nodes (14): BuildView, .body, .incorrectTileID, LearnView, .body, FlowActionBar, .body, FlowDraft (+6 more)

### Community 22 - "Challenge Run Wire Models"
Cohesion: 0.08
Nodes (30): ChallengeCommitBody, ChallengeCommitResponse, ChallengeEndedReason, goalReached, quit, timeUp, ChallengeErrorCode, ChallengeRunPlan (+22 more)

### Community 23 - "Result Summary Models"
Cohesion: 0.15
Nodes (15): CommitSummary, NeedPracticeCount, NewWordSummary, PracticeSummary, ResultGroups, ReviewSummary, SpeakingSummary, PracticeResult (+7 more)

### Community 24 - "Challenge Map View"
Cohesion: 0.07
Nodes (33): CalloutShape, ChallengeChapterSection, .bannerStyle, .body, .statusLabel, ChallengeLevelNode, .accessibilityLabel, .depth (+25 more)

### Community 25 - "Audio Recording & Session"
Cohesion: 0.08
Nodes (7): AudioSessionActivator, Configuration, NoVoiceRecorder, RecorderHandle, VoiceRecorder, .canRecord, VoiceRecording

### Community 26 - "Speech Synthesis & Wave Icon"
Cohesion: 0.07
Nodes (14): AVFoundation, AudioPlayButton, .body, .icon, SoundControlButtonStyle, SpeakerBody, SpeakerWave, SpeakerWaveIcon (+6 more)

### Community 27 - "Intro Motion Presentation"
Cohesion: 0.06
Nodes (23): IntroductionPresentation, IntroductionTemplateID, chunkMerge, flipLetters, .id, letterCascade, letterWave, swipeReveal (+15 more)

### Community 28 - "Sheets & App Settings"
Cohesion: 0.07
Nodes (18): FittedSheet, .body, syllables, GoogleMark, .body, PronunciationDetail, .body, .feedbackDetail (+10 more)

### Community 29 - "Ranking View & Public Profile"
Cohesion: 0.06
Nodes (24): .rankingStack, EditPublicProfileSheet, .avatarGrid, .canonicalName, .canSave, .nameChanged, .nameHint, .nameLocked (+16 more)

### Community 30 - "Result Detail Sheet"
Cohesion: 0.11
Nodes (15): ResultSheetBlock, .bar, .id, SpokenTally, ResultSheetGroup, .barLevel, .id, .showsNextReview (+7 more)

### Community 31 - "Onboarding Flow"
Cohesion: 0.07
Nodes (31): CollectionStep, .body, LevelStep, .body, OnboardingTitle, .body, OnboardingView, .body (+23 more)

### Community 32 - "Reorder Task View"
Cohesion: 0.10
Nodes (17): ReorderTaskView, .allTiles, .answerPanel, .body, .floatingTile, .isSingleWord, .minimumLines, .panelTiles (+9 more)

### Community 33 - "Challenge Map Models & iOS Notes"
Cohesion: 0.08
Nodes (24): Challenge Map / Match Madness iOS notes, Challenge error handling (CHALLENGE_RUN_ACTIVE, NOT_STARTED, time_up), iOS vs backend drift fixes (10/11/2026), Pending cleanup of Journey/checkpoint, Plan score rule (perSecondLeft clear bonus), Re-check procedure when backend changes, Refill rule (minMatchesBetweenRepeats), ChallengeChapter (+16 more)

### Community 34 - "Landing Page v2"
Cohesion: 0.07
Nodes (38): A1 to C2 level coverage, Results screen with Celebrate artboard and confetti, Checkpoint challenge after a few sessions, CTA: Download on App Store, CTA: Bắt đầu / Tải app, FAQ: Trước khi bắt đầu, Practice engine mirrors TaskScaffold feedback (Check / Try again / Show answer), Final CTA section with idle Syllie (+30 more)

### Community 35 - "Review Load Choice"
Cohesion: 0.06
Nodes (27): RankingPositionKind, percentile, rank, unranked, ReviewLoadChoiceSheet, .canLower, .lowerPicker, LenientEnum (+19 more)

### Community 37 - "Plan Controls UI"
Cohesion: 0.09
Nodes (20): .body, DailySpeakingToggle, .body, LearningDaysPicker, LearningDaysSummary, PlanSectionTitle, .body, ReminderPicker (+12 more)

### Community 38 - "Motion Tokens"
Cohesion: 0.08
Nodes (18): SwiftUI, MotionTokens, .animatedWord, ChunkMergeView, .body, FlipLettersView, .body, IntroGlyphRow (+10 more)

### Community 39 - "Challenge Run Store"
Cohesion: 0.12
Nodes (9): ChallengeRunStore, .canIssue, .engineGoal, .hasPendingRun, .hasSeenTutorial, .isActive, .remainingMs, ChallengeSandboxSummary (+1 more)

### Community 40 - "Demo Session Reducer"
Cohesion: 0.09
Nodes (25): Scored session demo engine (Learn->Build->Recall), SessionAction, advance, answerRevealed, buildSubmitted, feedbackDismissed, hintRequested, learnedNext (+17 more)

### Community 41 - "Surgery Task View"
Cohesion: 0.11
Nodes (14): ArcEffect, .animatableData, Flyer, FlyingPiece, .body, FrameID, key, letter (+6 more)

### Community 42 - "Answer Evaluation (Demo)"
Cohesion: 0.10
Nodes (8): AnswerEvaluator, BuildChallenge, WordOption, VocabularyItem, .allAcceptedForms, .partOfSpeechLabel, SessionFeedbackCopy, AnswerEvaluatorTests

### Community 43 - "App Root & Routing"
Cohesion: 0.06
Nodes (26): State architecture (@Observable @MainActor stores), AppRootView, .appRoute, .canLoadLearner, .isLaunchLoading, .route, RouteID, auth (+18 more)

### Community 44 - "Audio Playback & Scoring"
Cohesion: 0.11
Nodes (12): Speech, RecordingScoring, backend, onDevice, AudioClipPlayer, .canPlay, AudioClipPlaying, NoSpeechTranscriber (+4 more)

### Community 45 - "Random Practice View"
Cohesion: 0.10
Nodes (16): RandomPracticeView, .sourceCollections, .startRequirement, SelectAllButton, .body, SourceOptionRow, SourceText, .body (+8 more)

### Community 46 - "Cloze Task View"
Cohesion: 0.10
Nodes (17): TaskOption, ClozeFlightTarget, blank, slot, ClozeFramesKey, ClozeSentence, .blank, .body (+9 more)

### Community 47 - "Task Event"
Cohesion: 0.07
Nodes (25): .hasTranscripts, CommitBody, DeliveryMode, audio, fallback, none, RepairEdit, TaskEvent (+17 more)

### Community 48 - "My Words View"
Cohesion: 0.11
Nodes (17): CustomWordSheet, add, .id, list, LibraryStats, .body, MeaningDots, .body (+9 more)

### Community 49 - "Placement Test Store Tests"
Cohesion: 0.15
Nodes (4): PlacementTestStore, .currentQuestion, .isOnLastQuestion, PlacementTestStoreTests

### Community 50 - "Home View"
Cohesion: 0.12
Nodes (11): DailyLessonStatus, Scope, exhaustedNoCustom, exhaustedWithCustom, low, ok, HomeView, .body (+3 more)

### Community 51 - "Main Shell View"
Cohesion: 0.10
Nodes (18): MainShellView, .body, .homeStack, .profileStack, .wordsStack, PlanSheet, focus, .id (+10 more)

### Community 52 - "Practice Audio"
Cohesion: 0.11
Nodes (8): CuePlayer, Answer, correct, wrong, EnvironmentValues, SilentSoundEffects, SoundEffects, SoundEffectsPlaying

### Community 53 - "Session Store"
Cohesion: 0.10
Nodes (11): Content pipeline (bundled JSON validation), Practice Lab (sandbox, unscored), Seven backend task templates (TaskTemplate), Foundation, Observation, UserNotifications, FlowStage, learn (+3 more)

### Community 54 - "03 BACKEND"
Cohesion: 0.10
Nodes (22): ReviewLoadChoiceSheet (review backlog choice), Syll: Backend, Admin API (/admin), Auth and account (Supabase proxy, delete account), Backend modules (src/modules), Backend stack (NestJS on Fastify, Drizzle, Supabase Postgres), Custom words and AI drafts, DB conventions that are easy to break (UUID v7, hand-written SQL constraints, RLS) (+14 more)

### Community 55 - "Challenge Run Models"
Cohesion: 0.07
Nodes (24): NextAction, learnMore, openMap, playNextLevel, retry, unknown, Outcome, cleared (+16 more)

### Community 56 - "Onboarding Store"
Cohesion: 0.10
Nodes (14): OnboardingStore, .canContinueFromCollection, .canContinueFromTopics, Step, collection, level, placement, ready (+6 more)

### Community 57 - "Practice Session Store Tests (2)"
Cohesion: 0.15
Nodes (6): RecordedAudio, RecordingAssessment, .isValid, .scoreBand, .actions, .micButton

### Community 58 - "Motion Coordinator"
Cohesion: 0.10
Nodes (12): Motion, sound and haptics timings, DirectionalStepTransition, EnvironmentValues, .motion, MotionCoordinator, .liftedScale, .popTransition, .pressedScale (+4 more)

### Community 59 - "Challenge Map Store"
Cohesion: 0.12
Nodes (12): Challenge Map / Match Madness (concept), Concept vs implementation status (11/2026), Challenge Map, ChallengeNodeRef, .id, ChallengeLevelSheet, .localeNote, ChallengeMapStore (+4 more)

### Community 60 - "Syllie View"
Cohesion: 0.07
Nodes (26): .reactionDuration, .settledMood, SyllieMood, breath, deepThought, deepThoughtHold, excited, happy (+18 more)

### Community 61 - "Session Reducer Tests"
Cohesion: 0.24
Nodes (4): DemoContent, SessionState, SessionReducerTests, TestContent

### Community 62 - "Session Result"
Cohesion: 0.11
Nodes (20): RecallOutcome, hintedRecall, notRecalled, recalledAfterRetry, unaidedRecall, SessionResult, .afterRetryCount, .hintedCount (+12 more)

### Community 64 - "APIClient"
Cohesion: 0.10
Nodes (3): APIClient, ErrorBody, Scalar

### Community 65 - "Match Madness Game View"
Cohesion: 0.11
Nodes (11): ChallengeReadyView, .body, CloseRunButton, .body, MatchMadnessBoardView, .body, .exitMessage, .exitTitle (+3 more)

### Community 66 - "Topic Catalog"
Cohesion: 0.14
Nodes (11): CatalogState, Topic, .isFinished, TopicCatalog, .collections, VocabCollection, .isFinished, .topicIDs (+3 more)

### Community 67 - "Content Validator"
Cohesion: 0.10
Nodes (16): ContentIssue, acceptedOptionCount, duplicateID, emptyText, invalidAcceptedOption, invalidIntroChunks, missingBlank, optionCount (+8 more)

### Community 68 - "Journey Snake Layout"
Cohesion: 0.12
Nodes (10): .ordered, JourneySegmentLabel, .body, JourneySnakeLayout, PlacedLabel, .id, PlacedNode, .id (+2 more)

### Community 69 - "Result Summary Models (2)"
Cohesion: 0.10
Nodes (22): NewWordGroup, known, retried, revealed, smooth, PracticeGroup, clean, helped (+14 more)

### Community 70 - "Pronunciation Score"
Cohesion: 0.13
Nodes (9): PronunciationColoring, PronunciationSegment, PronunciationSyllable, SyllableBand, good, poor, unknown, .wordColor (+1 more)

### Community 71 - "Recall View"
Cohesion: 0.11
Nodes (7): ExerciseHeading, .body, HintSequence, RecallPrompt, .hints, RecallView, .body

### Community 73 - "Session Celebration View"
Cohesion: 0.15
Nodes (13): CelebrateV2Player, CelebrateV2View, .body, CelebrationCounts, CelebrationKind, collection, session, LPPill (+5 more)

### Community 74 - "02 FRONTEND"
Cohesion: 0.11
Nodes (21): Syll: Frontend features and core functions, Accessibility, Custom words (Add word), Home Syllie (HomeSyllie artboard), "I know this word" known check, Legacy demo engine (Learn → Build → Recall), Local storage (Keychain, UserDefaults), Localization rules (+13 more)

### Community 76 - "Word Intro Content"
Cohesion: 0.10
Nodes (17): .squareMarked, ExampleTranslation, .body, WordIntroContent, .bodyColor, .cardSections, .detailsToggle, .divider (+9 more)

### Community 77 - "Word Stack Board"
Cohesion: 0.14
Nodes (7): BuildInteractionState, .draggingTileID, WordStackBoard, .body, .completed, .sentencePanel, .tiles

### Community 78 - "Journey View"
Cohesion: 0.14
Nodes (13): JourneyView, .body, Hint, Kind, .announcement, locked, reviewDone, sessionDone (+5 more)

### Community 80 - "Token Store"
Cohesion: 0.15
Nodes (6): Security, .hasStoredSession, AuthTokens, InMemoryTokenStore, KeychainTokenStore, TokenStoring

### Community 81 - "Password Policy"
Cohesion: 0.12
Nodes (15): Change password in app, Password rules (8-72 chars, letter + digit), .canSubmit, .canSubmit, PasswordPolicy, Rule, digit, .id (+7 more)

### Community 82 - "Decorations"
Cohesion: 0.11
Nodes (14): Lottie, CelebrationBadge, .body, ConfettiBurst, .body, BrandBar, .body, CardSurface (+6 more)

### Community 83 - "Journey"
Cohesion: 0.13
Nodes (16): Journey, .currentSegment, .focusNode, .preview, JourneyNode, Kind, learning, review (+8 more)

### Community 84 - "Scope Review Load Tests"
Cohesion: 0.17
Nodes (6): CommitResponse, KnownCheck, ScopeEvents, .isEmpty, ScopeReviewLoadTests, .knownCheckPlan

### Community 86 - "Challenge Results View"
Cohesion: 0.12
Nodes (14): ChallengeResultsView, .actions, .celebrationEarned, .chip, .goal, .headline, .nextChapterNeedsWords, .note (+6 more)

### Community 87 - "Practice Session View"
Cohesion: 0.13
Nodes (14): SyllieLoadingView, .body, .body, BusyIndicator, .body, PracticeFlowView, .body, ScopeCompletionCard (+6 more)

### Community 88 - "Result Tile View"
Cohesion: 0.12
Nodes (13): ResultSwatch, .body, ResultTile.Caption, .text, ResultTile.Line, .text, ResultTileView, .body (+5 more)

### Community 89 - "Pronunciation Result Views"
Cohesion: 0.13
Nodes (12): CountingNumber, .animatableData, .body, .body, PronunciationSummary, RecordingPromptStyle, scored, scoring (+4 more)

### Community 90 - "generate"
Cohesion: 0.20
Nodes (11): ctl(), inky(), inner(), path(), build_previews(), clip(), generate(), main() (+3 more)

### Community 91 - "Task Scaffold"
Cohesion: 0.12
Nodes (9): Syllie Rive mascot (artboards, state machines, moods), Syllie as emotional layer (never changes learning results), MeaningCueText, .body, TapOutside, TaskFeedbackCopy, TaskScaffold, .body (+1 more)

### Community 92 - "01 APP CONCEPT"
Cohesion: 0.15
Nodes (17): Syll: App Concept, Collection, Core learning loop: Choose → Learn → Interact → Recall → Return, Core practice loop (Enter → Act → Feedback → Momentum → Recall → Micro-victory), Four skills per meaning (Reading, Writing, Listening, Speaking), Micro-lesson (3–5 words, 2–5 min), MVP scope, Onboarding: Collection first, Topic after (+9 more)

### Community 93 - "Step Action Bar"
Cohesion: 0.15
Nodes (10): EnvironmentValues, .stepActionBarHost, PracticeActionBar, .body, StepActionBar, StepActionBarHost, StepActionBarHostKey, StepActionBarKey (+2 more)

### Community 94 - "Home Syllie View"
Cohesion: 0.13
Nodes (12): HomeSylliePlayer, HomeSyllieScene, .duration, idle, planeChase, playLetters, sleepy, wakeUp (+4 more)

### Community 95 - "Custom Word"
Cohesion: 0.12
Nodes (10): CustomWordLookup, draft, existing, invalid, newMeaningDraft, ExistingWord, .body, Stage (+2 more)

### Community 96 - "Task Attempt"
Cohesion: 0.10
Nodes (9): PracticeAnswer, .solutionText, PracticeTaskView, .body, TypingTaskView, .answerField, .canCheck, LabTaskView (+1 more)

### Community 97 - "APIError"
Cohesion: 0.10
Nodes (14): Failure, cancelled, notConfigured, rejected, APIError, .code, invalidResponse, .isRetryable (+6 more)

### Community 98 - "App Settings Store"
Cohesion: 0.11
Nodes (9): AppSettingsStore, .hapticsEnabled, Keys, .reduceMotion, EditFocusView, .collectionChips, .droppedLearnedTopics, EditRoutineView (+1 more)

### Community 99 - "Pronunciation Score (2)"
Cohesion: 0.11
Nodes (16): Daily speaking setting, Scored read-aloud (T7b), Audio buttons (speaker and mic), Bottom feedback panel states, Scored read-aloud UI (T7b), PronunciationBand, excellent, fair (+8 more)

### Community 100 - "Practice Results View"
Cohesion: 0.13
Nodes (14): Practice results screen, ResultSection, newWords, practice, review, speaking, weak, LegacyResultGrid (+6 more)

### Community 101 - "Auth View"
Cohesion: 0.12
Nodes (13): AuthView, Field, email, password, .logInError, .trimmedEmail, ResetPasswordView, .body (+5 more)

### Community 102 - "Challenge Run Store (2)"
Cohesion: 0.10
Nodes (20): Failure, contentUnavailable, expired, invalidEvents, issue, levelLocked, notEnoughVocabulary, start (+12 more)

### Community 103 - "Challenge Map Models"
Cohesion: 0.12
Nodes (15): State, active, completed, contentUnavailable, unknown, State, locked, needsVocabulary (+7 more)

### Community 104 - "Practice Task"
Cohesion: 0.12
Nodes (13): PlanRequest, Capabilities, PracticeFilter, collection, customWords, topics, SessionMode, checkpointChallenge (+5 more)

### Community 105 - "Result Summary Models (3)"
Cohesion: 0.12
Nodes (15): ResultCause, hinted, notPassed, outOfTries, primed, recognizedOnly, retried, revealed (+7 more)

### Community 106 - "Result Summary Models (4)"
Cohesion: 0.13
Nodes (6): Key, .intValue, ResultItem, SpeakingGroup, notPassed, passed

### Community 107 - "Custom Words View"
Cohesion: 0.18
Nodes (7): CustomWordsView, .content, .moreIcon, RowAction, edit, remove, restore

### Community 108 - "Practice Session View (2)"
Cohesion: 0.22
Nodes (6): ReviewPreviewView, .body, .entranceTiming, TileWiggle, Frame, ReviewWord

### Community 109 - "Session Celebration View (2)"
Cohesion: 0.15
Nodes (11): CelebrationVariant, bounce, fireworks, flip, .landing, loop, puff, SoundCue (+3 more)

### Community 110 - "Recording Task View"
Cohesion: 0.23
Nodes (8): ListeningBars, .body, RecordingPulseButton, .body, .isBreathing, .isLive, VoiceEnvelope, Output

### Community 111 - "Challenge Components"
Cohesion: 0.16
Nodes (8): ChallengeTimeFormat, MatchTilePressStyle, StarRow, .body, StarRules, .body, MapNodeButtonStyle, .timer

### Community 112 - "Practice Result"
Cohesion: 0.11
Nodes (16): Line, alreadyKnew, becameFluent, helped, missed, neededRetry, relearn, sawAnswer (+8 more)

### Community 113 - "Build Interaction State"
Cohesion: 0.12
Nodes (10): CoreGraphics, Borders, Radii, Spacing, TileInteractionPhase, dragging, evaluating, idle (+2 more)

### Community 114 - "index"
Cohesion: 0.17
Nodes (17): Inside The App Gallery (Home, New Word, Practice, Results), Final CTA: Download On App Store, Bilingual Vietnamese Meanings, FAQ (audience, time, vs flashcards, own words, iOS 17+ only), Five Minutes A Day, Small Habit: Reminders, No Hearts Or Leaderboard, Interactive Hero Lesson Demo, Learn Vocabulary By Doing (+9 more)

### Community 115 - "Match Task View"
Cohesion: 0.29
Nodes (3): PairKey, MatchTaskView, .body

### Community 116 - "Draggable Word Tile"
Cohesion: 0.17
Nodes (5): DraggableWordTile, .accessibilityValue, .body, .displayedState, .gesture

### Community 117 - "Custom Word Edit View"
Cohesion: 0.15
Nodes (10): .body, CustomWordEditFields, .body, CustomWordEditView, .body, EditorField, .body, .isTooLong (+2 more)

### Community 118 - "Journey Node View"
Cohesion: 0.16
Nodes (12): JourneyNodeButtonStyle, JourneyNodeView, .accessibilityHint, .accessibilityLabel, .body, .focusRing, .glyph, .isReview (+4 more)

### Community 120 - "Spec: Session Result Statistics v1"
Cohesion: 0.14
Nodes (14): Session results: tiles and detail sheet, Results screen and session detail sheet design, Commit summary response (review/newWords), countedAsReview, Session result detail sheet, LP tile open decision, needPractice before/after (Weak tile), New-word groups (known / smooth / retried / revealed) (+6 more)

### Community 121 - "Feedback Haptics"
Cohesion: 0.17
Nodes (4): CoreHaptics, FeedbackProviding, NoOpFeedback, SettingsAwareFeedback

### Community 122 - "app redesign v1"
Cohesion: 0.22
Nodes (16): Answer tiles with depth edge (rest/selected/correct/wrong/off), Flow 1 · Today's lesson (daily session), 1.12a Celebration · collection finished (trophy), 1.1 Home, 1.1a Home · collection finished, 1.10a Other meanings sheet, 1.13 Session details sheet, 1.13a Session details · Speaking block (+8 more)

### Community 123 - "Result Sheet Model"
Cohesion: 0.12
Nodes (16): Kind, .barLevel, becameFluent, clean, helped, known, missed, notPassed (+8 more)

### Community 124 - "app redesign v1 (2)"
Cohesion: 0.19
Nodes (14): Flow 0b · Onboarding, Flow 4 · Profile & settings, 4.4 Delete account confirm sheet, 4.2 Edit routine sheet, 0b.4 Collection picker, 0b.3 English level picker (A1–C2), 0b.7 Plan ready, 0b.6 Routine (stepper, days, reminder, daily speaking toggle) (+6 more)

### Community 125 - "color palette v2"
Cohesion: 0.17
Nodes (11): Blue Ramp (accent, #3E68DB), Collection Marks (Everyday, Business, IELTS, TOEIC, My Words), WCAG Contrast Check Per Ramp Step, Coral Ramp (error, #FF5A3C), Syll Ink Palette (color-palette-v2), Feedback Panel Buttons (Green 600 / Coral 600), Green Ramp (success, #2BC86A), Open Decisions (HomeSyllie props, DESIGN_SYSTEM.md 4.1) (+3 more)

### Community 126 - "Flow Header"
Cohesion: 0.13
Nodes (10): Answer tiles (states, regular weight), Borders and depth edges (no shadows on cards), Button kinds (Ink, Blue, Green, Coral, Outline, Link), FlowHeader, .body, .fraction, .segmentedBar, Style (+2 more)

### Community 127 - "Highlighted Sentence"
Cohesion: 0.16
Nodes (6): HighlightedSentence, .body, .marked, HighlightRun, RoundedHighlightRenderer, .displayPadding

### Community 128 - "Syllie Artboard View"
Cohesion: 0.18
Nodes (7): RiveRuntime, SyllieArtboardPlayer, SyllieArtboardView, .body, SyllieFile, SplashView, .body

### Community 129 - "System Back Button"
Cohesion: 0.13
Nodes (4): UIKit, UINavigationController, SystemBackButton, View

### Community 130 - "Form Fields"
Cohesion: 0.17
Nodes (7): FieldErrorText, .body, LabeledField, .body, PasswordInput, .body, .form

### Community 131 - "Practice Task (2)"
Cohesion: 0.13
Nodes (15): CodingKeys, evaluation, id, ipa, maxRetries, meaningCue, options, pairs (+7 more)

### Community 132 - "Task Event (2)"
Cohesion: 0.13
Nodes (15): CodingKeys, assessmentReceiptId, elapsedMs, graphemeIndex, leftId, optionId, reason, replacement (+7 more)

### Community 133 - "Sign Up View"
Cohesion: 0.17
Nodes (7): AuthMessage, .body, SignUpView, .body, Field, email, password

### Community 135 - "Syllie View (2)"
Cohesion: 0.19
Nodes (5): SylliePlayer, SyllieView, .body, .canWake, .shownMood

### Community 136 - "Custom Word (2)"
Cohesion: 0.20
Nodes (11): CustomWord, .id, .isEditable, CustomWordGroup, .firstEditable, .id, .meaningText, .recalled (+3 more)

### Community 137 - "Challenge Run Store (3)"
Cohesion: 0.15
Nodes (10): ChallengeRunOutcome, .chapterCleared, .isCleared, .isFirstClear, .isNewBest, .nextNode, .result, .unlockKind (+2 more)

### Community 138 - "Choice Task View"
Cohesion: 0.20
Nodes (9): ChoiceOptionFace, .body, .border, .depth, .face, .foreground, ChoiceOptionPressStyle, ChoiceTaskView (+1 more)

### Community 139 - "Recording Task View (2)"
Cohesion: 0.21
Nodes (8): RecordingTaskView, .canUseMic, .feedback, .isRecording, .promptStyle, .scored, ScoredTake, .status

### Community 140 - "Word Tile"
Cohesion: 0.15
Nodes (10): WordTile, .body, .border, .borderWidth, .depth, .face, .faceDrop, .foreground (+2 more)

### Community 141 - "Feedback Banner"
Cohesion: 0.29
Nodes (7): FeedbackActionPanel, .body, FeedbackCopy, FeedbackKind, error, info, success

### Community 142 - "Challenge Board Ordering"
Cohesion: 0.26
Nodes (5): ChallengeBoardOrdering, Side, meaning, word, ChallengeBoardOrderingTests

### Community 143 - "Result Summary Models (5)"
Cohesion: 0.15
Nodes (13): CodingKeys, band, cause, gloss, learnedAt, lemma, meaningId, nextReviewAt (+5 more)

### Community 144 - "Auth Components"
Cohesion: 0.19
Nodes (8): AuthBrand, .body, AuthEmailField, .body, AuthFooterLink, .body, .body, .emailStep

### Community 145 - "Vocab API"
Cohesion: 0.17
Nodes (10): .example, .title, CEFRLevel, a1, a2, b1, b2, c1 (+2 more)

### Community 147 - "AUTH SETUP"
Cohesion: 0.18
Nodes (10): Persistence (Keychain tokens, UserDefaults stores), VocabFlow iOS App (CLAUDE.md guide), Auth setup guide (Google, Apple, password reset), Google sign-in via OAuth code + PKCE (no SDK), In-app password reset by emailed code, Sign in with Apple, Custom SMTP requirement, Supabase auth provider configuration (+2 more)

### Community 148 - "app redesign v1 (3)"
Cohesion: 0.23
Nodes (7): Blue ramp (accent), Coral ramp (wrong), Fields, chips, status pills, Foundations: tokens & components, Green ramp (correct), Ink ramp (30%), Sun ramp (reward)

### Community 149 - "Word Intro Content (2)"
Cohesion: 0.17
Nodes (8): WordPronunciation, .buttonSize, .iconSide, .isPlaying, Style, compact, hero, standard

### Community 150 - "Vocabulary Item"
Cohesion: 0.17
Nodes (12): CodingKeys, acceptedForms, definitionEN, example, exampleTranslation, id, intro, ipa (+4 more)

### Community 152 - "Template Parts"
Cohesion: 0.20
Nodes (6): action, .body, ChoiceTileButton, .body, .choiceValue, ChoiceTilePressStyle

### Community 153 - "Journey Segment Strip"
Cohesion: 0.23
Nodes (3): JourneySegmentStrip, .body, Layout

### Community 154 - "Result Sheet Model (2)"
Cohesion: 0.23
Nodes (7): ResultDateText, NextReview, inDays, tomorrow, tonight, weekday, .calendar

### Community 155 - "Lab Library Tests"
Cohesion: 0.17
Nodes (5): CatalogAppearanceTests, LabLibraryTests, MatchMadnessBackendParityTests, Fixture, Step

### Community 156 - "Custom Word (3)"
Cohesion: 0.25
Nodes (7): CustomWordInput, Issue, empty, invalidCharacters, tooLong, WordEntry, .body

### Community 158 - "inky idle"
Cohesion: 0.31
Nodes (9): app-icon.svg (1024 icon source: Syllie V2 body on white), inky-idle.svg (original Syllie/inky idle pose, larger top lobe), Monochrome ink/white palette for the mascot, Soft 3D shading recipe (radial gradient #3a3a3a->#101010, inner shadow, rim light, blurred highlight, eye inner shadow), Syllie mascot design: limbless black cloud with two white pill eyes, inky-idle-v2.svg (Syllie idle pose, refined compact cloud outline), AppIcon-1024.png (app icon: black Syllie cloud on white), BrandIcon@3x.png (small black Syllie cloud brand mark) (+1 more)

### Community 159 - "Practice Session Store"
Cohesion: 0.18
Nodes (10): Stage, committing, empty, failed, finished, idle, planning, reviewFinished (+2 more)

### Community 162 - "Symbol Motion"
Cohesion: 0.31
Nodes (3): SymbolBounceOnceModifier, SymbolReplaceModifier, View

### Community 163 - "Practice Task (3)"
Cohesion: 0.18
Nodes (9): TaskPhase, checkpointChallenge, dueReview, knownCheck, newPractice, other, randomPractice, speakingPractice (+1 more)

### Community 164 - "Challenge Components (2)"
Cohesion: 0.20
Nodes (5): MatchMadnessTile, Side, meaning, word, .state

### Community 167 - "app redesign v1 (4)"
Cohesion: 0.31
Nodes (10): App redesign v1 (visual spec), Flow 3 · Add word, Flow 5 · Ranking, Flow 2 · My Words, 3.1–3.7 Add word single sheet (entry, loading, multi-sense result, edit, invalid), 2.5–2.6 Added words list, actions sheet, delete confirm, 2.1 My Words, 2.3–2.4 Random practice (word source picker) (+2 more)

### Community 168 - "Confirm Sheet"
Cohesion: 0.20
Nodes (6): 1.11 Leave session sheet, ConfirmSheet instead of alerts; no swipe actions/context menus, ConfirmSheet, Style, destructive, leavePractice

### Community 169 - "02 FRONTEND (2)"
Cohesion: 0.20
Nodes (9): Adding a new template, Practice Lab sandbox, Recording scoring (on-device / backend Azure / unavailable), Seven task templates (select, cloze_select, typing, fly_reorder, match, surgery, recording), Speech recording-assess (Azure Pronunciation Assessment), Landing page screenshots README, Landing page screenshot slots, og-image.png (1200×630) (+1 more)

### Community 170 - "Challenge Home Card"
Cohesion: 0.27
Nodes (4): Daily Lesson card (DailyLessonStatus), ChallengeHomeCard, .body, PlayAction

### Community 172 - "Learning Preferences"
Cohesion: 0.20
Nodes (10): CodingKeys, collectionID, dailySpeaking, learningDays, reminderEnabled, reminderHour, reminderMinute, reviewsPerSession (+2 more)

### Community 173 - "Task Scaffold (2)"
Cohesion: 0.22
Nodes (3): TaskPromptView, .body, .promptFont

### Community 174 - "Change Password Sheet"
Cohesion: 0.22
Nodes (7): ChangePasswordSheet, .body, .done, Field, current, new, .form

### Community 175 - "Placement Test Store"
Cohesion: 0.20
Nodes (9): Stage, answering, finished, idle, loadFailed, loading, noContent, submitFailed (+1 more)

### Community 176 - "Placement Test View"
Cohesion: 0.22
Nodes (6): PlacementQuestionScreen, .answers, PlacementResultScreen, .body, PlacementTestView, .body

### Community 177 - "Practice Result (2)"
Cohesion: 0.20
Nodes (10): Caption, noNewWords, noReviews, noSkillMeasured, noWeakWordsLeft, pickedUp, practiceClean, remembered (+2 more)

### Community 178 - "app redesign v1 (5)"
Cohesion: 0.42
Nodes (9): Bottom feedback panel with Syllie (answer/ok/wrong/reveal/exhausted), Task templates, T2 Cloze (fill the blank), T5 Match pairs, T7 Read aloud (recording), T7b Scored read-aloud (scoring, result, error), T4 Reorder letters, T6 Spelling surgery (+1 more)

### Community 180 - "Primary Button"
Cohesion: 0.22
Nodes (9): Kind, app, danger, outline, outline3D, plain, practice, retry (+1 more)

### Community 181 - "Word Tile (2)"
Cohesion: 0.22
Nodes (8): WordTileVisualState, correct, disabled, dragging, idle, incorrect, pressed, selected

### Community 184 - "Session Reducer"
Cohesion: 0.22
Nodes (9): SessionEvent, advanced, answerRevealed, correct, finished, hintOpened, incorrect, restarted (+1 more)

### Community 186 - "03 BACKEND (2)"
Cohesion: 0.25
Nodes (7): On-device feedback, hints and retries, Skill status labels (Not verified … Needs practice again), Memory signals (unaided/assisted/failed recall, recognition), Practice evaluator (event replay grading), scopeEvents (completedTopicIds, scopeExhausted, collectionCompleted), Session commit (all-or-nothing, idempotent), Skill verification (not_verified → demonstrated → verified, issues)

### Community 189 - "Practice Task (4)"
Cohesion: 0.29
Nodes (6): CodingKeys, result, CodingKeys, collectionId, customOnly, topicIds

### Community 190 - "Controls"
Cohesion: 0.29
Nodes (7): Tone, accent, error, neutral, onAccent, reward, success

### Community 191 - "Controls (2)"
Cohesion: 0.29
Nodes (7): Tone, accent, accentSolid, error, neutral, reward, success

### Community 192 - "Attempt"
Cohesion: 0.33
Nodes (4): Attempt, AttemptStage, build, recall

### Community 193 - "Task Attempt (2)"
Cohesion: 0.29
Nodes (7): Status, answering, exhausted, recorded, revealed, solved, wrong

### Community 194 - "Practice Session Store (2)"
Cohesion: 0.29
Nodes (7): RecordingStage, assessed, blocked, idle, recording, uploadFailed, uploading

### Community 195 - "Practice Result (3)"
Cohesion: 0.29
Nodes (6): Kind, checkpoint, daily, randomPractice, speakingPractice, weakPractice

### Community 196 - "Syllie Preview View"
Cohesion: 0.29
Nodes (6): CelebrationRun, Mode, celebrate, loading, moods, results

### Community 197 - "color palette v2 (2)"
Cohesion: 0.33
Nodes (3): Ink Ramp (50-950, #131217), 60 · 30 · 10 color ratio and five color ramps, Role color tokens (Colors.swift)

### Community 198 - "README"
Cohesion: 0.40
Nodes (5): Syll docs index (README), Backend Spec v0.4 (Engineering Review Draft), vocab-backend/docs/DECISIONS.md, vocab-backend/docs/FRONTEND_FLOW.md (API contract), Syll (VocabFlow) app

### Community 199 - "Progress Track"
Cohesion: 0.33
Nodes (4): .continuousBar, ProgressTrack, .body, .unlockCondition

### Community 202 - "Practice Task (5)"
Cohesion: 0.33
Nodes (6): CodingKeys, card, id, phase, task, type

### Community 203 - "Result Summary Models (6)"
Cohesion: 0.33
Nodes (6): CodingKeys, becameFluent, groups, passed, slipped, total

### Community 204 - "Practice Result (4)"
Cohesion: 0.33
Nodes (6): Kind, newWords, practice, review, speaking, weakRemaining

### Community 205 - "CLAUDE"
Cohesion: 0.40
Nodes (3): Backend session flow (plan -> steps -> commit), Challenge (Match Madness), "I know this" known_check flow

### Community 206 - "app redesign v1 (6)"
Cohesion: 0.60
Nodes (5): CelebrateV2 Rive artboard (syllie.riv), Celebration variants V1–V5 (puff, fireworks, flip, loop, bounce), Syllie celebration variants, Perfect beat (V+): Ink crown, 1.12 Session celebration

### Community 207 - "app redesign v1 (7)"
Cohesion: 0.70
Nodes (5): Flow 0 · Sign in & sign up, 0.4 Check email screen, 0.1 Login screen, 0.5–0.6 Password reset (email, then code), 0.3 Sign up screen

### Community 208 - "color palette v2 (3)"
Cohesion: 0.40
Nodes (3): Measured Home Colour Allocation, Landing Colour Tokens (legacy #4775F5 / #171717 palette), Tactile Stepped-Depth Buttons And Tiles

### Community 209 - "04 CHALLENGE IOS NOTES"
Cohesion: 0.50
Nodes (3): Match Madness run flow, Fixed-slot board display (ChallengeBoardSlots.reconcile), ChallengeBoardSlots

### Community 210 - "Practice Task (6)"
Cohesion: 0.40
Nodes (5): CodingKeys, mode, newWords, reviewWords, sessionID

### Community 211 - "Practice Task (7)"
Cohesion: 0.40
Nodes (5): CodingKeys, audio, highlight, text, type

### Community 212 - "Result Sheet Model (3)"
Cohesion: 0.40
Nodes (5): Title, answers, newWords, review, speaking

### Community 214 - "Custom Word (5)"
Cohesion: 0.50
Nodes (4): Status, available, translationDraft, unavailable

### Community 215 - "Journey (2)"
Cohesion: 0.50
Nodes (4): Status, active, completed, preview

### Community 217 - "Match Madness Engine (2)"
Cohesion: 0.67
Nodes (3): Phase, goalReached, playing

### Community 218 - "Word Meaning Views"
Cohesion: 0.67
Nodes (3): Style, divided, quiet

## Ambiguous Edges - Review These
- `FlowHeader` → `Borders and depth edges (no shadows on cards)`  [AMBIGUOUS]
  docs/DESIGN_SYSTEM.md · relation: references
- `Ink Ramp (50-950, #131217)` → `Meet Syllie (mascot section)`  [AMBIGUOUS]
  landing/index.html · relation: conceptually_related_to
- `LaunchSyllieV2@3x.png (launch-screen Syllie, transparent background)` → `Naming question: 'V2' asset shows black Syllie, not the Periwinkle V2 artboards`  [AMBIGUOUS]
  VocabFlow/Resources/Assets.xcassets/LaunchSyllieV2.imageset/LaunchSyllieV2@3x.png · relation: rationale_for

## Knowledge Gaps
- **1124 isolated node(s):** `.isLaunchLoading`, `.canLoadLearner`, `.route`, `.appRoute`, `splash` (+1119 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1533 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **30 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `API Wire Helpers & Fixtures` to `Learner Store & API Surface`, `Ranking & Leaderboard Models`, `Controls & Profile UI`, `Practice Session Store (Daily Flow)`, `Live Vocab API Client`, `Plan Decoding & Lab Templates`, `Local Learning Progress`, `Auth & Social Sign-In`, `Primary Button Styles`, `Custom Word Store`, `Localization & Languages`, `Add Word Screen`, `Selection Controls`, `Match Madness Engine`, `Learning Plan Preferences`, `Task Attempt Rules`, `Typography & Syllie Reactions`, `Word Meaning & Learn Card`, `Custom Word Model`, `Demo Session Views (Learn/Build)`, `Challenge Run Wire Models`, `Result Summary Models`, `Challenge Map View`, `Speech Synthesis & Wave Icon`, `Intro Motion Presentation`, `Sheets & App Settings`, `Ranking View & Public Profile`, `Result Detail Sheet`, `Onboarding Flow`, `Challenge Map Models & iOS Notes`, `Review Load Choice`, `Practice Session Store Tests`, `Plan Controls UI`, `Motion Tokens`, `Challenge Run Store`, `Demo Session Reducer`, `Surgery Task View`, `Answer Evaluation (Demo)`, `App Root & Routing`, `Audio Playback & Scoring`, `Random Practice View`, `Cloze Task View`, `Task Event`, `My Words View`, `Placement Test Store Tests`, `Home View`, `Main Shell View`, `Practice Audio`, `Challenge Run Models`, `Onboarding Store`, `Practice Session Store Tests (2)`, `Challenge Map Store`, `Syllie View`, `Session Reducer Tests`, `Session Result`, `Challenge Run Store Tests`, `APIClient`, `Match Madness Game View`, `Topic Catalog`, `Content Validator`, `Journey Snake Layout`, `Result Summary Models (2)`, `Pronunciation Score`, `Recall View`, `Onboarding Store Tests`, `Session Celebration View`, `Word Intro Content`, `Word Stack Board`, `Journey View`, `Plan Decoding Tests`, `Token Store`, `Password Policy`, `Journey`, `Scope Review Load Tests`, `Task Attempt Tests`, `Challenge Results View`, `Practice Session View`, `Result Tile View`, `Pronunciation Result Views`, `Task Scaffold`, `Home Syllie View`, `Custom Word`, `Task Attempt`, `APIError`, `App Settings Store`, `Pronunciation Score (2)`, `Auth View`, `Challenge Run Store (2)`, `Challenge Map Models`, `Practice Task`, `Result Summary Models (3)`, `Result Summary Models (4)`, `Custom Words View`, `Practice Session View (2)`, `Session Celebration View (2)`, `Challenge Components`, `Build Interaction State`, `Custom Word Edit View`, `Journey Node View`, `Highlighted Sentence`, `Syllie Artboard View`, `Form Fields`, `Practice Task (2)`, `Task Event (2)`, `Sign Up View`, `Practice Fixtures`, `Custom Word (2)`, `Challenge Run Store (3)`, `Choice Task View`, `Recording Task View (2)`, `Word Tile`, `Feedback Banner`, `Challenge Board Ordering`, `Result Summary Models (5)`, `Auth Components`, `Vocab API`, `Word Intro Content (2)`, `Vocabulary Item`, `Transcript Matcher Tests`, `Template Parts`, `Result Sheet Model (2)`, `Lab Library Tests`, `Custom Word (3)`, `Highlighted Sentence Tests`, `Practice Task (3)`, `Challenge Components (2)`, `App Language Tests`, `Confirm Sheet`, `Demo Content Repository`, `Learning Preferences`, `Task Scaffold (2)`, `Placement Test Store`, `Placement Test View`, `APIClient Tests (2)`, `Challenge Board Slots Tests`, `Custom Word (4)`, `Practice Task (4)`, `Attempt`, `Practice Session Store (2)`, `Practice Result (3)`, `Hint Control`, `Recall Input`, `Practice Task (5)`, `Result Summary Models (6)`, `Practice Task (6)`, `Practice Task (7)`, `Drop Slot`, `Custom Word (5)`, `Journey (2)`, `Choice Task View (2)`?**
  _High betweenness centrality (0.532) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `PracticeSessionStore` (e.g. with `.tap()` and `.stepView()`) actually correct?**
  _`PracticeSessionStore` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isLaunchLoading`, `.canLoadLearner`, `.route` to the rest of the system?**
  _1124 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Learner Store & API Surface` be split into smaller, more focused modules?**
  _Cohesion score 0.041932841932841934 - nodes in this community are weakly interconnected._
- **Why does `PracticeSessionStore` connect `Practice Session Store (Daily Flow)` to `Learner Store & API Surface`, `API Wire Helpers & Fixtures`, `Ranking & Leaderboard Models`, `Plan Decoding & Lab Templates`, `Task Attempt Rules`, `Word Meaning & Learn Card`, `Challenge Run Wire Models`, `Result Summary Models`, `Audio Recording & Session`, `Practice Session Store`, `Reorder Task View`, `Practice Session Store Tests`, `02 FRONTEND (2)`, `Surgery Task View`, `App Root & Routing`, `Audio Playback & Scoring`, `Task Scaffold (2)`, `Practice Audio`, `Session Store`, `Practice Session Store Tests (2)`, `Practice Session Store (2)`, `02 FRONTEND`, `CLAUDE`, `Journey View`, `Scope Review Load Tests`, `Practice Session View`, `Practice Task`, `Feedback Haptics`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `FlowHeader` and `Borders and depth edges (no shadows on cards)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Ink Ramp (50-950, #131217)` and `Meet Syllie (mascot section)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._