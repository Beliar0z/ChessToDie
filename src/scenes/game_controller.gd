# res://src/scenes/game_controller.gd
# GDScript / game_controller.gd / Godot 4.7 / UI Orchestrator
class_name GameController
extends Control

var turn_manager: TurnManager
var board_view: BoardView
var card_hand_view: CardHandView

var chessboard_node: Control
var hand_container: Control
var deck_slot: Control
var deck_label: Label

var player_active_slot: Control
var opponent_active_slot: Control
var player_passive_row: Control
var opponent_passive_row: Control

var opponent_hand_container: Control
var opponent_hand_label: Label

var player_score_label: Label
var opponent_score_label: Label
var turn_phase_label: Label
var message_banner: Label
var end_turn_button: Button

var selected_card: CardResource = null
var is_targeting_card: bool = false

# Multi-step targeting state
var targeting_card: CardResource = null
var targeting_is_passive: bool = false
var targeting_passive_slot_index: int = -1
var targeting_steps: Array[Dictionary] = []
var current_targeting_step_index: int = 0
var collected_targets: Array = []
var current_step_valid_cells: Array[Vector2i] = []

const CARD_UI_SCENE_PATH: String = "res://assets/ui/card_ui.tscn"
const FRAME_ACTIVE_PATH: String = "res://assets/sprites/cards/card_frame_active.svg"
const FRAME_PASSIVE_PATH: String = "res://assets/sprites/cards/card_frame_passive.svg"
const CARD_BACK_PATH: String = "res://assets/sprites/cards/card_back.svg"
const DECK_PILE_PATH: String = "res://assets/sprites/cards/deck_pile.svg"

const SHADER_DEATH_RING: String = "res://assets/shaders/death_ring.gdshader"
const SHADER_RIVER_BARRIER: String = "res://assets/shaders/river_barrier.gdshader"
const SHADER_BARRIER_BURN: String = "res://assets/shaders/barrier_burn.gdshader"
const SHADER_HOLY_WAR: String = "res://assets/shaders/holy_war.gdshader"
const SHADER_STEALTH: String = "res://assets/shaders/stealth.gdshader"

func _ready() -> void:
	custom_minimum_size = Vector2(1920.0, 1080.0)
	setup_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_card_selection()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if is_targeting_card or selected_card != null:
			_cancel_card_selection()

func setup_game() -> void:
	if turn_manager == null:
		turn_manager = TurnManager.new()
		turn_manager.start_game()

	_ensure_ui_structure()
	_connect_signals()
	_update_all_ui()

func _ensure_ui_structure() -> void:
	chessboard_node = find_child("Chessboard", true, false) as Control
	if chessboard_node != null:
		board_view = chessboard_node.get_node_or_null("BoardViewComponent") as BoardView
		if board_view == null:
			board_view = BoardView.new()
			board_view.name = "BoardViewComponent"
			board_view.set_anchors_preset(PRESET_FULL_RECT)
			chessboard_node.add_child(board_view)

		var tiles_grid: GridContainer = chessboard_node.find_child("TilesGrid", true, false) as GridContainer
		board_view.setup(turn_manager, tiles_grid)

	hand_container = find_child("HandContainer", true, false) as Control
	if hand_container != null:
		card_hand_view = hand_container.get_node_or_null("CardHandViewComponent") as CardHandView
		if card_hand_view == null:
			card_hand_view = CardHandView.new()
			card_hand_view.name = "CardHandViewComponent"
			card_hand_view.set_anchors_preset(PRESET_FULL_RECT)
			hand_container.add_child(card_hand_view)
		card_hand_view.setup(turn_manager, turn_manager.current_turn_team)

	deck_slot = find_child("DeckSlot", true, false) as Control
	deck_label = find_child("DeckLabel", true, false) as Label

	opponent_score_label = find_child("OpponentScoreLabel", true, false) as Label
	opponent_passive_row = find_child("OpponentPassiveRow", true, false) as Control
	opponent_active_slot = find_child("OpponentActiveSlot", true, false) as Control

	turn_phase_label = find_child("TurnPhaseLabel", true, false) as Label
	message_banner = find_child("MessageBanner", true, false) as Label
	end_turn_button = find_child("EndTurnButton", true, false) as Button

	player_active_slot = find_child("PlayerActiveSlot", true, false) as Control
	player_passive_row = find_child("PlayerPassiveRow", true, false) as Control
	player_score_label = find_child("PlayerScoreLabel", true, false) as Label

	_ensure_opponent_hand_ui()

	_bind_active_slot(player_active_slot, PieceData.Team.WHITE)
	_bind_active_slot(opponent_active_slot, PieceData.Team.BLACK)
	_bind_passive_row(player_passive_row, PieceData.Team.WHITE)
	_bind_passive_row(opponent_passive_row, PieceData.Team.BLACK)

func _ensure_opponent_hand_ui() -> void:
	var top_zone: Control = find_child("TopPlayerZone", true, false) as Control
	if top_zone == null:
		return

	opponent_hand_container = top_zone.find_child("OpponentHandContainer", true, false) as Control
	opponent_hand_label = top_zone.find_child("OpponentHandLabel", true, false) as Label

	if opponent_hand_container == null:
		var hand_area: Control = Control.new()
		hand_area.name = "OpponentHandArea"
		hand_area.position = Vector2(20.0, 0.0)
		hand_area.custom_minimum_size = Vector2(520.0, 110.0)
		hand_area.size = Vector2(520.0, 110.0)
		top_zone.add_child(hand_area)

		opponent_hand_label = Label.new()
		opponent_hand_label.name = "OpponentHandLabel"
		opponent_hand_label.position = Vector2(0.0, 0.0)
		opponent_hand_label.custom_minimum_size = Vector2(400.0, 24.0)
		opponent_hand_label.add_theme_font_size_override("font_size", 16)
		opponent_hand_label.text = "TAY BÀI ĐỐI THỦ: 0 LÁ"
		hand_area.add_child(opponent_hand_label)

		opponent_hand_container = Control.new()
		opponent_hand_container.name = "OpponentHandContainer"
		opponent_hand_container.position = Vector2(0.0, 26.0)
		opponent_hand_container.custom_minimum_size = Vector2(520.0, 84.0)
		opponent_hand_container.size = Vector2(520.0, 84.0)
		hand_area.add_child(opponent_hand_container)

