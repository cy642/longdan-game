shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The distant layers already contain their own progressively cooler aerial
	// perspective. Keeping it separate preserves the open notch in morning mist.
	float seam = world_point.y * 2.4 + world_point.x * 0.60 + world_point.z * 0.63;
	float strata = sin(seam + sin(world_point.x * 0.53) * 1.8);
	float brush = 1.0 + 0.026 * strata;
	vec3 paint = COLOR.rgb * brush;
	ALBEDO = OUTPUT_IS_SRGB ? pow(max(paint, vec3(0.0001)), vec3(1.0 / 2.2)) : paint;
}
