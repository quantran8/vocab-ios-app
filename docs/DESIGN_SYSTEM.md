# Syll Design System

Tài liệu thiết kế của Syll (repo VocabFlow), app iOS học từ vựng tiếng Anh cho người Việt.

Bản trực quan đi kèm:

- [color-palette-v2.html](color-palette-v2.html): các dải màu và quy tắc 60 · 30 · 10.
- [app-redesign-v1.html](app-redesign-v1.html): token, component và toàn bộ màn hình xếp theo luồng.

---

## 1. Định hướng

Syll là app cao cấp cho người học trưởng thành, nhưng vẫn có cảm giác chơi. Hai vùng của app lấy cảm hứng từ hai nguồn khác nhau:

| Vùng               | Phạm vi                         | Cảm hứng  | Cảm giác cần đạt                                |
| ------------------ | ------------------------------- | --------- | ----------------------------------------------- |
| **Vùng luyện tập** | Mọi màn hình trong một buổi học | Duolingo  | Đã tay: thẻ và nút có cạnh dày, phản hồi rõ màu |
| **Vùng sản phẩm**  | Mọi thứ ngoài buổi học          | Brilliant | Bình tĩnh, gọn, nhiều khoảng trống              |

**Lấy cảm hứng, không sao chép.** Mượn nguyên tắc tổ chức (dải màu nhiều bậc, ít màu lõi, cạnh dày, phản hồi rõ ràng), không mượn giao diện. Không dùng lại màu, logo, minh họa, âm thanh hay chi tiết đặc trưng của hai app này, ví dụ thanh tiến độ dày có vệt sáng hay nút loa vuông nổi khối.

**Bản sắc riêng của Syll:**

- **Syllie:** mascot dáng đám mây, màu đen. Là lớp cảm xúc của app, không bao giờ thay đổi kết quả học.
- **Ink:** màu chữ và màu nút chính.
- **Blue trầm:** màu nhấn duy nhất của thương hiệu.

---

## 2. Ranh giới hai vùng

Màn hình đang yêu cầu người học trả lời, hoặc đang mở đầu hay kết thúc phần trả lời đó, thuộc vùng luyện tập. Còn lại thuộc vùng sản phẩm.

| Vùng luyện tập                         | Vùng sản phẩm                    |
| -------------------------------------- | -------------------------------- |
| Ôn từ bạn đã học, Đã ôn xong           | Trang chủ                        |
| Giới thiệu từ mới                      | Từ của tôi, Chi tiết từ, Thêm từ |
| 7 dạng bài tập                         | Hồ sơ, Cài đặt, sửa kế hoạch học |
| Kết quả cuối buổi và Chi tiết buổi học | Xếp hạng                         |
| Bài tập trong Practice Lab             | Đăng nhập, onboarding            |

---

## 3. Nguyên tắc chung

1. **Thành phần hệ thống giữ bản iOS.** Không tự vẽ lại những thứ iOS đã có: tab bar, thanh điều hướng và nút quay lại, Toggle, segmented control, DatePicker, Stepper hệ thống, sheet, Menu, pull-to-refresh, bàn phím. Chỉ được đặt tint theo bộ màu. Lý do: giữ đúng cảm giác native và hành vi trợ năng của iOS.
2. **Không tự vẽ popup giữa màn hình.**
   - Xác nhận dùng ConfirmSheet: `.sheet` vừa chiều cao nội dung, thay `.alert`. Kiểu phá hủy có icon nền coral-50, nút viền "Hủy" và nút Coral cạnh nhau; kiểu rời buổi học có Syllie.
   - Không dùng swipe action hay context menu: thay bằng nút ⋯ (vùng chạm 44pt) mở sheet hành động.
   - Hộp xác nhận luôn có cả nút hủy và nút xác nhận.
3. **Chữ chỉ khi có nghĩa.**
   - Mỗi dòng chữ phải cho người học biết thêm điều gì đó.
   - Không có chữ trang trí, không lặp thông tin đã có trên màn hình (một con số không xuất hiện lại ở tiêu đề và trên nút).
4. **Khoảng thở.** Không nhồi nhiều card hay item vào một màn hình. Ít phần hơn, khoảng cách rộng hơn.
5. **Không có dấu "." màu xanh cuối tiêu đề hay sau wordmark.** Tiêu đề là chữ thường.
6. **Mỗi màu một nghĩa** (xem 4.1). Không truyền thông tin chỉ bằng màu: trạng thái luôn kèm icon, chữ hoặc viền.
7. **Vùng chạm tối thiểu 44pt.**
8. **Chịu được nội dung dài.**
   - Bố cục phải ổn với Dynamic Type lớn, nhãn tiếng Việt dài và dữ liệu dài như tên người dùng hay tên Collection.
   - Text dài một dòng thì tự thu nhỏ tới 80% rồi cắt "…" ở cuối, không được làm vỡ bố cục.
9. **Luôn có phương án giảm chuyển động** khi người dùng bật Reduce Motion.
10. **Chỉ có giao diện sáng.**

---

## 4. Nền tảng thị giác

### 4.1 Màu

**Tỷ lệ 60 · 30 · 10** trên mỗi màn hình:

| Tầng | Màu             | Dùng cho                                                                |
| ---- | --------------- | ----------------------------------------------------------------------- |
| 60%  | Trắng `#FFFFFF` | Nền màn hình và card                                                    |
| 30%  | Ink             | Chữ, Syllie, nút chính, icon, viền. **Không bao giờ làm nền card.**     |
| 10%  | Nhấn            | Blue là chính; Green, Coral, Sun chỉ khi có trạng thái hoặc phần thưởng |

Màu nhấn và màu trạng thái phải **tươi**, không làm trầm đi. Làm trầm khiến app tối lại.

