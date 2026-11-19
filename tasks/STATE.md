# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 19/11/2026 - Milestone 2: Sửa Triệt Để Lỗi Hiển Thị Quân Cờ Trên UI & Test Tương Tác Thành Công

## 1. Mốc hiện tại
- **Milestone 2 - Giai đoạn 2A:** Nối mạch Core Logic và UI Scene theo đúng sơ đồ wireframe `design/bố cục UI.png` ở độ phân giải 1920x1080.
- **Trạng thái:** HOÀN TẤT 100%. Đã khắc phục lỗi `BoardView` tạo trùng lặp 1 lưới `TilesGrid` rỗng đè lên trên bàn cờ. Đã chụp ảnh màn hình render thực tế chứng minh 32 quân cờ hiển thị sắc nét và nước đi Tốt e2 -> e4 hoạt động mượt mà. Đã push commit `f5c9f8b` lên GitHub `origin main`.

## 2. Các quyết định Game Designer đã chốt
1. **Remote Git:** Đã push toàn bộ code và asset lên GitHub `origin main`.
2. **Layout UI:** Khớp 100% bản vẽ `design/bố cục UI.png`.
3. **Chế độ kiểm thử:** Hotseat 2 Người chơi (Local PvP) — Trắng đi trước, Đen đi sau, tự động chuyển lượt.

## 3. Trạng thái Ag2 & Ag3
- **Ag2 (Coder):** Đã sửa [src/scenes/board_view.gd](file:///E:/ChessToDie/src/scenes/board_view.gd), giải phóng lưới rỗng duplicate, giải phóng lớp che phủ giúp toàn bộ 32 quân cờ SVG xuất hiện sắc nét trên bàn cờ. Nước đi và highlight hoạt động hoàn hảo.
- **Ag3 (Graphic Designer):** Đã hoàn tất 49/49 asset.

## 4. Việc cần làm ngay khi mở lại CLI
- Game Designer mở lại game để trải nghiệm thực tế bàn cờ và quân cờ.
- Chuyển sang **Giai đoạn 2B: AI Boss Roguelike (Fog of War) & Cánh cửa 3D**.
