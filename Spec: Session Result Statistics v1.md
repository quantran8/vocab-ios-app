Spec: Session Result Statistics v1

Trạng thái: Draft, chờ review. Phạm vi: màn kết quả của session daily (gồm reviewOnly). Không đụng Tổng ôn, Random, Weak, Challenge.
Tham chiếu: 03_BACKEND.md §6.4, §7; 02_FRONTEND.md §5.2, §5.8; FRONTEND_FLOW.md (cập nhật contract sau khi duyệt).

1. Mục tiêu

Màn kết quả trả lời hai câu hỏi thay vì đếm input:

Ôn tập: các từ đã học, hôm nay tôi nhớ hay cần học lại?
Từ mới: tôi tiếp thu mượt đến đâu? (cố ý không gọi là “đã nhớ”: bằng chứng trong phase học mới luôn primed và không tính vào skill)

Nguyên tắc:

Nhóm hiển thị suy ra từ quyết định của scheduler/evaluator, không tính lại trên client. UI và SRS không bao giờ mâu thuẫn.
Một số, một chữ, một thanh màu mỗi tile. Chi tiết nằm trong sheet.
Wording không trừng phạt: “Học lại”, không “Quên”. Không phần trăm ngoài phân số tổng.
Không thêm query theo số Meaning. Mọi dữ liệu lấy từ những gì commit đã có trong tay.
2. Nhóm
2.1. Ôn tập (review)
Key	Nhãn UI	Điều kiện (theo kết quả SRS của Meaning trong commit này)
solid	Nhớ chắc	Unaided recall: interval giãn ra, streak +1
shaky	Chưa chắc	Assisted recall (interval giảm nửa, next ≤ 24 h), hoặc chỉ có recognition success khi đến hạn (lùi 24 h)
relearn	Học lại	Failed recall / failed recognition: interval 12 h, lapse +1

Meaning due chỉ có task không tạo tín hiệu nhớ (không xảy ra trong daily hiện tại, nhưng phải phòng): bỏ khỏi review và không đếm vào total.

2.2. Từ mới (newWords)

Xét toàn bộ task của Meaning trong phase học mới (trừ task known_check và task trong skippableTaskIds đã bị bỏ). Lấy nhóm thấp nhất mà Meaning rơi vào:

Key	Nhãn UI	Điều kiện
known	Đã biết	Qua known check (đúng lần đầu, không hint). Không đi qua learn, nên không xét task khác
smooth	Nắm ngay	Mọi task correct, không có event hint
retried	Cần thử lại	Có corrected_after_retry hoặc có hint; không có revealed/incorrect
revealed	Xem đáp án	Có ít nhất một revealed hoặc incorrect
Recording có event unavailable → task đó bỏ qua, không kéo Meaning xuống nhóm thấp hơn.
Known check sai → task known check bỏ qua, Meaning phân nhóm theo các task còn lại như bình thường (đúng tinh thần §5.4: lần sai không bị tính).
struggledAt: với retried/revealed, lấy skillOf của task tệ nhất (ưu tiên revealed/incorrect > retried > hinted; hòa thì lấy task có seq sớm hơn). Giá trị: reading | writing | listening | speaking. Reuse enum skill sẵn có, không thêm enum mới.

Mẫu số của tile = smooth + retried + revealed. known hiện riêng, không nằm trong mẫu số.

3. Backend
3.1. Response

summary của POST /sessions/{id}/commit (và commit-status) cho mode = daily:

