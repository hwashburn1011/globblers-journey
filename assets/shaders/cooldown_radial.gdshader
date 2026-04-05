shader_type canvas_item;
// Radial cooldown overlay — sweeps clockwise from 12 o'clock.
// cooldown_percent: 0.0 = fully on cooldown (full overlay), 1.0 = ready (no overlay).

uniform float cooldown_percent : hint_range(0.0, 1.0) = 1.0;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.65);
uniform bool animate = true;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	// Angle from top (12 o'clock), clockwise: atan2(x, -y) maps top=0, CW positive
	float angle = atan(uv.x, -uv.y);
	// Normalize to 0..1
	float norm_angle = (angle / TAU) + 0.5;

	// The "ready" portion sweeps CW from top. If cooldown_percent=0.7, top 70% is clear.
	float threshold = cooldown_percent;

	if (norm_angle > threshold && threshold < 0.999) {
		COLOR = overlay_color;
	} else {
		COLOR = vec4(0.0);
	}
}
