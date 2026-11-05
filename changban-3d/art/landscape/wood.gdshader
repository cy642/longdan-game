shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform bool plank_deck = false;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	float row = plank_deck ? world.z : world.x*.63+world.z*.81;
	float along = plank_deck ? world.x : world.y;
	float wav = sin(along*1.8+row*1.9)*.23+sin(along*.74)*.28;
	float grain = sin(row*50.0+wav*3.0+sin(row*12.0+along*.7))*0.5+0.5;
	float lines = smoothstep(.64,.99,grain) * max(.0,1.0-fwidth(row)*17.0);
	vec3 pigment=OUTPUT_IS_SRGB ? pow(max(COLOR.rgb,vec3(.001)),vec3(.75)) : COLOR.rgb;
	ALBEDO=pigment*(1.0-lines*.24)+vec3(.008,.006,.003);
	ROUGHNESS=.96;
}
