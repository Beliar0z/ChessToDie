shader_type canvas_item;

uniform vec4 river_deep : source_color = vec4(0.14, 0.22, 0.68, 0.78);
uniform vec4 river_glow : source_color = vec4(0.32, 0.72, 1.0, 0.92);
uniform vec4 arcane_violet : source_color = vec4(0.62, 0.36, 1.0, 0.85);
uniform float flow_speed : hint_range(0.5, 5.0) = 2.4;
uniform float band_half_height : hint_range(0.02, 0.35) = 0.075;

void fragment() {
	vec2 uv = UV;
	float t = TIME * flow_speed;

	float wave1 = sin(uv.x * 22.0 - t * 1.8) * 0.014;
	float wave2 = cos(uv.x * 38.0 + t * 2.3) * 0.008;
	float center_dist = abs(uv.y - 0.5 + wave1 + wave2);

	float mask = 1.0 - smoothstep(band_half_height * 0.45, band_half_height, center_dist);
	if (mask <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		float stream = sin(uv.x * 30.0 - t * 3.0 + uv.y * 12.0) * 0.5 + 0.5;
		float foam = smoothstep(band_half_height * 0.42, band_half_height * 0.82, center_dist) * mask;

		vec4 base_col = mix(river_deep, arcane_violet, stream * 0.45);
		vec4 col = mix(base_col, river_glow, foam * 0.85 + stream * 0.25);
		col.a = mask * (0.68 + 0.24 * foam);
		COLOR = col;
	}
}
