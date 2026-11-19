shader_type canvas_item;

uniform vec4 burn_color : source_color = vec4(0.95, 0.2, 0.05, 0.9);
uniform vec4 rune_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float pulse_speed : hint_range(0.5, 5.0) = 3.0;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	float d = distance(uv, center);
	
	// Hexagonal barrier pulse
	float angle = atan(uv.y - center.y, uv.x - center.x);
	float hex = cos(angle * 6.0) * 0.04;
	float ring = abs(d - (0.42 + hex));
	
	float ring_mask = 1.0 - smoothstep(0.01, 0.06, ring);
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	
	vec4 col = mix(burn_color, rune_color, pulse);
	col.a *= ring_mask * (0.7 + 0.3 * pulse);
	COLOR = col;
}
