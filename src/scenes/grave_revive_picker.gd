# res://src/scenes/grave_revive_picker.gd
# GDScript / grave_revive_picker.gd / Godot 4.7 / Graveyard Revive Picker Modal (Draft)
class_name GraveRevivePicker
extends Control

signal revive_confirmed(selected_indices: Array[int])
signal revive_cancelled()

const COLOR_PARCHMENT: Color = Color("#F5EFE6")
const COLOR_INK: Color = Color(0.102, 0.102, 0.114, 1.0)
const COLOR_GOLD: Color = Color("#F4A236")
const COLOR_BRIGHT_GOLD: Color = Color("#FFD700")
const COLOR_DARK_BG: Color = Color(0.075, 0.082, 0.115, 0.97)
const COLOR_ELIGIBLE_BG: Color = Color(0.14, 0.16, 0.22, 0.98)
const COLOR_SELECTED_BG: Color = Color(0.24, 0.18, 0.08, 0.98)
const COLOR_DISABLED_BG: Color = Color(0.06, 0.06, 0.08, 0.72)

var _backdrop: ColorRect
var _panel: PanelContainer
var _title_lbl: Label
var _subtitle_lbl: Label
var _budget_lbl: Label
var _grid: GridContainer
var _confirm_btn: Button
var _cancel_btn: Button

var _grave_pieces: Array[PieceData] = []
var _max_single_points: int = 999
var _max_total_points: int = 999
var _multi_select: bool = false
var _selected_indices: Array[int] = []
var _item_buttons: Array[Button] = []

