shader_type canvas_item;

// Full-screen glitch/static transition shader
// Used by ChapterTransition overlay during scene changes

uniform float progress : hint_range(0.0, 1.0) = 0.0; // 0 = clear, 1 = full static
uniform float time_offset : hint_range(0.0, 1000.0) = 0.0;
uniform vec3 tint_color : source_color = vec3(0.22, 1.0, 0.08); // terminal green
uniform float scanline_count : hint_range(50.0, 800.0) = 300.0;
uniform bool animate = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	float t = animate ? time_offset : 0.0;
	vec2 uv = SCREEN_UV;

	// Static noise — intensifies with progress
	float static_noise = hash(uv * 800.0 + vec2(t * 43.7, t * 17.3));
	static_noise = mix(0.0, static_noise, progress);

	// Horizontal glitch bands — random offset strips
	float band = floor(uv.y * 30.0 + t * 8.0);
	float band_noise = hash(vec2(band, floor(t * 12.0)));
	float glitch_shift = 0.0;
	if (band_noise > (1.0 - progress * 0.6)) {
		glitch_shift = (hash(vec2(band, t)) - 0.5) * 0.08 * progress;
	}

	// Scanlines
	float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
	scanline = mix(1.0, scanline * 0.7 + 0.3, progress * 0.5);

	// Color channel split (chromatic aberration increases with progress)
	float chroma = progress * 0.015;
	float r = texture(TEXTURE, vec2(uv.x + glitch_shift + chroma, uv.y)).r;
	float g = texture(TEXTURE, vec2(uv.x + glitch_shift, uv.y)).g;
	float b = texture(TEXTURE, vec2(uv.x + glitch_shift - chroma, uv.y)).b;

	// Blend between screen content and static based on progress
	vec3 screen_color = vec3(r, g, b) * scanline;
	vec3 static_color = vec3(static_noise) * tint_color;

	// At low progress: subtle glitch overlay. At high progress: full static takeover.
	float static_blend = smoothstep(0.3, 0.9, progress);
	vec3 final_color = mix(screen_color, static_color, static_blend);

	// Black bars that sweep in at high progress
	float black_sweep = smoothstep(0.7, 1.0, progress);
	final_color *= mix(1.0, 0.0, black_sweep);

	// Alpha ramps with progress
	float alpha = smoothstep(0.0, 0.15, progress);

	COLOR = vec4(final_color, alpha);
}