**Dải màu.** Mỗi màu có 11 bậc, 50 → 950. Dùng tên dải và bậc (ví dụ `blue-500`), không dùng mã hex lẻ.

| Dải   | 50       | 100      | 200      | 300      | 400      | 500      | 600      | 700      | 800      | 900      | 950      |
| ----- | -------- | -------- | -------- | -------- | -------- | -------- | -------- | -------- | -------- | -------- | -------- |
| Ink   | `F7F7F9` | `EFEFF2` | `E2E2E7` | `C8C8D0` | `A3A3AE` | `80808C` | `62626D` | `4A4A54` | `34343C` | `222228` | `131217` |
| Blue  | `EEF3FD` | `DCE6FB` | `BACCF6` | `92AEEF` | `6A8DE6` | `3E68DB` | `3053C2` | `28449E` | `22387D` | `1A2A5B` | `0E1733` |
| Green | `EAFBF1` | `CFF5DE` | `A0EABE` | `6BDC9A` | `45D17E` | `2BC86A` | `1FA857` | `188646` | `12673A` | `0E4A2A` | `062615` |
| Coral | `FFF1EE` | `FFDFD8` | `FFBFB1` | `FF9883` | `FF7559` | `FF5A3C` | `E5432A` | `BA3421` | `8C2A1D` | `5E1E16` | `320E09` |
| Sun   | `FFFBEA` | `FFF4C5` | `FFE88A` | `FFD84A` | `FFC81F` | `FFB800` | `E09A00` | `B47800` | `875A06` | `5C3E08` | `301F03` |

**Nghĩa của từng dải**

| Dải   | Nghĩa                                                                                                               |
| ----- | ------------------------------------------------------------------------------------------------------------------- |
| Ink   | Chữ, icon, nút chính, viền và đường kẻ. Trung tính ngả tím rất nhẹ.                                                 |
| Blue  | Màu nhấn: tiến độ, đang chọn, focus, link, tint của hệ thống, nút mở đầu luyện tập. Trầm hơn `#4775F5` cũ một chút. |
| Green | Đúng, nhớ chắc, ôn tập. Giữ đúng hướng success cũ `#2BC86A`.                                                        |
| Coral | Sai, cần luyện, xóa.                                                                                                |
| Sun   | LP, sao, thành tựu, ăn mừng.                                                                                        |

**Quy ước bậc** (giống nhau cho mọi dải)

| Bậc | Dùng cho                                                  |
| --- | --------------------------------------------------------- |
| 50  | Nền tô nhẹ: panel phản hồi, thẻ đang chọn, nền icon       |
| 100 | Nền nhấn: pill, nhãn trạng thái                           |
| 200 | Viền card, cạnh dày của thẻ đang chọn, đúng hoặc sai      |
| 500 | Màu đại diện: viền trạng thái, thanh tiến độ, mặt nút màu |
| 700 | Cạnh dày của nút màu, chữ màu trên nền trắng              |
| 800 | Chữ trên nền tô nhẹ                                       |

**Token theo vai trò** (giữ tên trong `Colors.swift`, đổi giá trị)

| Token                                                                  | Giá trị                                      |
| ---------------------------------------------------------------------- | -------------------------------------------- |
| `canvas`, `surface`                                                    | `#FFFFFF`                                    |
| `ink` / `mutedInk`                                                     | ink-950 / ink-600                            |
| `stroke`, `track` / `neutralSurface` / `tileDepth`                     | ink-200 / ink-100 / ink-200                  |
| `primaryAction` / `primaryDepth`                                       | ink-800 / ink-950                            |
| `interactive`, `focusRing`                                             | blue-500                                     |
| `practiceAction` / `practiceDepth` (mới)                               | blue-500 / blue-700                          |
| `selectedSurface` / `selectedInk` / `selectedDepth`                    | blue-50 / blue-700 / blue-200                |
| `success` / `successSurface` / `successInk` / `successDepth`           | green-500 / green-50 / green-800 / green-200 |
| `error` / `errorSurface` / `errorInk` / `errorDepth`                   | coral-500 / coral-50 / coral-800 / coral-200 |
| `reward` / `rewardDepth`                                               | sun-500 / sun-700                            |
| `resultStrong` / `resultMid` / `resultWeakStripe`, `resultWeakSurface` | blue-600 / blue-300 / blue-300 trên blue-50  |

Asset `AccentColor` (tint của hệ thống) đổi sang blue-500.

**Dấu Collection.** Mỗi Collection có một màu tươi, chỉ dùng ở chấm cạnh tên, icon và thanh tiến độ của Collection đó. Không bao giờ làm nền card.

| Collection | Màu       |
| ---------- | --------- |
| Everyday   | `#2F9BF4` |
| Business   | `#14B8A6` |
| IELTS      | `#F0458A` |
| TOEIC      | `#FF8A1F` |
| Từ của tôi | `#FFB800` |

### 4.2 Chữ

Font San Francisco của hệ thống. Bản sắc đến từ độ đậm, không từ font riêng. Cỡ chữ theo text style của iOS; cột pt là cỡ mặc định.

| Vai trò      | Text style  | pt                  | Độ đậm  | Dùng cho                             |
| ------------ | ----------- | ------------------- | ------- | ------------------------------------ |
| Display      | Large Title | 34                  | Heavy   | Tiêu đề màn hình, kết quả            |
| Prompt       | Title 1     | 28–36               | Heavy   | Từ cần xử lý trong bài tập, căn giữa |
| Sheet Title  | Title 2     | 26                  | Heavy   | Tiêu đề sheet                        |
| Screen Title | Title 2     | 22                  | Bold    | Câu hỏi, tiêu đề section             |
| Choice       | Title 2     | 22 (thẻ nối cặp 19) | Regular | Đáp án; giữ Regular ở mọi trạng thái |
| Action       | Headline    | 16                  | Bold    | Nhãn nút                             |
| Body         | Body        | 17                  | Regular | Nội dung                             |
| Secondary    | Subheadline | 15                  | Regular | Chữ phụ                              |
| Eyebrow      | Caption     | 12                  | Bold    | Nhãn in hoa, giãn chữ 1.2            |
| Micro        | Caption     | 12–13               | Regular | Chú thích                            |