func _bind_active_slot(slot: Control, team: PieceData.Team) -> void:
	if slot == null:
		return
	var catcher: SlotDropCatcher = slot.get_node_or_null("DropCatcher") as SlotDropCatcher
	if catcher == null:
		catcher = SlotDropCatcher.new()
		catcher.name = "DropCatcher"
		catcher.set_anchors_preset(PRESET_FULL_RECT)
		catcher.slot_type = "active"
		catcher.team = team
		catcher.controller = self
		slot.add_child(catcher)

func _bind_passive_row(row: Control, team: PieceData.Team) -> void:
	if row == null:
		return
	for i in range(row.get_child_count()):
		var slot: Control = row.get_child(i) as Control
		var catcher: SlotDropCatcher = slot.get_node_or_null("DropCatcher") as SlotDropCatcher
		if catcher == null:
			catcher = SlotDropCatcher.new()
			catcher.name = "DropCatcher"
			catcher.set_anchors_preset(PRESET_FULL_RECT)
			catcher.slot_type = "passive"
			catcher.slot_index = i
			catcher.team = team
			catcher.controller = self
			slot.add_child(catcher)

func _connect_signals() -> void:
	if board_view != null:
		if not board_view.tile_clicked.is_connected(_on_tile_clicked):
			board_view.tile_clicked.connect(_on_tile_clicked)
		if not board_view.move_executed.is_connected(_on_move_executed):
			board_view.move_executed.connect(_on_move_executed)
		if not board_view.card_dropped_on_tile.is_connected(_on_card_dropped_on_tile):
			board_view.card_dropped_on_tile.connect(_on_card_dropped_on_tile)
		if board_view.has_signal("tile_right_clicked"):
			if not board_view.tile_right_clicked.is_connected(_on_tile_right_clicked):
				board_view.tile_right_clicked.connect(_on_tile_right_clicked)

	if card_hand_view != null:
		if not card_hand_view.card_selected.is_connected(_on_card_selected):
			card_hand_view.card_selected.connect(_on_card_selected)
		if not card_hand_view.card_deselected.is_connected(_on_card_deselected):
			card_hand_view.card_deselected.connect(_on_card_deselected)

	if end_turn_button != null and not end_turn_button.pressed.is_connected(_on_end_turn_button_pressed):
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)

	if deck_slot != null and deck_slot is Button and not (deck_slot as Button).pressed.is_connected(_on_deck_slot_clicked):
		(deck_slot as Button).pressed.connect(_on_deck_slot_clicked)

# -------------------------------------------------------------
# Interactions & Targeting
# -------------------------------------------------------------

func _cancel_card_selection(clear_msg: bool = true) -> void:
	selected_card = null
	is_targeting_card = false
	targeting_card = null
	targeting_is_passive = false
	targeting_passive_slot_index = -1
	targeting_steps.clear()
	collected_targets.clear()
	current_step_valid_cells.clear()

	if card_hand_view != null:
		card_hand_view.deselect_card()
	if board_view != null:
		board_view.clear_highlights()
	if clear_msg:
		show_message("")

func _on_tile_right_clicked(_pos: Vector2i) -> void:
	if is_targeting_card or selected_card != null:
		_cancel_card_selection()

func _on_tile_clicked(pos: Vector2i) -> void:
	if is_targeting_card:
		_process_targeting_tile_click(pos)
		return

	if selected_card != null and selected_card.is_active():
		_try_cast_active_card(selected_card, pos)
		return

	if board_view != null:
		board_view.select_cell(pos)
	_update_all_ui()

func _on_card_dropped_on_tile(card: CardResource, pos: Vector2i) -> void:
	if card == null or not card.is_active():
		show_message("LÁ PASSIVE PHẢI THẢ VÀO 4 Ô TRAP SLOT BÊN PHẢI!")
		return
	_try_cast_active_card(card, pos)

func _try_cast_active_card(card: CardResource, target_pos: Vector2i = Vector2i(-1, -1)) -> void:
	var engine: CardEngine = turn_manager.get_current_engine()
	if engine.actives_used_this_turn >= 1:
		_cancel_card_selection(false)
		show_message("MỖI LƯỢT CHỈ ĐƯỢC DÙNG 1 LÁ ACTIVE!")
		return

	start_targeting(card, false, -1, target_pos)

func _on_move_executed(_from_pos: Vector2i, _to_pos: Vector2i) -> void:
	_update_all_ui()
	_check_reaction_window()

func _check_reaction_window() -> void:
	if turn_manager != null and turn_manager.passive_manager.has_ready_trigger(PieceData.Team.WHITE):
		show_message("BẪY ĐỦ ĐIỀU KIỆN — BẤM VÀO LÁ BÀI PHÁT SÁNG ĐỂ KÍCH HOẠT!")
		_update_all_ui()
		await get_tree().create_timer(2.0).timeout
		if turn_manager != null and turn_manager.passive_manager != null:
			turn_manager.passive_manager.clear_expired_triggers()
		_update_all_ui()

func _on_card_selected(card: CardResource) -> void:
	selected_card = card
	if card.is_active():
		show_message("ĐANG CHỌN [%s]: Kéo thả vào ACTIVE SLOT hoặc chọn mục tiêu!" % card.title)
	else:
		show_message("ĐANG CHỌN [%s]: Kéo thả hoặc bấm vào 1 trong 4 ô PASSIVE SLOT để úp!" % card.title)

func _on_card_deselected(_card: CardResource) -> void:
	selected_card = null
	if not is_targeting_card:
		show_message("")

