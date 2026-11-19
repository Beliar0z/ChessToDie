# ĐẶC TẢ THIẾT KẾ ĐỒ HỌA CHO AG3 (ART & ASSET SPECIFICATION) - GIAI ĐOẠN 2A
**Dự án:** Chess to Die  
**Giai đoạn:** Milestone 2 - Giai đoạn 2A: Nối Mạch Core Logic & UI Scene  
**Độ phân giải chuẩn:** $1920 \times 1080$ (Godot 4.7+, CanvasItem / Control 2D)  
**Người giao:** AG1 (Tech Lead & Producer)  
**Người thực hiện:** Ag3 (Graphic Designer & Technical Artist)  
**Nguồn tham chiếu:** `design/GDD_Core.md`, `design/bố cục UI.png`, `tasks/code_spec.md`  

---

## 1. MỤC TIÊU GIAI ĐOẠN 2A
Xây dựng Scene giao diện tổng thể `res://assets/ui/game_scene.tscn` và các thành phần UI bổ trợ theo đúng bản vẽ wireframe trong `design/bố cục UI.png` ở độ phân giải 1920x1080.
Bảo đảm tính thẩm mỹ Dark Fantasy / Qliphoth, tối giản phẳng chuẩn Chess.com đã định hình từ Milestone 1.

---

## 2. DANH MỤC TÀI NGUYÊN CẦN XUẤT MỚI VÀO `assets/`
Chỉ được tạo và sửa file trong thư mục `assets/`:
1. `res://assets/ui/game_scene.tscn`: Scene gốc tổng hợp toàn bộ màn hình ván cờ $1920 \times 1080$.
2. `res://assets/ui/active_slot.tscn`: Scene ô đặt/đánh bài Active (kích thước $150 \times 210$).
3. `res://assets/sprites/cards/deck_pile.svg`: Icon đồ họa SVG cho cọc bài rút (Draw Deck Pile).
4. `res://assets/manifest.json`: Cập nhật kê khai danh mục tài nguyên mới.

---

## 3. CẤU TRÚC CHI TIẾT CỦA `res://assets/ui/game_scene.tscn`
Scene gốc là một node `Control` với kích thước $1920 \times 1080$, anchor preset Full Rect (`anchors_preset = 15`), áp dụng Theme `res://assets/ui/main_theme.tres`.

### 3.1. Phân bố khu vực theo `design/bố cục UI.png`:
- **Nền màn hình (Background):** `ColorRect` màu tối `#0f1012`.
- **Khu vực Bên Trái (LeftArea) - Bàn cờ & Tay bài:**
  - `ChessboardArea` (Control):
    - Tọa độ: `offset_left = 60`, `offset_top = 40`, kích thước $800 \times 800$.
    - Instance node con: `Chessboard` (`res://assets/ui/chessboard.tscn`).
  - `BottomArea` (Control):
    - Tọa độ: `offset_left = 60`, `offset_top = 860`, kích thước $880 \times 200$.
    - `HandContainer` (HBoxContainer): Chứa các thẻ bài trên tay (chiều rộng ~700px, cuộn hoặc giãn cách đều).
    - `DeckSlot` (Control / Button): Nằm bên phải `HandContainer` (tọa độ x ~720, rộng ~140, cao ~190), hiển thị Texture của `res://assets/sprites/cards/deck_pile.svg` kèm `Label` đếm số bài còn lại (ví dụ: "DECK: 21").
- **Khu vực Bên Phải (RightArea) - Zone bài & Điều khiển:**
  - Tọa độ: `offset_left = 980`, `offset_top = 40`, kích thước $880 \times 1000$.
  - **Khu vực Đối thủ (TopPlayerZone) - Phe Đen:**
    - `OpponentScoreLabel`: Label điểm số và trạng thái phe Đen (`OPPONENT: 39 PTS`).
    - `OpponentPassiveRow` (HBoxContainer): Chứa 4 ô `res://assets/ui/passive_slot.tscn`.
    - `OpponentActiveSlot` (Control): Instance `res://assets/ui/active_slot.tscn` (vùng kích hoạt lá bài Active của phe Đen).
  - **Khu vực Trung Tâm (CenterControlZone):**
    - `TurnPhaseLabel`: Label hiển thị `ROUND 1 - WHITE TURN | MAIN PHASE` (font size 24, canh giữa).
    - `MessageBanner`: Label hoặc Panel thông báo sự kiện nổi bật (font size 28, màu vàng đồng `#D4AF37`, canh giữa).
    - `EndTurnButton`: Button kết thúc lượt (kích thước $200 \times 50$, chữ "END TURN").
  - **Khu vực Người chơi (BottomPlayerZone) - Phe Trắng:**
    - `PlayerActiveSlot` (Control): Instance `res://assets/ui/active_slot.tscn` (vùng kích hoạt lá bài Active của phe Trắng).
    - `PlayerPassiveRow` (HBoxContainer): Chứa 4 ô `res://assets/ui/passive_slot.tscn`.
    - `PlayerScoreLabel`: Label điểm số và trạng thái phe Trắng (`PLAYER: 39 PTS`).

---

## 4. CHI TIẾT SCENE `res://assets/ui/active_slot.tscn`
- Kích thước: $150 \times 210$ (tương đương `card_ui.tscn`).
- Cấu trúc Node:
  - Root: `Control` tên `ActiveSlot` (custom_minimum_size = 150x210).
  - `SlotBackground`: `ColorRect` màu tối `#16131c` có độ mờ nhẹ.
  - `SlotBorder`: `ReferenceRect` viền vàng đồng `#D4AF37` hoặc đỏ ma thuật `#8B0000`, border width 2px.
  - `SlotLabel`: Label chính giữa ghi `ACTIVE SPELL SLOT` (font size 11, màu xám nhạt).
  - `CardContainer`: Control hoặc TextureRect để chứa thẻ bài khi được kích hoạt vào ô này.

---

## 5. CHI TIẾT SVG `res://assets/sprites/cards/deck_pile.svg`
- ViewBox: `0 0 128 128` (hoặc `0 0 150 210`).
- Thiết kế: Biểu tượng một xấp thẻ bài xếp chồng lên nhau, mặt trên có hoa văn biểu tượng Qliphoth/Gothic tối giản tương đồng với `card_back.svg`.
- Màu sắc: Tông màu tím thẫm và vàng đồng, đường nét sắc nét.
