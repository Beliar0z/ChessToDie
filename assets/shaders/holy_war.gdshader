shader_type canvas_item;

uniform vec4 sky_darkness : source_color = vec4(0.05, 0.02, 0.08, 0.65);
uniform vec4 lightning_color : source_color = vec4(0.9, 0.8, 1.0, 1.0);
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	vec2 uv = UV;
	// Periodic lightning flash
	float t = TIME * 1.5;
	float strike = pow(sin(t * 3.0) * sin(t * 5.3 + 1.2), 16.0);
	
	vec4 base = sky_darkness;
	if (strike > 0.6) {
		float bolt = 1.0 - abs(uv.x - (0.5 + sin(uv.y * 15.0 + t) * 0.1));
		bolt = smoothstep(0.92, 0.99, bolt);
		base = mix(base, lightning_color, strike * flash_intensity + bolt);
	}
	COLOR = base;
}
