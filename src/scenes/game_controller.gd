# res://src/scenes/game_controller.gd
# GDScript / game_controller.gd / Godot 4.7 / Main Game Scene Controller
class_name GameController
extends Control

# Core Systems
var turn_manager: TurnManager
var board_view: BoardView
var card_hand_view: CardHandView

# UI Node References
var chessboard_node: Control
var hand_container: Control
var deck_slot: Control
var deck_label: Label

var player_active_slot: Control
var opponent_active_slot: Control
var player_passive_row: Control
var opponent_passive_row: Control

var player_score_label: Label
var opponent_score_label: Label
var turn_phase_label: Label
var message_banner: Label
var end_turn_button: Button

# Interaction State
var selected_card: CardResource = null
var selected_piece_pos: Vector2i = Vector2i(-1, -1)

# Shader paths
const SHADER_DEATH_RING: String = "res://assets/shaders/death_ring.gdshader"
const SHADER_RIVER_BARRIER: String = "res://assets/shaders/river_barrier.gdshader"
const SHADER_BARRIER_BURN: String = "res://assets/shaders/barrier_burn.gdshader"
const SHADER_HOLY_WAR: String = "res://assets/shaders/holy_war.gdshader"
const SHADER_STEALTH: String = "res://assets/shaders/stealth.gdshader"

# Sprites
const CARD_BACK_PATH: String = "res://assets/sprites/cards/card_back.svg"
const DECK_PILE_PATH: String = "res://assets/sprites/cards/deck_pile.svg"

func _ready() -> void:
	custom_minimum_size = Vector2(1920.0, 1080.0)
	setup_game()

func setup_game() -> void:
	if turn_manager == null:
		turn_manager = TurnManager.new()
		turn_manager.start_game()

	_ensure_ui_structure()
	_connect_signals()
	_update_all_ui()

