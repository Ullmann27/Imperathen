shader_type canvas_item;
// Hanging red-and-gold legion banner (vexillum) moving in the wind: folds, gold
// borders and fringe, a swallow-tailed hem and the aquila embroidered in gold.

uniform sampler2D emblem : filter_linear_mipmap, hint_default_transparent;
uniform float clock = -1.0;
uniform float wind = 1.0;
uniform float phase = 0.0;
uniform float light = 1.0;
uniform vec4 cloth : source_color = vec4(0.55, 0.05, 0.05, 1.0);
uniform vec4 trim : source_color = vec4(0.92, 0.70, 0.30, 1.0);
// Emblem placement in banner UV: x, y, width, height (set by the script to keep
// the aquila's aspect ratio).
uniform vec4 emblem_rect = vec4(0.12, 0.3, 0.76, 0.2);

void fragment() {
	float t = (clock < 0.0 ? TIME : clock) + phase;
	vec2 uv = UV;
	float hang = uv.y * uv.y;
	float sway = sin(t * 1.3 + uv.y * 3.2) * 0.035 + sin(t * 2.7 + uv.y * 7.0) * 0.012;
	uv.x += sway * hang * wind * 1.4;
	float ripple = sin(uv.x * 15.0 + t * 2.2 * wind + sin(uv.y * 4.0 - t * 1.4) * 1.8);
	float folds = 0.78 + 0.22 * ripple * (0.35 + 0.65 * uv.y);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0);
	// Swallow-tail hem with a short fringe.
	float notch = 0.9 + abs(uv.x - 0.5) * 0.16;
	float hem = smoothstep(notch + 0.004, notch - 0.004, uv.y);
	vec3 col = cloth.rgb * folds;
	float border = step(uv.x, 0.07) + step(0.93, uv.x) + step(uv.y, 0.06);
	float inner = (step(0.1, uv.x) * step(uv.x, 0.115) + step(0.885, uv.x) * step(uv.x, 0.9)) * step(0.09, uv.y);
	inner += step(0.09, uv.y) * step(uv.y, 0.1) * step(0.1, uv.x) * step(uv.x, 0.9);
	col = mix(col, trim.rgb * (0.65 + 0.45 * folds), clamp(border + inner, 0.0, 1.0));
	vec2 e_uv = (uv - emblem_rect.xy) / emblem_rect.zw;
	vec4 mark = texture(emblem, e_uv);
	float in_mark = step(0.0, e_uv.x) * step(e_uv.x, 1.0) * step(0.0, e_uv.y) * step(e_uv.y, 1.0);
	col = mix(col, trim.rgb * (0.7 + 0.5 * folds) * (0.75 + 0.35 * mark.r), mark.a * in_mark * 0.95);
	float fringe = smoothstep(notch - 0.05, notch - 0.03, uv.y) * hem;
	col = mix(col, trim.rgb * (0.55 + 0.3 * sin(uv.x * 160.0)), fringe);
	col *= light;
	COLOR = vec4(col, hem * inside * COLOR.a);
}
