shader_type canvas_item;
// Mandelbrot doomsday weapon: the real set, z -> z^2 + c, blooms out of the core
// inside a growing disc and dives toward Seahorse Valley. Monochrome bands with
// an amber boundary glow; the set's interior swallows the battlefield.
uniform vec2 core = vec2(0.5);
uniform vec2 aspect = vec2(1.777, 1.0);
uniform float radius = 0.0;       // reveal radius, in screen-height units
uniform vec2 focus = vec2(-0.5, 0.0); // complex coordinate under the core
uniform float scale = 3.0;        // complex units per screen height
uniform float time = 0.0;
uniform float fade = 1.0;
uniform int max_iter = 96;

void fragment() {
	vec2 d = (SCREEN_UV - core) * aspect;
	float r = length(d);
	float rim = exp(-pow((r - radius) / 0.007, 2.0));
	float inside = 1.0 - smoothstep(radius - 0.004, radius + 0.002, r);
	if (radius <= 0.0 || (inside <= 0.0 && rim < 0.01)) {
		discard;
	}
	vec2 c = focus + vec2(d.x, -d.y) * scale;
	vec2 z = vec2(0.0);
	float n = 0.0;
	float escaped = 0.0;
	for (int i = 0; i < 512; i++) {
		if (i >= max_iter) {
			break;
		}
		z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
		if (dot(z, z) > 256.0) {
			escaped = 1.0;
			break;
		}
		n += 1.0;
	}
	vec3 amber = vec3(1.0, 0.79, 0.3);
	vec4 col;
	if (escaped > 0.5) {
		float mu = n + 1.0 - log2(log(length(z)));
		float k = clamp(mu / float(max_iter), 0.0, 1.0);
		float lum = pow(k, 0.62);
		float band = 0.5 + 0.5 * cos(mu * 0.55 - time * 2.4);
		float v = lum * (0.45 + 0.55 * band);
		vec3 rgb = mix(vec3(v), amber, smoothstep(0.55, 0.95, lum) * 0.75);
		col = vec4(rgb, (0.12 + 0.62 * lum) * inside);
	} else {
		// The set itself: a void with a faint white grain.
		float grain = fract(sin(dot(floor(SCREEN_UV * 900.0), vec2(12.9898, 78.233))) * 43758.5453);
		col = vec4(vec3(0.02 + grain * 0.03), 0.7 * inside);
	}
	col.rgb = mix(col.rgb, amber, rim);
	col.a = max(col.a, rim * 0.9);
	COLOR = vec4(col.rgb, col.a * fade);
}
