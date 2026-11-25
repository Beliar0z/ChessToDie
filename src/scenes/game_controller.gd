# res://src/scenes/game_controller.gd
# GDScript / game_controller.gd / Godot 4.7 / UI Orchestrator
class_name GameController
extends Control

var turn_manager: TurnManager
var board_view: BoardView
var card_hand_view: CardHandView
var vfx_manager: VFXManager
var status_tooltip: StatusTooltip
var card_inspector: CardInspector
var grave_picker: GraveRevivePicker
var lan_bridge: LanTestBridge
var lan_mode: bool = false
var local_team: PieceData.Team = PieceData.Team.WHITE
var _is_applying_remote: bool = false
var _pending_revive_context: Dictionary = {}
var _selected_grave_index: int = -1
var _passive_glow_tweens: Dictionary = {}
var _deck_glow_tween: Tween = null

var chessboard_node: Control
var hand_container: Control
var deck_slot: Control
var deck_label: Label
var deck_glow_border: ReferenceRect

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
const FRAME_ACTIVE_PATH: String = "res://assets/ui/textures/frame_active.png"
const FRAME_PASSIVE_PATH: String = "res://assets/ui/textures/frame_passive.png"
const CARD_BACK_ACTIVE_PATH: String = "res://assets/sprites/cards/the_sun_back.png"
const CARD_BACK_PASSIVE_PATH: String = "res://assets/sprites/cards/the_moon_back.png"
const CARD_BACK_PATH: String = "res://assets/sprites/cards/the_moon_back.png"
const DECK_PILE_PATH: String = "res://assets/sprites/cards/the_sun_back.png"

const SHADER_DEATH_RING: String = "res://assets/shaders/death_ring.gdshader"
const SHADER_RIVER_BARRIER: String = "res://assets/shaders/river_barrier.gdshader"
const SHADER_BARRIER_BURN: String = "res://assets/shaders/barrier_burn.gdshader"
const SHADER_HOLY_WAR: String = "res://assets/shaders/holy_war.gdshader"
const SHADER_STEALTH: String = "res://assets/shaders/stealth.gdshader"
const SHADER_PASSIVE_PULSE: String = "res://assets/shaders/passive_pulse.gdshader"

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

	# Bật chế độ người chơi tự bấm rút bài từ Deck
	turn_manager.white_engine.manual_draw_mode = true

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

		vfx_manager = chessboard_node.get_node_or_null("VFXManagerComponent") as VFXManager
		if vfx_manager == null:
			vfx_manager = VFXManager.new()
			vfx_manager.name = "VFXManagerComponent"
			vfx_manager.set_anchors_preset(PRESET_FULL_RECT)
			chessboard_node.add_child(vfx_manager)
		vfx_manager.setup(board_view)
	elif vfx_manager == null:
		vfx_manager = VFXManager.new()
		vfx_manager.name = "VFXManagerComponent"
		add_child(vfx_manager)
		vfx_manager.setup(board_view)

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
	if deck_slot != null:
		deck_glow_border = _ensure_deck_glow_border(deck_slot)
		var deck_tex: TextureRect = deck_slot.find_child("DeckTexture", true, false) as TextureRect
		if deck_tex != null:
			deck_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if ResourceLoader.exists(CARD_BACK_ACTIVE_PATH):
				deck_tex.texture = load(CARD_BACK_ACTIVE_PATH) as Texture2D

	var opp_deck_tex: TextureRect = find_child("OpponentDeckTexture", true, false) as TextureRect
	if opp_deck_tex != null:
		opp_deck_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if ResourceLoader.exists(CARD_BACK_ACTIVE_PATH):
			opp_deck_tex.texture = load(CARD_BACK_ACTIVE_PATH) as Texture2D

	opponent_score_label = find_child("OpponentScoreLabel", true, false) as Label
	opponent_passive_row = find_child("OpponentPassiveRow", true, false) as Control
	opponent_active_slot = find_child("OpponentActiveSlot", true, false) as Control

	turn_phase_label = find_child("TurnPhaseLabel", true, false) as Label
	message_banner = find_child("MessageBanner", true, false) as Label
	end_turn_button = find_child("EndTurnButton", true, false) as Button

	player_active_slot = find_child("PlayerActiveSlot", true, false) as Control
	player_passive_row = find_child("PlayerPassiveRow", true, false) as Control
	player_score_label = find_child("PlayerScoreLabel", true, false) as Label

	_ensure_status_tooltip()
	_ensure_card_inspector()
	_ensure_grave_picker()
	_ensure_lan_bridge()
	_ensure_opponent_hand_ui()

	_bind_active_slot(player_active_slot, true)
	_bind_active_slot(opponent_active_slot, false)
	_bind_passive_row(player_passive_row, true)
	_bind_passive_row(opponent_passive_row, false)

func _ensure_status_tooltip() -> void:
	if status_tooltip == null:
		status_tooltip = get_node_or_null("StatusTooltip") as StatusTooltip
	if status_tooltip == null:
		status_tooltip = StatusTooltip.new()
		add_child(status_tooltip)

func _ensure_card_inspector() -> void:
	if card_inspector == null:
		card_inspector = get_node_or_null("CardInspector") as CardInspector
	if card_inspector == null:
		card_inspector = CardInspector.new()
		add_child(card_inspector)

func _ensure_grave_picker() -> void:
	if grave_picker == null:
		grave_picker = get_node_or_null("GraveRevivePicker") as GraveRevivePicker
	if grave_picker == null:
		grave_picker = GraveRevivePicker.new()
		add_child(grave_picker)
	if not grave_picker.revive_confirmed.is_connected(_on_revive_confirmed):
		grave_picker.revive_confirmed.connect(_on_revive_confirmed)
	if not grave_picker.revive_cancelled.is_connected(_on_revive_cancelled):
		grave_picker.revive_cancelled.connect(_on_revive_cancelled)

func _ensure_lan_bridge() -> void:
	if lan_bridge == null:
		lan_bridge = get_node_or_null("LanTestBridge") as LanTestBridge
	if lan_bridge == null:
		lan_bridge = LanTestBridge.new()
		lan_bridge.setup(self)
		add_child(lan_bridge)

func _get_viewer_team() -> PieceData.Team:
	return local_team if lan_mode else PieceData.Team.WHITE

func _get_opponent_viewer_team() -> PieceData.Team:
	return PieceData.Team.BLACK if _get_viewer_team() == PieceData.Team.WHITE else PieceData.Team.WHITE

func _is_local_turn() -> bool:
	if not lan_mode or turn_manager == null:
		return true
	return turn_manager.current_turn_team == local_team

