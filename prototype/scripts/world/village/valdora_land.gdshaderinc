// GLSL mirror of valdora_land.gd (tracks, brook, fen). Keep both in step:
// tests/village_landscape_test.gd renders this mask and compares it with the
// script. p = world (x, z) in metres.
const float LAND_TRACK_HALF_WIDTH = 2.4;
const float LAND_TRACK_FADE_START = 330.0;
const float LAND_TRACK_REACH = 420.0;
const float LAND_OPEN_WATER_END_Z = 65.0;
const float LAND_FEN_END_Z = 112.0;
const float LAND_END_ROUNDING = 3.5;

float land_lane_x(float z) {
	return .22 * sin(z * .17) + .13 * sin(z * .35);
}

float land_track_distance(vec2 p) {
	float best = 1e6;
	if (p.y < -49.0 && p.y > -LAND_TRACK_REACH) {
		best = min(best, abs(p.x - land_lane_x(p.y) - 2.2 * sin((p.y + 53.0) * .035) * smoothstep(53.0, 67.0, -p.y)));
	}
	if (p.y > 30.0 && p.y < LAND_TRACK_REACH) {
		best = min(best, abs(p.x - land_lane_x(p.y) - 3.0 * sin((p.y - 38.0) * .02) * smoothstep(38.0, 60.0, p.y)));
	}
	if (p.x > 52.0 && p.x < LAND_TRACK_REACH) {
		best = min(best, abs(p.y + 13.0 - 5.0 * sin((p.x - 48.0) * .015) * smoothstep(48.0, 70.0, p.x)) + max(0.0, 56.0 - p.x) * .6);
	}
	if (p.x < -33.0 && p.x > -LAND_TRACK_REACH) {
		best = min(best, abs(p.y - 4.0 - .14 * sin(p.x * .43) - 3.0 * sin((p.x + 33.0) * .03) * smoothstep(33.0, 47.0, -p.x)));
	}
	return best;
}

// 0 untouched ground .. 1 bare trodden earth; grain roughens the edge.
float land_track_wear(vec2 p, float grain) {
	float reach = 1.0 - smoothstep(LAND_TRACK_FADE_START, LAND_TRACK_REACH, max(abs(p.x), abs(p.y)));
	return (1.0 - smoothstep(1.25, LAND_TRACK_HALF_WIDTH, land_track_distance(p) + grain)) * reach;
}

float land_channel_x(float z) {
	float zc = min(z, LAND_OPEN_WATER_END_Z);
	return -28.0 + .52 * sin(zc * .18) + .23 * sin(zc * .46) + max(0.0, z - LAND_OPEN_WATER_END_Z) * .35;
}

float land_water_half_width(float z, float source_z) {
	if (z <= source_z || z >= LAND_FEN_END_Z) {
		return 0.0;
	}
	float width = 3.78 + .18 * sin(min(z, LAND_OPEN_WATER_END_Z) * .56);
	width *= mix(1.0, .22, smoothstep(LAND_OPEN_WATER_END_Z, LAND_FEN_END_Z - LAND_END_ROUNDING, z));
	float head = clamp((z - source_z) / LAND_END_ROUNDING, 0.0, 1.0);
	float tail = clamp((LAND_FEN_END_Z - z) / LAND_END_ROUNDING, 0.0, 1.0);
	return width * sqrt(head * (2.0 - head)) * sqrt(tail * (2.0 - tail));
}

// Lateral distance to the waterline (negative over water).
float land_water_distance(vec2 p, float source_z) {
	if (p.y < source_z - 2.0 || p.y > LAND_FEN_END_Z + 2.0) {
		return 99.0;
	}
	return abs(p.x - land_channel_x(p.y)) - land_water_half_width(p.y, source_z);
}
