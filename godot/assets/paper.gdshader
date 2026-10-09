shader_type canvas_item;
varying vec2 paper_position;
void vertex() { paper_position = VERTEX; }
void fragment() {
    float grain = fract(sin(dot(floor(paper_position * 1.3), vec2(12.9898, 78.233))) * 43758.5453);
    COLOR.rgb *= 0.973 + grain * 0.054;
}
