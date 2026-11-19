# res://src/core/piece_data.gd
# GDScript / piece_data.gd / Godot 4.7 / Core Engine
class_name PieceData
extends RefCounted

enum PieceType {
	PAWN,
	KNIGHT,
	BISHOP,
	ROOK,
	QUEEN,
	KING,
	SUPER_PAWN,
	SUPER_KNIGHT,
	SUPER_BISHOP,
	SUPER_ROOK,
	SUPER_QUEEN,
	SCARECROW,
	HEAL_POINT
}

enum Team {
	WHITE,
	BLACK
}

var type: PieceType = PieceType.PAWN
var team: Team = Team.WHITE
var points: int = 1
var hp: float = 1.0
var move_count: int = 0
var check_count: int = 0
var position_history: Array[Vector2i] = []

# Status Buffs / Debuffs
var is_locked: bool = false
var locked_turns: int = 0

var is_cursed: bool = false
var curse_turns: int = 0
var curse_moved: bool = false

var is_immortal: bool = false
var immortal_turns: int = 0

var is_stealth: bool = false
var stealth_turns: int = 0

var is_banned: bool = false
var banned_turns: int = 0
var banned_origin_pos: Vector2i = Vector2i(-1, -1)

var has_shield: bool = false
var shield_turns: int = 0

var is_clone: bool = false
var clone_source_type: PieceType = PieceType.PAWN

var double_move_active: bool = false
var custom_move_mode: String = "" # "LINEAR", "DIAGONAL", "KNIGHT_STEP", "ROOK", "KNIGHT", "BISHOP", "QUEEN"
var square_color_swap: bool = false

func _init(p_type: PieceType = PieceType.PAWN, p_team: Team = Team.WHITE) -> void:
	type = p_type
	team = p_team
	points = get_default_points(p_type)
	hp = 1.0
	move_count = 0
	check_count = 0
	position_history = []

func record_position(new_pos: Vector2i) -> void:
	position_history.append(new_pos)

func get_position_two_moves_ago() -> Vector2i:
	if position_history.is_empty():
		return Vector2i(-1, -1)
	if position_history.size() >= 3:
		return position_history[position_history.size() - 3]
	return position_history[0]

static func get_default_points(p_type: PieceType) -> int:
	match p_type:
		PieceType.PAWN:
			return 1
		PieceType.KNIGHT, PieceType.BISHOP:
			return 3
		PieceType.ROOK:
			return 5
		PieceType.QUEEN:
			return 9
		PieceType.KING:
			return 10
		PieceType.SUPER_PAWN:
			return 3
		PieceType.SUPER_KNIGHT, PieceType.SUPER_BISHOP:
			return 7
		PieceType.SUPER_ROOK:
			return 11
		PieceType.SUPER_QUEEN:
			return 20
		PieceType.SCARECROW, PieceType.HEAL_POINT:
			return 0
		_:
			return 1

func can_attack() -> bool:
	if is_locked or is_banned or is_stealth or is_immortal:
		return false
	if type == PieceType.SCARECROW or type == PieceType.HEAL_POINT:
		return false
	return true

func can_be_targeted() -> bool:
	if is_locked or is_stealth or is_banned:
		return false
	return true

func can_be_captured() -> bool:
	if is_locked or is_immortal or is_stealth or is_banned:
		return false
	if type == PieceType.SCARECROW:
		return false # Handled via surround rule
	return true

func clone() -> PieceData:
	var copy: PieceData = PieceData.new(type, team)
	copy.points = points
	copy.hp = hp
	copy.move_count = move_count
	copy.check_count = check_count
	copy.is_locked = is_locked
	copy.locked_turns = locked_turns
	copy.is_cursed = is_cursed
	copy.curse_turns = curse_turns
	copy.curse_moved = curse_moved
	copy.is_immortal = is_immortal
	copy.immortal_turns = immortal_turns
	copy.is_stealth = is_stealth
	copy.stealth_turns = stealth_turns
	copy.is_banned = is_banned
	copy.banned_turns = banned_turns
	copy.banned_origin_pos = banned_origin_pos
	copy.has_shield = has_shield
	copy.shield_turns = shield_turns
	copy.is_clone = is_clone
	copy.clone_source_type = clone_source_type
	copy.double_move_active = double_move_active
	copy.custom_move_mode = custom_move_mode
	copy.square_color_swap = square_color_swap
	copy.position_history = position_history.duplicate()
	return copy

func get_type_name() -> String:
	match type:
		PieceType.PAWN: return "PAWN"
		PieceType.KNIGHT: return "KNIGHT"
		PieceType.BISHOP: return "BISHOP"
		PieceType.ROOK: return "ROOK"
		PieceType.QUEEN: return "QUEEN"
		PieceType.KING: return "KING"
		PieceType.SUPER_PAWN: return "SUPER_PAWN"
		PieceType.SUPER_KNIGHT: return "SUPER_KNIGHT"
		PieceType.SUPER_BISHOP: return "SUPER_BISHOP"
		PieceType.SUPER_ROOK: return "SUPER_ROOK"
		PieceType.SUPER_QUEEN: return "SUPER_QUEEN"
		PieceType.SCARECROW: return "SCARECROW"
		PieceType.HEAL_POINT: return "HEAL_POINT"
		_: return "UNKNOWN"
