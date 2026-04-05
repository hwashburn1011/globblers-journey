shader_type spatial;
render_mode blend_mix, unshaded;

// Angry robot eye pulse shader — because a constant stare is creepy,
// but a PULSING stare is downright intimidating. Also flickers like
// a dying CRT because our eyes run on legacy firmware.

uniform vec4 eye_color : source_color = vec4(0.224, 1.0, 0.078, 1.0);
uniform float min_emission : hint_range(0.0, 20.0) = 6.0;
uniform float max_emission : hint_range(0.0, 20.0) = 12.0;
uniform float pulse_frequency : hint_range(0.1, 10.0) = 1.5;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.15;
uniform bool animate = true;

void fragment() {
	float emission_strength = max_emission;

	if (animate) {
		// Smooth sinusoidal pulse between min and max — breathe in, breathe out
		float pulse = sin(TIME * pulse_frequency * TAU) * 0.5 + 0.5;
		emission_strength = mix(min_emission, max_emission, pulse);

		// Pseudo-random flicker — fract(TIME * prime) gives cheap jitter
		// that makes the eyes look slightly unstable, like they could snap at any moment
		float flicker = fract(sin(TIME * 13.0) * 43758.5453);
		emission_strength -= flicker * flicker_amount * max_emission;
	}

	ALBEDO = eye_color.rgb;
	EMISSION = eye_color.rgb * emission_strength;
	ALPHA = 1.0;
}
