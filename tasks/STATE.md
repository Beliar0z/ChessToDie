# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 19/11/2026 - Milestone 1: Git Push & Remote Setup Gate

## 1. Mốc hiện tại
- **Milestone 1:** Thiết lập Git Remote và chuẩn bị Push toàn bộ mã nguồn dự án lên repository mới.
- **Giai đoạn:** Working tree đã sạch (`main` commit `2497bd7`), Godot headless test pass. Đang chờ xác nhận từ Game Designer về URL repository từ xa theo quy tắc kiểm soát thao tác Push.

## 2. Các quyết định Game Designer đã chốt
1. **Số lượng thẻ bài:** Khóa 51 lá bài cho Milestone 1 (31 Active + 20 Passive), 9 lá còn lại cập nhật sau.
2. **Vòng lửa sinh tử:** Nếu điểm về 0 mà chưa chiếu hết, bên có điểm ban đầu lớn hơn thì thua (Decision B - đánh thuế kẻ mạnh).
3. **Giới hạn bài:** Mỗi turn được dùng 1 Active + úp 1 Passive; tối đa 4 ô úp trên sân; kích hoạt Passive phản xạ không giới hạn số lần khi đủ điều kiện.
4. **Cứu thua chiếu hết:** Cho phép úp cả 2 lá (Passive 15 & 16), nhưng khi bị chiếu hết chỉ kích hoạt duy nhất 1 lá (ưu tiên lá úp trước).
5. **Lời nguyền (Active 31):** Đếm ngược số turn của quân = điểm của quân đó (Tốt 1đ = 1 turn, Xe 5đ = 5 turn). Hết turn không đi thì về mộ.
6. **Thánh chiến (Holy War):** Chỉ còn 2 Vua trên sân. Phá luật FIDE: 2 Vua được phép áp sát và ăn lẫn nhau trực tiếp (Decision A).
7. **Cấu trúc thực thi:** Ag2 code vào `src/`, Ag3 xuất asset vào `assets/`.
8. **Auto-Dispatch Protocol:** Tự động kích hoạt song song qua `agy` CLI, nghiệm thu tự động qua Headless Test Godot 4.7.1.

## 3. Trạng thái Ag2 & Ag3
- **Ag2 (Coder):** Đã hoàn thành các file core căn bản (`board_state.gd`, `move_validator.gd`, `piece_data.gd`, `card_resource.gd`, `test_runner.gd`). Đã chạy thử nghiệm headless pass.
- **Ag3 (Graphic Designer):** Đã khóa `tasks/art_spec.md`, chuẩn bị sprint asset cho 51 lá và bàn cờ.

## 4. Việc cần làm ngay khi mở lại CLI
- Nhận URL remote repository (GitHub/GitLab) từ Game Designer.
- Gắn remote: `git remote add origin <URL>`.
- Thực hiện push nhánh `main` lên repository từ xa ngay khi có lệnh xác nhận.
