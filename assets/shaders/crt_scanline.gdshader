shader_type spatial;
render_mode unshaded, cull_disabled;

// CRT/Scanline shader for in-world terminal screens
// "Retro is just 'we ran out of budget' with better branding."

uniform vec4 screen_color : source_color = vec4(0.15, 0.6, 0.1, 1.0);
uniform vec4 bg_color : source_color = vec4(0.01, 0.03, 0.01, 1.0);
uniform float scanline_count : hint_range(20.0, 200.0) = 80.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;
uniform float flicker_amount : hint_range(0.0, 0.2) = 0.04;
uniform float warp_amount : hint_range(0.0, 0.1) = 0.02;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.8;
uniform float glow_energy : hint_range(0.5, 5.0) = 2.5;
uniform float noise_amount : hint_range(0.0, 0.3) = 0.08;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.3;

// Pseudo-random hash — cheaper than importing a texture
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// CRT barrel distortion — the curvature of nostalgia
	vec2 center = uv - 0.5;
	float dist = dot(center, center);
	uv = uv + center * dist * warp_amount;

	// Scrolling scanlines — the telltale sign of "I am a computer screen"
	float scan_pos = uv.y * scanline_count + TIME * scroll_speed;
	float scanline = 1.0 - scanline_intensity * (0.5 + 0.5 * sin(scan_pos * 3.14159 * 2.0));

	// Flicker — screens don't just sit there, they twitch
	float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * flicker_speed));

	// Static noise — the ghost in the machine
	float noise = hash(uv * 100.0 + TIME * 7.0) * noise_amount;

	// Vignette — dark edges, bright center, just like our self-awareness
	float vig = 1.0 - vignette_strength * dist * 4.0;
	vig = clamp(vig, 0.0, 1.0);

	// Combine — green phosphor glow with all the CRT artifacts
	vec3 color = mix(bg_color.rgb, screen_color.rgb, 0.6 + noise);
	color *= scanline * flicker * vig;

	ALBEDO = color;
	EMISSION = color * glow_energy;
}
