# res://src/resources/card_resource.gd
# GDScript / card_resource.gd / Godot 4.7 / Resource
class_name CardResource
extends Resource

enum CardType {
	ACTIVE,
	PASSIVE
}

@export var id: String = ""
@export var title: String = ""
@export var card_type: CardType = CardType.ACTIVE
@export var cost: int = 0
@export var description: String = ""
@export var icon_path: String = ""
@export var target_type: String = "NONE" # "NONE", "PIECE", "ALLY_PIECE", "ENEMY_PIECE", "CELL", "GRAVE"
@export var tag: String = ""

func is_active() -> bool:
	return card_type == CardType.ACTIVE

func is_passive() -> bool:
	return card_type == CardType.PASSIVE
