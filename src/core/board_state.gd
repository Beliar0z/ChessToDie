# res://src/core/board_state.gd
# GDScript / board_state.gd / Godot 4.7 / Core Engine
class_name BoardState
extends RefCounted

const BOARD_SIZE: int = 8

# 8x8 grid where grid[y][x] contains PieceData or null
var grid: Array = []

var grave_white: Array[PieceData] = []
var grave_black: Array[PieceData] = []

var white_points_captured: int = 0
var black_points_captured: int = 0

var move_history: Array[Dictionary] = []

# Special mechanic fields
var forbidden_cells: Dictionary = {} # Vector2i -> int (turns_remaining)
var river_barrier_active: bool = false
var river_barrier_turns: int = 0
var gravity_vortex: Dictionary = {} # "center": Vector2i, "turns": int
var fire_diagonals: Array[Vector2i] = []
var barrier_burn_zones: Dictionary = {} # Vector2i -> Dictionary {"turns": int, "origin_team": int}

func _init() -> void:
	_init_empty_grid()

func _init_empty_grid() -> void:
	grid.clear()
	for y in range(BOARD_SIZE):
		var row: Array = []
		for x in range(BOARD_SIZE):
			row.append(null)
		grid.append(row)

func setup_initial_board() -> void:
	_init_empty_grid()
	grave_white.clear()
	grave_black.clear()
	white_points_captured = 0
	black_points_captured = 0
	move_history.clear()
	forbidden_cells.clear()
	river_barrier_active = false
	river_barrier_turns = 0
	gravity_vortex.clear()
	fire_diagonals.clear()
	barrier_burn_zones.clear()

	# White back rank (y = 0)
	set_piece(Vector2i(0, 0), PieceData.new(PieceData.PieceType.ROOK, PieceData.Team.WHITE))
	set_piece(Vector2i(1, 0), PieceData.new(PieceData.PieceType.KNIGHT, PieceData.Team.WHITE))
	set_piece(Vector2i(2, 0), PieceData.new(PieceData.PieceType.BISHOP, PieceData.Team.WHITE))
	set_piece(Vector2i(3, 0), PieceData.new(PieceData.PieceType.QUEEN, PieceData.Team.WHITE))
	set_piece(Vector2i(4, 0), PieceData.new(PieceData.PieceType.KING, PieceData.Team.WHITE))
	set_piece(Vector2i(5, 0), PieceData.new(PieceData.PieceType.BISHOP, PieceData.Team.WHITE))
	set_piece(Vector2i(6, 0), PieceData.new(PieceData.PieceType.KNIGHT, PieceData.Team.WHITE))
	set_piece(Vector2i(7, 0), PieceData.new(PieceData.PieceType.ROOK, PieceData.Team.WHITE))

	# White pawns (y = 1)
	for x in range(BOARD_SIZE):
		set_piece(Vector2i(x, 1), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.WHITE))

	# Black pawns (y = 6)
	for x in range(BOARD_SIZE):
		set_piece(Vector2i(x, 6), PieceData.new(PieceData.PieceType.PAWN, PieceData.Team.BLACK))

	# Black back rank (y = 7)
	set_piece(Vector2i(0, 7), PieceData.new(PieceData.PieceType.ROOK, PieceData.Team.BLACK))
	set_piece(Vector2i(1, 7), PieceData.new(PieceData.PieceType.KNIGHT, PieceData.Team.BLACK))
	set_piece(Vector2i(2, 7), PieceData.new(PieceData.PieceType.BISHOP, PieceData.Team.BLACK))
	set_piece(Vector2i(3, 7), PieceData.new(PieceData.PieceType.QUEEN, PieceData.Team.BLACK))
	set_piece(Vector2i(4, 7), PieceData.new(PieceData.PieceType.KING, PieceData.Team.BLACK))
	set_piece(Vector2i(5, 7), PieceData.new(PieceData.PieceType.BISHOP, PieceData.Team.BLACK))
	set_piece(Vector2i(6, 7), PieceData.new(PieceData.PieceType.KNIGHT, PieceData.Team.BLACK))
	set_piece(Vector2i(7, 7), PieceData.new(PieceData.PieceType.ROOK, PieceData.Team.BLACK))

