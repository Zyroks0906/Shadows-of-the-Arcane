shader_type canvas_item;

// A shallow puddle lying on the floor (ElementZone, Style.WATER). Not a rectangle: a blob
// whose outline is warped by smooth noise, so every pool has its own shape. Like real
// water it is a film at the rim and gathers towards the middle: depth rises from the edge
// in four steps (wet sheen -> thin film -> shallow -> pooled), each a little darker and
// more opaque, with light bands only where it is deep enough. Pixel-snapped to the world.

uniform vec2 rect_size = vec2(32.0, 32.0);
uniform vec4 deep : source_color = vec4(0.08, 0.2, 0.3, 1.0);
uniform vec4 shallow : source_color = vec4(0.2, 0.38, 0.48, 1.0);
uniform vec4 sheen : source_color = vec4(0.55, 0.72, 0.8, 1.0);
uniform vec4 glint : source_color = vec4(0.82, 0.95, 1.0, 1.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 local = floor(UV * rect_size) + 0.5;
	vec2 p = floor(world);
	// Normalised position in the pool (0 at the centre, 1 at the rect's edge), the outline
	// pushed in and out by two octaves of noise so the shore wanders.
	vec2 n = (local - rect_size * 0.5) / (rect_size * 0.5);
	float r = length(n * vec2(1.0, 1.05));
	r += (vnoise(p * 0.09) - 0.5) * 0.45 + (vnoise(p * 0.23 + 17.0) - 0.5) * 0.18;
	float depth = 1.0 - r / 0.92;
	if (depth <= 0.0) {
		discard;
	}
	float t = TIME;
	vec3 col;
	float a;
	if (depth < 0.1) {          // wet sheen on the stone: barely there
		col = sheen.rgb;
		a = 0.16;
	} else if (depth < 0.24) {  // a thin film
		col = shallow.rgb;
		a = 0.3;
	} else if (depth < 0.45) {  // shallow water
		col = mix(shallow.rgb, deep.rgb, 0.45);
		a = 0.45;
	} else {                    // pooled in the middle
		col = deep.rgb;
		a = 0.58;
	}
	// Light bands drift through the deeper water only.
	float w = sin(p.x * 0.27 + t * 1.1 + sin(p.y * 0.21 + t * 0.5) * 2.0)
		+ sin(p.y * 0.33 - t * 0.9 + sin(p.x * 0.15) * 1.8);
	float deepness = step(0.24, depth);
	col = mix(col, shallow.rgb * 1.25, step(1.3, w) * 0.5 * deepness);
	// The waterline: a pale broken pixel line where the film begins.
	float shore = step(0.1, depth) * step(depth, 0.135);
	col = mix(col, glint.rgb, shore * 0.5);
	a = max(a, shore * 0.45);
	// A few glints that blink, more of them in deeper water.
	float g = step(0.995 - deepness * 0.002, hash(p + vec2(0.0, floor(t * 2.0))));
	col = mix(col, glint.rgb, g * 0.85);
	a = max(a, g * 0.8);
	COLOR = vec4(col, a);
}