func handle_active_slot_action(team: PieceData.Team, dropped_card: CardResource = null) -> void:
	if team != turn_manager.current_turn_team:
		show_message("CHỈ ĐƯỢC DÙNG Ô CỦA PHE MÌNH!")
		return
	var card_to_use: CardResource = dropped_card if dropped_card != null else selected_card
	if card_to_use == null or not card_to_use.is_active():
		show_message("HÃY CHỌN HOẶC KÉO 1 LÁ BÀI [ACTIVE] VÀO ĐÂY!")
		return

	var engine: CardEngine = turn_manager.get_current_engine()
	if engine.actives_used_this_turn >= 1:
		_cancel_card_selection(false)
		show_message("MỖI LƯỢT CHỈ ĐƯỢC DÙNG 1 LÁ ACTIVE!")
		return

	var sel_cell: Vector2i = board_view.selected_cell if board_view != null else Vector2i(-1, -1)
	start_targeting(card_to_use, false, -1, sel_cell)

func handle_passive_slot_action(team: PieceData.Team, slot_index: int, dropped_card: CardResource = null) -> void:
	var slots: Array[Dictionary] = turn_manager.passive_manager.get_slots(team)

	# 1. Click vào ô đã có bài úp
	if slot_index < slots.size() and slots[slot_index].get("card") != null:
		var slot_data: Dictionary = slots[slot_index]
		if slot_data.get("is_ready_to_trigger", false):
			_activate_passive_trigger(team, slot_index)
			return
		else:
			show_message("LÁ BẪY NÀY CHƯA ĐỦ ĐIỀU KIỆN KÍCH HOẠT!")
			return

	# 2. Úp bài Passive từ tay vào ô trống
	if team != turn_manager.current_turn_team:
		show_message("CHỈ ĐƯỢC ÚP VÀO Ô PASSIVE CỦA PHE MÌNH!")
		return

	var card_to_use: CardResource = dropped_card if dropped_card != null else selected_card
	if card_to_use == null or card_to_use.is_active():
		show_message("HÃY CHỌN HOẶC KÉO 1 LÁ BÀI [PASSIVE] VÀO ĐÂY!")
		return

	var engine: CardEngine = turn_manager.get_current_engine()
	if not engine.can_place_passive(card_to_use):
		show_message("LƯỢT NÀY BẠN ĐÃ ÚP 1 LÁ PASSIVE RỒI!")
		return

	var ok: bool = turn_manager.place_passive_card(card_to_use)
	if ok:
		show_message("ĐÃ ÚP 1 LÁ PASSIVE: %s!" % card_to_use.title)
		_cancel_card_selection()
		_update_all_ui()
	else:
		show_message("KHÔNG THỂ ÚP BÀI PASSIVE!")

func _activate_passive_trigger(team: PieceData.Team, slot_index: int) -> void:
	var slots: Array[Dictionary] = turn_manager.passive_manager.get_slots(team)
	if slot_index >= slots.size():
		return
	var card: CardResource = slots[slot_index].get("card", null) as CardResource
	if card == null:
		return

	if card.id == "PASSIVE_01" or card.id == "PASSIVE_02" or card.id == "PASSIVE_14":
		start_targeting(card, true, slot_index)
		return

	var res: Dictionary = turn_manager.execute_passive_trigger(team, slot_index)
	if res.get("success", false):
		show_message("ĐÃ KÍCH HOẠT BẪY: %s!" % card.title)
		_cancel_card_selection()
		_update_all_ui()

func _on_deck_slot_clicked() -> void:
	if turn_manager == null:
		return
	var engine: CardEngine = turn_manager.get_current_engine()
	show_message("CỌC BÀI RÚT CÒN %d LÁ (MỖI 2 NƯỚC ĐI TỰ RÚT 1 LÁ)" % engine.deck.size())

func _on_end_turn_button_pressed() -> void:
	_cancel_card_selection()
	if board_view != null:
		board_view.deselect()
	turn_manager.end_turn()
	_update_all_ui()

# -------------------------------------------------------------
# Targeting System Engine
# -------------------------------------------------------------

func start_targeting(card: CardResource, is_passive: bool = false, slot_index: int = -1, initial_target: Vector2i = Vector2i(-1, -1)) -> void:
	targeting_card = card
	targeting_is_passive = is_passive
	targeting_passive_slot_index = slot_index
	collected_targets.clear()
	current_targeting_step_index = 0
	targeting_steps = _build_targeting_steps_for_card(card)

	if targeting_steps.is_empty():
		_finish_targeting()
		return

	is_targeting_card = true

	# Nếu đã click sẵn 1 ô hợp lệ từ trước, thử nạp luôn vào step 0
	if initial_target != Vector2i(-1, -1):
		var step0: Dictionary = targeting_steps[0]
		var valids: Array[Vector2i] = _get_valid_cells_for_step(step0)
		if valids.has(initial_target):
			collected_targets.append(initial_target)
			current_targeting_step_index += 1
			if current_targeting_step_index >= targeting_steps.size():
				_finish_targeting()
				return

	_apply_current_targeting_step()

