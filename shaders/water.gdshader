shader_type canvas_item;

// Deep water for the generated levels (the Water TileMapLayer). The tiles only give the
// shape; colour and motion come from here, on the world pixel grid so it stays crisp:
// - depth: darker under the bank above (the ledge's shadow), lighter towards open water;
// - caustics: two slow, crossing sine fields banded into two light levels;
// - glints: sparse pixels that blink on and off;
// - foam: a pale broken line where the water meets the bank below.

uniform vec4 deep : source_color = vec4(0.07, 0.16, 0.25, 1.0);
uniform vec4 mid : source_color = vec4(0.12, 0.27, 0.38, 1.0);
uniform vec4 light : source_color = vec4(0.25, 0.47, 0.58, 1.0);
uniform vec4 glint : source_color = vec4(0.78, 0.94, 1.0, 1.0);
uniform float speed = 1.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) {
		discard;
	}
	vec2 p = floor(world);
	float t = TIME * speed;
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	// Caustic field.
	float w = sin(p.x * 0.29 + t * 1.3 + sin(p.y * 0.19 + t * 0.6) * 2.2)
		+ sin(p.y * 0.37 - t * 1.1 + sin(p.x * 0.13 - t * 0.4) * 2.0);
	vec3 col = mix(deep.rgb, mid.rgb, 0.55 + 0.25 * sin(p.y * 0.05 + p.x * 0.03));
	col = mix(col, mid.rgb * 1.12, step(0.9, w) * 0.6);
	col = mix(col, light.rgb, step(1.55, w) * 0.75);
	// Bank edges from the tile art: its bright rim becomes foam, its dark lip a shadow.
	col = mix(col, glint.rgb * 0.9, smoothstep(0.55, 0.75, lum) * (0.55 + 0.45 * step(0.5, hash(vec2(p.x, floor(t * 2.0))))));
	col = mix(col, deep.rgb * 0.6, smoothstep(0.25, 0.1, lum) * 0.6);
	// Blinking glints.
	float g = step(0.996, hash(p + vec2(floor(t * 2.5), 0.0)));
	col = mix(col, glint.rgb, g * 0.85);
	COLOR = vec4(col, tex.a);
}
