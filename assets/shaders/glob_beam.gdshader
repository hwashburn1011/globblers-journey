shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

// Glob Beam Shader - Green energy beam for Globbler's signature move
// "Shaders are just math with attitude." - Globbler, probably

uniform vec4 beam_color : source_color = vec4(0.224, 1.0, 0.078, 0.8);
uniform float pulse_speed : hint_range(0.1, 10.0) = 3.0;
uniform float scroll_speed : hint_range(0.1, 5.0) = 2.0;
uniform float glow_intensity : hint_range(0.5, 10.0) = 3.0;
uniform float edge_fade : hint_range(0.1, 2.0) = 0.5;

void fragment() {
	// Scrolling UV for energy flow effect
	vec2 uv = UV;
	uv.y += TIME * scroll_speed;

	// Create energy pattern — overlapping sine waves
	float pattern = sin(uv.y * 20.0) * 0.5 + 0.5;
	pattern *= sin(uv.y * 7.0 + TIME * pulse_speed) * 0.3 + 0.7;

	// Edge fade — beam is brighter in center
	float edge = 1.0 - abs(uv.x - 0.5) * 2.0;
	edge = pow(edge, edge_fade);

	// Pulse overall brightness
	float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;

	// Final color
	float intensity = pattern * edge * pulse;
	ALBEDO = beam_color.rgb * intensity * glow_intensity;
	ALPHA = beam_color.a * intensity;
	EMISSION = beam_color.rgb * intensity * glow_intensity * 0.5;
}
