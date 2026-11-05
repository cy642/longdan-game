shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D drawing : source_color, filter_linear_mipmap, repeat_disable;
uniform float amber = 0.0;
uniform float offset = 0.0;

void fragment() {
	vec2 uv = UV;
	float beat = mod(TIME + offset, 4.87) - 3.81;
	float blink = smoothstep(0.0, 0.075, beat) * (1.0 - smoothstep(0.085, 0.19, beat));
	// Fold the illustrated eye into the lower lid; the painted brow stays put.
	if (uv.y > 0.31) {
		uv.y = 0.69 + (uv.y - 0.69) / mix(1.0, 0.055, blink);
		if (uv.y < 0.31 || uv.y > 1.0) { discard; }
	}
	vec4 pigment = texture(drawing, uv);
	float iris = smoothstep(.018,.12,pigment.b - pigment.r);
	ALBEDO = mix(pigment.rgb,pigment.bgr * vec3(0.85,0.79,0.59),amber * iris);
	ALPHA = pigment.a;
}
