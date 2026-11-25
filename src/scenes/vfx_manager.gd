# res://src/scenes/vfx_manager.gd
# GDScript / vfx_manager.gd / Godot 4.7 / VFX & Game Feel Manager
class_name VFXManager
extends Control

const SHADER_DEATH_RING: String = "res://assets/shaders/death_ring.gdshader"
const SHADER_RIVER_BARRIER: String = "res://assets/shaders/river_barrier.gdshader"
const SHADER_BARRIER_BURN: String = "res://assets/shaders/barrier_burn.gdshader"
const SHADER_HOLY_WAR: String = "res://assets/shaders/holy_war.gdshader"
const SHADER_STEALTH: String = "res://assets/shaders/stealth.gdshader"
const SHADER_PASSIVE_PULSE: String = "res://assets/shaders/passive_pulse.gdshader"

var board_view: BoardView = null
var _shake_tween: Tween = null
var _shake_target: Control = null
var _shake_origin: Vector2 = Vector2.ZERO
var _is_shaking: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	z_index = 40

func setup(p_board_view: BoardView) -> void:
	board_view = p_board_view

func play_card_cast_vfx(card: CardResource, target_slot: Control, from_global_pos: Vector2 = Vector2.ZERO) -> void:
	if target_slot == null or not is_instance_valid(target_slot):
		return
	if not target_slot.is_inside_tree():
		return

	var is_active_card: bool = card != null and card.is_active()
	var flash_color: Color = Color(1.45, 0.72, 0.72, 1.0) if is_active_card else Color(1.15, 0.85, 1.5, 1.0)

	# Flying energy card ghost from hand to ActiveSlot
	if from_global_pos != Vector2.ZERO and is_inside_tree():
		var ghost: ColorRect = ColorRect.new()
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.size = Vector2(96.0, 140.0)
		ghost.color = Color(0.91, 0.27, 0.33, 0.78) if is_active_card else Color(0.64, 0.42, 1.0, 0.78)
		ghost.global_position = from_global_pos
		ghost.z_index = 60
		add_child(ghost)

		var target_pos: Vector2 = target_slot.global_position + (target_slot.size - ghost.size) * 0.5
		var fly_tween: Tween = create_tween()
		fly_tween.set_parallel(true)
		fly_tween.set_trans(Tween.TRANS_CUBIC)
		fly_tween.set_ease(Tween.EASE_OUT)
		fly_tween.tween_property(ghost, "global_position", target_pos, 0.22)
		fly_tween.tween_property(ghost, "scale", Vector2(1.08, 1.08), 0.14)
		fly_tween.tween_property(ghost, "modulate:a", 0.0, 0.24)
		fly_tween.chain().tween_callback(ghost.queue_free)

	# Scale punch (1.12 -> 1.0) + flash on target slot
	target_slot.pivot_offset = target_slot.size * 0.5
	target_slot.scale = Vector2(1.12, 1.12)
	target_slot.modulate = flash_color

	var slot_tween: Tween = target_slot.create_tween()
	slot_tween.set_parallel(true)
	slot_tween.set_trans(Tween.TRANS_BACK)
	slot_tween.set_ease(Tween.EASE_OUT)
	slot_tween.tween_property(target_slot, "scale", Vector2.ONE, 0.26)
	slot_tween.tween_property(target_slot, "modulate", Color.WHITE, 0.28)

func play_tile_vfx(pos: Vector2i, vfx_type: String) -> void:
	var tile_rect: Rect2 = _resolve_tile_rect(pos)
	var effect_node: TileVFXNode = TileVFXNode.new()
	effect_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_node.vfx_type = vfx_type
	effect_node.tile_size = tile_rect.size
	effect_node.z_index = 45

	# Expand bounds for multi-tile effects
	var pad: Vector2 = tile_rect.size * 1.4 if (vfx_type == "explosion_cross" or vfx_type == "vortex" or vfx_type == "fusion_beam") else tile_rect.size * 0.5
	effect_node.position = tile_rect.position - pad
	effect_node.size = tile_rect.size + pad * 2.0
	effect_node.center_offset = pad + tile_rect.size * 0.5

	if not is_inside_tree():
		effect_node.free()
		return

	add_child(effect_node)

	var duration: float = _get_vfx_duration(vfx_type)
	var tween: Tween = effect_node.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(effect_node.set_progress, 0.0, 1.0, duration)
	tween.tween_callback(effect_node.queue_free)

