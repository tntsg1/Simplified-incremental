shader_type canvas_item;
render_mode blend_add;
// Boss energy layer: drawn over a square around the boss, additive. The flat
// line silhouette stays underneath; this supplies plasma, glow and moving light.
// UV 0..1 across the square; the boss body spans `body` of the square (0.5 = edge).
uniform int kind = 0;          // see BOSS_FX_KIND in battlefield.gd
uniform float time = 0.0;
uniform float flash = 0.0;     // recent hit, 0..1
uniform float hit_age = 9.0;   // seconds since the last heavy hit (shock ring)
uniform float enrage = 0.0;
uniform float spin = 0.0;      // body rotation (dipole axis, tumbling shard)
uniform float heading = 1.5708; // direction of travel, screen radians
uniform float aim = 1.5708;    // direction toward the core
uniform float hurt = 0.0;      // share of its health already lost
uniform float body = 0.3;
uniform float dying = 0.0;
uniform float doppler = 0.0;   // slowed-light strength, 0..1
uniform float approach = 0.0;  // -1 receding from the core .. 1 closing on it     // seconds since it was destroyed (0 = alive)
uniform float strength = 1.0;
const vec3 AMBER = vec3(1.0, 0.79, 0.3);
const vec3 HOT = vec3(1.0, 0.95, 0.85);
const vec3 ICE = vec3(0.85, 0.92, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Voronoi: x = distance to the nearest cell edge, y = cell id hash, z = distance to its seed.
vec3 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 best = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + hash2(i + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				best = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(sqrt(d2) - sqrt(d1), hash(best), sqrt(d1));
}

float ring(float r, float at, float width) {
	return smoothstep(width, 0.0, abs(r - at));
}

// A rocket/engine plume from `root` along `dir`, with standing shock diamonds.
float plume(vec2 c, vec2 root, vec2 dir, float len, float width, float seed) {
	vec2 q = c - root;
	float along = dot(q, dir) / len;
	if (along < 0.0) {
		return 0.0;
	}
	float side = dot(q, vec2(-dir.y, dir.x)) / width;
	float flick = 1.0 + 0.18 * sin(time * 47.0 + seed * 7.0) + 0.1 * sin(time * 31.0 + seed);
	float spread = 1.0 + along * 1.6;
	float turb = fbm(vec2(along * 6.0 - time * 9.0, side * 1.5 + seed));
	float sw = side / spread;
	float core = exp(-sw * sw * 2.5) * exp(-along * 2.4 / flick);
	float diamonds = 0.55 + 0.45 * cos(along * 26.0 - 0.6) * exp(-along * 3.0);
	return core * diamonds * (0.6 + 0.8 * turb);
}

// ------------------------------------------------------------------ star
vec3 star(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	float rn = r / body;
	if (rn < 1.0) {
		// Boiling photosphere: flowing noise, granulation cells, limb-brightened edge.
		vec2 flow = c / body * 2.7 + vec2(time * 0.35, -time * 0.22);
		float boil = fbm(flow + fbm(flow * 1.7 - time * 0.4) * 2.2);
		float gran = cells(c / body * 7.0 + vec2(time * 0.2, 0.0)).x;
		float granules = smoothstep(0.35, 0.8, boil) + smoothstep(0.12, 0.0, gran) * 0.18;
		float limb = smoothstep(0.6, 1.0, rn);
		float lum = 0.08 + 0.55 * granules + 0.35 * limb;
		col = mix(vec3(lum), AMBER * lum, 0.6 + 0.2 * sin(time * 1.3 + boil * 6.0));
		// Sunspots drift across and darken as it is wounded.
		col *= 1.0 - smoothstep(0.62, 0.7, fbm(c / body * 1.6 + time * 0.05)) * (0.4 + 0.4 * hurt);
	}
	// Corona: streamers that stretch out and pulse, brighter when enraged.
	float rays = fbm(vec2(ang * 3.1831 * 2.0, r * 3.0 - time * 0.9));
	float streamers = pow(rays, 3.0) * 1.6;
	float halo = exp(-max(0.0, rn - 1.0) * 3.0);
	float corona = (0.12 * halo + streamers * halo * 0.7) * smoothstep(0.92, 1.05, rn);
	col += AMBER * corona * (1.0 + enrage * 0.8);
	// Looping prominences: bright arcs that lift off the limb and fall back.
	float prom = sin(ang * 5.0 + time * 0.7) * 0.5 + 0.5;
	float lift = body * (1.08 + 0.22 * prom * (0.5 + 0.5 * sin(time * 1.7 + ang * 3.0)));
	col += HOT * ring(r, lift, 0.01) * pow(prom, 6.0) * 0.9;
	// A coronal mass ejection every few seconds: a bright shell racing out.
	float cme = fract(time * 0.28);
	float cme_ang = floor(time * 0.28) * 2.4;
	float lobe = pow(max(0.0, cos(ang - cme_ang)), 6.0);
	col += AMBER * ring(rn, 1.0 + cme * 0.75, 0.05 + cme * 0.05) * lobe * (1.0 - cme) * 1.1;
	return col;
}

// ------------------------------------------------------------------ magnetar
vec3 magnetar(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	float core_r = body * 0.42;
	vec2 d = rot(c, -spin);
	float th = atan(d.y, d.x);
	float rr = max(length(d), 0.0001);
	// Dipole field lines: sin^2(theta) / r is constant along each line; charge flows along them.
	float psi = sin(th) * sin(th) / rr;
	float bands = abs(fract(psi * 0.32 * body / 0.3 - time * 0.5) - 0.5);
	float lines = smoothstep(0.06, 0.0, bands) * smoothstep(body * 1.65, body * 0.5, rr) * smoothstep(core_r * 0.9, core_r * 1.4, rr);
	float flow = 0.5 + 0.5 * sin(th * 12.0 - time * 8.0 * sign(cos(th)));
	col += mix(ICE, AMBER, 0.35) * lines * (0.35 + 0.45 * flow);
	// Twin polar beams sweeping with the spin: narrow, white-hot, flickering.
	float beam = pow(max(0.0, abs(cos(th))), 160.0) * smoothstep(body * 1.65, 0.0, rr);
	col += vec3(1.0) * beam * (0.5 + 0.15 * sin(time * 40.0)) * (1.0 + enrage);
	// The neutron star: blinding core with crawling surface lightning.
	if (rr < core_r) {
		float crackle = fbm(d / body * 12.0 + time * 2.0);
		float bolt = smoothstep(0.55, 0.62, crackle) * (1.0 - smoothstep(0.62, 0.7, crackle));
		col += vec3(0.12 + 0.3 * (1.0 - rr / core_r)) + AMBER * bolt * 1.2;
	}
	col += ICE * exp(-max(0.0, rr - core_r) / body * 18.0) * 0.22;
	// Starquake ripples racing out of the crust.
	float quake = fract(time * 0.6);
	col += AMBER * ring(rr, core_r + quake * body * 1.3, 0.012) * (1.0 - quake) * 1.2;
	return col;
}

// ------------------------------------------------------------------ CHIRON: burning entry
vec3 asteroid(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	vec2 fwd = vec2(cos(heading), sin(heading));
	vec2 lc = rot(c, -time * 0.3);
	float la = atan(lc.y, lc.x);
	float lump = body * (1.0 + 0.08 * sin(la * 3.0 + 1.3) + 0.05 * sin(la * 7.0 + 0.4));
	float inside = step(r, lump);
	if (r < lump) {
		float rn = r / lump;
		vec3 n = vec3(c / lump, sqrt(max(0.0, 1.0 - rn * rn)));
		float diff = max(0.0, dot(n, normalize(vec3(fwd, 0.5))));
		float rock = fbm(lc / body * 3.0);
		col = vec3(0.05 + 0.1 * rock) * (0.4 + 0.9 * diff);
		// Lava veins: cell edges that glow and widen as it takes damage.
		vec3 v = cells(lc / body * 2.6);
		float vein = smoothstep(0.06 + 0.1 * hurt, 0.0, v.x) * (0.55 + 0.45 * sin(time * 3.0 + v.y * 20.0));
		col += mix(AMBER, HOT, vein) * vein * 1.3;
		// The face it ploughs through the air with is white-hot.
		float front = max(0.0, dot(normalize(c + 0.00001), fwd));
		col += mix(AMBER, HOT, front) * pow(front, 3.0) * smoothstep(0.45, 1.0, rn) * 1.4;
	}
	// The fire tail: a turbulent plume streaming behind, licking past the body.
	vec2 back = -fwd;
	float along = dot(c, back) / body;
	float side = dot(c, vec2(-back.y, back.x)) / body;
	float flame = fbm(vec2(along * 1.4 - time * 4.0, side * 2.2 + time * 0.4));
	float width = 0.9 + max(0.0, along) * 0.35 + (flame - 0.5) * 0.7;
	float shape = smoothstep(width, width * 0.15, abs(side)) * exp(-max(0.0, along) * 0.6) * smoothstep(-0.4, 0.7, along);
	float heat = exp(-max(0.0, along) * 1.2);
	vec3 fire = mix(AMBER * 0.85, HOT, heat * smoothstep(0.4, 0.9, flame));
	col += fire * shape * (0.3 + 0.9 * flame) * mix(1.0, 0.15, inside);
	// Bow shock: a bright arc pushed ahead of it.
	float bow = dot(c, fwd) / body;
	float bow_shape = ring(length(c - fwd * body * 0.35) / body, 1.05, 0.06) * smoothstep(0.1, 0.9, bow);
	col += HOT * bow_shape * (0.5 + 0.3 * sin(time * 20.0));
	return col;
}

// ------------------------------------------------------------------ NOMAD: rogue planet
vec3 planet(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	float rn = r / body;
	vec2 lit = vec2(cos(aim), sin(aim));
	if (rn < 1.0) {
		vec3 n = vec3(c / body, sqrt(1.0 - rn * rn));
		float lat = n.y;
		float lon = atan(n.x, n.z) + time * 0.12;
		// Cloud decks shearing past each other at different speeds.
		float shear = time * 0.18 * (1.0 + sin(lat * 9.0));
		float band = fbm(vec2(lon * 2.2 + shear, lat * 7.0 + fbm(vec2(lon * 3.0 - time * 0.1, lat * 12.0)) * 0.9));
		// A great storm eye rotating on the day side.
		vec2 eye = vec2(lon - 0.6, lat + 0.25);
		float eye_d = length(eye * vec2(0.8, 1.6));
		float swirl = sin(atan(eye.y, eye.x) * 2.0 + eye_d * 30.0 - time * 3.0);
		band += smoothstep(0.35, 0.0, eye_d) * swirl * 0.25;
		float diff = dot(n, normalize(vec3(lit, 0.45)));
		float term = smoothstep(-0.1, 0.3, diff);
		col = mix(vec3(0.8), AMBER, 0.3 + 0.4 * band) * (0.06 + 0.55 * band) * (0.08 + 0.92 * term);
		// Lightning flickering under the night-side clouds.
		float strike = step(0.93, hash(vec2(floor(time * 9.0), 7.0)));
		vec2 at = vec2(hash(vec2(floor(time * 9.0), 1.0)), hash(vec2(floor(time * 9.0), 2.0))) * 1.2 - 0.6;
		col += ICE * strike * exp(-length(c / body - at) * 9.0) * (1.0 - term) * 1.2;
	}
	// Atmosphere: a rim of scattered light, thickest on the lit side.
	float lit_side = 0.5 + 0.5 * dot(normalize(c + 0.00001), lit);
	col += mix(ICE, AMBER, 0.3) * exp(-abs(rn - 1.0) * 22.0) * (0.25 + 0.6 * lit_side);
	// Aurora curtains hanging over both poles.
	float pole = pow(abs(sin(ang)), 6.0);
	float curtain = fbm(vec2(ang * 9.0 + time * 0.7, time * 0.35));
	float h = smoothstep(1.0, 1.06, rn) * smoothstep(1.32 + 0.12 * curtain, 1.04, rn);
	col += mix(ICE, AMBER, curtain) * pole * h * curtain * 1.3;
	// Tidal ripples, stretched along the pull of the core.
	vec2 tc = vec2(dot(c, lit), dot(c, vec2(-lit.y, lit.x))) / body;
	float er = length(vec2(tc.x / 1.3, tc.y));
	for (int i = 0; i < 3; i++) {
		float k = fract(time * 0.32 + float(i) / 3.0);
		col += vec3(0.85) * ring(er, 1.15 + k * 0.6, 0.02) * (1.0 - k) * 0.45;
	}
	// Captured moonlets on an inclined orbit, hidden when they pass behind.
	for (int i = 0; i < 4; i++) {
		float a = time * 0.35 + float(i) * TAU / 4.0;
		vec2 m = vec2(cos(a) * 1.6, sin(a) * 0.45) * body;
		float behind = step(sin(a), 0.0) * step(length(m), body);
		float glow = exp(-length(c - m) / body * 40.0);
		col += mix(HOT, AMBER, float(i) * 0.25) * glow * (1.0 - behind) * 1.1;
	}
	return col;
}

// ------------------------------------------------------------------ CERES: pushed by engines
vec3 dwarf(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	float rn = r / body;
	if (rn < 1.0) {
		vec3 n = vec3(c / body, sqrt(1.0 - rn * rn));
		float diff = max(0.0, dot(n, normalize(vec3(0.5, 0.6, 0.7))));
		vec2 sp = rot(c / body, time * 0.08);
		vec3 crater = cells(sp * 3.2);
		float rim = smoothstep(0.08, 0.0, abs(crater.z - 0.3)) * 0.5;
		float bowl = smoothstep(0.3, 0.0, crater.z) * 0.35;
		float dust = fbm(sp * 4.0);
		col = vec3(0.07 + 0.1 * dust + rim * 0.2 - bowl * 0.08) * (0.25 + 0.9 * diff);
		// The bright salt spot of Occator, glinting as it rotates by.
		col += HOT * exp(-length(sp - vec2(0.2, -0.3)) * 14.0) * 0.6;
		// Stress fractures spreading from the thruster mounts as it is wounded.
		vec3 crack = cells(sp * 1.6 + 3.0);
		col += AMBER * smoothstep(0.03 * hurt, 0.0, crack.x) * hurt * 1.4;
	}
	// Three thruster rigs at its back burn with shock diamonds.
	for (int j = 0; j < 3; j++) {
		float a = -1.5708 + float(j - 1) * 0.62;
		vec2 dir = vec2(cos(a), sin(a));
		float p = plume(c, dir * body * 1.42, dir, body * 1.3, body * 0.13, float(j));
		col += mix(AMBER, HOT, smoothstep(0.3, 1.0, p)) * p * (1.4 + enrage * 0.6);
		col += AMBER * exp(-length(c - dir * body * 1.42) / body * 16.0) * 0.6;
	}
	col += ICE * exp(-abs(rn - 1.0) * 30.0) * 0.18;
	return col;
}

// ------------------------------------------------------------------ LEVIATHAN: shielded mothership
float hexdist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.732))), p.x);
}

