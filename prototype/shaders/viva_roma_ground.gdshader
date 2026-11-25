shader_type spatial;
render_mode world_vertex_coords, diffuse_burley, specular_schlick_ggx;

// World-space detail: no 1400 m UV stretching, no displacement or physics change.
uniform float detail_strength : hint_range(0.0,1.0) = 1.0;
varying vec2 terrain_xz;

float hash21(vec2 p) {
    p = fract(p * vec2(0.1031, 0.11369));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 w = f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),w.x),
               mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0)),w.x),w.y);
}
void vertex() { terrain_xz = VERTEX.xz; }
void fragment() {
    vec2 p = terrain_xz;
    float macro = noise2(p*0.045);
    float patch = noise2(p*0.30 + vec2(23.0,11.0));
    float soil = noise2(p*2.2);
    float distance_fade = 1.0-smoothstep(12.0,65.0,length(VERTEX));
    float micro = noise2(p*18.0);
    float scrub = smoothstep(0.36,0.76,macro*0.62+patch*0.38);
    vec3 dust = mix(vec3(0.23,0.17,0.105),vec3(0.40,0.31,0.195),patch);
    vec3 vegetation = mix(vec3(0.12,0.14,0.065),vec3(0.26,0.28,0.12),soil);
    ALBEDO = mix(dust,vegetation,scrub*0.72) * (0.88+0.22*soil+0.12*(micro-0.5)*distance_fade*detail_strength);
    ROUGHNESS = clamp(0.82+0.11*soil+0.05*micro,0.0,1.0);
    METALLIC = 0.0;
}
