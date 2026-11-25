# res://src/scenes/card_hand_view.gd
# GDScript / card_hand_view.gd / Godot 4.7 / UI Component (Fan Arc Hand)
class_name CardHandView
extends Control

signal card_selected(card: CardResource)
signal card_deselected(card: CardResource)
signal card_clicked(card: CardResource, card_node: Control)
signal card_hovered(card: CardResource, global_rect: Rect2)
signal card_unhovered()

const CARD_UI_SCENE_PATH: String = "res://assets/ui/card_ui.tscn"
const FRAME_ACTIVE_PATH: String = "res://assets/ui/textures/frame_active.png"
const FRAME_PASSIVE_PATH: String = "res://assets/ui/textures/frame_passive.png"
const CARD_BACK_ACTIVE_PATH: String = "res://assets/sprites/cards/the_sun_back.png"
const CARD_BACK_PASSIVE_PATH: String = "res://assets/sprites/cards/the_moon_back.png"

const COLOR_ACTIVE_ACCENT: Color = Color("#F4A236")
const COLOR_ACTIVE_BADGE_BG: Color = Color(0.24, 0.06, 0.09, 0.95)
const COLOR_PASSIVE_ACCENT: Color = Color("#64B5F6")
const COLOR_PASSIVE_BADGE_BG: Color = Color(0.04, 0.24, 0.57, 0.95)
const COLOR_INK_DARK: Color = Color(0.102, 0.102, 0.114, 1.0)

const CARD_WIDTH: float = 148.0
const CARD_HEIGHT: float = 206.0
const HOVER_SCALE: Vector2 = Vector2(1.22, 1.22)
const SELECTED_SCALE: Vector2 = Vector2(1.24, 1.24)
const HOVER_LIFT_Y: float = 42.0
const SELECTED_LIFT_Y: float = 52.0
const HOVER_TWEEN_DURATION: float = 0.14

var turn_manager: TurnManager
var displayed_team: PieceData.Team = PieceData.Team.WHITE
var cards_container: Control

var selected_card: CardResource = null
var selected_card_node: Control = null
var card_node_map: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(880.0, 250.0)
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

	var card_width: float = CARD_WIDTH
	var card_height: float = CARD_HEIGHT
	var center_index: float = float(count - 1) / 2.0
	var spacing: float = clampf(720.0 / maxf(float(count), 1.0), 62.0, 126.0)
	var total_width: float = spacing * float(count - 1)
	var container_w: float = size.x if size.x > 0.0 else custom_minimum_size.x
	if container_w <= 0.0:
		container_w = 880.0
	var start_x: float = (container_w - total_width) * 0.5

	for i in range(count):
		var holder: DraggableCardSlot = holders[i]
		var dist: float = float(i) - center_index
		var norm: float = 0.0 if count <= 1 else dist / maxf(center_index, 1.0) # -1.0 to +1.0
		var angle_deg: float = norm * 11.0 # -11 to +11 deg
		var pos_x: float = start_x + float(i) * spacing - (card_width * 0.5)
		var pos_y: float = 6.0 + (norm * norm) * 14.0 # smooth parabolic arc

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
	holder.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	holder.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_node: Control = null
	if ResourceLoader.exists(CARD_UI_SCENE_PATH):
		var scene: PackedScene = load(CARD_UI_SCENE_PATH) as PackedScene
		if scene != null:
			card_node = scene.instantiate() as Control

	if card_node != null:
		card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_node.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card_node.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		populate_card_node(card_node, card)
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
	if holder == null or not is_instance_valid(holder):
		return
	var base_pos: Vector2 = holder.get_meta("base_pos", holder.position)
	var target_pos: Vector2 = Vector2(base_pos.x, base_pos.y - HOVER_LIFT_Y)
	holder.z_index = 50
	_animate_holder_transform(holder, target_pos, 0.0, HOVER_SCALE)
	if holder.card_data != null:
		card_hovered.emit(holder.card_data, holder.get_global_rect())

func _on_card_mouse_exited(holder: DraggableCardSlot) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	var base_pos: Vector2 = holder.get_meta("base_pos", holder.position)
	var base_rot: float = float(holder.get_meta("base_rot", 0.0))
	var base_z: int = int(holder.get_meta("base_z", 0))

	var target_pos: Vector2 = base_pos
	var target_rot: float = base_rot
	var target_scale: Vector2 = Vector2.ONE
	var target_z: int = base_z
	if selected_card == holder.card_data:
		target_pos = Vector2(base_pos.x, base_pos.y - SELECTED_LIFT_Y)
		target_rot = 0.0
		target_scale = Vector2(1.12, 1.12)
		target_z = base_z + 15

	holder.z_index = target_z
	_animate_holder_transform(holder, target_pos, target_rot, target_scale)
	card_unhovered.emit()

func _animate_holder_transform(holder: DraggableCardSlot, target_pos: Vector2, target_rot: float, target_scale: Vector2) -> void:
	if holder.hover_tween != null and holder.hover_tween.is_valid():
		holder.hover_tween.kill()
		holder.hover_tween = null

	if holder.is_inside_tree():
		var tw: Tween = holder.create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "position", target_pos, HOVER_TWEEN_DURATION)
		tw.tween_property(holder, "rotation_degrees", target_rot, HOVER_TWEEN_DURATION)
		tw.tween_property(holder, "scale", target_scale, HOVER_TWEEN_DURATION)
		holder.hover_tween = tw
	else:
		holder.position = target_pos
		holder.rotation_degrees = target_rot
		holder.scale = target_scale