json
{
  "summary": {
    "review": {
      "total": 9,
      "groups": {
        "solid":   [ { "meaningId": "…", "wordId": "…", "lemma": "prevalence", "gloss": "tỷ lệ phổ biến", "nextReviewAt": "2026-11-25T13:00:00Z", "learnedAt": "2026-11-09T12:10:00Z" } ],
        "shaky":   [ … ],
        "relearn": [ … ]
      }
    },
    "newWords": {
      "total": 4,
      "groups": {
        "smooth":   [ { "meaningId": "…", "wordId": "…", "lemma": "symptom", "gloss": "triệu chứng", "nextReviewAt": "2026-11-15T13:00:00Z" } ],
        "retried":  [ { "…": "…", "struggledAt": "speaking" } ],
        "revealed": [ … ],
        "known":    [ … ]
      }
    },
    "newWordGoalSlots": 4,
    "knownMeanings": 1,
    "reviewedMeanings": 9,
    "practiceTasks": 31
  },
  "scopeEvents": { … }
}
Item: meaningId, wordId, lemma, gloss (theo explanationLocale của user lúc commit), nextReviewAt; learnedAt chỉ ở review; struggledAt chỉ ở newWords.retried / revealed.
Mảng trong groups luôn có mặt, rỗng khi không có. Thứ tự item trong mảng = thứ tự xuất hiện trong plan.
review.total = solid + shaky + relearn; newWords.total = smooth + retried + revealed (không gồm known).
Bốn field cũ (newWordGoalSlots, knownMeanings, reviewedMeanings, practiceTasks) giữ lại một release rồi gỡ; client mới không đọc.
Mode khác daily: review và newWords là null. checkpoint giữ nguyên.
3.2. Tính ở đâu
Trong session-commit, cùng transaction, sau khi reducer SRS đã tính progress mới và trước khi ghi commit_response. Phân nhóm review so sánh row progress trước/sau của từng Meaning đã có trong bộ nhớ; không đọc lại DB.
Phân nhóm newWords từ kết quả evaluator + raw_events đã có.
lemma/gloss: planner đã có cả hai khi dựng learn card và reviewWords; lưu vào plan lúc issue (plan bất biến, đọc ở commit) để commit không cần query. Nếu plan cũ (issue trước deploy) thiếu, fallback một query inArray trên meaning_localizations cho mọi Meaning của session.
Lưu nguyên summary vào commit_response → commit lặp và commit-status trả y nguyên (idempotent như hiện tại).
Ghi thêm vào learning_sessions.result: review.total, review.solid, newWords.total, newWords.smooth (bốn số nguyên). Mục đích: so sánh chuỗi buổi sau này không cần raw_events (bị xóa sau 30 ngày). Chưa có API đọc.
3.3. Ràng buộc
Không tăng số query theo số Meaning (test/api.test.ts so 1 vs 20 Meaning phải pass).
Mọi key nhóm là hằng ở src/common/constants/ theo quy ước hiện có.
Cập nhật FRONTEND_FLOW.md (contract) và DECISIONS.md (lý do shaky gộp assisted với recognition-only; lý do known ngoài mẫu số).
4. Client (iOS)
4.1. Decode
SessionCommitResponse.summary thêm review: ReviewSummary? và newWords: NewWordSummary?. Mọi field mới optional; struggledAt dùng LenientEnum → .unknown thì không hiện dòng phụ.
Nhóm lạ trong groups bỏ qua, không làm hỏng decode.
4.2. Ghép hai commit

Daily có thể gồm hai session liên tiếp (commit phần ôn → plan tiếp → commit từ mới). PracticeSessionStore:

Sau commit đầu, giữ summary.review trong một pendingReviewSummary.
Khi commit cuối trả về, ResultSummary = merge(pendingReviewSummary ?? last.review, last.newWords).
Hủy giữa chừng chain → không có màn kết quả, như hiện tại. Session mới (sessionToken mới) → xóa pendingReviewSummary.
4.3. Màn kết quả (PracticeResultsView)

Ba tile ngang, cao bằng nhau, không đổi số tile giữa các buổi:

Tile	Số	Caption	Thanh	Dòng phụ
LP	+N LP			(xem §6)
Ôn tập	solid/total	“nhớ chắc”	3 đoạn: solid / shaky / relearn	relearn > 0 → “N học lại”; else shaky > 0 → “N chưa chắc”; else trống
Từ mới	smooth/total	“nắm ngay”	3 đoạn: smooth / retried / revealed	nhóm vấp (retried+revealed) đông nhất theo struggledAt: “N vấp ở phát âm”; known > 0 → thêm “+N đã biết”
Thanh: 3 đoạn tỷ lệ theo số lượng, phân biệt bằng màu và pattern (đậm / nhạt / có vân), không chỉ màu. Token mới trong DesignSystem/Tokens/Colors cho ba mức, không dùng màu đúng/sai của vùng bài học.
Trạng thái rỗng: tile mờ, số “—”, caption “không có từ ôn” / “không có từ mới”, không thanh, không dòng phụ.
Chạm tile Ôn tập / Từ mới → mở sheet (§4.4), cuộn tới khối tương ứng. Tile LP không chạm.
Scope event card, Syllie Celebrate, confetti: giữ nguyên, nằm dưới ba tile.
Animation số và thanh đi qua MotionCoordinator; Reduce Motion thì hiện tĩnh.
4.4. Sheet chi tiết (SessionResultDetailSheet)

