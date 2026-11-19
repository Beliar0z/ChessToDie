# res://src/core/move_validator.gd
# GDScript / move_validator.gd / Godot 4.7 / Core Engine
class_name MoveValidator
extends RefCounted

static func get_pseudo_legal_moves(board: BoardState, from_pos: Vector2i, holy_war_active: bool = false, include_castling: bool = true) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var piece: PieceData = board.get_piece(from_pos)
	if piece == null or piece.is_locked or piece.is_banned:
		return moves
	if piece.type == PieceData.PieceType.SCARECROW or piece.type == PieceData.PieceType.HEAL_POINT:
		return moves

	# Custom mode overrides
	if piece.custom_move_mode != "":
		match piece.custom_move_mode:
			"LINEAR":
				_add_rook_moves(board, from_pos, piece, moves, holy_war_active)
				return moves
			"DIAGONAL":
				_add_bishop_moves(board, from_pos, piece, moves, holy_war_active)
				return moves
			"KNIGHT_STEP":
				_add_knight_moves(board, from_pos, piece, moves, holy_war_active)
				return moves
			"ROOK":
				_add_rook_moves(board, from_pos, piece, moves, holy_war_active)
				return moves
			"KNIGHT":
				_add_knight_moves(board, from_pos, piece, moves, holy_war_active)
				return moves
			"BISHOP":
				_add_bishop_moves(board, from_pos, piece, moves, holy_war_active)
				return moves
			"QUEEN":
				_add_queen_moves(board, from_pos, piece, moves, holy_war_active)
				return moves

	match piece.type:
		PieceData.PieceType.PAWN:
			_add_pawn_moves(board, from_pos, piece, moves, holy_war_active)
		PieceData.PieceType.KNIGHT:
			_add_knight_moves(board, from_pos, piece, moves, holy_war_active)
		PieceData.PieceType.BISHOP:
			_add_bishop_moves(board, from_pos, piece, moves, holy_war_active)
		PieceData.PieceType.ROOK:
			_add_rook_moves(board, from_pos, piece, moves, holy_war_active)
		PieceData.PieceType.QUEEN:
			_add_queen_moves(board, from_pos, piece, moves, holy_war_active)
		PieceData.PieceType.KING:
			_add_king_moves(board, from_pos, piece, moves, holy_war_active, include_castling)
		PieceData.PieceType.SUPER_PAWN:
			_add_super_pawn_moves(board, from_pos, piece, moves, holy_war_active)
		PieceData.PieceType.SUPER_KNIGHT:
			_add_super_knight_moves(board, from_pos, piece, moves, holy_war_active)
		PieceData.PieceType.SUPER_BISHOP:
			_add_super_bishop_moves(board, from_pos, piece, moves, holy_war_active)
		PieceData.PieceType.SUPER_ROOK:
			_add_super_rook_moves(board, from_pos, piece, moves, holy_war_active)
		PieceData.PieceType.SUPER_QUEEN:
			_add_super_queen_moves(board, from_pos, piece, moves, holy_war_active)

	return moves

static func _can_occupy_or_capture(board: BoardState, from_pos: Vector2i, to_pos: Vector2i, piece: PieceData, holy_war_active: bool) -> bool:
	if not board.is_valid_cell(to_pos):
		return false
	if board.is_cell_forbidden(to_pos):
		return false

	# River barrier check: between y=3 and y=4
	if board.river_barrier_active:
		if (from_pos.y <= 3 and to_pos.y >= 4) or (from_pos.y >= 4 and to_pos.y <= 3):
			return false

	var target: PieceData = board.get_piece(to_pos)
	if target == null:
		return true

	# Cannot capture allies
	if target.team == piece.team:
		return false

	# Decision A in Holy War: King can capture King directly
	if holy_war_active and piece.type == PieceData.PieceType.KING and target.type == PieceData.PieceType.KING:
		return true

	# Cannot capture if piece cannot attack
	if not piece.can_attack():
		return false

	# Cannot capture uncapturable targets
	if not target.can_be_captured():
		return false

	return true

