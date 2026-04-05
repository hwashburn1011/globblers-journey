shader_type spatial;
render_mode blend_add, unshaded, cull_back;

// Damage flash overlay — because nothing says "I'm hurt" like turning into a
// traffic light. White-to-red additive blast, controlled by flash_intensity.
// Slap this on next_pass of any mesh material and tween flash_intensity 1→0.

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color_start : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // white
uniform vec4 flash_color_end : source_color = vec4(1.0, 0.15, 0.1, 1.0);   // angry red

void fragment() {
	// Lerp from white (ouch) to red (OUCH) as intensity fades out —
	// maximum drama per pixel
	vec3 color = mix(flash_color_end.rgb, flash_color_start.rgb, flash_intensity);
	ALBEDO = color;
	EMISSION = color * flash_intensity * 3.0;
	ALPHA = flash_intensity * 0.7;
}
