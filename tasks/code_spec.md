# ĐẶC TẢ KỸ THUẬT CHO AG2 (CODE SPECIFICATION)
**Dự án:** Chess to Die  
**Phiên bản:** Godot 4.3+ (GDScript Typed)  
**Người giao:** AG1 (Tech Lead & Producer)  
**Người thực hiện:** Ag2 (Game Developer)  
**Nguồn tham chiếu:** `design/GDD_Core.md`, `tasks/gdd_audit.md`  

---

## 1. MỤC TIÊU & NGUYÊN TẮC KIẾN TRÚC
1. **Kiến trúc tách rời (Decoupled Core):**
   - Toàn bộ logic bàn cờ $8 \times 8$, hệ thống tính điểm, hiệu ứng 51 lá bài, Vòng lửa sinh tử và Thánh chiến phải nằm trong `res://src/core/`.
   - Các class trong `res://src/core/` bắt buộc kế thừa `RefCounted`, không được kế thừa `Node` hay gọi UI Node để có thể chạy kiểm thử hoàn toàn độc lập (Headless).
2. **Kiểm thử tự động (Headless Test Runner):**
   - Ag2 bắt buộc tạo `res://src/core/test_runner.gd` (kế thừa `SceneTree` hoặc chạy từ CLI bằng lệnh `godot --headless -s res://src/core/test_runner.gd`).
3. **Cơ chế chống Crash (Graceful Asset Fallback):**
   - Luôn nạp Asset qua một Resource Loader tập trung. Nếu file asset SVG/PNG/Shader chưa có thật trong `assets/`, fallback về icon chữ/màu mặc định, không bao giờ để crash game.

---

## 2. CẤU TRÚC THƯ MỤC SOURCE CODE
```
res://src/
├── core/
│   ├── board_state.gd         # Trạng thái bàn cờ 8x8, ma trận quân cờ, lịch sử nước đi
│   ├── piece_data.gd          # Dữ liệu quân cờ: loại, phe, điểm (1,3,5,9,10, siêu quân 3,7,11,20), HP, buff/debuff
│   ├── move_validator.gd      # Bộ tính toán nước đi hợp lệ chuẩn FIDE + bổ trợ biến dị kỹ năng bài
│   ├── turn_manager.gd        # Máy trạng thái 4 pha: DrawPhase -> MainPhase -> MovePhase -> EndPhase
│   ├── card_engine.gd         # Quản lý bộ bài (27 lá), rút bài, rút 6 lá ban đầu, đếm 2 turn rút 1 lá
│   ├── card_database.gd       # Định nghĩa dữ liệu và hiệu ứng của 51 lá bài (31 Active + 20 Passive)
│   ├── passive_manager.gd     # Quản lý 4 ô úp bài, lắng nghe event hook để tự động trigger phản xạ
│   ├── death_ring_system.gd   # Vòng lửa sinh tử (Stalemate) & Thánh chiến (Holy War 2 Vua)
│   └── test_runner.gd         # Script Headless Unit Test tự động cho AG1 nghiệm thu
├── resources/
│   ├── card_resource.gd       # Class Resource định nghĩa thẻ bài (id, title, type, cost, target_type)
│   └── cards/                 # Lưu trữ danh mục 51 lá bài dưới dạng .tres / Data
└── scenes/
    ├── board_view.gd          # Bridge kết nối Core Engine lên giao diện Node 2D UI
    └── card_hand_view.gd      # Điều khiển hiển thị tay bài (tối đa 10 lá) và 4 ô úp bài
```

---

## 3. CƠ CHẾ DỮ LIỆU & LUẬT CHƠI CỐT LÕI

