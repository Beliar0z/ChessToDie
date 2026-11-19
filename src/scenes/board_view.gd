class_name BoardView
extends Control

signal tile_clicked(pos: Vector2i)
signal tile_right_clicked(pos: Vector2i)
signal move_executed(from_pos: Vector2i, to_pos: Vector2i)
signal card_dropped_on_tile(card: CardResource, pos: Vector2i)

const BOARD_SIZE: int = 8

const COLOR_TILE_LIGHT: Color = Color(0.24, 0.27, 0.32, 1.0)
const COLOR_TILE_DARK: Color = Color(0.12, 0.13, 0.16, 1.0)
const COLOR_HIGHLIGHT_SELECT: Color = Color(0.83, 0.69, 0.22, 0.45)
const COLOR_HIGHLIGHT_MOVE: Color = Color(0.18, 0.80, 0.44, 0.40)
const COLOR_HIGHLIGHT_CAPTURE: Color = Color(0.91, 0.30, 0.24, 0.50)

var turn_manager: TurnManager
var tiles_grid: GridContainer
var shader_overlay: ColorRect
var arrow_overlay: ArrowOverlay

var selected_cell: Vector2i = Vector2i(-1, -1)
var highlighted_moves: Array[Vector2i] = []
var tile_controls: Array[Control] = []

# Chess.com right-click drawing state
var rmb_start_cell: Vector2i = Vector2i(-1, -1)
var rmb_current_cell: Vector2i = Vector2i(-1, -1)
var user_arrows: Array[Dictionary] = [] # [{from: Vector2i, to: Vector2i}]
var user_marked_cells: Array[Vector2i] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(760.0, 760.0)
	_ensure_grid_and_tiles()

func setup(p_turn_manager: TurnManager, p_grid: GridContainer = null) -> void:
	turn_manager = p_turn_manager
	if p_grid != null:
		var internal_grid: Node = get_node_or_null("TilesGrid")
		if internal_grid != null and internal_grid != p_grid:
			internal_grid.free()
		tiles_grid = p_grid
	_ensure_grid_and_tiles()
	update_board_visuals()

func _ensure_grid_and_tiles() -> void:
	if tiles_grid == null:
		if get_parent() != null:
			tiles_grid = get_parent().find_child("TilesGrid", false, false) as GridContainer
		if tiles_grid == null:
			tiles_grid = find_child("TilesGrid", true, false) as GridContainer

	if tiles_grid == null:
		tiles_grid = GridContainer.new()
		tiles_grid.name = "TilesGrid"
		tiles_grid.columns = BOARD_SIZE
		tiles_grid.set_anchors_preset(PRESET_FULL_RECT)
		tiles_grid.add_theme_constant_override("h_separation", 0)
		tiles_grid.add_theme_constant_override("v_separation", 0)
		add_child(tiles_grid)

	if tiles_grid.get_child_count() < 64:
		for child in tiles_grid.get_children():
			child.queue_free()
		tile_controls.clear()

		for index in range(64):
			var tile: BoardTileButton = _create_tile_button(index)
			tiles_grid.add_child(tile)
			tile_controls.append(tile)
	else:
		tile_controls.clear()
		for i in range(64):
			tile_controls.append(tiles_grid.get_child(i) as Control)

	if shader_overlay == null:
		shader_overlay = find_child("BoardShaderOverlay", true, false) as ColorRect
		if shader_overlay == null:
			shader_overlay = ColorRect.new()
			shader_overlay.name = "BoardShaderOverlay"
			shader_overlay.set_anchors_preset(PRESET_FULL_RECT)
			shader_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shader_overlay.color = Color(1, 1, 1, 0)
			add_child(shader_overlay)

	if arrow_overlay == null:
		arrow_overlay = ArrowOverlay.new()
		arrow_overlay.name = "ArrowOverlay"
		arrow_overlay.set_anchors_preset(PRESET_FULL_RECT)
		arrow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow_overlay.board_view = self
		add_child(arrow_overlay)