static func populate_card_node(node: Control, card: CardResource) -> void:
	if node == null or card == null:
		return

	var title_lbl: Label = node.find_child("TitleLabel", true, false) as Label
	var type_badge: Control = node.find_child("TypeBadge", true, false) as Control
	var divider: Control = node.find_child("Divider", true, false) as Control
	var art_icon: TextureRect = node.find_child("ArtIcon", true, false) as TextureRect
	var desc_node: Node = node.find_child("DescLabel", true, false)
	var frame_rect: TextureRect = node.find_child("CardFrame", true, false) as TextureRect
	var card_bg: Control = node.find_child("CardBg", true, false) as Control

	var is_act: bool = card.is_active()

	if card_bg != null:
		card_bg.visible = false
	if type_badge != null:
		type_badge.visible = false
	if divider != null:
		divider.visible = false

	if title_lbl != null:
		title_lbl.text = card.title
		title_lbl.clip_text = true
		title_lbl.add_theme_color_override("font_color", COLOR_INK_DARK)

	if art_icon != null:
		art_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art_icon.clip_contents = true
		art_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if card.icon_path != "" and ResourceLoader.exists(card.icon_path):
			art_icon.texture = load(card.icon_path) as Texture2D
			art_icon.visible = true
		else:
			art_icon.texture = null

	if desc_node != null:
		if desc_node is Label:
			var desc_lbl: Label = desc_node as Label
			desc_lbl.text = card.description
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.clip_text = true
			desc_lbl.add_theme_color_override("font_color", COLOR_INK_DARK)
		elif desc_node is RichTextLabel:
			var desc_rtl: RichTextLabel = desc_node as RichTextLabel
			desc_rtl.text = card.description
			desc_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_rtl.scroll_active = false
			desc_rtl.add_theme_color_override("default_color", COLOR_INK_DARK)

	if frame_rect != null:
		frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var frame_path: String = FRAME_ACTIVE_PATH if is_act else FRAME_PASSIVE_PATH
		if ResourceLoader.exists(frame_path):
			frame_rect.texture = load(frame_path) as Texture2D

static func _duplicate_or_create_stylebox(ctrl: Control) -> StyleBoxFlat:
	var existing: StyleBox = ctrl.get_theme_stylebox("panel")
	if existing is StyleBoxFlat:
		return (existing as StyleBoxFlat).duplicate() as StyleBoxFlat
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.095, 0.12, 0.98)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb

func _populate_card_ui(node: Control, card: CardResource) -> void:
	populate_card_node(node, card)

func _on_card_node_clicked(card: CardResource, node: Control) -> void:
	if selected_card == card:
		deselect_card()
	else:
		select_card(card, node)

func select_card(card: CardResource, node: Control) -> void:
	if selected_card_node != null and is_instance_valid(selected_card_node):
		var old_holder: DraggableCardSlot = selected_card_node as DraggableCardSlot
		var old_base_pos: Vector2 = selected_card_node.get_meta("base_pos", selected_card_node.position)
		var old_rot: float = float(selected_card_node.get_meta("base_rot", 0.0))
		var old_z: int = int(selected_card_node.get_meta("base_z", 0))
		selected_card_node.modulate = Color.WHITE
		selected_card_node.z_index = old_z
		if old_holder != null:
			_animate_holder_transform(old_holder, old_base_pos, old_rot, Vector2.ONE)
		else:
			selected_card_node.rotation_degrees = old_rot
			selected_card_node.scale = Vector2.ONE
			selected_card_node.position = old_base_pos

	selected_card = card
	selected_card_node = node

	if selected_card_node != null and is_instance_valid(selected_card_node):
		var base_pos: Vector2 = selected_card_node.get_meta("base_pos", selected_card_node.position)
		var sel_holder: DraggableCardSlot = selected_card_node as DraggableCardSlot
		selected_card_node.modulate = Color(1.15, 1.15, 0.95, 1.0)
		selected_card_node.z_index = 55
		if sel_holder != null:
			_animate_holder_transform(sel_holder, Vector2(base_pos.x, base_pos.y - SELECTED_LIFT_Y), 0.0, SELECTED_SCALE)
		else:
			selected_card_node.position = Vector2(base_pos.x, base_pos.y - SELECTED_LIFT_Y)

	card_selected.emit(card)
	card_clicked.emit(card, node)

func deselect_card() -> void:
	if selected_card_node != null and is_instance_valid(selected_card_node):
		var base_pos: Vector2 = selected_card_node.get_meta("base_pos", selected_card_node.position)
		var base_rot: float = float(selected_card_node.get_meta("base_rot", 0.0))
		var base_z: int = int(selected_card_node.get_meta("base_z", 0))
		var holder: DraggableCardSlot = selected_card_node as DraggableCardSlot
		selected_card_node.modulate = Color.WHITE
		selected_card_node.z_index = base_z
		if holder != null:
			_animate_holder_transform(holder, base_pos, base_rot, Vector2.ONE)
		else:
			selected_card_node.rotation_degrees = base_rot
			selected_card_node.scale = Vector2.ONE
			selected_card_node.position = base_pos

	var prev_card: CardResource = selected_card
	selected_card = null
	selected_card_node = null

	if prev_card != null:
		card_deselected.emit(prev_card)

class DraggableCardSlot extends Control:
	var card_data: CardResource
	var hand_view: CardHandView
	var visual_node: Control
	var hover_tween: Tween = null

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if card_data == null:
			return null
		if hand_view != null:
			hand_view.select_card(card_data, self)
		if visual_node != null:
			var dup: Control = visual_node.duplicate() as Control
			dup.position = Vector2(-74, -108)
			dup.modulate = Color(1, 1, 1, 0.85)
			var holder: Control = Control.new()
			holder.add_child(dup)
			set_drag_preview(holder)
		return {"type": "card", "card": card_data}
