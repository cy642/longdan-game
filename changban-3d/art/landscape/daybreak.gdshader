shader_type sky;

uniform vec4 zenith : source_color = vec4(0.32, 0.51, 0.64, 1.0);
uniform vec4 horizon : source_color = vec4(0.92, 0.78, 0.61, 1.0);
uniform vec4 cloud : source_color = vec4(0.93, 0.86, 0.74, 1.0);

void sky() {
	vec3 ray = EYEDIR;
	float height = max(ray.y,0.0);
	vec3 paint = mix(horizon.rgb,zenith.rgb,smoothstep(0.0,0.64,sqrt(height)));
	vec2 p = ray.xz / (height + 0.17);
	float curl = 1.8*sin(0.92*p.x) + 0.5*sin(1.65*p.y+0.72*p.x);
	float wisps = sin(3.2*p.y + curl) + 0.42*sin(6.1*p.y - 1.8*p.x + curl);
	float streaks = smoothstep(0.34,1.24,wisps) * smoothstep(0.018,0.19,height);
	COLOR = mix(paint,cloud.rgb,streaks*0.33);
}
