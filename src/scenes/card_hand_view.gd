# res://src/scenes/card_hand_view.gd
# GDScript / card_hand_view.gd / Godot 4.7 / UI Component (Fan Arc Hand)
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
var cards_container: Control

var selected_card: CardResource = null
var selected_card_node: Control = null
var card_node_map: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(880.0, 220.0)
	_ensure_cards_container()

func setup(p_turn_manager: TurnManager, p_team: PieceData.Team, p_container: Control = null) -> void:
	turn_manager = p_turn_manager
	displayed_team = p_team
	if p_container != null:
		cards_container = p_container
	_ensure_cards_container()
	refresh_hand()

func _ensure_cards_container() -> void:
	if cards_container == null:
		cards_container = find_child("CardsContainer", true, false) as Control

	if cards_container != null and cards_container is HBoxContainer:
		cards_container.name = "OldCardsContainer"
		cards_container.queue_free()
		cards_container = null

	if cards_container == null:
		cards_container = Control.new()
		cards_container.name = "CardsContainer"
		cards_container.set_anchors_preset(PRESET_FULL_RECT)
		cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cards_container)

func refresh_hand() -> void:
	_ensure_cards_container()
	if cards_container == null or turn_manager == null:
		return

	for child in cards_container.get_children():
		child.queue_free()
	card_node_map.clear()
	selected_card = null
	selected_card_node = null

	var engine: CardEngine = turn_manager.white_engine if displayed_team == PieceData.Team.WHITE else turn_manager.black_engine
	var cards: Array[CardResource] = engine.hand
	var holders: Array[DraggableCardSlot] = []

	for card in cards:
		var holder: DraggableCardSlot = _create_card_ui(card)
		cards_container.add_child(holder)
		holders.append(holder)
		card_node_map[holder] = card

	_apply_fan_arc_layout(holders)

func _apply_fan_arc_layout(holders: Array[DraggableCardSlot]) -> void:
	var count: int = holders.size()
	if count == 0:
		return

	var card_width: float = 132.0
	var card_height: float = 196.0
	var center_index: float = float(count - 1) / 2.0
	var spacing: float = clampf(700.0 / maxf(float(count), 1.0), 50.0, 110.0)
	var total_width: float = spacing * float(count - 1)
	var container_w: float = custom_minimum_size.x if custom_minimum_size.x > 0.0 else size.x
	if container_w <= 0.0:
		container_w = 880.0
	var start_x: float = (container_w - total_width) * 0.5

	for i in range(count):
		var holder: DraggableCardSlot = holders[i]
		var dist: float = float(i) - center_index
		var norm: float = 0.0 if count <= 1 else dist / maxf(center_index, 1.0) # -1.0 to +1.0
		var angle_deg: float = norm * 14.0 # từ -14 đến +14 độ
		var pos_x: float = start_x + float(i) * spacing - (card_width * 0.5)
		var pos_y: float = 20.0 + absf(norm) * 22.0 # vòm nhô cao ở giữa

		holder.position = Vector2(pos_x, pos_y)
		holder.rotation_degrees = angle_deg
		holder.pivot_offset = Vector2(card_width * 0.5, card_height)
		holder.z_index = i
		holder.set_meta("base_pos", holder.position)
		holder.set_meta("base_rot", angle_deg)
		holder.set_meta("base_z", i)

func _create_card_ui(card: CardResource) -> DraggableCardSlot:
	var holder: DraggableCardSlot = DraggableCardSlot.new()
	holder.card_data = card
	holder.hand_view = self
	holder.custom_minimum_size = Vector2(132.0, 196.0)
	holder.size = Vector2(132.0, 196.0)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_node: Control = null
	if ResourceLoader.exists(CARD_UI_SCENE_PATH):
		var scene: PackedScene = load(CARD_UI_SCENE_PATH) as PackedScene
		if scene != null:
			card_node = scene.instantiate() as Control

	if card_node != null:
		card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_populate_card_ui(card_node, card)
		holder.add_child(card_node)
		holder.visual_node = card_node

	holder.mouse_entered.connect(func():
		_on_card_mouse_entered(holder)
	)
	holder.mouse_exited.connect(func():
		_on_card_mouse_exited(holder)
	)
	holder.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_on_card_node_clicked(card, holder)
	)

	return holder

