# ĐẶC TẢ THIẾT KẾ ĐỒ HỌA CHO AG3 (ART & ASSET SPECIFICATION)
**Dự án:** Chess to Die  
**Độ phân giải chuẩn:** $1920 \times 1080$ (Godot 4.3+, CanvasItem / Control 2D)  
**Người giao:** AG1 (Tech Lead & Producer)  
**Người thực hiện:** Ag3 (Graphic Designer & Technical Artist)  
**Nguồn tham chiếu:** `design/GDD_Core.md`, `tasks/gdd_audit.md`  

---

## 1. NGUYÊN TẮC THẨM MỸ & THỰC THI BẮT BUỘC
1. **Phong cách thị giác (Visual Style):**
   - **Tối giản chuẩn Chess.com:** Bàn cờ phẳng, trực quan, độ tương phản sắc nét, tối ưu nhận diện trạng thái trong 0.2 giây.
   - **Tông màu Dark Fantasy / Qliphoth:** Đen than (`#121214`), xám đá (`#2A2D34`), vàng đồng cổ (`#D4AF37`), đỏ huyết dụ (`#8B0000`), tím hư vô (`#4B0082`).
   - **Cấm Animation nhân vật thừa:** Không vẽ tay cầm quân hay animation bốc bài. Toàn bộ hiệu ứng tập trung vào shader viền, hạt phát sáng, và icon trạng thái gọn gàng trên ô cờ.
2. **Định dạng file:**
   - Quân cờ và Icon trạng thái: Định dạng **SVG Vector** sắc nét chuẩn, tỷ lệ 1:1, viewbox `0 0 128 128` hoặc `0 0 256 256`.
   - Hiệu ứng ma thuật: Viết bằng **Godot Shader (`.gdshader`)** để gắn trực tiếp vào CanvasItem/TextureRect.
   - Giao diện: Dựng bằng Node UI Godot chuẩn (`.tscn`) và Theme tập trung (`.tres`).
3. **Quy tắc khớp nối 100% (Crucial Contract):**
   - Mọi tên file và đường dẫn liệt kê dưới đây phải khớp tuyệt đối 100% từng ký tự với `tasks/code_spec.md`.
4. **File kê khai tài nguyên (`assets/manifest.json`):**
   - Ag3 có trách nhiệm cập nhật `assets/manifest.json` ghi nhận trạng thái của từng asset để AG1 nghiệm thu chéo.

---

## 2. DANH MỤC TÀI NGUYÊN CHI TIẾT (EXACT PATH & SPECS)

### 2.1. Bộ Quân cờ Chuẩn (12 file SVG - 128x128 px)
*Đặc điểm:* Thiết kế phẳng, viền nét rõ, tương phản cao, phong cách gothic/qliphoth tinh gọn.
- `res://assets/sprites/pieces/pawn_white.svg` : Tốt trắng
- `res://assets/sprites/pieces/pawn_black.svg` : Tốt đen
- `res://assets/sprites/pieces/knight_white.svg` : Mã trắng
- `res://assets/sprites/pieces/knight_black.svg` : Mã đen
- `res://assets/sprites/pieces/bishop_white.svg` : Tượng trắng
- `res://assets/sprites/pieces/bishop_black.svg` : Tượng đen
- `res://assets/sprites/pieces/rook_white.svg` : Xe trắng
- `res://assets/sprites/pieces/rook_black.svg` : Xe đen
- `res://assets/sprites/pieces/queen_white.svg` : Hậu trắng
- `res://assets/sprites/pieces/queen_black.svg` : Hậu đen
- `res://assets/sprites/pieces/king_white.svg` : Vua trắng
- `res://assets/sprites/pieces/king_black.svg` : Vua đen

### 2.2. Bộ Siêu Quân cờ & Thực thể Đặc biệt (12 file SVG - 128x128 px)
*Đặc điểm:* Có vương miện gai, cánh rune, hoặc hào quang ma thuật để phân biệt ngay với quân chuẩn.
- `res://assets/sprites/pieces/super_pawn_white.svg` : Siêu Tốt trắng (3 Tốt hợp thể, giáp gai 3 hướng)
- `res://assets/sprites/pieces/super_pawn_black.svg` : Siêu Tốt đen
- `res://assets/sprites/pieces/super_knight_white.svg` : Siêu Mã trắng (2 Mã hợp thể, đầu ngựa ác quỷ có sừng)
- `res://assets/sprites/pieces/super_knight_black.svg` : Siêu Mã đen
- `res://assets/sprites/pieces/super_bishop_white.svg` : Siêu Tượng trắng (2 Tượng hợp thể, biểu tượng lưỡng cực âm dương)
- `res://assets/sprites/pieces/super_bishop_black.svg` : Siêu Tượng đen
- `res://assets/sprites/pieces/super_rook_white.svg` : Siêu Xe trắng (2 Xe hợp thể, pháo đài thành lũy có lưỡi dao chéo)
- `res://assets/sprites/pieces/super_rook_black.svg` : Siêu Xe đen
- `res://assets/sprites/pieces/super_queen_white.svg` : Siêu Hậu trắng (2 Hậu hợp thể, vương miện kép ma thần)
- `res://assets/sprites/pieces/super_queen_black.svg` : Siêu Hậu đen
- `res://assets/sprites/pieces/scarecrow.svg` : Bù nhìn ma thuật cản đường (hình nộm rơm/gỗ bị xích)
- `res://assets/sprites/pieces/heal_point.svg` : Điểm hồi phục Vòng lửa sinh tử (chữ thập ánh sáng xanh lục)

