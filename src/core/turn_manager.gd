# res://src/core/turn_manager.gd
# GDScript / turn_manager.gd / Godot 4.7 / Core Engine
class_name TurnManager
extends RefCounted

enum Phase {
	DRAW_PHASE,
	MAIN_PHASE,
	MOVE_PHASE,
	END_PHASE
}

var current_phase: Phase = Phase.DRAW_PHASE
var current_turn_team: PieceData.Team = PieceData.Team.WHITE
var turn_number: int = 1
var total_moves_played: int = 0

var board: BoardState
var white_engine: CardEngine
var black_engine: CardEngine
var passive_manager: PassiveManager
var death_ring_system: DeathRingSystem

var is_game_over: bool = false
var winner: int = -1 # -1: none, 0: white, 1: black, 2: draw
var game_over_reason: String = ""

# Interception survival state
var interception_extra_moves: int = 0
var interception_scope: String = "" # "KING" or "ALL"

func _init(p_board: BoardState = null) -> void:
	if p_board != null:
		board = p_board
	else:
		board = BoardState.new()
		board.setup_initial_board()

	white_engine = CardEngine.new(PieceData.Team.WHITE)
	black_engine = CardEngine.new(PieceData.Team.BLACK)
	passive_manager = PassiveManager.new()
	death_ring_system = DeathRingSystem.new()

	white_engine.setup_default_deck()
	black_engine.setup_default_deck()

func start_game() -> void:
	turn_number = 1
	total_moves_played = 0
	current_turn_team = PieceData.Team.WHITE
	current_phase = Phase.DRAW_PHASE
	is_game_over = false
	winner = -1
	game_over_reason = ""
	interception_extra_moves = 0
	interception_scope = ""

	white_engine.draw_initial_hand()
	black_engine.draw_initial_hand()

	start_turn()

func start_turn() -> void:
	current_phase = Phase.DRAW_PHASE
	var current_engine: CardEngine = get_current_engine()
	current_engine.reset_turn_limits()

	# Check and activate holy war if only 2 kings left
	death_ring_system.check_and_activate_holy_war(board)

	# Transition to Main Phase
	current_phase = Phase.MAIN_PHASE

func get_current_engine() -> CardEngine:
	return white_engine if current_turn_team == PieceData.Team.WHITE else black_engine

func get_opponent_engine() -> CardEngine:
	return black_engine if current_turn_team == PieceData.Team.WHITE else white_engine

func get_opponent_team() -> PieceData.Team:
	return PieceData.Team.BLACK if current_turn_team == PieceData.Team.WHITE else PieceData.Team.WHITE

# Phase 2: Main Phase actions
func play_active_card(card: CardResource, target_pos: Vector2i = Vector2i(-1, -1), extra_pos: Vector2i = Vector2i(-1, -1)) -> bool:
	if current_phase != Phase.MAIN_PHASE:
		return false
	var engine: CardEngine = get_current_engine()
	if not engine.can_play_active(card):
		return false

	# Check opponent passive counter (PASSIVE_04 COUNTER_ACTIVE)
	var opp_team: PieceData.Team = get_opponent_team()
	var opp_slots: Array[Dictionary] = passive_manager.get_slots(opp_team)
	for i in range(opp_slots.size()):
		var slot: Dictionary = opp_slots[i]
		var p_card: CardResource = slot.get("card", null)
		if p_card != null and p_card.id == "PASSIVE_04" and not passive_manager.is_muted(opp_team):
			passive_manager.remove_passive_at(opp_team, i)
			engine.play_active(card) # Consume card
			return false # Countered!

	if not engine.play_active(card):
		return false

	_execute_active_effect(card, target_pos, extra_pos)
	return true

func place_passive_card(card: CardResource) -> bool:
	if current_phase != Phase.MAIN_PHASE:
		return false
	if not passive_manager.can_place_passive(current_turn_team):
		return false
	var engine: CardEngine = get_current_engine()
	if not engine.can_place_passive(card):
		return false

	var taken: CardResource = engine.take_passive_from_hand(card)
	if taken == null:
		return false

	return passive_manager.place_passive(current_turn_team, taken, turn_number)

