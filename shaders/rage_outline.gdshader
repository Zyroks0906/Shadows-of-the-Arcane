shader_type canvas_item;
render_mode unshaded; // the rim glows: the chamber's darkness must not dim it

// Spartan Rage: the hero flushes red and a glowing red rim beats around his silhouette.
// The rim is the 1-pixel outline just outside the sprite (from the alpha of the
// neighbouring pixels), so it hugs the art and never covers it.

uniform vec4 rim : source_color = vec4(1.0, 0.18, 0.08, 1.0);
uniform float flush = 0.55; // how red the body turns
uniform float strength = 1.0; // 0..1, faded in and out by the script
uniform float width = 1.0;    // rim width in texels (the script sets one world pixel)

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float beat = 0.65 + 0.35 * sin(TIME * 7.0);
	if (c.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE * width;
		float n = 0.0;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.785398;
			n += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a;
		}
		COLOR = vec4(rim.rgb, step(0.5, n) * beat * strength) * vec4(1.0, 1.0, 1.0, COLOR.a);
	} else {
		vec3 red = mix(c.rgb, c.rgb * vec3(1.35, 0.6, 0.55), flush * strength);
		COLOR = vec4(red, c.a) * COLOR;
	}
}