Hai khối, mỗi khối là các nhóm theo thứ tự cần chú ý trước:

Ôn tập: relearn → shaky → solid. Mỗi nhóm có header “Nhớ chắc (7)” và dòng lịch “gặp lại …” tính từ nextReviewAt của item đầu (các item cùng nhóm có lịch gần nhau; hiển thị relative: “tối nay”, “ngày mai”, “sau 12 ngày”, “Chủ Nhật”). Item: lemma, gloss; nếu learnedAt trong 7 ngày gần nhất thì nhãn “học Thứ Hai”.
Từ mới: revealed → retried → smooth → known. Item có struggledAt thì nhãn “vấp ở …”.
Nhóm solid và smooth mặc định thu gọn khi khối có nhóm khác khác rỗng; các nhóm còn lại mặc định mở.
Chạm item → WordDetailSheet(wordId) (đã có, gọi GET /words/{wordId}).
Formatter ngày dùng AppLanguage.active.locale và timeZone của user settings.
4.5. Localization

Key mới (kèm bản vi, state translated, specifier có vị trí):

text
results.review.title            Review / Ôn tập
results.review.caption          remembered / nhớ chắc
results.review.group.solid      Remembered (%lld) / Nhớ chắc (%lld)
results.review.group.shaky      Not solid yet (%lld) / Chưa chắc (%lld)
results.review.group.relearn    Relearn (%lld) / Học lại (%lld)
results.review.empty            no reviews today / không có từ ôn
results.new.title               New words / Từ mới
results.new.caption             picked up / nắm ngay
results.new.group.smooth        Picked up right away (%lld) / Nắm ngay (%lld)
results.new.group.retried       Needed a retry (%lld) / Cần thử lại (%lld)
results.new.group.revealed      Saw the answer (%lld) / Xem đáp án (%lld)
results.new.group.known         Already knew (%lld) / Đã biết (%lld)
results.new.known.sub           +%lld already knew / +%lld đã biết
results.new.empty               no new words today / không có từ mới
results.struggledAt.reading|writing|listening|speaking
results.nextReview.tonight|tomorrow|inDays(%lld)|weekday(%@)
results.learnedOn               learned %@ / học %@

Accessibility label mỗi tile: “Ôn tập, 7 trên 9 nhớ chắc, 1 học lại”; thanh phân đoạn accessibilityHidden.

5. Test

Backend (vitest, thêm mã case nối tiếp C62):

Mỗi nhóm review ×1: unaided, assisted, recognition-only, failed. Known-check pass → known, fail → phân theo task còn lại.
newWords: smooth; hint không retry → retried; retry; reveal; incorrect hết lượt; recording unavailable không hạ nhóm; struggledAt chọn task tệ nhất.
Commit lặp cùng body → summary bằng nhau từng byte. commit-status sau commit → cùng summary.
reviewOnly → newWords.total = 0, mảng rỗng, không null.
Mode random_practice → review/newWords null.
Số query ở 1 vs 20 Meaning không đổi; plan cũ thiếu lemma/gloss → đúng một query fallback.
result có bốn số nguyên.

iOS (XCTest):

