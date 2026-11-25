# res://src/scenes/status_tooltip.gd
# GDScript / status_tooltip.gd / Godot 4.7 / Floating Status & Passive Tooltip
class_name StatusTooltip
extends PanelContainer

const VIEWPORT_BOUNDS: Vector2 = Vector2(1920.0, 1080.0)
const MARGIN_EDGE: float = 12.0
const ANCHOR_GAP: float = 12.0
const FILE_LETTERS: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h"]

var _vbox: VBoxContainer
var _title_label: Label
var _divider: ColorRect
var _body_label: Label

func _init() -> void:
	name = "StatusTooltip"
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()

func _build_ui() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color("#11141DE6")
	panel_style.border_color = Color("#D4AF37")
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_bottom = 10.0
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0.0, 4.0)
	add_theme_stylebox_override("panel", panel_style)

	_vbox = VBoxContainer.new()
	_vbox.name = "ContentVBox"
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_theme_constant_override("separation", 6)
	add_child(_vbox)

	_title_label = Label.new()
	_title_label.name = "TooltipTitle"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color("#F5DFB0"))
	_vbox.add_child(_title_label)

	_divider = ColorRect.new()
	_divider.name = "TooltipDivider"
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.custom_minimum_size = Vector2(260.0, 1.0)
	_divider.color = Color("#D4AF3766")
	_vbox.add_child(_divider)

	_body_label = Label.new()
	_body_label.name = "TooltipBody"
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.custom_minimum_size = Vector2(260.0, 0.0)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 13)
	_body_label.add_theme_color_override("font_color", Color("#E6ECF5"))
	_vbox.add_child(_body_label)

func show_tooltip(title: String, lines: Array[String], anchor_global_rect: Rect2) -> void:
	if lines.is_empty():
		hide_tooltip()
		return

	_title_label.text = title
	_body_label.text = "\n".join(lines)
	visible = true
	reset_size()

	var tip_size: Vector2 = get_combined_minimum_size()
	if size.x > tip_size.x:
		tip_size.x = size.x
	if size.y > tip_size.y:
		tip_size.y = size.y
	size = tip_size

	var viewport_size: Vector2 = VIEWPORT_BOUNDS
	if is_inside_tree() and get_viewport_rect().size.x > 0.0:
		viewport_size = get_viewport_rect().size

	var target_x: float = anchor_global_rect.end.x + ANCHOR_GAP
	if target_x + tip_size.x > viewport_size.x - MARGIN_EDGE:
		target_x = anchor_global_rect.position.x - tip_size.x - ANCHOR_GAP

	var target_y: float = anchor_global_rect.position.y
	target_x = clampf(target_x, MARGIN_EDGE, maxf(MARGIN_EDGE, viewport_size.x - tip_size.x - MARGIN_EDGE))
	target_y = clampf(target_y, MARGIN_EDGE, maxf(MARGIN_EDGE, viewport_size.y - tip_size.y - MARGIN_EDGE))

	global_position = Vector2(target_x, target_y)

func hide_tooltip() -> void:
	visible = false

func get_title_text() -> String:
	return _title_label.text if _title_label != null else ""

func get_body_text() -> String:
	return _body_label.text if _body_label != null else ""

static func get_piece_display_name(piece: PieceData) -> String:
	if piece == null:
		return ""
	var team_vn: String = "Trắng" if piece.team == PieceData.Team.WHITE else "Đen"
	var type_vn: String = ""
	match piece.type:
		PieceData.PieceType.PAWN: type_vn = "Tốt"
		PieceData.PieceType.KNIGHT: type_vn = "Mã"
		PieceData.PieceType.BISHOP: type_vn = "Tượng"
		PieceData.PieceType.ROOK: type_vn = "Xe"
		PieceData.PieceType.QUEEN: type_vn = "Hậu"
		PieceData.PieceType.KING: type_vn = "Vua"
		PieceData.PieceType.SUPER_PAWN: type_vn = "Siêu Tốt"
		PieceData.PieceType.SUPER_KNIGHT: type_vn = "Siêu Mã"
		PieceData.PieceType.SUPER_BISHOP: type_vn = "Siêu Tượng"
		PieceData.PieceType.SUPER_ROOK: type_vn = "Siêu Xe"
		PieceData.PieceType.SUPER_QUEEN: type_vn = "Siêu Hậu"
		PieceData.PieceType.SCARECROW: return "Bù Nhìn (%dđ)" % piece.points
		PieceData.PieceType.HEAL_POINT: return "Điểm Hồi Máu (%dđ)" % piece.points
		_: type_vn = "Quân Cờ"
	return "%s %s (%dđ)" % [type_vn, team_vn, piece.points]