func _create_tile_button(grid_index: int) -> BoardTileButton:
	var pos: Vector2i = grid_to_board(grid_index)
	var is_light: bool = (pos.x + pos.y) % 2 != 0

	var btn: BoardTileButton = BoardTileButton.new()
	btn.name = "Tile_%d_%d" % [pos.x, pos.y]
	btn.board_pos = pos
	btn.board_view = self
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(80, 80)
	btn.focus_mode = Control.FOCUS_NONE

	var bg: ColorRect = ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = COLOR_TILE_LIGHT if is_light else COLOR_TILE_DARK
	btn.add_child(bg)

	var hl: ColorRect = ColorRect.new()
	hl.name = "Highlight"
	hl.set_anchors_preset(PRESET_FULL_RECT)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.color = Color(0, 0, 0, 0)
	btn.add_child(hl)

	var piece_icon: TextureRect = TextureRect.new()
	piece_icon.name = "PieceIcon"
	piece_icon.set_anchors_preset(PRESET_FULL_RECT)
	piece_icon.offset_left = 6.0
	piece_icon.offset_top = 6.0
	piece_icon.offset_right = -6.0
	piece_icon.offset_bottom = -6.0
	piece_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	btn.add_child(piece_icon)

	var status_icon: TextureRect = TextureRect.new()
	status_icon.name = "StatusIcon"
	status_icon.set_anchors_preset(PRESET_TOP_RIGHT)
	status_icon.offset_left = -26.0
	status_icon.offset_top = 4.0
	status_icon.offset_right = -4.0
	status_icon.offset_bottom = 26.0
	status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	btn.add_child(status_icon)

	btn.gui_input.connect(func(event: InputEvent): _on_tile_gui_input(event, pos))
	return btn

func _on_tile_gui_input(event: InputEvent, pos: Vector2i) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			clear_annotations()
			tile_clicked.emit(pos)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				tile_right_clicked.emit(pos)
				rmb_start_cell = pos
				rmb_current_cell = pos
			else:
				var end_cell: Vector2i = _screen_to_board_pos(get_global_mouse_position())
				if rmb_start_cell != Vector2i(-1, -1) and end_cell != Vector2i(-1, -1):
					if rmb_start_cell == end_cell:
						_toggle_marked_cell(end_cell)
					else:
						_toggle_arrow(rmb_start_cell, end_cell)
				rmb_start_cell = Vector2i(-1, -1)
				rmb_current_cell = Vector2i(-1, -1)
				if arrow_overlay != null:
					arrow_overlay.queue_redraw()
	elif event is InputEventMouseMotion and rmb_start_cell != Vector2i(-1, -1):
		var hover_cell: Vector2i = _screen_to_board_pos(get_global_mouse_position())
		if hover_cell != Vector2i(-1, -1) and hover_cell != rmb_current_cell:
			rmb_current_cell = hover_cell
			if arrow_overlay != null:
				arrow_overlay.queue_redraw()

func _screen_to_board_pos(global_pos: Vector2) -> Vector2i:
	if tiles_grid == null:
		return Vector2i(-1, -1)
	var local: Vector2 = tiles_grid.get_global_transform().affine_inverse() * global_pos
	var rect: Rect2 = Rect2(Vector2.ZERO, tiles_grid.size)
	if not rect.has_point(local):
		return Vector2i(-1, -1)
	var col: int = clampi(int(local.x / (tiles_grid.size.x / 8.0)), 0, 7)
	var row: int = clampi(int(local.y / (tiles_grid.size.y / 8.0)), 0, 7)
	return Vector2i(col, 7 - row)

func _toggle_marked_cell(cell: Vector2i) -> void:
	if user_marked_cells.has(cell):
		user_marked_cells.erase(cell)
	else:
		user_marked_cells.append(cell)

func _toggle_arrow(from_c: Vector2i, to_c: Vector2i) -> void:
	for i in range(user_arrows.size()):
		if user_arrows[i]["from"] == from_c and user_arrows[i]["to"] == to_c:
			user_arrows.remove_at(i)
			return
	user_arrows.append({"from": from_c, "to": to_c})

