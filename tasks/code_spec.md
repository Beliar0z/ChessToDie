# ĐẶC TẢ SỬA LỖI TOÀN DIỆN CORE LOGIC (SPRINT A - 51 LÁ BÀI & CỜ VUA)
**Người nhận:** Ag2 (Game Developer - GDScript Godot 4.7)
**Nguồn:** Kiểm toán 100% code đối chiếu `design/GDD_Core.md`
**Mục tiêu:** Sửa triệt để toàn bộ lỗi logic trong `src/core/` và `src/scenes/game_controller.gd` TRƯỚC KHI làm đợt cải tổ UI/VFX ở Sprint B.

---

## 1. SỬA LỖI ACTIVE CARDS & LUẬT CỜ CƠ BẢN

1. **`ACTIVE_01` (Song Trùng — 1 quân cờ đi 2 nước):**
   - Thêm trạng thái trong `TurnManager`: `var double_move_piece_pos: Vector2i = Vector2i(-1, -1)` (reset về `Vector2i(-1, -1)` khi bắt đầu/kết thúc lượt).
   - Khi `execute_move(from_pos, to_pos)` chạy:
     - Nếu `double_move_piece_pos != Vector2i(-1, -1)` và `from_pos != double_move_piece_pos`: trả về `false` (nước thứ 2 bắt buộc phải đi bằng đúng quân đang có hiệu ứng Song Trùng!).
     - Sau khi di chuyển quân `piece`: nếu `piece.double_move_active` là `true`:
       - Tắt `piece.double_move_active = false`.
       - Đặt `double_move_piece_pos = to_pos`.
       - Cập nhật `current_phase = Phase.MOVE_PHASE` và **RETURN `true` KHÔNG gọi `end_turn()`** để người chơi (kể cả Hậu hay bất kỳ quân nào) đi tiếp nước thứ 2!
     - Khi đi xong nước thứ 2 (`from_pos == double_move_piece_pos`): reset `double_move_piece_pos = Vector2i(-1, -1)` rồi gọi `end_turn()` bình thường!
   - Trong `game_controller.gd`: khi `double_move_piece_pos != Vector2i(-1, -1)`, tự động chọn lại ô `double_move_piece_pos` và hiện banner `"SONG TRÙNG: ĐI TIẾP NƯỚC THỨ 2!"`.

2. **Nhập thành chuẩn FIDE + `PASSIVE_13` (Nhập Thành Thiên Uyển):**
   - Trong `BoardState.move_piece(from_pos, to_pos)` (hoặc `TurnManager.execute_move`):
     - Nếu `piece.type == KING` và `absi(to_pos.x - from_pos.x) == 2`:
       - Nhập thành cánh Vua (`to_pos.x == 6`): di chuyển Xe từ `(7, y)` sang `(5, y)` (tăng `rook.move_count += 1`, `record_position`).
       - Nhập thành cánh Hậu (`to_pos.x == 2`): di chuyển Xe từ `(0, y)` sang `(3, y)`.
     - Trong `TurnManager.execute_move`: bắn `passive_manager.evaluate_triggers("castling", {"active_team": current_turn_team, "king_pos": to_pos, "board": board})` để kích hoạt `PASSIVE_13`.

3. **`ACTIVE_02` (Dịch Chuyển):**
   - Trong `_execute_active_effect`: bắt buộc `p.team == current_turn_team`, `p.type != QUEEN`, `p.type != ROOK`, ô đích trống, không bị cấm và sau khi dịch chuyển không gây chiếu Vua đối thủ (và không để Vua mình bị chiếu).

4. **`ACTIVE_14` (Triệu Hồn Mộ Địa — duy trì 1 turn duy nhất):**
   - Thêm `var temporary_summon_turns: int = 0` trong `PieceData`.
   - Khi `ACTIVE_14` triệu hồi quân từ mộ: đặt `revived.temporary_summon_turns = 1`.
   - Trong `_process_piece_status_countdowns()`: nếu `p.temporary_summon_turns > 0`, trừ 1; nếu về `0` thì gỡ quân khỏi bàn cờ trả về mộ!

