# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 19/11/2026 - Milestone 2: Giai Đoạn 2A Hoàn Tất 100%, Nghiệm Thu Thành Công (8/8 Pass)

## 1. Mốc hiện tại
- **Milestone 2 - Giai đoạn 2A:** Nối mạch Core Logic và UI Scene theo đúng sơ đồ wireframe `design/bố cục UI.png` ở độ phân giải 1920x1080.
- **Trạng thái:** HOÀN TẤT 100%. Ag2 (Coder) và Ag3 (Graphic Designer) đã xuất xưởng toàn bộ Controller và Scene UI. Headless Test Suite trên Godot 4.7.1 vượt qua 8/8 test cases. Toàn bộ 49/49 asset trong `assets/manifest.json` tồn tại đầy đủ.

## 2. Các quyết định Game Designer đã chốt
1. **Remote Git:** Đã push code Milestone 1 lên GitHub `origin main`.
2. **Layout UI:** Tuân thủ 100% sơ đồ bản vẽ `design/bố cục UI.png`:
   - Bên trái: Bàn cờ 8x8 ở trên, tay bài ở dưới, cọc bài rút nằm cạnh tay bài.
   - Bên phải đối xứng: Phe Đen (trên) có 4 ô Passive + 1 ô Active; Phe Trắng (dưới) có 1 ô Active + 4 ô Passive; Khu trung tâm có HUD pha lượt, thông báo banner và nút End Turn.
3. **Màu sắc:** Tạm thời giữ phong cách Qliphoth / Dark Fantasy phẳng đã có.
4. **Chế độ kiểm thử:** Chọn **Phương án 1: Hotseat 2 Người chơi (Local PvP)** — 2 phe luân phiên đi cờ và đánh bài trên cùng một máy.

## 3. Trạng thái Ag2 & Ag3
- **Ag2 (Coder):** ĐÃ HOÀN TẤT 100%. Triển khai [src/scenes/game_controller.gd](file:///E:/ChessToDie/src/scenes/game_controller.gd) (655 dòng), nâng cấp `board_view.gd`, `card_hand_view.gd`, cấu hình `project.godot` và bổ sung test case `test_ui_scene_integration` vào `test_runner.gd` (Pass 8/8).
- **Ag3 (Graphic Designer):** ĐÃ HOÀN TẤT 100%. Xuất đầy đủ [assets/ui/game_scene.tscn](file:///E:/ChessToDie/assets/ui/game_scene.tscn), [assets/ui/active_slot.tscn](file:///E:/ChessToDie/assets/ui/active_slot.tscn), [assets/sprites/cards/deck_pile.svg](file:///E:/ChessToDie/assets/sprites/cards/deck_pile.svg) và cập nhật [assets/manifest.json](file:///E:/ChessToDie/assets/manifest.json) (49/49 tài nguyên sẵn sàng).

## 4. Việc cần làm ngay khi mở lại CLI
- Commit mã nguồn và asset Giai đoạn 2A vào Git local.
- Xin phép Game Designer thực hiện `git push origin main`.
- Chuyển sang **Giai đoạn 2B: AI Boss Roguelike (Fog of War) & Cánh cửa 3D**.
