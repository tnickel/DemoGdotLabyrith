extends Node3D

var time_passed = 0.0
var rings = []
var colors = [
    Color(1.0, 0.0, 0.3), # Neon Pink
    Color(0.0, 1.0, 0.5), # Cyber Green
    Color(0.0, 0.5, 1.0), # Electric Blue
    Color(1.0, 0.8, 0.0), # Burning Gold
    Color(0.6, 0.0, 1.0)  # Plasma Purple
]

func _ready():
    var base_color = colors[randi() % colors.size()]
    
    # Postament (Pedestal)
    var pedestal = MeshInstance3D.new()
    var p_mesh = CylinderMesh.new()
    p_mesh.top_radius = 0.8
    p_mesh.bottom_radius = 1.0
    p_mesh.height = 0.6
    pedestal.mesh = p_mesh
    var p_mat = StandardMaterial3D.new()
    p_mat.albedo_color = Color(0.05, 0.05, 0.05)
    p_mat.metallic = 0.9
    p_mat.roughness = 0.3
    pedestal.material_override = p_mat
    # Lift pedestal to floor level (height is 0.6, so origin is at 0.3 offset + 0.25 floor = 0.5)
    pedestal.position.y = 0.3
    add_child(pedestal)
    
    var static_body = StaticBody3D.new()
    var coll = CollisionShape3D.new()
    var cyl_shape = CylinderShape3D.new()
    cyl_shape.radius = 1.0
    cyl_shape.height = 0.6
    coll.shape = cyl_shape
    static_body.add_child(coll)
    pedestal.add_child(static_body)
    
    # Hologram/Wireframe Shader
    var shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;
uniform vec4 neon_color : source_color;
uniform float pulse_speed = 2.0;

void fragment() {
    float grid_u = fract(UV.x * 28.0);
    float grid_v = fract(UV.y * 14.0);
    // Antialiased lines
    float line_u = smoothstep(0.15, 0.1, grid_u) + smoothstep(0.85, 0.9, grid_u);
    float line_v = smoothstep(0.15, 0.1, grid_v) + smoothstep(0.85, 0.9, grid_v);
    float wire = max(line_u, line_v);
    
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    
    ALBEDO = mix(vec3(0.02), neon_color.rgb, wire);
    METALLIC = 0.9;
    ROUGHNESS = 0.15;
    if (wire > 0.5) {
        EMISSION = neon_color.rgb * (3.0 + pulse * 4.0);
    }
}
"""
    
    # Create 3 interlocking toruses
    for i in range(3):
        var ring = MeshInstance3D.new()
        var t_mesh = TorusMesh.new()
        t_mesh.inner_radius = 0.6 + i * 0.3
        t_mesh.outer_radius = 0.75 + i * 0.3
        t_mesh.rings = 48
        t_mesh.ring_segments = 24
        ring.mesh = t_mesh
        
        var mat = ShaderMaterial.new()
        mat.shader = shader
        # Randomize color slightly per ring for a nice multi-hued neon effect
        var c = base_color.lerp(Color(1,1,1), randf() * 0.15)
        mat.set_shader_parameter("neon_color", c)
        mat.set_shader_parameter("pulse_speed", 1.5 + randf())
        ring.material_override = mat
        
        ring.position.y = 2.2
        ring.rotation_degrees = Vector3(randf()*360, randf()*360, randf()*360)
        
        var spin_dir = Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)).normalized()
        rings.append({"node": ring, "spin": spin_dir * randf_range(0.5, 2.0)})
        add_child(ring)

    # Powerful colored light illuminating the dark museum
    var omni = OmniLight3D.new()
    omni.light_color = base_color
    omni.light_energy = 5.0
    omni.omni_range = 10.0
    omni.shadow_enabled = true
    omni.position.y = 2.2
    add_child(omni)

func _process(delta):
    time_passed += delta
    for obj in rings:
        obj.node.rotate_x(obj.spin.x * delta)
        obj.node.rotate_y(obj.spin.y * delta)
        obj.node.rotate_z(obj.spin.z * delta)
        # Gentle floating
        obj.node.position.y = 2.2 + sin(time_passed * 1.5 + obj.spin.x) * 0.3
