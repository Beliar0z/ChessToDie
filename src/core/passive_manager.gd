# res://src/core/passive_manager.gd
# GDScript / passive_manager.gd / Godot 4.7 / Core Engine
class_name PassiveManager
extends RefCounted

const MAX_PASSIVE_SLOTS: int = 4

# Structure for a placed passive card:
# {
#   "card": CardResource,
#   "placed_turn": int,
#   "turns_on_board": int,
#   "team": PieceData.Team,
#   "is_ready_to_trigger": bool,
#   "trigger_window_active": bool
# }
var white_slots: Array[Dictionary] = []
var black_slots: Array[Dictionary] = []

var white_passives_muted_turns: int = 0
var black_passives_muted_turns: int = 0

func _init() -> void:
	clear()

func clear() -> void:
	white_slots.clear()
	black_slots.clear()
	white_passives_muted_turns = 0
	black_passives_muted_turns = 0

func get_slots(team: PieceData.Team) -> Array[Dictionary]:
	return white_slots if team == PieceData.Team.WHITE else black_slots

func get_slot(team: PieceData.Team, index: int) -> Dictionary:
	var slots: Array[Dictionary] = get_slots(team)
	if index >= 0 and index < slots.size():
		return slots[index]
	return {}

func can_place_passive(team: PieceData.Team) -> bool:
	var slots: Array[Dictionary] = get_slots(team)
	return slots.size() < MAX_PASSIVE_SLOTS

func place_passive(team: PieceData.Team, card: CardResource, current_turn_number: int) -> bool:
	if not can_place_passive(team):
		return false
	var slot_data: Dictionary = {
		"card": card,
		"placed_turn": current_turn_number,
		"turns_on_board": 0,
		"team": team,
		"is_ready_to_trigger": false,
		"trigger_window_active": false
	}
	if team == PieceData.Team.WHITE:
		white_slots.append(slot_data)
	else:
		black_slots.append(slot_data)
	return true

func is_muted(team: PieceData.Team) -> bool:
	return white_passives_muted_turns > 0 if team == PieceData.Team.WHITE else black_passives_muted_turns > 0

func has_ready_trigger(team: PieceData.Team) -> bool:
	var slots: Array[Dictionary] = get_slots(team)
	for slot in slots:
		if slot.get("is_ready_to_trigger", false):
			return true
	return false

func trigger_slot(team: PieceData.Team, slot_index: int) -> CardResource:
	var slots: Array[Dictionary] = get_slots(team)
	if slot_index >= 0 and slot_index < slots.size():
		var slot: Dictionary = slots[slot_index]
		slots.remove_at(slot_index)
		return slot.get("card", null) as CardResource
	return null

func remove_passive_at(team: PieceData.Team, index: int) -> CardResource:
	return trigger_slot(team, index)

func clear_expired_triggers() -> void:
	for slot in white_slots:
		if slot.get("trigger_window_active", false):
			slot["is_ready_to_trigger"] = false
			slot["trigger_window_active"] = false
	for slot in black_slots:
		if slot.get("trigger_window_active", false):
			slot["is_ready_to_trigger"] = false
			slot["trigger_window_active"] = false