5. **`ACTIVE_15`, `ACTIVE_16`, `ACTIVE_17` (Hiến tế tạo Xe/Mã-Tượng/Hậu — chờ 1 turn + spawn góc):**
   - Quân vừa được triệu hồi bằng hiến tế đặt `is_locked = true; locked_turns = 1` (chờ 1 turn mới được đi đúng GDD).
   - Ưu tiên spawn tại `A1/H1` (Trắng) hoặc `A8/H8` (Đen). Nếu cả 2 ô góc đang bận, lưu vào hàng đợi `pending_sacrifice_spawns` và tự spawn ngay khi 1 trong 2 ô góc trống!

6. **`ACTIVE_27` (Bù Nhìn Thế Thân — 3 turn hoặc bị >= 3 quân địch vây ăn):**
   - Thêm `var scarecrow_turns: int = 0` trong `PieceData`. Khi spawn đặt `crow.scarecrow_turns = 3`.
   - Trong `_process_piece_status_countdowns()`: trừ `scarecrow_turns`; nếu về 0 hoặc bị >= 3 quân địch có thể tấn công vào ô đó thì tự hủy Bù nhìn.

7. **`ACTIVE_28` (Bóng Ma Chiến Trường):**
   - Sửa `p.stealth_turns = 3` (đúng GDD dòng 52 là 3 turn, không phải 2).

8. **`ACTIVE_29` (Phân Thân Thuật):**
   - Khi một quân có `is_clone == true` di chuyển đè lên ô có quân địch trong `execute_move()`:
     - Đếm số phân thân cùng `team` và `clone_source_type` còn trên sân (`ban_rounds = max(1, clone_count)`).
     - KHÔNG giết quân địch vào mộ, mà set `captured.is_banned = true; captured.banned_turns = ban_rounds` (để quân địch nằm nguyên trạng thái Ban hoặc lưu tạm và không đi/không bị ăn) và **xóa phân thân vừa đánh** khỏi bàn cờ!
   - Trong `game_controller.gd`: cập nhật targeting cho `ACTIVE_29` cho phép chọn đúng số ô sân nhà (Tốt: tối đa 5, Mã/Tượng: 2, Vua: 3; không cho chọn Hậu & Xe).

9. **`ACTIVE_30` (Hố Đen Trọng Lực — hàng 4/5, hút bán kính 2 ô vào 1 ô, vào tâm Ban 3 turn):**
   - Trong `_execute_active_effect("ACTIVE_30")`:
     - Với mọi quân cờ trên bàn (trừ quân đang ở đúng tâm `center`), nếu `maxi(absi(pos.x - center.x), absi(pos.y - center.y)) <= 2`:
       - Tính vector kéo vào 1 ô: `step = Vector2i(signi(center.x - pos.x), signi(center.y - pos.y))`, `new_pos = pos + step`.
       - Nếu `new_pos == center`: quân bị hút vào tâm -> set `p.is_banned = true; p.banned_turns = 3` (kể cả quân mình!). Nếu ô tâm đã có quân khác, đặt ở ô trống gần tâm nhất và vẫn gắn `is_banned = true; banned_turns = 3`.
       - Nếu `new_pos != center` và ô `new_pos` trống: di chuyển quân từ `pos` sang `new_pos`.

---

## 2. SỬA TRIỆT ĐỂ 100% 20 LÁ PASSIVE