Tiêu đề dùng giãn chữ âm: khoảng -0.6 cho tiêu đề thường, -1.2 cho Display.

### 4.3 Khoảng cách

Thang: **4 · 8 · 12 · 16 · 24 · 32 · 40**.

| Thông số                | pt                    |
| ----------------------- | --------------------- |
| Lề ngang màn hình       | 20 (24 trong bài tập) |
| Khoảng giữa hai section | 32–40                 |
| Vùng chạm tối thiểu     | 44                    |
| Chiều cao nút           | 50                    |
| Chiều cao thẻ đáp án    | 60                    |
| Chiều cao thẻ nối cặp   | 84                    |

### 4.4 Bo góc

Dùng bo góc liên tục (continuous corner).

| Thành phần                               | pt                |
| ---------------------------------------- | ----------------- |
| Nút hành động, pill, chip, thanh tiến độ | Bo tròn hoàn toàn |
| Thẻ đáp án, ô nhập, thẻ chữ cái          | 14–16             |
| Card                                     | 20                |
| Sheet, panel phản hồi (hai góc trên)     | 24–28             |

### 4.5 Viền và độ sâu

**Viền:**

- Card và item có viền dùng **2pt**; khi cần nét nhẹ thì 1.5pt.
- Đường kẻ giữa các dòng trong card: 1.5pt ink-100.

**Không shadow, không cạnh dày cho card hay item.** Độ sâu chỉ dành cho những thứ bấm được hoặc cần nhấn mạnh:

| Bề mặt                                     | Cạnh dày                                                          |
| ------------------------------------------ | ----------------------------------------------------------------- |
| Nút Ink, Blue, Green, Coral                | 4pt, màu bậc 700 của dải (Ink dùng 950)                           |
| Nút viền trong luyện tập ("Đóng")          | 3pt ink-200 ("Tôi biết từ này" là nút viền phẳng, không cạnh dày) |
| Thẻ đáp án lúc bình thường                 | 3pt ink-200                                                       |
| Thẻ đáp án đang chọn / đúng / sai          | 3pt blue-200 / green-200 / coral-200                              |
| Card, dòng danh sách, ô thống kê, nền icon | Không có                                                          |

Khi nhấn, bề mặt lún xuống bằng đúng độ dày cạnh. Shadow mềm chỉ dùng cho vật đang được nhấc lên (thẻ đang kéo) và các control gốc của iOS.

### 4.6 Icon

SF Symbols, nét vừa. Luôn kèm nhãn hoặc mô tả cho VoiceOver. Icon trong card dùng ô vuông bo 12 với nền bậc 50 của màu mang nghĩa (Sun cho thử thách, Green cho ôn tập) hoặc ink-50.

---

## 5. Thành phần

### 5.1 Nút

Cao **50pt**, bo tròn hoàn toàn, chữ 16 bold, rộng hết chiều ngang.

| Loại            | Mặt / cạnh dày                       | Khi nào dùng                                                                                                                       |
| --------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Ink** (chính) | ink-700 / ink-950                    | Hầu hết hành động: Kiểm tra, Tiếp tục trong buổi học, Học từ mới, Xong, Lưu thay đổi, Bắt đầu, Tra từ, Thêm từ, Tiếp tục luyện tập |
| **Blue**        | blue-500 / blue-700                  | Chỉ nút mở vào luyện tập từ bên ngoài: "Tiếp tục" trên card Bài học hôm nay, "Luyện ngay" ở Từ của tôi                             |
| **Green**       | green-600 / green-800                | Chỉ "Tiếp tục" trong panel trả lời đúng                                                                                            |
| **Coral**       | coral-600 / coral-800                | Chỉ "Thử lại" trong panel trả lời sai                                                                                              |
| **Viền**        | Trắng, viền 2pt ink-200              | Hành động phụ: Hủy, Đăng xuất. Trong luyện tập có cạnh dày 3pt                                                                     |
| **Link chữ**    | blue-600, hoặc coral-700 khi phá hủy | Sửa, Xem chi tiết, Quản lý từ đã thêm, Xóa tài khoản                                                                               |
| **Vô hiệu**     | ink-100, chữ ink-400, không cạnh dày | Khi chưa đủ điều kiện, ví dụ "Kiểm tra bản sửa" chưa có chỗ sửa                                                                    |

Mặt nút Ink dùng ink-800 trên cạnh ink-950 (đổi từ ink-700 ngày 14/11/2026 theo yêu cầu).

### 5.2 Card và danh sách

- **Card:** nền trắng, viền 2pt ink-200, bo 20, không shadow.
- **Dòng:** nhãn bên trái, giá trị đậm bên phải. Không cần icon nếu nhãn đã rõ.
- **Số thống kê chỉ để xem** (ví dụ "248 Từ đã học"): đặt trong card để có điểm tựa, không có mũi tên.
- **Mũi tên ›** chỉ đặt ở những gì chạm được.

### 5.3 Header và điều hướng