vec3 mothership(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	float rn = r / body;
	// Energy veins from the reactor to each hull corner, pulsing outward.
	float sector = mod(ang + 1.5708 + TAU / 10.0, TAU / 5.0) - TAU / 10.0;
	float spoke = smoothstep(0.035, 0.0, abs(sin(sector)) * rn) * step(rn, 0.95);
	float pulse = pow(0.5 + 0.5 * sin(rn * 14.0 - time * 7.0), 4.0);
	col += AMBER * spoke * (0.45 + 1.4 * pulse);
	// Hull plating lit from within, panels flickering in sequence.
	vec3 plate = cells(rot(c / body, -time * 0.4) * 5.0);
	float panel = step(0.6, fract(plate.y * 5.0 + time * 0.8));
	col += mix(AMBER, ICE, plate.y) * (smoothstep(0.05, 0.0, plate.x) * 0.25 + panel * 0.08) * smoothstep(0.92, 0.8, rn);
	// The reactor heart.
	float beat = 0.5 + 0.5 * pow(abs(sin(time * 3.2)), 8.0);
	col += mix(AMBER, HOT, beat) * exp(-rn * 9.0) * (0.8 + beat);
	col += AMBER * ring(rn, 0.22 + beat * 0.04, 0.03) * 0.8;
	// The hex shield: a bubble of cells that shimmer as a scan wave crosses them.
	float shield_r = 1.45;
	if (rn < shield_r + 0.05) {
		vec2 uv = c / body * 4.2;
		vec2 grid = vec2(1.0, 1.732);
		vec2 ga = mod(uv, grid) - grid * 0.5;
		vec2 gb = mod(uv - grid * 0.5, grid) - grid * 0.5;
		vec2 gv = mix(gb, ga, step(dot(ga, ga), dot(gb, gb)));
		vec2 id = uv - gv;
		float edge = 0.5 - hexdist(gv);
		float shell = pow(clamp(rn / shield_r, 0.0, 1.0), 6.0);
		float scan = pow(0.5 + 0.5 * sin(dot(id, vec2(0.6, 0.8)) * 0.9 - time * 3.0), 6.0);
		float lines = smoothstep(0.06, 0.0, edge);
		// Hits ring out across the shield from the top.
		float ripple = ring(length(c / body - vec2(0.0, -shield_r)), hit_age * 3.5, 0.25) * exp(-hit_age * 2.0);
		float lit = shell * (0.35 + 1.2 * scan + 2.0 * ripple + 0.8 * flash) + scan * 0.12;
		float inside = smoothstep(shield_r + 0.05, shield_r - 0.02, rn);
		col += mix(ICE, AMBER, scan) * lines * lit * inside;
		col += mix(ICE, AMBER, scan) * pow(clamp(rn / shield_r, 0.0, 1.0), 10.0) * inside * 0.3;
		col += ICE * ring(rn, shield_r, 0.03) * (0.6 + 0.4 * flash);
	}
	// Three main engines.
	for (int j = 0; j < 3; j++) {
		vec2 root = vec2(float(j - 1) * 0.45, -0.7) * body;
		float p = plume(c, root, vec2(0.0, -1.0), body * 1.1, body * 0.1, float(j) + 4.0);
		col += mix(AMBER, HOT, smoothstep(0.3, 1.0, p)) * p * 1.3;
	}
	// Hangar lights chasing along the keel.
	for (int j = 0; j < 8; j++) {
		vec2 q = vec2((float(j) - 3.5) * 0.2, 0.62) * body;
		float on = step(0.5, fract(time * 3.0 + float(j) * 0.37));
		col += AMBER * exp(-length(c - q) / body * 50.0) * on * 1.2;
	}
	return col;
}