func _ensure_deck_glow_border(slot_node: Control) -> ReferenceRect:
	var glow: ReferenceRect = slot_node.find_child("DeckGlowBorder", true, false) as ReferenceRect
	if glow == null:
		glow = ReferenceRect.new()
		glow.name = "DeckGlowBorder"
		glow.set_anchors_preset(PRESET_FULL_RECT)
		glow.border_color = Color("#FFD700")
		glow.border_width = 4.0
		glow.editor_only = false
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.visible = false
		slot_node.add_child(glow)
	return glow

func _ensure_opponent_hand_ui() -> void:
	# Tìm từ root GameScene (vì OpponentHandArea đã chuyển lên đầu cột trái phía trên bàn cờ)
	opponent_hand_container = find_child("OpponentHandContainer", true, false) as Control
	opponent_hand_label = find_child("OpponentHandLabel", true, false) as Label

	if opponent_hand_container == null:
		var hand_area: Control = Control.new()
		hand_area.name = "OpponentHandArea"
		hand_area.position = Vector2(60.0, 8.0)
		hand_area.custom_minimum_size = Vector2(800.0, 114.0)
		hand_area.size = Vector2(800.0, 114.0)
		add_child(hand_area)

		opponent_hand_label = Label.new()
		opponent_hand_label.name = "OpponentHandLabel"
		opponent_hand_label.position = Vector2(0.0, 0.0)
		opponent_hand_label.custom_minimum_size = Vector2(800.0, 22.0)
		opponent_hand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opponent_hand_label.add_theme_font_size_override("font_size", 14)
		opponent_hand_label.text = "TAY BÀI ĐỐI THỦ: 0 LÁ"
		hand_area.add_child(opponent_hand_label)

		opponent_hand_container = Control.new()
		opponent_hand_container.name = "OpponentHandContainer"
		opponent_hand_container.position = Vector2(0.0, 20.0)
		opponent_hand_container.custom_minimum_size = Vector2(800.0, 94.0)
		opponent_hand_container.size = Vector2(800.0, 94.0)
		hand_area.add_child(opponent_hand_container)

func _bind_active_slot(slot: Control, is_player_side: bool) -> void:
	if slot == null:
		return
	var catcher: SlotDropCatcher = slot.get_node_or_null("DropCatcher") as SlotDropCatcher
	if catcher == null:
		catcher = SlotDropCatcher.new()
		catcher.name = "DropCatcher"
		catcher.set_anchors_preset(PRESET_FULL_RECT)
		catcher.slot_type = "active"
		catcher.is_player_side = is_player_side
		catcher.controller = self
		slot.add_child(catcher)

func _bind_passive_row(row: Control, is_player_side: bool) -> void:
	if row == null:
		return
	for i in range(row.get_child_count()):
		var slot: Control = row.get_child(i) as Control
		var catcher: SlotDropCatcher = slot.get_node_or_null("DropCatcher") as SlotDropCatcher
		if catcher == null:
			catcher = SlotDropCatcher.new()
			catcher.name = "DropCatcher"
			catcher.set_anchors_preset(PRESET_FULL_RECT)
			catcher.mouse_filter = Control.MOUSE_FILTER_STOP
			catcher.slot_type = "passive"
			catcher.slot_index = i
			catcher.is_player_side = is_player_side
			catcher.controller = self
			slot.add_child(catcher)
		if not catcher.get_meta("hover_connected", false):
			catcher.set_meta("hover_connected", true)
			catcher.mouse_entered.connect(func():
				var t: PieceData.Team = _get_viewer_team() if is_player_side else _get_opponent_viewer_team()
				_on_passive_slot_hovered(t, i, slot)
			)
			catcher.mouse_exited.connect(_on_passive_slot_unhovered)

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
		if board_view.has_signal("tile_hovered"):
			if not board_view.tile_hovered.is_connected(_on_tile_hovered):
				board_view.tile_hovered.connect(_on_tile_hovered)
		if board_view.has_signal("tile_unhovered"):
			if not board_view.tile_unhovered.is_connected(_on_tile_unhovered):
				board_view.tile_unhovered.connect(_on_tile_unhovered)

	if card_hand_view != null:
		if not card_hand_view.card_selected.is_connected(_on_card_selected):
			card_hand_view.card_selected.connect(_on_card_selected)
		if not card_hand_view.card_deselected.is_connected(_on_card_deselected):
			card_hand_view.card_deselected.connect(_on_card_deselected)
		if card_hand_view.has_signal("card_hovered") and not card_hand_view.card_hovered.is_connected(_on_hand_card_hovered):
			card_hand_view.card_hovered.connect(_on_hand_card_hovered)
		if card_hand_view.has_signal("card_unhovered") and not card_hand_view.card_unhovered.is_connected(_on_hand_card_unhovered):
			card_hand_view.card_unhovered.connect(_on_hand_card_unhovered)

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
	_pending_revive_context.clear()
	_selected_grave_index = -1
	if grave_picker != null:
		grave_picker.close_picker()

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
	if not _is_local_turn():
		show_message("ĐANG CHỜ ĐỐI THỦ ĐI...")
		return

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
	if not _is_local_turn():
		show_message("ĐANG CHỜ ĐỐI THỦ ĐI...")
		return
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