func trigger_board_shake(intensity: float = 8.0, duration: float = 0.25, target: Control = null) -> void:
	var shake_node: Control = target
	if shake_node == null and board_view != null:
		shake_node = board_view
	if shake_node == null or not is_instance_valid(shake_node) or not shake_node.is_inside_tree():
		return

	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		if _shake_target != null and is_instance_valid(_shake_target) and _is_shaking:
			_shake_target.position = _shake_origin

	_shake_target = shake_node
	_shake_origin = shake_node.position
	_is_shaking = true

	var steps: int = 6
	var step_dur: float = maxf(duration / float(steps + 1), 0.02)
	var offsets: Array[Vector2] = [
		Vector2(1.0, -0.7),
		Vector2(-0.9, 0.8),
		Vector2(0.7, 0.6),
		Vector2(-0.6, -0.5),
		Vector2(0.4, -0.3),
		Vector2(-0.2, 0.2)
	]

	_shake_tween = shake_node.create_tween()
	for i in range(steps):
		var damping: float = 1.0 - (float(i) / float(steps))
		var offset_vec: Vector2 = offsets[i] * intensity * damping
		_shake_tween.tween_property(shake_node, "position", _shake_origin + offset_vec, step_dur)
	_shake_tween.tween_property(shake_node, "position", _shake_origin, step_dur)
	_shake_tween.tween_callback(func() -> void:
		_is_shaking = false
	)

static func get_vfx_type_for_card(card: CardResource) -> String:
	if card == null:
		return "ripple"
	match card.id:
		"ACTIVE_09", "ACTIVE_10", "ACTIVE_11", "ACTIVE_12", "ACTIVE_13", "ACTIVE_15", "ACTIVE_16", "ACTIVE_17":
			return "fusion_beam"
		"ACTIVE_19", "ACTIVE_20", "ACTIVE_21", "ACTIVE_22", "ACTIVE_23", "ACTIVE_24":
			return "lock_chains"
		"ACTIVE_25":
			return "explosion_cross"
		"ACTIVE_30":
			return "vortex"
		"ACTIVE_31", "PASSIVE_01", "PASSIVE_17", "PASSIVE_20":
			return "dissolve"
		_:
			return "ripple"

static func should_shake_for_card(card: CardResource) -> bool:
	if card == null:
		return false
	match card.id:
		"ACTIVE_09", "ACTIVE_10", "ACTIVE_11", "ACTIVE_12", "ACTIVE_13", "ACTIVE_15", "ACTIVE_16", "ACTIVE_17", "ACTIVE_18", "ACTIVE_25", "ACTIVE_30":
			return true
		_:
			return false

func _resolve_tile_rect(pos: Vector2i) -> Rect2:
	if board_view != null and is_instance_valid(board_view):
		return board_view.get_tile_rect(pos)
	var fallback_size: Vector2 = Vector2(95.0, 95.0)
	var col: int = clampi(pos.x, 0, 7)
	var screen_row: int = clampi(7 - pos.y, 0, 7)
	return Rect2(Vector2(float(col) * fallback_size.x, float(screen_row) * fallback_size.y), fallback_size)

func _get_vfx_duration(vfx_type: String) -> float:
	match vfx_type:
		"explosion_cross": return 0.45
		"vortex": return 0.65
		"fusion_beam": return 0.55
		"lock_chains": return 0.50
		"dissolve": return 0.42
		_: return 0.42

