Đọc `tasks/STATE.md` và `design/GDD_Core.md`. Trước tiên, cập nhật `tasks/dispatch_sprint.ps1` và `Gemini.md` để đảm bảo cả Ag2 và Ag3 đều chạy bằng model 4.0 mới nhất.

Lưu ý: Chưa chốt theme riêng của 10 Boss và chưa làm 20 lá Mega (để dành cho Milestone 2B). Đợt Auto-Dispatch này tập trung 100% vào nâng cấp **Thẻ bài, Hiệu ứng thị giác (VFX) và Bố cục UI nền tảng** theo dạng Modular để sau này dễ thay theme theo từng Boss:

1. THIẾT KẾ LẠI THẺ BÀI (`card_ui.tscn`) & VẼ ĐỦ ICON SVG CHO BỘ BÀI CƠ BẢN (Ag3 & Ag2):
- Ag3 thiết kế lại scene `assets/ui/card_ui.tscn` bằng `StyleBoxFlat` (bo góc 8px, viền 2 lớp sắc nét, đổ bóng chiều sâu) chia bố cục 4 phần cân đối:
  + Header: Tên lá bài rõ nét + huy hiệu phân loại `[ACTIVE]` (tông Đỏ huyết) hoặc `[PASSIVE]` (tông Tím vực thẳm).
  + Khung Art trung tâm: Hiển thị icon SVG riêng biệt của từng lá bài (nền tối có họa tiết hình học mờ phía sau).
  + Thân mô tả: `RichTextLabel` hoặc `Label` bật `autowrap_mode = AUTOWRAP_WORD_SMART`, cỡ chữ 11px, padding đều 4 cạnh để chữ nằm gọn 100% trong khung.
- Ag3 vẽ bộ icon vector `.svg` tối giản, sắc nét trong `assets/sprites/cards/icons/` cho toàn bộ danh sách lá bài Active và Passive hiện có trong `design/GDD_Core.md` (khiên vua, vòng lửa, sông ngăn cách, phân thân, bù nhìn, hiến tế, khóa quân, kết giới, đường chéo lửa...) và Ag2 nối đường dẫn icon vào `CardDatabase`.

2. NÂNG CẤP HIỆU ỨNG CHIÊU THỨC & CẢM GIÁC ĐÁNH (VFX / SHADERS / TWEENS) (Ag3 & Ag2):
- Hiệu ứng dùng bài & ăn quân (`src/scenes/vfx_manager.gd` hoặc tích hợp trong `BoardView` / `GameController`):
  + Khi kích hoạt bài Active: Lá bài bay/phóng nhẹ vào `ActiveSlot` kèm hiệu ứng lóe sáng (`Tween`), đồng thời phát hiệu ứng tại ô mục tiêu trên bàn cờ (vòng sóng lan tỏa, tia lửa nổ chữ thập của Tốt cảm tử, xoáy hút tâm hàng 4-5, xích khóa quân, ánh sáng hợp thể Siêu quân).
  + Hoàn thiện và tinh chỉnh 5 shader trong `assets/shaders/` (`death_ring.gdshader`, `river_barrier.gdshader`, `barrier_burn.gdshader`, `holy_war.gdshader`, `stealth.gdshader`) để hiển thị rõ ràng, mượt mà trực tiếp trên các ô cờ bị ảnh hưởng chứ không chỉ hiện chữ trên banner.
  + Hiệu ứng vật lý nhẹ (Game Feel): Rung nhẹ bàn cờ (`Screen Shake`) khi chiếu tướng, kích hoạt bài lớn hoặc nổ quân; hiệu ứng tan biến / chớp sáng khi quân cờ bị tiêu diệt hoặc bị Ban.
- Hiệu ứng viền sáng Passive (`Glow-to-Click`): Khi lá Passive úp đủ điều kiện kích hoạt, chạy shader/tween viền sáng nhịp thở (pulse glow) nổi bật để người chơi nhận ra ngay lập tức.

3. TINH CHỈNH BỐ CỤC UI NỀN TẢNG & XÒE QUẠT (Ag3 & Ag2):
- Thiết kế UI nền tảng theo phong cách tối giản, sắc nét chuẩn Chess.com (`assets/ui/main_theme.tres` dùng `StyleBoxFlat` bo góc, viền mảnh, tách riêng các hằng số màu để dễ đổi skin theo từng Boss ở Milestone sau).
- Thêm viền tọa độ bàn cờ (`a–h`, `1–8`) rõ ràng, không đè lên quân cờ; làm mượt chấm tròn nước đi hợp lệ và vòng tròn bao quanh ô ăn quân giống Chess.com.
- Tinh chỉnh khoảng cách và góc xoay xòe quạt của `CardHandView` và `OpponentHandFan` để các lá bài chồng lớp tự nhiên, hover vào lá nào thì lá đó phóng to, dựng thẳng và nổi lên mượt mà bằng `Tween` (không giật cục).

4. TỰ KIỂM TRA BẰNG ẢNH CHỤP & HEADLESS TEST:
- Chụp ảnh màn hình `tasks/ui_preview.png` khi chạy test trong Godot 4.7.1; Ag3 tự mở ảnh kiểm tra xem còn lỗi tràn chữ, lệch khung hay đè layer nào không rồi sửa triệt để trước khi báo cáo.
- Chạy Godot Headless Test đảm bảo pass 100% logic.