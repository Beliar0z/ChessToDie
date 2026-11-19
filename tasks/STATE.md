# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 20/11/2026 - Triển Khai Nâng Cấp UI/UX & Cơ Chế Passive/Targeting Theo Fix.md

## 1. Mốc hiện tại
- **Nhiệm vụ:** Nâng cấp UI/UX bài xòe hình quạt (Fan Arc), cụm bài đối thủ xòe quạt ngược, cơ chế hiển thị mặt bài Passive đã úp cho người chơi, hiệu ứng viền phát sáng Glow-to-Click bẫy Passive, hệ thống Targeting nhiều mục tiêu tuần tự, lưu lịch sử vị trí kéo Hậu 2 nước và cảnh báo 1 Active/turn.
- **Trạng thái:** Đã khóa `tasks/code_spec.md` và `tasks/art_spec.md` theo đúng `design/Fix.md` và `design/GDD_Core.md`. Đang kích hoạt Auto-Dispatch song song Ag2 và Ag3.

## 2. Các quyết định Game Designer đã chốt
1. **Bài trên tay (Fan Arc):** Bỏ HBoxContainer phẳng, xếp bài theo vòm cung (-14° đến +14°). Hover dựng thẳng 0°, scale 1.28x, nhô cao `z_index = 50`.
2. **Bài đối thủ:** Hiển thị cụm bài úp xòe quạt ngược ở `TopPlayerZone` kèm nhãn đếm số lượng bài.
3. **Passive Đã Úp & Viền Sáng (Glow-to-Click):**
   - Người chơi (Trắng) thấy đầy đủ `card_ui.tscn` và nhãn "ĐÃ ÚP". Đối thủ (Đen) thấy `card_back.svg`.
   - Khi đủ điều kiện (`is_ready_to_trigger == true`): bật viền sáng ma thuật quanh ô Passive.
   - Bấm trực tiếp vào ô bẫy phát sáng để kích hoạt (không dùng popup hỏi Có/Không).
   - Cửa sổ phản ứng 2.0s trong lượt Boss khi Boss kích hoạt điều kiện bẫy của người chơi.
4. **Active Slot:** Render trực tiếp `card_ui.tscn` vào `CardContainer` khi kích hoạt hoặc kéo thả Active vào.
5. **Cảnh báo giới hạn:** Chặn dùng lá Active thứ 2 trong lượt và hiện thông báo: "MỖI LƯỢT CHỈ ĐƯỢC DÙNG 1 LÁ ACTIVE!".
6. **Lịch sử vị trí:** Lưu `position_history` trong `PieceData` để kéo Hậu về vị trí cách đó 2 nước đi.
7. **Targeting System:** Chọn nhiều mục tiêu tuần tự với tô sáng ô và hiển thị tiến độ trên banner.

## 3. Trạng thái Ag2 & Ag3
- **Ag2 (Coder):** Nhận spec `tasks/code_spec.md` (Fan Arc `card_hand_view.gd`, cụm bài đối thủ, viền sáng passive `passive_manager.gd`, targeting system `game_controller.gd`, `position_history` trong `piece_data.gd`).
- **Ag3 (Graphic Designer):** Nhận spec `tasks/art_spec.md` (nâng cấp `passive_slot.tscn` với `GlowBorder` và `CardContainer`, nâng cấp `active_slot.tscn`, thêm `OpponentHandArea` vào `game_scene.tscn`).

## 4. Việc cần làm ngay khi mở lại CLI
- Chờ Ag2 và Ag3 hoàn thành nhiệm vụ qua tiến trình ngầm `tasks/dispatch_sprint.ps1`.
- Chạy kiểm thử tự động headless Godot 4.7.1 để nghiệm thu toàn bộ.
- Báo cáo kết quả chi tiết cho Game Designer.
