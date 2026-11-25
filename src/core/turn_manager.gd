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

# Sprint A extended state
var double_move_piece_pos: Vector2i = Vector2i(-1, -1)
var forced_king_move_team: int = -1
var passive_12_used: bool = false
var pending_sacrifice_spawns: Array[Dictionary] = []

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
	double_move_piece_pos = Vector2i(-1, -1)
	forced_king_move_team = -1
	passive_12_used = false
	pending_sacrifice_spawns.clear()

	white_engine.draw_initial_hand()
	black_engine.draw_initial_hand()

	start_turn()

func start_turn() -> void:
	current_phase = Phase.DRAW_PHASE
	double_move_piece_pos = Vector2i(-1, -1)
	var current_engine: CardEngine = get_current_engine()
	current_engine.reset_turn_limits()

	# Process any queued sacrifice spawns if corners opened up
	_process_pending_sacrifice_spawns()

	# Check and activate holy war if only 2 kings left
	death_ring_system.check_and_activate_holy_war(board)

	# Transition to Main Phase
	current_phase = Phase.MAIN_PHASE

	# Evaluate start-of-turn passive triggers (PASSIVE_03 Cleanse, PASSIVE_10 10-round revive, PASSIVE_17/18, etc.)
	passive_manager.evaluate_triggers("main_phase_started", {"board": board})

func get_current_engine() -> CardEngine:
	return white_engine if current_turn_team == PieceData.Team.WHITE else black_engine

func get_opponent_engine() -> CardEngine:
	return black_engine if current_turn_team == PieceData.Team.WHITE else white_engine

func get_opponent_team() -> PieceData.Team:
	return PieceData.Team.BLACK if current_turn_team == PieceData.Team.WHITE else PieceData.Team.WHITE

# Phase 2: Main Phase actions
func play_active_card(card: CardResource, target_pos: Vector2i = Vector2i(-1, -1), extra_pos: Vector2i = Vector2i(-1, -1), targets: Array = []) -> bool:
	if current_phase != Phase.MAIN_PHASE:
		return false
	var engine: CardEngine = get_current_engine()
	if not engine.can_play_active(card):
		return false

	var all_targets: Array = targets.duplicate()
	if all_targets.is_empty():
		if target_pos != Vector2i(-1, -1):
			all_targets.append(target_pos)
		if extra_pos != Vector2i(-1, -1):
			all_targets.append(extra_pos)

	# Check opponent passive counter (PASSIVE_04 COUNTER_ACTIVE)
	var opp_team: PieceData.Team = get_opponent_team()
	var opp_slots: Array[Dictionary] = passive_manager.get_slots(opp_team)
	for i in range(opp_slots.size()):
		var slot: Dictionary = opp_slots[i]
		if int(slot.get("turns_on_board", 0)) < 1:
			continue
		var p_card: CardResource = slot.get("card", null) as CardResource
		if p_card != null and p_card.id == "PASSIVE_04" and not passive_manager.is_muted(opp_team):
			passive_manager.remove_passive_at(opp_team, i)
			engine.play_active(card) # Consume card
			passive_manager.evaluate_triggers("active_card_played", {
				"active_team": current_turn_team,
				"active_card": card,
				"board": board,
				"countered": true
			})
			return false # Countered!

	if not engine.play_active(card):
		return false

	_execute_active_effect(card, all_targets)

	passive_manager.evaluate_triggers("active_card_played", {
		"active_team": current_turn_team,
		"active_card": card,
		"board": board,
		"countered": false
	})

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

	var placed: bool = passive_manager.place_passive(current_turn_team, taken, turn_number)
	if placed:
		passive_manager.evaluate_triggers("passive_placed", {"board": board})
	return placed