- **Trang con (push):** thanh điều hướng của iOS chỉ có nút quay lại; iOS 26 vẽ nút này thành vòng tròn kính, dưới iOS 26 giữ mũi tên của hệ thống. Nút ✕ và nút quay lại tự vẽ (màn không có thanh điều hướng) thì dưới iOS 26 là vòng tròn ink-100 36pt. Không đặt tiêu đề trên thanh. Tiêu đề lớn nằm trong nội dung, mỗi màn một tiêu đề.
- **Sheet:** grabber của hệ thống, nút đóng ✕ ở góc phải (bước trong sheet có thêm ‹ ở góc trái), vẽ như nút trên thanh điều hướng: vòng tròn kính trên iOS 26, icon ink trơn trước đó (`SystemBarButtonLabel`, giống nút bánh răng ở Hồ sơ). Một luồng nhiều bước (ví dụ Thêm từ) nằm trong **một sheet**, chuyển bước bên trong sheet. Không chồng nhiều sheet lên nhau.
- **Tab bar:** tab bar của iOS, bốn mục Trang chủ, Từ của tôi, Xếp hạng, Hồ sơ. Tint blue-500.
- **Buổi học:** nút ✕ trơn (icon ink-400, không vòng tròn, vùng chạm 44pt; `FlowHeader`) và thanh tiến độ cao 10pt màu blue-500, không có vệt sáng. Ô ✕ rộng 24pt (vùng chạm 44pt tràn ra hai bên), bên phải thanh có một ô trống 24pt, nên thanh nằm giữa màn hình.

### 5.4 Điều khiển

| Thành phần                                            | Quy định                                                                        |
| ----------------------------------------------------- | ------------------------------------------------------------------------------- |
| Toggle                                                | Bản iOS, `.tint` blue-500 khi bật. Dòng toggle không có dòng phụ: lời giải thích nằm sau ⓘ cạnh nhãn (`InfoPopoverButton`, popover 280pt như ⓘ của Bài học hôm nay) |
| Segmented control, DatePicker, Stepper hệ thống, Menu | Bản iOS, chỉ đặt tint                                                           |
| Stepper số từ (− số +)                                | Thành phần riêng: card có hai nút tròn ink-100 và số lớn ở giữa                 |
| Chọn ngày học                                         | Thành phần riêng: ô bo 12, viền 2pt; đang chọn thì nền blue-50 và viền blue-500 |
| Chip Topic                                            | Viên thuốc có icon; đang chọn thì viền 2pt blue-500 và nền blue-50              |
| Ô nhập                                                | Viền 2pt ink-200, bo 16; khi focus thì viền blue-500 kèm vòng blue-100          |
| Pill trạng thái                                       | Cao 24, chữ 12 bold, nền bậc 50 hoặc 100, chữ bậc 700 hoặc 800                  |

### 5.5 Thẻ đáp án

Cao 60pt (thẻ nối cặp 84pt), viền 2pt, luôn có cạnh dày 3pt. Chữ căn giữa, 22pt (thẻ nối cặp 19pt), Regular ở mọi trạng thái: không in đậm khi chọn, vì chữ đậm hơn làm dòng chữ nhảy. Màu đổi ngay khi chạm. Đúng/sai chỉ thể hiện bằng màu thẻ, không có dấu ✓/✕.

| Trạng thái          | Giao diện                                                       |
| ------------------- | --------------------------------------------------------------- |
| Bình thường         | Nền trắng, viền ink-200, cạnh dày ink-200                       |
| Đang chọn           | Nền blue-50, chữ blue-700, viền blue-500, cạnh dày blue-200     |
| Đúng                | Nền green-50, chữ green-800, viền green-500, cạnh dày green-200 |
| Sai                 | Nền coral-50, chữ coral-800, viền coral-500, cạnh dày coral-200 |
| Không còn chọn được | Chữ ink-400                                                     |

### 5.6 Nút âm thanh (loa và micro)

Một họ nút, hai cấp. Cùng icon nét, cùng màu Blue, cùng cách báo trạng thái.

| Cấp              | Dùng ở                                                                               | Giao diện                                                                                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Cạnh IPA**     | Giới thiệu từ và dưới từ trong sheet (44, IPA 19pt), trong card nghĩa (36, IPA 17pt) | Tròn phẳng, nền blue-50, icon blue-600, không cạnh dày. Vùng chạm luôn 44pt                                                                                |
| **Giữa bài tập** | Loa của đề nghe, micro của Đọc to                                                    | Một kích thước chung: nút 128pt mặt blue-500, icon trắng, cạnh dày 5pt blue-700, đứng một mình, lúc nghỉ không có quầng hay đĩa nền. Nhấn lún như nút Blue |

| Trạng thái      | Cạnh IPA                                                                    | Giữa bài tập                                                                                                                                                                                  |
| --------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Đang phát       | Vạch sóng trên icon chạy 1 → 2 → 3, lặp lại (mỗi bước 280ms); nền không đổi | Như cột bên: vạch sóng chạy 1 → 2 → 3, mặt giữ blue-500                                                                                                                                       |
| Đang ghi        |                                                                             | Icon đổi thành ■ dừng (chạm là kết thúc lượt ghi); quầng tô màu (blue-100 trong, blue-50 ngoài) kèm gợn sóng, chỉ hiện khi nghe thấy giọng và lớn nhỏ theo độ lớn giọng, vạch mức âm dưới nút |
| Không dùng được | ink-100 / ink-400                                                           | Mặt ink-100, icon ink-400, không cạnh dày                                                                                                                                                     |

Icon loa có 3 vạch sóng. Gợn sóng quanh nút chỉ dành cho ghi âm, vì chỉ micro đo âm thanh thật; loa đang phát chỉ chạy vạch sóng trên icon. Reduce Motion: loa hiện đủ 3 vạch đứng yên; micro một vòng đứng yên, không gợn sóng. Âm thanh không tự phát.

---

## 6. Vùng luyện tập

### 6.1 Thứ tự một buổi học

1. Đang chuẩn bị (Syllie bay).
2. **Ôn từ bạn đã học:** thẻ từ kèm tên Topic, Syllie đứng giữa lời mở đầu và danh sách. Hai nút: Tiếp tục (Ink), Đóng (viền).
3. Các bài ôn.
4. **Đã ôn xong:** Syllie, dòng "Giờ đến từ mới của …" (chỉ khi Focus có 1–2 chủ đề; Focus dài hơn thì bỏ dòng, không bao giờ liệt kê cả danh sách), danh sách từ mới sắp học trong một card, nút "Học từ mới".
5. Giới thiệu từ mới và các bài tập.
6. Đang lưu tiến độ.
7. Kết quả.

