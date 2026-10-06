shader_type canvas_item;
// Background dot grid pushed around by shockwaves (Geometry Wars style).
// waves[i] = (x, y, radius, strength) in battlefield coordinates.
uniform vec4 waves[12];
uniform int wave_count = 0;
uniform vec2 origin = vec2(0.0);
uniform float spacing = 24.0;
uniform float time = 0.0;
uniform vec4 dot_color : source_color = vec4(0.15, 0.15, 0.15, 1.0);
uniform vec4 lit_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
varying vec2 world;

void vertex() {
	world = VERTEX + origin;
}

void fragment() {
	vec2 disp = vec2(0.0);
	float light = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= wave_count) {
			break;
		}
		vec4 w = waves[i];
		vec2 d = world - w.xy;
		float dist = length(d);
		float k = max(0.0, 1.0 - abs(dist - w.z) / 70.0);
		k = k * k * (3.0 - 2.0 * k);
		if (dist > 0.001) {
			disp += d / dist * w.w * k;
		}
		light += k * w.w / 26.0;
	}
	disp += vec2(sin(world.y * 0.021 + time * 0.6), cos(world.x * 0.017 + time * 0.5)) * 0.9;
	vec2 cell = abs(mod(world - disp, spacing) - spacing * 0.5);
	float dot_mask = 1.0 - smoothstep(0.7, 1.6, max(cell.x, cell.y));
	float lit = clamp(light, 0.0, 1.0);
	COLOR = vec4(mix(dot_color.rgb, lit_color.rgb, lit), dot_mask * (dot_color.a + lit * 0.5));
}