1. **Sửa lỗi `PASSIVE_20` (Ban > 2 lượt — QUAN TRỌNG NHẤT):**
   - Trong `TurnManager._process_piece_status_countdowns()`:
     - **BẮT BUỘC thêm khối đếm ngược `is_banned`:**
       ```gdscript
       if p.is_banned:
           p.banned_turns -= 1
           if p.banned_turns <= 0:
               p.is_banned = false
               p.banned_turns = 0
       ```
     - Kiểm tra kỹ: khi Trắng kích hoạt `PASSIVE_20` lên quân Đen vừa ăn quân Trắng (trong lượt Đen hoặc ngay sau nước ăn của Đen), quân Đen sẽ bị Ban đúng **2 lượt của Đen** rồi tự động gỡ Ban! (Chú ý: nếu quân Đen vừa ăn ở lượt Đen và `PASSIVE_20` kích hoạt TRƯỚC `end_turn()` của Đen, tránh trừ mất 1 lượt ngay cuối lượt đó bằng cách dùng cờ `just_applied_ban` hoặc chỉ trừ từ lượt sau, đảm bảo đúng tròn 2 lượt bị khóa!).
2. **Sửa luật Passive chỉ kích hoạt từ lượt tiếp theo (`GDD_Core.md` dòng 14):**
   - Trong `PassiveManager.evaluate_triggers()`: bỏ qua mọi slot có `int(slot.get("turns_on_board", 0)) < 1` (chỉ ngoại lệ nếu muốn test riêng, hoặc trong test hãy advance 1 turn trước khi kích hoạt Passive).
   - Cập nhật `test_runner.gd` nếu có test cũ úp bài rồi kích hoạt ngay cùng lượt (phải đặt `turns_on_board = 1` hoặc qua lượt đúng luật GDD).
3. **`PASSIVE_05` (Kết Giới Thiêu Đốt):**
   - Trong `execute_passive_trigger("PASSIVE_05")`: nếu `target_pos == Vector2i(-1, -1)` và `not board.move_history.is_empty()`, lấy `target_pos = board.move_history.back()["to"]`.
   - Trong `TurnManager._process_board_hazards()`:
     - Duyệt `board.barrier_burn_zones`: với mỗi ô có quân cờ đứng trong đó, trừ `0.5` điểm (`piece.hp` hoặc thêm `var current_points: float` / trừ trực tiếp điểm; nếu về `<= 0` thì tiêu diệt quân đó đưa vào mộ), bắn event `point_penalty_applied` cho `PASSIVE_19`, sau đó giảm `turns` của zone đi 1 (khi `turns <= 0` xóa khỏi `barrier_burn_zones`).
4. **`PASSIVE_06` (Nữ Hoàng Khóa Chân):**
   - Trong `BoardState.execute_queen_tether()`: **BỎ 2 dòng `q.is_locked = true; q.locked_turns = 2`** để đúng 100% `GDD_Core.md` dòng 64 (chỉ kéo cả 2 Hậu về vị trí cách đó 2 nước đi).
5. **`PASSIVE_08` (Đảo Nghịch Thời Gian) & `PASSIVE_14` (Thoát Hiểm Hoàng Cung):**
   - Trong `TurnManager.execute_move()`: sau khi di chuyển, nếu `MoveValidator.is_in_check(board, opp_team)`:
     - Tăng `piece.check_count += 1` (phục vụ `PASSIVE_11`!).
     - Bắn `passive_manager.evaluate_triggers("king_checked", {"checked_team": opp_team, "checking_piece": piece, "max_check_count": piece.check_count, "board": board})`.
   - Trong `TurnManager`: thêm `var forced_king_move_team: int = -1`. Khi `PASSIVE_14` kích hoạt: dịch chuyển Vua đồng minh đến `target_pos` và đặt `forced_king_move_team = int(opp_team)`. Trong `execute_move()` và `BoardView`: khi `forced_king_move_team == int(current_turn_team)`, chỉ cho phép Vua di chuyển (nếu Vua còn nước đi hợp lệ), sau khi đi xong reset `forced_king_move_team = -1`.