func _build_targeting_steps_for_card(card: CardResource) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	match card.id:
		"ACTIVE_01": # Song Trùng
			steps.append({"prompt": "CHỌN 1 QUÂN ĐỒNG MINH ĐỂ ĐI 2 NƯỚC", "type": "ALLY_PIECE"})
		"ACTIVE_02": # Dịch Chuyển
			steps.append({"prompt": "CHỌN QUÂN ĐỂ DỊCH CHUYỂN (TRỪ HẬU & XE)", "type": "PIECE_NO_QUEEN_ROOK"})
			steps.append({"prompt": "CHỌN Ô TRỐNG ĐÍCH ĐẾN", "type": "EMPTY_CELL"})
		"ACTIVE_03": # Hoán Đổi
			steps.append({"prompt": "CHỌN QUÂN ĐỒNG MINH 1/2", "type": "ALLY_PIECE"})
			steps.append({"prompt": "CHỌN QUÂN ĐỒNG MINH 2/2", "type": "ALLY_PIECE_OTHER"})
		"ACTIVE_04", "ACTIVE_18", "ACTIVE_24": # Không cần target
			pass
		"ACTIVE_05": # 5 Ô Cấm
			for i in range(5):
				steps.append({"prompt": "CHỌN Ô CẤM %d/5" % [i + 1], "type": "ANY_CELL"})
		"ACTIVE_06": # Mã Xung Trận
			steps.append({"prompt": "CHỌN MÃ ĐỒNG MINH ĐI ĐƯỜNG THẲNG", "type": "ALLY_KNIGHT"})
		"ACTIVE_07": # Chiến Xa Xiên
			steps.append({"prompt": "CHỌN XE ĐỒNG MINH ĐI ĐƯỜNG CHÉO", "type": "ALLY_ROOK"})
		"ACTIVE_08": # Tượng Phi Mã
			steps.append({"prompt": "CHỌN TƯỢNG ĐỒNG MINH ĐI BƯỚC MÃ", "type": "ALLY_BISHOP"})
		"ACTIVE_09": # Hợp thể 3 Tốt
			steps.append({"prompt": "CHỌN TỐT 1/3 HỢP THỂ", "type": "ALLY_PAWN"})
			steps.append({"prompt": "CHỌN TỐT 2/3 HỢP THỂ", "type": "ALLY_PAWN_OTHER"})
			steps.append({"prompt": "CHỌN TỐT 3/3 HỢP THỂ", "type": "ALLY_PAWN_OTHER"})
			steps.append({"prompt": "CHỌN Ô TRỐNG SÂN NHÀ SPAWN SIÊU TỐT", "type": "HOME_EMPTY_CELL"})
		"ACTIVE_10": # Hợp thể 2 Mã
			steps.append({"prompt": "CHỌN MÃ 1/2 HỢP THỂ", "type": "ALLY_KNIGHT"})
			steps.append({"prompt": "CHỌN MÃ 2/2 HỢP THỂ", "type": "ALLY_KNIGHT_OTHER"})
			steps.append({"prompt": "CHỌN Ô TRỐNG SÂN NHÀ SPAWN SIÊU MÃ", "type": "HOME_EMPTY_CELL"})
		"ACTIVE_11": # Hợp thể 2 Xe
			steps.append({"prompt": "CHỌN XE 1/2 HỢP THỂ", "type": "ALLY_ROOK"})
			steps.append({"prompt": "CHỌN XE 2/2 HỢP THỂ", "type": "ALLY_ROOK_OTHER"})
			steps.append({"prompt": "CHỌN Ô TRỐNG SÂN NHÀ SPAWN SIÊU XE", "type": "HOME_EMPTY_CELL"})
		"ACTIVE_12": # Hợp thể 2 Tượng
			steps.append({"prompt": "CHỌN TƯỢNG 1/2 HỢP THỂ", "type": "ALLY_BISHOP"})
			steps.append({"prompt": "CHỌN TƯỢNG 2/2 HỢP THỂ", "type": "ALLY_BISHOP_OTHER"})
			steps.append({"prompt": "CHỌN Ô TRỐNG SÂN NHÀ SPAWN SIÊU TƯỢNG", "type": "HOME_EMPTY_CELL"})
		"ACTIVE_13": # Hợp thể 2 Hậu
			steps.append({"prompt": "CHỌN HẬU 1/2 HỢP THỂ", "type": "ALLY_QUEEN"})
			steps.append({"prompt": "CHỌN HẬU 2/2 HỢP THỂ", "type": "ALLY_QUEEN_OTHER"})
			steps.append({"prompt": "CHỌN Ô TRỐNG SÂN NHÀ SPAWN SIÊU HẬU", "type": "HOME_EMPTY_CELL"})
		"ACTIVE_14": # Triệu hồi mộ
			steps.append({"prompt": "CHỌN Ô TRỐNG SÂN NHÀ ĐỂ TRIỆU HỒI TỪ MỘ", "type": "HOME_EMPTY_CELL"})
		"ACTIVE_15", "ACTIVE_16", "ACTIVE_17": # Tế đàn
			var req: int = 8 if card.id == "ACTIVE_15" else (7 if card.id == "ACTIVE_16" else 17)
			steps.append({"prompt": "CHỌN CÁC QUÂN ĐỒNG MINH ĐỂ HIẾN TẾ (CẦN %d ĐIỂM)" % req, "type": "SACRIFICE", "req_points": req})
		"ACTIVE_19": # Khóa Xe
			steps.append({"prompt": "CHỌN XE ĐỐI THỦ ĐỂ KHÓA", "type": "ENEMY_ROOK"})
		"ACTIVE_20": # Khóa Mã
			steps.append({"prompt": "CHỌN MÃ ĐỐI THỦ ĐỂ KHÓA", "type": "ENEMY_KNIGHT"})
		"ACTIVE_21": # Khóa Tượng
			steps.append({"prompt": "CHỌN TƯỢNG ĐỐI THỦ ĐỂ KHÓA", "type": "ENEMY_BISHOP"})
		"ACTIVE_22": # Khóa Hậu
			steps.append({"prompt": "CHỌN HẬU ĐỐI THỦ ĐỂ KHÓA", "type": "ENEMY_QUEEN"})
		"ACTIVE_23": # Tam trùng tỏa
			steps.append({"prompt": "CHỌN QUÂN ĐỊCH 1/3 (TRỪ VUA)", "type": "ENEMY_NON_KING"})
			steps.append({"prompt": "CHỌN QUÂN ĐỊCH 2/3", "type": "ENEMY_NON_KING"})
			steps.append({"prompt": "CHỌN QUÂN ĐỊCH 3/3", "type": "ENEMY_NON_KING"})
		"ACTIVE_25": # Tốt bộc phá
			steps.append({"prompt": "CHỌN TỐT ĐỒNG MINH ĐỂ KÍCH NỔ", "type": "ALLY_PAWN"})
		"ACTIVE_26": # Thân thể kim cương
			steps.append({"prompt": "CHỌN QUÂN ĐỒNG MINH BẤT TỬ (3 TURN)", "type": "ALLY_PIECE"})
		"ACTIVE_27": # Bù nhìn
			steps.append({"prompt": "CHỌN Ô TRỐNG ĐẶT BÙ NHÌN", "type": "EMPTY_CELL"})
		"ACTIVE_28": # Bóng ma chiến trường
			steps.append({"prompt": "CHỌN QUÂN ĐỒNG MINH 1/2 TÀNG HÌNH", "type": "ALLY_NON_QUEEN"})
			steps.append({"prompt": "CHỌN QUÂN ĐỒNG MINH 2/2 TÀNG HÌNH", "type": "ALLY_NON_QUEEN"})
		"ACTIVE_29": # Phân thân thuật
			steps.append({"prompt": "CHỌN QUÂN ĐỒNG MINH MUỐN PHÂN THÂN", "type": "ALLY_PIECE"})
		"ACTIVE_30": # Hố đen
			steps.append({"prompt": "CHỌN Ô ĐẶT HỐ ĐEN TẠI HÀNG 4 HOẶC 5", "type": "RANK_4_5"})
		"ACTIVE_31": # Lời nguyền
			steps.append({"prompt": "CHỌN QUÂN ĐỊCH ĐỂ ÁP LỜI NGUYỄN", "type": "ENEMY_PIECE"})

		# Passives
		"PASSIVE_01":
			steps.append({"prompt": "CHỌN QUÂN ĐỊCH (<3 ĐIỂM) ĐỂ TIÊU DIỆT", "type": "ENEMY_UNDER_3PTS"})
		"PASSIVE_02":
			steps.append({"prompt": "CHỌN Ô TRỐNG SÂN NHÀ HỒI SINH QUÂN (<5 ĐIỂM)", "type": "HOME_EMPTY_CELL"})
		"PASSIVE_14":
			steps.append({"prompt": "CHỌN Ô TRỐNG CHO VUA TẨU THOÁT", "type": "EMPTY_CELL"})

	return steps

