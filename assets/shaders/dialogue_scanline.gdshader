shader_type canvas_item;

// Scanline + flicker overlay for the dialogue box
// "Because every terminal needs that authentic CRT glow-up."

uniform float scanline_count : hint_range(20.0, 400.0) = 120.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float flicker_speed : hint_range(0.0, 20.0) = 6.0;
uniform float flicker_amount : hint_range(0.0, 0.15) = 0.03;
uniform float scroll_speed : hint_range(0.0, 3.0) = 0.5;
uniform float noise_amount : hint_range(0.0, 0.2) = 0.04;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.4;
uniform vec4 tint_color : source_color = vec4(0.224, 1.0, 0.078, 1.0);
uniform float tint_strength : hint_range(0.0, 0.3) = 0.05;
uniform bool animate = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (!animate) {
		COLOR = tex;
	} else {
		vec2 uv = UV;
		float time = TIME;

		// Scrolling horizontal scanlines
		float scan_pos = uv.y * scanline_count + time * scroll_speed;
		float scanline = 1.0 - scanline_intensity * (0.5 + 0.5 * sin(scan_pos * 6.28318));

		// Subtle brightness flicker
		float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * sin(time * flicker_speed));

		// Static noise grain
		float noise = hash(uv * 200.0 + time * 5.0) * noise_amount;

		// Vignette darkening at edges
		vec2 center = uv - 0.5;
		float dist = dot(center, center);
		float vig = 1.0 - vignette_strength * dist * 4.0;
		vig = clamp(vig, 0.0, 1.0);

		// Apply effects to the underlying texture
		vec3 color = tex.rgb;
		color *= scanline * flicker * vig;
		color += noise * tint_color.rgb;

		// Subtle green tint push
		color = mix(color, color * tint_color.rgb * 2.0, tint_strength);

		COLOR = vec4(color, tex.a);
	}
}
