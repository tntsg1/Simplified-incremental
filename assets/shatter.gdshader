shader_type canvas_item;
// Structural collapse for the rewritten-pi strike: the rendered frame cracks
// into Voronoi shards that drift apart, tilt and fall, with bright fracture
// lines and a void showing through the gaps, before the frame reassembles.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float crack = 0.0;
uniform float progress = 0.0;
uniform float settle = 0.0;
uniform vec2 center = vec2(0.5);
uniform vec2 aspect = vec2(1.777, 1.0);
uniform vec2 seeds[20];

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = uv * aspect;
	float best = 1e9;
	float second = 1e9;
	int bi = 0;
	for (int i = 0; i < 20; i++) {
		float d = distance(p, seeds[i] * aspect);
		if (d < best) {
			second = best;
			best = d;
			bi = i;
		} else if (d < second) {
			second = d;
		}
	}
	vec2 s = seeds[bi];
	float h1 = fract(float(bi) * 0.6180339);
	float h2 = fract(float(bi) * 0.4142135 + 0.3);
	vec2 away = normalize((s - center) * aspect + vec2(0.0001)) / aspect;
	float k = progress;
	vec2 off = away * k * (0.05 + 0.09 * h1) + vec2(0.0, k * k * (0.08 + 0.14 * h2));
	float ang = (h2 - 0.5) * 1.6 * k;
	vec2 rel = (uv - s - off) * aspect;
	rel = vec2(cos(ang) * rel.x - sin(ang) * rel.y, sin(ang) * rel.x + cos(ang) * rel.y);
	vec2 src = s + rel / aspect;
	vec3 shard = texture(screen_tex, clamp(src, vec2(0.0), vec2(1.0))).rgb;
	// Each shard catches the light differently as it tilts.
	shard *= 1.0 + (h1 - 0.5) * 0.5 * k;
	float gap = second - best;
	float edge = 1.0 - smoothstep(0.0, 0.003 + 0.02 * k, gap);
	vec3 col = mix(shard, vec3(1.0), edge * crack * (1.0 - k * 0.6));
	col = mix(col, vec3(0.02), edge * k);
	vec3 base = texture(screen_tex, uv).rgb;
	COLOR = vec4(mix(col, base, settle), 1.0);
}