func clear_annotations() -> void:
	if user_arrows.is_empty() and user_marked_cells.is_empty():
		return
	user_arrows.clear()
	user_marked_cells.clear()
	if arrow_overlay != null:
		arrow_overlay.queue_redraw()

func grid_to_board(grid_index: int) -> Vector2i:
	var screen_row: int = grid_index / BOARD_SIZE
	var col: int = grid_index % BOARD_SIZE
	var board_y: int = 7 - screen_row
	return Vector2i(col, board_y)

func board_to_grid(pos: Vector2i) -> int:
	var screen_row: int = 7 - pos.y
	return screen_row * BOARD_SIZE + pos.x

func begin_drag_from(pos: Vector2i) -> void:
	if turn_manager == null or turn_manager.board == null:
		return
	var piece: PieceData = turn_manager.board.get_piece(pos)
	if piece != null and piece.team == turn_manager.current_turn_team:
		clear_annotations()
		selected_cell = pos
		var is_holy_war: bool = turn_manager.death_ring_system.is_holy_war_active
		highlighted_moves = MoveValidator.get_legal_moves(turn_manager.board, pos, is_holy_war)
		update_board_visuals()

func try_drop_piece(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if turn_manager == null:
		return
	if from_pos == to_pos:
		return
	if highlighted_moves.has(to_pos):
		var ok: bool = turn_manager.execute_move(from_pos, to_pos)
		if ok:
			move_executed.emit(from_pos, to_pos)
	deselect()

func select_cell(pos: Vector2i) -> void:
	if turn_manager == null or turn_manager.board == null:
		return

	if selected_cell == Vector2i(-1, -1):
		var piece: PieceData = turn_manager.board.get_piece(pos)
		if piece != null and piece.team == turn_manager.current_turn_team:
			selected_cell = pos
			var is_holy_war: bool = turn_manager.death_ring_system.is_holy_war_active
			highlighted_moves = MoveValidator.get_legal_moves(turn_manager.board, pos, is_holy_war)
	elif selected_cell == pos:
		deselect()
	else:
		if highlighted_moves.has(pos):
			var from_pos: Vector2i = selected_cell
			var ok: bool = turn_manager.execute_move(from_pos, pos)
			if ok:
				move_executed.emit(from_pos, pos)
			deselect()
		else:
			var piece: PieceData = turn_manager.board.get_piece(pos)
			if piece != null and piece.team == turn_manager.current_turn_team:
				selected_cell = pos
				var is_holy_war: bool = turn_manager.death_ring_system.is_holy_war_active
				highlighted_moves = MoveValidator.get_legal_moves(turn_manager.board, pos, is_holy_war)
			else:
				deselect()

	update_board_visuals()

func deselect() -> void:
	selected_cell = Vector2i(-1, -1)
	highlighted_moves.clear()
	update_board_visuals()

func highlight_legal_moves(moves: Array[Vector2i]) -> void:
	highlighted_moves = moves.duplicate()
	update_board_visuals()

func highlight_targeting_cells(cells: Array[Vector2i]) -> void:
	highlighted_moves = cells.duplicate()
	update_board_visuals()

func clear_highlights() -> void:
	highlighted_moves.clear()
	update_board_visuals()

func update_board_visuals() -> void:
	if tile_controls.size() < 64:
		return

	for index in range(64):
		var pos: Vector2i = grid_to_board(index)
		var tile: Control = tile_controls[index]
		var hl: ColorRect = tile.find_child("Highlight", false, false) as ColorRect
		var piece_icon: TextureRect = tile.find_child("PieceIcon", false, false) as TextureRect
		var status_icon: TextureRect = tile.find_child("StatusIcon", false, false) as TextureRect

		if hl != null:
			if pos == selected_cell:
				hl.color = COLOR_HIGHLIGHT_SELECT
			elif highlighted_moves.has(pos):
				var target_piece: PieceData = turn_manager.board.get_piece(pos) if turn_manager != null and turn_manager.board != null else null
				hl.color = COLOR_HIGHLIGHT_CAPTURE if target_piece != null else COLOR_HIGHLIGHT_MOVE
			else:
				hl.color = Color(0, 0, 0, 0)

		if piece_icon != null:
			if turn_manager != null and turn_manager.board != null:
				var piece: PieceData = turn_manager.board.get_piece(pos)
				if piece != null:
					var path: String = _get_piece_asset_path(piece)
					if path != "" and ResourceLoader.exists(path):
						piece_icon.texture = load(path) as Texture2D
					else:
						piece_icon.texture = null
					piece_icon.visible = true
					piece_icon.modulate = Color(1.0, 1.0, 1.0, 0.45) if piece.is_stealth else Color.WHITE
				else:
					piece_icon.texture = null
					piece_icon.visible = false
			else:
				piece_icon.texture = null
				piece_icon.visible = false

		if status_icon != null:
			var status_path: String = _get_status_asset_path(pos)
			if status_path != "" and ResourceLoader.exists(status_path):
				status_icon.texture = load(status_path) as Texture2D
				status_icon.visible = true
			else:
				status_icon.texture = null
				status_icon.visible = false

func _get_piece_asset_path(piece: PieceData) -> String:
	var team_str: String = "white" if piece.team == PieceData.Team.WHITE else "black"
	match piece.type:
		PieceData.PieceType.PAWN: return "res://assets/sprites/pieces/pawn_" + team_str + ".svg"
		PieceData.PieceType.KNIGHT: return "res://assets/sprites/pieces/knight_" + team_str + ".svg"
		PieceData.PieceType.BISHOP: return "res://assets/sprites/pieces/bishop_" + team_str + ".svg"
		PieceData.PieceType.ROOK: return "res://assets/sprites/pieces/rook_" + team_str + ".svg"
		PieceData.PieceType.QUEEN: return "res://assets/sprites/pieces/queen_" + team_str + ".svg"
		PieceData.PieceType.KING: return "res://assets/sprites/pieces/king_" + team_str + ".svg"
		PieceData.PieceType.SUPER_PAWN: return "res://assets/sprites/pieces/super_pawn_" + team_str + ".svg"
		PieceData.PieceType.SUPER_KNIGHT: return "res://assets/sprites/pieces/super_knight_" + team_str + ".svg"
		PieceData.PieceType.SUPER_BISHOP: return "res://assets/sprites/pieces/super_bishop_" + team_str + ".svg"
		PieceData.PieceType.SUPER_ROOK: return "res://assets/sprites/pieces/super_rook_" + team_str + ".svg"
		PieceData.PieceType.SUPER_QUEEN: return "res://assets/sprites/pieces/super_queen_" + team_str + ".svg"
		PieceData.PieceType.SCARECROW: return "res://assets/sprites/pieces/scarecrow.svg"
		PieceData.PieceType.HEAL_POINT: return "res://assets/sprites/pieces/heal_point.svg"
		_: return ""

func _get_status_asset_path(pos: Vector2i) -> String:
	if turn_manager == null or turn_manager.board == null:
		return ""
	if turn_manager.board.is_cell_forbidden(pos):
		return "res://assets/sprites/status/forbidden_cell.svg"
	var piece: PieceData = turn_manager.board.get_piece(pos)
	if piece != null:
		if piece.curse_turns > 0 or piece.is_cursed:
			return "res://assets/sprites/status/curse_mark.svg"
		if piece.is_locked:
			return "res://assets/sprites/status/lock_mark.svg"
		if piece.is_immortal:
			return "res://assets/sprites/status/immortal_mark.svg"
		if piece.is_banned:
			return "res://assets/sprites/status/ban_mark.svg"
		if piece.has_shield:
			return "res://assets/sprites/status/shield_king.svg"
		if piece.is_stealth:
			return "res://assets/sprites/status/stealth_mark.svg"
		if piece.is_clone:
			return "res://assets/sprites/status/clone_mark.svg"
	return ""

func apply_board_shader(shader_path: String) -> void:
	if shader_overlay == null or not ResourceLoader.exists(shader_path):
		return
	var shader: Shader = load(shader_path) as Shader
	if shader != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		shader_overlay.material = mat
		shader_overlay.visible = true

func remove_board_shader() -> void:
	if shader_overlay != null:
		shader_overlay.material = null
		shader_overlay.visible = false

# --- Drag & Drop Tile Helper ---
class BoardTileButton extends Button:
	var board_pos: Vector2i
	var board_view: BoardView

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if board_view == null or board_view.turn_manager == null:
			return null
		var piece: PieceData = board_view.turn_manager.board.get_piece(board_pos)
		if piece == null or piece.team != board_view.turn_manager.current_turn_team:
			return null
		board_view.begin_drag_from(board_pos)
		var icon_node: TextureRect = find_child("PieceIcon", false, false) as TextureRect
		if icon_node != null and icon_node.texture != null:
			var preview: TextureRect = TextureRect.new()
			preview.texture = icon_node.texture
			preview.custom_minimum_size = Vector2(76, 76)
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.position = Vector2(-38, -38)
			var holder: Control = Control.new()
			holder.add_child(preview)
			set_drag_preview(holder)
		return {"type": "piece", "from": board_pos}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		if data.get("type") == "piece":
			return board_view.highlighted_moves.has(board_pos)
		if data.get("type") == "card":
			return true
		return false

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if typeof(data) != TYPE_DICTIONARY:
			return
		if data.get("type") == "piece":
			board_view.try_drop_piece(data["from"], board_pos)
		elif data.get("type") == "card":
			board_view.card_dropped_on_tile.emit(data["card"], board_pos)

# --- Chess.com Arrow & Square Marker Overlay ---
class ArrowOverlay extends Control:
	var board_view: BoardView

	func _draw() -> void:
		if board_view == null or board_view.tiles_grid == null:
			return
		var cell_size: Vector2 = board_view.tiles_grid.size / 8.0
		if cell_size.x <= 0.0:
			return

		for cell in board_view.user_marked_cells:
			var rect: Rect2 = _cell_rect(cell, cell_size)
			draw_rect(rect, Color(0.92, 0.32, 0.25, 0.45), true)

		for arrow in board_view.user_arrows:
			_draw_chess_arrow(arrow["from"], arrow["to"], cell_size, Color(0.96, 0.65, 0.14, 0.78))

		if board_view.rmb_start_cell != Vector2i(-1, -1) and board_view.rmb_current_cell != Vector2i(-1, -1):
			if board_view.rmb_start_cell != board_view.rmb_current_cell:
				_draw_chess_arrow(board_view.rmb_start_cell, board_view.rmb_current_cell, cell_size, Color(0.96, 0.65, 0.14, 0.5))

	func _cell_rect(cell: Vector2i, cell_size: Vector2) -> Rect2:
		var screen_col: int = cell.x
		var screen_row: int = 7 - cell.y
		return Rect2(Vector2(screen_col * cell_size.x, screen_row * cell_size.y), cell_size)

	func _draw_chess_arrow(from_c: Vector2i, to_c: Vector2i, cell_size: Vector2, col: Color) -> void:
		var start_p: Vector2 = _cell_rect(from_c, cell_size).get_center()
		var end_p: Vector2 = _cell_rect(to_c, cell_size).get_center()
		var dir: Vector2 = (end_p - start_p).normalized()
		if dir == Vector2.ZERO:
			return
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var head_len: float = cell_size.x * 0.34
		var head_w: float = cell_size.x * 0.24
		var shaft_w: float = cell_size.x * 0.11

		var p_start: Vector2 = start_p + dir * (cell_size.x * 0.18)
		var p_neck: Vector2 = end_p - dir * head_len
		var pts: PackedVector2Array = PackedVector2Array([
			p_start - perp * shaft_w,
			p_neck - perp * shaft_w,
			p_neck - perp * head_w,
			end_p,
			p_neck + perp * head_w,
			p_neck + perp * shaft_w,
			p_start + perp * shaft_w
		])
		draw_colored_polygon(pts, col)