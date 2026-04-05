shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

// Emissive green weapon trail ribbon
uniform vec4 trail_color : source_color = vec4(0.224, 1.0, 0.078, 0.9);
uniform float fade_power : hint_range(0.5, 4.0) = 1.5;

void fragment() {
	// UV.x = 0 at newest point, 1 at oldest — fade out along length
	float alpha = pow(1.0 - UV.x, fade_power) * trail_color.a;
	// UV.y = 0 at base, 1 at tip — slight gradient for depth
	float width_fade = sin(UV.y * PI);
	ALBEDO = trail_color.rgb;
	EMISSION = trail_color.rgb * 2.0;
	ALPHA = alpha * width_fade;
}
