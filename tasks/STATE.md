# BỘ NHỚ TRẠNG THÁI DỰ ÁN (PERSISTENT STATE)
**Cập nhật lần cuối:** 19/11/2026 - Milestone 1: Auto-Dispatch Đang Chạy Song Song

## 1. Mốc hiện tại
- **Milestone 1:** Triển khai song song Core Logic 51 lá bài (Ag2) và Asset Vector/Shader/UI (Ag3).
- **Giai đoạn:** Đang thực thi song song Ag2 & Ag3 (Tiến trình Task-132, Ag2 PID: 15740, Ag3 PID: 660).

## 2. Các quyết định Game Designer đã chốt
1. **Số lượng thẻ bài:** Khóa 51 lá bài cho Milestone 1 (31 Active + 20 Passive), 9 lá còn lại cập nhật sau.
2. **Vòng lửa sinh tử:** Nếu điểm về 0 mà chưa chiếu hết, bên có điểm ban đầu lớn hơn thì thua (Decision B - đánh thuế kẻ mạnh).
3. **Giới hạn bài:** Mỗi turn được dùng 1 Active + úp 1 Passive; tối đa 4 ô úp trên sân; kích hoạt Passive phản xạ không giới hạn số lần khi đủ điều kiện.
4. **Cứu thua chiếu hết:** Cho phép úp cả 2 lá (Passive 15 & 16), nhưng khi bị chiếu hết chỉ kích hoạt duy nhất 1 lá (ưu tiên lá úp trước).
5. **Lời nguyền (Active 31):** Đếm ngược số turn của quân = điểm của quân đó (Tốt 1đ = 1 turn, Xe 5đ = 5 turn). Hết turn không đi thì về mộ.
6. **Thánh chiến (Holy War):** Chỉ còn 2 Vua trên sân. Phá luật FIDE: 2 Vua được phép áp sát và ăn lẫn nhau trực tiếp (Decision A).
7. **Cấu trúc thực thi:** Không dùng git worktree; Ag2 thao tác độc quyền trong `src/`, Ag3 thao tác độc quyền trong `assets/`.
8. **Auto-Dispatch Protocol:** Tự động kích hoạt đồng thời Ag2 và Ag3 qua `agy` CLI chạy ngầm, tự động chạy Unit Test Godot Headless sau khi hoàn tất.

## 3. Trạng thái Ag2 & Ag3
- **Ag2 (Coder):** Đang chạy song song (PID 15740) - Đọc `src/GEMINI.md`, `design/GDD_Core.md`, `tasks/code_spec.md`, `tasks/ag2_prompt.txt` -> Code toàn bộ 11 module GDScript và test runner vào `src/`. Log: `tasks/ag2.log`.
- **Ag3 (Graphic Designer):** Đang chạy song song (PID 660) - Đọc `assets/GEMINI.md`, `design/GDD_Core.md`, `tasks/art_spec.md`, `tasks/ag3_prompt.txt` -> Xuất 41 assets vào `assets/` và cập nhật `assets/manifest.json`. Log: `tasks/ag3.log`.

## 4. Việc cần làm ngay khi mở lại CLI
- Đợi Task-132 báo hoàn thành hoặc kiểm tra Ag2 & Ag3 kết thúc.
- Đọc `tasks/ag2.log` và `tasks/ag3.log`.
- Kiểm tra chéo 100% tài nguyên trong `assets/manifest.json` khớp với `src/`.
- Chạy lệnh test headless Godot: `& "E:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path E:\ChessToDie -s res://src/core/test_runner.gd`.
- Báo cáo kết quả nghiệm thu cuối cùng cho Game Designer.
