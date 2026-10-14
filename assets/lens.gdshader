shader_type canvas_item;
// Gravitational lens riding with the photoid: space around the massive particle
// is pulled toward it, bending the battlefield into a ring around a dark core.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 center = vec2(0.5);
uniform float radius = 0.1;
uniform float strength = 0.0;
uniform vec2 aspect = vec2(1.777, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = (uv - center) * aspect;
	float r = length(d);
	vec3 col = texture(screen_tex, uv).rgb;
	if (r < radius && strength > 0.0) {
		float k = 1.0 - r / radius;
		// Sample from farther out: the image is stretched around the mass.
		vec2 dir = d / max(r, 1e-5);
		float bend = strength * radius * k * k * 0.9;
		vec2 src = uv + dir / aspect * bend;
		col = texture(screen_tex, src).rgb;
		// Einstein ring and a light-swallowing core.
		float ring = exp(-pow((r / radius - 0.42) / 0.05, 2.0));
		col += vec3(ring * 0.45 * strength);
		col *= 1.0 - smoothstep(0.16, 0.0, r / radius) * 0.85 * strength;
	}
	COLOR = vec4(col, 1.0);
}