func _get_valid_cells_for_step(step: Dictionary) -> Array[Vector2i]:
	var valids: Array[Vector2i] = []
	if turn_manager == null or turn_manager.board == null:
		return valids

	var board: BoardState = turn_manager.board
	var cur_team: PieceData.Team = turn_manager.current_turn_team
	var opp_team: PieceData.Team = PieceData.Team.BLACK if cur_team == PieceData.Team.WHITE else PieceData.Team.WHITE
	var stype: String = step.get("type", "")

	for y in range(BoardState.BOARD_SIZE):
		for x in range(BoardState.BOARD_SIZE):
			var pos: Vector2i = Vector2i(x, y)
			var p: PieceData = board.get_piece(pos)

			match stype:
				"ALLY_PIECE":
					if p != null and p.team == cur_team:
						valids.append(pos)
				"ALLY_PIECE_OTHER":
					if p != null and p.team == cur_team and not collected_targets.has(pos):
						valids.append(pos)
				"ALLY_NON_QUEEN":
					if p != null and p.team == cur_team and p.type != PieceData.PieceType.QUEEN and p.type != PieceData.PieceType.SUPER_QUEEN and not collected_targets.has(pos):
						valids.append(pos)
				"ALLY_PAWN":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.PAWN or p.type == PieceData.PieceType.SUPER_PAWN):
						valids.append(pos)
				"ALLY_PAWN_OTHER":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.PAWN or p.type == PieceData.PieceType.SUPER_PAWN) and not collected_targets.has(pos):
						valids.append(pos)
				"ALLY_KNIGHT":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.KNIGHT or p.type == PieceData.PieceType.SUPER_KNIGHT):
						valids.append(pos)
				"ALLY_KNIGHT_OTHER":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.KNIGHT or p.type == PieceData.PieceType.SUPER_KNIGHT) and not collected_targets.has(pos):
						valids.append(pos)
				"ALLY_ROOK":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.ROOK or p.type == PieceData.PieceType.SUPER_ROOK):
						valids.append(pos)
				"ALLY_ROOK_OTHER":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.ROOK or p.type == PieceData.PieceType.SUPER_ROOK) and not collected_targets.has(pos):
						valids.append(pos)
				"ALLY_BISHOP":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.BISHOP or p.type == PieceData.PieceType.SUPER_BISHOP):
						valids.append(pos)
				"ALLY_BISHOP_OTHER":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.BISHOP or p.type == PieceData.PieceType.SUPER_BISHOP) and not collected_targets.has(pos):
						valids.append(pos)
				"ALLY_QUEEN":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.QUEEN or p.type == PieceData.PieceType.SUPER_QUEEN):
						valids.append(pos)
				"ALLY_QUEEN_OTHER":
					if p != null and p.team == cur_team and (p.type == PieceData.PieceType.QUEEN or p.type == PieceData.PieceType.SUPER_QUEEN) and not collected_targets.has(pos):
						valids.append(pos)
				"PIECE_NO_QUEEN_ROOK":
					if p != null and p.type != PieceData.PieceType.QUEEN and p.type != PieceData.PieceType.SUPER_QUEEN and p.type != PieceData.PieceType.ROOK and p.type != PieceData.PieceType.SUPER_ROOK:
						valids.append(pos)
				"ENEMY_PIECE":
					if p != null and p.team == opp_team:
						valids.append(pos)
				"ENEMY_NON_KING":
					if p != null and p.team == opp_team and p.type != PieceData.PieceType.KING and not collected_targets.has(pos):
						valids.append(pos)
				"ENEMY_ROOK":
					if p != null and p.team == opp_team and (p.type == PieceData.PieceType.ROOK or p.type == PieceData.PieceType.SUPER_ROOK):
						valids.append(pos)
				"ENEMY_KNIGHT":
					if p != null and p.team == opp_team and (p.type == PieceData.PieceType.KNIGHT or p.type == PieceData.PieceType.SUPER_KNIGHT):
						valids.append(pos)
				"ENEMY_BISHOP":
					if p != null and p.team == opp_team and (p.type == PieceData.PieceType.BISHOP or p.type == PieceData.PieceType.SUPER_BISHOP):
						valids.append(pos)
				"ENEMY_QUEEN":
					if p != null and p.team == opp_team and (p.type == PieceData.PieceType.QUEEN or p.type == PieceData.PieceType.SUPER_QUEEN):
						valids.append(pos)
				"ENEMY_UNDER_3PTS":
					if p != null and p.team == opp_team and p.points < 3:
						valids.append(pos)
				"EMPTY_CELL":
					if p == null and not board.is_cell_forbidden(pos):
						valids.append(pos)
				"HOME_EMPTY_CELL":
					if p == null and not board.is_cell_forbidden(pos):
						if (cur_team == PieceData.Team.WHITE and pos.y <= 3) or (cur_team == PieceData.Team.BLACK and pos.y >= 4):
							valids.append(pos)
				"RANK_4_5":
					if (pos.y == 3 or pos.y == 4) and not board.is_cell_forbidden(pos):
						valids.append(pos)
				"ANY_CELL":
					if not collected_targets.has(pos):
						valids.append(pos)
				"SACRIFICE":
					if p != null and p.team == cur_team and p.type != PieceData.PieceType.KING and not collected_targets.has(pos):
						valids.append(pos)

	return valids