// ------------------------------------------------------------------ 'OUMUAMUA: tumbling shard
vec3 cigar(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	vec2 local = rot(c, -spin);
	vec2 q = local / (body * vec2(1.55, 0.3));
	float d = dot(q, q);
	if (d < 1.0) {
		vec3 n = normalize(vec3(q.x / 1.55, q.y / 0.3, sqrt(1.0 - d)));
		// The light falls from a fixed direction, so the sheen slides as it tumbles.
		vec3 light = normalize(vec3(rot(vec2(-0.6, -0.6), -spin), 0.55));
		float diff = max(0.0, dot(n, light));
		float spec = pow(max(0.0, dot(reflect(-light, n), vec3(0.0, 0.0, 1.0))), 40.0);
		float streak = fbm(vec2(q.x * 3.0, q.y * 18.0));
		col = vec3(0.05 + 0.08 * streak) * (0.3 + diff) + HOT * spec * 1.6;
		col += AMBER * pow(1.0 - n.z, 3.0) * 0.6;
	}
	// The glint: once per tumble it catches the light in a four-point flare.
	float glint = pow(max(0.0, sin(time * 1.1)), 12.0);
	vec2 gp = rot(vec2(body * 1.1, 0.0), spin);
	vec2 gd = c - gp;
	float flare = exp(-length(gd) / body * 10.0) + (exp(-abs(gd.x) / body * 90.0) + exp(-abs(gd.y) / body * 90.0)) * exp(-length(gd) / body * 2.0);
	col += HOT * flare * glint * 1.5;
	// Silent probe cones sweeping the field.
	for (int j = 0; j < 2; j++) {
		float a = time * (0.7 + float(j) * 0.4) + float(j) * 3.14159;
		float off = abs(mod(ang - a + 3.14159, TAU) - 3.14159);
		float cone = smoothstep(0.12, 0.0, off) * smoothstep(body * 3.5, body * 0.4, r);
		float tick = 0.5 + 0.5 * sin(r / body * 30.0 - time * 12.0);
		col += vec3(0.9) * cone * (0.06 + 0.1 * tick);
	}
	// Light bending round it: a faint lensing halo that breathes.
	col += ICE * ring(length(local / vec2(1.55, 0.45)) / body, 1.35 + 0.05 * sin(time * 2.0), 0.08) * 0.18;
	return col;
}

