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
#   "team": PieceData.Team
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
		"team": team
	}
	if team == PieceData.Team.WHITE:
		white_slots.append(slot_data)
	else:
		black_slots.append(slot_data)
	return true

func is_muted(team: PieceData.Team) -> bool:
	return white_passives_muted_turns > 0 if team == PieceData.Team.WHITE else black_passives_muted_turns > 0

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
		var card: CardResource = slot.get("card", null)
		if card != null:
			if card.id == "PASSIVE_15" or card.id == "PASSIVE_16":
				chosen_index = i
				chosen_slot = slot
				break

	if chosen_index != -1:
		var card: CardResource = chosen_slot["card"]
		slots.remove_at(chosen_index)
		result["intercepted"] = true
		result["card_id"] = card.id
		result["extra_moves_granted"] = 2
		if card.id == "PASSIVE_15":
			result["target_scope"] = "KING"
		else:
			result["target_scope"] = "ALL"

	return result

func remove_passive_at(team: PieceData.Team, index: int) -> CardResource:
	var slots: Array[Dictionary] = get_slots(team)
	if index >= 0 and index < slots.size():
		var slot: Dictionary = slots[index]
		slots.remove_at(index)
		return slot.get("card", null)
	return null

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
