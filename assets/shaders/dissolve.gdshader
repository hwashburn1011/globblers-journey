shader_type spatial;
render_mode blend_mix, cull_back;

// Death dissolve — because dying should look SICK. Vertical noise-based dissolve
// from bottom to top with a glowing neon-green edge. Tween dissolve_amount 0→1 to
// disintegrate, 1→0 to rematerialize. Very anime. Very dramatic.

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.06;
uniform vec4 edge_color : source_color = vec4(0.224, 1.0, 0.078, 1.0);  // #39FF14 baby
uniform float edge_emission_strength : hint_range(0.0, 20.0) = 8.0;
uniform float noise_scale : hint_range(1.0, 50.0) = 12.0;
uniform float height_bias : hint_range(0.0, 1.0) = 0.6;  // how much height vs noise matters

// Cheap hash-based noise — no texture needed, we're runtime artisans
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);  // smoothstep interpolation, not smoothbrain

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise for that extra crispy dissolve edge
float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		val += amp * value_noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	if (dissolve_amount < 0.001) {
		// Not dissolving — full opacity, bail early like a lazy garbage collector
		ALPHA = 1.0;
	} else {
		// Mix model-space height with noise for organic dissolve pattern
		// VERTEX.y is in model space — bottom is low, top is high
		float height_factor = clamp((VERTEX.y + 0.5) / 1.5, 0.0, 1.0);
		float noise = fbm(UV * noise_scale);

		// Blend height and noise — height_bias controls the vertical sweep direction
		float dissolve_value = mix(noise, height_factor, height_bias);

		// The threshold marches from -edge_width to 1.0+edge_width as dissolve_amount goes 0→1
		float threshold = dissolve_amount * (1.0 + edge_width * 2.0) - edge_width;

		// Distance from the dissolve front — negative = dissolved, positive = still here
		float dist = dissolve_value - threshold;

		if (dist < 0.0) {
			// Gone. Deleted. rm -rf'd from existence.
			discard;
		}

		// Glowing edge zone — the dramatic green fire of digital death
		float edge_factor = 1.0 - smoothstep(0.0, edge_width, dist);

		// Apply edge glow — override emission in the edge zone
		EMISSION = edge_color.rgb * edge_factor * edge_emission_strength;
		// Slight alpha fade at the very edge for softer look
		ALPHA = smoothstep(0.0, edge_width * 0.3, dist);
		ALPHA = max(ALPHA, edge_factor * 0.8);  // but keep the glow visible
	}
}