func _apply_current_targeting_step() -> void:
	if current_targeting_step_index >= targeting_steps.size():
		_finish_targeting()
		return

	var step: Dictionary = targeting_steps[current_targeting_step_index]
	current_step_valid_cells = _get_valid_cells_for_step(step)

	if board_view != null:
		board_view.highlight_targeting_cells(current_step_valid_cells)

	var prompt_str: String = step.get("prompt", "CHỌN MỤC TIÊU")
	show_message("[%s] - BƯỚC %d/%d: %s (ESC / Chuột phải để hủy)" % [
		targeting_card.title,
		current_targeting_step_index + 1,
		targeting_steps.size(),
		prompt_str
	])

func _process_targeting_tile_click(pos: Vector2i) -> void:
	if not current_step_valid_cells.has(pos):
		show_message("Ô NÀY KHÔNG HỢP LỆ! HÃY CHỌN Ô PHÁT SÁNG (ESC ĐỂ HỦY)")
		return

	collected_targets.append(pos)

	# Special dynamic expansion for ACTIVE_29 (Clone War)
	if targeting_card != null and targeting_card.id == "ACTIVE_29" and current_targeting_step_index == 0:
		var src_p: PieceData = turn_manager.board.get_piece(pos)
		var clone_count: int = 2
		if src_p != null:
			if src_p.type == PieceData.PieceType.PAWN:
				clone_count = 5
			elif src_p.type == PieceData.PieceType.KING:
				clone_count = 3
			else:
				clone_count = 2
		for k in range(clone_count):
			targeting_steps.append({"prompt": "CHỌN Ô TRỐNG SÂN NHÀ ĐẶT BÓNG %d/%d" % [k + 1, clone_count], "type": "HOME_EMPTY_CELL"})

	# Special check for Sacrifice cards (ACTIVE_15, 16, 17)
	var cur_step: Dictionary = targeting_steps[current_targeting_step_index]
	if cur_step.get("type", "") == "SACRIFICE":
		var req_pts: int = int(cur_step.get("req_points", 8))
		var current_pts: int = 0
		for tpos in collected_targets:
			if tpos is Vector2i:
				var sp: PieceData = turn_manager.board.get_piece(tpos)
				if sp != null:
					current_pts += sp.points
		if current_pts < req_pts:
			# Vẫn chưa đủ điểm, tiếp tục chọn thêm quân hiến tế
			_apply_current_targeting_step()
			show_message("[%s] - ĐÃ CHỌN %d/%d ĐIỂM HIẾN TẾ: Hãy chọn thêm quân!" % [targeting_card.title, current_pts, req_pts])
			return

	current_targeting_step_index += 1
	if current_targeting_step_index >= targeting_steps.size():
		_finish_targeting()
	else:
		_apply_current_targeting_step()

func _finish_targeting() -> void:
	if targeting_card == null:
		_cancel_card_selection()
		return

	var final_msg: String = ""
	if targeting_is_passive:
		var res: Dictionary = turn_manager.execute_passive_trigger(turn_manager.current_turn_team, targeting_passive_slot_index, collected_targets)
		if res.get("success", false):
			final_msg = "ĐÃ KÍCH HOẠT BẪY: %s!" % targeting_card.title
	else:
		var ok: bool = turn_manager.play_active_card(targeting_card, Vector2i(-1, -1), Vector2i(-1, -1), collected_targets)
		if ok:
			final_msg = "KÍCH HOẠT: %s!" % targeting_card.title
			_animate_active_slot_trigger(turn_manager.current_turn_team, targeting_card)
		else:
			final_msg = "BỊ PHẢN ĐÒN HOẶC KHÔNG THỂ DÙNG BÀI!"

	_cancel_card_selection(false)
	_update_all_ui()
	if final_msg != "":
		show_message(final_msg)

# -------------------------------------------------------------
# Visual & State Synchronizations
# -------------------------------------------------------------

func _update_all_ui() -> void:
	if turn_manager == null:
		return

	_update_hud_labels()
	_update_deck_display()
	_update_opponent_hand_display()
	_update_passive_slots_display()
	_update_shaders()
	_check_and_display_event_banners()

	if card_hand_view != null:
		card_hand_view.setup(turn_manager, turn_manager.current_turn_team)

	if board_view != null and not is_targeting_card:
		board_view.update_board_visuals()

func _update_hud_labels() -> void:
	if turn_phase_label != null:
		var team_str: String = "TRẮNG" if turn_manager.current_turn_team == PieceData.Team.WHITE else "ĐEN"
		var phase_str: String = _get_phase_name(turn_manager.current_phase)
		turn_phase_label.text = "ROUND %d - LƯỢT %s | %s" % [turn_manager.turn_number, team_str, phase_str]

	if player_score_label != null:
		player_score_label.text = "TRẮNG: %d ĐIỂM" % int(turn_manager.board.white_points_captured)

	if opponent_score_label != null:
		opponent_score_label.text = "ĐEN: %d ĐIỂM" % int(turn_manager.board.black_points_captured)

