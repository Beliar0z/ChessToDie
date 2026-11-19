# res://src/scenes/card_hand_view.gd
# GDScript / card_hand_view.gd / Godot 4.7 / UI Hand View Component
class_name CardHandView
extends Control

signal card_selected(card: CardResource)
signal card_deselected(card: CardResource)
signal card_clicked(card: CardResource, card_node: Control)

const CARD_UI_SCENE_PATH: String = "res://assets/ui/card_ui.tscn"
const FRAME_ACTIVE_PATH: String = "res://assets/sprites/cards/card_frame_active.svg"
const FRAME_PASSIVE_PATH: String = "res://assets/sprites/cards/card_frame_passive.svg"

var turn_manager: TurnManager
var displayed_team: PieceData.Team = PieceData.Team.WHITE
var cards_container: HBoxContainer

var selected_card: CardResource = null
var selected_card_node: Control = null

# Map card_node -> CardResource
var card_node_map: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(700.0, 190.0)
	_ensure_cards_container()

func setup(p_turn_manager: TurnManager, p_team: PieceData.Team, p_container: HBoxContainer = null) -> void:
	turn_manager = p_turn_manager
	displayed_team = p_team
	if p_container != null:
		cards_container = p_container
	_ensure_cards_container()
	refresh_hand()

func _ensure_cards_container() -> void:
	if cards_container == null:
		cards_container = find_child("CardsContainer", true, false) as HBoxContainer

	if cards_container == null:
		var parent_container: HBoxContainer = get_node_or_null("CardsContainer") as HBoxContainer
		if parent_container != null:
			cards_container = parent_container
		else:
			cards_container = HBoxContainer.new()
			cards_container.name = "CardsContainer"
			cards_container.set_anchors_preset(PRESET_FULL_RECT)
			cards_container.add_theme_constant_override("separation", 10)
			cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
			add_child(cards_container)

func refresh_hand() -> void:
	_ensure_cards_container()
	if cards_container == null or turn_manager == null:
		return

	# Clear previous card instances
	for child in cards_container.get_children():
		child.queue_free()
	card_node_map.clear()
	selected_card = null
	selected_card_node = null

	var engine: CardEngine = turn_manager.white_engine if displayed_team == PieceData.Team.WHITE else turn_manager.black_engine
	var cards: Array[CardResource] = engine.hand

	for card in cards:
		var card_ui: Control = _create_card_ui(card)
		cards_container.add_child(card_ui)
		card_node_map[card_ui] = card

func _create_card_ui(card: CardResource) -> Control:
	var card_node: Control = null
	if ResourceLoader.exists(CARD_UI_SCENE_PATH):
		var scene: PackedScene = load(CARD_UI_SCENE_PATH) as PackedScene
		if scene != null:
			card_node = scene.instantiate() as Control

	if card_node == null:
		# Graceful Fallback if card_ui.tscn is missing
		card_node = _create_fallback_card_ui(card)
	else:
		_populate_card_ui(card_node, card)

	card_node.custom_minimum_size = Vector2(130.0, 180.0)
	card_node.mouse_filter = Control.MOUSE_FILTER_PASS

	# Connect GUI input for click handling
	card_node.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_on_card_node_clicked(card, card_node)
	)

	return card_node

func _populate_card_ui(node: Control, card: CardResource) -> void:
	var title_lbl: Label = node.find_child("TitleLabel", true, false) as Label
	var desc_lbl: Label = node.find_child("DescLabel", true, false) as Label
	var cost_lbl: Label = node.find_child("CostLabel", true, false) as Label
	var frame_rect: TextureRect = node.find_child("CardFrame", true, false) as TextureRect
	var art_rect: TextureRect = node.find_child("ArtIcon", true, false) as TextureRect

	if title_lbl != null:
		title_lbl.text = card.title
	if desc_lbl != null:
		desc_lbl.text = card.description
	if cost_lbl != null:
		cost_lbl.text = str(card.cost) if card.cost > 0 else ""

	if frame_rect != null:
		var frame_path: String = FRAME_ACTIVE_PATH if card.is_active() else FRAME_PASSIVE_PATH
		if ResourceLoader.exists(frame_path):
			frame_rect.texture = load(frame_path) as Texture2D

	if art_rect != null and card.icon_path != "" and ResourceLoader.exists(card.icon_path):
		art_rect.texture = load(card.icon_path) as Texture2D

func _create_fallback_card_ui(card: CardResource) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Card_" + card.id
	panel.custom_minimum_size = Vector2(130.0, 180.0)

	var bg_color: Color = Color(0.12, 0.16, 0.24, 0.95) if card.is_active() else Color(0.20, 0.10, 0.28, 0.95)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(6)
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(0.83, 0.69, 0.22, 0.8) if card.is_active() else Color(0.60, 0.40, 0.85, 0.8)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = card.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title)

	var type_lbl: Label = Label.new()
	type_lbl.text = "ACTIVE" if card.is_active() else "PASSIVE"
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", 9)
	type_lbl.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(type_lbl)

	var desc: Label = Label.new()
	desc.text = card.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 9)
	vbox.add_child(desc)

	return panel

func _on_card_node_clicked(card: CardResource, node: Control) -> void:
	if selected_card == card:
		deselect_card()
	else:
		select_card(card, node)

func select_card(card: CardResource, node: Control) -> void:
	# Reset old selection visual
	if selected_card_node != null and is_instance_valid(selected_card_node):
		selected_card_node.position.y = 0.0
		selected_card_node.modulate = Color.WHITE

	selected_card = card
	selected_card_node = node

	if selected_card_node != null:
		selected_card_node.position.y = -16.0
		selected_card_node.modulate = Color(1.2, 1.2, 0.9, 1.0) # Brightened highlight

	card_selected.emit(card)
	card_clicked.emit(card, node)

func deselect_card() -> void:
	if selected_card_node != null and is_instance_valid(selected_card_node):
		selected_card_node.position.y = 0.0
		selected_card_node.modulate = Color.WHITE

	var prev_card: CardResource = selected_card
	selected_card = null
	selected_card_node = null

	if prev_card != null:
		card_deselected.emit(prev_card)