// ------------------------------------------------------------------ CATHEDRAL: supercluster rose window
vec3 cathedral(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	float rn = r / body;
	// Five-fold mirrored stained glass, slowly turning.
	float seg = TAU / 10.0;
	float fa = mod(ang + time * 0.12 + 1.5708, seg * 2.0);
	fa = abs(fa - seg);
	vec2 k = vec2(cos(fa), sin(fa)) * rn;
	vec3 glass = cells(k * 3.4 + vec2(0.0, time * 0.15));
	float lead = smoothstep(0.08, 0.0, glass.x);
	float pane = 0.15 + 0.85 * glass.y;
	float shimmer = 0.6 + 0.4 * sin(time * 2.0 + glass.y * 20.0);
	float window = smoothstep(0.95, 0.85, rn);
	col += mix(AMBER, HOT, glass.y) * pane * shimmer * window * 0.32;
	col += HOT * lead * window * 0.5;
	col += HOT * exp(-rn * 5.0) * 0.8;
	// Counter-rotating halos of light, like vaulting.
	for (int j = 0; j < 3; j++) {
		float rr = 1.25 + float(j) * 0.28;
		float dir = mod(float(j), 2.0) * 2.0 - 1.0;
		float arches = pow(0.5 + 0.5 * sin(ang * 3.0 + time * 0.4 * dir + float(j)), 3.0);
		col += mix(AMBER, ICE, float(j) * 0.3) * ring(rn, rr, 0.025) * arches * (0.55 - float(j) * 0.12);
	}
	// God rays from the five spires, drifting with dust.
	for (int j = 0; j < 5; j++) {
		float a = -1.5708 + float(j - 2) * 0.45;
		vec2 dir = vec2(cos(a), sin(a));
		vec2 root = dir * body * 1.4;
		vec2 q = c - root;
		float along = dot(q, dir) / body;
		float side = abs(dot(q, vec2(-dir.y, dir.x))) / body;
		float beam = smoothstep(0.08 + along * 0.06, 0.0, side) * step(0.0, along) * exp(-along * 0.8);
		float dust = 0.6 + 0.4 * fbm(vec2(along * 3.0 - time * 1.5, side * 10.0 + float(j)));
		col += HOT * beam * dust * (0.35 + 0.15 * sin(time * 4.0 + float(j)));
	}
	// A halo of drone lights orbiting.
	for (int j = 0; j < 12; j++) {
		float a = time * 0.6 + float(j) * TAU / 12.0;
		col += AMBER * exp(-length(c / body - vec2(cos(a), sin(a)) * 2.1) * 30.0) * 0.9;
	}
	return col;
}