6. **Triển khai đủ 6 lá Passive đang thiếu trong `execute_passive_trigger()`:**
   - `PASSIVE_11` (Kỳ Thủ Lão Luyện): tìm quân đồng minh có `check_count >= 10` -> set `is_immortal = true; immortal_turns = 3`.
   - `PASSIVE_12` (Ngũ Thập Luân Hồi): thêm `var passive_12_used: bool = false`. Nếu `not passive_12_used` và `total_moves_played >= 50` và điểm 2 bên bằng nhau -> đánh dấu `passive_12_used = true`, reset bàn cờ về trạng thái ban đầu (`board.setup_initial_board()`).
   - `PASSIVE_13` (Nhập Thành Thiên Uyển): sau khi nhập thành, dịch Vua (và Xe đi kèm) lùi về phía giữa bàn cờ thêm 1 ô nếu ô đó trống.
   - `PASSIVE_17` (Đoạn Tuyệt Liên Hoàn): thêm helper `BoardState.has_three_diagonal_pawns(team) -> Array[Vector2i]`. Truyền vào `evaluate_triggers`. Khi kích hoạt `PASSIVE_17`, tiêu diệt 1 con Tốt đối thủ nằm trong chuỗi 3 Tốt chéo tại `target_pos` (hoặc con đầu tiên nếu không truyền `target_pos`).
   - `PASSIVE_18` (Hỏa Diễm Tam Điểm): khi bản thân có 3 Tốt tạo đường chéo, điền các ô thuộc đường chéo đó vào `board.fire_diagonals`. Trong `execute_move()`: mọi quân di chuyển vào ô nằm trong `board.fire_diagonals` bị trừ `1` điểm (nếu về `<= 0` bị tiêu diệt, bắn `point_penalty_applied` cho `PASSIVE_19`).
   - `PASSIVE_19` (Cộng Hưởng Bộc Phá): khi đội bị trừ điểm (từ `PASSIVE_05`, `PASSIVE_18`, hoặc Vòng lửa sinh tử), kích hoạt sẽ buff `+2` điểm cho toàn bộ quân đồng minh đang chịu ảnh hưởng.
   - Đảm bảo `game_controller.gd` có targeting step cho `PASSIVE_17` (chọn 1 trong 3 Tốt chéo địch).

---

## 3. MỞ RỘNG BỘ UNIT TEST (`src/core/test_runner.gd`)
Thêm ít nhất 5 test cases mới (nâng tổng lên **20/20 PASS**):
- Test 16: `test_active_01_double_move_queen` (dùng `ACTIVE_01` lên Hậu Trắng -> Hậu đi được ĐÚNG 2 nước liên tiếp trong cùng 1 turn mới chuyển lượt sang Đen!).
- Test 17: `test_passive_20_ban_exact_two_turns` (quân Đen ăn quân Trắng -> kích hoạt `PASSIVE_20` -> quân Đen bị Ban đúng 2 lượt của Đen, sang lượt thứ 3 tự động gỡ Ban và đi lại bình thường!).
- Test 18: `test_passive_next_turn_rule_and_burn_zone` (Passive mới úp trong turn 1 KHÔNG thể kích hoạt ngay trong turn 1; `PASSIVE_05` đốt 0.5đ/lượt và tự tắt sau 2 lượt; `PASSIVE_06` kéo 2 Hậu về không tự ý khóa).
- Test 19: `test_gravity_vortex_and_castling_and_temp_summon` (`ACTIVE_30` hút quân bán kính 2 ô vào 1 ô & Ban quân vào tâm 3 turn; Nhập thành di chuyển cả Vua và Xe; `ACTIVE_14` quân triệu hồi mộ tự biến mất sau 1 turn).
- Test 20: `test_remaining_passives_11_12_14_17_18_19` (kiểm tra `PASSIVE_11` bất tử sau 10 lần chiếu, `PASSIVE_14` ép đi Vua, `PASSIVE_17` hủy Tốt chéo, `PASSIVE_18` đường chéo lửa trừ 1đ, `PASSIVE_19` buff +2đ).

Chạy `& "E:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path E:\ChessToDie -s res://src/core/test_runner.gd` đảm bảo **20/20 PASS** và KHÔNG chạy cửa sổ đồ họa trong bước này.
TUYỆT ĐỐI KHÔNG sửa file trong `design/` hoặc `assets/`. Chỉ làm việc trong `src/`.