func evaluate_triggers(event_name: String, context: Dictionary) -> Array[Dictionary]:
	var triggered_slots: Array[Dictionary] = []
	var teams: Array[PieceData.Team] = [PieceData.Team.WHITE, PieceData.Team.BLACK]

	for team in teams:
		if is_muted(team):
			continue

		var slots: Array[Dictionary] = get_slots(team)
		var opp_team: PieceData.Team = PieceData.Team.BLACK if team == PieceData.Team.WHITE else PieceData.Team.WHITE

		for i in range(slots.size()):
			var slot: Dictionary = slots[i]
			if int(slot.get("turns_on_board", 0)) < 1:
				continue
			var card: CardResource = slot.get("card", null) as CardResource
			if card == null:
				continue

			var ready: bool = false
			var is_windowed: bool = false

			match card.id:
				"PASSIVE_01": # BOUNTY_10PTS: ăn đủ >= 10đ quân địch
					var pts: int = context.get("points_captured", -1)
					if pts < 0 and context.has("board"):
						var b: BoardState = context["board"] as BoardState
						pts = b.white_points_captured if team == PieceData.Team.WHITE else b.black_points_captured
					if pts >= 10:
						ready = true

				"PASSIVE_02": # RESURRECT_50PCT: mất > 50% tổng số quân
					var lost_pct: float = float(context.get("lost_pieces_pct", -1.0))
					if lost_pct < 0.0 and context.has("board"):
						var b: BoardState = context["board"] as BoardState
						var remaining: int = b.get_team_piece_count(team)
						if remaining < 8:
							ready = true
					elif lost_pct > 0.5:
						ready = true

				"PASSIVE_03": # CLEANSE_DEBUFFS: hủy mọi debuff
					if event_name == "main_phase_started" or event_name == "debuff_applied":
						ready = true

				"PASSIVE_04": # COUNTER_ACTIVE: hủy 1 lá Active vừa tung ra
					var active_team: int = int(context.get("active_team", -1))
					if event_name == "active_card_played" and active_team == int(opp_team):
						ready = true
						is_windowed = true

				"PASSIVE_05": # BARRIER_BURN: kết giới quanh quân địch vừa đi
					var active_team: int = int(context.get("active_team", -1))
					if (event_name == "piece_moved" or event_name == "move_executed") and active_team == int(opp_team):
						ready = true
						is_windowed = true

				"PASSIVE_06": # QUEEN_TETHER: Hậu đối thủ di chuyển
					var active_team: int = int(context.get("active_team", -1))
					var moved_p: PieceData = context.get("moved_piece", null) as PieceData
					if event_name == "queen_moved" and active_team == int(opp_team):
						ready = true
						is_windowed = true
					elif (event_name == "piece_moved" or event_name == "move_executed") and active_team == int(opp_team):
						if moved_p != null and (moved_p.type == PieceData.PieceType.QUEEN or moved_p.type == PieceData.PieceType.SUPER_QUEEN):
							ready = true
							is_windowed = true

				"PASSIVE_07": # STEAL_PAWNS: toàn bộ Tốt đồng minh bị diệt
					if context.has("board"):
						var b: BoardState = context["board"] as BoardState
						var pawns: int = 0
						for piece_dict in b.get_all_pieces(team):
							var p: PieceData = piece_dict["piece"] as PieceData
							if p != null and (p.type == PieceData.PieceType.PAWN or p.type == PieceData.PieceType.SUPER_PAWN):
								pawns += 1
						if pawns == 0:
							ready = true

				"PASSIVE_08": # REWIND_CHECK: Vua bị chiếu
					if (event_name == "check" or event_name == "king_checked") and int(context.get("checked_team", -1)) == int(team):
						ready = true
						is_windowed = true

				"PASSIVE_09": # TRAP_DISARM: tiêu hủy trap đối thủ
					var opp_slots: Array[Dictionary] = get_slots(opp_team)
					if not opp_slots.is_empty():
						ready = true

				"PASSIVE_10": # DELAYED_REVIVE: úp đủ 10 vòng
					var turns_on: int = int(slot.get("turns_on_board", 0))
					if turns_on >= 10:
						ready = true

				"PASSIVE_11": # CHECK_VETERAN: quân chiếu 10 lần
					var checking_p: PieceData = context.get("checking_piece", null) as PieceData
					if checking_p != null and checking_p.team == team and checking_p.check_count >= 10:
						ready = true
					elif int(context.get("max_check_count", 0)) >= 10 and (checking_p == null or checking_p.team == team):
						ready = true
					elif context.has("board"):
						var b11: BoardState = context["board"] as BoardState
						for entry in b11.get_all_pieces(team):
							var ep: PieceData = entry["piece"] as PieceData
							if ep != null and ep.check_count >= 10:
								ready = true
								break

				"PASSIVE_12": # RESTART_50MOVES: 50 nước điểm bằng nhau
					if int(context.get("total_moves", 0)) >= 50 and bool(context.get("points_equal", false)):
						ready = true

				"PASSIVE_13": # CASTLING_SHIFT: khi nhập thành
					if event_name == "castling" and int(context.get("active_team", -1)) == int(team):
						ready = true
						is_windowed = true

				"PASSIVE_14": # CASTLE_ESCAPE: Vua nhập thành bị chiếu
					if (event_name == "check" or event_name == "king_checked") and int(context.get("checked_team", -1)) == int(team):
						ready = true
						is_windowed = true

				"PASSIVE_15", "PASSIVE_16": # CHECKMATE HOOK
					if (event_name == "checkmate" or bool(context.get("is_checkmate", false))) and int(context.get("checkmated_team", -1)) == int(team):
						ready = true

				"PASSIVE_17": # CHAIN_BREAKER: đối phương có 3 Tốt chéo
					if bool(context.get("opp_has_diagonal_pawns", false)):
						ready = true
					elif context.has("board"):
						var b17: BoardState = context["board"] as BoardState
						if not b17.has_three_diagonal_pawns(opp_team).is_empty():
							ready = true

				"PASSIVE_18": # FIRE_DIAGONAL: bản thân có 3 Tốt chéo
					if bool(context.get("ally_has_diagonal_pawns", false)):
						ready = true
					elif context.has("board"):
						var b18: BoardState = context["board"] as BoardState
						if not b18.has_three_diagonal_pawns(team).is_empty():
							ready = true

				"PASSIVE_19": # POINT_REACTIVE_BUFF: dính trừ điểm
					if event_name == "point_penalty_applied" and int(context.get("target_team", -1)) == int(team):
						ready = true

				"PASSIVE_20": # RETALIATION_BAN: quân địch vừa ăn quân đồng minh
					var cap: PieceData = context.get("captured_piece", null) as PieceData
					if (event_name == "piece_captured" or event_name == "move_executed") and cap != null and cap.team == team:
						ready = true
						is_windowed = true

			if ready:
				slot["is_ready_to_trigger"] = true
				if is_windowed:
					slot["trigger_window_active"] = true
				triggered_slots.append({
					"team": team,
					"slot_index": i,
					"card": card,
					"slot": slot
				})

	return triggered_slots