// ------------------------------------------------------------------ THE SILENCE: the void that eats light
vec3 rift(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	float rn = r / body;
	float horizon = 0.45;
	// Spiral arms of light falling inward, faster as they get closer.
	float s = ang * 3.0 + log(max(rn, 0.01)) * 7.0 + time * 1.6;
	float arms = pow(0.5 + 0.5 * sin(s), 6.0);
	float grain = fbm(vec2(ang * 4.0 + time * 0.5, log(max(rn, 0.01)) * 6.0 + time * 2.0));
	float disk = smoothstep(horizon, horizon + 0.12, rn) * exp(-max(0.0, rn - 0.6) * 1.6);
	col += mix(AMBER, HOT, arms) * arms * disk * (0.35 + 0.9 * grain);
	// The photon ring: a razor-thin circle of light that cannot get away.
	col += HOT * ring(rn, horizon + 0.02, 0.02) * (1.3 + 0.4 * sin(time * 5.0));
	col += AMBER * exp(-abs(rn - horizon - 0.02) * 25.0) * 0.35;
	// Cracks in space: jagged fractures flickering outward.
	vec3 v = cells(vec2(ang * 2.5, log(max(rn, 0.01)) * 2.0 - time * 0.1));
	float crack = smoothstep(0.04, 0.0, v.x) * smoothstep(horizon + 0.1, 0.9, rn) * smoothstep(2.6, 1.4, rn);
	float live = step(0.55 - 0.3 * hurt, fract(v.y * 7.0 + time * 0.25));
	col += ICE * crack * live * (0.6 + 0.4 * sin(time * 30.0 + v.y * 50.0));
	// Starlight streaking inward from far away.
	for (int j = 0; j < 24; j++) {
		float fj = float(j);
		float k = fract(time * 0.45 + fj * 0.137);
		float a = fj * 2.399 + k * 1.4;
		float dist = 2.6 - 2.1 * k * k;
		vec2 p = vec2(cos(a), sin(a)) * dist;
		vec2 tdir = vec2(cos(a), sin(a));
		vec2 q = c / body - p;
		float along = dot(q, tdir);
		float side = abs(dot(q, vec2(-tdir.y, tdir.x)));
		float streak = smoothstep(0.02, 0.0, side) * smoothstep(0.0, 0.05, along) * smoothstep(0.25 * k + 0.02, 0.0, along);
		col += HOT * streak * k * 0.9;
	}
	col *= step(horizon, rn);
	return col;
}

