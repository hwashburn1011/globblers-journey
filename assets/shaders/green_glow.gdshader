shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

// Pulsing green glow shader — because everything Globbler touches should glow
// like it owes him money. Attach to interactive objects and glob targets.

uniform vec4 glow_color : source_color = vec4(0.224, 1.0, 0.078, 0.8);
uniform float pulse_speed : hint_range(0.5, 8.0) = 2.5;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.4;
uniform float pulse_max : hint_range(0.5, 3.0) = 1.2;
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.0;
uniform float glow_intensity : hint_range(0.5, 5.0) = 2.0;

void fragment() {
	// Fresnel rim glow — brighter at edges like a proper sci-fi outline
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power);

	// Pulsing brightness — heartbeat of the digital realm
	float pulse = mix(pulse_min, pulse_max, (sin(TIME * pulse_speed) * 0.5 + 0.5));

	ALBEDO = glow_color.rgb * glow_intensity * pulse;
	ALPHA = fresnel * glow_color.a * pulse;
}