func _init() -> void:
	name = "GraveRevivePicker"
	z_index = 185
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.025, 0.04, 0.74)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(720.0, 480.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COLOR_DARK_BG
	sb.border_color = COLOR_GOLD
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 20.0
	sb.content_margin_top = 16.0
	sb.content_margin_right = 20.0
	sb.content_margin_bottom = 16.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	sb.shadow_size = 16
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	_title_lbl.text = "CHỌN QUÂN HỒI SINH TỪ MỘ ĐỊA"
	vbox.add_child(_title_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.add_theme_font_size_override("font_size", 14)
	_subtitle_lbl.add_theme_color_override("font_color", COLOR_PARCHMENT)
	_subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_subtitle_lbl)

	_budget_lbl = Label.new()
	_budget_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_budget_lbl.add_theme_font_size_override("font_size", 13)
	_budget_lbl.add_theme_color_override("font_color", COLOR_BRIGHT_GOLD)
	vbox.add_child(_budget_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(680.0, 290.0)
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)

	_confirm_btn = Button.new()
	_confirm_btn.text = "XÁC NHẬN HỒI SINH"
	_confirm_btn.custom_minimum_size = Vector2(210.0, 42.0)
	_confirm_btn.add_theme_font_size_override("font_size", 15)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(_confirm_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "HỦY"
	_cancel_btn.custom_minimum_size = Vector2(120.0, 42.0)
	_cancel_btn.add_theme_font_size_override("font_size", 15)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(_cancel_btn)

func open_picker(card: CardResource, grave: Array[PieceData], max_single_pts: int = 999, max_total_pts: int = 999, multi_select: bool = false) -> void:
	_grave_pieces = grave.duplicate()
	_max_single_points = max_single_pts
	_max_total_points = max_total_pts
	_multi_select = multi_select
	_selected_indices.clear()

	_title_lbl.text = "%s — MỘ ĐỊA (%d QUÂN)" % [card.title.to_upper(), _grave_pieces.size()]
	if multi_select:
		_subtitle_lbl.text = "Các quân sáng đèn đủ điều kiện hồi sinh (tổng điểm <= %dđ). Bấm chọn 1 hoặc nhiều quân:" % max_total_pts
	elif max_single_pts < 100:
		_subtitle_lbl.text = "Các quân sáng đèn đủ điều kiện hồi sinh (<= %d điểm). Quân tối màu vượt giới hạn điểm:" % max_single_pts
	else:
		_subtitle_lbl.text = "Chọn 1 quân bất kỳ đã chết trong mộ địa để hồi sinh:"

	_rebuild_grid()
	_refresh_selection_visuals()
	visible = true

func close_picker() -> void:
	visible = false
	_selected_indices.clear()

func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_item_buttons.clear()

	for i in range(_grave_pieces.size()):
		var p: PieceData = _grave_pieces[i]
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(122.0, 134.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_meta("grave_idx", i)

		var ivbox: VBoxContainer = VBoxContainer.new()
		ivbox.set_anchors_preset(PRESET_FULL_RECT)
		ivbox.offset_left = 6.0
		ivbox.offset_top = 6.0
		ivbox.offset_right = -6.0
		ivbox.offset_bottom = -6.0
		ivbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ivbox.alignment = BoxContainer.ALIGNMENT_CENTER
		ivbox.add_theme_constant_override("separation", 3)
		btn.add_child(ivbox)

		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(64.0, 64.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path: String = _get_piece_texture_path(p)
		if path != "" and ResourceLoader.exists(path):
			icon.texture = load(path) as Texture2D
		ivbox.add_child(icon)

		var name_lbl: Label = Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", COLOR_PARCHMENT)
		name_lbl.text = "%s (%dđ)" % [_get_piece_vn_name(p.type), p.points]
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ivbox.add_child(name_lbl)

		var tag_lbl: Label = Label.new()
		tag_lbl.name = "TagLabel"
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.add_theme_font_size_override("font_size", 10)
		tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ivbox.add_child(tag_lbl)

		btn.pressed.connect(func(): _on_piece_clicked(i))
		_grid.add_child(btn)
		_item_buttons.append(btn)

func _get_selected_total_points() -> int:
	var total: int = 0
	for idx in _selected_indices:
		if idx >= 0 and idx < _grave_pieces.size():
			total += _grave_pieces[idx].points
	return total

func _is_index_eligible(idx: int) -> bool:
	if idx < 0 or idx >= _grave_pieces.size():
		return false
	var p: PieceData = _grave_pieces[idx]
	if p.points > _max_single_points:
		return false
	if _selected_indices.has(idx):
		return true
	if _multi_select:
		return (_get_selected_total_points() + p.points) <= _max_total_points
	return p.points <= _max_total_points

func _on_piece_clicked(idx: int) -> void:
	if _selected_indices.has(idx):
		_selected_indices.erase(idx)
	else:
		if not _is_index_eligible(idx):
			return
		if not _multi_select:
			_selected_indices.clear()
		_selected_indices.append(idx)
	_refresh_selection_visuals()

func _refresh_selection_visuals() -> void:
	var sel_pts: int = _get_selected_total_points()
	if _multi_select:
		_budget_lbl.text = "Đã chọn: %d quân | Tổng điểm: %d / %dđ" % [_selected_indices.size(), sel_pts, _max_total_points]
	else:
		if _selected_indices.is_empty():
			_budget_lbl.text = "Chưa chọn quân nào"
		else:
			var sp: PieceData = _grave_pieces[_selected_indices[0]]
			_budget_lbl.text = "Đang chọn: %s (%dđ)" % [_get_piece_vn_name(sp.type), sp.points]

	for i in range(_item_buttons.size()):
		var btn: Button = _item_buttons[i]
		var is_sel: bool = _selected_indices.has(i)
		var is_elig: bool = _is_index_eligible(i)
		var tag_lbl: Label = btn.find_child("TagLabel", true, false) as Label

		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6

		if is_sel:
			sb.bg_color = COLOR_SELECTED_BG
			sb.border_color = COLOR_BRIGHT_GOLD
			sb.border_width_left = 3
			sb.border_width_top = 3
			sb.border_width_right = 3
			sb.border_width_bottom = 3
			btn.disabled = false
			btn.modulate = Color(1.08, 1.08, 1.0, 1.0)
			if tag_lbl != null:
				tag_lbl.text = "✓ ĐÃ CHỌN"
				tag_lbl.add_theme_color_override("font_color", COLOR_BRIGHT_GOLD)
		elif is_elig:
			sb.bg_color = COLOR_ELIGIBLE_BG
			sb.border_color = COLOR_GOLD
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			btn.disabled = false
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if tag_lbl != null:
				tag_lbl.text = "ĐỦ ĐIỀU KIỆN"
				tag_lbl.add_theme_color_override("font_color", Color("#6EE7B7"))
		else:
			sb.bg_color = COLOR_DISABLED_BG
			sb.border_color = Color(0.25, 0.26, 0.32, 0.5)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			btn.disabled = true
			btn.modulate = Color(0.42, 0.42, 0.48, 0.62)
			if tag_lbl != null:
				tag_lbl.text = "QUÁ ĐIỂM"
				tag_lbl.add_theme_color_override("font_color", Color("#F87171"))

		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("disabled", sb)

	_confirm_btn.disabled = _selected_indices.is_empty()

func _on_confirm_pressed() -> void:
	if _selected_indices.is_empty():
		return
	var chosen: Array[int] = _selected_indices.duplicate()
	close_picker()
	revive_confirmed.emit(chosen)

func _on_cancel_pressed() -> void:
	close_picker()
	revive_cancelled.emit()

func _get_piece_texture_path(piece: PieceData) -> String:
	var team_str: String = "white" if piece.team == PieceData.Team.WHITE else "black"
	match piece.type:
		PieceData.PieceType.PAWN: return "res://assets/sprites/pieces/pawn_" + team_str + ".png"
		PieceData.PieceType.KNIGHT: return "res://assets/sprites/pieces/knight_" + team_str + ".png"
		PieceData.PieceType.BISHOP: return "res://assets/sprites/pieces/bishop_" + team_str + ".png"
		PieceData.PieceType.ROOK: return "res://assets/sprites/pieces/rook_" + team_str + ".png"
		PieceData.PieceType.QUEEN: return "res://assets/sprites/pieces/queen_" + team_str + ".png"
		PieceData.PieceType.KING: return "res://assets/sprites/pieces/king_" + team_str + ".png"
		PieceData.PieceType.SUPER_PAWN: return "res://assets/sprites/pieces/super_pawn_" + team_str + ".png"
		PieceData.PieceType.SUPER_KNIGHT: return "res://assets/sprites/pieces/super_knight_" + team_str + ".png"
		PieceData.PieceType.SUPER_BISHOP: return "res://assets/sprites/pieces/super_bishop_" + team_str + ".png"
		PieceData.PieceType.SUPER_ROOK: return "res://assets/sprites/pieces/super_rook_" + team_str + ".png"
		PieceData.PieceType.SUPER_QUEEN: return "res://assets/sprites/pieces/super_queen_" + team_str + ".png"
		PieceData.PieceType.SCARECROW: return "res://assets/sprites/pieces/scarecrow.png"
		PieceData.PieceType.HEAL_POINT: return "res://assets/sprites/pieces/heal_point.png"
		_: return ""

func _get_piece_vn_name(ptype: PieceData.PieceType) -> String:
	match ptype:
		PieceData.PieceType.PAWN: return "Tốt"
		PieceData.PieceType.KNIGHT: return "Mã"
		PieceData.PieceType.BISHOP: return "Tượng"
		PieceData.PieceType.ROOK: return "Xe"
		PieceData.PieceType.QUEEN: return "Hậu"
		PieceData.PieceType.KING: return "Vua"
		PieceData.PieceType.SUPER_PAWN: return "Siêu Tốt"
		PieceData.PieceType.SUPER_KNIGHT: return "Siêu Mã"
		PieceData.PieceType.SUPER_BISHOP: return "Siêu Tượng"
		PieceData.PieceType.SUPER_ROOK: return "Siêu Xe"
		PieceData.PieceType.SUPER_QUEEN: return "Siêu Hậu"
		_: return "Quân Cờ"
