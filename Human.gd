extends CharacterBody3D

var SPEED = 2.0
var health = 5
var current_dir = Vector3.ZERO
var change_dir_timer = 0.0

@onready var animation_player: AnimationPlayer
@onready var model_root: Node3D
@onready var hit_light: OmniLight3D

var hit_timer = 0.0

var foot_sound: AudioStreamPlayer3D
var hit_sound: AudioStreamPlayer3D
var step_timer = 0.0
var step_interval = 0.4

func _ready():
    # Instantiate the downloaded Godot character GLB
    var glb_packed = preload("res://player.glb")
    model_root = glb_packed.instantiate()
    
    var type_rand = randf()
    if type_rand < 0.2:
        # Scout
        SPEED = 4.0
        health = 1
        model_root.scale = Vector3(0.8, 0.8, 0.8)
        step_interval = 0.25
    elif type_rand > 0.8:
        # Juggernaut
        SPEED = 1.0
        health = 12
        model_root.scale = Vector3(1.6, 1.6, 1.6)
        step_interval = 0.8
    else:
        # Normal
        model_root.scale = Vector3(1.2, 1.2, 1.2)
        
    add_child(model_root)
    
    # Setup animations
    animation_player = model_root.get_node("AnimationPlayer")
    if animation_player != null and animation_player.has_animation("walking_nogun"):
        # Play Walk animation looping
        animation_player.get_animation("walking_nogun").loop_mode = Animation.LOOP_LINEAR
        animation_player.play("walking_nogun")
    
    # Physics Collision
    var coll = CollisionShape3D.new()
    var shape = CapsuleShape3D.new()
    shape.radius = 0.4
    shape.height = 1.8
    coll.shape = shape
    coll.position = Vector3(0, 0.9, 0)
    add_child(coll)
    
    # Hit reaction light
    hit_light = OmniLight3D.new()
    hit_light.light_color = Color(1.0, 0.0, 0.0)
    hit_light.light_energy = 5.0
    hit_light.omni_range = 3.0
    hit_light.visible = false
    hit_light.position = Vector3(0, 1.5, 0)
    add_child(hit_light)
    
    pick_new_dir()
    
    foot_sound = AudioStreamPlayer3D.new()
    foot_sound.stream = preload("res://audio/step.wav")
    foot_sound.max_distance = 15.0
    add_child(foot_sound)
    
    hit_sound = AudioStreamPlayer3D.new()
    hit_sound.stream = preload("res://audio/hit.wav")
    hit_sound.max_distance = 25.0
    add_child(hit_sound)

func pick_new_dir():
    var dirs = [Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1)]
    dirs.shuffle()
    for d in dirs:
        if not test_move(global_transform, d * 1.5):
            current_dir = d
            break
    change_dir_timer = randf_range(2.0, 6.0)

func _physics_process(delta):
    if hit_timer > 0:
        hit_timer -= delta
        if hit_timer <= 0:
            hit_light.visible = false
            
    step_timer -= delta
    if step_timer <= 0 and velocity.length() > 0.5:
        foot_sound.play()
        step_timer = step_interval
    
    if current_dir == Vector3.ZERO: pick_new_dir()
    
    # Smoothly rotate ONLY the visual model, not the physics capsule!
    # Point it opposite to current_dir because the TPS mesh is authored facing +Z
    if Vector2(velocity.x, velocity.z).length() > 0.1:
        var target_transform = model_root.global_transform.looking_at(model_root.global_position + Vector3(velocity.x, 0, velocity.z), Vector3.UP)
        var target_rot = target_transform.basis.get_rotation_quaternion()
        model_root.transform.basis = Basis(model_root.quaternion.slerp(target_rot, 5.0 * delta))
    
    # Fluid forward movement but strictly along grid axis to prevent wall clipping
    velocity = current_dir * SPEED
    move_and_slide()
    
    change_dir_timer -= delta
    if change_dir_timer <= 0:
        change_dir_timer = randf_range(2.0, 6.0)
        var side_dirs = [Vector3(current_dir.z, 0, -current_dir.x), Vector3(-current_dir.z, 0, current_dir.x)]
        var turn_dir = side_dirs[randi() % 2]
        if not test_move(global_transform, turn_dir * 1.5):
            current_dir = turn_dir
            
    if test_move(global_transform, current_dir * 0.5):
        pick_new_dir()

func take_damage():
    health -= 1
    hit_light.visible = true
    hit_timer = 0.1
    hit_sound.play()
    
    if health <= 0:
        queue_free()