// ------------------------------------------------------------------ THE OTHER BRANE
vec3 brane(vec2 c, float r, float ang) {
	vec3 col = vec3(0.0);
	float rn = r / body;
	float skin = 1.25 * (1.0 + 0.035 * sin(4.0 * ang) * cos(time * 1.7) + 0.02 * sin(7.0 * ang + 1.0) * cos(time * 1.1));
	// Inside: its own cosmic web, filaments and nodes, turning the other way.
	if (rn < skin) {
		vec2 w = rot(c / body, -time * 0.08) * 2.6;
		vec3 web = cells(w);
		float filament = smoothstep(0.07, 0.0, web.x);
		float node = exp(-web.z * 14.0);
		float twinkle = 0.6 + 0.4 * sin(time * 3.0 + web.y * 30.0);
		col += mix(ICE, AMBER, web.y) * (filament * 0.22 + node * 0.8 * twinkle) * smoothstep(skin, skin - 0.2, rn);
		col += AMBER * exp(-rn * 7.0) * 0.9;
	}
	// The skin: thin-film fringes swirling round the membrane.
	float film = fbm(vec2(ang * 2.0 + time * 0.3, time * 0.2)) * 6.0;
	float fringe = 0.5 + 0.5 * sin(film * 3.0 + ang * 5.0 - time * 1.5);
	float shell = exp(-abs(rn - skin) * 26.0);
	col += mix(ICE, AMBER, fringe) * shell * (0.25 + 0.6 * fringe);
	// Where it presses against our brane: interference fringes racing toward the core.
	vec2 dir = vec2(cos(aim), sin(aim));
	vec2 contact = dir * skin;
	vec2 q = c / body - contact;
	float qd = length(q);
	float facing = smoothstep(-0.2, 0.6, dot(normalize(q + 0.0001), dir));
	float waves = pow(0.5 + 0.5 * cos(qd * 22.0 - time * 7.0), 3.0) * exp(-qd * 1.3) * facing;
	col += mix(HOT, AMBER, 0.5 + 0.5 * sin(qd * 11.0)) * waves * 0.5;
	col += HOT * exp(-qd * 18.0) * (0.9 + 0.3 * sin(time * 6.0));
	return col;
}

