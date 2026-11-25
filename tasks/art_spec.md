# GODOT UI/VFX INTEGRATION SPEC (AG3) — SPRINT B (PIXEL ART GOLDEN STANDARD)
**Tham chiếu phong cách:** `design/art_bible.md`  
**Engine:** Godot 4.7.1 (`E:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`)

## 1. Mục tiêu tích hợp toàn bộ Asset Pixel Art Mẫu Vàng vào Godot
Thay thế toàn bộ asset SVG cũ (quân cờ, khung thẻ bài, mặt lưng, icon thẻ bài) sang bộ **PNG Pixel Art** vừa sản xuất bởi Ag4 & Ag5, bật **`TEXTURE_FILTER_NEAREST`** trên toàn dự án, và nâng cấp `card_ui.tscn` + `CardInspector` theo đúng `design/art_bible.md`.

## 2. Danh sách thay đổi bắt buộc (Khớp nối 100% tên file)

### A. Cấu hình Godot `Nearest` Filter (`project.godot`)
- Thêm vào `project.godot`:
  ```ini
  [rendering]
  textures/canvas_textures/default_texture_filter=0
  ```
- Đảm bảo mọi `TextureRect` quân cờ, khung bài, tranh bài, mặt lưng bài đặt `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`.

### B. Tích hợp 24 Quân Cờ 3D-to-Pixel (`src/scenes/board_view.gd`)
- Đổi 24 đường dẫn trong `src/scenes/board_view.gd` từ `.svg` sang `.png`:
  - `res://assets/sprites/pieces/pawn_white.png`, `pawn_black.png`
  - `knight_white.png`, `knight_black.png`, `bishop_white.png`, `bishop_black.png`
  - `rook_white.png`, `rook_black.png`, `queen_white.png`, `queen_black.png`
  - `king_white.png`, `king_black.png`
  - `super_pawn_white.png`, `super_pawn_black.png`, `super_knight_white.png`, `super_knight_black.png`
  - `super_bishop_white.png`, `super_bishop_black.png`, `super_rook_white.png`, `super_rook_black.png`
  - `super_queen_white.png`, `super_queen_black.png`
  - `scarecrow.png`, `heal_point.png`
- Đảm bảo `TextureRect` của quân cờ có `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST` và `stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED`.

### C. Tích hợp 51 Tranh Thẻ Bài, 2 Khung Mặt Trước & 2 Mặt Lưng Tarot
1. `src/core/card_database.gd` (dòng 38):
   - Đổi `card.icon_path = "res://assets/sprites/cards/art/" + id.to_lower() + ".png"` (51 file `active_01.png`..`active_31.png`, `passive_01.png`..`passive_20.png`).
2. `src/scenes/card_hand_view.gd` & `src/scenes/game_controller.gd`:
   - `FRAME_ACTIVE_PATH = "res://assets/ui/textures/frame_active.png"`
   - `FRAME_PASSIVE_PATH = "res://assets/ui/textures/frame_passive.png"`
   - `CARD_BACK_ACTIVE_PATH = "res://assets/sprites/cards/the_sun_back.png"`
   - `CARD_BACK_PASSIVE_PATH = "res://assets/sprites/cards/the_moon_back.png"`
   - `CARD_BACK_PATH = "res://assets/sprites/cards/the_moon_back.png"` (hoặc chọn `the_sun_back.png` cho bài Active / Deck Active và `the_moon_back.png` cho bài Passive úp ở `passive_slot.tscn`!).
3. `assets/ui/passive_slot.tscn` & `assets/ui/game_scene.tscn`:
   - `passive_slot.tscn`: đổi `CardBackTexture` sang `res://assets/sprites/cards/the_moon_back.png` với `texture_filter = 1` (`NEAREST`).
   - `game_scene.tscn`: đổi texture Deck sang `res://assets/sprites/cards/the_sun_back.png` (hoặc giữ 2 mặt lưng Tarot sắc nét) với `texture_filter = 1` (`NEAREST`).
4. Thiết kế lại lớp hiển thị trong `assets/ui/card_ui.tscn` (và code bind trong `card_hand_view.gd` / `game_controller.gd`):
   - **Tầng dưới:** `ArtIcon` (tranh minh họa `136x104` đặt vừa khít vùng cửa sổ tranh trong suốt của khung, `texture_filter = 1` `NEAREST`).
   - **Tầng giữa:** `CardFrame` (`frame_active.png` / `frame_passive.png`, **`modulate = Color(1, 1, 1, 1)`**, `texture_filter = 1` `NEAREST`, tắt `CardBg` cũ hoặc ẩn đi để lộ viền bo góc đen của khung PNG!).
   - **Tầng trên:**
     - `TitleLabel`: đặt gọn trong dải giấy cổ `#F5EFE6` phía trên (tránh đè huy hiệu góc trên-trái và mây góc trên-phải), **chữ màu tối `#1A1A1D`** (`Color(0.102, 0.102, 0.114, 1)`).
     - `DescLabel` (nếu có trên lá bài): đặt gọn trong khung giấy cổ `#F5EFE6` phía dưới, **chữ màu tối `#1A1A1D`**.
     - Ẩn `TypeBadge` & `Divider` cũ vì khung PNG đã có sẵn huy hiệu loại bài và dải mây/lửa ngăn cách siêu đẹp!
5. **`CardInspector` (Soi bài cỡ lớn khi hover):**
   - Đảm bảo khi hover bất kỳ lá bài nào trên tay hoặc trên bàn (đã mở), khung `CardInspector` cỡ lớn hiển thị sắc nét (`NEAREST`) tranh bài + khung bài + tên bài + mô tả đầy đủ bằng chữ tối `#1A1A1D` trên nền giấy cổ `#F5EFE6` để chống đau mắt.

## 3. Tiêu chí nghiệm thu (Bắt buộc)
- Chạy headless test Godot 4.7.1:
  `& "E:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path E:\ChessToDie -s res://src/core/test_runner.gd`
- Đạt **20/20 PASS**, 0 lỗi biên dịch/parse, 0 lỗi thiếu resource!
- Chụp ảnh preview giao diện mới (nếu có script chụp `tasks/ui_preview.png`) để kiểm chứng trực quan.