# Phase 3: Move Phase
func execute_move(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if is_game_over:
		return false
	if current_phase != Phase.MAIN_PHASE and current_phase != Phase.MOVE_PHASE:
		return false

	# ACTIVE_01 (Song Trùng): 2nd move MUST be made by the same piece
	var was_second_double_move: bool = false
	if double_move_piece_pos != Vector2i(-1, -1):
		if from_pos != double_move_piece_pos:
			return false
		was_second_double_move = true

	var piece: PieceData = board.get_piece(from_pos)
	if piece == null or piece.team != current_turn_team:
		return false

	# If in checkmate interception with KING scope, only King can move
	if interception_extra_moves > 0 and interception_scope == "KING" and piece.type != PieceData.PieceType.KING:
		return false

	# PASSIVE_14 (Thoát Hiểm Hoàng Cung): Opponent forced to move King if King has legal moves
	var is_holy_war: bool = death_ring_system.is_holy_war_active
	if forced_king_move_team == int(current_turn_team):
		var kpos: Vector2i = board.find_king(current_turn_team)
		if kpos != Vector2i(-1, -1):
			var king_legal: Array[Vector2i] = MoveValidator.get_legal_moves(board, kpos, is_holy_war)
			if not king_legal.is_empty() and piece.type != PieceData.PieceType.KING:
				return false

	var allow_king_attacks: bool = is_holy_war or (interception_extra_moves > 0 and interception_scope == "KING")
	var legal_moves: Array[Vector2i] = MoveValidator.get_legal_moves(board, from_pos, allow_king_attacks)
	if not legal_moves.has(to_pos):
		return false

	current_phase = Phase.MOVE_PHASE

	if forced_king_move_team == int(current_turn_team):
		forced_king_move_team = -1

	var is_castling: bool = (piece.type == PieceData.PieceType.KING and absi(to_pos.x - from_pos.x) == 2)
	var captured: PieceData = null
	var clone_ban_executed: bool = false

	# ACTIVE_29 (Phân Thân Thuật): Clone landing on enemy piece bans it instead of capturing, then clone vanishes
	var dest_piece: PieceData = board.get_piece(to_pos)
	if piece.is_clone and dest_piece != null and dest_piece.team != piece.team:
		var clone_count: int = 0
		for entry in board.get_all_pieces(piece.team):
			var cp: PieceData = entry["piece"] as PieceData
			if cp != null and cp.is_clone and cp.clone_source_type == piece.clone_source_type:
				clone_count += 1
		var ban_rounds: int = maxi(1, clone_count)
		dest_piece.is_banned = true
		dest_piece.banned_turns = ban_rounds
		dest_piece.just_applied_ban = false
		board.remove_piece(from_pos)
		board.move_history.append({
			"from": from_pos,
			"to": to_pos,
			"piece": piece,
			"captured": null,
			"clone_ban": true
		})
		total_moves_played += 1
		clone_ban_executed = true
	else:
		captured = board.move_piece(from_pos, to_pos)
		total_moves_played += 1

	# Process queued sacrifice spawns if a corner was just vacated
	_process_pending_sacrifice_spawns()

	# PASSIVE_18 (Hỏa Diễm Tam Điểm): stepping onto a fire diagonal cell deals -1 point
	if not clone_ban_executed and board.fire_diagonals.has(to_pos):
		var stepped: PieceData = board.get_piece(to_pos)
		if stepped != null and not stepped.is_immortal and stepped.type != PieceData.PieceType.SCARECROW and stepped.type != PieceData.PieceType.HEAL_POINT:
			stepped.current_points -= 1.0
			stepped.points = maxi(0, int(ceil(stepped.current_points)))
			stepped.affected_by_point_penalty = true
			if stepped.current_points <= 0.001:
				board.remove_piece(to_pos)
				if stepped.team == PieceData.Team.WHITE:
					board.grave_white.append(stepped)
				else:
					board.grave_black.append(stepped)
			passive_manager.evaluate_triggers("point_penalty_applied", {
				"target_team": int(stepped.team),
				"board": board
			})

	var points_eq: bool = is_equal_approx(
		board.get_total_team_points(PieceData.Team.WHITE),
		board.get_total_team_points(PieceData.Team.BLACK)
	)
	var opp_team: PieceData.Team = get_opponent_team()

	if is_castling:
		passive_manager.evaluate_triggers("castling", {
			"active_team": current_turn_team,
			"king_pos": to_pos,
			"board": board
		})

	if piece.type == PieceData.PieceType.QUEEN or piece.type == PieceData.PieceType.SUPER_QUEEN:
		passive_manager.evaluate_triggers("queen_moved", {
			"active_team": current_turn_team,
			"moved_piece": piece,
			"from": from_pos,
			"to": to_pos,
			"captured_piece": captured,
			"total_moves": total_moves_played,
			"points_equal": points_eq,
			"board": board
		})

	if captured != null:
		passive_manager.evaluate_triggers("piece_captured", {
			"active_team": current_turn_team,
			"moved_piece": piece,
			"from": from_pos,
			"to": to_pos,
			"captured_piece": captured,
			"total_moves": total_moves_played,
			"points_equal": points_eq,
			"board": board
		})
	else:
		passive_manager.evaluate_triggers("piece_moved", {
			"active_team": current_turn_team,
			"moved_piece": piece,
			"from": from_pos,
			"to": to_pos,
			"total_moves": total_moves_played,
			"points_equal": points_eq,
			"board": board
		})

	# Check detection -> increment check_count & fire king_checked (PASSIVE_08, PASSIVE_11, PASSIVE_14)
	if MoveValidator.is_in_check(board, opp_team):
		piece.check_count += 1
		passive_manager.evaluate_triggers("king_checked", {
			"checked_team": opp_team,
			"checking_piece": piece,
			"max_check_count": piece.check_count,
			"board": board
		})

	# King slain condition (Holy War or PASSIVE_15 counter-kill)
	if captured != null and captured.type == PieceData.PieceType.KING:
		is_game_over = true
		winner = int(current_turn_team)
		game_over_reason = "KING_SLAIN"
		double_move_piece_pos = Vector2i(-1, -1)
		return true

	# Check card draw trigger: every 2 moves by self
	var engine: CardEngine = get_current_engine()
	engine.on_move_completed()

	# ACTIVE_01 (Song Trùng): If piece had double_move_active, allow 2nd consecutive move without ending turn!
	if not clone_ban_executed and piece.double_move_active and board.get_piece(to_pos) == piece:
		piece.double_move_active = false
		double_move_piece_pos = to_pos
		current_phase = Phase.MOVE_PHASE
		return true

	if was_second_double_move:
		double_move_piece_pos = Vector2i(-1, -1)

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
	double_move_piece_pos = Vector2i(-1, -1)

	# 1. Update countdowns of active piece effects
	_process_piece_status_countdowns()

	# 2. Process board special mechanic turns
	_process_board_hazards()

	# 2b. Process pending sacrifice spawns
	_process_pending_sacrifice_spawns()

	# 3. Process Death Ring burn if active
	if death_ring_system.is_death_ring_active:
		var burn_res: Dictionary = death_ring_system.process_turn_burn(board, current_turn_team)
		for entry in board.get_all_pieces(current_turn_team):
			var ep: PieceData = entry["piece"] as PieceData
			if ep != null:
				ep.affected_by_point_penalty = true
		passive_manager.evaluate_triggers("point_penalty_applied", {
			"target_team": int(current_turn_team),
			"board": board
		})
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

			# Scarecrow surround check (applies even if enemy just moved to surround it)
			if p.type == PieceData.PieceType.SCARECROW:
				var crow_enemy: PieceData.Team = PieceData.Team.BLACK if p.team == PieceData.Team.WHITE else PieceData.Team.WHITE
				if MoveValidator.count_attackers(board, Vector2i(x, y), crow_enemy) >= 3:
					board.remove_piece(Vector2i(x, y))
					continue

			# Only process countdowns for pieces of current_turn_team whose turn just finished
			if p.team != current_turn_team:
				continue

			# Decrement Scarecrow duration (ACTIVE_27)
			if p.type == PieceData.PieceType.SCARECROW and p.scarecrow_turns > 0:
				p.scarecrow_turns -= 1
				if p.scarecrow_turns <= 0:
					board.remove_piece(Vector2i(x, y))
					continue

			# Decrement Temporary Summon duration (ACTIVE_14)
			if p.temporary_summon_turns > 0:
				p.temporary_summon_turns -= 1
				if p.temporary_summon_turns <= 0:
					board.remove_piece(Vector2i(x, y))
					if p.team == PieceData.Team.WHITE:
						board.grave_white.append(p)
					else:
						board.grave_black.append(p)
					continue

			# Decrement Ban (PASSIVE_20 / ACTIVE_29 / ACTIVE_30)
			if p.is_banned:
				if p.just_applied_ban:
					p.just_applied_ban = false
				else:
					p.banned_turns -= 1
					if p.banned_turns <= 0:
						p.is_banned = false
						p.banned_turns = 0

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
						continue

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

	# PASSIVE_05: Barrier Burn Zones (burn 0.5 points/turn for 2 turns)
	if not board.barrier_burn_zones.is_empty():
		var to_remove_burn: Array[Vector2i] = []
		var penalized_teams: Dictionary = {}
		for pos in board.barrier_burn_zones.keys():
			var zone: Dictionary = board.barrier_burn_zones[pos]
			var p: PieceData = board.get_piece(pos)
			if p != null and p.type != PieceData.PieceType.SCARECROW and p.type != PieceData.PieceType.HEAL_POINT:
				p.current_points -= 0.5
				p.points = maxi(0, int(ceil(p.current_points)))
				p.affected_by_point_penalty = true
				penalized_teams[int(p.team)] = true
				if p.current_points <= 0.0:
					board.remove_piece(pos)
					if p.team == PieceData.Team.WHITE:
						board.grave_white.append(p)
					else:
						board.grave_black.append(p)
			var rem_turns: int = int(zone.get("turns", 0)) - 1
			if rem_turns <= 0:
				to_remove_burn.append(pos)
			else:
				zone["turns"] = rem_turns
				board.barrier_burn_zones[pos] = zone
		for pos in to_remove_burn:
			board.barrier_burn_zones.erase(pos)
		for t_int in penalized_teams.keys():
			passive_manager.evaluate_triggers("point_penalty_applied", {
				"target_team": int(t_int),
				"board": board
			})

func _get_sacrifice_spawn_candidates(team: PieceData.Team, spawn_type: PieceData.PieceType) -> Array[Vector2i]:
	var y: int = 0 if team == PieceData.Team.WHITE else 7
	match spawn_type:
		PieceData.PieceType.ROOK:
			return [Vector2i(0, y), Vector2i(7, y)]
		PieceData.PieceType.KNIGHT, PieceData.PieceType.BISHOP:
			return [Vector2i(1, y), Vector2i(6, y), Vector2i(2, y), Vector2i(5, y)]
		PieceData.PieceType.QUEEN:
			return [Vector2i(3, y)]
		_:
			return [Vector2i(0, y), Vector2i(7, y)]

func _process_pending_sacrifice_spawns() -> void:
	if pending_sacrifice_spawns.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for req in pending_sacrifice_spawns:
		var t: PieceData.Team = req["team"] as PieceData.Team
		var stype: PieceData.PieceType = req["type"] as PieceData.PieceType
		var candidates: Array[Vector2i] = _get_sacrifice_spawn_candidates(t, stype)
		var spawn_pos: Vector2i = Vector2i(-1, -1)
		for cand in candidates:
			if board.get_piece(cand) == null and not board.is_cell_forbidden(cand):
				spawn_pos = cand
				break
		if spawn_pos != Vector2i(-1, -1):
			var spawned: PieceData = PieceData.new(stype, t)
			spawned.is_locked = true
			spawned.locked_turns = 1
			board.set_piece(spawn_pos, spawned)
		else:
			remaining.append(req)
	pending_sacrifice_spawns = remaining

func _execute_active_effect(card: CardResource, targets: Array) -> void:
	var target_pos: Vector2i = targets[0] if targets.size() > 0 and targets[0] is Vector2i else Vector2i(-1, -1)
	var extra_pos: Vector2i = targets[1] if targets.size() > 1 and targets[1] is Vector2i else Vector2i(-1, -1)

	match card.id:
		"ACTIVE_01": # DOUBLE_MOVE
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team == current_turn_team:
				p.double_move_active = true
		"ACTIVE_02": # TELEPORT_PIECE
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team == current_turn_team and p.type != PieceData.PieceType.QUEEN and p.type != PieceData.PieceType.SUPER_QUEEN and p.type != PieceData.PieceType.ROOK and p.type != PieceData.PieceType.SUPER_ROOK:
				if board.is_valid_cell(extra_pos) and board.get_piece(extra_pos) == null and not board.is_cell_forbidden(extra_pos):
					var sim_board: BoardState = board.clone()
					var sim_p: PieceData = sim_board.remove_piece(target_pos)
					sim_board.set_piece(extra_pos, sim_p)
					var opp_team: PieceData.Team = get_opponent_team()
					if not MoveValidator.is_in_check(sim_board, opp_team) and not MoveValidator.is_in_check(sim_board, current_turn_team):
						board.remove_piece(target_pos)
						board.set_piece(extra_pos, p)
						p.record_position(extra_pos)
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
			if targets.size() >= 5:
				for pos in targets:
					if pos is Vector2i and board.is_valid_cell(pos):
						board.forbidden_cells[pos] = 2
			else:
				for i in range(5):
					var cell: Vector2i = Vector2i((target_pos.x + i) % BoardState.BOARD_SIZE, target_pos.y)
					board.forbidden_cells[cell] = 2
		"ACTIVE_06": # KNIGHT_LINEAR
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team == current_turn_team and (p.type == PieceData.PieceType.KNIGHT or p.type == PieceData.PieceType.SUPER_KNIGHT):
				p.custom_move_mode = "LINEAR"
		"ACTIVE_07": # ROOK_DIAGONAL
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team == current_turn_team and (p.type == PieceData.PieceType.ROOK or p.type == PieceData.PieceType.SUPER_ROOK):
				p.custom_move_mode = "DIAGONAL"
		"ACTIVE_08": # BISHOP_KNIGHT
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team == current_turn_team and (p.type == PieceData.PieceType.BISHOP or p.type == PieceData.PieceType.SUPER_BISHOP):
				p.custom_move_mode = "KNIGHT_STEP"
		"ACTIVE_09": # FUSION_PAWN
			if targets.size() >= 4 and targets[3] is Vector2i:
				_fuse_pieces_at_dest(PieceData.PieceType.PAWN, 3, PieceData.PieceType.SUPER_PAWN, targets[3] as Vector2i, targets)
			else:
				_fuse_pieces(PieceData.PieceType.PAWN, 3, PieceData.PieceType.SUPER_PAWN)
		"ACTIVE_10": # FUSION_KNIGHT
			if targets.size() >= 3 and targets[2] is Vector2i:
				_fuse_pieces_at_dest(PieceData.PieceType.KNIGHT, 2, PieceData.PieceType.SUPER_KNIGHT, targets[2] as Vector2i, targets)
			else:
				_fuse_pieces(PieceData.PieceType.KNIGHT, 2, PieceData.PieceType.SUPER_KNIGHT)
		"ACTIVE_11": # FUSION_ROOK
			if targets.size() >= 3 and targets[2] is Vector2i:
				_fuse_pieces_at_dest(PieceData.PieceType.ROOK, 2, PieceData.PieceType.SUPER_ROOK, targets[2] as Vector2i, targets)
			else:
				_fuse_pieces(PieceData.PieceType.ROOK, 2, PieceData.PieceType.SUPER_ROOK)
		"ACTIVE_12": # FUSION_BISHOP
			if targets.size() >= 3 and targets[2] is Vector2i:
				_fuse_pieces_at_dest(PieceData.PieceType.BISHOP, 2, PieceData.PieceType.SUPER_BISHOP, targets[2] as Vector2i, targets)
			else:
				_fuse_pieces(PieceData.PieceType.BISHOP, 2, PieceData.PieceType.SUPER_BISHOP)
		"ACTIVE_13": # FUSION_QUEEN
			if targets.size() >= 3 and targets[2] is Vector2i:
				_fuse_pieces_at_dest(PieceData.PieceType.QUEEN, 2, PieceData.PieceType.SUPER_QUEEN, targets[2] as Vector2i, targets)
			else:
				_fuse_pieces(PieceData.PieceType.QUEEN, 2, PieceData.PieceType.SUPER_QUEEN)
		"ACTIVE_14": # GRAVE_SUMMON (duy trì 1 turn duy nhất)
			var grave: Array[PieceData] = board.grave_white if current_turn_team == PieceData.Team.WHITE else board.grave_black
			if not grave.is_empty() and board.is_valid_cell(target_pos) and board.get_piece(target_pos) == null and not board.is_cell_forbidden(target_pos):
				var chosen_idx: int = grave.size() - 1
				if targets.size() >= 2 and typeof(targets[1]) == TYPE_INT:
					var req_idx: int = int(targets[1])
					if req_idx >= 0 and req_idx < grave.size():
						chosen_idx = req_idx
				var revived: PieceData = grave[chosen_idx]
				grave.remove_at(chosen_idx)
				revived.team = current_turn_team
				revived.temporary_summon_turns = 1
				board.set_piece(target_pos, revived)
		"ACTIVE_15": # SACRIFICE_ROOK (8pts)
			_process_sacrifice_summon(targets, 8, PieceData.PieceType.ROOK)
		"ACTIVE_16": # SACRIFICE_MINOR (7pts)
			_process_sacrifice_summon(targets, 7, PieceData.PieceType.KNIGHT)
		"ACTIVE_17": # SACRIFICE_QUEEN (17pts)
			_process_sacrifice_summon(targets, 17, PieceData.PieceType.QUEEN)
		"ACTIVE_18": # RIVER_BARRIER
			board.river_barrier_active = true
			board.river_barrier_turns = 2
		"ACTIVE_19", "ACTIVE_20", "ACTIVE_21", "ACTIVE_22": # LOCK
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team != current_turn_team:
				p.is_locked = true
				p.locked_turns = 2
		"ACTIVE_23": # LOCK_THREE
			for pos in targets:
				if pos is Vector2i:
					var p: PieceData = board.get_piece(pos)
					if p != null and p.team != current_turn_team and p.type != PieceData.PieceType.KING:
						p.is_locked = true
						p.locked_turns = 1
		"ACTIVE_24": # MUTE_PASSIVES
			if current_turn_team == PieceData.Team.WHITE:
				passive_manager.black_passives_muted_turns = 2
			else:
				passive_manager.white_passives_muted_turns = 2
		"ACTIVE_25": # PAWN_EXPLOSION
			var p: PieceData = board.get_piece(target_pos)
			if p != null and (p.type == PieceData.PieceType.PAWN or p.type == PieceData.PieceType.SUPER_PAWN) and p.team == current_turn_team:
				board.remove_piece(target_pos)
				if p.team == PieceData.Team.WHITE:
					board.grave_white.append(p)
				else:
					board.grave_black.append(p)
				var cross_offsets: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
				for off in cross_offsets:
					var adj: Vector2i = target_pos + off
					var adj_peek: PieceData = board.get_piece(adj)
					if adj_peek == null or adj_peek.is_immortal or adj_peek.is_banned:
						continue
					var adj_p: PieceData = board.remove_piece(adj)
					if adj_p != null:
						if adj_p.team == PieceData.Team.WHITE:
							board.grave_white.append(adj_p)
						else:
							board.grave_black.append(adj_p)
						if adj_p.type == PieceData.PieceType.KING and not adj_p.is_clone:
							is_game_over = true
							winner = int(PieceData.Team.BLACK if adj_p.team == PieceData.Team.WHITE else PieceData.Team.WHITE)
							game_over_reason = "KING_SLAIN"
		"ACTIVE_26": # IMMORTAL_PIECE
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team == current_turn_team:
				p.is_immortal = true
				p.immortal_turns = 3
		"ACTIVE_27": # SPAWN_SCARECROW (3 turn hoặc bị >= 3 quân địch vây ăn)
			if board.is_valid_cell(target_pos) and board.get_piece(target_pos) == null and not board.is_cell_forbidden(target_pos):
				var crow: PieceData = PieceData.new(PieceData.PieceType.SCARECROW, current_turn_team)
				crow.scarecrow_turns = 3
				board.set_piece(target_pos, crow)
		"ACTIVE_28": # STEALTH_TROOPS (kéo dài 3 turn)
			for pos in targets:
				if pos is Vector2i:
					var p: PieceData = board.get_piece(pos)
					if p != null and p.type != PieceData.PieceType.QUEEN and p.type != PieceData.PieceType.SUPER_QUEEN and p.team == current_turn_team:
						p.is_stealth = true
						p.stealth_turns = 3
		"ACTIVE_29": # CLONE_WAR (trừ Hậu và Xe)
			var src_p: PieceData = board.get_piece(target_pos)
			if src_p != null and src_p.team == current_turn_team and src_p.type != PieceData.PieceType.QUEEN and src_p.type != PieceData.PieceType.SUPER_QUEEN and src_p.type != PieceData.PieceType.ROOK and src_p.type != PieceData.PieceType.SUPER_ROOK:
				for i in range(1, targets.size()):
					var cpos = targets[i]
					if cpos is Vector2i and board.is_valid_cell(cpos) and board.get_piece(cpos) == null and not board.is_cell_forbidden(cpos):
						var clone_p: PieceData = src_p.clone()
						clone_p.is_clone = true
						clone_p.clone_source_type = src_p.type
						board.set_piece(cpos, clone_p)
		"ACTIVE_30": # GRAVITY_VORTEX (hàng 4/5, hút bán kính 2 ô vào 1 ô, vào tâm Ban 3 turn)
			if board.is_valid_cell(target_pos) and (target_pos.y == 3 or target_pos.y == 4):
				board.gravity_vortex = {"center": target_pos, "turns": 2}
				var affected: Array[Dictionary] = []
				for y in range(BoardState.BOARD_SIZE):
					for x in range(BoardState.BOARD_SIZE):
						var pos: Vector2i = Vector2i(x, y)
						if pos == target_pos:
							continue
						var p: PieceData = board.get_piece(pos)
						if p == null:
							continue
						var dist: int = maxi(absi(pos.x - target_pos.x), absi(pos.y - target_pos.y))
						if dist <= 2:
							affected.append({"pos": pos, "piece": p, "dist": dist})
				affected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["dist"]) < int(b["dist"]))
				for item in affected:
					var pos: Vector2i = item["pos"] as Vector2i
					var p: PieceData = item["piece"] as PieceData
					var step: Vector2i = Vector2i(signi(target_pos.x - pos.x), signi(target_pos.y - pos.y))
					var new_pos: Vector2i = pos + step
					if new_pos == target_pos:
						if board.get_piece(target_pos) == null:
							board.remove_piece(pos)
							board.set_piece(target_pos, p)
						else:
							var near: Vector2i = board.find_nearest_empty_cell(target_pos)
							if near != Vector2i(-1, -1):
								board.remove_piece(pos)
								board.set_piece(near, p)
						p.is_banned = true
						p.banned_turns = 3
						p.just_applied_ban = (p.team == current_turn_team)
					elif board.is_valid_cell(new_pos) and board.get_piece(new_pos) == null:
						board.remove_piece(pos)
						board.set_piece(new_pos, p)
		"ACTIVE_31": # DEATH_CURSE
			var p: PieceData = board.get_piece(target_pos)
			if p != null and p.team != current_turn_team:
				p.is_cursed = true
				p.curse_turns = p.points
				p.curse_moved = false

