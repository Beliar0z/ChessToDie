shader_type canvas_item;

uniform vec4 gold_color : source_color = vec4(1.0, 0.84, 0.24, 1.0);
uniform vec4 void_violet : source_color = vec4(0.68, 0.36, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.5, 8.0) = 3.6;

void fragment() {
	float t = TIME * pulse_speed;
	float breath = sin(t) * 0.5 + 0.5;
	float shimmer = sin((UV.x + UV.y) * 14.0 - t * 1.8) * 0.5 + 0.5;

	vec4 col = mix(void_violet, gold_color, 0.45 + 0.55 * breath);
	col.rgb += vec3(0.18) * shimmer * breath;
	col.a = COLOR.a * (0.55 + 0.45 * breath);
	COLOR = col;
}