func _on_move_executed(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if lan_mode and not _is_applying_remote and lan_bridge != null:
		lan_bridge.send_move(from_pos, to_pos)
	if vfx_manager != null and turn_manager != null and turn_manager.board != null:
		if not turn_manager.board.move_history.is_empty():
			var last_move: Dictionary = turn_manager.board.move_history.back()
			if last_move.get("captured") != null:
				vfx_manager.play_tile_vfx(to_pos, "dissolve")
				vfx_manager.trigger_board_shake(5.5, 0.20)
		if MoveValidator.is_in_check(turn_manager.board, turn_manager.current_turn_team):
			vfx_manager.trigger_board_shake(9.0, 0.28)
	_update_all_ui()
	if turn_manager != null and turn_manager.double_move_piece_pos != Vector2i(-1, -1):
		if board_view != null:
			board_view.deselect()
			board_view.select_cell(turn_manager.double_move_piece_pos)
		show_message("SONG TRÙNG: ĐI TIẾP NƯỚC THỨ 2!")
		return
	_check_reaction_window()

func _check_reaction_window() -> void:
	var viewer: PieceData.Team = _get_viewer_team()
	if turn_manager != null and turn_manager.passive_manager.has_ready_trigger(viewer):
		show_message("BẪY ĐỦ ĐIỀU KIỆN — BẤM VÀO LÁ BÀI PHÁT SÁNG ĐỂ KÍCH HOẠT!")
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
	if not _is_local_turn():
		show_message("ĐANG CHỜ ĐỐI THỦ ĐI...")
		return
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
	if not _is_local_turn():
		show_message("ĐANG CHỜ ĐỐI THỦ ĐI...")
		return
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
		if lan_mode and not _is_applying_remote and lan_bridge != null:
			lan_bridge.send_place_passive(card_to_use.id)
		show_message("ĐÃ ÚP 1 LÁ PASSIVE: %s!" % card_to_use.title)
		_cancel_card_selection()
		_update_all_ui()
	else:
		show_message("KHÔNG THỂ ÚP BÀI PASSIVE!")

func _activate_passive_trigger(team: PieceData.Team, slot_index: int) -> void:
	if lan_mode and team != local_team:
		show_message("CHỈ ĐƯỢC KÍCH HOẠT BẪY CỦA PHE MÌNH!")
		return
	var slots: Array[Dictionary] = turn_manager.passive_manager.get_slots(team)
	if slot_index >= slots.size():
		return
	var card: CardResource = slots[slot_index].get("card", null) as CardResource
	if card == null:
		return

	if card.id == "PASSIVE_01" or card.id == "PASSIVE_02" or card.id == "PASSIVE_10" or card.id == "PASSIVE_14" or card.id == "PASSIVE_17":
		start_targeting(card, true, slot_index)
		return

	var res: Dictionary = turn_manager.execute_passive_trigger(team, slot_index)
	if res.get("success", false):
		if lan_mode and not _is_applying_remote and lan_bridge != null:
			lan_bridge.send_trigger_passive(team, slot_index, [])
		show_message("ĐÃ KÍCH HOẠT BẪY: %s!" % card.title)
		_cancel_card_selection()
		_update_all_ui()

func _on_deck_slot_clicked() -> void:
	if turn_manager == null:
		return
	var viewer: PieceData.Team = _get_viewer_team()
	var engine: CardEngine = turn_manager.white_engine if viewer == PieceData.Team.WHITE else turn_manager.black_engine
	if engine.has_pending_draw():
		if engine.hand.size() >= CardEngine.MAX_HAND_SIZE:
			show_message("TAY ĐÃ ĐỦ 10 LÁ! HÃY DÙNG HOẶC BỎ 1 LÁ TRƯỚC KHI RÚT.")
			return
		var drawn: CardResource = engine.claim_pending_draw()
		if drawn != null:
			if lan_mode and not _is_applying_remote and lan_bridge != null:
				lan_bridge.send_claim_draw(viewer)
			_play_deck_draw_feedback()
			_update_all_ui()
			show_message("ĐÃ RÚT LÁ BÀI: %s!" % drawn.title)
	else:
		var rem: int = engine.moves_until_next_draw()
		show_message("CÒN %d NƯỚC ĐI NỮA ĐỂ RÚT BÀI" % rem)

func _play_deck_draw_feedback() -> void:
	if deck_slot == null or not deck_slot.is_inside_tree():
		return
	deck_slot.pivot_offset = deck_slot.size * 0.5
	var tw: Tween = deck_slot.create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(deck_slot, "scale", Vector2(1.08, 1.08), 0.10)
	tw.tween_property(deck_slot, "scale", Vector2.ONE, 0.14)

func _on_tile_hovered(pos: Vector2i, global_rect: Rect2) -> void:
	if turn_manager == null or turn_manager.board == null:
		return
	_ensure_status_tooltip()
	var data: Dictionary = StatusTooltip.build_piece_tooltip_data(turn_manager.board, pos, _get_viewer_team())
	if bool(data.get("should_show", false)):
		var lines: Array[String] = []
		for line in data.get("lines", []):
			lines.append(String(line))
		status_tooltip.show_tooltip(String(data.get("title", "")), lines, global_rect)
	else:
		status_tooltip.hide_tooltip()

func _on_tile_unhovered() -> void:
	if status_tooltip != null:
		status_tooltip.hide_tooltip()

func _on_passive_slot_hovered(team: PieceData.Team, slot_index: int, slot_node: Control) -> void:
	if turn_manager == null or turn_manager.passive_manager == null or slot_node == null:
		return
	_ensure_status_tooltip()
	var viewer: PieceData.Team = _get_viewer_team()
	var slot_data: Dictionary = turn_manager.passive_manager.get_slot(team, slot_index)
	var data: Dictionary = StatusTooltip.build_passive_tooltip_data(
		slot_data,
		team,
		turn_manager.turn_number,
		turn_manager.passive_manager,
		viewer
	)
	if bool(data.get("should_show", false)):
		var lines: Array[String] = []
		for line in data.get("lines", []):
			lines.append(String(line))
		status_tooltip.show_tooltip(String(data.get("title", "")), lines, slot_node.get_global_rect())
	else:
		status_tooltip.hide_tooltip()

	if team == viewer and slot_data.get("card") != null:
		_ensure_card_inspector()
		card_inspector.show_card(slot_data["card"] as CardResource, slot_node.get_global_rect())

func _on_passive_slot_unhovered() -> void:
	if status_tooltip != null:
		status_tooltip.hide_tooltip()
	if card_inspector != null:
		card_inspector.hide_inspector()

func _on_hand_card_hovered(card: CardResource, global_rect: Rect2) -> void:
	if card == null:
		return
	_ensure_card_inspector()
	card_inspector.show_card(card, global_rect)

func _on_hand_card_unhovered() -> void:
	if card_inspector != null:
		card_inspector.hide_inspector()

func _on_end_turn_button_pressed() -> void:
	if not _is_local_turn():
		show_message("ĐANG CHỜ ĐỐI THỦ ĐI...")
		return
	_cancel_card_selection()
	if board_view != null:
		board_view.deselect()
	turn_manager.end_turn()
	if lan_mode and not _is_applying_remote and lan_bridge != null:
		lan_bridge.send_end_turn()
	_update_all_ui()

# -------------------------------------------------------------
# Targeting System Engine
# -------------------------------------------------------------

func start_targeting(card: CardResource, is_passive: bool = false, slot_index: int = -1, initial_target: Vector2i = Vector2i(-1, -1)) -> void:
	# Mở bảng chọn quân từ Mộ Địa cho các lá có cơ chế Hồi Sinh
	if card != null and (card.id == "ACTIVE_14" or card.id == "PASSIVE_02" or card.id == "PASSIVE_10") and _selected_grave_index == -1:
		var acting_team: PieceData.Team = _get_viewer_team() if (is_passive and lan_mode) else turn_manager.current_turn_team
		var grave: Array[PieceData] = turn_manager.board.grave_white if acting_team == PieceData.Team.WHITE else turn_manager.board.grave_black
		if grave.is_empty():
			_cancel_card_selection(false)
			show_message("MỘ ĐỊA ĐANG TRỐNG — KHÔNG CÓ QUÂN ĐỂ HỒI SINH!")
			return
		_ensure_grave_picker()
		_pending_revive_context = {
			"card": card,
			"is_passive": is_passive,
			"slot_index": slot_index,
			"initial_target": initial_target,
			"team": acting_team
		}
		if card.id == "ACTIVE_14":
			grave_picker.open_picker(card, grave, 999, 999, false)
		elif card.id == "PASSIVE_02":
			grave_picker.open_picker(card, grave, 4, 4, false)
		elif card.id == "PASSIVE_10":
			grave_picker.open_picker(card, grave, 4, 4, true)
		show_message("[%s] — HÃY CHỌN QUÂN HỒI SINH TRONG MỘ ĐỊA!" % card.title)
		return

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
			steps.append({"prompt": "CHỌN QUÂN ĐỒNG MINH MUỐN PHÂN THÂN (TRỪ HẬU & XE)", "type": "ALLY_CLONEABLE"})
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
		"PASSIVE_17":
			steps.append({"prompt": "CHỌN 1 TRONG 3 TỐT CHÉO ĐỐI THỦ ĐỂ TIÊU HỦY", "type": "ENEMY_DIAGONAL_PAWN"})

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
					if p != null and p.team == cur_team and p.type != PieceData.PieceType.QUEEN and p.type != PieceData.PieceType.SUPER_QUEEN and p.type != PieceData.PieceType.ROOK and p.type != PieceData.PieceType.SUPER_ROOK:
						valids.append(pos)
				"ALLY_CLONEABLE":
					if p != null and p.team == cur_team and p.type != PieceData.PieceType.QUEEN and p.type != PieceData.PieceType.SUPER_QUEEN and p.type != PieceData.PieceType.ROOK and p.type != PieceData.PieceType.SUPER_ROOK:
						valids.append(pos)
				"ENEMY_DIAGONAL_PAWN":
					var diag_pawns: Array[Vector2i] = board.has_three_diagonal_pawns(opp_team)
					if diag_pawns.has(pos):
						valids.append(pos)
				"ENEMY_PIECE":
					if p != null and p.team == opp_team and p.can_be_targeted():
						valids.append(pos)
				"ENEMY_NON_KING":
					if p != null and p.team == opp_team and p.type != PieceData.PieceType.KING and p.can_be_targeted() and not collected_targets.has(pos):
						valids.append(pos)
				"ENEMY_ROOK":
					if p != null and p.team == opp_team and p.can_be_targeted() and (p.type == PieceData.PieceType.ROOK or p.type == PieceData.PieceType.SUPER_ROOK):
						valids.append(pos)
				"ENEMY_KNIGHT":
					if p != null and p.team == opp_team and p.can_be_targeted() and (p.type == PieceData.PieceType.KNIGHT or p.type == PieceData.PieceType.SUPER_KNIGHT):
						valids.append(pos)
				"ENEMY_BISHOP":
					if p != null and p.team == opp_team and p.can_be_targeted() and (p.type == PieceData.PieceType.BISHOP or p.type == PieceData.PieceType.SUPER_BISHOP):
						valids.append(pos)
				"ENEMY_QUEEN":
					if p != null and p.team == opp_team and p.can_be_targeted() and (p.type == PieceData.PieceType.QUEEN or p.type == PieceData.PieceType.SUPER_QUEEN):
						valids.append(pos)
				"ENEMY_UNDER_3PTS":
					if p != null and p.team == opp_team and p.can_be_targeted() and p.points < 3:
						valids.append(pos)
				"EMPTY_CELL":
					if p == null and not board.is_cell_forbidden(pos):
						if targeting_card != null and targeting_card.id == "ACTIVE_02" and collected_targets.size() >= 1 and collected_targets[0] is Vector2i:
							var sim_b: BoardState = board.clone()
							var src_p: PieceData = sim_b.remove_piece(collected_targets[0] as Vector2i)
							if src_p != null:
								sim_b.set_piece(pos, src_p)
								if not MoveValidator.is_in_check(sim_b, opp_team) and not MoveValidator.is_in_check(sim_b, cur_team):
									valids.append(pos)
						else:
							valids.append(pos)
				"HOME_EMPTY_CELL":
					if p == null and not board.is_cell_forbidden(pos) and not collected_targets.has(pos):
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

	if current_step_valid_cells.is_empty():
		var card_name: String = targeting_card.title if targeting_card != null else "BÀI"
		_cancel_card_selection(false)
		show_message("KHÔNG CÓ MỤC TIÊU HỢP LỆ CHO [%s]!" % card_name)
		return

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

func _on_revive_confirmed(selected_indices: Array[int]) -> void:
	if _pending_revive_context.is_empty() or selected_indices.is_empty():
		_cancel_card_selection()
		return
	var card: CardResource = _pending_revive_context.get("card", null) as CardResource
	var is_passive: bool = bool(_pending_revive_context.get("is_passive", false))
	var slot_index: int = int(_pending_revive_context.get("slot_index", -1))
	var initial_target: Vector2i = _pending_revive_context.get("initial_target", Vector2i(-1, -1)) as Vector2i
	var acting_team: PieceData.Team = _pending_revive_context.get("team", PieceData.Team.WHITE) as PieceData.Team
	_pending_revive_context.clear()

	if card == null:
		_cancel_card_selection()
		return

	if card.id == "PASSIVE_10":
		var targets_arr: Array = []
		for idx in selected_indices:
			targets_arr.append(idx)
		var res: Dictionary = turn_manager.execute_passive_trigger(acting_team, slot_index, targets_arr)
		if res.get("success", false):
			if lan_mode and not _is_applying_remote and lan_bridge != null:
				lan_bridge.send_trigger_passive(acting_team, slot_index, targets_arr)
			show_message("ĐÃ HỒI SINH %d QUÂN TỪ MỘ (%s)!" % [selected_indices.size(), card.title])
			_play_vfx_for_card_cast(card, acting_team, [], Vector2.ZERO, false)
		_cancel_card_selection(false)
		_update_all_ui()
		return

	_selected_grave_index = selected_indices[0]
	start_targeting(card, is_passive, slot_index, initial_target)

func _on_revive_cancelled() -> void:
	_cancel_card_selection()

func _finish_targeting() -> void:
	if targeting_card == null:
		_cancel_card_selection()
		return

	var final_msg: String = ""
	var cast_card: CardResource = targeting_card
	var cast_targets: Array = collected_targets.duplicate()
	if _selected_grave_index >= 0:
		cast_targets.append(_selected_grave_index)
	var cast_team: PieceData.Team = turn_manager.current_turn_team
	var from_hand_pos: Vector2 = Vector2.ZERO
	if card_hand_view != null and card_hand_view.selected_card_node != null and is_instance_valid(card_hand_view.selected_card_node) and card_hand_view.selected_card_node.is_inside_tree():
		from_hand_pos = card_hand_view.selected_card_node.global_position

	if targeting_is_passive:
		var trig_team: PieceData.Team = _get_viewer_team() if lan_mode else cast_team
		var res: Dictionary = turn_manager.execute_passive_trigger(trig_team, targeting_passive_slot_index, cast_targets)
		if res.get("success", false):
			if lan_mode and not _is_applying_remote and lan_bridge != null:
				lan_bridge.send_trigger_passive(trig_team, targeting_passive_slot_index, cast_targets)
			final_msg = "ĐÃ KÍCH HOẠT BẪY: %s!" % cast_card.title
			_play_vfx_for_card_cast(cast_card, trig_team, cast_targets, Vector2.ZERO, false)
	else:
		var ok: bool = turn_manager.play_active_card(cast_card, Vector2i(-1, -1), Vector2i(-1, -1), cast_targets)
		if lan_mode and not _is_applying_remote and lan_bridge != null:
			lan_bridge.send_play_active(cast_card.id, cast_targets)
		if ok:
			final_msg = "KÍCH HOẠT: %s!" % cast_card.title
			_animate_active_slot_trigger(cast_team, cast_card)
			_play_vfx_for_card_cast(cast_card, cast_team, cast_targets, from_hand_pos, true)
		else:
			final_msg = "BỊ PHẢN ĐÒN HOẶC KHÔNG THỂ DÙNG BÀI!"

	_cancel_card_selection(false)
	_update_all_ui()
	if final_msg != "":
		show_message(final_msg)

func _play_vfx_for_card_cast(card: CardResource, team: PieceData.Team, targets: Array, from_global_pos: Vector2, is_active_cast: bool) -> void:
	if vfx_manager == null or card == null:
		return
	if is_active_cast:
		var slot: Control = player_active_slot if team == PieceData.Team.WHITE else opponent_active_slot
		vfx_manager.play_card_cast_vfx(card, slot, from_global_pos)

	var vfx_type: String = VFXManager.get_vfx_type_for_card(card)
	var played_on_target: bool = false
	for t in targets:
		if t is Vector2i and t != Vector2i(-1, -1):
			vfx_manager.play_tile_vfx(t, vfx_type)
			played_on_target = true

	if not played_on_target and turn_manager != null and turn_manager.board != null:
		var king_pos: Vector2i = turn_manager.board.find_king(team)
		if king_pos != Vector2i(-1, -1):
			vfx_manager.play_tile_vfx(king_pos, vfx_type)

	if VFXManager.should_shake_for_card(card):
		var shake_amp: float = 11.0 if (card.id == "ACTIVE_25" or card.id == "ACTIVE_30") else 7.5
		vfx_manager.trigger_board_shake(shake_amp, 0.28)

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
		var hand_team: PieceData.Team = _get_viewer_team() if lan_mode else turn_manager.current_turn_team
		card_hand_view.setup(turn_manager, hand_team)

	if board_view != null and not is_targeting_card:
		board_view.update_board_visuals()

func _update_hud_labels() -> void:
	if turn_phase_label != null:
		var team_str: String = "TRẮNG" if turn_manager.current_turn_team == PieceData.Team.WHITE else "ĐEN"
		var phase_str: String = _get_phase_name(turn_manager.current_phase)
		turn_phase_label.text = "ROUND %d - LƯỢT %s | %s" % [turn_manager.turn_number, team_str, phase_str]

	var viewer: PieceData.Team = _get_viewer_team()
	if player_score_label != null:
		if viewer == PieceData.Team.WHITE:
			player_score_label.text = "TRẮNG: %d ĐIỂM" % int(turn_manager.board.white_points_captured)
		else:
			player_score_label.text = "ĐEN (BẠN): %d ĐIỂM" % int(turn_manager.board.black_points_captured)

	if opponent_score_label != null:
		if viewer == PieceData.Team.WHITE:
			opponent_score_label.text = "ĐEN: %d ĐIỂM" % int(turn_manager.board.black_points_captured)
		else:
			opponent_score_label.text = "TRẮNG (ĐỐI THỦ): %d ĐIỂM" % int(turn_manager.board.white_points_captured)

func _update_deck_display() -> void:
	_update_deck_glow()

func _update_deck_glow() -> void:
	if turn_manager == null:
		return
	var viewer: PieceData.Team = _get_viewer_team()
	var engine: CardEngine = turn_manager.white_engine if viewer == PieceData.Team.WHITE else turn_manager.black_engine
	var pending: bool = engine.has_pending_draw()

	if deck_slot != null and deck_glow_border == null:
		deck_glow_border = _ensure_deck_glow_border(deck_slot)

	if pending:
		if deck_label != null:
			deck_label.text = "RÚT BÀI! (+%d) | %d/27" % [engine.pending_draws, engine.deck.size()]
			deck_label.add_theme_color_override("font_color", Color("#FFD700"))
		if deck_glow_border != null:
			deck_glow_border.visible = true
			if ResourceLoader.exists(SHADER_PASSIVE_PULSE) and deck_glow_border.material == null:
				var pulse_shader: Shader = load(SHADER_PASSIVE_PULSE) as Shader
				if pulse_shader != null:
					var mat: ShaderMaterial = ShaderMaterial.new()
					mat.shader = pulse_shader
					deck_glow_border.material = mat
			if deck_glow_border.is_inside_tree():
				if _deck_glow_tween == null or not _deck_glow_tween.is_valid():
					deck_glow_border.modulate = Color(1.0, 0.92, 0.45, 1.0)
					_deck_glow_tween = deck_glow_border.create_tween()
					_deck_glow_tween.set_loops()
					_deck_glow_tween.set_trans(Tween.TRANS_SINE)
					_deck_glow_tween.set_ease(Tween.EASE_IN_OUT)
					_deck_glow_tween.tween_property(deck_glow_border, "modulate:a", 0.38, 0.6)
					_deck_glow_tween.tween_property(deck_glow_border, "modulate:a", 1.0, 0.6)
	else:
		if _deck_glow_tween != null and _deck_glow_tween.is_valid():
			_deck_glow_tween.kill()
		_deck_glow_tween = null
		if deck_glow_border != null:
			deck_glow_border.visible = false
			deck_glow_border.modulate = Color.WHITE
			deck_glow_border.material = null
		if deck_label != null:
			deck_label.text = "DECK: %d / 27" % engine.deck.size()
			deck_label.remove_theme_color_override("font_color")

func _update_opponent_hand_display() -> void:
	_ensure_opponent_hand_ui()
	if opponent_hand_container == null or turn_manager == null:
		return

	for child in opponent_hand_container.get_children():
		child.queue_free()

	var opp_team: PieceData.Team = _get_opponent_viewer_team()
	var opp_engine: CardEngine = turn_manager.black_engine if opp_team == PieceData.Team.BLACK else turn_manager.white_engine
	var opp_cards: Array[CardResource] = opp_engine.hand
	var count: int = opp_cards.size()

	if opponent_hand_label != null:
		opponent_hand_label.text = "TAY BÀI ĐỐI THỦ: %d LÁ" % count

	if count == 0:
		return

	var card_w: float = 66.0
	var card_h: float = 94.0
	var center_index: float = float(count - 1) / 2.0
	var spacing: float = clampf(480.0 / maxf(float(count), 1.0), 44.0, 54.0)
	var total_width: float = spacing * float(count - 1)
	var container_w: float = opponent_hand_container.size.x if opponent_hand_container.size.x > 0.0 else 800.0
	var start_x: float = (container_w - total_width) * 0.5

	for i in range(count):
		var card_rect: TextureRect = TextureRect.new()
		card_rect.custom_minimum_size = Vector2(card_w, card_h)
		card_rect.size = Vector2(card_w, card_h)
		card_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		card_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var back_path: String = CARD_BACK_ACTIVE_PATH if opp_cards[i].is_active() else CARD_BACK_PASSIVE_PATH
		if ResourceLoader.exists(back_path):
			card_rect.texture = load(back_path) as Texture2D
		elif ResourceLoader.exists(CARD_BACK_PATH):
			card_rect.texture = load(CARD_BACK_PATH) as Texture2D
		else:
			var bg: ColorRect = ColorRect.new()
			bg.set_anchors_preset(PRESET_FULL_RECT)
			bg.color = Color(0.18, 0.12, 0.28)
			card_rect.add_child(bg)

		var dist: float = float(i) - center_index
		var norm: float = 0.0 if count <= 1 else dist / maxf(center_index, 1.0)
		var angle_deg: float = norm * 8.0 # Góc đối xứng nhẹ -8..+8 độ, đều tăm tắp
		var pos_x: float = start_x + float(i) * spacing - (card_w * 0.5)
		var pos_y: float = 4.0 + absf(norm) * 8.0

		card_rect.position = Vector2(pos_x, pos_y)
		card_rect.rotation_degrees = angle_deg
		card_rect.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
		card_rect.z_index = i
		opponent_hand_container.add_child(card_rect)

func _update_passive_slots_display() -> void:
	var viewer: PieceData.Team = _get_viewer_team()
	var opp: PieceData.Team = _get_opponent_viewer_team()
	_update_team_passive_row(player_passive_row, viewer, true)
	_update_team_passive_row(opponent_passive_row, opp, false)

func _update_team_passive_row(row: Control, team: PieceData.Team, face_up: bool = true) -> void:
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

		# GlowBorder bật kèm Pulse Glow nhịp thở khi is_ready_to_trigger == true
		if glow_border != null:
			_set_passive_glow_pulse(slot_node, glow_border, is_ready and face_up)

		if has_card:
			var card: CardResource = slot_data["card"] as CardResource
			if face_up:
				# Phe mình thấy rõ mặt bài kèm nhãn "ĐÃ ÚP" phía trên không đè bài
				if card_back != null:
					card_back.visible = false
				if slot_lbl != null:
					slot_lbl.visible = false
				if status_tag != null:
					status_tag.visible = true

				_render_card_into_container(card_container, card)
			else:
				# Đối thủ úp mặt lưng the_moon_back.png (Fog of war)
				if card_back != null:
					card_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					if ResourceLoader.exists(CARD_BACK_PASSIVE_PATH):
						card_back.texture = load(CARD_BACK_PASSIVE_PATH) as Texture2D
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
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35, 1.0))
		tag.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
		tag.add_theme_constant_override("outline_size", 3)
		tag.text = "ĐÃ ÚP"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.visible = false
		slot_node.add_child(tag)
	# Đặt gọn phía TRÊN ngoài khung lá bài để không che tên/tranh bài
	tag.set_anchors_preset(PRESET_TOP_WIDE)
	tag.offset_left = 0.0
	tag.offset_top = -18.0
	tag.offset_right = 0.0
	tag.offset_bottom = -2.0
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.z_index = 5
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
		card_node.custom_minimum_size = Vector2(CardHandView.CARD_WIDTH, CardHandView.CARD_HEIGHT)
		card_node.size = Vector2(CardHandView.CARD_WIDTH, CardHandView.CARD_HEIGHT)
		var avail: Vector2 = container.size
		if avail.x < 20.0 or avail.y < 20.0:
			var parent_ctrl: Control = container.get_parent() as Control
			if parent_ctrl != null and parent_ctrl.custom_minimum_size.x > 20.0:
				avail = parent_ctrl.custom_minimum_size
			else:
				avail = Vector2(148.0, 206.0)
		var fit_scale: float = minf((avail.x - 4.0) / CardHandView.CARD_WIDTH, (avail.y - 4.0) / CardHandView.CARD_HEIGHT)
		fit_scale = clampf(fit_scale, 0.55, 1.0)
		card_node.scale = Vector2(fit_scale, fit_scale)
		var scaled_w: float = CardHandView.CARD_WIDTH * fit_scale
		var scaled_h: float = CardHandView.CARD_HEIGHT * fit_scale
		card_node.position = Vector2((avail.x - scaled_w) * 0.5, (avail.y - scaled_h) * 0.5)
		card_node.set_meta("card_id", card.id)
		_populate_card_ui(card_node, card)
		container.add_child(card_node)

