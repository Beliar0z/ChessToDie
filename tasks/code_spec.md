# ĐẶC TẢ KỸ THUẬT CHO AG2 (CODE SPECIFICATION) - NÂNG CẤP THEO FIX.MD
**Dự án:** Chess to Die  
**Giai đoạn:** Milestone 2 - Hoàn thiện UI/UX & Cơ chế Viền Sáng Passive, Targeting System  
**Phiên bản:** Godot 4.7+ (GDScript Typed)  
**Người giao:** AG1 (Tech Lead & Producer)  
**Người thực hiện:** Ag2 (Game Developer)  
**Nguồn tham chiếu:** `design/Fix.md`, `design/GDD_Core.md`, `design/Lưu ý cần sửa.md`  

---

## 1. MỤC TIÊU TRIỂN KHAI
Triển khai toàn bộ các yêu cầu trong `design/Fix.md` (Phần A & Phần B):
1. **Xòe bài hình quạt (Fan Arc):** Viết lại `src/scenes/card_hand_view.gd` theo đường cong vòm, góc xoay từ -14° đến +14°. Xử lý hover chuột dựng thẳng về 0°, scale 1.28x, nhô cao `z_index = 50`.
2. **Cụm bài đối thủ xòe quạt ngược:** Thêm hiển thị cụm bài úp của đối thủ ở `TopPlayerZone` với nhãn đếm số bài trên tay.
3. **Hiện bài Passive đã úp cho người chơi & Hiệu ứng viền sáng Glow-to-Click:**
   - Khi Trắng úp bài vào `PlayerPassiveRow`, nạp `card_ui.tscn` kèm nhãn "ĐÃ ÚP". Phe Đen vẫn giữ mặt lưng `card_back.svg`.
   - `PassiveManager`: Bổ sung cơ chế quét điều kiện kích hoạt `is_ready_to_trigger`. Bật viền sáng (`GlowBorder`) quanh ô khi đủ điều kiện.
   - Bấm vào ô bẫy phát sáng để kích hoạt ngay (không dùng popup hỏi Có/Không).
   - Cửa sổ phản ứng 2.0 giây khi Boss làm bật bẫy của người chơi.
4. **Active Slot:** Render đầy đủ `card_ui.tscn` vào `CardContainer` của Active Slot khi dùng bài Active.
5. **Cảnh báo 1 Active/turn:** Chặn dùng lá Active thứ 2 và thông báo trên `MessageBanner`: "MỖI LƯỢT CHỈ ĐƯỢC DÙNG 1 LÁ ACTIVE!".
6. **Lịch sử tọa độ `position_history`:** Lưu `position_history: Array[Vector2i]` trong `PieceData` cho hiệu ứng kéo Hậu lùi 2 nước.
7. **Hệ thống chọn nhiều mục tiêu (`targeting_steps`):** Quản lý chọn tuần tự nhiều ô cho các lá bài Hoán đổi, 5 ô cấm, Hợp thể, Phân thân, Khóa 3 quân, Hiến tế triệu hồi tại A1/H1 hoặc A8/H8. Hỗ trợ ESC hoặc chuột phải để hủy.
8. **Đồng bộ toàn bộ danh mục bài & Test Runner:** Đảm bảo `src/core/test_runner.gd` pass 100% không lỗi.

---

## 2. CHI TIẾT FILE VÀ MODULE CẦN THỰC HIỆN

### 2.1. `src/core/piece_data.gd`
- Thêm trường `var position_history: Array[Vector2i] = []`.
- Khi quân cờ được khởi tạo tại `pos`, thêm `position_history.append(pos)`.
- Thêm phương thức `record_position(new_pos: Vector2i) -> void`: append `new_pos` vào mảng.
- Thêm phương thức `get_position_two_moves_ago() -> Vector2i`: lấy tọa độ cách đó 2 nước đi (nếu lịch sử < 3 thì lấy tọa độ xa nhất).

### 2.2. `src/core/board_state.gd`
- Trong hàm `execute_move(from_pos: Vector2i, to_pos: Vector2i)`: gọi `piece.record_position(to_pos)`.

### 2.3. `src/core/passive_manager.gd`
- Cập nhật cấu trúc slot:
  ```gdscript
  slot = {
      "card": card_resource,
      "placed_turn": turn_number,
      "team": team,
      "is_ready_to_trigger": false,
      "trigger_window_active": false
  }
  ```
