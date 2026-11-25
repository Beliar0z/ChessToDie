shader_type canvas_item;

uniform vec4 shadow_tint : source_color = vec4(0.28, 0.42, 0.65, 1.0);
uniform vec4 scan_glow : source_color = vec4(0.68, 0.86, 1.0, 1.0);
uniform float distortion_strength : hint_range(0.001, 0.04) = 0.012;
uniform float pulse_speed : hint_range(0.5, 5.0) = 1.8;

void fragment() {
	vec2 uv = UV;
	float t = TIME * pulse_speed;
	float wave = sin(uv.y * 28.0 + t * 2.2) * distortion_strength;
	vec2 distorted_uv = clamp(uv + vec2(wave, 0.0), vec2(0.0), vec2(1.0));

	vec4 tex = texture(TEXTURE, distorted_uv);
	float scanline = smoothstep(0.75, 0.98, sin(uv.y * 64.0 - t * 4.5) * 0.5 + 0.5);
	float sweep = smoothstep(0.92, 1.0, sin((uv.y - fract(TIME * 0.45)) * 6.28318));
	float alpha_pulse = 0.38 + sin(t) * 0.12;

	vec3 ghost_rgb = mix(tex.rgb, shadow_tint.rgb, 0.55);
	ghost_rgb = mix(ghost_rgb, scan_glow.rgb, scanline * 0.25 + sweep * 0.4);
	COLOR = vec4(ghost_rgb, tex.a * (alpha_pulse + sweep * 0.15));
}