### 3.1. Điểm số & Quân cờ
- **Quân chuẩn:** Tốt (`PAWN` = 1đ), Mã (`KNIGHT` = 3đ), Tượng (`BISHOP` = 3đ), Xe (`ROOK` = 5đ), Hậu (`QUEEN` = 9đ), Vua (`KING` = 10đ).
- **Siêu quân cờ:**
  - `SUPER_PAWN` (3đ): Đi tiến, lùi, chéo 1 ô (từ 3 Tốt hợp thể).
  - `SUPER_KNIGHT` (7đ): Nhảy L-shape cộng thêm 1 ô hoặc nhảy 2 lần (từ 2 Mã hợp thể).
  - `SUPER_BISHOP` (7đ): Di chuyển đường chéo và có khả năng đổi giữa ô đen và trắng (từ 2 Tượng hợp thể).
  - `SUPER_ROOK` (11đ): Di chuyển ngang dọc chuẩn Xe + đi chéo 1 ô (từ 2 Xe hợp thể).
  - `SUPER_QUEEN` (20đ): Di chuyển như Hậu + Mã, có thể hoán đổi vị trí với bất kỳ quân nào (từ 2 Hậu hợp thể).
- **Thực thể đặc biệt:**
  - `SCARECROW` (0đ): Bù nhìn cản đường, không di chuyển, không bị tác động trừ khi bị $\ge 3$ quân vây ăn.
  - `HEAL_POINT`: Điểm hồi máu xuất hiện ngẫu nhiên trong Vòng lửa sinh tử.

### 3.2. Chu trình Turn & Giới hạn Thẻ bài
- **Bốc bài ban đầu:** Bốc 6 lá khi ván đấu bắt đầu.
- **Tần suất bốc bài:** Cứ mỗi 2 nước đi của bản thân thì bốc 1 lá.
- **Giới hạn bài trên tay:** Tối đa 10 lá. Đầy tay phải hủy hoặc skip bốc.
- **Giới hạn trong lượt thi đấu:**
  - Được dùng **tối đa 1 lá Active** trong turn của mình.
  - Được **úp tối đa 1 lá Passive** vào 1 trong 4 ô úp trên sân.
  - **Kích hoạt Passive:** Không giới hạn số lần kích hoạt trong turn (khi đối thủ kích hoạt điều kiện bẫy, mọi bài passive đủ điều kiện đều được quyền kích hoạt).

### 3.3. Checkmate Interception Hook (Cứu thua chiếu hết)
- Khi phe đối phương tung nước đi gây chiếu hết (`is_checkmate == true`):
  - **KHÔNG ĐƯỢC** kích hoạt Game Over ngay lập tức.
  - Gọi hook: `PassiveManager.trigger_checkmate_hook(player_id)`.
  - Nếu người chơi có úp cả Passive 15 (`KING_2_MOVES`) và Passive 16 (`ALL_PIECES_2_MOVES`):
    - **CHỈ KÍCH HOẠT DUY NHẤT 1 LÁ** (ưu tiên lá được úp xuống sân trước). Lá còn lại giữ nguyên trạng thái úp trên sân.
    - Cấp quyền đi 2 nước cho Vua hoặc quân cờ để hóa giải hoặc tiêu diệt đối phương.
  - Nếu không có bài úp cứu thua hoặc sau 2 nước đi vẫn không giải chiếu được thì mới Game Over.

### 3.4. Vòng lửa sinh tử & Thánh chiến (Decision B & A từ Game Designer)
- **Vòng lửa sinh tử:** Kích hoạt khi rơi vào thế Stalemate (1 trong 2 bên hết nước đi hợp lệ).
  - Đưa toàn bộ quân còn sống về vị trí ban đầu.
  - Mỗi lượt thiêu đốt điểm số của toàn bộ quân cờ bên trong.
  - Xuất hiện điểm hồi phục ngẫu nhiên (`HEAL_POINT`), tăng giới hạn di chuyển của mọi quân cờ lên 1 ô.
  - **Quy tắc phân định thắng thua (Đã chốt Decision B):** Nếu điểm về 0 mà chưa bên nào chiếu hết được, **BÊN CÓ SỐ ĐIỂM BAN ĐẦU LỚN HƠN THÌ SẼ THUA** (cơ chế đánh thuế bên chiếm ưu thế mà không dứt điểm được trận đấu).
- **Thánh chiến (Holy War - Đã chốt Decision A):**
  - Kích hoạt khi trên bàn cờ CHỈ CÒN ĐÚNG 2 VUA.
  - Mỗi lượt, Vua được quyền chọn 1 kiểu di chuyển của Xe, Mã, Tượng hoặc Hậu.
  - **PHÁ VỠ LUẬT FIDE:** 2 Vua được phép đi vào ô kiểm soát của nhau và tấn công ăn trực tiếp Vua đối phương.