class TileVFXNode extends Control:
	var vfx_type: String = "ripple"
	var progress: float = 0.0
	var tile_size: Vector2 = Vector2(95.0, 95.0)
	var center_offset: Vector2 = Vector2(47.5, 47.5)

	func set_progress(p: float) -> void:
		progress = clampf(p, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 1.0 - progress
		var r_base: float = minf(tile_size.x, tile_size.y) * 0.5
		var c: Vector2 = center_offset

		match vfx_type:
			"ripple":
				var r1: float = r_base * (0.25 + progress * 1.15)
				var r2: float = r_base * (0.10 + progress * 0.80)
				draw_arc(c, r1, 0.0, TAU, 48, Color(0.92, 0.78, 0.32, alpha * 0.9), 4.0 * (1.0 - progress * 0.5), true)
				draw_arc(c, r2, 0.0, TAU, 48, Color(0.55, 0.85, 1.0, alpha * 0.65), 2.5, true)
				draw_circle(c, r_base * (0.35 * (1.0 - progress)), Color(1.0, 0.92, 0.65, alpha * 0.35))

			"explosion_cross":
				var arm_len: float = tile_size.x * (0.45 + progress * 0.95)
				var arm_w: float = tile_size.x * 0.42 * (1.0 - progress * 0.45)
				var fire_col: Color = Color(1.0, 0.36, 0.12, alpha * 0.92)
				var core_col: Color = Color(1.0, 0.92, 0.45, alpha * 0.95)
				draw_rect(Rect2(c.x - arm_len, c.y - arm_w * 0.5, arm_len * 2.0, arm_w), fire_col, true)
				draw_rect(Rect2(c.x - arm_w * 0.5, c.y - arm_len, arm_w, arm_len * 2.0), fire_col, true)
				draw_circle(c, r_base * (0.55 + progress * 0.5), core_col)
				draw_arc(c, r_base * (0.6 + progress * 1.4), 0.0, TAU, 48, Color(1.0, 0.55, 0.15, alpha * 0.85), 5.0 * alpha, true)

			"vortex":
				var spin: float = progress * TAU * 2.0
				var pull_r: float = r_base * (1.9 - progress * 1.45)
				for i in range(4):
					var start_a: float = spin + float(i) * (TAU * 0.25)
					draw_arc(c, maxf(pull_r, 4.0), start_a, start_a + 1.1, 24, Color(0.64, 0.38, 1.0, alpha * 0.92), 4.5, true)
					draw_arc(c, maxf(pull_r * 0.6, 2.0), -start_a, -start_a + 0.9, 20, Color(0.32, 0.14, 0.68, alpha * 0.8), 3.0, true)
				draw_circle(c, r_base * 0.38 * (1.0 - progress * 0.4), Color(0.08, 0.03, 0.16, alpha * 0.9))

			"lock_chains":
				var inset: float = r_base * 0.72
				var snap: float = minf(progress * 2.2, 1.0)
				var col_chain: Color = Color(0.92, 0.28, 0.34, alpha * 0.95)
				var col_gold: Color = Color(0.95, 0.78, 0.32, alpha * 0.9)
				var p1: Vector2 = c + Vector2(-inset, -inset) * snap
				var p2: Vector2 = c + Vector2(inset, inset) * snap
				var p3: Vector2 = c + Vector2(inset, -inset) * snap
				var p4: Vector2 = c + Vector2(-inset, inset) * snap
				draw_line(p1, p2, col_chain, 5.0, true)
				draw_line(p3, p4, col_chain, 5.0, true)
				draw_arc(c, r_base * 0.55, 0.0, TAU, 32, col_gold, 3.0, true)

			"fusion_beam":
				var beam_w: float = tile_size.x * 0.62 * (1.0 - progress * 0.45)
				var beam_h: float = tile_size.y * 2.4
				draw_rect(Rect2(c.x - beam_w * 0.5, c.y - beam_h * 0.65, beam_w, beam_h), Color(1.0, 0.86, 0.38, alpha * 0.72), true)
				draw_rect(Rect2(c.x - beam_w * 0.22, c.y - beam_h * 0.65, beam_w * 0.44, beam_h), Color(1.0, 0.98, 0.86, alpha * 0.92), true)
				draw_arc(c, r_base * (0.4 + progress * 1.25), 0.0, TAU, 48, Color(1.0, 0.84, 0.25, alpha * 0.95), 4.0, true)

			"dissolve":
				var flash_a: float = maxf(0.0, 1.0 - progress * 2.5)
				if flash_a > 0.0:
					draw_circle(c, r_base * 0.75, Color(1.0, 0.95, 0.85, flash_a * 0.75))
				for i in range(8):
					var ang: float = float(i) * (TAU / 8.0) + 0.35
					var dist: float = r_base * (0.2 + progress * 0.95)
					var p: Vector2 = c + Vector2(cos(ang), sin(ang)) * dist + Vector2(0.0, -progress * 18.0)
					var sz: float = maxf(2.0, 7.0 * (1.0 - progress))
					draw_rect(Rect2(p - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), Color(0.95, 0.35, 0.42, alpha * 0.9), true)
