# res://src/core/card_database.gd
# GDScript / card_database.gd / Godot 4.7 / Core Engine
class_name CardDatabase
extends RefCounted

static var _cards: Dictionary = {}
static var _initialized: bool = false

static func get_all_cards() -> Dictionary:
	_ensure_initialized()
	return _cards

static func get_card(id: String) -> CardResource:
	_ensure_initialized()
	if _cards.has(id):
		return _cards[id]
	return null

static func get_all_card_ids() -> Array:
	_ensure_initialized()
	return _cards.keys()

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_init_database()
	_initialized = true

static func _create_card(id: String, title: String, type: CardResource.CardType, cost: int, description: String, target_type: String = "NONE", tag: String = "") -> CardResource:
	var card: CardResource = CardResource.new()
	card.id = id
	card.title = title
	card.card_type = type
	card.cost = cost
	card.description = description
	card.target_type = target_type
	card.tag = tag if tag != "" else id
	card.icon_path = "res://assets/sprites/cards/" + id.to_lower() + ".svg"
	return card

static func _init_database() -> void:
	_cards.clear()

	# 31 Active Cards
	_cards["ACTIVE_01"] = _create_card("ACTIVE_01", "Song Trùng", CardResource.CardType.ACTIVE, 0, "1 quân cờ được đi 2 nước trong turn này.", "ALLY_PIECE", "DOUBLE_MOVE")
	_cards["ACTIVE_02"] = _create_card("ACTIVE_02", "Dịch Chuyển", CardResource.CardType.ACTIVE, 0, "Dịch chuyển 1 quân bất kỳ đến ô trống (ngoại trừ ô đang chiếu + trừ Hậu và Xe).", "PIECE", "TELEPORT_PIECE")
	_cards["ACTIVE_03"] = _create_card("ACTIVE_03", "Hoán Đổi", CardResource.CardType.ACTIVE, 0, "Hoán đổi vị trí của 2 quân đồng minh.", "ALLY_PIECE", "SWAP_ALLIES")
	_cards["ACTIVE_04"] = _create_card("ACTIVE_04", "Khiên Vua", CardResource.CardType.ACTIVE, 0, "Tạo lá chắn bảo vệ Vua không thể bị chiếu trong 3 lượt tiếp theo.", "NONE", "KING_SHIELD")
	_cards["ACTIVE_05"] = _create_card("ACTIVE_05", "Vùng Cấm", CardResource.CardType.ACTIVE, 0, "Tạo 5 ô cấm di chuyển trong 2 nước đi.", "CELL", "FORBIDDEN_CELLS")
	_cards["ACTIVE_06"] = _create_card("ACTIVE_06", "Mã Xung Trận", CardResource.CardType.ACTIVE, 0, "Di chuyển Mã theo đường thẳng trong turn này.", "ALLY_PIECE", "KNIGHT_LINEAR")
	_cards["ACTIVE_07"] = _create_card("ACTIVE_07", "Chiến Xa Xiên", CardResource.CardType.ACTIVE, 0, "Di chuyển Xe theo đường chéo trong turn này.", "ALLY_PIECE", "ROOK_DIAGONAL")
	_cards["ACTIVE_08"] = _create_card("ACTIVE_08", "Tượng Phi Mã", CardResource.CardType.ACTIVE, 0, "Di chuyển Tượng theo bước nhảy của Mã trong turn này.", "ALLY_PIECE", "BISHOP_KNIGHT")
	_cards["ACTIVE_09"] = _create_card("ACTIVE_09", "Hợp Thể Tốt", CardResource.CardType.ACTIVE, 0, "Hợp thể 3 Tốt thành 1 Siêu Tốt (tiến, lùi, chéo 1 ô).", "NONE", "FUSION_PAWN")
	_cards["ACTIVE_10"] = _create_card("ACTIVE_10", "Hợp Thể Mã", CardResource.CardType.ACTIVE, 0, "Hợp thể 2 Mã thành 1 Siêu Mã (tăng thêm 1 ô nhảy).", "NONE", "FUSION_KNIGHT")
	_cards["ACTIVE_11"] = _create_card("ACTIVE_11", "Hợp Thể Xe", CardResource.CardType.ACTIVE, 0, "Hợp thể 2 Xe thành 1 Siêu Xe (ngang dọc + chéo 1 ô).", "NONE", "FUSION_ROOK")
	_cards["ACTIVE_12"] = _create_card("ACTIVE_12", "Hợp Thể Tượng", CardResource.CardType.ACTIVE, 0, "Hợp thể 2 Tượng thành 1 Siêu Tượng (đổi được màu ô).", "NONE", "FUSION_BISHOP")
	_cards["ACTIVE_13"] = _create_card("ACTIVE_13", "Hợp Thể Hậu", CardResource.CardType.ACTIVE, 0, "Hợp thể 2 Hậu thành 1 Siêu Hậu (Hậu + Mã + hoán đổi vị trí quân).", "NONE", "FUSION_QUEEN")
	_cards["ACTIVE_14"] = _create_card("ACTIVE_14", "Triệu Hồn Mộ Địa", CardResource.CardType.ACTIVE, 0, "Triệu hồi 1 quân bất kỳ từ mộ sống lại trong 1 turn (tại 4 hàng sân nhà).", "GRAVE", "GRAVE_SUMMON")
	_cards["ACTIVE_15"] = _create_card("ACTIVE_15", "Tế Đàn Chiến Xa", CardResource.CardType.ACTIVE, 0, "Hiến tế 8 điểm quân trên sân để tạo Xe (chờ 1 turn, spawn tại A1/H1 hoặc A8/H8).", "NONE", "SACRIFICE_ROOK")
	_cards["ACTIVE_16"] = _create_card("ACTIVE_16", "Tế Đàn Tướng Mã", CardResource.CardType.ACTIVE, 0, "Hiến tế 7 điểm quân để hồi sinh Mã hoặc Tượng (spawn tại ô xuất phát).", "NONE", "SACRIFICE_MINOR")
	_cards["ACTIVE_17"] = _create_card("ACTIVE_17", "Tế Đàn Nữ Hoàng", CardResource.CardType.ACTIVE, 0, "Hiến tế 17 điểm quân để hồi sinh Hậu (spawn tại D1 hoặc D8).", "NONE", "SACRIFICE_QUEEN")
	_cards["ACTIVE_18"] = _create_card("ACTIVE_18", "Dòng Sông Ngăn Cách", CardResource.CardType.ACTIVE, 0, "Tạo sông ngăn cách giữa hàng 4 và hàng 5 trong turn tiếp theo, cấm quân vượt qua.", "NONE", "RIVER_BARRIER")
	_cards["ACTIVE_19"] = _create_card("ACTIVE_19", "Xiềng Xích Xe", CardResource.CardType.ACTIVE, 0, "Khóa Xe đối thủ trong 2 lượt (không thể đi, không bị chỉ định hay bị ăn).", "ENEMY_PIECE", "LOCK_ROOK")
	_cards["ACTIVE_20"] = _create_card("ACTIVE_20", "Xiềng Xích Mã", CardResource.CardType.ACTIVE, 0, "Khóa Mã đối thủ trong 2 lượt.", "ENEMY_PIECE", "LOCK_KNIGHT")
	_cards["ACTIVE_21"] = _create_card("ACTIVE_21", "Xiềng Xích Tượng", CardResource.CardType.ACTIVE, 0, "Khóa Tượng đối thủ trong 2 lượt.", "ENEMY_PIECE", "LOCK_BISHOP")
	_cards["ACTIVE_22"] = _create_card("ACTIVE_22", "Xiềng Xích Hậu", CardResource.CardType.ACTIVE, 0, "Khóa Hậu đối thủ trong 2 lượt.", "ENEMY_PIECE", "LOCK_QUEEN")
	_cards["ACTIVE_23"] = _create_card("ACTIVE_23", "Tam Trùng Tỏa", CardResource.CardType.ACTIVE, 0, "Khóa 3 quân bất kỳ của đối thủ trong 1 lượt (trừ Vua).", "NONE", "LOCK_THREE")
	_cards["ACTIVE_24"] = _create_card("ACTIVE_24", "Câm Lặng Bẫy", CardResource.CardType.ACTIVE, 0, "Khóa toàn bộ bài Passive của đối thủ trong 2 turn.", "NONE", "MUTE_PASSIVES")
	_cards["ACTIVE_25"] = _create_card("ACTIVE_25", "Tốt Bộc Phá", CardResource.CardType.ACTIVE, 0, "Hy sinh 1 Tốt nổ hình chữ thập (bán kính 1 ô), tiêu diệt toàn bộ quân trong phạm vi.", "ALLY_PIECE", "PAWN_EXPLOSION")
	_cards["ACTIVE_26"] = _create_card("ACTIVE_26", "Thân Thể Kim Cương", CardResource.CardType.ACTIVE, 0, "1 quân cờ bất tử trong 3 turn (đổi lại không thể ăn quân địch).", "ALLY_PIECE", "IMMORTAL_PIECE")
	_cards["ACTIVE_27"] = _create_card("ACTIVE_27", "Bù Nhìn Thế Thân", CardResource.CardType.ACTIVE, 0, "Tạo 1 Bù nhìn (0đ) cản đường trong 3 turn hoặc đến khi bị >= 3 quân địch vây ăn.", "CELL", "SPAWN_SCARECROW")
	_cards["ACTIVE_28"] = _create_card("ACTIVE_28", "Bóng Ma Chiến Trường", CardResource.CardType.ACTIVE, 0, "Tàng hình quân cờ (trừ Hậu) trong 2 turn, không bị thấy, không bị ăn và không thể ăn quân.", "ALLY_PIECE", "STEALTH_TROOPS")
	_cards["ACTIVE_29"] = _create_card("ACTIVE_29", "Phân Thân Thuật", CardResource.CardType.ACTIVE, 0, "Phân thân quân cờ (Tốt: 5, Mã/Tượng: 2, Vua: 3). Di chuyển đè quân địch sẽ Ban quân địch X round.", "ALLY_PIECE", "CLONE_WAR")
	_cards["ACTIVE_30"] = _create_card("ACTIVE_30", "Hố Đen Trọng Lực", CardResource.CardType.ACTIVE, 0, "Đặt hố đen tại hàng 4/5 hút quân trong bán kính 2 ô vào tâm; quân vào tâm bị Ban 3 turn.", "CELL", "GRAVITY_VORTEX")
	_cards["ACTIVE_31"] = _create_card("ACTIVE_31", "Lời Nguyền Tử Vong", CardResource.CardType.ACTIVE, 0, "Nguyền rủa 1 quân cờ; sau số turn = điểm quân cờ mà không đi thì bị tiêu diệt.", "ENEMY_PIECE", "DEATH_CURSE")

	# 20 Passive Cards
	_cards["PASSIVE_01"] = _create_card("PASSIVE_01", "Chiến Tích Thập Điểm", CardResource.CardType.PASSIVE, 0, "Khi ăn đủ >= 10đ quân địch, tiêu diệt ngay 1 quân <3đ của đối phương.", "NONE", "BOUNTY_10PTS")
	_cards["PASSIVE_02"] = _create_card("PASSIVE_02", "Bất Khuất Trùng Sinh", CardResource.CardType.PASSIVE, 0, "Khi mất >50% tổng số quân, hồi sinh 1 quân <5đ về bàn cờ.", "NONE", "RESURRECT_50PCT")
	_cards["PASSIVE_03"] = _create_card("PASSIVE_03", "Thanh Tẩy Khí Lực", CardResource.CardType.PASSIVE, 0, "Hủy mọi hiệu ứng bất lợi đang có trên bàn cờ.", "NONE", "CLEANSE_DEBUFFS")
	_cards["PASSIVE_04"] = _create_card("PASSIVE_04", "Phản Đòn Pháp Trận", CardResource.CardType.PASSIVE, 0, "Phản đòn: Hủy ngay lập tức 1 lá bài Active vừa được đối thủ tung ra.", "NONE", "COUNTER_ACTIVE")
	_cards["PASSIVE_05"] = _create_card("PASSIVE_05", "Kết Giới Thiêu Đốt", CardResource.CardType.PASSIVE, 0, "Tạo kết giới 6 ô quanh quân địch vừa đi trong 2 lượt; mỗi lượt đốt 0.5đ, về 0đ thì chết.", "NONE", "BARRIER_BURN")
	_cards["PASSIVE_06"] = _create_card("PASSIVE_06", "Nữ Hoàng Khóa Chân", CardResource.CardType.PASSIVE, 0, "Khi Hậu đối thủ di chuyển, kéo giật cả 2 Hậu về và khóa trong 2 lượt.", "NONE", "QUEEN_TETHER")
	_cards["PASSIVE_07"] = _create_card("PASSIVE_07", "Đoạt Tốt Trận Huyết", CardResource.CardType.PASSIVE, 0, "Khi toàn bộ Tốt đồng minh bị tiêu diệt, cướp 30% số Tốt còn lại của địch (làm tròn xuống).", "NONE", "STEAL_PAWNS")
	_cards["PASSIVE_08"] = _create_card("PASSIVE_08", "Đảo Nghịch Thời Gian", CardResource.CardType.PASSIVE, 0, "Khi Vua bị 1 quân chiếu, buộc quân cờ vừa chiếu lùi về vị trí cũ.", "NONE", "REWIND_CHECK")
	_cards["PASSIVE_09"] = _create_card("PASSIVE_09", "Phá Hủy Cạm Bẫy", CardResource.CardType.PASSIVE, 0, "Tiêu hủy toàn bộ bài Passive đang úp của đối thủ.", "NONE", "TRAP_DISARM")
	_cards["PASSIVE_10"] = _create_card("PASSIVE_10", "Thập Trận Vọng Hồn", CardResource.CardType.PASSIVE, 0, "Khi lá bài úp đủ 10 vòng đấu trên sân, hồi sinh các quân từ mộ (tổng điểm <= 4đ).", "NONE", "DELAYED_REVIVE")
	_cards["PASSIVE_11"] = _create_card("PASSIVE_11", "Kỳ Thủ Lão Luyện", CardResource.CardType.PASSIVE, 0, "1 quân cờ tích lũy đủ 10 lần chiếu Vua sẽ nhận trạng thái bất tử trong 3 turn.", "NONE", "CHECK_VETERAN")
	_cards["PASSIVE_12"] = _create_card("PASSIVE_12", "Ngũ Thập Luân Hồi", CardResource.CardType.PASSIVE, 0, "Sau 50 nước đi, nếu điểm 2 bên bằng nhau, kích hoạt chơi lại ván cờ (1 lần duy nhất).", "NONE", "RESTART_50MOVES")
	_cards["PASSIVE_13"] = _create_card("PASSIVE_13", "Nhập Thành Thiên Uyển", CardResource.CardType.PASSIVE, 0, "Khi nhập thành, quân Vua và Xe lùi sâu vào giữa bàn cờ thêm 1 ô so với chuẩn.", "NONE", "CASTLING_SHIFT")
	_cards["PASSIVE_14"] = _create_card("PASSIVE_14", "Thoát Hiểm Hoàng Cung", CardResource.CardType.PASSIVE, 0, "Khi Vua ở vị trí nhập thành bị chiếu, tẩu thoát đến ô chọn và ép đối thủ phải đi Vua lượt sau.", "NONE", "CASTLE_ESCAPE")
	_cards["PASSIVE_15"] = _create_card("PASSIVE_15", "Vua Nghịch Cảnh Phá Vây", CardResource.CardType.PASSIVE, 0, "Khi rơi vào thế chiếu hết, Vua được đi 2 nước (kể cả ăn trực tiếp Vua đối thủ).", "NONE", "CHECKMATE_KING_ESCAPE")
	_cards["PASSIVE_16"] = _create_card("PASSIVE_16", "Toàn Quân Phản Kích", CardResource.CardType.PASSIVE, 0, "Khi rơi vào thế chiếu hết, mọi quân cờ được đi 2 nước (trừ ăn Vua đối thủ).", "NONE", "CHECKMATE_ARMY_SURGE")
	_cards["PASSIVE_17"] = _create_card("PASSIVE_17", "Đoạn Tuyệt Liên Hoàn", CardResource.CardType.PASSIVE, 0, "Nếu đối phương có 3 Tốt tạo thành đường chéo, lập tức tiêu hủy 1 con.", "NONE", "CHAIN_BREAKER")
	_cards["PASSIVE_18"] = _create_card("PASSIVE_18", "Hỏa Diễm Tam Điểm", CardResource.CardType.PASSIVE, 0, "Nếu bản thân có 3 Tốt đường chéo, tạo dải lửa; mọi quân địch bước vào bị trừ 1đ.", "NONE", "FIRE_DIAGONAL")
	_cards["PASSIVE_19"] = _create_card("PASSIVE_19", "Cộng Hưởng Bộc Phá", CardResource.CardType.PASSIVE, 0, "Khi dính hiệu ứng bị trừ điểm, lập tức buff +2 điểm cho toàn bộ quân đang chịu ảnh hưởng.", "NONE", "POINT_REACTIVE_BUFF")
	_cards["PASSIVE_20"] = _create_card("PASSIVE_20", "Truy Hồn Trục Xuất", CardResource.CardType.PASSIVE, 0, "Quân địch vừa ăn quân đồng minh lập tức bị Ban trục xuất trong 2 lượt tiếp theo.", "NONE", "RETALIATION_BAN")