### 3.5. Quy tắc Lời nguyền (Active 31 - Đã chốt)
- Nguyền rủa 1 quân cờ: Số turn đếm ngược = Số điểm của quân cờ đó (Tốt 1đ = 1 turn; Xe 5đ = 5 turn; Hậu 9đ = 9 turn).
- Sau số turn đếm ngược đó, nếu đối phương không di chuyển quân cờ này thì quân cờ bị tiêu diệt và đưa vào mộ.

---

## 4. DANH MỤC 51 LÁ BÀI (ID & TRIGGER ENGINE)

### 31 Active Cards (`ACTIVE_01` -> `ACTIVE_31`)
- `ACTIVE_01`: `DOUBLE_MOVE` - 1 quân cờ được đi 2 nước trong turn này.
- `ACTIVE_02`: `TELEPORT_PIECE` - Dịch chuyển 1 quân bất kỳ đến ô trống (ngoại trừ ô đang chiếu + trừ Hậu/Xe).
- `ACTIVE_03`: `SWAP_ALLIES` - Hoán đổi vị trí của 2 quân đồng minh.
- `ACTIVE_04`: `KING_SHIELD` - Tạo lá chắn bảo vệ Vua không thể bị chiếu trong 3 lượt tiếp theo.
- `ACTIVE_05`: `FORBIDDEN_CELLS` - Tạo 5 ô cấm di chuyển trong 2 nước đi.
- `ACTIVE_06`: `KNIGHT_LINEAR` - Di chuyển Mã theo đường thẳng trong turn này.
- `ACTIVE_07`: `ROOK_DIAGONAL` - Di chuyển Xe theo đường chéo trong turn này.
- `ACTIVE_08`: `BISHOP_KNIGHT` - Di chuyển Tượng theo bước nhảy của Mã trong turn này.
- `ACTIVE_09`: `FUSION_PAWN` - Hợp thể 3 Tốt thành 1 Siêu Tốt (tiến, lùi, chéo 1 ô).
- `ACTIVE_10`: `FUSION_KNIGHT` - Hợp thể 2 Mã thành 1 Siêu Mã (tăng thêm 1 ô nhảy).
- `ACTIVE_11`: `FUSION_ROOK` - Hợp thể 2 Xe thành 1 Siêu Xe (ngang dọc + chéo 1 ô).
- `ACTIVE_12`: `FUSION_BISHOP` - Hợp thể 2 Tượng thành 1 Siêu Tượng (đổi được màu ô).
- `ACTIVE_13`: `FUSION_QUEEN` - Hợp thể 2 Hậu thành 1 Siêu Hậu (Hậu + Mã + hoán đổi vị trí quân).
- `ACTIVE_14`: `GRAVE_SUMMON` - Triệu hồi 1 quân bất kỳ từ mộ sống lại trong 1 turn (tại 4 hàng sân nhà).
- `ACTIVE_15`: `SACRIFICE_ROOK` - Hiến tế 8 điểm quân trên sân để tạo Xe (chờ 1 turn, spawn tại A1/H1 hoặc A8/H8).
- `ACTIVE_16`: `SACRIFICE_MINOR` - Hiến tế 7 điểm quân để hồi sinh Mã hoặc Tượng (spawn tại ô xuất phát).
- `ACTIVE_17`: `SACRIFICE_QUEEN` - Hiến tế 17 điểm quân để hồi sinh Hậu (spawn tại D1 hoặc D8).
- `ACTIVE_18`: `RIVER_BARRIER` - Tạo sông ngăn cách giữa hàng 4 và hàng 5 trong turn tiếp theo, cấm quân vượt qua.
- `ACTIVE_19`: `LOCK_ROOK` - Khóa Xe đối thủ trong 2 lượt (không thể đi, không bị chỉ định hay bị ăn).
- `ACTIVE_20`: `LOCK_KNIGHT` - Khóa Mã đối thủ trong 2 lượt.
- `ACTIVE_21`: `LOCK_BISHOP` - Khóa Tượng đối thủ trong 2 lượt.
- `ACTIVE_22`: `LOCK_QUEEN` - Khóa Hậu đối thủ trong 2 lượt.
- `ACTIVE_23`: `LOCK_THREE` - Khóa 3 quân bất kỳ của đối thủ trong 1 lượt (trừ Vua).
- `ACTIVE_24`: `MUTE_PASSIVES` - Khóa toàn bộ bài Passive của đối thủ trong 2 turn.
- `ACTIVE_25`: `PAWN_EXPLOSION` - Hy sinh 1 Tốt nổ hình chữ thập (bán kính 1 ô), tiêu diệt toàn bộ quân trong phạm vi.
- `ACTIVE_26`: `IMMORTAL_PIECE` - 1 quân cờ bất tử trong 3 turn (đổi lại không thể ăn quân địch).
- `ACTIVE_27`: `SPAWN_SCARECROW` - Tạo 1 Bù nhìn (0đ) cản đường trong 3 turn hoặc đến khi bị $\ge 3$ quân địch vây ăn.
- `ACTIVE_28`: `STEALTH_TROOPS` - Tàng hình quân cờ (trừ Hậu) trong 2 turn, không bị thấy, không bị ăn và không thể ăn quân.
- `ACTIVE_29`: `CLONE_WAR` - Phân thân quân cờ (Tốt: 5, Mã/Tượng: 2, Vua: 3). Di chuyển đè quân địch sẽ Ban quân địch X round.
- `ACTIVE_30`: `GRAVITY_VORTEX` - Đặt hố đen tại hàng 4/5 hút quân trong bán kính 2 ô vào tâm; quân vào tâm bị Ban 3 turn.
- `ACTIVE_31`: `DEATH_CURSE` - Nguyền rủa 1 quân cờ; sau số turn = điểm quân cờ mà không đi thì bị tiêu diệt.

