shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float vignette_intensity : hint_range(0.0, 1.5) = 0.42;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.55;
uniform vec4 vignette_color : source_color = vec4(0.02, 0.05, 0.12, 1.0);

uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.0035;
uniform float grain_intensity : hint_range(0.0, 0.1) = 0.015;

float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center_offset = uv - vec2(0.5);
	float dist_from_center = length(center_offset);
	
	// 1. Subtle Chromatic Aberration (Radial RGB split increasing toward edges)
	float split = chromatic_aberration * dist_from_center;
	vec2 dir = normalize(center_offset + vec2(0.0001));
	
	float r = texture(screen_texture, uv - dir * split).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv + dir * split).b;
	vec3 scene_col = vec3(r, g, b);
	
	// 2. Cinematic Vignette
	float vignette = smoothstep(0.85, 0.85 - vignette_intensity, dist_from_center);
	scene_col = mix(vignette_color.rgb, scene_col, mix(1.0, vignette, vignette_opacity));
	
	// 3. Subtle Film Grain for tactile arcade feel
	float grain = (random(uv + vec2(TIME * 0.01, TIME * 0.02)) - 0.5) * grain_intensity;
	scene_col += vec3(grain);
	
	COLOR = vec4(scene_col, 1.0);
}