func _process_sacrifice_summon(targets: Array, required_points: int, spawn_type: PieceData.PieceType) -> void:
	var total_pts: int = 0
	var sacrificed: Array[Vector2i] = []
	for pos in targets:
		if pos is Vector2i:
			var p: PieceData = board.get_piece(pos)
			if p != null and p.team == current_turn_team and p.type != PieceData.PieceType.KING:
				total_pts += p.points
				sacrificed.append(pos)
				if total_pts >= required_points:
					break

	if total_pts >= required_points:
		for spos in sacrificed:
			var p: PieceData = board.remove_piece(spos)
			if p != null:
				if current_turn_team == PieceData.Team.WHITE:
					board.grave_white.append(p)
				else:
					board.grave_black.append(p)

		var candidates: Array[Vector2i] = _get_sacrifice_spawn_candidates(current_turn_team, spawn_type)
		var spawn_pos: Vector2i = Vector2i(-1, -1)
		for cand in candidates:
			if board.get_piece(cand) == null and not board.is_cell_forbidden(cand):
				spawn_pos = cand
				break

		if spawn_pos != Vector2i(-1, -1):
			var spawned: PieceData = PieceData.new(spawn_type, current_turn_team)
			spawned.is_locked = true
			spawned.locked_turns = 1
			board.set_piece(spawn_pos, spawned)
		else:
			pending_sacrifice_spawns.append({"team": current_turn_team, "type": spawn_type})

