extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 9.0
const MOUSE_SENSITIVITY = 0.003
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D

var shoot_sound: AudioStreamPlayer
var damage_timer = 0.0
var vignette = null

var xr_origin: XROrigin3D
var vr_camera: XRCamera3D

func _ready():
    floor_max_angle = deg_to_rad(75.0)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    var mgr = get_node("/root/SettingsManager")
    mgr.settings_updated.connect(_on_settings_updated)
    _on_settings_updated()
    
    if mgr.is_vr:
        xr_origin = XROrigin3D.new()
        xr_origin.position.y = -0.7 # Offset floor downwards so physical height places head correctly in the 2.0m maze
        add_child(xr_origin)
        vr_camera = XRCamera3D.new()
        xr_origin.add_child(vr_camera)
        
        camera.current = false
        vr_camera.current = true
        # Hide standard HUD crosshair if it exists
        var ui = get_node_or_null("UI")
        if ui: ui.visible = false
        
        var fps_lbl = Label3D.new()
        fps_lbl.name = "VRFPSLabel"
        fps_lbl.pixel_size = 0.001
        fps_lbl.position = Vector3(0, 0.2, -0.6)
        fps_lbl.no_depth_test = true
        fps_lbl.render_priority = 100
        vr_camera.add_child(fps_lbl)
    
    shoot_sound = AudioStreamPlayer.new()
    shoot_sound.stream = preload("res://audio/shoot.wav")
    add_child(shoot_sound)
    
    # Find damage vignette (set after maze generates)
    await get_tree().process_frame
    await get_tree().process_frame
    vignette = get_tree().root.find_child("DamageVignette", true, false)

func _on_settings_updated():
    var mgr = get_node("/root/SettingsManager")
    $Camera3D/SpotLight3D.light_energy = mgr.flash_brightness

func _unhandled_input(event):
    var mgr = get_node_or_null("/root/SettingsManager")
    
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        # Turn the player's body left/right using the mouse
        rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        
        # Mouse pitch (looking up/down)
        if not (mgr and mgr.is_vr):
            camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
            camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
        else:
            # Erlaubt das Umsehen mit der Maus auch in der VR-Option (für Desktop/Testen nützlich)
            if is_instance_valid(xr_origin):
                xr_origin.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
                xr_origin.rotation.x = clamp(xr_origin.rotation.x, -PI/2, PI/2)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        else:
            shoot()

func _physics_process(delta):
    if not is_on_floor():
        velocity.y -= gravity * delta

    if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
        velocity.y = JUMP_VELOCITY

    var input_dir = Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1
    if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1
    if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1
    if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1

    input_dir = input_dir.normalized()
    
    var h_rot = global_transform.basis
    if is_instance_valid(vr_camera):
        # Move in the direction the VR headset is looking horizontally
        var cam_z = vr_camera.global_transform.basis.z
        cam_z.y = 0; cam_z = cam_z.normalized()
        var cam_x = vr_camera.global_transform.basis.x
        cam_x.y = 0; cam_x = cam_x.normalized()
        h_rot = Basis(cam_x, Vector3.UP, cam_z)
        
    var direction = (h_rot * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    var current_speed = SPEED
    if Input.is_physical_key_pressed(KEY_SHIFT):
        current_speed = SPRINT_SPEED
        
    if direction:
        velocity.x = direction.x * current_speed
        velocity.z = direction.z * current_speed
    else:
        velocity.x = move_toward(velocity.x, 0, current_speed)
        velocity.z = move_toward(velocity.z, 0, current_speed)

    move_and_slide()
    
    if is_instance_valid(vr_camera):
        var fps_lbl = vr_camera.get_node_or_null("VRFPSLabel")
        if fps_lbl:
            fps_lbl.text = "FPS: %d" % Engine.get_frames_per_second()
    
    # Monster contact damage
    damage_timer -= delta
    for i in get_slide_collision_count():
        var col = get_slide_collision(i)
        if col and col.get_collider() and col.get_collider().has_method("take_damage"):
            if damage_timer <= 0:
                damage_timer = 1.5
                if vignette and vignette.has_method("take_hit"):
                    vignette.take_hit()

func shoot():
    # Draw laser
    create_laser_visual()
    shoot_sound.play()
    
    var active_cam = vr_camera if is_instance_valid(vr_camera) else camera
    var space_state = get_world_3d().direct_space_state
    var start_pos = active_cam.global_position
    var end_pos = start_pos + active_cam.global_transform.basis * Vector3(0, 0, -20.0)
    var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
    var result = space_state.intersect_ray(query)
    
    if result:
        var collider = result.collider
        if collider and collider.has_method("take_damage"):
            collider.take_damage(1)

func create_laser_visual():
    var laser = MeshInstance3D.new()
    var cyl = CylinderMesh.new()
    cyl.top_radius = 0.05
    cyl.bottom_radius = 0.05
    cyl.height = 10.0
    laser.mesh = cyl
    
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0, 1, 0)
    mat.emission_enabled = true
    mat.emission = Color(0, 1, 0)
    mat.emission_energy_multiplier = 4.0
    laser.material_override = mat
    
    get_tree().root.add_child(laser)
    
    var active_cam = vr_camera if is_instance_valid(vr_camera) else camera
    var start_pos = active_cam.global_position + active_cam.global_transform.basis * Vector3(0.3, -0.3, -0.5)
    var end_pos = start_pos + active_cam.global_transform.basis * Vector3(0, 0, -10)
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(active_cam.global_position, active_cam.global_position + active_cam.global_transform.basis * Vector3(0, 0, -20.0))
    var result = space_state.intersect_ray(query)
    
    if result:
        end_pos = result.position
    
    var dist = start_pos.distance_to(end_pos)
    cyl.height = dist
    
    laser.global_position = (start_pos + end_pos) / 2.0
    laser.look_at(end_pos, Vector3.UP)
    laser.rotation_degrees.x += 90 # align cylinder
    
    # Remove after short time
    await get_tree().create_timer(0.1).timeout
    laser.queue_free()
