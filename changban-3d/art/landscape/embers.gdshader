shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

void vertex() {
	// Face the camera, retaining each puff's world scale and origin.
	mat4 bill = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bill[0].xyz *= length(MODEL_MATRIX[0].xyz);
	bill[1].xyz *= length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * bill;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = length(p) + 0.08 * sin(p.y * 9.0 + p.x * 3.0)
		+ 0.07 * sin(p.x * 11.0 - p.y * 4.0);
	ALBEDO = vec3(0.25, 0.25, 0.24);
	ALPHA = (1.0 - smoothstep(0.17, 0.97, edge)) * COLOR.a * 0.24;
}