func _ensure_ui_structure() -> void:
	# 1. Background
	var bg: ColorRect = find_child("Background", true, false) as ColorRect
	if bg == null:
		bg = ColorRect.new()
		bg.name = "Background"
		bg.set_anchors_preset(PRESET_FULL_RECT)
		bg.color = Color(0.06, 0.06, 0.07, 1.0)
		add_child(bg)
		move_child(bg, 0)

	# 2. Chessboard Area (Left)
	chessboard_node = find_child("Chessboard", true, false) as Control
	if chessboard_node == null:
		var cb_area: Control = find_child("ChessboardArea", true, false) as Control
		if cb_area == null:
			cb_area = Control.new()
			cb_area.name = "ChessboardArea"
			cb_area.offset_left = 60.0
			cb_area.offset_top = 40.0
			cb_area.offset_right = 860.0
			cb_area.offset_bottom = 840.0
			add_child(cb_area)

		# Try instantiating res://assets/ui/chessboard.tscn
		if ResourceLoader.exists("res://assets/ui/chessboard.tscn"):
			var cb_scene: PackedScene = load("res://assets/ui/chessboard.tscn") as PackedScene
			if cb_scene != null:
				chessboard_node = cb_scene.instantiate() as Control
				cb_area.add_child(chessboard_node)

		if chessboard_node == null:
			chessboard_node = Control.new()
			chessboard_node.name = "Chessboard"
			chessboard_node.set_anchors_preset(PRESET_FULL_RECT)
			cb_area.add_child(chessboard_node)

	# Attach BoardView logic to Chessboard
	board_view = chessboard_node.get_node_or_null("BoardViewComponent") as BoardView
	if board_view == null:
		board_view = BoardView.new()
		board_view.name = "BoardViewComponent"
		board_view.set_anchors_preset(PRESET_FULL_RECT)
		chessboard_node.add_child(board_view)

	var tiles_grid: GridContainer = chessboard_node.find_child("TilesGrid", true, false) as GridContainer
	board_view.setup(turn_manager, tiles_grid)

	# 3. Bottom Area (HandContainer & DeckSlot)
	var bottom_area: Control = find_child("BottomArea", true, false) as Control
	if bottom_area == null:
		bottom_area = Control.new()
		bottom_area.name = "BottomArea"
		bottom_area.offset_left = 60.0
		bottom_area.offset_top = 860.0
		bottom_area.offset_right = 940.0
		bottom_area.offset_bottom = 1060.0
		add_child(bottom_area)

	hand_container = bottom_area.find_child("HandContainer", true, false) as Control
	if hand_container == null:
		hand_container = Control.new()
		hand_container.name = "HandContainer"
		hand_container.offset_left = 0.0
		hand_container.offset_top = 0.0
		hand_container.offset_right = 720.0
		hand_container.offset_bottom = 200.0
		bottom_area.add_child(hand_container)

	card_hand_view = hand_container.get_node_or_null("CardHandViewComponent") as CardHandView
	if card_hand_view == null:
		card_hand_view = CardHandView.new()
		card_hand_view.name = "CardHandViewComponent"
		card_hand_view.set_anchors_preset(PRESET_FULL_RECT)
		hand_container.add_child(card_hand_view)

	card_hand_view.setup(turn_manager, turn_manager.current_turn_team)

	deck_slot = bottom_area.find_child("DeckSlot", true, false) as Control
	if deck_slot == null:
		var btn: Button = Button.new()
		btn.name = "DeckSlot"
		btn.offset_left = 730.0
		btn.offset_top = 10.0
		btn.offset_right = 870.0
		btn.offset_bottom = 190.0
		btn.flat = true
		bottom_area.add_child(btn)
		deck_slot = btn

		# Background / Icon
		var tex: TextureRect = TextureRect.new()
		tex.name = "DeckTexture"
		tex.set_anchors_preset(PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(DECK_PILE_PATH):
			tex.texture = load(DECK_PILE_PATH) as Texture2D
		elif ResourceLoader.exists(CARD_BACK_PATH):
			tex.texture = load(CARD_BACK_PATH) as Texture2D
		deck_slot.add_child(tex)

	deck_label = deck_slot.find_child("DeckLabel", true, false) as Label
	if deck_label == null:
		deck_label = Label.new()
		deck_label.name = "DeckLabel"
		deck_label.set_anchors_preset(PRESET_BOTTOM_WIDE)
		deck_label.offset_top = -30.0
		deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deck_label.add_theme_font_size_override("font_size", 12)
		deck_slot.add_child(deck_label)

	# 4. Right Area (Zones)
	var right_area: Control = find_child("RightArea", true, false) as Control
	if right_area == null:
		right_area = Control.new()
		right_area.name = "RightArea"
		right_area.offset_left = 980.0
		right_area.offset_top = 40.0
		right_area.offset_right = 1860.0
		right_area.offset_bottom = 1040.0
		add_child(right_area)

	# 4.1. TopPlayerZone (Opponent / Black)
	var top_zone: Control = find_child("TopPlayerZone", true, false) as Control
	if top_zone == null:
		top_zone = Control.new()
		top_zone.name = "TopPlayerZone"
		top_zone.offset_left = 0.0
		top_zone.offset_top = 0.0
		top_zone.offset_right = 880.0
		top_zone.offset_bottom = 260.0
		right_area.add_child(top_zone)

	opponent_score_label = top_zone.find_child("OpponentScoreLabel", true, false) as Label
	if opponent_score_label == null:
		opponent_score_label = Label.new()
		opponent_score_label.name = "OpponentScoreLabel"
		opponent_score_label.offset_left = 20.0
		opponent_score_label.offset_top = 10.0
		opponent_score_label.offset_right = 400.0
		opponent_score_label.offset_bottom = 40.0
		opponent_score_label.add_theme_font_size_override("font_size", 18)
		top_zone.add_child(opponent_score_label)

	opponent_passive_row = top_zone.find_child("OpponentPassiveRow", true, false) as Control
	if opponent_passive_row == null:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "OpponentPassiveRow"
		row.offset_left = 20.0
		row.offset_top = 50.0
		row.offset_right = 500.0
		row.offset_bottom = 210.0
		row.add_theme_constant_override("separation", 10)
		top_zone.add_child(row)
		opponent_passive_row = row
		_populate_passive_row_slots(row, PieceData.Team.BLACK)

	opponent_active_slot = top_zone.find_child("OpponentActiveSlot", true, false) as Control
	if opponent_active_slot == null:
		opponent_active_slot = _create_active_slot("OpponentActiveSlot", PieceData.Team.BLACK)
		opponent_active_slot.offset_left = 520.0
		opponent_active_slot.offset_top = 50.0
		top_zone.add_child(opponent_active_slot)

	# 4.2. CenterControlZone
	var center_zone: Control = find_child("CenterControlZone", true, false) as Control
	if center_zone == null:
		center_zone = Control.new()
		center_zone.name = "CenterControlZone"
		center_zone.offset_left = 0.0
		center_zone.offset_top = 280.0
		center_zone.offset_right = 880.0
		center_zone.offset_bottom = 600.0
		right_area.add_child(center_zone)

	turn_phase_label = center_zone.find_child("TurnPhaseLabel", true, false) as Label
	if turn_phase_label == null:
		turn_phase_label = Label.new()
		turn_phase_label.name = "TurnPhaseLabel"
		turn_phase_label.offset_left = 40.0
		turn_phase_label.offset_top = 20.0
		turn_phase_label.offset_right = 840.0
		turn_phase_label.offset_bottom = 60.0
		turn_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		turn_phase_label.add_theme_font_size_override("font_size", 22)
		center_zone.add_child(turn_phase_label)

	message_banner = center_zone.find_child("MessageBanner", true, false) as Label
	if message_banner == null:
		message_banner = Label.new()
		message_banner.name = "MessageBanner"
		message_banner.offset_left = 40.0
		message_banner.offset_top = 80.0
		message_banner.offset_right = 840.0
		message_banner.offset_bottom = 150.0
		message_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		message_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message_banner.add_theme_font_size_override("font_size", 20)
		message_banner.add_theme_color_override("font_color", Color(0.83, 0.69, 0.22)) # Gold
		center_zone.add_child(message_banner)

	end_turn_button = center_zone.find_child("EndTurnButton", true, false) as Button
	if end_turn_button == null:
		end_turn_button = Button.new()
		end_turn_button.name = "EndTurnButton"
		end_turn_button.text = "END TURN"
		end_turn_button.offset_left = 320.0
		end_turn_button.offset_top = 180.0
		end_turn_button.offset_right = 560.0
		end_turn_button.offset_bottom = 240.0
		end_turn_button.add_theme_font_size_override("font_size", 18)
		center_zone.add_child(end_turn_button)

	# 4.3. BottomPlayerZone (Player / White)
	var bottom_zone: Control = find_child("BottomPlayerZone", true, false) as Control
	if bottom_zone == null:
		bottom_zone = Control.new()
		bottom_zone.name = "BottomPlayerZone"
		bottom_zone.offset_left = 0.0
		bottom_zone.offset_top = 620.0
		bottom_zone.offset_right = 880.0
		bottom_zone.offset_bottom = 980.0
		right_area.add_child(bottom_zone)

	player_active_slot = bottom_zone.find_child("PlayerActiveSlot", true, false) as Control
	if player_active_slot == null:
		player_active_slot = _create_active_slot("PlayerActiveSlot", PieceData.Team.WHITE)
		player_active_slot.offset_left = 20.0
		player_active_slot.offset_top = 50.0
		bottom_zone.add_child(player_active_slot)

	player_passive_row = bottom_zone.find_child("PlayerPassiveRow", true, false) as Control
	if player_passive_row == null:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "PlayerPassiveRow"
		row.offset_left = 200.0
		row.offset_top = 50.0
		row.offset_right = 680.0
		row.offset_bottom = 210.0
		row.add_theme_constant_override("separation", 10)
		bottom_zone.add_child(row)
		player_passive_row = row
		_populate_passive_row_slots(row, PieceData.Team.WHITE)

	player_score_label = bottom_zone.find_child("PlayerScoreLabel", true, false) as Label
	if player_score_label == null:
		player_score_label = Label.new()
		player_score_label.name = "PlayerScoreLabel"
		player_score_label.offset_left = 20.0
		player_score_label.offset_top = 220.0
		player_score_label.offset_right = 400.0
		player_score_label.offset_bottom = 250.0
		player_score_label.add_theme_font_size_override("font_size", 18)
		bottom_zone.add_child(player_score_label)

func _create_active_slot(slot_name: String, team: PieceData.Team) -> Control:
	var root: Control = null
	if ResourceLoader.exists("res://assets/ui/active_slot.tscn"):
		var scn: PackedScene = load("res://assets/ui/active_slot.tscn") as PackedScene
		if scn != null:
			root = scn.instantiate() as Control

	if root == null:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(150, 210)
		btn.flat = true

		var bg: ColorRect = ColorRect.new()
		bg.name = "SlotBackground"
		bg.set_anchors_preset(PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.color = Color(0.09, 0.08, 0.12, 0.9)
		btn.add_child(bg)

		var lbl: Label = Label.new()
		lbl.name = "SlotLabel"
		lbl.text = "ACTIVE SPELL\nSLOT"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(PRESET_FULL_RECT)
		lbl.add_theme_font_size_override("font_size", 12)
		btn.add_child(lbl)

		root = btn

	root.name = slot_name
	if root is Button:
		(root as Button).pressed.connect(func(): _on_active_slot_clicked(team))
	else:
		root.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				_on_active_slot_clicked(team)
		)

	return root

func _populate_passive_row_slots(row_container: Control, team: PieceData.Team) -> void:
	for i in range(4):
		var slot_ctrl: Control = null
		if ResourceLoader.exists("res://assets/ui/passive_slot.tscn"):
			var scn: PackedScene = load("res://assets/ui/passive_slot.tscn") as PackedScene
			if scn != null:
				slot_ctrl = scn.instantiate() as Control

		if slot_ctrl == null:
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(100, 140)
			btn.flat = true

			var bg: ColorRect = ColorRect.new()
			bg.name = "SlotBackground"
			bg.set_anchors_preset(PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.color = Color(0.10, 0.08, 0.16, 0.8)
			btn.add_child(bg)

			var lbl: Label = Label.new()
			lbl.name = "SlotLabel"
			lbl.text = "PASSIVE %d" % (i + 1)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.set_anchors_preset(PRESET_FULL_RECT)
			lbl.add_theme_font_size_override("font_size", 11)
			btn.add_child(lbl)

			var back_tex: TextureRect = TextureRect.new()
			back_tex.name = "CardBackTexture"
			back_tex.set_anchors_preset(PRESET_FULL_RECT)
			back_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			back_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			back_tex.visible = false
			if ResourceLoader.exists(CARD_BACK_PATH):
				back_tex.texture = load(CARD_BACK_PATH) as Texture2D
			btn.add_child(back_tex)

			slot_ctrl = btn

		slot_ctrl.name = "PassiveSlot_%d" % i
		row_container.add_child(slot_ctrl)

		var slot_idx: int = i
		if slot_ctrl is Button:
			(slot_ctrl as Button).pressed.connect(func(): _on_passive_slot_clicked(team, slot_idx))
		else:
			slot_ctrl.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and ev.pressed:
					_on_passive_slot_clicked(team, slot_idx)
			)

func _connect_signals() -> void:
	if board_view != null:
		if not board_view.tile_clicked.is_connected(_on_tile_clicked):
			board_view.tile_clicked.connect(_on_tile_clicked)
		if not board_view.move_executed.is_connected(_on_move_executed):
			board_view.move_executed.connect(_on_move_executed)

	if card_hand_view != null:
		if not card_hand_view.card_selected.is_connected(_on_card_selected):
			card_hand_view.card_selected.connect(_on_card_selected)
		if not card_hand_view.card_deselected.is_connected(_on_card_deselected):
			card_hand_view.card_deselected.connect(_on_card_deselected)

	if end_turn_button != null:
		if not end_turn_button.pressed.is_connected(_on_end_turn_button_pressed):
			end_turn_button.pressed.connect(_on_end_turn_button_pressed)

	if deck_slot != null:
		if deck_slot is Button:
			if not (deck_slot as Button).pressed.is_connected(_on_deck_slot_clicked):
				(deck_slot as Button).pressed.connect(_on_deck_slot_clicked)
		else:
			deck_slot.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and ev.pressed:
					_on_deck_slot_clicked()
			)