### 6.2 Khung chung của mọi bài tập

| Từ trên xuống | Nội dung                                                                                                                                               |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Header        | ✕ và thanh tiến độ                                                                                                                                     |
| Câu hỏi       | Căn trái, Screen Title                                                                                                                                 |
| Đề            | **Hoặc** chữ căn giữa, **hoặc** một nút loa giữa bài tập (5.6), cùng nút với micro của Đọc to. Không có dạng vừa chữ vừa loa. Câu nghe không hiện chữ. |
| Nội dung      | Thẻ đáp án, câu có chỗ trống, chữ cái…                                                                                                                 |
| Panel đáy     | Syllie bên trái, hành động bên phải                                                                                                                    |

### 6.3 Panel đáy

| Trạng thái                | Panel                                             | Hành động                                                                                            |
| ------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Đang trả lời              | Nền trắng                                         | Link "Xem đáp án" phía trên, nút Ink "Kiểm tra"                                                      |
| Có gợi ý (Gõ từ, Xếp chữ) | Nền trắng                                         | Hàng "Hiện gợi ý 1/2" (blue-700) và "Xem đáp án"; gợi ý hiện thành chip "a \_ \_ \_"; nút "Kiểm tra" |
| Đúng                      | green-50, "Chính xác!" + đáp án                   | Nút Green "Tiếp tục"                                                                                 |
| Sai, còn lượt             | coral-50, "Chưa đúng / Thử lại, hoặc xem đáp án." | Link "Xem đáp án", nút Coral "Thử lại"                                                               |
| Đã xem đáp án             | blue-50, "Đáp án đây" + đáp án                    | Nút Ink "Tiếp tục"                                                                                   |
| Hết lượt                  | blue-50 (không đỏ), "Đáp án đúng" + đáp án        | Nút Ink "Tiếp tục"; thẻ sai vẫn giữ màu Coral                                                        |
| Nối cặp                   | Nền trắng                                         | Không có nút Kiểm tra; link "Xem đáp án" và dòng "Đã ghép N cặp"                                     |

Rời buổi học: nút ✕ mở sheet có Syllie, nút Ink "Tiếp tục luyện tập" và nút viền phẳng (không cạnh dày) chữ coral "Rời đi không lưu".

### 6.4 Giới thiệu từ

- Từ lớn ở giữa; ngay dưới là loại từ (chữ nghiêng 15, ink-500: loại từ thuộc về từ, không phải tiêu đề của nghĩa), rồi IPA kèm nút loa tròn blue-50.
- **Một card duy nhất, gọn, không eyebrow:** Nghĩa (thông tin chính, 26 Heavy), đường kẻ, câu ví dụ kèm bản dịch. Trong câu ví dụ, từ đang học được tô nền blue-100.
- Định nghĩa tiếng Anh ẩn sau hàng "Xem chi tiết ⌄" (ink-500) ở đáy card; chạm thì card mở rộng tại chỗ, hiện khối Định nghĩa (có eyebrow), hàng đổi thành "Thu gọn ⌃". Chỉ là trình bày, không đổi tiến độ buổi học.
- Link "Nghĩa khác (N)" nằm **ngoài** card, ngay dưới: card là nghĩa đang học, còn nghĩa khác chỉ để tham khảo, không thuộc bài học. Chỉ hiện khi từ có nghĩa khác.
- Hai nút: "Tiếp tục" (Ink) và "Tôi biết từ này" (nút chữ ink, không nền, không viền). Buổi học hằng ngày luôn có bước kiểm tra đã biết, nên đây là màn giới thiệu từ duy nhất.

### 6.5 Các dạng bài tập

| Dạng               | Điểm chính                                                                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Chọn đáp án        | 3–4 thẻ đáp án                                                                                                                                 |
| Điền vào chỗ trống | Từ được chọn bay vào ô trống; chỗ cũ trong ngân hàng từ để lại ô xám giữ chỗ                                                                   |
| Gõ từ              | Nhãn "Câu trả lời của bạn", ô nhập lớn, có gợi ý theo nấc                                                                                      |
| Xếp chữ            | Ô chữ 54×54; từ dài thì mọi ô thu hẹp đều để cả từ nằm trên một dòng. Vùng trả lời là dòng kẻ; chữ đã dùng để lại ô xám để hàng chữ không nhảy |
| Nối cặp            | Hai cột thẻ cao bằng nhau; cặp đúng khóa màu Green, đang chọn màu Blue                                                                         |
| Sửa lỗi chính tả   | Chạm một ô chữ để mở bàn phím "Thay bằng" trong card; phím cao 50pt, chữ 20pt, card đệm ngang 8pt để phím rộng nhất có thể                     |
| Đọc to             | IPA của bản ghi dưới từ (17pt Ink 500). Nút giữa bài tập (5.6) với icon micro; nút phụ "Không thể nói lúc này"                                  |

**Đọc to có chấm điểm (T7b).** Chỉ khi backend chấm điểm; bản ghi chấm trên máy (chỉ đúng/sai, không có điểm) giữ kết quả T7. Sau khi dừng ghi, app gọi API chấm điểm:

