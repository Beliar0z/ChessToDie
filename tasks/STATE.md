# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 19/11/2026 - Milestone 1: Ag2 và Ag3 Hoàn Tất 100%, Nghiệm Thu Hoàn Thành

## 1. Mốc hiện tại
- **Milestone 1:** Triển khai core gameplay và tài nguyên đồ họa theo hợp đồng kỹ thuật.
- **Giai đoạn:** Ag2 đã hoàn tất 100% Core Logic & Headless Test (7/7 Pass). Ag3 đã xuất đầy đủ 46/46 tài nguyên đồ họa (SVG, Shader, Theme, Scene) vào `assets/` và cập nhật `assets/manifest.json`. Toàn bộ kiểm thử nghiệm thu chéo đã vượt qua. Sẵn sàng bước sang Milestone 2.

## 2. Các quyết định Game Designer đã chốt
1. **Repository từ xa:** Sử dụng `https://github.com/Beliar0z/ChessToDie.git` làm remote origin chính thức của dự án.
2. **Số lượng thẻ bài:** Khóa 51 lá bài cho Milestone 1 (31 Active + 20 Passive), 9 lá còn lại cập nhật sau.
3. **Vòng lửa sinh tử:** Nếu điểm về 0 mà chưa chiếu hết, bên có điểm ban đầu lớn hơn thì thua (Decision B - đánh thuế kẻ mạnh).
4. **Giới hạn bài:** Mỗi turn được dùng 1 Active + úp 1 Passive; tối đa 4 ô úp trên sân; kích hoạt Passive phản xạ không giới hạn số lần khi đủ điều kiện.
5. **Cứu thua chiếu hết:** Cho phép úp cả 2 lá (Passive 15 & 16), nhưng khi bị chiếu hết chỉ kích hoạt duy nhất 1 lá (ưu tiên lá úp trước).
6. **Lời nguyền (Active 31):** Đếm ngược số turn của quân = điểm của quân đó (Tốt 1đ = 1 turn, Xe 5đ = 5 turn). Hết turn không đi thì về mộ.
7. **Thánh chiến (Holy War):** Chỉ còn 2 Vua trên sân. Phá luật FIDE: 2 Vua được phép áp sát và ăn lẫn nhau trực tiếp (Decision A).
8. **Cấu trúc thực thi:** Ag2 code vào `src/`, Ag3 xuất asset vào `assets/`.
9. **Auto-Dispatch Protocol:** Tự động kích hoạt song song qua `agy` CLI, nghiệm thu tự động qua Headless Test Godot 4.7.1.

## 3. Trạng thái Ag2 & Ag3
- **Ag2 (Coder):** ĐÃ HOÀN TẤT 100%. Toàn bộ 11 module GDScript chuẩn typed và 7/7 test cases trong `src/core/test_runner.gd` đã vượt qua kiểm thử headless trên Godot 4.7.1 (Exit Code 0).
- **Ag3 (Graphic Designer):** ĐÃ HOÀN TẤT 100%. Toàn bộ 46/46 file tài nguyên (12 SVG quân chuẩn, 12 SVG siêu quân & thực thể, 8 SVG status marks, 3 SVG khung bài, 5 Shader, 6 Theme & Scene UI) đã tạo đầy đủ, XML hợp lệ, đúng chuẩn Dark Fantasy / Chess.com phẳng và đăng ký vào `assets/manifest.json`.

## 4. Việc cần làm ngay khi mở lại CLI
- Commit và push toàn bộ mã nguồn `src/` và tài nguyên `assets/` của Milestone 1 lên GitHub remote.
- Bắt đầu triển khai Milestone 2: Nối mạch Core Logic vào UI Scene (`chessboard.tscn`, `card_ui.tscn`, `hand_bar.tscn`, `passive_slot.tscn`, `combat_hud.tscn`) và tích hợp AI Boss Roguelike.