func _update_deck_display() -> void:
	if deck_label != null and turn_manager != null:
		var engine: CardEngine = turn_manager.get_current_engine()
		deck_label.text = "DECK: %d / 27" % engine.deck.size()

func _update_opponent_hand_display() -> void:
	_ensure_opponent_hand_ui()
	if opponent_hand_container == null or turn_manager == null:
		return

	for child in opponent_hand_container.get_children():
		child.queue_free()

	var opp_cards: Array[CardResource] = turn_manager.black_engine.hand
	var count: int = opp_cards.size()

	if opponent_hand_label != null:
		opponent_hand_label.text = "TAY BÀI ĐỐI THỦ: %d LÁ" % count

	if count == 0:
		return

	var card_w: float = 72.0
	var card_h: float = 104.0
	var center_index: float = float(count - 1) / 2.0
	var spacing: float = clampf(420.0 / maxf(float(count), 1.0), 30.0, 65.0)
	var total_width: float = spacing * float(count - 1)
	var container_w: float = opponent_hand_container.size.x if opponent_hand_container.size.x > 0.0 else 520.0
	var start_x: float = (container_w - total_width) * 0.5

	for i in range(count):
		var card_rect: TextureRect = TextureRect.new()
		card_rect.custom_minimum_size = Vector2(card_w, card_h)
		card_rect.size = Vector2(card_w, card_h)
		card_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		if ResourceLoader.exists(CARD_BACK_PATH):
			card_rect.texture = load(CARD_BACK_PATH) as Texture2D
		else:
			var bg: ColorRect = ColorRect.new()
			bg.set_anchors_preset(PRESET_FULL_RECT)
			bg.color = Color(0.18, 0.12, 0.28)
			card_rect.add_child(bg)

		var dist: float = float(i) - center_index
		var norm: float = 0.0 if count <= 1 else dist / maxf(center_index, 1.0)
		var angle_deg: float = norm * -14.0 # Quạt ngược +14 -> -14
		var pos_x: float = start_x + float(i) * spacing - (card_w * 0.5)
		var pos_y: float = 4.0 + absf(norm) * 10.0

		card_rect.position = Vector2(pos_x, pos_y)
		card_rect.rotation_degrees = angle_deg
		card_rect.pivot_offset = Vector2(card_w * 0.5, 0.0) # Pivot ở đỉnh
		card_rect.z_index = i
		opponent_hand_container.add_child(card_rect)

func _update_passive_slots_display() -> void:
	_update_team_passive_row(player_passive_row, PieceData.Team.WHITE)
	_update_team_passive_row(opponent_passive_row, PieceData.Team.BLACK)

func _update_team_passive_row(row: Control, team: PieceData.Team) -> void:
	if row == null or turn_manager == null:
		return

	var slots: Array[Dictionary] = turn_manager.passive_manager.get_slots(team)
	var child_count: int = row.get_child_count()

	for i in range(child_count):
		var slot_node: Control = row.get_child(i) as Control
		var card_back: TextureRect = slot_node.find_child("CardBackTexture", true, false) as TextureRect
		var slot_lbl: Label = slot_node.find_child("SlotLabel", true, false) as Label
		var card_container: Control = _ensure_card_container_on_slot(slot_node)
		var glow_border: ReferenceRect = _ensure_glow_border_on_slot(slot_node)
		var status_tag: Label = _ensure_status_tag_on_slot(slot_node)

		var has_card: bool = i < slots.size() and slots[i].get("card") != null
		var slot_data: Dictionary = slots[i] if i < slots.size() else {}
		var is_ready: bool = slot_data.get("is_ready_to_trigger", false)

		# GlowBorder bật khi is_ready_to_trigger == true
		if glow_border != null:
			glow_border.visible = is_ready

		if has_card:
			var card: CardResource = slot_data["card"] as CardResource
			if team == PieceData.Team.WHITE:
				# Trắng thấy rõ mặt bài kèm nhãn "ĐÃ ÚP"
				if card_back != null:
					card_back.visible = false
				if slot_lbl != null:
					slot_lbl.visible = false
				if status_tag != null:
					status_tag.visible = true

				_render_card_into_container(card_container, card)
			else:
				# Đen úp mặt lưng card_back.svg (Fog of war)
				if card_back != null:
					card_back.visible = true
				if slot_lbl != null:
					slot_lbl.visible = false
				if status_tag != null:
					status_tag.visible = false
				_clear_container(card_container)
		else:
			if card_back != null:
				card_back.visible = false
			if slot_lbl != null:
				slot_lbl.visible = true
			if status_tag != null:
				status_tag.visible = false
			_clear_container(card_container)

func _ensure_card_container_on_slot(slot_node: Control) -> Control:
	var container: Control = slot_node.find_child("CardContainer", true, false) as Control
	if container == null:
		container = Control.new()
		container.name = "CardContainer"
		container.set_anchors_preset(PRESET_FULL_RECT)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_node.add_child(container)
	return container

func _ensure_glow_border_on_slot(slot_node: Control) -> ReferenceRect:
	var glow: ReferenceRect = slot_node.find_child("GlowBorder", true, false) as ReferenceRect
	if glow == null:
		glow = slot_node.find_child("MagicGlowBorder", true, false) as ReferenceRect
	if glow == null:
		glow = ReferenceRect.new()
		glow.name = "GlowBorder"
		glow.set_anchors_preset(PRESET_FULL_RECT)
		glow.border_color = Color(1.0, 0.84, 0.0, 0.95) # Gold
		glow.border_width = 3.0
		glow.editor_only = false
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_node.add_child(glow)
	return glow

func _ensure_status_tag_on_slot(slot_node: Control) -> Label:
	var tag: Label = slot_node.find_child("StatusTag", true, false) as Label
	if tag == null:
		tag = Label.new()
		tag.name = "StatusTag"
		tag.set_anchors_preset(PRESET_TOP_RIGHT)
		tag.offset_left = -70.0
		tag.offset_top = 4.0
		tag.offset_right = -4.0
		tag.offset_bottom = 22.0
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		tag.text = "ĐÃ ÚP"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.visible = false
		slot_node.add_child(tag)
	return tag

