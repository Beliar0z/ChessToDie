# res://src/core/death_ring_system.gd
# GDScript / death_ring_system.gd / Godot 4.7 / Core Engine
class_name DeathRingSystem
extends RefCounted

var is_death_ring_active: bool = false
var is_holy_war_active: bool = false

var initial_points_white: float = 0.0
var initial_points_black: float = 0.0

var current_points_white: float = 0.0
var current_points_black: float = 0.0

var burn_rate_per_turn: float = 1.0
var heal_points_spawned: Array[Vector2i] = []

func _init() -> void:
	reset()

func reset() -> void:
	is_death_ring_active = false
	is_holy_war_active = false
	initial_points_white = 0.0
	initial_points_black = 0.0
	current_points_white = 0.0
	current_points_black = 0.0
	burn_rate_per_turn = 1.0
	heal_points_spawned.clear()

func activate_death_ring(board: BoardState) -> void:
	is_death_ring_active = true
	# Capture total team points at onset
	initial_points_white = board.get_total_team_points(PieceData.Team.WHITE)
	initial_points_black = board.get_total_team_points(PieceData.Team.BLACK)
	current_points_white = initial_points_white
	current_points_black = initial_points_black

	# Reset living pieces back to original starting positions
	_reposition_pieces_to_origin(board)

	# Spawn initial heal point on board
	spawn_heal_point(board)

func check_and_activate_holy_war(board: BoardState) -> bool:
	var white_pieces: Array[Dictionary] = board.get_all_pieces(PieceData.Team.WHITE)
	var black_pieces: Array[Dictionary] = board.get_all_pieces(PieceData.Team.BLACK)

	# Holy war triggers when ONLY the 2 Kings remain on the entire board
	if white_pieces.size() == 1 and black_pieces.size() == 1:
		var p_w: PieceData = white_pieces[0]["piece"]
		var p_b: PieceData = black_pieces[0]["piece"]
		if p_w.type == PieceData.PieceType.KING and p_b.type == PieceData.PieceType.KING:
			is_holy_war_active = true
			is_death_ring_active = true
			return true
	return false

func process_turn_burn(board: BoardState, active_team: PieceData.Team) -> Dictionary:
	var result: Dictionary = {
		"points_white": current_points_white,
		"points_black": current_points_black,
		"game_over": false,
		"winner": -1, # -1 none, 0 white, 1 black
		"reason": ""
	}

	if not is_death_ring_active:
		return result

	# Burn current points
	if active_team == PieceData.Team.WHITE:
		current_points_white = max(0.0, current_points_white - burn_rate_per_turn)
	else:
		current_points_black = max(0.0, current_points_black - burn_rate_per_turn)

	result["points_white"] = current_points_white
	result["points_black"] = current_points_black

	# Decision B: If points reach 0 without checkmate:
	# The team that had the HIGHER initial points LOSES.
	if current_points_white <= 0.0 or current_points_black <= 0.0:
		result["game_over"] = true
		result["reason"] = "DEATH_RING_POINTS_DEPLETED"
		if initial_points_white > initial_points_black:
			# White had higher initial points -> White loses -> Black wins
			result["winner"] = int(PieceData.Team.BLACK)
		elif initial_points_black > initial_points_white:
			# Black had higher initial points -> Black loses -> White wins
			result["winner"] = int(PieceData.Team.WHITE)
		else:
			# Tiebreaker if equal
			result["winner"] = int(PieceData.Team.WHITE if current_points_white > current_points_black else PieceData.Team.BLACK)

	return result

func spawn_heal_point(board: BoardState) -> Vector2i:
	for attempt in range(20):
		var rx: int = randi() % BoardState.BOARD_SIZE
		var ry: int = 2 + (randi() % 4) # spawn in central ranks 2..5
		var pos: Vector2i = Vector2i(rx, ry)
		if board.get_piece(pos) == null and not board.is_cell_forbidden(pos):
			var hp_piece: PieceData = PieceData.new(PieceData.PieceType.HEAL_POINT, PieceData.Team.WHITE)
			board.set_piece(pos, hp_piece)
			heal_points_spawned.append(pos)
			return pos
	return Vector2i(-1, -1)

func _reposition_pieces_to_origin(board: BoardState) -> void:
	# Keep track of pieces
	var living: Array[PieceData] = []
	for y in range(BoardState.BOARD_SIZE):
		for x in range(BoardState.BOARD_SIZE):
			var p: PieceData = board.grid[y][x] as PieceData
			if p != null and p.type != PieceData.PieceType.HEAL_POINT and p.type != PieceData.PieceType.SCARECROW:
				living.append(p)

	# Clean grid
	for y in range(BoardState.BOARD_SIZE):
		for x in range(BoardState.BOARD_SIZE):
			board.grid[y][x] = null

	# Put back King, then others in available standard slots
	for p in living:
		var target_pos: Vector2i = _get_default_slot(p.type, p.team, board)
		board.set_piece(target_pos, p)

func _get_default_slot(type: PieceData.PieceType, team: PieceData.Team, board: BoardState) -> Vector2i:
	var base_y: int = 0 if team == PieceData.Team.WHITE else 7
	var pawn_y: int = 1 if team == PieceData.Team.WHITE else 6

	if type == PieceData.PieceType.KING:
		return Vector2i(4, base_y)

	if type == PieceData.PieceType.PAWN or type == PieceData.PieceType.SUPER_PAWN:
		for x in range(BoardState.BOARD_SIZE):
			if board.get_piece(Vector2i(x, pawn_y)) == null:
				return Vector2i(x, pawn_y)

	for x in range(BoardState.BOARD_SIZE):
		if board.get_piece(Vector2i(x, base_y)) == null:
			return Vector2i(x, base_y)

	# fallback
	for y in range(BoardState.BOARD_SIZE):
		for x in range(BoardState.BOARD_SIZE):
			if board.get_piece(Vector2i(x, y)) == null:
				return Vector2i(x, y)

	return Vector2i(0, 0)
