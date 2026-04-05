shader_type spatial;
render_mode blend_mix, unshaded, cull_front;

// Glob target highlight — pulsing green emission + fresnel outline.
// Applied as next_pass on the mesh's material so the base look stays intact.
// "Selected targets get the green ring of destiny."

uniform vec4 highlight_color : source_color = vec4(0.224, 1.0, 0.078, 1.0);
uniform float pulse_speed : hint_range(0.5, 8.0) = 3.0;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_max : hint_range(0.5, 2.0) = 1.0;
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.5;
uniform float emission_strength : hint_range(0.5, 8.0) = 3.0;
uniform float outline_thickness : hint_range(0.0, 0.05) = 0.02;
uniform bool animate = true;

void vertex() {
	// Push verts along normals for outline effect
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power);

	float pulse = 1.0;
	if (animate) {
		pulse = mix(pulse_min, pulse_max, sin(TIME * pulse_speed) * 0.5 + 0.5);
	} else {
		pulse = mix(pulse_min, pulse_max, 0.5);
	}

	float intensity = fresnel * pulse * emission_strength;
	ALBEDO = highlight_color.rgb * intensity;
	ALPHA = clamp(fresnel * pulse * highlight_color.a, 0.0, 0.85);
}
