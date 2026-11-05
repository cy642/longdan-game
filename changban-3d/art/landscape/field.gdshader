shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform sampler2D ground_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D brush : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec2 ground_xz;

void vertex() {
	ground_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

vec3 swatch(vec2 tile_uv, vec2 tile) {
	// Mirrored edges in the atlas are continuous; use pre-fract derivatives for
	// stable mips where world UVs wrap and along glancing hedge-lines.
	return textureGrad(brush, (tile + 0.004 + fract(tile_uv)*0.992)*0.5,
		dFdx(tile_uv)*0.496, dFdy(tile_uv)*0.496).rgb;
}

void fragment() {
	vec3 base = texture(ground_map, UV).rgb;
	mat2 skew = mat2(vec2(0.94,0.34),vec2(-0.34,0.94));
	vec2 field_uv = skew * ground_xz * 0.248;
	float on_path = smoothstep(-0.010,0.048,base.r-base.g);
	vec3 dirt = swatch(field_uv,vec2(0.0));
	vec3 turf = swatch(field_uv*0.86+vec2(0.27,0.13),vec2(1.0,0.0));
	vec3 strokes = mix(turf,dirt,on_path);
	float relief = dot(strokes,vec3(0.27,0.60,0.13));
	float brush_gain = mix(clamp(relief*1.46 + 0.26,0.37,0.98),clamp(relief*1.22 + 0.23,0.36,0.98),on_path);
	ALBEDO = base*brush_gain + strokes*0.022;
	ROUGHNESS = 0.97;
}
