shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.12, 0.42, 0.5, 1.0);
uniform float phase = 0.0;
void fragment() {
 vec2 p = UV - 0.5;
 float haze = exp(-length(p * vec2(1.2, 2.5) - vec2(0.15, 0.08)) * 4.0);
 float band = pow(max(0.0, 1.0 - abs(p.y + sin(p.x * 5.0 + phase) * 0.08) * 5.0), 3.0);
 float vignette = smoothstep(0.8, 0.1, length(p));
 COLOR = vec4(tint.rgb * (haze * 0.3 + band * 0.055), vignette * 0.6);
}
