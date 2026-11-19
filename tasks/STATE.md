# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 20/11/2026 - Nghiệm Thu Toàn Diện Sprint Fix.md (13/13 Test Cases Pass, Render Game Scene Hoàn Hảo)

## 1. Mốc hiện tại
- **Nhiệm vụ Fix.md:** Hoàn tất 100% toàn bộ Phần A (UI/UX) và Phần B (Cơ chế Logic, Passive Glow-to-Click, Targeting System, Position History).
- **Trạng thái:** ĐÃ NGHIỆM THU HOÀN TẤT. Bộ kiểm thử tự động `test_runner.gd` đạt **13/13 PASS**. Render thực tế đã được chụp ảnh minh chứng tại `tasks/screenshot_fan_arc.png` và `tasks/screenshot_slots_active.png`. Commit `ff62dfb` đã được push an toàn lên GitHub `origin main`.

## 2. Các quyết định Game Designer đã chốt
1. **Fan Arc Bài Trên Tay:** Bài trên tay xòe vòm cung từ -14° đến +14°. Khi rê chuột vào: dựng thẳng về 0°, scale 1.28x, nhô cao `z_index = 50` để đọc rõ nội dung; rời chuột trả về vị trí cũ.
2. **Cụm Bài Đối Thủ:** Render cụm bài úp mặt lưng `card_back.svg` xòe quạt ngược ở `TopPlayerZone` kèm nhãn đếm số bài hiện tại của đối thủ.
3. **Mặt Bài Passive & Viền Sáng:**
   - Phe Trắng (Người chơi) thấy đầy đủ `card_ui.tscn` và nhãn "ĐÃ ÚP". Phe Đen thấy `card_back.svg`.
   - Cơ chế Glow-to-Click: Tự động quét điều kiện `is_ready_to_trigger`, bật viền sáng ma thuật `GlowBorder` khi đủ điều kiện, bấm trực tiếp để kích hoạt (không dùng popup Có/Không). Cửa sổ phản ứng 2.0s trong lượt Boss khi Boss kích hoạt điều kiện bẫy của người chơi.
4. **Active Slot:** Render trực tiếp `card_ui.tscn` vào `CardContainer` khi kích hoạt hoặc kéo thả Active vào.
5. **Cảnh báo giới hạn:** Chặn dùng lá Active thứ 2 trong lượt và hiện banner: "MỖI LƯỢT CHỈ ĐƯỢC DÙNG 1 LÁ ACTIVE!".
6. **Lịch sử vị trí:** Lưu `position_history` trong `PieceData` để kéo 2 Hậu về vị trí cách đó 2 nước đi.
7. **Targeting System:** Quản lý chọn tuần tự nhiều mục tiêu (Hoán đổi 2 quân, 5 ô cấm, Hợp thể, Phân thân, Khóa 3 quân, Hiến tế triệu hồi tại A1/H1/A8/H8...) với tô sáng ô và nút ESC/chuột phải để hủy.

## 3. Trạng thái Ag2 & Ag3
- **Ag2 (Coder):** ĐÃ HOÀN TẤT 100%. Triển khai Fan Arc trong `card_hand_view.gd`, cụm bài đối thủ, viền sáng passive `passive_manager.gd`, targeting system `game_controller.gd`, `position_history` trong `piece_data.gd`. Mở rộng `test_runner.gd` lên 13 test cases.
- **Ag3 (Graphic Designer):** ĐÃ HOÀN TẤT 100%. Nâng cấp `passive_slot.tscn`, `active_slot.tscn`, `game_scene.tscn` và cập nhật `manifest.json`.

## 4. Việc cần làm ngay khi mở lại CLI
- Game Designer mở lại game để trải nghiệm thực tế bộ giao diện Fan Arc và cơ chế bẫy Passive phát sáng viền.
- Chuẩn bị bước sang **Milestone 2B: Lập trình AI Boss Roguelike (Fog of War) & Dựng giao diện 10 Cánh Cửa 3D**.