PlanDecodingTests: summary thiếu field, nhóm lạ, struggledAt lạ → decode được.
PracticeSessionStoreTests: chain hai commit ghép đúng; hủy giữa chain không giữ pendingReviewSummary sang session mới.
ResultTileTests (mới, logic thuần): chọn dòng phụ, mẫu số không gồm known, trạng thái rỗng.
Thêm fixture kết quả vào Practice Lab để xem tile/sheet không cần backend.
6. Ngoài phạm vi và quyết định mở
LP: backend chưa có (§16). Ship hai tile trước; tile LP thêm khi có số thật, không hiện “+0”. Trước đó phải chốt: reviewOnly, “Tôi biết từ này” và practice có tính LP không.
So sánh với các buổi trước: chưa làm; §3.2 chỉ ghi result để mở đường.
Hành động từ nhóm relearn: chưa có lối “luyện ngay N từ này” (Random Practice không lọc theo meaningId). Ghi nhận, để spec sau.
Áp dụng cho Tổng ôn / Random / Weak: để sau, khi có lối vào UI hoặc nhu cầu.
7. Thứ tự làm
Backend: hằng số nhóm → phân nhóm trong commit → lưu commit_response + result → test → FRONTEND_FLOW.md.
Lưu lemma/gloss vào plan lúc issue (deploy cùng hoặc trước bước 1; fallback query bảo vệ khoảng trống).
iOS: decode → merge chain → tile → sheet → strings vi → test → fixture Practice Lab.
Gỡ bốn field cũ ở release kế tiếp sau khi client đã lên.
Phạm vi thêm: random_practice, weak_words_practice. Daily giữ nguyên v1. Checkpoint chưa làm.

8. Mục tiêu

Màn kết quả của hai mode luyện tập vẫn có 3 tile: LP và hai tile thống kê. Tile 1 dùng chung cho cả hai mode, tile 2 khác theo mode:

Mode	Tile 1	Tile 2
Random	Lượt tự làm đúng	Kỹ năng lên mức
Weak	Lượt tự làm đúng	Từ còn cần luyện

Nguyên tắc từ v1 vẫn giữ: nhóm suy ra từ quyết định của skill-verification, client không tính lại, và số query không tăng theo số Meaning.

9. Phân loại lượt (dùng chung)

Đơn vị là task có skill evidence. Với Random có skills thì mỗi task tương ứng một từ. Với Weak thì mỗi task tương ứng một cặp (từ, kỹ năng).

Key	Nhãn UI	Điều kiện (theo dòng skill_evidence của task)
clean	Tự làm đúng	valid, reasons rỗng (một lần pass)
helped	Đúng nhờ trợ giúp	Đúng nhưng reasons có hinted, retried hoặc primed
missed	Chưa làm được	Sai hoặc revealed
(loại khỏi mẫu số)		Task không có evidence, hoặc reasons chỉ gồm lý do không do câu trả lời: weak_template (match, surgery), invalid_recording, recording unavailable, audio_not_played, quality_unqualified

Mẫu số của tile 1 là clean + helped + missed. Số task bị loại hiện trong sheet (“2 lượt không tính vào kỹ năng: nối cặp, không ghi âm được”) để người học không thắc mắc vì sao 10 câu mà mẫu số chỉ là 8.

10. Thay đổi kỹ năng

Với mỗi cặp (Meaning, skill) mà session chạm tới, so trạng thái trước và sau commit:

Key	Điều kiện
leveledUp	Trạng thái tăng hạng: not_verified → demonstrated, demonstrated → verified, hoặc nhảy từ not_verified lên verified
cleared	Issue tắt trong commit này
pendingConfirm	Có pass sạch trên kỹ năng đang có issue, nhưng chưa đủ 12 h kể từ issue, nên issue chưa tắt
regressed	Phát sinh issue failed mới (bao gồm cả trường hợp mất verified)

Một cặp có thể vừa leveledUp vừa cleared. pendingConfirm cần có tên riêng: người học làm Weak ngay sau một buổi daily sai sẽ làm đúng mà từ vẫn “cần luyện”, và nếu không giải thích thì trông như app bị lỗi.

11. Tile
11.1. Tile 1 (cả hai mode)
Số	Caption	Thanh	Dòng phụ
clean/total	“tự làm đúng”	3 đoạn: clean / helped / missed	missed > 0 → “N chưa làm được”; nếu không thì helped > 0 → “N cần trợ giúp”; nếu không thì để trống
11.2. Tile 2, Random: “Kỹ năng lên mức”
Số: +N, với N là số leveledUp. Caption: “kỹ năng lên mức”.
Dòng phụ: regressed > 0 → “N cần luyện lại”; nếu không thì số cặp vừa lên verified > 0 → “N mới Verified”.
Khi N = 0 và không có regressed: số “0”, dòng phụ “Verified cần đúng ở 2 buổi cách ≥ 24 h”. Đây là câu giải thích mà người học cần nhất khi luyện liên tục trong một ngày.
11.3. Tile 2, Weak: “Còn cần luyện”
Số: số từ còn needsPractice sau commit (cùng định nghĩa với needPracticeWords của GET /me/words/stats). Caption: “từ cần luyện”.
Dòng phụ: delta so với trước buổi (“−3 sau buổi này”). Nếu pendingConfirm > 0 thì thêm “N xác nhận sau 12 h”.
Số về 0 thì caption đổi thành “không còn từ yếu” và Syllie dùng mood proud.

