shader_type canvas_item;

uniform vec4 shadow_tint : source_color = vec4(0.2, 0.3, 0.45, 0.4);
uniform float distortion_strength : hint_range(0.001, 0.05) = 0.015;
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.5;

void fragment() {
	vec2 uv = UV;
	float wave = sin(uv.y * 30.0 + TIME * pulse_speed) * distortion_strength;
	vec2 distorted_uv = uv + vec2(wave, 0.0);
	
	vec4 tex = texture(TEXTURE, distorted_uv);
	float alpha_pulse = 0.35 + sin(TIME * pulse_speed) * 0.15;
	
	vec4 final_col = mix(tex, shadow_tint, 0.6);
	final_col.a = tex.a * alpha_pulse;
	COLOR = final_col;
}
