shader_type canvas_item;

uniform vec4 burn_color : source_color = vec4(0.95, 0.22, 0.06, 0.9);
uniform vec4 rune_color : source_color = vec4(1.0, 0.72, 0.16, 1.0);
uniform float pulse_speed : hint_range(0.5, 6.0) = 3.2;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	float d = distance(uv, center);
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;

	// Outer tile border flame
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float border_mask = 1.0 - smoothstep(0.02, 0.11, edge);

	// Rotating hexagonal rune ring
	float angle = atan(uv.y - center.y, uv.x - center.x) + TIME * 0.4;
	float hex = cos(angle * 6.0) * 0.035;
	float ring = abs(d - (0.38 + hex));
	float ring_mask = 1.0 - smoothstep(0.012, 0.045, ring);

	float combined = max(border_mask * 0.85, ring_mask * 0.9);
	float center_tint = (1.0 - smoothstep(0.0, 0.48, d)) * 0.12;

	vec4 col = mix(burn_color, rune_color, pulse * 0.65 + ring_mask * 0.35);
	col.a = clamp((combined * (0.65 + 0.35 * pulse)) + center_tint, 0.0, 0.88);
	COLOR = col;
}