# -------------------------------------------------------------
# Interactions
# -------------------------------------------------------------

func _on_tile_clicked(pos: Vector2i) -> void:
	# If an active card is currently selected and clicked on board, attempt targeted cast
	if selected_card != null and selected_card.is_active():
		var engine: CardEngine = turn_manager.get_current_engine()
		if engine.can_play_active(selected_card):
			var ok: bool = turn_manager.play_active_card(selected_card, pos)
			if ok:
				show_message("ĐÃ KÍCH HOẠT: %s TẠI Ô (%d, %d)" % [selected_card.title, pos.x, pos.y])
				selected_card = null
				card_hand_view.deselect_card()
				_update_all_ui()
				return

	# Normal chess piece selection / movement
	board_view.select_cell(pos)
	_update_all_ui()

func _on_move_executed(from_pos: Vector2i, to_pos: Vector2i) -> void:
	selected_piece_pos = Vector2i(-1, -1)
	_update_all_ui()

func _on_card_selected(card: CardResource) -> void:
	selected_card = card
	var kind: String = "ACTIVE" if card.is_active() else "PASSIVE"
	show_message("CHỌN: %s [%s] - Click Slot hoặc Ô Cờ để dùng" % [card.title, kind])

func _on_card_deselected(_card: CardResource) -> void:
	selected_card = null
	show_message("")

