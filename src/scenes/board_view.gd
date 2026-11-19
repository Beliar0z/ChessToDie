# res://src/scenes/board_view.gd
# GDScript / board_view.gd / Godot 4.7 / UI Chessboard Component
class_name BoardView
extends Control

signal tile_clicked(pos: Vector2i)
signal move_executed(from_pos: Vector2i, to_pos: Vector2i)

const BOARD_SIZE: int = 8

# Colors for Dark Fantasy / Qliphoth Flat UI
const COLOR_TILE_LIGHT: Color = Color(0.24, 0.27, 0.32, 1.0) # Slate Grey
const COLOR_TILE_DARK: Color = Color(0.12, 0.13, 0.16, 1.0)  # Dark Charcoal
const COLOR_HIGHLIGHT_SELECT: Color = Color(0.83, 0.69, 0.22, 0.45) # Gold
const COLOR_HIGHLIGHT_MOVE: Color = Color(0.18, 0.80, 0.44, 0.40)   # Emerald
const COLOR_HIGHLIGHT_CAPTURE: Color = Color(0.91, 0.30, 0.24, 0.50) # Crimson

var turn_manager: TurnManager
var tiles_grid: GridContainer
var shader_overlay: ColorRect

var selected_cell: Vector2i = Vector2i(-1, -1)
var highlighted_moves: Array[Vector2i] = []

# Array of 64 tile controls mapped by grid_index (0..63)
# grid_index = (7 - y) * 8 + x (so row 0 visually is y=7 Black side, row 7 is y=0 White side)
var tile_controls: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(768.0, 768.0)
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
		var parent_grid: GridContainer = get_node_or_null("TilesGrid") as GridContainer
		if parent_grid != null:
			tiles_grid = parent_grid
		else:
			tiles_grid = GridContainer.new()
			tiles_grid.name = "TilesGrid"
			tiles_grid.columns = BOARD_SIZE
			tiles_grid.set_anchors_preset(PRESET_FULL_RECT)
			tiles_grid.add_theme_constant_override("h_separation", 0)
			tiles_grid.add_theme_constant_override("v_separation", 0)
			add_child(tiles_grid)

	# If tiles are not yet populated, create 64 tiles
	if tiles_grid.get_child_count() < 64:
		# Clear existing partial children
		for child in tiles_grid.get_children():
			child.queue_free()
		tile_controls.clear()

		for index in range(64):
			var tile: Button = _create_tile_button(index)
			tiles_grid.add_child(tile)
			tile_controls.append(tile)
	else:
		tile_controls.clear()
		for i in range(64):
			var tile: Control = tiles_grid.get_child(i) as Control
			tile_controls.append(tile)

	# Ensure shader overlay node exists above tiles
	if shader_overlay == null:
		shader_overlay = find_child("BoardShaderOverlay", true, false) as ColorRect
		if shader_overlay == null:
			shader_overlay = ColorRect.new()
			shader_overlay.name = "BoardShaderOverlay"
			shader_overlay.set_anchors_preset(PRESET_FULL_RECT)
			shader_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shader_overlay.color = Color(1, 1, 1, 0) # transparent by default
			add_child(shader_overlay)

func _create_tile_button(grid_index: int) -> Button:
	var pos: Vector2i = grid_to_board(grid_index)
	var is_light: bool = (pos.x + pos.y) % 2 != 0

	var btn: Button = Button.new()
	btn.name = "Tile_%d_%d" % [pos.x, pos.y]
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(80, 80)
	btn.focus_mode = Control.FOCUS_NONE

	# Background ColorRect
	var bg: ColorRect = ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = COLOR_TILE_LIGHT if is_light else COLOR_TILE_DARK
	btn.add_child(bg)

	# Highlight ColorRect
	var hl: ColorRect = ColorRect.new()
	hl.name = "Highlight"
	hl.set_anchors_preset(PRESET_FULL_RECT)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.color = Color(0, 0, 0, 0)
	btn.add_child(hl)

	# Piece TextureRect
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

	# Status Icon TextureRect
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

	# Connect click event
	btn.pressed.connect(func(): _on_tile_button_pressed(pos))

	return btn

func grid_to_board(grid_index: int) -> Vector2i:
	var screen_row: int = grid_index / BOARD_SIZE
	var col: int = grid_index % BOARD_SIZE
	var board_y: int = 7 - screen_row
	return Vector2i(col, board_y)

func board_to_grid(pos: Vector2i) -> int:
	var screen_row: int = 7 - pos.y
	return screen_row * BOARD_SIZE + pos.x

func _on_tile_button_pressed(pos: Vector2i) -> void:
	tile_clicked.emit(pos)

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
			# If user clicked another friendly piece, reselect
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

		# 1. Update Highlight
		if hl != null:
			if pos == selected_cell:
				hl.color = COLOR_HIGHLIGHT_SELECT
			elif highlighted_moves.has(pos):
				var target_piece: PieceData = turn_manager.board.get_piece(pos) if turn_manager != null and turn_manager.board != null else null
				if target_piece != null:
					hl.color = COLOR_HIGHLIGHT_CAPTURE
				else:
					hl.color = COLOR_HIGHLIGHT_MOVE
			else:
				hl.color = Color(0, 0, 0, 0)

		# 2. Update Piece Icon
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

					# Apply stealth or clone visual tweak if needed
					if piece.is_stealth:
						piece_icon.modulate = Color(1.0, 1.0, 1.0, 0.45)
					else:
						piece_icon.modulate = Color.WHITE
				else:
					piece_icon.texture = null
					piece_icon.visible = false
			else:
				piece_icon.texture = null
				piece_icon.visible = false

		# 3. Update Status Overlay
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

# Shaders support
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
