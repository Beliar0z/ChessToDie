# res://src/scenes/board_view.gd
# GDScript / board_view.gd / Godot 4.7 / UI Bridge
class_name BoardView
extends Node2D

const CELL_SIZE: float = 80.0
const BOARD_OFFSET: Vector2 = Vector2(100.0, 100.0)

var turn_manager: TurnManager
var selected_cell: Vector2i = Vector2i(-1, -1)
var highlighted_moves: Array[Vector2i] = []

func _ready() -> void:
	if turn_manager == null:
		turn_manager = TurnManager.new()
		turn_manager.start_game()
	queue_redraw()

func _draw() -> void:
	# Draw 8x8 squares
	for y in range(BoardState.BOARD_SIZE):
		for x in range(BoardState.BOARD_SIZE):
			var rect_pos: Vector2 = BOARD_OFFSET + Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var rect: Rect2 = Rect2(rect_pos, Vector2(CELL_SIZE, CELL_SIZE))
			var is_light: bool = (x + y) % 2 == 0
			var square_color: Color = Color(0.85, 0.85, 0.85) if is_light else Color(0.3, 0.35, 0.4)

			if Vector2i(x, y) == selected_cell:
				square_color = Color(0.9, 0.8, 0.2, 0.8)
			elif highlighted_moves.has(Vector2i(x, y)):
				square_color = Color(0.2, 0.8, 0.3, 0.6)

			draw_rect(rect, square_color)
			draw_rect(rect, Color(0.1, 0.1, 0.1, 0.5), false, 1.0)

			# Draw piece fallback / representation
			if turn_manager != null and turn_manager.board != null:
				var piece: PieceData = turn_manager.board.get_piece(Vector2i(x, y))
				if piece != null:
					_draw_piece(rect_pos, piece)

func _draw_piece(cell_origin: Vector2, piece: PieceData) -> void:
	var asset_path: String = _get_piece_asset_path(piece)
	if asset_path != "" and ResourceLoader.exists(asset_path):
		var tex: Texture2D = load(asset_path) as Texture2D
		if tex != null:
			draw_texture_rect(tex, Rect2(cell_origin + Vector2(8, 8), Vector2(CELL_SIZE - 16, CELL_SIZE - 16)), false)
			return

	var center: Vector2 = cell_origin + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	var radius: float = CELL_SIZE * 0.35
	var color: Color = Color(0.95, 0.95, 0.95) if piece.team == PieceData.Team.WHITE else Color(0.15, 0.15, 0.15)
	var border_color: Color = Color(0.1, 0.1, 0.1) if piece.team == PieceData.Team.WHITE else Color(0.9, 0.9, 0.9)

	draw_circle(center, radius, color)
	draw_arc(center, radius, 0, TAU, 32, border_color, 2.0)

	# Label fallback
	var text: String = piece.get_type_name().substr(0, 2)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, center + Vector2(-10, 5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, border_color)

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

func select_cell(pos: Vector2i) -> void:
	if turn_manager == null:
		return
	if selected_cell == Vector2i(-1, -1):
		var piece: PieceData = turn_manager.board.get_piece(pos)
		if piece != null and piece.team == turn_manager.current_turn_team:
			selected_cell = pos
			highlighted_moves = MoveValidator.get_legal_moves(turn_manager.board, pos, turn_manager.death_ring_system.is_holy_war_active)
	else:
		if highlighted_moves.has(pos):
			turn_manager.execute_move(selected_cell, pos)
		selected_cell = Vector2i(-1, -1)
		highlighted_moves.clear()
	queue_redraw()
