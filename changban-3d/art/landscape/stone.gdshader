shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D brush : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 world;
varying vec3 slope;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	slope = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 weathering(vec2 coords) {
	vec2 uv=coords*0.52;
	return textureGrad(brush,vec2(.002,.502)+fract(uv)*.496,dFdx(uv)*.496,dFdy(uv)*.496).rgb;
}
void fragment() {
	vec3 w = pow(abs(normalize(slope)),vec3(3.0));
	w /= max(0.001,w.x+w.y+w.z);
	vec3 patina = weathering(world.zy)*w.x + weathering(world.xz)*w.y + weathering(world.xy)*w.z;
	float grains=dot(patina,vec3(.27,.61,.12));
	float moss=smoothstep(.33,.85,slope.y+sin(world.z*2.5+world.x*2.8)*.24)*smoothstep(.14,.34,grains);
	ALBEDO = mix(COLOR.rgb*(.69+grains*1.9)+patina*.17,vec3(.16,.21,.092)*(.76+grains),moss*.45);
	ROUGHNESS=.95;
}
