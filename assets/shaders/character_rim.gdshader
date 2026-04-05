shader_type spatial;
render_mode blend_mix;

// Fresnel rim-light shader for the Globbler body — because even dark metal
// deserves a neon green halo that screams "protagonist energy."
// Applied as next_pass material so the base PBR still renders underneath.

uniform vec4 rim_color : source_color = vec4(0.2, 1.0, 0.1, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_intensity : hint_range(0.0, 5.0) = 1.5;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = vec3(0.0);
	EMISSION = rim_color.rgb * fresnel * rim_intensity;
	ALPHA = fresnel * rim_color.a;
}