func trigger_checkmate_hook(team: PieceData.Team) -> Dictionary:
	var result: Dictionary = {
		"intercepted": false,
		"card_id": "",
		"extra_moves_granted": 0,
		"target_scope": "" # "KING" or "ALL"
	}

	if is_muted(team):
		return result

	var slots: Array[Dictionary] = get_slots(team)
	var chosen_index: int = -1
	var chosen_slot: Dictionary = {}

	# Rule: If both PASSIVE_15 and PASSIVE_16 are placed, ONLY trigger ONE (priority to earlier placed)
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		var card: CardResource = slot.get("card", null) as CardResource
		if card != null:
			if card.id == "PASSIVE_15" or card.id == "PASSIVE_16":
				chosen_index = i
				chosen_slot = slot
				break

	if chosen_index != -1:
		var card: CardResource = chosen_slot["card"] as CardResource
		slots.remove_at(chosen_index)
		result["intercepted"] = true
		result["card_id"] = card.id
		result["extra_moves_granted"] = 2
		if card.id == "PASSIVE_15":
			result["target_scope"] = "KING"
		else:
			result["target_scope"] = "ALL"

	return result

func on_turn_end(team: PieceData.Team) -> void:
	# Decrement mute counters
	if team == PieceData.Team.WHITE:
		if white_passives_muted_turns > 0:
			white_passives_muted_turns -= 1
	else:
		if black_passives_muted_turns > 0:
			black_passives_muted_turns -= 1

	# Increment turn counter for placed passives
	var slots: Array[Dictionary] = get_slots(team)
	for s in slots:
		s["turns_on_board"] = int(s.get("turns_on_board", 0)) + 1