func _set_passive_glow_pulse(slot_node: Control, glow_border: ReferenceRect, active: bool) -> void:
	var key: int = slot_node.get_instance_id()
	if not active:
		if _passive_glow_tweens.has(key):
			var old_tw: Tween = _passive_glow_tweens[key] as Tween
			if old_tw != null and old_tw.is_valid():
				old_tw.kill()
			_passive_glow_tweens.erase(key)
		glow_border.visible = false
		glow_border.modulate = Color.WHITE
		glow_border.material = null
		return

	glow_border.visible = true
	if ResourceLoader.exists(SHADER_PASSIVE_PULSE) and glow_border.material == null:
		var pulse_shader: Shader = load(SHADER_PASSIVE_PULSE) as Shader
		if pulse_shader != null:
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = pulse_shader
			glow_border.material = mat

	if slot_node.is_inside_tree():
		var existing_tw: Tween = _passive_glow_tweens.get(key, null) as Tween
		if existing_tw == null or not existing_tw.is_valid():
			glow_border.modulate = Color(1.0, 0.94, 0.65, 1.0)
			var tw: Tween = glow_border.create_tween()
			tw.set_loops()
			tw.set_trans(Tween.TRANS_SINE)
			tw.set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(glow_border, "modulate:a", 0.40, 0.65)
			tw.tween_property(glow_border, "modulate:a", 1.0, 0.65)
			_passive_glow_tweens[key] = tw