### 20 Passive Cards (`PASSIVE_01` -> `PASSIVE_20`)
- `PASSIVE_01`: `BOUNTY_10PTS` - Khi ăn đủ $\ge 10$đ quân địch, tiêu diệt ngay 1 quân $<3$đ của đối phương.
- `PASSIVE_02`: `RESURRECT_50PCT` - Khi mất $>50\%$ tổng số quân, hồi sinh 1 quân $<5$đ về bàn cờ.
- `PASSIVE_03`: `CLEANSE_DEBUFFS` - Hủy mọi hiệu ứng bất lợi đang có trên bàn cờ.
- `PASSIVE_04`: `COUNTER_ACTIVE` - Phản đòn: Hủy ngay lập tức 1 lá bài Active vừa được đối thủ tung ra.
- `PASSIVE_05`: `BARRIER_BURN` - Tạo kết giới 6 ô quanh quân địch vừa đi trong 2 lượt; mỗi lượt đốt 0.5đ, về 0đ thì chết.
- `PASSIVE_06`: `QUEEN_TETHER` - Khi Hậu đối thủ di chuyển, kéo giật cả 2 Hậu về và khóa trong 2 lượt.
- `PASSIVE_07`: `STEAL_PAWNS` - Khi toàn bộ Tốt đồng minh bị tiêu diệt, cướp 30% số Tốt còn lại của địch (làm tròn xuống).
- `PASSIVE_08`: `REWIND_CHECK` - Khi Vua bị 1 quân chiếu, buộc quân cờ vừa chiếu lùi về vị trí cũ.
- `PASSIVE_09`: `TRAP_DISARM` - Tiêu hủy toàn bộ bài Passive đang úp của đối thủ.
- `PASSIVE_10`: `DELAYED_REVIVE` - Khi lá bài úp đủ 10 vòng đấu trên sân, hồi sinh các quân từ mộ (tổng điểm $\le 4$đ).
- `PASSIVE_11`: `CHECK_VETERAN` - 1 quân cờ tích lũy đủ 10 lần chiếu Vua sẽ nhận trạng thái bất tử trong 3 turn.
- `PASSIVE_12`: `RESTART_50MOVES` - Sau 50 nước đi, nếu điểm 2 bên bằng nhau, kích hoạt chơi lại ván cờ (1 lần duy nhất).
- `PASSIVE_13`: `CASTLING_SHIFT` - Khi nhập thành, quân Vua và Xe lùi sâu vào giữa bàn cờ thêm 1 ô so với chuẩn.
- `PASSIVE_14`: `CASTLE_ESCAPE` - Khi Vua ở vị trí nhập thành bị chiếu, tẩu thoát đến ô chọn và ép đối thủ phải đi Vua lượt sau.
- `PASSIVE_15`: `CHECKMATE_KING_ESCAPE` - Khi rơi vào thế chiếu hết, Vua được đi 2 nước (kể cả ăn trực tiếp Vua đối thủ).
- `PASSIVE_16`: `CHECKMATE_ARMY_SURGE` - Khi rơi vào thế chiếu hết, mọi quân cờ được đi 2 nước (trừ ăn Vua đối thủ).
- `PASSIVE_17`: `CHAIN_BREAKER` - Nếu đối phương có 3 Tốt tạo thành đường chéo, lập tức tiêu hủy 1 con.
- `PASSIVE_18`: `FIRE_DIAGONAL` - Nếu bản thân có 3 Tốt đường chéo, tạo dải lửa; mọi quân địch bước vào bị trừ 1đ.
- `PASSIVE_19`: `POINT_REACTIVE_BUFF` - Khi dính hiệu ứng bị trừ điểm, lập tức buff +2 điểm cho toàn bộ quân đang chịu ảnh hưởng.
- `PASSIVE_20`: `RETALIATION_BAN` - Quân địch vừa ăn quân đồng minh lập tức bị Ban trục xuất trong 2 lượt tiếp theo.

