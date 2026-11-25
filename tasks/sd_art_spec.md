# SD FORGE & PILLOW ART SPEC (AG5) — FULL BATCH PRODUCTION (51 LÁ BÀI + MANIFEST)
**Tham chiếu phong cách:** `design/art_bible.md` & Mẫu Vàng đã duyệt (`frame_active.png`, `frame_passive.png`, `the_sun_back.png`, `the_moon_back.png`)  
**SD Forge API:** `http://127.0.0.1:7860/sdapi/v1/txt2img` (`DreamshaperPixelart.safetensors`)

## 1. Mục tiêu sản xuất hàng loạt
1. **KHÔNG ghi đè 4 file Mẫu Vàng đã chốt:**
   - `assets/ui/textures/frame_active.png`
   - `assets/ui/textures/frame_passive.png`
   - `assets/sprites/cards/the_sun_back.png`
   - `assets/sprites/cards/the_moon_back.png`
2. **Tạo hàng đợi dữ liệu `E:\ChessToDie\tools\art_pipeline\cards_queue.json`:**
   - Đọc đầy đủ **51 lá bài** từ `E:\ChessToDie\src\core\card_database.gd` (`active_01`..`active_31` và `passive_01`..`passive_20`).
   - Gán cho từng lá một prompt Dark Fantasy Pixel Art kiểu Balatro cực rõ chủ thể (ăn khớp sát tên và hiệu ứng của từng lá trong `card_database.gd`!).
     - Các lá **Active (`active_01`..`active_31`)**: ưu tiên điểm nhấn ánh sáng nóng/vàng cam/đỏ ma thuật trên nền tối kịch tính.
     - Các lá **Passive (`passive_01`..`passive_20`)**: ưu tiên điểm nhấn ánh sáng xanh biển/băng/lam ma thuật trên nền đêm huyền bí.
3. **Viết & chạy script `E:\ChessToDie\tools\art_pipeline\batch_render_cards.py`:**
   - Xuất đủ **51 tranh minh họa PNG** vào `E:\ChessToDie\assets\sprites\cards\art\<card_id>.png` (ví dụ: `active_01.png` .. `active_31.png`, `passive_01.png` .. `passive_20.png`).
   - **Kích thước khớp chính xác cửa sổ tranh của `frame_active.png` / `frame_passive.png`:** kiểm tra đúng kích thước của `assets/sprites/cards/sample_card_art.png` (hiện là `136x104` px — từ lưới gốc `68x52` phóng `2x NEAREST`, hoặc lấy đúng kích thước `sample_card_art.png` để 100% khớp khít!).
   - **Tối ưu GPU GTX 1650 4GB VRAM:**
     - Sinh SD Forge `512x384`, `steps = 18`, `cfg_scale = 7.5`, `sampler_name = "DPM++ 2M"`, `batch_size = 1`, seed cố định theo index (reproducible).
     - Hậu kỳ Pillow: center-crop tỷ lệ `68:52`, downscale về lưới gốc (`68x52`), lượng tử hóa giới hạn **16–18 màu sắc nét** (no blurry dithering), phóng `2x NEAREST` ra `136x104` (RGBA opaque).
     - **Hỗ trợ resume:** nếu file đích đã tồn tại và > 0 KB thì bỏ qua (trừ khi truyền `--force`), in tiến độ từng lá `[i/51]`.
4. **Cập nhật `E:\ChessToDie\assets\manifest.json`:**
   - Giữ lại các entry shader/theme/scene hiện có, đồng thời đăng ký đầy đủ các file PNG mới:
     - 24 quân cờ `res://assets/sprites/pieces/<name>.png` (`64x64`, `png`)
     - 2 khung mặt trước `res://assets/ui/textures/frame_active.png`, `res://assets/ui/textures/frame_passive.png` (`148x206`, `png`)
     - 2 mặt lưng Tarot `res://assets/sprites/cards/the_sun_back.png`, `res://assets/sprites/cards/the_moon_back.png` (`148x206`, `png`)
     - 51 tranh thẻ bài `res://assets/sprites/cards/art/<card_id>.png` (`136x104`, `png`)
   - Cập nhật chính xác `total_assets` và `completed_assets`.

## 2. Tiêu chí nghiệm thu
- Đủ **51/51** file trong `assets/sprites/cards/art/` (`active_01.png`..`active_31.png`, `passive_01.png`..`passive_20.png`), mỗi file > 0 KB, đúng kích thước khớp `sample_card_art.png`.
- `assets/manifest.json` là JSON hợp lệ, 100% đường dẫn PNG mới đều tồn tại thực tế trên đĩa.
- Không sửa `src/` hay `design/`.