func _populate_card_ui(node: Control, card: CardResource) -> void:
	CardHandView.populate_card_node(node, card)

func _animate_active_slot_trigger(team: PieceData.Team, card: CardResource) -> void:
	var is_viewer: bool = (team == _get_viewer_team())
	var slot: Control = player_active_slot if is_viewer else opponent_active_slot
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

	# Full-board shaders (Death Ring / Holy War)
	if turn_manager.death_ring_system.is_death_ring_active:
		board_view.apply_board_shader(SHADER_DEATH_RING)
	elif turn_manager.death_ring_system.is_holy_war_active:
		board_view.apply_board_shader(SHADER_HOLY_WAR)
	else:
		board_view.remove_board_shader()

	# River barrier overlay (rank 4-5) - coexists with full-board & per-tile shaders
	var river_on: bool = turn_manager.board.river_barrier_active or turn_manager.board.river_barrier_turns > 0
	board_view.set_river_barrier_visible(river_on)

func _check_and_display_event_banners() -> void:
	if turn_manager == null:
		return

	if turn_manager.is_game_over:
		var win_team: String = "TRẮNG THẮNG!" if turn_manager.winner == 0 else ("ĐEN THẮNG!" if turn_manager.winner == 1 else "HÒA NHAU!")
		show_message("TRẬN ĐẤU KẾT THÚC! %s (%s)" % [win_team, turn_manager.game_over_reason])
		return

	if turn_manager.double_move_piece_pos != Vector2i(-1, -1):
		show_message("SONG TRÙNG: ĐI TIẾP NƯỚC THỨ 2!")
		return

	if turn_manager.forced_king_move_team == int(turn_manager.current_turn_team):
		show_message("THOÁT HIỂM HOÀNG CUNG: BẮT BUỘC PHẢI DI CHUYỂN VUA!")
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

	var viewer: PieceData.Team = _get_viewer_team()
	var viewer_engine: CardEngine = turn_manager.white_engine if viewer == PieceData.Team.WHITE else turn_manager.black_engine
	if viewer_engine.has_pending_draw():
		show_message("ĐẾN LƯỢT RÚT BÀI — BẤM VÀO DECK ĐỂ RÚT!")
		return

