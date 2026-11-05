shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

varying vec2 water_coordinate;

void vertex() {
	water_coordinate = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	// Only the thin, brighter foam pieces drift, keeping the river edge fixed.
	float foam = step(-2.03, VERTEX.y);
	VERTEX.x += foam * 0.30 * sin(TIME * 0.74 + water_coordinate.y * 1.9);
}

void fragment() {
	float current = sin(water_coordinate.y * 3.9 + water_coordinate.x * 0.47 + TIME * 0.7);
	float broken = sin(water_coordinate.x * 1.95 - water_coordinate.y * 1.1 - TIME * 0.53);
	float glint = smoothstep(0.78, 1.0, current) * smoothstep(0.38, 0.92, broken);
	ALBEDO = COLOR.rgb * (1.0 + glint * 0.16);
	ROUGHNESS = 0.82;
}
