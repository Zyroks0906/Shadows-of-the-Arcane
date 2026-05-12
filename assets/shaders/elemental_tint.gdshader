shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 secondary_tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Create a vertical gradient between the two tint colors
    // Shifting the UV.y to make the transition more centered
    float gradient_pos = smoothstep(0.0, 1.0, UV.y);
    vec3 gradient_color = mix(tint_color.rgb, secondary_tint_color.rgb, gradient_pos);
    
    // Add a subtle pulsing effect to the intensity
    float pulse = 0.8 + 0.2 * sin(TIME * 3.0); // Faster pulse
    float dynamic_intensity = tint_intensity * pulse;
    
    // Mix with a bit of additive blending for "intensity"
    vec3 mixed_color = mix(tex_color.rgb, gradient_color, dynamic_intensity);
    vec3 additive_glow = gradient_color * dynamic_intensity * 0.3; // Add a bit of glow
    
    COLOR = vec4(mixed_color + additive_glow, tex_color.a);
}