# -------------------------------------------------------------
# Temporary 2-Machine LAN PvP Test Mode Hooks
# -------------------------------------------------------------

func on_lan_mode_changed(active: bool, p_local_team: PieceData.Team) -> void:
	lan_mode = active
	local_team = p_local_team
	if board_view != null:
		board_view.set_flipped(lan_mode and local_team == PieceData.Team.BLACK)
		board_view.allowed_control_team = int(local_team) if lan_mode else -1
	_cancel_card_selection(false)
	_update_all_ui()

func start_synced_lan_game(white_deck: Array[CardResource], black_deck: Array[CardResource], p_local_team: PieceData.Team) -> void:
	lan_mode = true
	local_team = p_local_team
	turn_manager = TurnManager.new()
	turn_manager.white_engine.set_custom_deck(white_deck)
	turn_manager.black_engine.set_custom_deck(black_deck)
	turn_manager.white_engine.manual_draw_mode = true
	turn_manager.black_engine.manual_draw_mode = true
	turn_manager.start_game()

	if board_view != null:
		board_view.setup(turn_manager, board_view.tiles_grid)
		board_view.set_flipped(local_team == PieceData.Team.BLACK)
		board_view.allowed_control_team = int(local_team)

	_clear_active_slot_visual(player_active_slot)
	_clear_active_slot_visual(opponent_active_slot)
	_cancel_card_selection(false)
	_update_all_ui()
	var side_str: String = "TRẮNG" if local_team == PieceData.Team.WHITE else "ĐEN"
	show_message("LAN PVP SẴN SÀNG! BẠN ĐIỀU KHIỂN PHE %s" % side_str)

