# res://src/core/card_engine.gd
# GDScript / card_engine.gd / Godot 4.7 / Core Engine
class_name CardEngine
extends RefCounted

const DECK_SIZE: int = 27
const INITIAL_DRAW_COUNT: int = 6
const MAX_HAND_SIZE: int = 10
const DRAW_MOVE_INTERVAL: int = 2

var team: PieceData.Team = PieceData.Team.WHITE
var deck: Array[CardResource] = []
var hand: Array[CardResource] = []
var discard_pile: Array[CardResource] = []

var self_move_count: int = 0
var actives_used_this_turn: int = 0
var passives_placed_this_turn: int = 0

func _init(p_team: PieceData.Team = PieceData.Team.WHITE) -> void:
	team = p_team
	deck.clear()
	hand.clear()
	discard_pile.clear()
	self_move_count = 0
	actives_used_this_turn = 0
	passives_placed_this_turn = 0

func setup_default_deck() -> void:
	deck.clear()
	hand.clear()
	discard_pile.clear()
	self_move_count = 0
	actives_used_this_turn = 0
	passives_placed_this_turn = 0

	var all_ids: Array = CardDatabase.get_all_card_ids()
	# Take first 27 cards deterministically or wrap around
	for i in range(DECK_SIZE):
		var id: String = all_ids[i % all_ids.size()]
		var card: CardResource = CardDatabase.get_card(id)
		if card != null:
			deck.append(card)

func set_custom_deck(cards: Array[CardResource]) -> void:
	deck.clear()
	hand.clear()
	discard_pile.clear()
	for c in cards:
		deck.append(c)

func draw_initial_hand() -> Array[CardResource]:
	var drawn: Array[CardResource] = []
	for i in range(INITIAL_DRAW_COUNT):
		var c: CardResource = draw_card()
		if c != null:
			drawn.append(c)
	return drawn

func draw_card() -> CardResource:
	if deck.is_empty():
		return null
	if hand.size() >= MAX_HAND_SIZE:
		# Hand full limit: skip draw or discard as per GDD
		return null
	var card: CardResource = deck.pop_front()
	hand.append(card)
	return card

func on_move_completed() -> bool:
	self_move_count += 1
	if self_move_count % DRAW_MOVE_INTERVAL == 0:
		var drawn: CardResource = draw_card()
		return drawn != null
	return false

func can_play_active(card: CardResource) -> bool:
	if card == null or not card.is_active():
		return false
	if actives_used_this_turn >= 1:
		return false
	return hand.has(card)

func play_active(card: CardResource) -> bool:
	if not can_play_active(card):
		return false
	hand.erase(card)
	discard_pile.append(card)
	actives_used_this_turn += 1
	return true

func can_place_passive(card: CardResource) -> bool:
	if card == null or not card.is_passive():
		return false
	if passives_placed_this_turn >= 1:
		return false
	return hand.has(card)

func take_passive_from_hand(card: CardResource) -> CardResource:
	if not can_place_passive(card):
		return null
	hand.erase(card)
	passives_placed_this_turn += 1
	return card

func reset_turn_limits() -> void:
	actives_used_this_turn = 0
	passives_placed_this_turn = 0
