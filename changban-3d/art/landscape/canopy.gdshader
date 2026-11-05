shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D spray : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool meadow = false;
void vertex() {
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float tip=meadow ? 1.0-fract(UV.y*2.0) : 0.45;
	VERTEX.x+=tip*0.034*sin(TIME*1.3+world.x*0.73+world.z*0.46);
}
void fragment() {
	vec4 leaves = texture(spray,UV);
	// The original brushwork already contains cool inner leaves and warm tips.
	// Give every spray a canopy normal instead of alternating bright/dark cards.
	NORMAL=normalize(mix(NORMAL,normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz),0.68));
	ALBEDO=leaves.rgb*(meadow ? vec3(.58,.60,.52) : vec3(.57,.65,.62));
	ALPHA=leaves.a;
	ALPHA_SCISSOR_THRESHOLD=meadow ? .31 : .43;
	ROUGHNESS=.97;
}