func _on_card_mouse_entered(holder: DraggableCardSlot) -> void:
	holder.rotation_degrees = 0.0
	holder.scale = Vector2(1.28, 1.28)
	var base_pos: Vector2 = holder.get_meta("base_pos", holder.position)
	holder.position = Vector2(base_pos.x, base_pos.y - 45.0)
	holder.z_index = 50

func _on_card_mouse_exited(holder: DraggableCardSlot) -> void:
	var base_pos: Vector2 = holder.get_meta("base_pos", holder.position)
	var base_rot: float = float(holder.get_meta("base_rot", 0.0))
	var base_z: int = int(holder.get_meta("base_z", 0))

	holder.rotation_degrees = base_rot
	holder.scale = Vector2.ONE
	if selected_card == holder.card_data:
		holder.position = Vector2(base_pos.x, base_pos.y - 25.0)
		holder.z_index = base_z + 10
	else:
		holder.position = base_pos
		holder.z_index = base_z

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

func _on_card_node_clicked(card: CardResource, node: Control) -> void:
	if selected_card == card:
		deselect_card()
	else:
		select_card(card, node)

func select_card(card: CardResource, node: Control) -> void:
	if selected_card_node != null and is_instance_valid(selected_card_node):
		var old_base_pos: Vector2 = selected_card_node.get_meta("base_pos", selected_card_node.position)
		var old_rot: float = float(selected_card_node.get_meta("base_rot", 0.0))
		var old_z: int = int(selected_card_node.get_meta("base_z", 0))
		selected_card_node.rotation_degrees = old_rot
		selected_card_node.scale = Vector2.ONE
		selected_card_node.position = old_base_pos
		selected_card_node.modulate = Color.WHITE
		selected_card_node.z_index = old_z

	selected_card = card
	selected_card_node = node

	if selected_card_node != null and is_instance_valid(selected_card_node):
		var base_pos: Vector2 = selected_card_node.get_meta("base_pos", selected_card_node.position)
		selected_card_node.position = Vector2(base_pos.x, base_pos.y - 25.0)
		selected_card_node.modulate = Color(1.15, 1.15, 0.95, 1.0)
		selected_card_node.z_index = int(selected_card_node.get_meta("base_z", 0)) + 15

	card_selected.emit(card)
	card_clicked.emit(card, node)

func deselect_card() -> void:
	if selected_card_node != null and is_instance_valid(selected_card_node):
		var base_pos: Vector2 = selected_card_node.get_meta("base_pos", selected_card_node.position)
		var base_rot: float = float(selected_card_node.get_meta("base_rot", 0.0))
		var base_z: int = int(selected_card_node.get_meta("base_z", 0))
		selected_card_node.rotation_degrees = base_rot
		selected_card_node.scale = Vector2.ONE
		selected_card_node.position = base_pos
		selected_card_node.modulate = Color.WHITE
		selected_card_node.z_index = base_z

	var prev_card: CardResource = selected_card
	selected_card = null
	selected_card_node = null

	if prev_card != null:
		card_deselected.emit(prev_card)

class DraggableCardSlot extends Control:
	var card_data: CardResource
	var hand_view: CardHandView
	var visual_node: Control

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if card_data == null:
			return null
		if hand_view != null:
			hand_view.select_card(card_data, self)
		if visual_node != null:
			var dup: Control = visual_node.duplicate() as Control
			dup.position = Vector2(-66, -98)
			dup.modulate = Color(1, 1, 1, 0.85)
			var holder: Control = Control.new()
			holder.add_child(dup)
			set_drag_preview(holder)
		return {"type": "card", "card": card_data}