- Thêm hàm `evaluate_triggers(event_name: String, context: Dictionary) -> Array[Dictionary]`:
  - Quét qua 4 slot của mỗi bên.
  - So khớp điều kiện với `card.id` (ví dụ: `PASSIVE_04` khi event là `active_card_played`, `PASSIVE_06` khi event là `queen_moved`, `PASSIVE_01` khi điểm ăn $\ge 10$, `PASSIVE_02` khi quân mất $> 50\%$, `PASSIVE_15`/`16` khi bị chiếu hết...).
  - Đánh dấu `slot["is_ready_to_trigger"] = true`.
- Thêm hàm `trigger_slot(team: PieceData.Team, slot_index: int) -> CardResource`: tiêu hao slot và trả về card để controller thực thi hiệu ứng.
- Thêm hàm `clear_expired_triggers()`: tự động tắt `is_ready_to_trigger = false` đối với các bẫy mang tính thời điểm nếu không được bấm kích hoạt kịp thời.

### 2.4. `src/scenes/card_hand_view.gd` (Fan Arc)
- Bỏ layout HBox phẳng. Dùng `Control` tự do làm container.
- Thuật toán sắp xếp Fan Arc:
  ```gdscript
  var count: int = cards.size()
  var card_width: float = 132.0
  var card_height: float = 196.0
  var center_index: float = float(count - 1) / 2.0
  var spacing: float = clamp(700.0 / max(count, 1), 50.0, 110.0)
  var total_width: float = spacing * (count - 1)
  var start_x: float = (custom_minimum_size.x - total_width) * 0.5

  for i in range(count):
      var holder = holders[i]
      var dist: float = (float(i) - center_index)
      var norm: float = 0.0 if count <= 1 else dist / max(center_index, 1.0) # -1.0 to +1.0
      var angle_deg: float = norm * 14.0 # từ -14 đến +14 độ
      var pos_x: float = start_x + float(i) * spacing - (card_width * 0.5)
      var pos_y: float = 20.0 + abs(norm) * 22.0 # vòm nhô cao ở giữa

      holder.position = Vector2(pos_x, pos_y)
      holder.rotation_degrees = angle_deg
      holder.pivot_offset = Vector2(card_width * 0.5, card_height)
      holder.z_index = i
      holder.set_meta("base_pos", holder.position)
      holder.set_meta("base_rot", angle_deg)
      holder.set_meta("base_z", i)
  ```
- Sự kiện rê chuột (`mouse_entered`):
  - Dựng thẳng: `holder.rotation_degrees = 0.0`
  - Phóng to: `holder.scale = Vector2(1.28, 1.28)`
  - Nhô cao: `holder.position.y = holder.get_meta("base_pos").y - 45.0`
  - Đưa lên trên: `holder.z_index = 50`
- Sự kiện rời chuột (`mouse_exited`):
  - Khôi phục rotation, scale `Vector2.ONE`, position từ `base_pos`, `z_index = base_z`.

### 2.5. `src/scenes/game_controller.gd`
- **Cụm bài đối thủ:** Quản lý `opponent_hand_container` xòe quạt ngược (`rotation_degrees` từ $+14^\circ \to -14^\circ$, pivot ở đỉnh thẻ bài, úp `card_back.svg`).
- **Passive Slot & Viền sáng:**
  - Ô Trắng úp bài: instance `card_ui.tscn` vào `CardContainer` của slot, hiển thị nhãn "ĐÃ ÚP". Ô Đen úp `card_back.svg`.
  - Kết nối tín hiệu click vào ô Passive: nếu `slot["is_ready_to_trigger"] == true`, gọi kích hoạt bẫy.
  - Bật/tắt node `GlowBorder` trên slot tương ứng với `is_ready_to_trigger`.
  - Cửa sổ phản ứng lượt Boss: `await get_tree().create_timer(2.0).timeout`.
- **Active Slot:** Render `card_ui.tscn` trực tiếp vào `CardContainer`, ẩn placeholder thô.
- **Giới hạn 1 Active:** Nếu `active_cards_played_this_turn >= 1`, chặn và hiện banner: "MỖI LƯỢT CHỈ ĐƯỢC DÙNG 1 LÁ ACTIVE!".
- **Targeting System:** Quản lý state chọn mục tiêu cho các lá bài phức tạp (Hoán đổi, 5 ô cấm, Hợp thể, Phân thân, Khóa 3 quân, Hiến tế triệu hồi góc...). Nhấn ESC hoặc chuột phải để hủy.

### 2.6. `src/core/test_runner.gd`
- Cập nhật và bổ sung test cases kiểm tra:
  - Fan arc layout calculation.
  - `position_history` tracking trên quân cờ.
  - Viền sáng và cơ chế trigger passive `is_ready_to_trigger`.
  - Chạy `godot --headless -s res://src/core/test_runner.gd` đạt PASS 100%.
