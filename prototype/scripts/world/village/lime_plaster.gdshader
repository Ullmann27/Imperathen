shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Lime plaster over rubble for Valdora's houses. UVs are box-projected metres.
// Rising damp and splash dirt follow world height above the village ground;
// a world-space macro term and a per-house offset break up tiling.
uniform vec3 tint : source_color = vec3(.89,.80,.69);
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float metres_per_tile = 2.0;
uniform float normal_depth = 1.0;
uniform float ground_height = 0.0;
uniform float damp_top = 1.10;
uniform vec3 damp_color : source_color = vec3(.70,.64,.55);
uniform float detail = 1.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (detail < .5) {
		ALBEDO = tint * .80;
		ROUGHNESS = .92;
	} else {
		vec2 shift = fract(NODE_POSITION_WORLD.xz * vec2(.137, .291));
		vec2 uv = UV / metres_per_tile + shift;
		vec3 paint = texture(albedo_map, uv).rgb;
		vec3 mask = texture(mask_map, uv).rgb;
		float macro = texture(mask_map, vec2(world_pos.x + world_pos.z, world_pos.y) * .085 + shift).b;
		float h = world_pos.y - ground_height;
		float jag = (macro - .5) * .55 + (mask.b - .5) * .25;
		// Faces turned toward the house centre are indoors: no rain splash, less damp.
		vec3 world_normal = mat3(INV_VIEW_MATRIX) * NORMAL;
		float indoor = step(0.0, dot(world_normal.xz, NODE_POSITION_WORLD.xz - world_pos.xz));
		float damp = (1.0 - smoothstep(.42, damp_top, h + jag)) * mix(1.0, .35, indoor);
		float splash = (1.0 - smoothstep(.36, .66, h + jag * .35)) * (1.0 - indoor);
		// The tile carries a few spalled patches down to the rubble. Repeated on
		// every tile they read as a pattern, so they only stay where the wall is
		// weathered (macro patches outdoors) and are plastered over elsewhere
		// and in every lived-in room.
		float spalled = 1.0 - smoothstep(.47, .56, dot(paint, vec3(.2126, .7152, .0722)));
		float mended = spalled * mix(1.0 - smoothstep(.56, .66, macro), 1.0, indoor);
		paint = mix(paint, vec3(.80, .755, .665) * (.97 + .06 * mask.b), mended);
		vec3 base = paint * tint * (.90 + .20 * macro);
		base = mix(base, base * damp_color, damp * .85);
		base = mix(base, base * vec3(.66, .58, .47), splash * .55);
		ALBEDO = base;
		ROUGHNESS = clamp(mask.r + damp * .04 - splash * .03, .5, 1.0);
		// Ambient occlusion where the wall meets the ground or floor, and under
		// the eaves/ridge indoors: the contact darkening Compatibility has no
		// screen-space pass for.
		float contact = mix(.55, 1.0, smoothstep(.0, .55, h - mix(0.0, .39, indoor)));
		float ceiling = mix(1.0, mix(.7, 1.0, smoothstep(3.6, 2.6, h)), indoor);
		AO = mix(1.0, mask.g, .85 * (1.0 - mended)) * contact * ceiling;
		AO_LIGHT_AFFECT = .2;
		NORMAL_MAP = texture(normal_map, uv).rgb;
		NORMAL_MAP_DEPTH = normal_depth * (1.0 - .85 * mended);
	}
}