static func _add_pawn_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	var forward: int = 1 if piece.team == PieceData.Team.WHITE else -1
	var start_rank: int = 1 if piece.team == PieceData.Team.WHITE else 6

	# 1 square forward
	var one_step: Vector2i = Vector2i(from_pos.x, from_pos.y + forward)
	if board.is_valid_cell(one_step) and not board.is_cell_forbidden(one_step) and board.get_piece(one_step) == null:
		if not (board.river_barrier_active and ((from_pos.y <= 3 and one_step.y >= 4) or (from_pos.y >= 4 and one_step.y <= 3))):
			moves.append(one_step)
			# 2 squares forward from start rank
			if from_pos.y == start_rank:
				var two_steps: Vector2i = Vector2i(from_pos.x, from_pos.y + 2 * forward)
				if board.is_valid_cell(two_steps) and not board.is_cell_forbidden(two_steps) and board.get_piece(two_steps) == null:
					if not (board.river_barrier_active and ((from_pos.y <= 3 and two_steps.y >= 4) or (from_pos.y >= 4 and two_steps.y <= 3))):
						moves.append(two_steps)

	# Diagonal captures
	for dx in [-1, 1]:
		var diag: Vector2i = Vector2i(from_pos.x + dx, from_pos.y + forward)
		if board.is_valid_cell(diag) and not board.is_cell_forbidden(diag):
			var target: PieceData = board.get_piece(diag)
			if target != null and target.team != piece.team:
				if _can_occupy_or_capture(board, from_pos, diag, piece, holy_war_active):
					moves.append(diag)

static func _add_super_pawn_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	# Super Pawn: can move forward, backward, diagonally 1 step
	var directions: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1),
		Vector2i(1, -1), Vector2i(-1, -1)
	]
	for d in directions:
		var target_pos: Vector2i = from_pos + d
		if _can_occupy_or_capture(board, from_pos, target_pos, piece, holy_war_active):
			moves.append(target_pos)

static func _add_knight_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	var offsets: Array[Vector2i] = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
		Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)
	]
	for off in offsets:
		var target_pos: Vector2i = from_pos + off
		if _can_occupy_or_capture(board, from_pos, target_pos, piece, holy_war_active):
			moves.append(target_pos)

static func _add_super_knight_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	# Extended Knight jump (+1 range)
	var offsets: Array[Vector2i] = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
		Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1),
		Vector2i(1, 3), Vector2i(3, 1), Vector2i(-1, 3), Vector2i(-3, 1),
		Vector2i(1, -3), Vector2i(3, -1), Vector2i(-1, -3), Vector2i(-3, -1),
		Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2)
	]
	for off in offsets:
		var target_pos: Vector2i = from_pos + off
		if _can_occupy_or_capture(board, from_pos, target_pos, piece, holy_war_active):
			moves.append(target_pos)

static func _add_ray_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, directions: Array[Vector2i], moves: Array[Vector2i], holy_war_active: bool) -> void:
	for dir in directions:
		var cur: Vector2i = from_pos + dir
		while board.is_valid_cell(cur):
			if board.is_cell_forbidden(cur):
				break
			if board.river_barrier_active and ((cur.y == 4 and cur.y - dir.y == 3) or (cur.y == 3 and cur.y - dir.y == 4)):
				break
			var target: PieceData = board.get_piece(cur)
			if target == null:
				moves.append(cur)
			else:
				if _can_occupy_or_capture(board, from_pos, cur, piece, holy_war_active):
					moves.append(cur)
				break
			cur += dir

static func _add_bishop_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	_add_ray_moves(board, from_pos, piece, dirs, moves, holy_war_active)

static func _add_super_bishop_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	_add_bishop_moves(board, from_pos, piece, moves, holy_war_active)
	# Can step 1 orthogonally to switch square color
	var ortho: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in ortho:
		var target_pos: Vector2i = from_pos + d
		if _can_occupy_or_capture(board, from_pos, target_pos, piece, holy_war_active):
			if not moves.has(target_pos):
				moves.append(target_pos)

static func _add_rook_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	_add_ray_moves(board, from_pos, piece, dirs, moves, holy_war_active)

static func _add_super_rook_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	_add_rook_moves(board, from_pos, piece, moves, holy_war_active)
	# Diagonals 1 step
	var diag: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for d in diag:
		var target_pos: Vector2i = from_pos + d
		if _can_occupy_or_capture(board, from_pos, target_pos, piece, holy_war_active):
			if not moves.has(target_pos):
				moves.append(target_pos)

static func _add_queen_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	_add_ray_moves(board, from_pos, piece, dirs, moves, holy_war_active)

static func _add_super_queen_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool) -> void:
	_add_queen_moves(board, from_pos, piece, moves, holy_war_active)
	_add_knight_moves(board, from_pos, piece, moves, holy_war_active)

