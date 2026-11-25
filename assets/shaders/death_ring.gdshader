shader_type canvas_item;

uniform vec4 flame_color : source_color = vec4(0.88, 0.14, 0.04, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.78, 0.18, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform float ring_thickness : hint_range(0.02, 0.25) = 0.085;
uniform float speed : hint_range(0.5, 6.0) = 2.4;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float min_edge = min(edge_x, edge_y);

	float breath = 1.0 + 0.12 * sin(TIME * speed * 1.4);
	float dynamic_thick = ring_thickness * breath;

	if (min_edge < dynamic_thick * 1.35) {
		float norm = clamp(1.0 - (min_edge / dynamic_thick), 0.0, 1.0);
		float t = TIME * speed;
		float wave = sin((uv.x * 26.0 + uv.y * 26.0) + t * 2.2) * 0.5 + 0.5;
		float flicker = sin(uv.x * 52.0 - t * 3.1) * cos(uv.y * 52.0 + t * 2.7) * 0.5 + 0.5;

		// Moving ember sparks along the ring
		vec2 spark_grid = floor(vec2(uv.x * 36.0 + sin(t) * 2.0, uv.y * 36.0 - t * 3.5));
		float spark_rnd = hash21(spark_grid);
		float spark = smoothstep(0.92, 0.99, spark_rnd) * smoothstep(0.0, 0.65, 1.0 - min_edge / (dynamic_thick * 1.3));

		float fire_intensity = clamp(norm * 0.85 + wave * 0.22 + flicker * 0.18, 0.0, 1.0);
		vec4 col = mix(flame_color, core_color, pow(fire_intensity, 1.8));
		col = mix(col, ember_color, spark);

		float edge_alpha = smoothstep(0.0, 0.28, norm) * 0.88;
		col.a = clamp(edge_alpha + spark * 0.7, 0.0, 0.92);
		COLOR = col;
	} else {
		COLOR = vec4(0.0);
	}
}