- **Đang chấm:** từ ở chỗ đề chuyển Ink 300, có một vệt sáng quét theo hướng đọc (Reduce Motion: đứng yên). Micro ở trạng thái off, dòng hướng dẫn thành "Đang chấm điểm…". Panel không có nút, Syllie lặp thinking. Lỗi hoặc quá thời gian dùng trạng thái "Không chấm được" có sẵn (Thử lại / Bỏ qua).
- **Tổng điểm là thông tin chính:** vòng 176pt (cùng khung với micro, nét 14pt, nền Ink 100) thay chỗ nút micro, số 56pt đếm lên. Dưới vòng, thay dòng hướng dẫn, là tiêu đề theo band của tổng điểm (server gửi, client không tự chia ngưỡng): Excellent! / Good job (Green 700), Almost there (Sun 700), Keep practicing (Coral 700). Vòng cùng màu với tiêu đề.
- **Từ giữ ở chỗ đề**, âm tiết tô màu chữ theo band từng âm (server gửi): good Green 700, poor Coral 600. Màu lan theo hướng đọc sau khi vòng đếm xong. Không ô, không điểm trên từ; IPA vẫn ở dưới từ như lúc ghi. VoiceOver đọc nhóm từng âm ("ci, chưa tốt").
- **Panel đáy chỉ có chi tiết:** một dòng gọn ("Các âm đều tốt" hoặc "Cần luyện: ci, ate") và "Chi tiết ⌄" bên phải, rồi Syllie và nút. Chạm "Chi tiết" mở rộng panel ngay tại chỗ (không mở sheet; panel cao lên như sheet iOS đổi detent: spring `panelExpand`, gần như không vượt quá, cùng một chuyển động khi mở và thu gọn; các dòng không tự trượt mà lộ ra theo mép panel): mỗi âm tiết một dòng 36pt gồm âm (tô màu), IPA, điểm; chạm lại để thu gọn. Nền panel Green 50 khi đạt ("Tiếp tục" Green), Coral 50 khi chưa đạt ("Thử lại" Coral + "Tiếp tục" phụ). Thử lại đưa micro về chỗ vòng điểm và từ về Ink.
- **Lỗi chấm điểm** (mạng, server lỗi, quá thời gian): từ về Ink, IPA giữ nguyên, micro off, dòng trạng thái "Chưa chấm được bản ghi." Panel info Blue 50: "Không kết nối được" + "Bản ghi của bạn vẫn còn. Thử gửi lại nhé.", Syllie idle. "Thử lại" (Ink) gửi lại đúng bản ghi cũ; "Bỏ qua" (phụ). Không có nút ghi lại.
- Backend không gửi điểm theo âm tiết: không tô màu, không có dòng chi tiết. Copy luôn giữ ý luyện nói không ảnh hưởng tiến độ.

### 6.6 Kết quả

- **Đầu màn:** Syllie, chip sun-100 "Hoàn thành buổi học", tiêu đề "Làm tốt lắm".
- **Tile cho từng phần có số liệu:** Ôn tập "7/9 · nhớ chắc", Từ mới "2/4 · nắm ngay". Tile trống thì ẩn. Có ghi âm được chấm thì thêm tile Nói "2/3 · nói đúng". Mỗi tile chỉ có số và chú thích, không có link riêng. Dưới hàng tile là **một** link "Xem chi tiết buổi học ›" (căn giữa) mở sheet; chạm tile cũng mở sheet đó, cuộn tới khối của tile. Các nhóm yếu hơn chỉ xuất hiện trong sheet chi tiết, không lặp lại trên tile.
- **Card LP:** "+45 LP", tổng LP, các chip chia theo nguồn.
- **Nút:** "Xong" (Ink); với Random hoặc Weak thêm "Luyện tiếp".
- **Buổi học dùng hết từ mới của Collection:** card hoàn thành dưới card LP (icon cúp sun-50, "Bạn đã học hết mọi từ trong …"). Nút của nó thay "Xong": "Chọn bộ từ khác" (Ink) và "Để sau" (viền).
- **Sheet Chi tiết buổi học:**
  - Mỗi khối có thanh tỷ lệ ba mức: blue-600 / blue-300 / sọc blue-300 trên blue-50.
  - Mỗi nhóm có ô màu tương ứng, dòng giải thích và lịch gặp lại.
  - Mỗi từ có nguyên nhân (blue-700) và chi tiết kỹ năng hoặc ngày học.
  - Nhóm mạnh thu gọn sẵn.
  - Khối Nói: thanh hai mức (nói đúng / chưa đạt), nhóm Chưa đạt và Nói đúng (đều mở sẵn); mỗi từ có "Điểm N" (blue-700) và tên band như màn chấm điểm. Backend cũ không gửi nhóm: thay bằng dòng "Nói đúng: 2/3 từ". Đã nói thành thạo / Cần luyện lại là nhóm không ô màu, thu gọn sẵn. Dòng cuối: "Phần nói không ảnh hưởng tiến độ học của từ."

### 6.7 Quy tắc nội dung trong bài học

- Không lộ đáp án trước khi bài tập kết thúc. Đáp án chỉ nằm trong panel đáy.
- Âm thanh không tự phát.
- Mỗi lúc chỉ có một hành động chính.
- Sai không bị phạt về cảm xúc: giọng trung tính, luôn có đường đi tiếp.

---

## 7. Vùng sản phẩm

- **Đăng nhập và đăng ký:**
  - Màn đăng nhập mở đầu bằng Syllie và chữ "Syll".
  - Ô nhập có nhãn phía trên, nút mắt cho mật khẩu, "Quên mật khẩu?" là link.
  - Nút "Đăng nhập" Ink, rồi "hoặc", rồi nút Sign in with Apple gốc (đen) và nút viền Google.
  - Link "Tạo tài khoản" ghim ở đáy màn hình.
  - Lỗi hiện ngay dưới ô nhập (viền Coral, chữ coral-700 kèm icon), không dùng alert.
  - Tạo tài khoản và đặt lại mật khẩu là trang con có nút quay lại của iOS. Quy tắc mật khẩu hiện trực tiếp (tick Green khi đạt). Ô mã dùng chữ số đơn cách và tự điền mã của iOS.
  - Màn "Kiểm tra email của bạn": Syllie kèm icon thư, email in đậm.