func _on_active_slot_clicked(team: PieceData.Team) -> void:
	if team != turn_manager.current_turn_team:
		show_message("CHỈ ĐƯỢC ĐÁNH VÀO Ô ACTIVE CỦA PHE MÌNH!")
		return

	if selected_card == null or not selected_card.is_active():
		show_message("HÃY CHỌN 1 LÁ BÀI ACTIVE TRÊN TAY!")
		return

	var engine: CardEngine = turn_manager.get_current_engine()
	if not engine.can_play_active(selected_card):
		show_message("LƯỢT NÀY BẠN ĐÃ DÙNG 1 LÁ BÀI ACTIVE!")
		return

	var target_pos: Vector2i = board_view.selected_cell
	var ok: bool = turn_manager.play_active_card(selected_card, target_pos)
	if ok:
		show_message("KÍCH HOẠT THÀNH CÔNG: %s!" % selected_card.title)
		_animate_active_slot_trigger(team, selected_card)
		selected_card = null
		card_hand_view.deselect_card()
		_update_all_ui()
	else:
		show_message("KÍCH HOẠT BỊ CHẶN HOẶC KHÔNG THÀNH CÔNG!")

func _on_passive_slot_clicked(team: PieceData.Team, slot_index: int) -> void:
	if team != turn_manager.current_turn_team:
		show_message("CHỈ ĐƯỢC ÚP VÀO Ô PASSIVE CỦA PHE MÌNH!")
		return

	if selected_card == null or selected_card.is_active():
		show_message("HÃY CHỌN 1 LÁ BÀI PASSIVE TRÊN TAY ĐỂ ÚP!")
		return

	var engine: CardEngine = turn_manager.get_current_engine()
	if not engine.can_place_passive(selected_card):
		show_message("LƯỢT NÀY BẠN ĐÃ ÚP 1 BÀI PASSIVE!")
		return

	var slots: Array[Dictionary] = turn_manager.passive_manager.get_slots(team)
	if slot_index < slots.size() and slots[slot_index].get("card") != null:
		show_message("Ô PASSIVE NÀY ĐÃ CÓ BÀI ÚP!")
		return

	var ok: bool = turn_manager.place_passive_card(selected_card)
	if ok:
		show_message("ĐÃ ÚP 1 LÁ BÀI PASSIVE!")
		selected_card = null
		card_hand_view.deselect_card()
		_update_all_ui()
	else:
		show_message("KHÔNG THỂ ÚP BÀI PASSIVE (ĐẦY 4 Ô HOẶC KHÔNG HỢP LỆ)!")

