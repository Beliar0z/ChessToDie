# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 19/11/2026 - Milestone 1: Git Push Thành Công

## 1. Mốc hiện tại
- **Milestone 1:** Triển khai core gameplay và đồng bộ mã nguồn lên Git remote.
- **Giai đoạn:** Đã liên kết remote `origin` (`https://github.com/Beliar0z/ChessToDie.git`) và đẩy thành công nhánh `main`. Local working tree sạch, test pass.

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
- **Ag2 (Coder):** Đã hoàn tất các module cơ sở (`board_state.gd`, `move_validator.gd`, `piece_data.gd`, `card_resource.gd`, `test_runner.gd`). Sẵn sàng cho sprint tiếp theo: nạp dữ liệu 51 lá bài `.tres` và logic hiệu ứng.
- **Ag3 (Graphic Designer):** Đã khóa `tasks/art_spec.md`. Sẵn sàng cho sprint xuất SVG/PNG quân cờ, thẻ bài và shader.

## 4. Việc cần làm ngay khi mở lại CLI
- Tiếp tục kích hoạt Sprint Ag2 để triển khai hệ thống 51 Card Resource (`src/resources/cards/`) và logic thi triển hiệu ứng (`card_effect_manager.gd`).
- Kích hoạt Sprint Ag3 để xuất 41 tài nguyên đồ họa chuẩn SVG/Shader vào `assets/`.
- Chạy tự động headless test kiểm tra tích hợp.