func _fuse_pieces_at_dest(source_type: PieceData.PieceType, needed_count: int, result_type: PieceData.PieceType, dest_pos: Vector2i, targets: Array) -> void:
	var consumed: int = 0
	for i in range(mini(needed_count, targets.size())):
		var pos = targets[i]
		if pos is Vector2i:
			var p: PieceData = board.get_piece(pos)
			if p != null and p.team == current_turn_team and p.type == source_type:
				board.remove_piece(pos)
				consumed += 1

	if consumed == needed_count and board.is_valid_cell(dest_pos) and board.get_piece(dest_pos) == null:
		board.set_piece(dest_pos, PieceData.new(result_type, current_turn_team))
	elif consumed == needed_count:
		var fallback_pos: Vector2i = board.find_nearest_empty_cell(dest_pos)
		if fallback_pos != Vector2i(-1, -1):
			board.set_piece(fallback_pos, PieceData.new(result_type, current_turn_team))

func execute_passive_trigger(team: PieceData.Team, slot_index: int, targets: Array = []) -> Dictionary:
	var card: CardResource = passive_manager.trigger_slot(team, slot_index)
	if card == null:
		return {"success": false, "reason": "NO_CARD"}

	var target_pos: Vector2i = targets[0] if targets.size() > 0 and targets[0] is Vector2i else Vector2i(-1, -1)
	var opp_team: PieceData.Team = PieceData.Team.BLACK if team == PieceData.Team.WHITE else PieceData.Team.WHITE

	match card.id:
		"PASSIVE_01": # BOUNTY_10PTS: destroy enemy piece < 3pts
			if board.is_valid_cell(target_pos):
				var p: PieceData = board.get_piece(target_pos)
				if p != null and p.team == opp_team and p.points < 3:
					board.remove_piece(target_pos)
					if opp_team == PieceData.Team.WHITE:
						board.grave_white.append(p)
					else:
						board.grave_black.append(p)

		"PASSIVE_02": # RESURRECT_50PCT: revive piece < 5pts at target empty cell
			var grave: Array[PieceData] = board.grave_white if team == PieceData.Team.WHITE else board.grave_black
			var found_idx: int = -1
			if targets.size() >= 2 and typeof(targets[1]) == TYPE_INT:
				var req_idx: int = int(targets[1])
				if req_idx >= 0 and req_idx < grave.size() and grave[req_idx].points < 5:
					found_idx = req_idx
			if found_idx == -1:
				for i in range(grave.size() - 1, -1, -1):
					if grave[i].points < 5:
						found_idx = i
						break
			if found_idx != -1 and board.is_valid_cell(target_pos) and board.get_piece(target_pos) == null:
				var revived: PieceData = grave[found_idx]
				grave.remove_at(found_idx)
				revived.team = team
				board.set_piece(target_pos, revived)

		"PASSIVE_03": # CLEANSE_DEBUFFS: hủy mọi hiệu ứng bất lợi đang có trên sân
			for y in range(BoardState.BOARD_SIZE):
				for x in range(BoardState.BOARD_SIZE):
					var p: PieceData = board.grid[y][x] as PieceData
					if p != null and p.team == team:
						p.is_locked = false
						p.locked_turns = 0
						p.is_cursed = false
						p.curse_turns = 0
						p.is_banned = false
						p.banned_turns = 0
						p.affected_by_point_penalty = false
			board.forbidden_cells.clear()
			board.barrier_burn_zones.clear()
			board.fire_diagonals.clear()
			board.river_barrier_active = false
			board.river_barrier_turns = 0

		"PASSIVE_04": # COUNTER_ACTIVE
			pass

		"PASSIVE_05": # BARRIER_BURN
			if target_pos == Vector2i(-1, -1) and not board.move_history.is_empty():
				target_pos = board.move_history.back().get("to", Vector2i(-1, -1))
			if board.is_valid_cell(target_pos):
				var offsets: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, -1)]
				for off in offsets:
					var c: Vector2i = target_pos + off
					if board.is_valid_cell(c):
						board.barrier_burn_zones[c] = {"turns": 2, "origin_team": team}

		"PASSIVE_06": # QUEEN_TETHER
			board.execute_queen_tether()

		"PASSIVE_07": # STEAL_PAWNS
			var opp_pawns: Array[Vector2i] = []
			for y in range(BoardState.BOARD_SIZE):
				for x in range(BoardState.BOARD_SIZE):
					var p: PieceData = board.grid[y][x] as PieceData
					if p != null and p.team == opp_team and (p.type == PieceData.PieceType.PAWN or p.type == PieceData.PieceType.SUPER_PAWN):
						opp_pawns.append(Vector2i(x, y))
			var steal_count: int = int(floor(float(opp_pawns.size()) * 0.3))
			for i in range(mini(steal_count, opp_pawns.size())):
				var pos: Vector2i = opp_pawns[i]
				var p: PieceData = board.get_piece(pos)
				if p != null:
					p.team = team

		"PASSIVE_08": # REWIND_CHECK
			if not board.move_history.is_empty():
				var last_move: Dictionary = board.move_history.back()
				var from_c: Vector2i = last_move.get("from", Vector2i(-1, -1))
				var to_c: Vector2i = last_move.get("to", Vector2i(-1, -1))
				var p: PieceData = board.get_piece(to_c)
				if p != null and board.is_valid_cell(from_c) and board.get_piece(from_c) == null:
					board.remove_piece(to_c)
					board.set_piece(from_c, p)

		"PASSIVE_09": # TRAP_DISARM
			var opp_slots: Array[Dictionary] = passive_manager.get_slots(opp_team)
			opp_slots.clear()

		"PASSIVE_10": # DELAYED_REVIVE
			var grave: Array[PieceData] = board.grave_white if team == PieceData.Team.WHITE else board.grave_black
			var pts_left: int = 4
			var custom_indices: Array[int] = []
			for t in targets:
				if typeof(t) == TYPE_INT:
					var gi: int = int(t)
					if gi >= 0 and gi < grave.size() and not custom_indices.has(gi):
						custom_indices.append(gi)
			if not custom_indices.is_empty():
				custom_indices.sort()
				custom_indices.reverse()
				for gi in custom_indices:
					if grave[gi].points <= pts_left:
						pts_left -= grave[gi].points
						var p: PieceData = grave[gi]
						grave.remove_at(gi)
						var spawn_pos: Vector2i = board.find_nearest_empty_cell(Vector2i(3, 0) if team == PieceData.Team.WHITE else Vector2i(3, 7))
						if spawn_pos != Vector2i(-1, -1):
							p.team = team
							board.set_piece(spawn_pos, p)
			else:
				for i in range(grave.size() - 1, -1, -1):
					if pts_left <= 0:
						break
					if grave[i].points <= pts_left:
						pts_left -= grave[i].points
						var p: PieceData = grave[i]
						grave.remove_at(i)
						var spawn_pos: Vector2i = board.find_nearest_empty_cell(Vector2i(3, 0) if team == PieceData.Team.WHITE else Vector2i(3, 7))
						if spawn_pos != Vector2i(-1, -1):
							p.team = team
							board.set_piece(spawn_pos, p)

		"PASSIVE_11": # CHECK_VETERAN: quân chiếu đủ 10 lần -> bất tử 3 turn
			for entry in board.get_all_pieces(team):
				var p11: PieceData = entry["piece"] as PieceData
				if p11 != null and p11.check_count >= 10:
					p11.is_immortal = true
					p11.immortal_turns = 3
					break

		"PASSIVE_12": # RESTART_50MOVES: chơi lại ván cờ (1 lần/trận)
			var pts_eq: bool = is_equal_approx(
				board.get_total_team_points(PieceData.Team.WHITE),
				board.get_total_team_points(PieceData.Team.BLACK)
			)
			if not passive_12_used and total_moves_played >= 50 and pts_eq:
				passive_12_used = true
				board.setup_initial_board()

		"PASSIVE_13": # CASTLING_SHIFT: dịch Vua (và Xe đi kèm) lùi về giữa bàn cờ 1 ô nếu trống
			var kpos13: Vector2i = board.find_king(team)
			if kpos13 != Vector2i(-1, -1):
				var y13: int = kpos13.y
				if kpos13.x == 6:
					var rook13: PieceData = board.get_piece(Vector2i(5, y13))
					if rook13 != null and rook13.type == PieceData.PieceType.ROOK and rook13.team == team and board.get_piece(Vector2i(4, y13)) == null:
						board.set_piece(Vector2i(4, y13), rook13)
						board.set_piece(Vector2i(5, y13), null)
						var king13: PieceData = board.remove_piece(kpos13)
						board.set_piece(Vector2i(5, y13), king13)
					elif board.get_piece(Vector2i(5, y13)) == null:
						var king13_only: PieceData = board.remove_piece(kpos13)
						board.set_piece(Vector2i(5, y13), king13_only)
				elif kpos13.x == 2:
					var rook13q: PieceData = board.get_piece(Vector2i(3, y13))
					if rook13q != null and rook13q.type == PieceData.PieceType.ROOK and rook13q.team == team and board.get_piece(Vector2i(4, y13)) == null:
						board.set_piece(Vector2i(4, y13), rook13q)
						board.set_piece(Vector2i(3, y13), null)
						var king13q: PieceData = board.remove_piece(kpos13)
						board.set_piece(Vector2i(3, y13), king13q)
					elif board.get_piece(Vector2i(3, y13)) == null:
						var king13q_only: PieceData = board.remove_piece(kpos13)
						board.set_piece(Vector2i(3, y13), king13q_only)

		"PASSIVE_14": # CASTLE_ESCAPE: tẩu thoát Vua & ép đối phương đi Vua lượt tới
			var kpos: Vector2i = board.find_king(team)
			if kpos != Vector2i(-1, -1) and board.is_valid_cell(target_pos) and board.get_piece(target_pos) == null:
				var k: PieceData = board.remove_piece(kpos)
				board.set_piece(target_pos, k)
				k.record_position(target_pos)
			forced_king_move_team = int(opp_team)

		"PASSIVE_15", "PASSIVE_16":
			interception_extra_moves = 2
			interception_scope = "KING" if card.id == "PASSIVE_15" else "ALL"

		"PASSIVE_17": # CHAIN_BREAKER: tiêu hủy 1 trong 3 Tốt chéo đối thủ
			var opp_diag: Array[Vector2i] = board.has_three_diagonal_pawns(opp_team)
			if not opp_diag.is_empty():
				var kill_pos: Vector2i = target_pos if opp_diag.has(target_pos) else opp_diag[0]
				var killed: PieceData = board.remove_piece(kill_pos)
				if killed != null:
					if opp_team == PieceData.Team.WHITE:
						board.grave_white.append(killed)
					else:
						board.grave_black.append(killed)

		"PASSIVE_18": # FIRE_DIAGONAL: tạo đường chéo lửa trừ 1đ (đốt ngay quân địch đang đứng trên đường chéo + quân bước vào)
			var ally_diag: Array[Vector2i] = board.has_three_diagonal_pawns(team)
			if not ally_diag.is_empty():
				var new_fire_cells: Array[Vector2i] = []
				var dir: Vector2i = ally_diag[1] - ally_diag[0]
				var cur: Vector2i = ally_diag[0]
				while board.is_valid_cell(cur):
					if not board.fire_diagonals.has(cur):
						board.fire_diagonals.append(cur)
					new_fire_cells.append(cur)
					cur += dir
				cur = ally_diag[0] - dir
				while board.is_valid_cell(cur):
					if not board.fire_diagonals.has(cur):
						board.fire_diagonals.append(cur)
					new_fire_cells.append(cur)
					cur -= dir
				# Đốt ngay -1đ cho quân địch đang đứng sẵn trên dải lửa (Tốt 1đ chết ngay)
				var burned_enemy: bool = false
				for fpos in new_fire_cells:
					var fp: PieceData = board.get_piece(fpos)
					if fp != null and fp.team == opp_team and not fp.is_immortal and fp.type != PieceData.PieceType.SCARECROW and fp.type != PieceData.PieceType.HEAL_POINT:
						fp.current_points -= 1.0
						fp.points = maxi(0, int(ceil(fp.current_points)))
						fp.affected_by_point_penalty = true
						burned_enemy = true
						if fp.current_points <= 0.001:
							board.remove_piece(fpos)
							if fp.team == PieceData.Team.WHITE:
								board.grave_white.append(fp)
							else:
								board.grave_black.append(fp)
				if burned_enemy:
					passive_manager.evaluate_triggers("point_penalty_applied", {
						"target_team": int(opp_team),
						"board": board
					})

		"PASSIVE_19": # POINT_REACTIVE_BUFF: buff +2đ cho toàn bộ quân đồng minh đang dính hiệu ứng trừ điểm
			for entry in board.get_all_pieces(team):
				var p19: PieceData = entry["piece"] as PieceData
				if p19 != null and (p19.affected_by_point_penalty or death_ring_system.is_death_ring_active):
					p19.current_points += 2.0
					p19.points = maxi(0, int(ceil(p19.current_points)))
					p19.affected_by_point_penalty = false

		"PASSIVE_20": # RETALIATION_BAN
			if not board.move_history.is_empty():
				var last_move: Dictionary = board.move_history.back()
				var to_c: Vector2i = last_move.get("to", Vector2i(-1, -1))
				var p: PieceData = board.get_piece(to_c)
				if p != null:
					p.is_banned = true
					p.banned_turns = 2
					p.just_applied_ban = (p.team == current_turn_team)

	return {"success": true, "card": card}

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
