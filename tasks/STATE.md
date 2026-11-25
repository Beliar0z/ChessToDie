# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 25/11/2026 - HOÀN TẤT SPRINT B + THÊM CHẾ ĐỘ TEST LAN PVP 2 MÁY (2 CHIẾN TUYẾN) + FIX TRÙNG CHỮ `ĐÃ ÚP`/`DECK` & TÂN TRANG Ô BÀI (20/20 PASS)

## 1. Mốc hiện tại
- **Sprint A (Core Logic Full Fix):** ĐÃ NGHIỆM THU HOÀN TẤT 100% (20/20 Headless Test PASS).
- **Sprint B (Golden Standard + Sản xuất hàng loạt Asset Pixel Art + Tích hợp Godot UI/VFX):** **ĐÃ NGHIỆM THU HOÀN TẤT 100%**
  - `design/art_bible.md` v1.1 đã khóa cứng phong cách Balatro Pixel Art sắc nét (`TEXTURE_FILTER_NEAREST`).
  - **24/24 quân cờ 3D-to-Pixel (`64x64` RGBA, alpha nhị phân `{0, 255}`):** `assets/sprites/pieces/*.png` (12 quân chuẩn + 10 siêu quân + `scarecrow.png` + `heal_point.png`).
  - **51/51 tranh thẻ bài (`136x104` từ lưới `68x52` phóng `2x NEAREST`, 18 màu Balatro):** `assets/sprites/cards/art/active_01.png`..`active_31.png` và `passive_01.png`..`passive_20.png`.
  - **2 khung mặt trước cảm hứng `samplecard.jfif` (`148x206`):** `assets/ui/textures/frame_active.png`, `frame_passive.png`.
  - **2 mặt lưng Tarot đã chốt (`148x206`):** `assets/sprites/cards/the_sun_back.png` (Mặt Trời híp mắt nhe răng), `assets/sprites/cards/the_moon_back.png` (Mặt Trăng chữ `C` mắt lòng đen tròng trắng từ `tasks/images.jfif` + vòng thiên văn/mây/sao).
  - **`assets/manifest.json`:** `180/180` asset hợp lệ, `0` file thiếu trên đĩa.
  - **Tích hợp Godot 4.7.1:** Bật `default_texture_filter=0` (`NEAREST`) trong `project.godot`, nối đủ 24 quân cờ PNG + 51 tranh bài PNG + 2 khung + 2 mặt lưng Tarot + `CardInspector` phóng to `2x` (`296x412`) khi hover.
  - **Cơ chế Test tạm 2 máy LAN PvP (`src/scenes/lan_test_bridge.gd`) & Fix UI:**
    - Thanh LAN góc trên-phải (`HOST TRẮNG` / nhập IP / `JOIN ĐEN`, port `7777`): tự lật bàn cờ + đảo góc nhìn bài/Fog of War cho phe Đen, đồng bộ lockstep nước đi/bài Active/Passive/rút bài/End Turn.
    - Fix chữ `ĐÃ ÚP` đẩy lên trên ngoài khung bài (`offset_top = -18`), fix `DECK` / `BOSS DECK` nằm tách hẳn dưới ảnh mặt lưng Tarot (`offset_bottom = -26`), tân trang ô `ActiveSlot` (viền The Sun `#F4A236`) & `PassiveSlot` (viền The Moon `#64B5F6`).
  - **Godot 4.7.1 Headless Test (`test_runner.gd`):** **ALL TESTS PASSED! (20/20)** — 0 lỗi biên dịch, 0 lỗi parse, 0 lỗi thiếu resource.

## 2. Các quyết định Game Designer đã chốt
1. **Thứ tự ưu tiên:** Hoàn thiện sạch 100% Core Logic (Sprint A) → Cải tổ mỹ thuật Pixel Art & tích hợp UI Godot (Sprint B — ĐÃ XONG) → AI Boss Roguelike & 10 cánh cửa Qliphoth 3D (Giai đoạn 2B).
2. **Bố cục Phương án 1:** Bài đối thủ trên đỉnh cột trái → Bàn cờ `680x680` giữa → Bài người chơi dưới cột trái; cột phải phóng to 8 Passive (`148x206`), 2 Active (`148x196`), 2 Deck (`156x216`).
3. **Art Bible v1.1 (`design/art_bible.md`):** Pixel Art sắc nét, tương phản cao, bảng màu giới hạn kiểu Balatro, bắt buộc `TEXTURE_FILTER_NEAREST`; Mặt sau Active = Tarot The Sun (`#2E0F15`, `#F4A236`, `#FFF0C2`), Passive = Tarot The Moon (`#0B3D91`, `#64B5F6`, `#E3F2FD`); Mặt trước viền đen dày bo góc, khung tiêu đề & mô tả giấy cổ `#F5EFE6` chữ `#1A1A1D`.

## 3. Trạng thái Ag2, Ag3, Ag4 & Ag5
- **Ag2 (Coder):** Hoàn tất Sprint A (20/20 PASS). Sẵn sàng cho Giai đoạn 2B (AI Boss Fog of War + 20 lá Mega nếu có).
- **Ag3 (Godot UI/VFX):** Hoàn tất Sprint B (tích hợp full 79 PNG Pixel Art + `NEAREST` + `CardInspector` + 20/20 PASS).
- **Ag4 (Blender 3D Artist):** Hoàn tất 24/24 quân cờ 3D-to-Pixel (`tools/blender/render_all_pieces.py`). Sẵn sàng cho 10 cánh cửa Qliphoth 3D `.glb` ở Giai đoạn 2B.
- **Ag5 (SD Forge Art Pipeline):** Hoàn tất 51/51 tranh thẻ bài + 2 khung + 2 mặt lưng + `assets/manifest.json` (`tools/art_pipeline/cards_queue.json`, `batch_render_cards.py`).

## 4. Việc cần làm ngay khi mở lại CLI
- Mời Game Designer mở Godot 4.7.1 chạy trực tiếp `res://assets/ui/game_scene.tscn` chơi thử & duyệt bản Pixel Art hoàn chỉnh vừa ráp xong (ghi nhận nếu cần tinh chỉnh tranh lá bài nào hoặc bố cục UI).
- Sau khi duyệt bản chơi thử: triển khai **Giai đoạn 2B — AI Boss Roguelike (Fog of War) & 10 cánh cửa Qliphoth 3D (Forward+)**.
