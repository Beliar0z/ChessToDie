shader_type canvas_item;

uniform vec4 flame_color : source_color = vec4(0.85, 0.15, 0.05, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.7, 0.1, 1.0);
uniform float ring_thickness : hint_range(0.01, 0.3) = 0.08;
uniform float speed : hint_range(0.5, 5.0) = 2.0;

void fragment() {
	vec2 uv = UV;
	float edge_dist_x = min(uv.x, 1.0 - uv.x);
	float edge_dist_y = min(uv.y, 1.0 - uv.y);
	float min_edge = min(edge_dist_x, edge_dist_y);
	
	if (min_edge < ring_thickness) {
		float norm = 1.0 - (min_edge / ring_thickness);
		float wave = sin((uv.x + uv.y) * 20.0 + TIME * speed) * 0.5 + 0.5;
		float noise = sin(uv.x * 40.0 - TIME * speed * 1.5) * cos(uv.y * 40.0 + TIME * speed);
		float fire_intensity = clamp(norm + wave * 0.3 + noise * 0.2, 0.0, 1.0);
		
		vec4 final_col = mix(flame_color, core_color, fire_intensity * fire_intensity);
		final_col.a *= smoothstep(0.0, 0.2, norm) * 0.85;
		COLOR = final_col;
	} else {
		COLOR = vec4(0.0);
	}
}