### 2.3. Bộ Dấu ấn & Trạng thái Ô cờ (8 file SVG - 64x64 px hoặc 128x128 px)
*Đặc điểm:* Icon overlay bán trong suốt, hiển thị ở góc hoặc viền ô cờ mà không che mất quân cờ bên trong.
- `res://assets/sprites/status/forbidden_cell.svg` : Dấu X gai cấm bước vào ô
- `res://assets/sprites/status/curse_mark.svg` : Đầu lâu nguyền rủa kèm vòng tròn ma pháp
- `res://assets/sprites/status/lock_mark.svg` : Dây xích ma thuật khóa quân
- `res://assets/sprites/status/shield_king.svg` : Khiên thần thánh bảo vệ Vua
- `res://assets/sprites/status/immortal_mark.svg` : Hào quang kim cương bất tử
- `res://assets/sprites/status/stealth_mark.svg` : Đôi mắt bóng đêm/sương mù tàng hình
- `res://assets/sprites/status/ban_mark.svg` : Vết nứt không gian trục xuất (Ban)
- `res://assets/sprites/status/clone_mark.svg` : Biểu tượng ảo ảnh phân thân

### 2.4. Khung Thẻ bài & Mặt Lưng Bài (3 file SVG - Tỷ lệ 3:4 hoặc 300x420 px)
*Đặc điểm:* Khung thẻ bài viền gothic chạm trổ kim loại, có cửa sổ ảnh và khung chữ mô tả.
- `res://assets/sprites/cards/card_frame_active.svg` : Khung bài Active tông màu đỏ huyết dụ / vàng đồng rực lửa
- `res://assets/sprites/cards/card_frame_passive.svg` : Khung bài Passive tông màu xanh bóng đêm / tím hư vô
- `res://assets/sprites/cards/card_back.svg` : Mặt lưng bài úp, họa tiết cây Qliphoth đảo ngược bí ẩn

### 2.5. Hệ thống Shader Hiệu ứng (.gdshader)
*Đặc điểm:* Nhẹ, chạy GPU mượt mà, hỗ trợ CanvasItem.
- `res://assets/shaders/death_ring.gdshader` : Shader ngọn lửa thiêu đốt bao quanh 4 cạnh bàn cờ
- `res://assets/shaders/river_barrier.gdshader` : Shader dòng sông năng lượng ngăn giữa hàng 4 và 5
- `res://assets/shaders/barrier_burn.gdshader` : Shader kết giới ma pháp đốt điểm trên 6 ô liền kề
- `res://assets/shaders/holy_war.gdshader` : Shader sấm sét bầu trời u ám cho chế độ Thánh chiến
- `res://assets/shaders/stealth.gdshader` : Shader làm mờ ảo ảnh tàng hình cho quân cờ

### 2.6. Theme và Giao diện UI Scenes (.tres & .tscn)
*Đặc điểm:* Dựng bằng Control/MarginContainer/GridContainer chuẩn độ phân giải $1920 \times 1080$.
- `res://assets/ui/main_theme.tres` : Theme chứa StyleBoxFlat, màu chữ, font size chuẩn tối giản
- `res://assets/ui/chessboard.tscn` : Bàn cờ 8x8 gồm 64 ô kẻ ô màu xám đậm (`#36393F`) và xám đen (`#202225`)
- `res://assets/ui/card_ui.tscn` : Component thẻ bài hiển thị tên lá bài, icon, mô tả hiệu ứng, cost
- `res://assets/ui/passive_slot.tscn` : 4 ô đặt bài úp cạnh bàn cờ
- `res://assets/ui/hand_bar.tscn` : Thanh hiển thị bài trên tay ở đáy màn hình (chứa tối đa 10 lá)
- `res://assets/ui/combat_hud.tscn` : Khung hiển thị điểm số 2 bên, avatar Boss/Player, nút End Turn

---

## 3. MẪU BÁO CÁO NGHIỆM THU (`assets/manifest.json`)
Ag3 phải duy trì file `assets/manifest.json` theo cấu trúc:
```json
{
  "total_assets": 41,
  "completed_assets": 0,
  "assets": [
    {
      "path": "res://assets/sprites/pieces/pawn_white.svg",
      "type": "svg",
      "resolution": "128x128",
      "status": "ready"
    }
  ]
}
```
