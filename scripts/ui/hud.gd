extends CanvasLayer

func _ready() -> void:
	add_to_group("hud")
	_setup_vignette()

func _setup_vignette() -> void:
	var vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float opacity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    float dist = distance(UV, vec2(0.5));
    COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.4, 0.7, dist) * intensity * opacity);
}
"""
	vignette.material = mat
	add_child(vignette)

func show_interaction_prompt(text: String) -> void:
	pass
