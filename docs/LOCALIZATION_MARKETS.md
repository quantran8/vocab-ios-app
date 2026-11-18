# Thị trường mục tiêu và ngôn ngữ cần hỗ trợ

Danh sách 10 thị trường đang nhắm tới, cộng thị trường gốc Việt Nam. Localization của app phải hỗ trợ
các ngôn ngữ này. Hiện tại app có `en` và `vi` (xem mục Localization trong `CLAUDE.md`).

| # | Thị trường | Ngôn ngữ | Nhóm |
|---|------------|----------|------|
| 1 | 🇮🇳 Ấn Độ | English → Hindi | Test thị trường sớm |
| 2 | 🇲🇽 Mexico | Spanish | Tăng trưởng |
| 3 | 🇯🇵 Nhật Bản | Japanese | Premium |
| 4 | 🇧🇷 Brazil | Portuguese | Tăng trưởng |
| 5 | 🇰🇷 Hàn Quốc | Korean | Premium |
| 6 | 🇹🇼 Đài Loan | Traditional Chinese | Premium |
| 7 | 🇪🇸 Tây Ban Nha | Spanish | Tận dụng bản dịch |
| 8 | 🇹🇭 Thái Lan | Thai | Tăng trưởng |
| 9 | 🇸🇦 Saudi Arabia | Arabic | Premium |
| 10 | 🇮🇩 Indonesia | Indonesian | Tăng trưởng |
| — | 🇻🇳 Việt Nam | Vietnamese | Thị trường gốc, đã hỗ trợ |

## Ngôn ngữ cần hỗ trợ (gộp theo ngôn ngữ)

| Ngôn ngữ | Mã gợi ý | Thị trường | Ghi chú |
|----------|----------|------------|---------|
| Vietnamese | `vi` | Việt Nam | Đã có; bắt buộc giữ đủ bản dịch cho mọi key mới |
| Hindi | `hi` | Ấn Độ | Dòng "English → Hindi": nghĩa của từ hiển thị bằng Hindi |
| Spanish | `es` | Mexico, Tây Ban Nha | Hai thị trường dùng chung một bản dịch (Tây Ban Nha là "tận dụng bản dịch"); chỉ tách `es-MX`/`es-ES` nếu từ vựng khác biệt đáng kể |
| Japanese | `ja` | Nhật Bản | |
| Portuguese | `pt-BR` | Brazil | Bồ Đào Nha Brazil, không phải `pt-PT` |
| Korean | `ko` | Hàn Quốc | |
| Traditional Chinese | `zh-Hant` | Đài Loan | Chữ phồn thể, không dùng bản giản thể |
| Thai | `th` | Thái Lan | |
| Arabic | `ar` | Saudi Arabia | Chữ viết phải-sang-trái (RTL): cần kiểm tra layout, icon có hướng, chuyển cảnh |
| Indonesian | `id` | Indonesia | |

## Quy tắc

Mọi text hiển thị trong app (không đến từ dữ liệu) phải có bản dịch đầy đủ cho **tất cả** ngôn ngữ ở bảng trên,
trong cùng một thay đổi. Thiếu một ngôn ngữ ở bất kỳ key nào là lỗi. Chi tiết kỹ thuật ở mục Localization trong `CLAUDE.md`.

## Trạng thái

- `AppLanguage` có đủ 11 ngôn ngữ; `knownRegions` trong `project.pbxproj` đã thêm.
- Bản dịch `Localizable.xcstrings` và `InfoPlist.xcstrings` cho 9 ngôn ngữ mới được dịch máy (AI). Cần người bản ngữ
  rà soát trước khi phát hành ở từng thị trường, đặc biệt Arabic, Hindi, Thai, Nhật, Hàn.
- `uiLocale` gửi backend (`hi-IN`, `es-MX`, `ja-JP`, `pt-BR`, `ko-KR`, `zh-TW`, `th-TH`, `ar-SA`, `id-ID`) cần backend xác nhận hỗ trợ.

## Việc còn lại

- Nội dung học (nghĩa, phản hồi) đến từ JSON và backend, không nằm trong string catalog: cần `vocab-backend` trả nghĩa theo ngôn ngữ.
- Arabic (RTL) cần rà soát riêng: mascot, thanh tiến độ, bảng nối từ, hướng chuyển cảnh, icon có hướng.
- Thai, Japanese, Chinese, Korean không tách từ bằng khoảng trắng: kiểm tra cách ngắt dòng và typography token.
- Màn chọn ngày trong tuần (`Weekday`) chỉ có quy tắc riêng cho tiếng Việt; các ngôn ngữ khác theo locale hệ thống.
