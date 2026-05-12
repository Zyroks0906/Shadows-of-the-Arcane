shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec3 mixed_color = mix(tex_color.rgb, tint_color.rgb, tint_intensity);
    COLOR = vec4(mixed_color, tex_color.a);
}
