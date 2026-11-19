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

	if piece.type == PieceData.PieceType.QUEEN or piece.type == PieceData.PieceType.SUPER_QUEEN:
		passive_manager.evaluate_triggers("queen_moved", {
			"active_team": current_turn_team,
			"moved_piece": piece,
			"from": from_pos,
			"to": to_pos,
			"captured_piece": captured,
			"board": board
		})

	if captured != null:
		passive_manager.evaluate_triggers("piece_captured", {
			"active_team": current_turn_team,
			"moved_piece": piece,
			"from": from_pos,
			"to": to_pos,
			"captured_piece": captured,
			"board": board
		})
	else:
		passive_manager.evaluate_triggers("piece_moved", {
			"active_team": current_turn_team,
			"moved_piece": piece,
			"from": from_pos,
			"to": to_pos,
			"board": board
		})

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
		"ACTIVE_14": # GRAVE_SUMMON
			var grave: Array[PieceData] = board.grave_white if current_turn_team == PieceData.Team.WHITE else board.grave_black
			if not grave.is_empty() and board.is_valid_cell(target_pos) and board.get_piece(target_pos) == null:
				var revived: PieceData = grave.pop_back()
				revived.team = current_turn_team
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
					var adj_p: PieceData = board.remove_piece(adj)
					if adj_p != null:
						if adj_p.team == PieceData.Team.WHITE:
							board.grave_white.append(adj_p)
						else:
							board.grave_black.append(adj_p)
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
			for pos in targets:
				if pos is Vector2i:
					var p: PieceData = board.get_piece(pos)
					if p != null and p.type != PieceData.PieceType.QUEEN and p.team == current_turn_team:
						p.is_stealth = true
						p.stealth_turns = 2
		"ACTIVE_29": # CLONE_WAR
			var src_p: PieceData = board.get_piece(target_pos)
			if src_p != null and src_p.team == current_turn_team:
				for i in range(1, targets.size()):
					var cpos = targets[i]
					if cpos is Vector2i and board.is_valid_cell(cpos) and board.get_piece(cpos) == null:
						var clone_p: PieceData = src_p.clone()
						clone_p.is_clone = true
						clone_p.clone_source_type = src_p.type
						board.set_piece(cpos, clone_p)
		"ACTIVE_30": # GRAVITY_VORTEX
			if board.is_valid_cell(target_pos):
				board.gravity_vortex = {"center": target_pos, "turns": 2}
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

		var corner1: Vector2i = Vector2i(0, 0) if current_turn_team == PieceData.Team.WHITE else Vector2i(0, 7)
		var corner2: Vector2i = Vector2i(7, 0) if current_turn_team == PieceData.Team.WHITE else Vector2i(7, 7)
		var spawn_pos: Vector2i = corner1
		if board.get_piece(spawn_pos) != null:
			spawn_pos = corner2
		if board.get_piece(spawn_pos) != null:
			spawn_pos = board.find_nearest_empty_cell(corner1)

		if spawn_pos != Vector2i(-1, -1):
			board.set_piece(spawn_pos, PieceData.new(spawn_type, current_turn_team))

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
			for i in range(grave.size() - 1, -1, -1):
				if grave[i].points < 5:
					found_idx = i
					break
			if found_idx != -1 and board.is_valid_cell(target_pos) and board.get_piece(target_pos) == null:
				var revived: PieceData = grave[found_idx]
				grave.remove_at(found_idx)
				revived.team = team
				board.set_piece(target_pos, revived)

		"PASSIVE_03": # CLEANSE_DEBUFFS
			for y in range(BoardState.BOARD_SIZE):
				for x in range(BoardState.BOARD_SIZE):
					var p: PieceData = board.grid[y][x] as PieceData
					if p != null and p.team == team:
						p.is_locked = false
						p.is_cursed = false
						p.is_banned = false

		"PASSIVE_04": # COUNTER_ACTIVE
			pass

		"PASSIVE_05": # BARRIER_BURN
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

		"PASSIVE_14": # CASTLE_ESCAPE
			var kpos: Vector2i = board.find_king(team)
			if kpos != Vector2i(-1, -1) and board.is_valid_cell(target_pos) and board.get_piece(target_pos) == null:
				var k: PieceData = board.remove_piece(kpos)
				board.set_piece(target_pos, k)

		"PASSIVE_15", "PASSIVE_16":
			interception_extra_moves = 2
			interception_scope = "KING" if card.id == "PASSIVE_15" else "ALL"

		"PASSIVE_20": # RETALIATION_BAN
			if not board.move_history.is_empty():
				var last_move: Dictionary = board.move_history.back()
				var to_c: Vector2i = last_move.get("to", Vector2i(-1, -1))
				var p: PieceData = board.get_piece(to_c)
				if p != null:
					p.is_banned = true
					p.banned_turns = 2

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