static func _add_king_moves(board: BoardState, from_pos: Vector2i, piece: PieceData, moves: Array[Vector2i], holy_war_active: bool, include_castling: bool = true) -> void:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	for d in dirs:
		var target_pos: Vector2i = from_pos + d
		if _can_occupy_or_capture(board, from_pos, target_pos, piece, holy_war_active):
			moves.append(target_pos)

	# Castling (only if not holy war, not moved, not in check, and include_castling is true)
	if include_castling and not holy_war_active and piece.move_count == 0 and not is_in_check(board, piece.team):
		var y: int = from_pos.y
		# Kingside (towards x=7)
		var rook_k: PieceData = board.get_piece(Vector2i(7, y))
		if rook_k != null and rook_k.type == PieceData.PieceType.ROOK and rook_k.move_count == 0:
			if board.get_piece(Vector2i(5, y)) == null and board.get_piece(Vector2i(6, y)) == null:
				var opp_team: PieceData.Team = PieceData.Team.BLACK if piece.team == PieceData.Team.WHITE else PieceData.Team.WHITE
				if not is_square_attacked(board, Vector2i(5, y), opp_team) and not is_square_attacked(board, Vector2i(6, y), opp_team):
					moves.append(Vector2i(6, y))
		# Queenside (towards x=0)
		var rook_q: PieceData = board.get_piece(Vector2i(0, y))
		if rook_q != null and rook_q.type == PieceData.PieceType.ROOK and rook_q.move_count == 0:
			if board.get_piece(Vector2i(1, y)) == null and board.get_piece(Vector2i(2, y)) == null and board.get_piece(Vector2i(3, y)) == null:
				var opp_team: PieceData.Team = PieceData.Team.BLACK if piece.team == PieceData.Team.WHITE else PieceData.Team.WHITE
				if not is_square_attacked(board, Vector2i(2, y), opp_team) and not is_square_attacked(board, Vector2i(3, y), opp_team):
					moves.append(Vector2i(2, y))

static func is_square_attacked(board: BoardState, pos: Vector2i, by_team: PieceData.Team) -> bool:
	for y in range(BoardState.BOARD_SIZE):
		for x in range(BoardState.BOARD_SIZE):
			var p: PieceData = board.grid[y][x] as PieceData
			if p != null and p.team == by_team and p.can_attack():
				if p.type == PieceData.PieceType.PAWN:
					var forward: int = 1 if p.team == PieceData.Team.WHITE else -1
					if pos == Vector2i(x - 1, y + forward) or pos == Vector2i(x + 1, y + forward):
						return true
				elif p.type == PieceData.PieceType.KING:
					if abs(pos.x - x) <= 1 and abs(pos.y - y) <= 1:
						return true
				else:
					var attacks: Array[Vector2i] = get_pseudo_legal_moves(board, Vector2i(x, y), false, false)
					if attacks.has(pos):
						return true
	return false

static func is_in_check(board: BoardState, team: PieceData.Team) -> bool:
	var king_pos: Vector2i = board.find_king(team)
	if king_pos == Vector2i(-1, -1):
		return false
	var king: PieceData = board.get_piece(king_pos)
	if king != null and king.has_shield:
		return false
	var opp_team: PieceData.Team = PieceData.Team.BLACK if team == PieceData.Team.WHITE else PieceData.Team.WHITE
	return is_square_attacked(board, king_pos, opp_team)

static func get_legal_moves(board: BoardState, from_pos: Vector2i, holy_war_active: bool = false) -> Array[Vector2i]:
	var legal: Array[Vector2i] = []
	var piece: PieceData = board.get_piece(from_pos)
	if piece == null:
		return legal

	var pseudos: Array[Vector2i] = get_pseudo_legal_moves(board, from_pos, holy_war_active)
	for dest in pseudos:
		if holy_war_active:
			# In Holy War, Kings can move adjacent and attack each other directly
			legal.append(dest)
			continue

		# Simulate move to verify king is not in check
		var sim_board: BoardState = board.clone()
		sim_board.move_piece(from_pos, dest)

		# If moving King had shield, check shield
		if not is_in_check(sim_board, piece.team):
			legal.append(dest)

	return legal

static func get_all_legal_moves(board: BoardState, team: PieceData.Team, holy_war_active: bool = false) -> Array[Dictionary]:
	var all_moves: Array[Dictionary] = []
	for y in range(BoardState.BOARD_SIZE):
		for x in range(BoardState.BOARD_SIZE):
			var p: PieceData = board.grid[y][x] as PieceData
			if p != null and p.team == team:
				var from_pos: Vector2i = Vector2i(x, y)
				var moves: Array[Vector2i] = get_legal_moves(board, from_pos, holy_war_active)
				for dest in moves:
					all_moves.append({"from": from_pos, "to": dest})
	return all_moves

static func is_checkmate(board: BoardState, team: PieceData.Team, holy_war_active: bool = false) -> bool:
	if holy_war_active:
		return false
	if not is_in_check(board, team):
		return false
	var legal_moves: Array[Dictionary] = get_all_legal_moves(board, team, holy_war_active)
	return legal_moves.is_empty()

static func is_stalemate(board: BoardState, team: PieceData.Team, holy_war_active: bool = false) -> bool:
	if is_in_check(board, team):
		return false
	var legal_moves: Array[Dictionary] = get_all_legal_moves(board, team, holy_war_active)
	return legal_moves.is_empty()