---

## 5. DANH SÁCH ĐƯỜNG DẪN ASSET BẮT BUỘC KHỚP NỐI (100% MATCH VỚI ART SPEC)
Ag2 **chỉ được phép** nạp file asset theo danh sách đường dẫn chính xác tuyệt đối sau:

```gdscript
# 1. Quân cờ chuẩn
const PATH_PAWN_WHITE = "res://assets/sprites/pieces/pawn_white.svg"
const PATH_PAWN_BLACK = "res://assets/sprites/pieces/pawn_black.svg"
const PATH_KNIGHT_WHITE = "res://assets/sprites/pieces/knight_white.svg"
const PATH_KNIGHT_BLACK = "res://assets/sprites/pieces/knight_black.svg"
const PATH_BISHOP_WHITE = "res://assets/sprites/pieces/bishop_white.svg"
const PATH_BISHOP_BLACK = "res://assets/sprites/pieces/bishop_black.svg"
const PATH_ROOK_WHITE = "res://assets/sprites/pieces/rook_white.svg"
const PATH_ROOK_BLACK = "res://assets/sprites/pieces/rook_black.svg"
const PATH_QUEEN_WHITE = "res://assets/sprites/pieces/queen_white.svg"
const PATH_QUEEN_BLACK = "res://assets/sprites/pieces/queen_black.svg"
const PATH_KING_WHITE = "res://assets/sprites/pieces/king_white.svg"
const PATH_KING_BLACK = "res://assets/sprites/pieces/king_black.svg"

# 2. Siêu quân cờ & Thực thể đặc biệt
const PATH_SUPER_PAWN_WHITE = "res://assets/sprites/pieces/super_pawn_white.svg"
const PATH_SUPER_PAWN_BLACK = "res://assets/sprites/pieces/super_pawn_black.svg"
const PATH_SUPER_KNIGHT_WHITE = "res://assets/sprites/pieces/super_knight_white.svg"
const PATH_SUPER_KNIGHT_BLACK = "res://assets/sprites/pieces/super_knight_black.svg"
const PATH_SUPER_BISHOP_WHITE = "res://assets/sprites/pieces/super_bishop_white.svg"
const PATH_SUPER_BISHOP_BLACK = "res://assets/sprites/pieces/super_bishop_black.svg"
const PATH_SUPER_ROOK_WHITE = "res://assets/sprites/pieces/super_rook_white.svg"
const PATH_SUPER_ROOK_BLACK = "res://assets/sprites/pieces/super_rook_black.svg"
const PATH_SUPER_QUEEN_WHITE = "res://assets/sprites/pieces/super_queen_white.svg"
const PATH_SUPER_QUEEN_BLACK = "res://assets/sprites/pieces/super_queen_black.svg"
const PATH_SCARECROW = "res://assets/sprites/pieces/scarecrow.svg"
const PATH_HEAL_POINT = "res://assets/sprites/pieces/heal_point.svg"

# 3. Dấu ấn trạng thái
const PATH_FORBIDDEN_CELL = "res://assets/sprites/status/forbidden_cell.svg"
const PATH_CURSE_MARK = "res://assets/sprites/status/curse_mark.svg"
const PATH_LOCK_MARK = "res://assets/sprites/status/lock_mark.svg"
const PATH_SHIELD_KING = "res://assets/sprites/status/shield_king.svg"
const PATH_IMMORTAL_MARK = "res://assets/sprites/status/immortal_mark.svg"
const PATH_STEALTH_MARK = "res://assets/sprites/status/stealth_mark.svg"
const PATH_BAN_MARK = "res://assets/sprites/status/ban_mark.svg"
const PATH_CLONE_MARK = "res://assets/sprites/status/clone_mark.svg"

# 4. Thẻ bài & Khung UI
const PATH_CARD_FRAME_ACTIVE = "res://assets/sprites/cards/card_frame_active.svg"
const PATH_CARD_FRAME_PASSIVE = "res://assets/sprites/cards/card_frame_passive.svg"
const PATH_CARD_BACK = "res://assets/sprites/cards/card_back.svg"

# 5. Shaders
const PATH_SHADER_DEATH_RING = "res://assets/shaders/death_ring.gdshader"
const PATH_SHADER_RIVER_BARRIER = "res://assets/shaders/river_barrier.gdshader"
const PATH_SHADER_BARRIER_BURN = "res://assets/shaders/barrier_burn.gdshader"
const PATH_SHADER_HOLY_WAR = "res://assets/shaders/holy_war.gdshader"
const PATH_SHADER_STEALTH = "res://assets/shaders/stealth.gdshader"

# 6. Giao diện UI Scenes
const PATH_MAIN_THEME = "res://assets/ui/main_theme.tres"
const PATH_SCENE_CHESSBOARD = "res://assets/ui/chessboard.tscn"
const PATH_SCENE_CARD_UI = "res://assets/ui/card_ui.tscn"
const PATH_SCENE_PASSIVE_SLOT = "res://assets/ui/passive_slot.tscn"
const PATH_SCENE_HAND_BAR = "res://assets/ui/hand_bar.tscn"
const PATH_SCENE_COMBAT_HUD = "res://assets/ui/combat_hud.tscn"
```

