extends CharacterBody3D

var health = 3
var SPEED = 2.5
var player_ref: CharacterBody3D = null
var nav_update_timer = 0.0
var current_dir = Vector3(1, 0, 0)  # fallback random walk direction
var change_dir_timer = 0.0

@onready var mesh_inst: MeshInstance3D
var hit_sound: AudioStreamPlayer3D
var explode_sound: AudioStreamPlayer3D

func _ready():
    mesh_inst = MeshInstance3D.new()
    var body_mesh = CapsuleMesh.new()
    body_mesh.radius = 0.4
    body_mesh.height = 1.6
    mesh_inst.mesh = body_mesh
    var mat_body = StandardMaterial3D.new()
    mat_body.albedo_color = Color(0.3, 0.3, 0.3)
    mat_body.metallic = 1.0; mat_body.roughness = 0.05
    mesh_inst.material_override = mat_body
    add_child(mesh_inst)
    
    var eyes = MeshInstance3D.new()
    var eye_box = BoxMesh.new(); eye_box.size = Vector3(0.5, 0.15, 0.2)
    eyes.mesh = eye_box; eyes.position = Vector3(0, 0.4, -0.4)
    var mat_eyes = StandardMaterial3D.new()
    mat_eyes.albedo_color = Color(1.0, 0.0, 0.0)
    mat_eyes.emission_enabled = true; mat_eyes.emission = Color(1, 0, 0)
    mat_eyes.emission_energy_multiplier = 4.0
    eyes.material_override = mat_eyes; mesh_inst.add_child(eyes)
    
    var coll = CollisionShape3D.new()
    var shape = CapsuleShape3D.new(); shape.radius = 0.4; shape.height = 1.6
    coll.shape = shape; add_child(coll)
    
    var omni = OmniLight3D.new()
    omni.position = Vector3(0, 0.4, -0.5)
    omni.light_color = Color(1.0, 0.2, 0.2); omni.light_energy = 1.0; omni.omni_range = 4.0
    mesh_inst.add_child(omni)
    
    hit_sound = AudioStreamPlayer3D.new()
    hit_sound.stream = preload("res://audio/hit.wav"); hit_sound.max_distance = 25.0; add_child(hit_sound)
    explode_sound = AudioStreamPlayer3D.new()
    explode_sound.stream = preload("res://audio/explosion.wav")
    explode_sound.max_distance = 40.0; explode_sound.unit_size = 5.0; add_child(explode_sound)
    
    # Delay to find player after scene is ready
    await get_tree().process_frame
    await get_tree().process_frame
    player_ref = get_tree().root.find_child("Player", true, false) as CharacterBody3D
    # Start random walk
    pick_new_dir()

func pick_new_dir():
    var dirs = [Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1)]
    dirs.shuffle()
    for d in dirs:
        if not test_move(global_transform, d * 1.5):
            current_dir = d
            break
    change_dir_timer = randf_range(2.0, 6.0)

func _physics_process(delta):
    mesh_inst.position.y = sin(Time.get_ticks_msec() * 0.005) * 0.2
    
    # Random walk (NavMesh is disabled in this project)
    if current_dir == Vector3.ZERO: pick_new_dir()
    var move_dir = current_dir
    change_dir_timer -= delta
    if change_dir_timer <= 0:
        pick_new_dir()
    if test_move(global_transform, current_dir * 0.5):
        pick_new_dir()
    
    # Chase player if nearby
    if player_ref != null:
        var to_player = (player_ref.global_position - global_position)
        to_player.y = 0
        if to_player.length() < 8.0:
            move_dir = to_player.normalized()
    
    # Smooth facing
    if move_dir.length() > 0.1:
        var current_rot = mesh_inst.quaternion
        var target_transform = mesh_inst.global_transform.looking_at(mesh_inst.global_position + move_dir, Vector3.UP)
        var target_rot = target_transform.basis.get_rotation_quaternion()
        mesh_inst.transform.basis = Basis(current_rot.slerp(target_rot, 8.0 * delta))
    
    velocity.x = move_dir.x * SPEED
    velocity.z = move_dir.z * SPEED
    if not is_on_floor():
        velocity.y -= 9.8 * delta
    move_and_slide()

func take_damage(amount: int):
    health -= amount
    
    if health <= 0:
        die()
        return
        
    hit_sound.play()
    
    # Flash white
    var mat: StandardMaterial3D = mesh_inst.material_override
    mat.emission = Color(1.0, 1.0, 1.0)
    mat.emission_energy_multiplier = 5.0
    await get_tree().create_timer(0.1).timeout
    mat.emission = Color(1.0, 0.0, 0.0)
    mat.emission_energy_multiplier = 2.0
    
func die():
    if not mesh_inst.visible: return
    mesh_inst.visible = false
    set_physics_process(false)
    velocity = Vector3.ZERO
    
    # Fireball Particle Effect
    var p_mat = ParticleProcessMaterial.new()
    p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    p_mat.emission_sphere_radius = 0.5
    p_mat.direction = Vector3(0, 1, 0)
    p_mat.spread = 180.0
    p_mat.initial_velocity_min = 2.0
    p_mat.initial_velocity_max = 5.0
    p_mat.gravity = Vector3(0, 2.0, 0) # Fire goes slightly up
    p_mat.scale_min = 0.5
    p_mat.scale_max = 1.5
    
    var grad = Gradient.new()
    grad.set_offset(0, 0.0)
    grad.set_color(0, Color(1, 1, 0, 1)) # Bright Yellow Core
    grad.set_offset(1, 1.0)
    grad.set_color(1, Color(0.1, 0.1, 0.1, 0)) # Dissipate into dark smoke
    grad.add_point(0.2, Color(1, 0.4, 0, 1)) # Orange Fire
    grad.add_point(0.6, Color(0.8, 0.1, 0.0, 0.8)) # Red Fire
    
    var tex = GradientTexture1D.new()
    tex.gradient = grad
    p_mat.color_ramp = tex
    
    var draw_mat = StandardMaterial3D.new()
    draw_mat.vertex_color_use_as_albedo = true
    draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    
    var q_mesh = QuadMesh.new()
    q_mesh.material = draw_mat
    
    var particles = GPUParticles3D.new()
    particles.process_material = p_mat
    particles.draw_pass_1 = q_mesh
    particles.amount = 40
    particles.lifetime = 0.8
    particles.one_shot = true
    particles.explosiveness = 1.0
    
    add_child(particles)
    particles.emitting = true
    
    # Sound & Flash
    explode_sound.play()
    var light = OmniLight3D.new()
    light.light_color = Color(1.0, 0.5, 0.0)
    light.light_energy = 5.0
    light.omni_range = 6.0
    add_child(light)
    
    await get_tree().create_timer(1.0).timeout
    queue_free()