- **Onboarding** (sau lần đăng nhập đầu): Chào → Trình độ (có thể qua bài kiểm tra) → Bộ từ → Chủ đề → Lịch học → Sẵn sàng.
  - Mỗi màn một câu hỏi, một hành động chính; nút vô hiệu tới khi đã chọn.
  - Bốn bước giữa có header chung: nút quay lại tròn và thanh 4 đoạn blue-500, không có chữ "Bước n/4".
  - Lựa chọn một (ngôn ngữ, trình độ, bộ từ) là các dòng trong một card với dấu tick tròn; chủ đề là chip có icon.
  - Lịch học: dưới "Từ ôn / buổi" là card Toggle "Luyện nói" (mặc định tắt). ⓘ cạnh nhãn mở popover "Đọc to từ trong các bài học. Đúng hay sai đều không ảnh hưởng tiến độ học của bạn." Câu này luôn phải có: luyện nói chỉ để tập phát âm. Ở Hồ sơ, "Luyện nói" là dòng Toggle (cùng ⓘ) ngay trong card "Lịch học của bạn", trên "Tự cân bằng ôn và từ mới": bật/tắt là lưu ngay, không mở sheet Lịch học, và sheet không có mục này.
  - Trình độ: card "Chưa chắc? Làm bài kiểm tra" đứng đầu, rồi 6 trình độ, mỗi dòng có tên tiếng Việt và một ví dụ làm được gì. Bài kiểm tra là vùng luyện tập (thẻ đáp án có cạnh dày, "Bỏ qua" + "Tiếp").
  - Sẵn sàng: Syllie, tóm tắt là các dòng nhãn / giá trị trong một card, nút Blue "Học bài đầu tiên".
- **Trang chủ:**
  - Lời chào tách hai dòng: "Chào buổi sáng" (17pt Semibold, ink-500) và tên (26pt Heavy, ink-950) trên một dòng. Tên dài tự thu nhỏ tới 80% rồi cắt "…". Syllie rộng khoảng 88pt bên phải, không có bóng.
  - Card "Bài học hôm nay" chỉ nói buổi học kế tiếp có gì ("10 từ ôn · 8 từ mới") và nút Blue "Bắt đầu". Phần nào bằng 0 thì bỏ, không ghi "0 từ ôn": chỉ "8 từ mới" hoặc "10 từ ôn"; cả hai bằng 0 thì ẩn dòng. Không có thanh tiến độ hay ước lượng thời gian: không có dữ liệu đứng sau.
  - Thử thách tạm ẩn.
  - Khi số từ chờ ôn vượt ngưỡng, card Bài học hôm nay có thêm một dòng dưới đường kẻ: "Còn N từ khác chờ ôn" / "Ôn riêng 10 từ, không có từ mới" (N = số từ đến hạn trừ phần bài học đã lấy). Chạm để bắt đầu buổi chỉ ôn. Không đặt thành card riêng tên "Ôn thêm": tách khỏi bài học thì không đọc được mục đích.
  - **Đã học hết Collection:** card Bài học hôm nay nói thẳng trạng thái (icon cúp nền sun-50, "Bạn đã học hết …", một dòng hướng dẫn), nút Blue "Ôn N từ" (không có từ đến hạn thì "Luyện tập") và nút viền "Chọn bộ từ khác". Không hiện "Ôn thêm". Khối Đang học: dòng dưới thanh tiến độ đổi thành pill "Hoàn thành" kèm tổng số từ. Chỉ hết các Topic đang chọn thì nút viền là "Chọn thêm chủ đề".
  - Khối "Đang học": tiến độ Collection và các Topic; mọi thanh tiến độ dùng màu dấu của Collection. Dòng tên Collection chỉ có chấm màu và tên (tên dài thu nhỏ tới 80% rồi cắt "…"); số từ "128 / 600 từ" nằm dưới thanh.
- **Từ của tôi:**
  - Card thống kê có thứ bậc: "Từ đã học" là số chính (30pt) bên trái; "Cần luyện thêm" và "Nói thành thạo" là tập con của nó nên nhỏ hơn (19pt), xếp chồng bên phải, số thẳng cột. Cột trái chỉ rộng vừa nội dung, phần còn lại cho cột phải; nhãn dài thì xuống dòng, không cắt "…".
  - Khối Luyện tập: Từ còn yếu và Luyện nói bắt đầu ngay, nên là hai ô cạnh nhau cao bằng nhau, nút Blue sát đáy ô (giãn hết bề ngang ô) để hai nút luôn thẳng hàng. Nút Luyện nói có icon micro, chữ "Nói ngay"; nút Từ còn yếu là "Luyện ngay". Luyện tập ngẫu nhiên là một dòng có › bên dưới vì còn bước chọn nguồn từ. Không có từ yếu thì ô đó nói rõ ("Không có từ nào cần luyện") và không có nút.
  - Không đặt nút cạnh tiêu đề trong một dòng: tiêu đề bị ép xuống dòng ở ngôn ngữ dài và các dòng nhấp nhô.
  - Danh sách từ: từ đậm, IPA ở dòng dưới (chỉ khi mọi nghĩa của từ, kể cả nghĩa chưa học, đọc giống nhau), chấm xanh lá cho số nghĩa đã học.
  - **Từ bạn đã thêm** (sheet): mỗi từ một dòng, các nghĩa đã thêm nối bằng "; ". Chạm dòng mở Chi tiết từ; nút ⋯ với từ một nghĩa mở thẳng Menu gốc của iOS (Sửa, Khôi phục bản gốc, Xóa); với từ nhiều nghĩa mở sheet hành động: một card, mỗi nghĩa là một dòng (pill "Đã sửa" nếu đã sửa) với nút ⋯ là Menu đó. Xóa hỏi bằng ConfirmSheet: "Xóa nghĩa này?" khi từ còn nghĩa khác, "Xóa từ này?" khi là nghĩa cuối.
