shader_type spatial;

// Glitch shader for corrupted enemies — because nothing says "I'm broken"
// like occasionally teleporting your own vertices. Applied to things that
// should probably have been garbage collected ages ago.

uniform vec4 base_color : source_color = vec4(0.2, 0.8, 0.9, 1.0);
uniform vec4 glitch_color : source_color = vec4(0.9, 0.1, 0.3, 1.0);
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float glitch_speed : hint_range(0.5, 10.0) = 4.0;
uniform float vertex_displacement : hint_range(0.0, 0.5) = 0.15;
uniform float color_split : hint_range(0.0, 0.2) = 0.06;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.7;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.3;
uniform float emission_energy : hint_range(0.5, 5.0) = 2.5;

// Cheap pseudo-random
float rand(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

float rand2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	// Periodic vertex glitch — random displacement bursts
	float glitch_time = floor(TIME * glitch_speed);
	float glitch_trigger = step(0.7, rand(glitch_time));

	if (glitch_trigger > 0.0) {
		// Slice the model along Y and offset slices horizontally
		float slice = floor(VERTEX.y * 8.0) / 8.0;
		float offset = (rand(slice + glitch_time) - 0.5) * vertex_displacement * 2.0;
		VERTEX.x += offset * glitch_intensity;
		VERTEX.z += (rand(slice + glitch_time + 1.0) - 0.5) * vertex_displacement * glitch_intensity;
	}
}

void fragment() {
	float glitch_time = floor(TIME * glitch_speed);
	float glitch_trigger = step(0.7, rand(glitch_time));

	// Color channel split during glitch — RGB offset like a dying monitor
	vec3 color = base_color.rgb;
	if (glitch_trigger > 0.0) {
		float split = color_split * glitch_intensity;
		// Shift hue toward glitch color during corruption bursts
		float blend = rand(glitch_time + 3.0) * glitch_intensity * 0.6;
		color = mix(color, glitch_color.rgb, blend);

		// Horizontal band corruption
		float band = step(0.6, rand2(vec2(floor(UV.y * 12.0), glitch_time)));
		color = mix(color, glitch_color.rgb, band * 0.4);
	}

	// Subtle persistent scan distortion — always a little broken
	float scan = 0.95 + 0.05 * sin(UV.y * 40.0 + TIME * 3.0);
	color *= scan;

	ALBEDO = color;
	EMISSION = color * emission_energy;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
}
