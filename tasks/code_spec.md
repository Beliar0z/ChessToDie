# ĐẶC TẢ KỸ THUẬT CHO AG2 (CODE SPECIFICATION) - GIAI ĐOẠN 2A
**Dự án:** Chess to Die  
**Giai đoạn:** Milestone 2 - Giai đoạn 2A: Nối Mạch Core Logic & UI Scene  
**Phiên bản:** Godot 4.7+ (GDScript Typed)  
**Người giao:** AG1 (Tech Lead & Producer)  
**Người thực hiện:** Ag2 (Game Developer)  
**Nguồn tham chiếu:** `design/GDD_Core.md`, `design/bố cục UI.png`, `tasks/art_spec.md`  

---

## 1. MỤC TIÊU GIAI ĐOẠN 2A
Kết nối toàn bộ 11 module Core Logic đã hoàn thành ở Milestone 1 vào hệ thống giao diện UI Scene theo đúng sơ đồ wireframe trong `design/bố cục UI.png` ở độ phân giải 1920x1080.
Hỗ trợ chế độ chơi **Hotseat 2 Người chơi (Local PvP)**: Người chơi Trắng và Đen luân phiên điều khiển trên cùng một màn hình.

---

## 2. DANH MỤC FILE CẦN TẠO & CHỈNH SỬA
Chỉ được tạo và sửa file trong thư mục `src/` và file cấu hình `project.godot`:
1. `src/scenes/game_controller.gd`: Controller chính kế thừa `Control` (gắn vào root của `res://assets/ui/game_scene.tscn`).
2. `src/scenes/board_view.gd`: Nâng cấp / kết nối trực tiếp với GridContainer 8x8 của `chessboard.tscn`, xử lý vẽ quân bằng TextureRect SVG và bắt sự kiện click.
3. `src/scenes/card_hand_view.gd`: Nâng cấp hiển thị danh sách thẻ bài trên tay bằng `card_ui.tscn`, xử lý click/drag đánh Active hoặc úp Passive.
4. `src/core/test_runner.gd`: Bổ sung thêm test case integration (test_ui_scene_integration) kiểm tra nạp `game_scene.tscn` và mô phỏng 1 vòng tương tác đi cờ/dùng bài headless.
5. `project.godot`: Đặt `application/run/main_scene="res://assets/ui/game_scene.tscn"`.

---

## 3. CẤU TRÚC KẾT NỐI NODE TRONG `game_scene.tscn`
`game_controller.gd` sẽ tìm hoặc tham chiếu các node con theo đúng layout `design/bố cục UI.png`:
- **Vùng Bàn Cờ (Bên Trái):**
  - Node `ChessboardArea/Chessboard` (`assets/ui/chessboard.tscn`): Lưới 8x8 ô cờ.
  - Node `BottomArea/HandContainer` (`assets/ui/hand_bar.tscn`): Chứa các lá bài trên tay.
  - Node `BottomArea/DeckSlot`: Chứa bộ bài để rút, hiển thị số lá còn lại (`X / 27`).
- **Vùng Tác Vụ & Passive (Bên Phải):**
  - **Phe Đen (TopPlayerZone):**
    - `OpponentPassiveRow`: Chứa 4 ô `passive_slot.tscn`.
    - `OpponentActiveSlot`: 1 ô `active_slot.tscn` nhận bài Active khi phe Đen đánh bài.
    - `OpponentScoreLabel`: Điểm số phe Đen.
  - **Khu Điều Khiển Trung Tâm (CenterControlZone):**
    - `TurnPhaseLabel`: Label hiển thị Lượt (TRẮNG/ĐEN), Vòng đấu (Round), Pha (Draw, Main, Move, End).
    - `MessageBanner`: Hiển thị thông báo trạng thái lớn (Chiếu, Checkmate Hook, Vòng lửa...).
    - `EndTurnButton`: Nút kết thúc lượt.
  - **Phe Trắng (BottomPlayerZone):**
    - `PlayerActiveSlot`: 1 ô `active_slot.tscn` nhận bài Active khi phe Trắng đánh bài.
    - `PlayerPassiveRow`: Chứa 4 ô `passive_slot.tscn`.
    - `PlayerScoreLabel`: Điểm số phe Trắng.

---

## 4. CHI TIẾT LOGIC TƯƠNG TÁC BẮT BUỘC

