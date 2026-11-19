# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 19/11/2026 - Milestone 2: Bắt đầu Giai đoạn 2A - Nối mạch Core Logic và UI Scene

## 1. Mốc hiện tại
- **Milestone 1:** Hoàn tất 100%, commit `3394420` đã được push an toàn lên remote `https://github.com/Beliar0z/ChessToDie.git` (nhánh `main`).
- **Milestone 2 - Giai đoạn 2A:** Nối mạch Core Logic và UI Scene (Bàn cờ, Tay bài, Slot thụ động, HUD trận đấu, Tích hợp Shader).

## 2. Các quyết định Game Designer đã chốt
1. **Remote Git:** Đã cấp phép và push thành công lên GitHub `origin main`.
2. **Ưu tiên Milestone 2:** Tập trung hoàn thiện giai đoạn 2A (Nối mạch Core Logic với UI Scene để người chơi tương tác đánh cờ và dùng bài trực tiếp trên giao diện) trước khi làm AI Boss và cánh cửa Roguelike 3D.
3. **Độ phân giải & hiển thị:** Chuẩn 1920x1080, CanvasItem / Expand.

## 3. Trạng thái Ag2 & Ag3
- **Ag2 (Coder):** Đã hoàn tất 11 module core. Chuẩn bị nhận spec bóc tách cho UI controller, kết nối signals giữa TurnManager/CardEngine với UI scenes (`board_view`, `hand_bar`, `card_ui`, `passive_slot`, `combat_hud`).
- **Ag3 (Graphic Designer):** Đã xuất 46 asset vào `assets/`. Chuẩn bị nhận spec bổ sung (nếu cần tinh chỉnh layout/texture cho scene chính `game_scene.tscn`).

## 4. Việc cần làm ngay khi mở lại CLI
- Bóc tách hợp đồng kỹ thuật cho Giai đoạn 2A: `tasks/code_spec.md` (đặc tả controller và event flow cho UI), `tasks/art_spec.md` (tổng hợp scene root `game_scene.tscn`).
- Chuẩn bị prompt cho Ag2 và Ag3, kích hoạt điều phối song song qua `tasks/dispatch_sprint.ps1`.
- Kiểm thử chạy Scene trên Godot 4.7.
