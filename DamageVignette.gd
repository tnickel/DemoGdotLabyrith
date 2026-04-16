extends CanvasLayer

signal player_damaged

var vignette_rect: ColorRect
var hp: int = 5
var max_hp: int = 5

func _ready():
    layer = 10
    vignette_rect = ColorRect.new()
    vignette_rect.color = Color(0, 0, 0, 0)
    vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(vignette_rect)
    
    var shader = Shader.new()
    shader.code = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec2 uv = UV - 0.5;
    float d = length(uv) * 2.0;
    float v = smoothstep(0.3, 1.0, d) * strength;
    COLOR = vec4(0.8, 0.0, 0.0, v);
}
"""
    var smat = ShaderMaterial.new()
    smat.shader = shader
    vignette_rect.material = smat

func take_hit():
    hp -= 1
    var smat: ShaderMaterial = vignette_rect.material
    var base_strength = 1.0 - float(hp) / float(max_hp) * 0.5
    smat.set_shader_parameter("strength", base_strength + 0.5)
    
    var tw = create_tween()
    tw.tween_method(func(v): smat.set_shader_parameter("strength", v),
        base_strength + 0.5, base_strength, 0.5)
    
    if hp <= 0:
        # Simple death: respawn at origin
        await get_tree().create_timer(1.0).timeout
        get_tree().reload_current_scene()