### 4.1. Tương tác Bàn cờ 8x8 (Chess Interaction)
- Lắng nghe click ô cờ:
  - Nếu click vào quân cờ của phe đang đến lượt (`turn_manager.current_turn_team`):
    - Đánh dấu `selected_pos`.
    - Gọi `MoveValidator.get_legal_moves(board, selected_pos, is_holy_war)` để lấy mảng nước đi hợp lệ.
    - Đổi màu/hiện vòng tròn highlight trên các ô đi hợp lệ.
  - Nếu đang có quân được chọn và click vào 1 ô nằm trong `highlighted_moves`:
    - Gọi `turn_manager.execute_move(selected_pos, target_pos)`.
    - Cập nhật lại hình ảnh quân cờ trên bàn cờ.
    - Kiểm tra phong cấp tốt: Nếu tốt đến đáy bàn cờ, tự động phong cấp thành Hậu (`QUEEN`).
    - Xóa highlight và bỏ chọn quân.
  - Nếu click vào ô khác không hợp lệ: Bỏ chọn quân.

### 4.2. Tương tác Thẻ bài (Card Hand & Slots)
- Trong chế độ Hotseat Local PvP: Khi đến lượt phe nào, hiển thị danh sách thẻ bài trên tay của phe đó (`turn_manager.white_engine.hand` hoặc `turn_manager.black_engine.hand`).
- Khi click vào 1 lá bài trên tay:
  - Phóng to nhẹ hoặc đổi viền sáng để báo hiệu lá bài đang được chọn (`selected_card`).
- Đánh bài Active:
  - Khi đã chọn 1 lá Active và người chơi click vào `PlayerActiveSlot` (hoặc `OpponentActiveSlot` tương ứng với lượt):
  - Kiểm tra điều kiện qua `TurnManager`: lượt này chưa dùng Active (`active_cards_played_this_turn < 1`).
  - Gọi thực thi hiệu ứng bài, trừ lá bài khỏi tay, hiển thị thẻ bài vào `ActiveSlot`, sau đó xóa/thu nhỏ đưa vào mộ.
- Úp bài Passive:
  - Khi đã chọn 1 lá Passive và người chơi click vào 1 trong 4 ô của `PlayerPassiveRow` (hoặc `OpponentPassiveRow`):
  - Kiểm tra điều kiện: lượt này chưa úp Passive (`passive_cards_placed_this_turn < 1`) và slot đó đang trống.
  - Đặt bài vào `PassiveManager`, hiển thị mặt lưng (`assets/sprites/cards/card_back.svg`) tại slot đó, trừ lá bài khỏi tay.
- Rút bài từ bộ bài:
  - Click vào `DeckSlot` hoặc tự động rút: Khi đạt 2 nước đi bản thân, `card_engine.check_and_draw()` tự động rút thêm 1 lá từ cọc bài vào tay. Cập nhật nhãn số lượng lá còn lại trên `DeckSlot`.

### 4.3. Tương tác HUD & Pha Lượt
- Nút `EndTurnButton`:
  - Khi bấm, gọi `turn_manager.end_turn()`.
  - Cập nhật hiển thị sang lượt phe tiếp theo, reset trạng thái đã đánh Active/Passive của lượt mới.
  - Cập nhật nhãn `TurnPhaseLabel` và điểm số `PlayerScoreLabel`, `OpponentScoreLabel`.
- Banner thông báo (`MessageBanner`):
  - Lắng nghe các sự kiện:
    - Khi có nước chiếu: hiển thị "CHIẾU TƯỚNG!".
    - Khi bị chiếu hết nhưng có Passive cứu: hiển thị "CHECKMATE HOOK TRIGGERED! 2 NƯỚC GIẢI VÂY".
    - Khi Stalemate: hiển thị "VÒNG LỬA SINH TỬ KÍCH HOẠT!".
    - Khi chỉ còn 2 Vua: hiển thị "THÁNH CHIẾN 2 VUA! VUA ĐƯỢC ĂN NHAU!".

### 4.4. Tích hợp Shaders Hiệu Ứng Bàn Cờ
- Khi `turn_manager.death_ring_system.is_death_ring_active == true`: Kích hoạt shader `res://assets/shaders/death_ring.gdshader` trên bàn cờ.
- Khi có quân dính lời nguyền hoặc tàng hình: Gán shader `res://assets/shaders/stealth.gdshader` hoặc icon status mark tương ứng từ `assets/sprites/status/`.

---

## 5. YÊU CẦU KIỂM THỬ TỰ ĐỘNG (INTEGRATION TEST)
Trong `src/core/test_runner.gd`:
Thêm test case `test_ui_scene_integration()`:
- Nạp scene `res://assets/ui/game_scene.tscn`.
- Kiểm tra root node có script `GameController`.
- Kiểm tra tồn tại đầy đủ các node con: `Chessboard`, `HandContainer`, `DeckSlot`, `PlayerActiveSlot`, `OpponentActiveSlot`, `PlayerPassiveRow`, `OpponentPassiveRow`, `EndTurnButton`.
- Gọi hàm khởi tạo `setup_game()` và mô phỏng 1 thao tác đi cờ (chọn Tốt e2, đi e4), kiểm tra trạng thái cập nhật thành công mà không gây lỗi runtime.
- In `[PASS] test_ui_scene_integration` và thoát code 0.