- **Chi tiết từ:** mỗi nghĩa là một card mở/đóng, mở được nhiều card cùng lúc (loa dưới từ theo card vừa mở gần nhất), có nhãn Định nghĩa, Ví dụ (kèm bản dịch), Kỹ năng (lưới 2×2 có màu trạng thái) và ngày học.
  - IPA và audio thuộc từng nghĩa. Mọi nghĩa đọc giống nhau thì IPA và loa nằm dưới từ, một lần.
  - Các nghĩa đọc khác nhau (lead /liːd/, /led/) thì dưới từ không có IPA hay loa. Mỗi card có IPA và loa tròn blue-50 ngay dưới nghĩa, hiện cả khi thu gọn. Loa là nút riêng, chạm vào không mở/đóng card.
- **Luyện tập ngẫu nhiên:** các nguồn từ nằm thẳng trên màn (không sheet), một card với dấu tick tròn, mặc định Tất cả từ đã học. Chọn một Collection thì Topic mở ra ngay dưới dòng đó, trong cùng card, kèm nhãn "Chủ đề · 2/6".
- **Hồ sơ:** Tier, LP và tiến độ lên Tier kế gộp trong một card dưới tên.
- **Cài đặt:** nhóm thành card; chỉ giữ dòng phụ có nghĩa; bỏ dòng không chọn được.
- **Xếp hạng:**
  - Segmented control của iOS.
  - Dòng của bạn nền blue-50 kèm pill "Bạn"; top 1 số hạng màu Sun.
  - Chưa có báo cáo người chơi: dòng không có nút ⋯.
- **Thêm từ:** một sheet, các bước Nhập → Đang tra → Kết quả → Đã thêm, cùng Sửa, Tìm nghĩa khác, Không phải từ.
  - Kết quả cho thêm nhiều nghĩa một lần: mỗi nghĩa là một card chọn được (dấu tick tròn, đang chọn viền blue-500 nền blue-50), nhóm theo loại từ. Nghĩa đầu được chọn sẵn; nghĩa đã có trong lộ trình hoặc đã học thì không chọn được.
  - Card mở ra hiện Định nghĩa, Ví dụ và link "Sửa nghĩa này"; mở được nhiều card cùng lúc. Nút chính đếm số nghĩa đã chọn ("Thêm 2 nghĩa"). "Tìm nghĩa khác" là link dưới danh sách.
  - IPA và loa theo quy tắc của Chi tiết từ: mọi nghĩa đọc giống nhau thì nằm dưới từ, một lần; đọc khác nhau thì mỗi card có dòng IPA + loa riêng dưới nghĩa (loa nền trắng trên card đang chọn).
  - Sửa: từ được tô trong câu ví dụ luôn là từ đang thêm, tự tô, không có bước chọn từ. Câu ví dụ không còn từ đó thì báo lỗi ngay dưới ô và chưa cho lưu.

**Giọng văn:** rõ, ngắn, tôn trọng người đọc. Không reo hò, không gây áp lực.

---

## 8. Chuyển động, âm thanh, rung

Mọi chuyển động đi qua `MotionCoordinator`. Khi bật Reduce Motion: chuyển màn hình thành mờ dần, bỏ phóng to thu nhỏ, chuyển động bay, hiệu ứng lắc và pháo giấy.

| Khoảnh khắc                    | Thời lượng                                     |
| ------------------------------ | ---------------------------------------------- |
| Nhấn (lún xuống bằng cạnh dày) | 120ms                                          |
| Đổi trạng thái                 | khoảng 240ms                                   |
| Từ hoặc chữ bay vào ô          | khoảng 220ms                                   |
| Panel phản hồi xuất hiện       | khoảng 360ms, từ dưới lên                      |
| Chuyển bước                    | 360ms                                          |
| Thanh tiến độ                  | 400ms                                          |
| Lắc khi sai                    | 400ms, chỉ ở Chọn đáp án và Nối cặp            |
| Ăn mừng cuối buổi              | Syllie bay vào, pháo giấy theo nhịp của Syllie |

- **Rung:** ba loại (lựa chọn, đúng, sai), người dùng tắt được trong Cài đặt.
- **Âm thanh hiệu ứng:** chỉ trong vùng luyện tập.

---

## 9. Checklist khi thiết kế màn hình mới

**Mọi màn hình**

- [ ] Thuộc vùng nào? Đã lấy cảm hứng đúng nguồn mà không sao chép?
- [ ] Thành phần hệ thống có đang dùng bản iOS gốc không?
- [ ] Tỷ lệ 60 trắng · 30 Ink · 10 nhấn? Card có nền trắng (không nền Ink, không pastel tràn lan)?
- [ ] Card viền 2pt, không shadow? Cạnh dày chỉ có ở nút và thẻ đáp án?
- [ ] Mọi dòng chữ đều có nghĩa, không lặp thông tin?
- [ ] Đủ khoảng thở, không nhồi nhét?
- [ ] Ổn với tên dài, nhãn tiếng Việt dài và cỡ chữ lớn?
- [ ] Không có dấu "." xanh cuối tiêu đề?
- [ ] Có phương án Reduce Motion? Vùng chạm từ 44pt?

**Vùng luyện tập**

- [ ] Một câu hỏi, một đề (chữ hoặc loa), một hành động chính?
- [ ] Panel đáy đủ trạng thái: gợi ý, xem đáp án, đúng, sai còn lượt, hết lượt?
- [ ] Không lộ đáp án trước khi kết thúc?

**Vùng sản phẩm**

- [ ] Một hành động chính?
- [ ] Mũi tên › chỉ ở chỗ chạm được?
