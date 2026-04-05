shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

// Hackable Terminal Beacon — vertical light beam + ring pulse
// "Follow the green light, meatbag. It means FREE STUFF."

uniform vec4 beam_color : source_color = vec4(0.224, 1.0, 0.078, 0.6);
uniform float pulse_speed : hint_range(0.5, 8.0) = 2.5;
uniform float scroll_speed : hint_range(0.1, 3.0) = 1.0;
uniform float glow_intensity : hint_range(0.5, 10.0) = 3.0;
uniform float proximity_fade : hint_range(0.0, 1.0) = 0.0;
uniform bool is_ring = false;
uniform bool animate = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float t = animate ? TIME : 0.0;
	vec2 uv = UV;

	float pulse = sin(t * pulse_speed) * 0.2 + 0.8;
	float pulse2 = sin(t * pulse_speed * 0.7 + 1.0) * 0.15 + 0.85;

	float intensity;

	if (is_ring) {
		// Ring mode: radial pulse expanding outward from center
		float dist = length(uv - vec2(0.5));
		// Ring band that pulses outward
		float ring_phase = fract(t * 0.4);
		float ring = smoothstep(0.02, 0.0, abs(dist - ring_phase * 0.5));
		// Static inner glow
		float inner = smoothstep(0.4, 0.0, dist) * 0.3;
		intensity = (ring + inner) * pulse;
	} else {
		// Beam mode: vertical scrolling energy column
		float center_dist = abs(uv.x - 0.5) * 2.0;
		float edge = 1.0 - center_dist;
		edge = pow(max(edge, 0.0), 2.0);
		edge = smoothstep(0.0, 0.25, edge);

		// Scrolling noise pattern
		float scroll = t * scroll_speed;
		float pattern = value_noise(vec2(uv.x * 8.0, uv.y * 6.0 + scroll));
		pattern = mix(0.5, pattern, 0.6);

		// Vertical fade: strong at base, thin at top
		float vert_fade = pow(1.0 - uv.y, 0.8);

		intensity = edge * pattern * vert_fade * pulse2;
	}

	vec3 color = beam_color.rgb * intensity * glow_intensity;
	float alpha = beam_color.a * intensity * proximity_fade;

	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
	EMISSION = color * 1.2;
}
