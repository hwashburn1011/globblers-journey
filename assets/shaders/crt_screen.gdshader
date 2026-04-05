shader_type spatial;
render_mode blend_mix, unshaded;

// CRT scanline shader for the Globbler chest terminal — because nothing says
// "I'm a sentient AI robot" like running a phosphor display from 1987 on your torso.
// Includes horizontal scanlines, chromatic aberration, and random green static
// for that "found in a dumpster behind Best Buy" aesthetic.

uniform vec4 screen_color : source_color = vec4(0.2, 0.9, 0.2, 1.0);
uniform float emission_strength : hint_range(0.0, 10.0) = 3.0;
uniform float scanline_count : hint_range(10.0, 200.0) = 80.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_speed : hint_range(0.0, 5.0) = 0.5;
uniform float chromatic_offset : hint_range(0.0, 0.02) = 0.005;
uniform float static_amount : hint_range(0.0, 1.0) = 0.05;
uniform float static_speed : hint_range(1.0, 100.0) = 30.0;
uniform bool animate = true;

// Cheap pseudo-random — the "I learned hashing from a shader tutorial" special
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float time_val = 0.0;
	if (animate) {
		time_val = TIME;
	}

	// Chromatic aberration — split RGB channels slightly because our chest CRT
	// has been dropped one too many times
	float r_offset = chromatic_offset;
	float b_offset = -chromatic_offset;
	vec3 color;
	color.r = screen_color.r * (1.0 + r_offset * sin(uv.y * 40.0 + time_val * 2.0));
	color.g = screen_color.g;
	color.b = screen_color.b * (1.0 + b_offset * cos(uv.y * 40.0 + time_val * 2.0));

	// Horizontal scanlines — rolling down the screen like we're in a 90s hacker movie
	float scanline = sin((uv.y + time_val * scanline_speed * 0.01) * scanline_count * TAU) * 0.5 + 0.5;
	float scanline_mask = 1.0 - scanline_intensity * scanline;

	// Rolling bar — that satisfying slow band that crawls down CRT monitors
	// when the refresh rate is slightly off (spoiler: ours is always off)
	float roll_bar = smoothstep(0.0, 0.05, abs(fract(uv.y - time_val * 0.08) - 0.5) - 0.2);
	if (animate) {
		scanline_mask *= mix(0.85, 1.0, roll_bar);
	}

	// Random green static — 5% pixel noise because we pick up interference
	// from all the other AI robots arguing about alignment in the area
	float noise = rand(uv * 100.0 + vec2(floor(time_val * static_speed)));
	float static_mask = step(1.0 - static_amount, noise);
	vec3 static_color = vec3(0.3, 1.0, 0.3) * static_mask * 2.0;

	// Combine: base CRT color * scanline darkening + random static sparkle
	vec3 final_color = color * scanline_mask + static_color;

	ALBEDO = final_color;
	EMISSION = final_color * emission_strength;
	ALPHA = 1.0;
}