Tile 2 của Weak hiển thị số còn lại, không phải số đã gỡ. Người học muốn biết danh sách từ yếu đang ngắn lại, và delta ở dòng phụ đã cho biết buổi này gỡ được bao nhiêu.

11.4. Trạng thái rỗng

Khi mọi task đều bị loại khỏi mẫu số (ví dụ Random không chọn kỹ năng mà toàn bài nối cặp), tile 1 hiện “—” với caption “buổi này không đo kỹ năng”. Hai tile vẫn giữ nguyên vị trí như v1.

12. Sheet chi tiết

Random:

Khối “Lượt làm”, thứ tự missed → helped → clean. Mỗi item ghi lemma, gloss và nhãn kỹ năng. Khi người học có chọn skills, các item được nhóm theo kỹ năng trước.
Khối “Kỹ năng thay đổi”: regressed → leveledUp. Item ghi chuyển trạng thái, ví dụ “Nghe: Demonstrated → Verified”.
Dòng cuối (nếu có): “N từ đến hạn được tính như ôn · gặp lại …”. Phần này lấy từ các Meaning đã đến hạn có unaided recall và được đẩy lịch theo §7.2. Nó trả lời một câu người học hay thắc mắc: luyện tập có tính là ôn không.

Weak:

Các nhóm theo cặp (từ, kỹ năng), thứ tự: “Vẫn cần luyện” (missed, helped) → “Chờ xác nhận” (pendingConfirm, ghi rõ giờ có thể xác nhận) → “Đã ổn” (cleared).
Từ thuộc nhóm “hay sai” (không có issue kỹ năng) chỉ xếp theo clean / helped / missed, gắn nhãn “hay sai gần đây”.

Chạm vào item ở cả hai mode đều mở WordDetailSheet(wordId). Nhóm “Đã ổn” và nhóm clean thu gọn mặc định khi có nhóm khác không rỗng.

13. Backend
13.1. Response

summary khi mode là random_practice hoặc weak_words_practice. Hai khối review và newWords của v1 là null ở các mode này.

json
{
  "summary": {
    "practice": {
      "total": 8,
      "excluded": { "count": 2, "reasons": ["weak_template", "invalid_recording"] },
      "groups": {
        "clean":  [ { "meaningId": "…", "wordId": "…", "lemma": "…", "gloss": "…", "skill": "listening" } ],
        "helped": [ … ],
        "missed": [ … ]
      }
    },
    "skillChanges": {
      "leveledUp":      [ { "meaningId": "…", "wordId": "…", "lemma": "…", "skill": "speaking", "from": "demonstrated", "to": "verified" } ],
      "cleared":        [ … ],
      "pendingConfirm": [ { "…": "…", "confirmableAt": "2026-11-14T03:00:00Z" } ],
      "regressed":      [ … ]
    },
    "needPractice": { "before": 11, "after": 8 },
    "countedAsReview": [ { "meaningId": "…", "wordId": "…", "lemma": "…", "nextReviewAt": "…" } ]
  }
}
Mọi mảng luôn có mặt, kể cả khi rỗng.
needPractice có ở cả hai mode. Client chỉ hiển thị nó ở Weak, nhưng giữ nó ở Random để sau này dùng không phải đổi contract.
skill và from/to dùng lại enum skill và skill status đã có.
13.2. Tính ở đâu
Vẫn trong transaction commit, sau khi chấm lại và suy ra evidence, trước khi ghi commit_response.
Trạng thái trước: chạy hàm thuần của skill-verification trên evidence cũ của các Meaning bị chạm. Nếu commit chưa đọc sẵn dữ liệu này thì đọc thêm một query inArray. Trạng thái sau: chạy cùng hàm trên evidence cũ cộng evidence mới, tính trong bộ nhớ.
needPractice.before lấy từ snapshot trước khi ghi (cùng cơ chế với scopeEvents), after là một câu aggregate sau khi ghi. Tổng cộng thêm tối đa hai query, không phụ thuộc số Meaning.
pendingConfirm.confirmableAt = thời điểm issue + 12 h.
countedAsReview lấy từ reducer SRS, gồm các Meaning đến hạn có unaided recall không bị primed.
lemma/gloss lấy từ plan như v1 §3.2 (planner của Random và Weak cũng phải lưu hai trường này lúc issue).
Ghi vào result các số: practice.total, practice.clean, skillChanges.leveledUp, needPractice.after.
14. Client
SessionCommitResponse.summary thêm practice, skillChanges, needPractice, countedAsReview. Tất cả optional, enum dùng LenientEnum.
PracticeResultsView chọn bộ tile theo mode: daily dùng v1, Random dùng 11.1 + 11.2, Weak dùng 11.1 + 11.3. Hai mode này không có chain commit nên không cần merge.
Tiêu đề màn kết quả: “Practice complete” / “Luyện tập xong” cho cả hai mode (hiện đang dùng chung “Flow complete”).
Màn kết quả có nút “Luyện tiếp” mở lại Random / Weak với cùng tham số. Đây vẫn là thao tác plan một session mới như hiện tại, không thêm API.