func is_valid_cell(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

func is_cell_forbidden(pos: Vector2i) -> bool:
	if not is_valid_cell(pos):
		return true
	return forbidden_cells.has(pos) and int(forbidden_cells[pos]) > 0

func get_piece(pos: Vector2i) -> PieceData:
	if not is_valid_cell(pos):
		return null
	return grid[pos.y][pos.x] as PieceData

func set_piece(pos: Vector2i, piece: PieceData) -> void:
	if not is_valid_cell(pos):
		return
	grid[pos.y][pos.x] = piece

func remove_piece(pos: Vector2i) -> PieceData:
	if not is_valid_cell(pos):
		return null
	var piece: PieceData = grid[pos.y][pos.x] as PieceData
	grid[pos.y][pos.x] = null
	return piece

func move_piece(from_pos: Vector2i, to_pos: Vector2i) -> PieceData:
	var piece: PieceData = get_piece(from_pos)
	if piece == null or not is_valid_cell(to_pos):
		return null

	var captured_piece: PieceData = get_piece(to_pos)
	if captured_piece != null:
		if captured_piece.team == PieceData.Team.WHITE:
			grave_white.append(captured_piece)
			black_points_captured += captured_piece.points
		else:
			grave_black.append(captured_piece)
			white_points_captured += captured_piece.points

	set_piece(to_pos, piece)
	set_piece(from_pos, null)
	piece.move_count += 1
	piece.curse_moved = true

	# Pawn promotion to Queen on back rank
	if piece.type == PieceData.PieceType.PAWN:
		if (piece.team == PieceData.Team.WHITE and to_pos.y == BOARD_SIZE - 1) or (piece.team == PieceData.Team.BLACK and to_pos.y == 0):
			piece.type = PieceData.PieceType.QUEEN
			piece.points = PieceData.get_default_points(PieceData.PieceType.QUEEN)

	move_history.append({
		"from": from_pos,
		"to": to_pos,
		"piece": piece,
		"captured": captured_piece
	})

	return captured_piece

func find_king(team: PieceData.Team) -> Vector2i:
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var p: PieceData = grid[y][x] as PieceData
			if p != null and p.type == PieceData.PieceType.KING and p.team == team:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func get_all_pieces(team: PieceData.Team) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var p: PieceData = grid[y][x] as PieceData
			if p != null and p.team == team:
				result.append({"pos": Vector2i(x, y), "piece": p})
	return result

func get_total_team_points(team: PieceData.Team) -> float:
	var total: float = 0.0
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var p: PieceData = grid[y][x] as PieceData
			if p != null and p.team == team:
				total += float(p.points)
	return total

func get_team_piece_count(team: PieceData.Team) -> int:
	var count: int = 0
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var p: PieceData = grid[y][x] as PieceData
			if p != null and p.team == team:
				count += 1
	return count

func clone() -> BoardState:
	var new_board: BoardState = BoardState.new()
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var p: PieceData = grid[y][x] as PieceData
			if p != null:
				new_board.grid[y][x] = p.clone()
			else:
				new_board.grid[y][x] = null

	for p in grave_white:
		new_board.grave_white.append(p.clone())
	for p in grave_black:
		new_board.grave_black.append(p.clone())

	new_board.white_points_captured = white_points_captured
	new_board.black_points_captured = black_points_captured

	for cell in forbidden_cells:
		new_board.forbidden_cells[cell] = forbidden_cells[cell]

	new_board.river_barrier_active = river_barrier_active
	new_board.river_barrier_turns = river_barrier_turns

	for k in gravity_vortex:
		new_board.gravity_vortex[k] = gravity_vortex[k]

	new_board.fire_diagonals = fire_diagonals.duplicate()

	for cell in barrier_burn_zones:
		new_board.barrier_burn_zones[cell] = barrier_burn_zones[cell].duplicate()

	return new_board