---

## 6. YÊU CẦU KIỂM THỬ TỰ ĐỘNG (TEST_RUNNER.GD)
Script `res://src/core/test_runner.gd` bắt buộc phải kiểm tra và in kết quả `PASS` cho các test case sau:
1. `test_standard_fide_moves()`: Đi quân, bắt quân, tính chiếu và chiếu hết tiêu chuẩn.
2. `test_card_draw_engine()`: Rút 6 lá đầu trận; cứ 2 nước đi của bản thân thì bốc 1 lá; kịch trần 10 lá trên tay.
3. `test_turn_restrictions()`: Kiểm tra không thể đánh quá 1 Active trong turn; úp tối đa 1 Passive; không thể úp quá 4 lá trên sân.
4. `test_checkmate_hook_survival()`: Mô phỏng chiếu hết, kiểm tra hoãn kết thúc trận, trigger duy nhất 1 trong 2 lá Passive 15 hoặc 16 (ưu tiên lá úp trước), Vua đi 2 nước phản sát.
5. `test_death_ring_stalemate_resolution()`: Tạo thế Stalemate, kích hoạt Vòng lửa sinh tử, kiểm tra bên có điểm ban đầu lớn hơn bị xử thua khi hết điểm (Decision B).
6. `test_holy_war_kings_combat()`: Đưa bàn cờ về trạng thái chỉ còn 2 Vua, kiểm tra 2 Vua được phép áp sát và ăn lẫn nhau (Decision A).
7. `test_curse_countdown()`: Nguyền Xe (5đ), kiểm tra đếm ngược đúng 5 turn của đối phương và tiêu diệt Xe nếu không di chuyển.
