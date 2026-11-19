# res://src/scenes/card_hand_view.gd
# GDScript / card_hand_view.gd / Godot 4.7 / UI View
class_name CardHandView
extends Control

var turn_manager: TurnManager
var displayed_team: PieceData.Team = PieceData.Team.WHITE

func _ready() -> void:
	custom_minimum_size = Vector2(800.0, 160.0)

func setup(p_turn_manager: TurnManager, p_team: PieceData.Team) -> void:
	turn_manager = p_turn_manager
	displayed_team = p_team
	queue_redraw()

func _draw() -> void:
	if turn_manager == null:
		return

	var engine: CardEngine = turn_manager.white_engine if displayed_team == PieceData.Team.WHITE else turn_manager.black_engine
	var cards: Array[CardResource] = engine.hand
	var card_w: float = 70.0
	var card_h: float = 100.0
	var spacing: float = 8.0

	for i in range(cards.size()):
		var card: CardResource = cards[i]
		var pos: Vector2 = Vector2(i * (card_w + spacing) + 10.0, 10.0)
		var rect: Rect2 = Rect2(pos, Vector2(card_w, card_h))

		var bg_color: Color = Color(0.2, 0.4, 0.7) if card.is_active() else Color(0.6, 0.3, 0.2)
		draw_rect(rect, bg_color)
		draw_rect(rect, Color(0.9, 0.9, 0.9), false, 1.5)

		if card.icon_path != "" and ResourceLoader.exists(card.icon_path):
			var icon_tex: Texture2D = load(card.icon_path) as Texture2D
			if icon_tex != null:
				draw_texture_rect(icon_tex, Rect2(pos + Vector2(10, 10), Vector2(card_w - 20, 40)), false)

		var font: Font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, pos + Vector2(5, 20), card.id, HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 10), 10, Color.WHITE)
			draw_string(font, pos + Vector2(5, 50), card.title.substr(0, 8), HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 10), 10, Color.WHITE)