vec3 aura(vec2 c, float r, float ang) {
	float n = fbm(vec2(ang * 2.0, r * 4.0 - time * 0.6));
	float halo = exp(-abs(r - body) * 9.0);
	return mix(vec3(0.9), AMBER, 0.4) * halo * (0.35 + 0.6 * n);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c);
	float ang = atan(c.y, c.x);
	vec3 col;
	if (kind == 0) {
		col = star(c, r, ang);
	} else if (kind == 1) {
		col = magnetar(c, r, ang);
	} else if (kind == 3) {
		col = asteroid(c, r, ang);
	} else if (kind == 4) {
		col = planet(c, r, ang);
	} else if (kind == 5) {
		col = dwarf(c, r, ang);
	} else if (kind == 6) {
		col = mothership(c, r, ang);
	} else if (kind == 7) {
		col = cigar(c, r, ang);
	} else if (kind == 8) {
		col = cathedral(c, r, ang);
	} else if (kind == 9) {
		col = rift(c, r, ang);
	} else if (kind == 10) {
		col = brane(c, r, ang);
	} else {
		col = aura(c, r, ang);
	}
	// Enraged: everything runs hotter and pulses.
	col *= 1.0 + enrage * (0.25 + 0.2 * sin(time * 6.0));
	// Slowed light: closing in turns it blue, falling away red, and as it turns
	// one limb comes toward us while the other recedes.
	if (doppler > 0.0) {
		float lum = dot(col, vec3(0.3, 0.5, 0.2));
		float limb = clamp(rot(c, -heading).y / body, -1.4, 1.4) * 0.55;
		float s = clamp(approach * 0.55 + limb * 1.3, -1.0, 1.0);
		vec3 shift = mix(vec3(1.0, 0.42, 0.33), vec3(0.44, 0.72, 1.0), step(0.0, s));
		col = mix(col, shift * lum * 1.7, clamp(abs(s) * 1.4, 0.0, 1.0) * doppler * 0.95);
	}
	// Hits: a soft bloom on the body and a shock ring rolling off it.
	col += HOT * flash * exp(-r / body * 3.0) * 0.12;
	col += HOT * ring(r / body, 1.0 + hit_age * 2.6, 0.05 + hit_age * 0.1) * exp(-hit_age * 5.0) * 0.5;
	// Destroyed: the body flares white, ruptures into rays and rings out twice.
	if (dying > 0.0) {
		float k = dying;
		float rn = r / body;
		col *= (1.0 + k * 8.0) * (1.0 - smoothstep(0.1, 0.5, k));
		float rays = pow(0.5 + 0.5 * sin(ang * 13.0 + fbm(vec2(ang * 3.0, 1.0)) * 7.0), 10.0);
		col += HOT * rays * smoothstep(0.6 + k * 4.5, 0.0, rn) * (1.0 - smoothstep(0.35, 1.4, k)) * 1.3;
		col += HOT * exp(-rn * (2.0 + k * 10.0)) * (1.0 - smoothstep(0.0, 0.7, k)) * 2.0;
		col += HOT * ring(rn, 1.0 + k * 5.5, 0.06 + k * 0.25) * (1.0 - smoothstep(0.2, 1.5, k)) * 1.4;
		col += AMBER * ring(rn, 0.8 + k * 3.2, 0.1 + k * 0.35) * (1.0 - smoothstep(0.3, 1.7, k)) * 1.1;
		float debris = step(0.86, hash(floor(vec2(ang * 30.0, rn * 2.0 - k * 6.0))));
		col += AMBER * debris * ring(rn, 0.5 + k * 4.0, 0.4) * (1.0 - smoothstep(0.4, 1.6, k)) * 0.8;
	}
	// Fade to nothing well before the square's edge.
	col *= smoothstep(0.5, 0.38, r) * strength;
	COLOR = vec4(col, 1.0);
}