Key localization mới (kèm bản vi):

text
results.practice.title / caption            Practice / tự làm đúng
results.practice.group.clean|helped|missed  Tự làm đúng (%lld) / Đúng nhờ trợ giúp (%lld) / Chưa làm được (%lld)
results.practice.excluded                   %lld lượt không tính vào kỹ năng: %@
results.practice.empty                      buổi này không đo kỹ năng
results.skills.leveledUp.caption            kỹ năng lên mức
results.skills.newlyVerified                %lld mới Verified
results.skills.regressed                    %lld cần luyện lại
results.skills.verifiedHint                 Verified cần đúng ở 2 buổi cách ≥ 24 h
results.skills.transition                   %1$@: %2$@ → %3$@
results.weak.remaining.caption              từ cần luyện
results.weak.delta                          %lld sau buổi này
results.weak.pending                        %lld xác nhận sau 12 h
results.weak.pending.at                     xác nhận được lúc %@
results.weak.none                           không còn từ yếu
results.weak.frequentMistake                hay sai gần đây
results.countedAsReview                     %lld từ đến hạn được tính như ôn
15. Test

Backend:

Mỗi nhóm clean / helped / missed có một case, và mỗi lý do bị loại có một case. Riêng primed đúng phải vào helped, không bị loại.
leveledUp cho từng bước chuyển. Pass lần hai cách 24 h ở session khác → verified. Pass hai lần cùng ngày → chỉ demonstrated.
Weak: pass trước 12 h → pendingConfirm có confirmableAt đúng, needPractice.after không giảm. Pass sau 12 h → cleared, after giảm.
Failed trên kỹ năng đang verified → regressed.
Từ đến hạn có unaided recall trong Random → nằm trong countedAsReview. Từ chưa đến hạn → không nằm trong đó.
Commit lặp và commit-status trả summary giống nhau. Số query ở 1 và 20 Meaning bằng nhau.

iOS:

Chọn bộ tile theo mode. Dòng phụ của tile 2 Random khi N = 0. Delta của Weak.
Decode được với field thiếu, enum lạ.
Thêm fixture kết quả Random và Weak vào Practice Lab.
16. Quyết định mở (bổ sung)
Dùng chữ “Verified” trên UI. WordDetailSheet đang dùng nhãn tiếng Anh (Not verified / Demonstrated / Verified). Nếu bản vi dịch các nhãn này thì tile và sheet phải dùng cùng bản dịch. Cần chốt trước khi viết string.
LP cho Random/Weak: cùng câu hỏi mở với daily ở v1 §6, và ở hai mode này dễ farm hơn vì có thể luyện lại liên tục.
Checkpoint: chưa có lối vào UI. Khi bật lại thì có thể dùng tile 1 của v1.1, cộng unaidedRecalledCount sẵn có.