func _clear_container(container: Control) -> void:
	if container != null:
		for c in container.get_children():
			c.queue_free()

func _render_card_into_container(container: Control, card: CardResource) -> void:
	if container == null or card == null:
		return
	if container.get_child_count() > 0:
		var existing: Control = container.get_child(0) as Control
		if existing.get_meta("card_id", "") == card.id:
			return
		_clear_container(container)

	var card_node: Control = null
	if ResourceLoader.exists(CARD_UI_SCENE_PATH):
		var scene: PackedScene = load(CARD_UI_SCENE_PATH) as PackedScene
		if scene != null:
			card_node = scene.instantiate() as Control

	if card_node != null:
		card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_node.scale = Vector2(0.85, 0.85)
		card_node.position = Vector2(4.0, 2.0)
		card_node.set_meta("card_id", card.id)
		_populate_card_ui(card_node, card)
		container.add_child(card_node)

func _populate_card_ui(node: Control, card: CardResource) -> void:
	var title_lbl: Label = node.find_child("TitleLabel", true, false) as Label
	var type_lbl: Label = node.find_child("TypeLabel", true, false) as Label
	var desc_lbl: Label = node.find_child("DescLabel", true, false) as Label
	var frame_rect: TextureRect = node.find_child("CardFrame", true, false) as TextureRect

	var is_act: bool = card.is_active()
	if title_lbl != null:
		title_lbl.text = card.title
	if type_lbl != null:
		type_lbl.text = "[ACTIVE]" if is_act else "[PASSIVE]"
		type_lbl.add_theme_color_override("font_color", Color(0.92, 0.35, 0.32) if is_act else Color(0.68, 0.45, 0.95))
	if desc_lbl != null:
		desc_lbl.text = card.description
	if frame_rect != null:
		var frame_path: String = FRAME_ACTIVE_PATH if is_act else FRAME_PASSIVE_PATH
		if ResourceLoader.exists(frame_path):
			frame_rect.texture = load(frame_path) as Texture2D

func _animate_active_slot_trigger(team: PieceData.Team, card: CardResource) -> void:
	var slot: Control = player_active_slot if team == PieceData.Team.WHITE else opponent_active_slot
	if slot == null or card == null:
		return

	var container: Control = _ensure_card_container_on_slot(slot)
	_render_card_into_container(container, card)

	var lbl: Label = slot.find_child("SlotLabel", true, false) as Label
	if lbl != null:
		lbl.visible = false

	var glow: ReferenceRect = _ensure_glow_border_on_slot(slot)
	if glow != null:
		glow.visible = true

func _update_shaders() -> void:
	if board_view == null or turn_manager == null:
		return

	if turn_manager.death_ring_system.is_death_ring_active:
		board_view.apply_board_shader(SHADER_DEATH_RING)
	elif turn_manager.death_ring_system.is_holy_war_active:
		board_view.apply_board_shader(SHADER_HOLY_WAR)
	elif turn_manager.board.river_barrier_active:
		board_view.apply_board_shader(SHADER_RIVER_BARRIER)
	elif turn_manager.board.barrier_burn_zones.size() > 0:
		board_view.apply_board_shader(SHADER_BARRIER_BURN)
	else:
		board_view.remove_board_shader()

func _check_and_display_event_banners() -> void:
	if turn_manager == null:
		return

	if turn_manager.is_game_over:
		var win_team: String = "TRẮNG THẮNG!" if turn_manager.winner == 0 else ("ĐEN THẮNG!" if turn_manager.winner == 1 else "HÒA NHAU!")
		show_message("TRẬN ĐẤU KẾT THÚC! %s (%s)" % [win_team, turn_manager.game_over_reason])
		return

	if turn_manager.interception_extra_moves > 0:
		show_message("CHECKMATE HOOK TRIGGERED! %d NƯỚC GIẢI VÂY" % turn_manager.interception_extra_moves)
		return

	if turn_manager.death_ring_system.is_holy_war_active:
		show_message("THÁNH CHIẾN 2 VUA! VUA ĐƯỢC ĂN NHAU!")
		return

	if turn_manager.death_ring_system.is_death_ring_active:
		show_message("VÒNG LỬA SINH TỬ KÍCH HOẠT!")
		return

	var current_team: PieceData.Team = turn_manager.current_turn_team
	if MoveValidator.is_in_check(turn_manager.board, current_team):
		show_message("CHIẾU TƯỚNG!")
		return

func show_message(msg: String) -> void:
	if message_banner != null:
		message_banner.text = msg

func _get_phase_name(p: TurnManager.Phase) -> String:
	match p:
		TurnManager.Phase.DRAW_PHASE: return "DRAW PHASE"
		TurnManager.Phase.MAIN_PHASE: return "MAIN PHASE"
		TurnManager.Phase.MOVE_PHASE: return "MOVE PHASE"
		TurnManager.Phase.END_PHASE: return "END PHASE"
		_: return "UNKNOWN"

# --- Bộ nhận Click & Drag-Drop cho Active/Passive Slot ---
class SlotDropCatcher extends Control:
	var slot_type: String = "active"
	var slot_index: int = 0
	var team: PieceData.Team = PieceData.Team.WHITE
	var controller: GameController

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and controller != null:
				if slot_type == "active":
					controller.handle_active_slot_action(team)
				else:
					controller.handle_passive_slot_action(team, slot_index)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY or data.get("type") != "card":
			return false
		var card: CardResource = data.get("card") as CardResource
		if card == null:
			return false
		if slot_type == "active":
			return card.is_active()
		return card.is_passive()

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if controller == null or typeof(data) != TYPE_DICTIONARY:
			return
		var card: CardResource = data.get("card") as CardResource
		if slot_type == "active":
			controller.handle_active_slot_action(team, card)
		else:
			controller.handle_passive_slot_action(team, slot_index, card)
