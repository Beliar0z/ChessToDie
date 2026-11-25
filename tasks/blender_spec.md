# BLENDER 3D-TO-PIXEL SPEC (AG4) — FULL BATCH PRODUCTION (24 QUÂN CỜ)
**Tham chiếu phong cách:** `design/art_bible.md` & Mẫu Vàng đã duyệt (`tools/blender/render_golden_pawns.py`)  
**Blender CLI:** `E:\blender\blender.exe` (luôn chạy `--background --python`)

## 1. Mục tiêu sản xuất hàng loạt
Tạo script `E:\ChessToDie\tools\blender\render_all_pieces.py` kế thừa chính xác hệ thống ánh sáng, camera, Freestyle outline `#0A080C`, 3-step CONSTANT Cel Shader và hậu kỳ hard-binary alpha từ `render_golden_pawns.py`, để render đủ **24 file PNG `64x64` RGBA** vào `E:\ChessToDie\assets\sprites\pieces\`:

### A. 12 Quân cờ chuẩn (White & Black)
1. `pawn_white.png`, `pawn_black.png` *(giữ nguyên dáng Mẫu Vàng đã duyệt)*
2. `knight_white.png`, `knight_black.png` *(đầu ngựa điêu khắc góc cạnh Gothic, bờm sắc nét, đế tròn)*
3. `bishop_white.png`, `bishop_black.png` *(mũ giám mục chóp nhọn có khe cắt chéo đặc trưng, vòng cổ)*
4. `rook_white.png`, `rook_black.png` *(tháp pháo đài trụ vuông/tròn có 4–5 lỗ châu mai răng cưa rõ ở đỉnh)*
5. `queen_white.png`, `queen_black.png` *(thân thon cao, vương miện nhiều gai nhọn + viên ngọc đỉnh)*
6. `king_white.png`, `king_black.png` *(cao nhất bộ cờ, vương miện dày + thánh giá lớn rõ nét trên đỉnh)*

### B. 10 Siêu Quân Cờ (Super Pieces — White & Black)
Thiết kế dựa trên quân chuẩn tương ứng nhưng **oách hơn, to hơn ~10%, có thêm giáp vai / vương miện gai / hào quang tinh thể sắc nét** (tô điểm thêm mảng nhấn vàng `#F4A236` cho Siêu Quân Trắng và tím/đỏ hắc diện `#A83B1B` hoặc `#64B5F6` cho Siêu Quân Đen để phân biệt lập tức trên bàn cờ `64x64`!):
7. `super_pawn_white.png`, `super_pawn_black.png` *(Tốt đội mũ giáp sừng / vương miện nhỏ + khiên)*
8. `super_knight_white.png`, `super_knight_black.png` *(Ngựa chiến bọc giáp đầu + sừng kỳ lân / bờm lửa)*
9. `super_bishop_white.png`, `super_bishop_black.png` *(Giám mục mũ cao hai tầng + vòng hào quang sau đỉnh)*
10. `super_rook_white.png`, `super_rook_black.png` *(Pháo đài lớn 2 tầng lỗ châu mai + trụ giáp góc)*
11. `super_queen_white.png`, `super_queen_black.png` *(Nữ hoàng vương miện đại đế gai lớn + đôi cánh/hào quang sau lưng)*

### C. 2 Thực thể đặc biệt trên bàn cờ
12. `scarecrow.png` *(Bù nhìn rơm Gothic cắm trên cọc gỗ chữ thập, mũ rơm nhọn rách, bảng màu nâu rơm `#D8A85A` / `#7A4E24` + mắt phát sáng `#FFF0C2`)*
13. `heal_point.png` *(Đài tinh thể hồi máu phát sáng nổi lơ lửng trên bệ đá nhỏ, bảng màu xanh ngọc/băng `#64F6B5` / `#1E9E6E` / `#E3F2FD`)*

## 2. Yêu cầu kỹ thuật & Nghiệm thu
- Tất cả 24 file đều có kích thước chính xác **`64x64`**, mode **`RGBA`**, dung lượng > 0 KB, **alpha nhị phân tuyệt đối (`0` hoặc `255`)**, có viền đen Freestyle `#0A080C` và bóng đổ đế.
- Chạy thành công lệnh:
  `& "E:\blender\blender.exe" --background --python E:\ChessToDie\tools\blender\render_all_pieces.py`
- Tự kiểm tra bằng Python (Pillow) đủ 24/24 file hợp lệ, không file nào rỗng hoặc mờ viền.
- Không sửa `src/` hay `design/`.
