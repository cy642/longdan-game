shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D woven_silk : source_color, filter_linear_mipmap, repeat_disable;

void vertex() {
	float loose = UV.y * UV.y;
	float wave = sin(TIME * 2.5 + VERTEX.x * 2.35 + VERTEX.z * 0.23 - UV.y * 2.0);
	VERTEX.z += loose * wave * 0.145;
	VERTEX.x += loose * sin(TIME * 1.65 + VERTEX.z + UV.y * 1.5) * 0.065;
}

void fragment() {
	ALBEDO = texture(woven_silk, UV).rgb;
	ROUGHNESS = 0.98;
}
