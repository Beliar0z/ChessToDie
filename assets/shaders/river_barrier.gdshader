shader_type canvas_item;

uniform vec4 river_color : source_color = vec4(0.1, 0.5, 0.9, 0.85);
uniform vec4 foam_color : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform float flow_speed : hint_range(0.5, 5.0) = 2.5;

void fragment() {
	vec2 uv = UV;
	float wave1 = sin(uv.x * 25.0 + TIME * flow_speed) * 0.05;
	float wave2 = cos(uv.x * 40.0 - TIME * flow_speed * 1.2) * 0.03;
	float center_dist = abs(uv.y - 0.5 + wave1 + wave2);
	
	float river_mask = 1.0 - smoothstep(0.0, 0.45, center_dist);
	float foam = smoothstep(0.3, 0.42, center_dist) * river_mask;
	
	vec4 col = mix(river_color, foam_color, foam);
	col.a *= river_mask;
	COLOR = col;
}