static func build_piece_tooltip_data(board: BoardState, pos: Vector2i, viewer_team: PieceData.Team = PieceData.Team.WHITE) -> Dictionary:
	var result: Dictionary = {
		"should_show": false,
		"title": "",
		"lines": [] as Array[String]
	}
	if board == null or not board.is_valid_cell(pos):
		return result

	var piece: PieceData = board.get_piece(pos)
	# Giữ Fog of War cho quân tàng hình của đối thủ
	if piece != null and piece.is_stealth and piece.team != viewer_team:
		return result

	var lines: Array[String] = []
	if piece != null:
		if piece.is_locked:
			lines.append("• Xiềng Xích (Bị Khóa) — còn %d lượt" % piece.locked_turns)
		if piece.is_cursed:
			lines.append("• Lời Nguyền Tử Vong — còn %d lượt" % piece.curse_turns)
		if piece.is_immortal:
			lines.append("• Bất Tử (Kim Cương) — còn %d lượt" % piece.immortal_turns)
		if piece.is_stealth:
			lines.append("• Tàng Hình — còn %d lượt" % piece.stealth_turns)
		if piece.is_banned:
			lines.append("• Bị Trục Xuất (Ban) — còn %d lượt" % piece.banned_turns)
		if piece.has_shield:
			lines.append("• Khiên Bảo Vệ Vua — còn %d lượt" % piece.shield_turns)
		if piece.is_clone:
			lines.append("• Phân Thân")
		if piece.double_move_active:
			lines.append("• Song Trùng (Đi 2 nước lượt này)")
		if piece.custom_move_mode != "":
			lines.append("• Biến Thể Di Chuyển: %s (lượt này)" % piece.custom_move_mode)

	# Hiệu ứng ô cờ
	if board.barrier_burn_zones.has(pos):
		var burn_info: Variant = board.barrier_burn_zones[pos]
		var burn_turns: int = int(burn_info.get("turns", 0)) if burn_info is Dictionary else int(burn_info)
		lines.append("• Kết Giới Thiêu Đốt (-0.5đ/lượt) — còn %d lượt" % burn_turns)

	if board.is_cell_forbidden(pos):
		var forb_turns: int = int(board.forbidden_cells.get(pos, 0))
		lines.append("• Ô Cấm Di Chuyển — còn %d lượt" % forb_turns)

	if board.fire_diagonals.has(pos):
		lines.append("• Đường Chéo Lửa (-1đ)")

	if lines.is_empty():
		return result

	var title_str: String = ""
	if piece != null:
		title_str = get_piece_display_name(piece)
	else:
		var coord: String = "%s%d" % [FILE_LETTERS[clampi(pos.x, 0, 7)], pos.y + 1]
		title_str = "Hiệu Ứng Ô %s" % coord.to_upper()

	result["should_show"] = true
	result["title"] = title_str
	result["lines"] = lines
	return result

static func build_passive_tooltip_data(
	slot_data: Dictionary,
	team: PieceData.Team,
	turn_number: int,
	passive_manager: PassiveManager,
	viewer_team: PieceData.Team = PieceData.Team.WHITE
) -> Dictionary:
	var result: Dictionary = {
		"should_show": false,
		"title": "",
		"lines": [] as Array[String]
	}
	if slot_data.is_empty() or slot_data.get("card") == null:
		return result

	var placed_turn: int = int(slot_data.get("placed_turn", turn_number))
	var rounds_on_board: int = maxi(0, turn_number - placed_turn)
	var is_muted: bool = passive_manager != null and passive_manager.is_muted(team)
	var muted_turns: int = 0
	if passive_manager != null:
		muted_turns = passive_manager.white_passives_muted_turns if team == PieceData.Team.WHITE else passive_manager.black_passives_muted_turns

	var lines: Array[String] = []
	if team == viewer_team:
		var card: CardResource = slot_data["card"] as CardResource
		result["title"] = "%s [PASSIVE]" % card.title
		if card.description != "":
			lines.append(card.description)
		lines.append("• Đã úp trên sân: %d vòng" % rounds_on_board)
		if is_muted:
			lines.append("• Đang bị Câm Lặng Bẫy — còn %d lượt" % muted_turns)
		elif bool(slot_data.get("is_ready_to_trigger", false)):
			lines.append("• SẴN SÀNG KÍCH HOẠT — Bấm trực tiếp để dùng!")
		elif placed_turn >= turn_number:
			lines.append("• Đang chờ sang lượt sau (còn 1 lượt)")
		else:
			lines.append("• Đang úp — Chờ điều kiện kích hoạt")
	else:
		# Fog of War cho bài Passive úp của đối thủ
		result["title"] = "Bài Bẫy Úp (Đối Thủ)"
		lines.append("• Đã úp trên sân: %d vòng" % rounds_on_board)
		if is_muted:
			lines.append("• Đang bị Câm Lặng Bẫy — còn %d lượt" % muted_turns)

	result["should_show"] = true
	result["lines"] = lines
	return result
