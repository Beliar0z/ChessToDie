shader_type canvas_item;

uniform vec4 crimson_aura : source_color = vec4(0.68, 0.08, 0.14, 0.85);
uniform vec4 gold_radiance : source_color = vec4(1.0, 0.82, 0.28, 0.95);
uniform float aura_thickness : hint_range(0.03, 0.28) = 0.11;
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;

void fragment() {
	vec2 uv = UV;
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float min_edge = min(edge_x, edge_y);

	float t = TIME * pulse_speed;
	float pulse = sin(t) * 0.5 + 0.5;
	float thick = aura_thickness * (0.9 + 0.2 * pulse);

	if (min_edge < thick) {
		float norm = 1.0 - (min_edge / thick);
		vec2 centered = uv - vec2(0.5);
		float angle = atan(centered.y, centered.x);
		float rays = sin(angle * 16.0 + t * 1.4) * 0.5 + 0.5;

		vec4 col = mix(crimson_aura, gold_radiance, clamp(norm * 0.7 + rays * 0.35, 0.0, 1.0));
		col.a = smoothstep(0.0, 0.35, norm) * (0.55 + 0.3 * rays);
		COLOR = col;
	} else {
		COLOR = vec4(0.0);
	}
}
