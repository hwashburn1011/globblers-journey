shader_type canvas_item;

// CRT curvature post-process — barrel distortion + vignette + subtle scanlines
// "Every screen deserves to look like it was manufactured in 1987."
// Applied as a full-screen ColorRect on a high CanvasLayer.

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float barrel_strength : hint_range(0.0, 0.15) = 0.04;
uniform float scanline_count : hint_range(100.0, 1000.0) = 400.0;
uniform float scanline_alpha : hint_range(0.0, 0.3) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.45;
uniform float vignette_softness : hint_range(0.1, 2.0) = 0.6;
uniform float chromatic_offset : hint_range(0.0, 3.0) = 0.8;
uniform bool animate = true;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Barrel distortion — CRT bulge
	vec2 centered = uv - 0.5;
	float dist_sq = dot(centered, centered);
	vec2 warped = uv + centered * dist_sq * barrel_strength;

	// Slight chromatic aberration along distortion direction
	vec2 ca_offset = centered * dist_sq * chromatic_offset * 0.002;
	float r = textureLod(SCREEN_TEXTURE, warped + ca_offset, 0.0).r;
	float g = textureLod(SCREEN_TEXTURE, warped, 0.0).g;
	float b = textureLod(SCREEN_TEXTURE, warped - ca_offset, 0.0).b;
	vec3 color = vec3(r, g, b);

	// Black outside the warped bounds — CRT bezel effect
	if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
		color = vec3(0.0);
	}

	// Subtle scanlines — horizontal darkening bands
	if (animate) {
		float scan = sin(warped.y * scanline_count * 3.14159) * 0.5 + 0.5;
		color *= 1.0 - scanline_alpha * scan;
	}

	// Vignette — dark edges
	float vig = 1.0 - smoothstep(vignette_softness, vignette_softness + 0.4, length(centered) * 2.0) * vignette_strength;
	color *= vig;

	COLOR = vec4(color, 1.0);
}