# Phase 3: Move Phase
func execute_move(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if is_game_over:
		return false
	if current_phase != Phase.MAIN_PHASE and current_phase != Phase.MOVE_PHASE:
		return false

	current_phase = Phase.MOVE_PHASE

	var piece: PieceData = board.get_piece(from_pos)
	if piece == null or piece.team != current_turn_team:
		return false

	# If in checkmate interception with KING scope, only King can move
	if interception_extra_moves > 0 and interception_scope == "KING" and piece.type != PieceData.PieceType.KING:
		return false

	var is_holy_war: bool = death_ring_system.is_holy_war_active
	var allow_king_attacks: bool = is_holy_war or (interception_extra_moves > 0 and interception_scope == "KING")
	var legal_moves: Array[Vector2i] = MoveValidator.get_legal_moves(board, from_pos, allow_king_attacks)
	if not legal_moves.has(to_pos):
		return false

	var captured: PieceData = board.move_piece(from_pos, to_pos)
	total_moves_played += 1

	# King slain condition (Holy War or PASSIVE_15 counter-kill)
	if captured != null and captured.type == PieceData.PieceType.KING:
		is_game_over = true
		winner = int(current_turn_team)
		game_over_reason = "KING_SLAIN"
		return true

	# Check card draw trigger: every 2 moves by self
	var engine: CardEngine = get_current_engine()
	engine.on_move_completed()

	# Interception extra moves handling
	if interception_extra_moves > 0:
		interception_extra_moves -= 1
		if interception_extra_moves > 0:
			# Still has extra move in interception window
			return true

	end_turn()
	return true

# Phase 4: End Phase
func end_turn() -> void:
	current_phase = Phase.END_PHASE

	# 1. Update countdowns of active piece effects
	_process_piece_status_countdowns()

	# 2. Process board special mechanic turns
	_process_board_hazards()

	# 3. Process Death Ring burn if active
	if death_ring_system.is_death_ring_active:
		var burn_res: Dictionary = death_ring_system.process_turn_burn(board, current_turn_team)
		if burn_res.get("game_over", false):
			is_game_over = true
			winner = burn_res.get("winner", -1)
			game_over_reason = burn_res.get("reason", "DEATH_RING_POINTS_DEPLETED")
			return

	# 4. Notify passive manager of turn end
	passive_manager.on_turn_end(current_turn_team)

	# 5. Check opponent checkmate / stalemate
	var opp_team: PieceData.Team = get_opponent_team()
	var opp_in_check: bool = MoveValidator.is_in_check(board, opp_team)
	var is_holy_war: bool = death_ring_system.is_holy_war_active

	if MoveValidator.is_checkmate(board, opp_team, is_holy_war):
		# Interception hook
		var hook_res: Dictionary = passive_manager.trigger_checkmate_hook(opp_team)
		if hook_res.get("intercepted", false):
			interception_extra_moves = hook_res.get("extra_moves_granted", 2)
			interception_scope = hook_res.get("target_scope", "KING")
			# Checkmate postponed, give turn to opponent
			_switch_turn()
			return
		else:
			is_game_over = true
			winner = int(current_turn_team)
			game_over_reason = "CHECKMATE"
			return

	elif MoveValidator.is_stalemate(board, opp_team, is_holy_war):
		if not death_ring_system.is_death_ring_active:
			death_ring_system.activate_death_ring(board)

	_switch_turn()

func _switch_turn() -> void:
	current_turn_team = get_opponent_team()
	if current_turn_team == PieceData.Team.WHITE:
		turn_number += 1
	start_turn()

func set_holy_war_king_move_mode(team: PieceData.Team, mode: String) -> bool:
	if not death_ring_system.is_holy_war_active:
		return false
	var kpos: Vector2i = board.find_king(team)
	if kpos == Vector2i(-1, -1):
		return false
	var king: PieceData = board.get_piece(kpos)
	if king != null:
		king.custom_move_mode = mode
		return true
	return false

func _process_piece_status_countdowns() -> void:
	for y in range(BoardState.BOARD_SIZE):
		for x in range(BoardState.BOARD_SIZE):
			var p: PieceData = board.grid[y][x] as PieceData
			if p == null:
				continue

			# Only process countdowns for pieces of current_turn_team whose turn just finished
			if p.team != current_turn_team:
				continue

			# Decrement locks
			if p.is_locked:
				p.locked_turns -= 1
				if p.locked_turns <= 0:
					p.is_locked = false

			# Decrement curse (Active 31)
			if p.is_cursed:
				if p.curse_moved:
					# Moved during turn, curse cleansed
					p.is_cursed = false
				else:
					p.curse_turns -= 1
					if p.curse_turns <= 0:
						# Destroy piece to grave
						board.remove_piece(Vector2i(x, y))
						if p.team == PieceData.Team.WHITE:
							board.grave_white.append(p)
						else:
							board.grave_black.append(p)

			# Decrement immortal
			if p.is_immortal:
				p.immortal_turns -= 1
				if p.immortal_turns <= 0:
					p.is_immortal = false

			# Decrement stealth
			if p.is_stealth:
				p.stealth_turns -= 1
				if p.stealth_turns <= 0:
					p.is_stealth = false

			# Decrement shield
			if p.has_shield:
				p.shield_turns -= 1
				if p.shield_turns <= 0:
					p.has_shield = false

			# Reset custom move mode at turn end
			p.custom_move_mode = ""

func _process_board_hazards() -> void:
	# Forbidden cells
	var to_remove_forbidden: Array[Vector2i] = []
	for pos in board.forbidden_cells:
		var turns: int = int(board.forbidden_cells[pos]) - 1
		if turns <= 0:
			to_remove_forbidden.append(pos)
		else:
			board.forbidden_cells[pos] = turns
	for pos in to_remove_forbidden:
		board.forbidden_cells.erase(pos)

	# River barrier
	if board.river_barrier_active:
		board.river_barrier_turns -= 1
		if board.river_barrier_turns <= 0:
			board.river_barrier_active = false

func _execute_active_effect(card: CardResource, target_pos: Vector2i, extra_pos: Vector2i) -> void:
	match card.id:
		"ACTIVE_01": # DOUBLE_MOVE
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team == current_turn_team:
				p.double_move_active = true
		"ACTIVE_02": # TELEPORT_PIECE
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.type != PieceData.PieceType.QUEEN and p.type != PieceData.PieceType.ROOK:
				if board.is_valid_cell(extra_pos) and board.get_piece(extra_pos) == null:
					board.remove_piece(target_pos)
					board.set_piece(extra_pos, p)
		"ACTIVE_03": # SWAP_ALLIES
			var p1: PieceData = board.get_piece(target_pos)
			var p2: PieceData = board.get_piece(extra_pos)
			if p1 != null and p2 != null and p1.team == current_turn_team and p2.team == current_turn_team:
				board.set_piece(target_pos, p2)
				board.set_piece(extra_pos, p1)
		"ACTIVE_04": # KING_SHIELD
			var kpos: Vector2i = board.find_king(current_turn_team)
			var k: PieceData = board.get_piece(kpos)
			if k != null:
				k.has_shield = true
				k.shield_turns = 3
		"ACTIVE_05": # FORBIDDEN_CELLS
			for i in range(5):
				var cell: Vector2i = Vector2i((target_pos.x + i) % BoardState.BOARD_SIZE, target_pos.y)
				board.forbidden_cells[cell] = 2
		"ACTIVE_06": # KNIGHT_LINEAR
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.type == PieceData.PieceType.KNIGHT:
				p.custom_move_mode = "LINEAR"
		"ACTIVE_07": # ROOK_DIAGONAL
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.type == PieceData.PieceType.ROOK:
				p.custom_move_mode = "DIAGONAL"
		"ACTIVE_08": # BISHOP_KNIGHT
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.type == PieceData.PieceType.BISHOP:
				p.custom_move_mode = "KNIGHT_STEP"
		"ACTIVE_09": # FUSION_PAWN
			_fuse_pieces(PieceData.PieceType.PAWN, 3, PieceData.PieceType.SUPER_PAWN)
		"ACTIVE_10": # FUSION_KNIGHT
			_fuse_pieces(PieceData.PieceType.KNIGHT, 2, PieceData.PieceType.SUPER_KNIGHT)
		"ACTIVE_11": # FUSION_ROOK
			_fuse_pieces(PieceData.PieceType.ROOK, 2, PieceData.PieceType.SUPER_ROOK)
		"ACTIVE_12": # FUSION_BISHOP
			_fuse_pieces(PieceData.PieceType.BISHOP, 2, PieceData.PieceType.SUPER_BISHOP)
		"ACTIVE_13": # FUSION_QUEEN
			_fuse_pieces(PieceData.PieceType.QUEEN, 2, PieceData.PieceType.SUPER_QUEEN)
		"ACTIVE_18": # RIVER_BARRIER
			board.river_barrier_active = true
			board.river_barrier_turns = 2
		"ACTIVE_19", "ACTIVE_20", "ACTIVE_21", "ACTIVE_22": # LOCK
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team != current_turn_team:
				p.is_locked = true
				p.locked_turns = 2
		"ACTIVE_24": # MUTE_PASSIVES
			if current_turn_team == PieceData.Team.WHITE:
				passive_manager.black_passives_muted_turns = 2
			else:
				passive_manager.white_passives_muted_turns = 2
		"ACTIVE_26": # IMMORTAL_PIECE
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team == current_turn_team:
				p.is_immortal = true
				p.immortal_turns = 3
		"ACTIVE_27": # SPAWN_SCARECROW
			if board.is_valid_cell(target_pos) and board.get_piece(target_pos) == null:
				var crow: PieceData = PieceData.new(PieceData.PieceType.SCARECROW, current_turn_team)
				board.set_piece(target_pos, crow)
		"ACTIVE_28": # STEALTH_TROOPS
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.type != PieceData.PieceType.QUEEN and p.team == current_turn_team:
				p.is_stealth = true
				p.stealth_turns = 2
		"ACTIVE_31": # DEATH_CURSE
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team != current_turn_team:
				p.is_cursed = true
				p.curse_turns = p.points
				p.curse_moved = false

func _fuse_pieces(source_type: PieceData.PieceType, needed_count: int, result_type: PieceData.PieceType) -> void:
	var matches: Array[Vector2i] = []
	for y in range(BoardState.BOARD_SIZE):
		for x in range(BoardState.BOARD_SIZE):
			var p: PieceData = board.grid[y][x] as PieceData
			if p != null and p.team == current_turn_team and p.type == source_type:
				matches.append(Vector2i(x, y))
				if matches.size() == needed_count:
					break
		if matches.size() == needed_count:
			break

	if matches.size() == needed_count:
		var target_pos: Vector2i = matches[0]
		for i in range(1, needed_count):
			board.remove_piece(matches[i])
		board.set_piece(target_pos, PieceData.new(result_type, current_turn_team))
