shader_type canvas_item;

// Physical slashes: the painted crescent with its colours taken out, a plain steel-grey
// streak, so a swing with no element never reads as an elemental one.
uniform vec4 tint : source_color = vec4(0.93, 0.94, 0.97, 1.0);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(clamp(vec3(l) * 1.35, 0.0, 1.0) * tint.rgb, t.a * COLOR.a);
}