func _clear_active_slot_visual(slot: Control) -> void:
	if slot == null:
		return
	var container: Control = slot.find_child("CardContainer", true, false) as Control
	_clear_container(container)
	var lbl: Label = slot.find_child("SlotLabel", true, false) as Label
	if lbl != null:
		lbl.visible = true
	var glow: ReferenceRect = slot.find_child("GlowBorder", true, false) as ReferenceRect
	if glow != null:
		glow.visible = false

func apply_remote_move(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if turn_manager == null:
		return
	_is_applying_remote = true
	var ok: bool = turn_manager.execute_move(from_pos, to_pos)
	if ok:
		_on_move_executed(from_pos, to_pos)
	_is_applying_remote = false

func apply_remote_play_active(card_id: String, targets: Array) -> void:
	if turn_manager == null:
		return
	_is_applying_remote = true
	var engine: CardEngine = turn_manager.get_current_engine()
	var found: CardResource = null
	for c in engine.hand:
		if c.id == card_id:
			found = c
			break
	if found != null:
		var cast_team: PieceData.Team = turn_manager.current_turn_team
		var ok: bool = turn_manager.play_active_card(found, Vector2i(-1, -1), Vector2i(-1, -1), targets)
		if ok:
			_animate_active_slot_trigger(cast_team, found)
			_play_vfx_for_card_cast(found, cast_team, targets, Vector2.ZERO, true)
			show_message("ĐỐI THỦ KÍCH HOẠT: %s!" % found.title)
		else:
			show_message("LÁ ACTIVE CỦA ĐỐI THỦ BỊ PHẢN ĐÒN!")
	_update_all_ui()
	_is_applying_remote = false

func apply_remote_place_passive(card_id: String) -> void:
	if turn_manager == null:
		return
	_is_applying_remote = true
	var engine: CardEngine = turn_manager.get_current_engine()
	for c in engine.hand:
		if c.id == card_id:
			turn_manager.place_passive_card(c)
			show_message("ĐỐI THỦ VỪA ÚP 1 LÁ BẪY PASSIVE!")
			break
	_update_all_ui()
	_is_applying_remote = false

func apply_remote_trigger_passive(team: PieceData.Team, slot_index: int, targets: Array) -> void:
	if turn_manager == null:
		return
	_is_applying_remote = true
	var slots: Array[Dictionary] = turn_manager.passive_manager.get_slots(team)
	var card: CardResource = slots[slot_index].get("card", null) as CardResource if slot_index < slots.size() else null
	var res: Dictionary = turn_manager.execute_passive_trigger(team, slot_index, targets)
	if res.get("success", false) and card != null:
		show_message("ĐỐI THỦ KÍCH HOẠT BẪY: %s!" % card.title)
		_play_vfx_for_card_cast(card, team, targets, Vector2.ZERO, false)
	_update_all_ui()
	_is_applying_remote = false

func apply_remote_claim_draw(team: PieceData.Team) -> void:
	if turn_manager == null:
		return
	_is_applying_remote = true
	var engine: CardEngine = turn_manager.white_engine if team == PieceData.Team.WHITE else turn_manager.black_engine
	engine.claim_pending_draw()
	_update_all_ui()
	_is_applying_remote = false

func apply_remote_end_turn() -> void:
	if turn_manager == null:
		return
	_is_applying_remote = true
	turn_manager.end_turn()
	_update_all_ui()
	_is_applying_remote = false

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
	var is_player_side: bool = true
	var controller: GameController

	func _resolve_team() -> PieceData.Team:
		if controller == null:
			return PieceData.Team.WHITE if is_player_side else PieceData.Team.BLACK
		return controller._get_viewer_team() if is_player_side else controller._get_opponent_viewer_team()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and controller != null:
				var team: PieceData.Team = _resolve_team()
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
		var team: PieceData.Team = _resolve_team()
		if slot_type == "active":
			controller.handle_active_slot_action(team, card)
		else:
			controller.handle_passive_slot_action(team, slot_index, card)

# --- CardInspector (Soi bài cỡ lớn sắc nét NEAREST khi hover) ---
class CardInspector extends Control:
	const VIEWPORT_BOUNDS: Vector2 = Vector2(1920.0, 1080.0)
	const PREVIEW_W: float = 296.0
	const PREVIEW_H: float = 412.0
	const COLOR_PARCHMENT: Color = Color("#F5EFE6")
	const COLOR_INK: Color = Color(0.102, 0.102, 0.114, 1.0)
	const COLOR_BORDER: Color = Color("#121014")

	var _card_holder: Control
	var _art_icon: TextureRect
	var _frame_rect: TextureRect
	var _title_label: Label
	var _desc_panel: PanelContainer
	var _desc_title: Label
	var _desc_body: Label

	func _init() -> void:
		name = "CardInspector"
		z_index = 190
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visible = false
		_build_ui()

	func _build_ui() -> void:
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.name = "InspectorVBox"
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 8)
		add_child(vbox)

		_card_holder = Control.new()
		_card_holder.name = "CardPreview"
		_card_holder.custom_minimum_size = Vector2(PREVIEW_W, PREVIEW_H)
		_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(_card_holder)

		_art_icon = TextureRect.new()
		_art_icon.name = "ArtIcon"
		_art_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_art_icon.clip_contents = true
		_art_icon.set_anchors_preset(PRESET_TOP_WIDE)
		_art_icon.offset_left = 12.0
		_art_icon.offset_top = 56.0
		_art_icon.offset_right = -12.0
		_art_icon.offset_bottom = 252.0
		_art_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_card_holder.add_child(_art_icon)

		_frame_rect = TextureRect.new()
		_frame_rect.name = "CardFrame"
		_frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_frame_rect.set_anchors_preset(PRESET_FULL_RECT)
		_frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_card_holder.add_child(_frame_rect)

		_title_label = Label.new()
		_title_label.name = "TitleLabel"
		_title_label.set_anchors_preset(PRESET_TOP_WIDE)
		_title_label.offset_left = 56.0
		_title_label.offset_top = 16.0
		_title_label.offset_right = -48.0
		_title_label.offset_bottom = 52.0
		_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title_label.clip_text = true
		_title_label.add_theme_font_size_override("font_size", 18)
		_title_label.add_theme_color_override("font_color", COLOR_INK)
		_card_holder.add_child(_title_label)

		var card_desc: Label = Label.new()
		card_desc.name = "CardDescPreview"
		card_desc.set_anchors_preset(PRESET_FULL_RECT)
		card_desc.offset_left = 20.0
		card_desc.offset_top = 268.0
		card_desc.offset_right = -20.0
		card_desc.offset_bottom = -32.0
		card_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_desc.clip_text = true
		card_desc.add_theme_font_size_override("font_size", 14)
		card_desc.add_theme_color_override("font_color", COLOR_INK)
		_card_holder.add_child(card_desc)

		_desc_panel = PanelContainer.new()
		_desc_panel.name = "InspectorDescPanel"
		_desc_panel.custom_minimum_size = Vector2(PREVIEW_W, 0.0)
		_desc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = COLOR_PARCHMENT
		sb.border_color = COLOR_BORDER
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 12.0
		sb.content_margin_top = 10.0
		sb.content_margin_right = 12.0
		sb.content_margin_bottom = 10.0
		_desc_panel.add_theme_stylebox_override("panel", sb)
		vbox.add_child(_desc_panel)

		var dv: VBoxContainer = VBoxContainer.new()
		dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dv.add_theme_constant_override("separation", 4)
		_desc_panel.add_child(dv)

		_desc_title = Label.new()
		_desc_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_desc_title.add_theme_font_size_override("font_size", 16)
		_desc_title.add_theme_color_override("font_color", COLOR_INK)
		dv.add_child(_desc_title)

		_desc_body = Label.new()
		_desc_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_desc_body.custom_minimum_size = Vector2(PREVIEW_W - 24.0, 0.0)
		_desc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc_body.add_theme_font_size_override("font_size", 14)
		_desc_body.add_theme_color_override("font_color", COLOR_INK)
		dv.add_child(_desc_body)

	func show_card(card: CardResource, anchor_global_rect: Rect2) -> void:
		if card == null:
			hide_inspector()
			return
		var is_act: bool = card.is_active()
		var frame_path: String = GameController.FRAME_ACTIVE_PATH if is_act else GameController.FRAME_PASSIVE_PATH
		if ResourceLoader.exists(frame_path):
			_frame_rect.texture = load(frame_path) as Texture2D
		if card.icon_path != "" and ResourceLoader.exists(card.icon_path):
			_art_icon.texture = load(card.icon_path) as Texture2D
		else:
			_art_icon.texture = null

		_title_label.text = card.title
		var card_desc: Label = _card_holder.get_node_or_null("CardDescPreview") as Label
		if card_desc != null:
			card_desc.text = card.description

		var kind_tag: String = "ACTIVE • THE SUN" if is_act else "PASSIVE • THE MOON"
		_desc_title.text = "%s (%s)" % [card.title, kind_tag]
		_desc_body.text = card.description
		visible = true
		reset_size()

		var vp: Vector2 = VIEWPORT_BOUNDS
		if is_inside_tree() and get_viewport_rect().size.x > 0.0:
			vp = get_viewport_rect().size
		var box_size: Vector2 = get_combined_minimum_size()
		var target_x: float = anchor_global_rect.end.x + 16.0
		if target_x + box_size.x > vp.x - 16.0:
			target_x = anchor_global_rect.position.x - box_size.x - 16.0
		var target_y: float = anchor_global_rect.position.y - box_size.y - 16.0
		if target_y < 16.0:
			target_y = anchor_global_rect.position.y - box_size.y * 0.35
		target_x = clampf(target_x, 16.0, maxf(16.0, vp.x - box_size.x - 16.0))
		target_y = clampf(target_y, 16.0, maxf(16.0, vp.y - box_size.y - 16.0))
		global_position = Vector2(target_x, target_y)

	func hide_inspector() -> void:
		visible = false