func _on_deck_slot_clicked() -> void:
	var engine: CardEngine = turn_manager.get_current_engine()
	show_message("CỌC BÀI RÚT CÒN %d LÁ (2 NƯỚC ĐI TỰ ĐỘNG BỐC 1 LÁ)" % engine.deck.size())

func _on_end_turn_button_pressed() -> void:
	selected_card = null
	if card_hand_view != null:
		card_hand_view.deselect_card()
	if board_view != null:
		board_view.deselect()

	turn_manager.end_turn()
	_update_all_ui()

# -------------------------------------------------------------
# Visual & State Synchronizations
# -------------------------------------------------------------

func _update_all_ui() -> void:
	if turn_manager == null:
		return

	_update_hud_labels()
	_update_deck_display()
	_update_passive_slots_display()
	_update_shaders()
	_check_and_display_event_banners()

	if card_hand_view != null:
		card_hand_view.setup(turn_manager, turn_manager.current_turn_team)

	if board_view != null:
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

func _update_passive_slots_display() -> void:
	_update_team_passive_row(player_passive_row, PieceData.Team.WHITE)
	_update_team_passive_row(opponent_passive_row, PieceData.Team.BLACK)

func _update_team_passive_row(row: Control, team: PieceData.Team) -> void:
	if row == null or turn_manager == null:
		return

	var slots: Array[Dictionary] = turn_manager.passive_manager.get_slots(team)
	var child_count: int = row.get_child_count()

	for i in range(mini(child_count, slots.size())):
		var slot_node: Control = row.get_child(i) as Control
		var card_back: TextureRect = slot_node.find_child("CardBackTexture", true, false) as TextureRect
		var slot_lbl: Label = slot_node.find_child("SlotLabel", true, false) as Label
		var has_card: bool = slots[i].get("card") != null

		if card_back != null:
			card_back.visible = has_card
		if slot_lbl != null:
			slot_lbl.visible = not has_card

func _animate_active_slot_trigger(team: PieceData.Team, card: CardResource) -> void:
	var slot: Control = player_active_slot if team == PieceData.Team.WHITE else opponent_active_slot
	if slot == null:
		return
	var lbl: Label = slot.find_child("SlotLabel", true, false) as Label
	if lbl != null:
		lbl.text = "ĐÃ ĐÁNH:\n" + card.title

func _update_shaders() -> void:
	if board_view == null or turn_manager == null:
		return

	# Priority of shaders on the board
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
