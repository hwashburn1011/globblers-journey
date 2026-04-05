shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

// Glob Beam Shader V2 - The beam that makes enemies reconsider their life choices
// Now with 200% more "please don't look directly at it"

uniform vec4 beam_color : source_color = vec4(0.224, 1.0, 0.078, 0.85);
uniform vec4 core_color : source_color = vec4(0.7, 1.0, 0.7, 1.0);
uniform float pulse_speed : hint_range(0.1, 10.0) = 3.0;
uniform float scroll_speed : hint_range(0.1, 5.0) = 2.0;
uniform float glow_intensity : hint_range(0.5, 20.0) = 5.0;
uniform float edge_softness : hint_range(0.5, 4.0) = 1.8;
uniform float core_width : hint_range(0.01, 0.5) = 0.15;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.03;
uniform float noise_scale : hint_range(1.0, 50.0) = 12.0;
uniform bool animate = true;

// Cheap pseudo-noise — no texture needed, just math being dramatic
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep interpolation
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise — because one layer of chaos is never enough
float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		val += amp * value_noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	float t = animate ? TIME : 0.0;

	vec2 uv = UV;

	// Distort UVs with noise for organic energy wobble
	float noise_distort = fbm(vec2(uv.x * 8.0, uv.y * 4.0 + t * 1.5));
	uv.x += (noise_distort - 0.5) * distortion_strength;

	// Scrolling UV for energy flow — two speeds for parallax depth
	float scroll_fast = t * scroll_speed;
	float scroll_slow = t * scroll_speed * 0.6;

	// Multi-layer energy pattern — overlapping noise bands
	float pattern1 = fbm(vec2(uv.x * noise_scale, uv.y * noise_scale * 0.5 + scroll_fast));
	float pattern2 = fbm(vec2(uv.x * noise_scale * 0.7 + 3.7, uv.y * noise_scale * 0.3 + scroll_slow));
	float pattern = mix(pattern1, pattern2, 0.5);
	pattern = smoothstep(0.25, 0.75, pattern); // contrast boost

	// Soft edge falloff — cubic for smoother beam boundary
	float center_dist = abs(uv.x - 0.5) * 2.0;
	float edge = 1.0 - center_dist;
	edge = pow(max(edge, 0.0), edge_softness);
	edge = smoothstep(0.0, 0.3, edge); // extra soft taper at the fringe

	// Hot core — bright white-green center stripe
	float core = 1.0 - smoothstep(0.0, core_width, center_dist);
	core = pow(core, 2.0); // sharp but smooth falloff

	// Pulsing — subtle throb that the bloom system will love
	float pulse = sin(t * pulse_speed) * 0.12 + 0.88;
	float pulse2 = sin(t * pulse_speed * 1.7 + 1.3) * 0.08 + 0.92;

	// Beam body intensity
	float body = pattern * edge * pulse;

	// Core intensity — cranked high for bloom to grab onto
	float core_intensity = core * pulse2 * 2.0;

	// Combine: body beam + superimposed hot core
	vec3 body_color = beam_color.rgb * body * glow_intensity;
	vec3 hot_core = core_color.rgb * core_intensity * glow_intensity;
	vec3 final_color = body_color + hot_core;

	// Alpha: beam visibility with soft edges, core always opaque-ish
	float alpha = beam_color.a * max(body, core_intensity * 0.5);

	ALBEDO = final_color;
	ALPHA = clamp(alpha, 0.0, 1.0);

	// Emission cranked for bloom — the post-process glow pass will feast on this
	EMISSION = final_color * 1.5;
}
