extends Node3D

const SPEED = 2.5
var target_y = 0.0
var current_y = 0.0
var l_offset = 4.5

var platform: AnimatableBody3D
var doors = [] # Dictionary list: [{"level":0, "left":Node, "right":Node, "open":false}, ...]

func setup(levels: int, l_off: float):
    l_offset = l_off
    # Build Platform
    platform = AnimatableBody3D.new()
    var p_mesh = MeshInstance3D.new()
    p_mesh.mesh = BoxMesh.new()
    p_mesh.mesh.size = Vector3(4.0, 0.2, 4.0)
    var mat_neon = StandardMaterial3D.new()
    mat_neon.albedo_color = Color(1, 0, 0)
    mat_neon.emission_enabled = true
    mat_neon.emission = Color(1, 0, 0)
    mat_neon.emission_energy_multiplier = 2.0
    p_mesh.material_override = mat_neon
    platform.add_child(p_mesh)
    
    var coll = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = p_mesh.mesh.size
    coll.shape = shape
    platform.add_child(coll)
    add_child(platform)
    
    # Build Glass Walls & Doors per level
    var glass_mat = StandardMaterial3D.new()
    glass_mat.albedo_color = Color(0.2, 0.5, 0.8, 0.2) # Transparent Blue
    glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass_mat.metallic = 0.9
    glass_mat.roughness = 0.1
    
    var grid_mat = StandardMaterial3D.new()
    grid_mat.albedo_color = Color(0.1, 0.1, 0.1)
    grid_mat.metallic = 1.0
    
    for l in range(levels):
        var c_y = l * l_offset
        # Glass enclosure
        var cage = MeshInstance3D.new()
        cage.mesh = BoxMesh.new()
        cage.mesh.size = Vector3(4.8, l_offset, 4.8)
        cage.material_override = glass_mat
        cage.position = Vector3(0, c_y + l_offset/2.0, 0)
        
        # We only apply visual glass. For collisions, we add invisible walls
        # left, right, back. Front is doors.
        for dir in [Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,-1)]:
            var w_body = StaticBody3D.new()
            var w_coll = CollisionShape3D.new()
            var cs = BoxShape3D.new()
            if dir.z != 0: cs.size = Vector3(5.0, l_offset, 0.2)
            else: cs.size = Vector3(0.2, l_offset, 5.0)
            w_coll.shape = cs
            w_body.add_child(w_coll)
            w_body.position = Vector3(0, c_y + l_offset/2.0, 0) + dir * 2.4
            
            var panel = MeshInstance3D.new()
            panel.mesh = QuadMesh.new()
            panel.mesh.size = Vector2(5.0, l_offset)
            panel.material_override = glass_mat
            
            # rotate quad to point inwards
            if dir.z > 0.5: panel.rotation_degrees = Vector3(0, 0, 0)
            elif dir.z < -0.5: panel.rotation_degrees = Vector3(0, 180, 0)
            elif dir.x > 0.5: panel.rotation_degrees = Vector3(0, 90, 0)
            elif dir.x < -0.5: panel.rotation_degrees = Vector3(0, -90, 0)
            
            w_body.add_child(panel)
            
            add_child(w_body)
            
        # Add visual cage
        # add_child(cage)  (Opting for just clear pillars instead to avoid z-fighting with maze walls)
        
        # Doors (Front +Z)
        var d_left = AnimatableBody3D.new()
        var d_right = AnimatableBody3D.new()
        
        for d in [d_left, d_right]:
            var m = MeshInstance3D.new()
            m.mesh = BoxMesh.new()
            m.mesh.size = Vector3(2.0, l_offset, 0.2)
            m.material_override = grid_mat
            d.add_child(m)
            var c = CollisionShape3D.new()
            var shape2 = BoxShape3D.new()
            shape2.size = m.mesh.size
            c.shape = shape2
            d.add_child(c)
            add_child(d)
        
        d_left.position = Vector3(-1.0, c_y + l_offset/2.0, 2.4)
        d_right.position = Vector3( 1.0, c_y + l_offset/2.0, 2.4)
        
        # Sensor
        var sensor = Area3D.new()
        var s_coll = CollisionShape3D.new()
        var s_shape = BoxShape3D.new()
        s_shape.size = Vector3(4.0, 2.0, 4.0)
        s_coll.shape = s_shape
        sensor.add_child(s_coll)
        sensor.position = Vector3(0, c_y + 1.0, 3.5) # Just outside front door
        add_child(sensor)
        
        # We need to bind the level id `l` safely. Godot 4 connect with binds
        sensor.body_entered.connect(_on_sensor.bind(l))
        sensor.body_exited.connect(_on_sensor_exit.bind(l))
        
        doors.append({"level": l, "left": d_left, "right": d_right, "open": false, "y_base": c_y})

func _on_sensor(body, level):
    if body.name == "Player":
        call_elevator(level)

func _on_sensor_exit(body, level):
    if body.name == "Player":
        close_door(level)

func call_elevator(level):
    target_y = level * l_offset
    for d in doors:
        if d.level != level:
            close_door(d.level)
    open_door(level)

func close_door(level):
    doors[level].open = false

func open_door(level):
    doors[level].open = true

func _physics_process(delta):
    # Move platform
    if current_y < target_y:
        current_y += SPEED * delta
        if current_y > target_y: current_y = target_y
    elif current_y > target_y:
        current_y -= SPEED * delta
        if current_y < target_y: current_y = target_y
        
    platform.global_position.y = current_y + 0.1
    
    # Optional update emission color based on movement
    var mat = platform.get_child(0).material_override
    if current_y == target_y:
        mat.emission = Color(0, 1, 0) # Green when arrived
    else:
        mat.emission = Color(1, 0, 0) # Red when moving
    
    # Move doors
    for d in doors:
        var target_left_x = -1.0
        var target_right_x = 1.0
        
        # Open doors if platform is arrived at this level AND doors are commanded open
        if d.open and abs(current_y - d.y_base) < 0.1:
            target_left_x = -2.8
            target_right_x = 2.8
            
        d.left.position.x = move_toward(d.left.position.x, target_left_x, 5.0 * delta)
        d.right.position.x = move_toward(d.right.position.x, target_right_x, 5.0 * delta)
