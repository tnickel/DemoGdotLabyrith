extends Node3D

const MAZE_W = 30
const MAZE_H = 30
const MAZE_L = 1
const C_SIZE = 5.0
const WALL_HEIGHT = 4.0
const L_OFFSET = 4.5 # WALL_HEIGHT + 0.5 floor thickness

var wall_mats = []
var painting_textures = []
var video_files = []
var mgr
var maze = []

var all_video_screens = []
var video_pool = []
var video_increment_index = 0
var all_monsters = []
const MAX_MONSTERS = 20
const MONSTER_ACTIVE_RANGE = 5 * 5.0  # 5 Zellen * C_SIZE

# MultiMesh accumulators: [floor_std, floor_hall, floor_vid, ceil]
var _mm_floors: Array = [[], [], [], []]
# Wall transforms: [4 mesh_types][4 zone_materials]
var _mm_walls: Array = []
var _mm_wall_meshes: Array = []  # BoxMesh refs: [wall_mesh, h_wall_mesh, hall_wall_mesh, h_hall_wall_mesh]
# Shared materials stored for _finalize_multimeshes
var _floor_mat = null
var _hall_floor_mat = null
var _video_carpet_mat = null
var _ceil_mat = null
var _tile_mesh = null
# Cached player reference to avoid find_child() every frame
var _player_cached: Node3D = null
var _collision_body_floor: StaticBody3D
var _collision_body_ceil: StaticBody3D
var _collision_body_walls: StaticBody3D
var _wall_coll_shapes: Array = []
var _neon_colors: Array = []
var _neon_mat_pool: Array = []
var _mm_neons: Array = []
var _mm_chevrons: Array = []
var _chevron_mesh: Mesh
var _chevron_mat: Material
var _neon_mesh: Mesh
var _mm_frames: Array = []
var _frame_mesh: Mesh
var _frame_mat: Material
var _perf_log: FileAccess = null
var _log_counter: int = 0
# Cached scene-tree counts (only updated every 60 ticks to avoid find_children() CPU-spikes)
var _cached_n_lights: int = 0
var _cached_n_meshes: int = 0
var _cached_n_mm: int = 0
var _cached_n_particles: int = 0
var _cached_n_vp: int = 0

var loading_ui: CanvasLayer = null
var progress_bar: ProgressBar = null

func _cp(n: String):
    var f = FileAccess.open("D:\\AntiGravitySoftware\\GitWorkspace\\DemoGdotLabyrith\\" + n + ".txt", FileAccess.WRITE)
    if f:
        f.store_line(n + " reached at " + str(Time.get_ticks_msec()))
        f.close()

func _ready():
    _cp("CP01_ready_start")
    
    # --- Performance Log File (CSV, opened early before any await) ---
    var log_path_abs = "D:\\AntiGravitySoftware\\GitWorkspace\\DemoGdotLabyrith\\laufzeitanalyse.log"
    _perf_log = FileAccess.open(log_path_abs, FileAccess.WRITE)
    if _perf_log:
        _perf_log.store_line("timestamp;fps;draw_calls;render_obj;nodes;videos;monsters_alive;monsters_total;player_x;player_y;player_z;active_monsters;chunk_cells;vsync")
        _perf_log.flush()
        _cp("CP02_log_ok")
    else:
        _cp("CP02_log_FAIL")
        
    var pt = Timer.new()
    pt.wait_time = 0.5
    pt.autostart = true
    pt.timeout.connect(func():
        var perf_lbl = get_node_or_null("PerfLayer/PerfLabel")
        var fps = Engine.get_frames_per_second()
        var dc  = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
        var ro  = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
        var nc  = get_tree().get_node_count()
        var mc = all_monsters.size()
        var mc_alive = 0
        var mc_active = 0
        for _m in all_monsters:
            if is_instance_valid(_m):
                mc_alive += 1
                if _m.is_physics_processing(): mc_active += 1

        if is_instance_valid(perf_lbl):
            var col = Color(0.1,1.0,0.3) if fps >= 55 else (Color(1.0,0.8,0.0) if fps >= 30 else Color(1.0,0.2,0.1))
            perf_lbl.add_theme_color_override("font_color", col)
            if mgr.show_perf_hud:
                var vsync_on = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
                perf_lbl.text = "FPS: %d  DrawCalls: %d  RenderObj: %d  VSync: %s\n" % [fps, dc, ro, "ON" if vsync_on else "OFF"]
                perf_lbl.text += "Nodes: %d  Monsters: %d/%d (active: %d)  Videos: %d" % [nc, mc_alive, mc, mc_active, all_video_screens.size()]
            else:
                perf_lbl.text = "FPS: %d" % fps
        
        _log_counter += 1
        if _log_counter % 4 == 0 and _perf_log:
            var p_pos = Vector3.ZERO
            if is_instance_valid(_player_cached):
                p_pos = _player_cached.global_position
            var v_on = 1 if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else 0
            _perf_log.store_line("%d;%d;%d;%d;%d;%d;%d;%d;%.1f;%.1f;%.1f;%d;%d;%d" % [
                Time.get_ticks_msec(), fps, dc, ro, nc,
                all_video_screens.size(), mc_alive, mc,
                p_pos.x, p_pos.y, p_pos.z, mc_active, mgr.chunk_cells, v_on
            ])
            _perf_log.flush()
        
        # --- Zentrale Video-Steuerung mit Ressourcen-Pool (O(n) alle 0.5s) ---
        if is_instance_valid(_player_cached) and video_pool.size() > 0:
            const MAX_VID_DIST = 15.0
            var cam = null
            var origin = _player_cached.get_node_or_null("XROrigin3D")
            if origin: cam = origin.get_node_or_null("XRCamera3D")
            if not cam: cam = _player_cached.get_node_or_null("Camera3D")
            
            var distances = []
            for i in range(all_video_screens.size()):
                var vs = all_video_screens[i]
                if not is_instance_valid(vs.inst): continue
                var d = vs.inst.global_position.distance_to(_player_cached.global_position)
                if d <= MAX_VID_DIST:
                    var is_looking = false
                    if is_instance_valid(cam):
                        var dir_to_vid = cam.global_position.direction_to(vs.inst.global_position)
                        var look_dir = -cam.global_transform.basis.z
                        if look_dir.dot(dir_to_vid) > 0.4:
                            is_looking = true
                    
                    # Wertung: Bild wird um 10 Meter priorisiert, wenn wir direkt draufschauen
                    var score = d - (10.0 if is_looking else 0.0)
                    distances.append({"idx": i, "dist": d, "score": score})
                    
            distances.sort_custom(func(a, b): return a.score < b.score)
            var active_indices = []
            if distances.size() > 0:
                active_indices.append(distances[0].idx) # Nur exakt EIN Video (das beste) abspielen!

            # Pool-Elemente aufraeumen (die nicht mehr in Reichweite sind)
            for p in video_pool:
                if p.assigned_to != -1 and not (p.assigned_to in active_indices):
                    p.player.stop()
                    p.vp.size = Vector2i(2,2)
                    p.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
                    var vs = all_video_screens[p.assigned_to]
                    if is_instance_valid(vs.mat):
                        vs.mat.albedo_texture = null
                        vs.mat.emission_texture = null
                        vs.mat.albedo_color = Color(0.01, 0.01, 0.01)
                    vs.pool_idx = -1
                    p.assigned_to = -1

            # Neue Videos zuweisen und Volume regeln
            for i in range(active_indices.size()):
                var idx = active_indices[i]
                var dist = distances[i].dist
                var vs = all_video_screens[idx]
                
                # Zuweisen falls noch nicht geschehen
                if vs.pool_idx == -1:
                    for p in video_pool:
                        if p.assigned_to == -1:
                            p.assigned_to = idx
                            vs.pool_idx = video_pool.find(p)
                            if p.player.stream.file != vs.video_path:
                                var new_stream = VideoStreamTheora.new()
                                new_stream.file = vs.video_path
                                p.player.stream = new_stream
                            p.player.play()
                            p.vp.size = Vector2i(1280, 720)
                            p.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
                            var vp_tex = p.vp.get_texture()
                            if is_instance_valid(vs.mat):
                                vs.mat.albedo_texture = vp_tex
                                vs.mat.emission_texture = vp_tex
                                vs.mat.albedo_color = Color(1.0, 1.0, 1.0)
                            break
                            
                # Lautstaerke für zugewiesenes Video updaten
                if vs.pool_idx != -1:
                    var p = video_pool[vs.pool_idx]
                    var ratio = clamp(1.0 - (dist / MAX_VID_DIST), 0.0, 1.0)
                    p.player.volume_db = lerp(-60.0, 5.0, ratio)
    )
    add_child(pt)
    
    const MAX_TEXTURES = 30  # 96 Bilder laden dauert ~17s – wir brauchen nur 30
    var gallery_path = "res://gallery/"
    var dir = DirAccess.open(gallery_path)
    if dir:
        var all_files = []
        for file in dir.get_files():
            if file.ends_with(".import"): continue
            var ext = file.get_extension().to_lower()
            if ext == "png" or ext == "jpg" or ext == "jpeg":
                all_files.append(file)
        all_files.shuffle()  # Zufaellige Auswahl damit jeder Run anders aussieht
        for file in all_files:
            if painting_textures.size() >= MAX_TEXTURES: break
            # Nutzt Godots rasend schnellen internen Resource-Loader (laedt die `.import` Vorkompilierung)
            # statt das JPG jedes mal muehsam manuell am CPU zu dekodieren!
            var tex = load(gallery_path + file)
            if tex and tex is Texture2D:
                painting_textures.append(tex)

    
    var video_path = "res://gallery_video/"
    var v_dir = DirAccess.open(video_path)
    if v_dir:
        for file in v_dir.get_files():
            if file.get_extension().to_lower() == "ogv":
                video_files.append(video_path + file)
                
    # Initialisiere 12 statische Video-Player für ganzes Spiel (Video Pool)
    for i in range(12):
        var vp = SubViewport.new()
        vp.size = Vector2i(2, 2)
        vp.disable_3d = true
        var player = VideoStreamPlayer.new()
        player.expand = true
        player.loop = true
        player.volume_db = -80.0
        player.anchor_right = 1.0
        player.anchor_bottom = 1.0
        player.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var stream = VideoStreamTheora.new()
        player.stream = stream
        vp.add_child(player)
        add_child(vp)
        video_pool.append({"vp": vp, "player": player, "assigned_to": -1})
    
    if painting_textures.size() == 0:
        var tex_dir = DirAccess.open("res://textures/")
        if tex_dir:
            for file in tex_dir.get_files():
                if file.begins_with("landscape_") and file.ends_with(".jpg"):
                    painting_textures.append(load("res://textures/" + file))
    
    mgr = get_node("/root/SettingsManager")
    mgr.apply_graphics_settings()
    mgr.settings_updated.connect(_on_settings_updated)
    
    # 4 Zone Materials
    var wall_noise = FastNoiseLite.new()
    wall_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    wall_noise.frequency = 0.05
    var wall_tex = NoiseTexture2D.new()
    wall_tex.noise = wall_noise
    wall_tex.width = 512; wall_tex.height = 512
    wall_tex.as_normal_map = true; wall_tex.bump_strength = 0.5
    var albedo_tex = NoiseTexture2D.new()
    albedo_tex.noise = wall_noise
    albedo_tex.width = 512; albedo_tex.height = 512
    
    for i in range(4):
        var mat = StandardMaterial3D.new()
        mat.normal_enabled = true
        mat.normal_texture = wall_tex
        mat.albedo_texture = albedo_tex
        mat.uv1_scale = Vector3(2, 2, 2)
        if i == 0: mat.albedo_color = Color(0.2, 0.4, 0.8)
        elif i == 1: mat.albedo_color = Color(0.5, 0.2, 0.2)
        elif i == 2: mat.albedo_color = Color(0.2, 0.6, 0.2)
        elif i == 3: mat.albedo_color = Color(0.8, 0.7, 0.2)
        mat.metallic = 0.6   # war 1.0 - zu hoher Specular-Aufwand
        mat.roughness = 0.3  # war 0.05 - Mirror-Wände sind GPU-teuer
        wall_mats.append(mat)
        
    _update_lighting()
    
    # 1. Spawning Loading Screen immediately
    loading_ui = CanvasLayer.new()
    loading_ui.layer = 100
    var bg = ColorRect.new()
    bg.color = Color(0, 0, 0, 1)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading_ui.add_child(bg)
    
    progress_bar = ProgressBar.new()
    progress_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    progress_bar.custom_minimum_size = Vector2(400, 30)
    bg.add_child(progress_bar)
    
    var lbl = Label.new()
    lbl.text = "Generating High-Fidelity Geometry..."
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    lbl.position.y -= 40
    progress_bar.add_child(lbl)
    
    add_child(loading_ui)
    
    var p = get_tree().root.find_child("Player", true, false)
    if p: p.set_physics_process(false) # Freeze player to prevent falling before floor spawns
    
    _cp("CP03_before_await")
    await get_tree().process_frame # Let Godot draw the loading screen once
    
    _cp("CP04_after_await")
    print("[MAZE] Starting async generation... t=", Time.get_ticks_msec())
    await generate_maze()
    _cp("CP05_maze_generated")
    print("[MAZE] Generation done. t=", Time.get_ticks_msec())
    
    # NavMesh DISABLED - caused main thread freeze on large mazes
    # (Baking traverses all StaticBody3D children which is very slow)
    
    print("[MAZE] Adding DamageVignette... t=", Time.get_ticks_msec())
    var VignetteClass = preload("res://DamageVignette.gd")
    var vignette = VignetteClass.new()
    vignette.name = "DamageVignette"
    add_child(vignette)
    
    print("[MAZE] Adding Minimap... t=", Time.get_ticks_msec())
    var minimap_layer = CanvasLayer.new()
    add_child(minimap_layer)
    var MinimapClass = preload("res://MinimapUI.gd")
    var minimap = MinimapClass.new()
    minimap.maze_ref = maze
    minimap.c_size = C_SIZE
    minimap.maze_w = MAZE_W
    minimap.maze_h = MAZE_H
    minimap_layer.add_child(minimap)
    print("[MAZE] All done. t=", Time.get_ticks_msec())
    
    _cp("CP06_before_player_pos")
    _player_cached = get_tree().root.find_child("Player", true, false)
    
    if p:
        var found = false
        for x in range(MAZE_W):
            for z in range(MAZE_H):
                if maze[0][x][z].has_statue:
                    p.global_position = Vector3(x * C_SIZE, 2.0, z * C_SIZE + 2.0)
                    p.velocity = Vector3.ZERO
                    p.set_physics_process(true)
                    found = true
                    break
            if found: break
        
    loading_ui.queue_free()
    _cp("CP07_loading_freed")

    # --- FPS / Performance Overlay (alle 0.5s aktualisiert) ---
    var perf_layer = CanvasLayer.new()
    perf_layer.layer = 200
    perf_layer.name = "PerfLayer"
    add_child(perf_layer)
    var perf_lbl = Label.new()
    perf_lbl.name = "PerfLabel"
    perf_lbl.position = Vector2(10, 10)
    perf_lbl.add_theme_color_override("font_color", Color(0.1, 1.0, 0.3))
    perf_lbl.add_theme_font_size_override("font_size", 14)
    perf_layer.add_child(perf_lbl)
    _cp("CP08_perf_overlay_ready")
    
    # Show log status in HUD briefly
    if _perf_log:
        perf_lbl.text = "LOG OK: " + log_path_abs
    else:
        perf_lbl.text = "LOG FAILED!"
        perf_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.1))
    # Timer was moved to top of file

func instantiate_player(start_cell):
    maze = []
    for l in range(MAZE_L):
        var level = []
        for x in range(MAZE_W):
            var row = []

func generate_maze():
    _cp("CP_GEN_start")
    maze = []
    for l in range(MAZE_L):
        var level = []
        for x in range(MAZE_W):
            var row = []
            for z in range(MAZE_H):
                row.append({"pos": Vector3(x, l, z), "visited": false, "N": true, "E": true, "S": true, "W": true, "U": false, "D": false, "is_hall": false, "is_vid_corr": false, "type": "corridor", "dist": 999999, "path_to": null, "hall_theme": -1, "has_statue": false})
            level.append(row)
        maze.append(level)
        
    var stack = [Vector3(0, 0, 0)]
    maze[0][0][0].visited = true
    _cp("CP_GEN_maze_init_done")
    
    while stack.size() > 0:
        var curr = stack[stack.size() - 1]
        var x = int(curr.x); var l = int(curr.y); var z = int(curr.z)
        
        var unvisited = []
        if z > 0 and not maze[l][x][z-1].visited: unvisited.append({"dir": "N", "pos": Vector3(x, l, z-1)})
        if z < MAZE_H - 1 and not maze[l][x][z+1].visited: unvisited.append({"dir": "S", "pos": Vector3(x, l, z+1)})
        if x < MAZE_W - 1 and not maze[l][x+1][z].visited: unvisited.append({"dir": "E", "pos": Vector3(x+1, l, z)})
        if x > 0 and not maze[l][x-1][z].visited: unvisited.append({"dir": "W", "pos": Vector3(x-1, l, z)})
        
        if unvisited.size() > 0:
            var next_cell = unvisited[randi() % unvisited.size()]
            var nx = int(next_cell.pos.x); var nz = int(next_cell.pos.z)
            maze[l][nx][nz].visited = true
            
            if next_cell.dir == "N":
                maze[l][x][z].N = false; maze[l][nx][nz].S = false
            elif next_cell.dir == "S":
                maze[l][x][z].S = false; maze[l][nx][nz].N = false
            elif next_cell.dir == "E":
                maze[l][x][z].E = false; maze[l][nx][nz].W = false
            elif next_cell.dir == "W":
                maze[l][x][z].W = false; maze[l][nx][nz].E = false
                
            stack.append(next_cell.pos)
        else:
            stack.pop_back()

    _cp("CP_GEN_dfs_done")

    # Create 3 large Video Corridors
    for i in range(3):
        var is_horizontal = randf() > 0.5
        var w = 15 if is_horizontal else 1
        var d = 1 if is_horizontal else 15
        var hx = randi() % (MAZE_W - w - 1) + 1
        var hz = randi() % (MAZE_H - d - 1) + 1
        
        for x in range(hx, hx + w):
            for z in range(hz, hz + d):
                maze[0][x][z].is_vid_corr = true
                maze[0][x][z].is_hall = false # explicitly false so it gets standard hall settings
                maze[0][x][z].N = false; maze[0][x][z].S = false
                maze[0][x][z].E = false; maze[0][x][z].W = false
                # Bound the corridor walls strongly
                if x == hx: maze[0][x][z].W = true
                if x == hx + w - 1: maze[0][x][z].E = true
                if z == hz: maze[0][x][z].N = true
                if z == hz + d - 1: maze[0][x][z].S = true
        
        # Punch holes at the ends to connect to the rest of the maze
        if is_horizontal:
            if hx > 1: 
                maze[0][hx][hz].W = false
                maze[0][hx-1][hz].E = false
            if hx + w < MAZE_W - 1: 
                maze[0][hx+w-1][hz].E = false
                maze[0][hx+w][hz].W = false
        else:
            if hz > 1: 
                maze[0][hx][hz].N = false
                maze[0][hx][hz-1].S = false
            if hz + d < MAZE_H - 1: 
                maze[0][hx][hz+d-1].S = false
                maze[0][hx][hz+d].N = false

    # Create large regular halls
    for i in range(8):
        var w = randi() % 3 + 3
        var d = randi() % 3 + 3
        var hx = randi() % (MAZE_W - w - 1) + 1
        var hz = randi() % (MAZE_H - d - 1) + 1
        var th = randi() % 3
        
        for x in range(hx, hx + w):
            for z in range(hz, hz + d):
                if not maze[0][x][z].is_vid_corr:
                    maze[0][x][z].is_hall = true
                    maze[0][x][z].hall_theme = th
                    if x > hx: maze[0][x][z].W = false; maze[0][x-1][z].E = false
                    if z > hz: maze[0][x][z].N = false; maze[0][x][z-1].S = false
                    if x == hx + w / 2 and z == hz + d / 2:
                        maze[0][x][z].has_statue = true

    print("[MAZE] Carving done. t=", Time.get_ticks_msec())
    compute_hall_paths(maze)
    print("[MAZE] Paths done. t=", Time.get_ticks_msec())
    _cp("CP_GEN_before_build")
    await build_physical_maze(maze)
    _cp("CP_GEN_after_build")
    print("[MAZE] Build done. t=", Time.get_ticks_msec())

func compute_hall_paths(maze):
    var queue = []
    
    for l in range(MAZE_L):
        for x in range(MAZE_W):
            for z in range(MAZE_H):
                if maze[l][x][z].is_hall:
                    maze[l][x][z].dist = 0
                    queue.append(Vector3(x, l, z))
                    
    var head = 0
    while head < queue.size():
        var curr = queue[head]
        head += 1
        var x = int(curr.x); var l = int(curr.y); var z = int(curr.z)
        var d = maze[l][x][z].dist
        var c = maze[l][x][z]
        
        var neighbors = []
        if not c.N: neighbors.append(Vector3(x, l, z-1))
        if not c.S: neighbors.append(Vector3(x, l, z+1))
        if not c.E: neighbors.append(Vector3(x+1, l, z))
        if not c.W: neighbors.append(Vector3(x-1, l, z))
        
        for n in neighbors:
            var nx = int(n.x); var nl = int(n.y); var nz = int(n.z)
            if maze[nl][nx][nz].dist > d + 1:
                maze[nl][nx][nz].dist = d + 1
                maze[nl][nx][nz].path_to = curr
                queue.append(n)

func build_physical_maze(maze):
    _cp("CP_BUILD_start")
    var total_cells = MAZE_L * MAZE_W * MAZE_H
    var computed = 0
    var wall_thick = 0.5
    var HALL_HEIGHT = WALL_HEIGHT * 3.0
    var wall_mesh = BoxMesh.new()
    wall_mesh.size = Vector3(C_SIZE, WALL_HEIGHT, wall_thick)
    var h_wall_mesh = BoxMesh.new()
    h_wall_mesh.size = Vector3(wall_thick, WALL_HEIGHT, C_SIZE)
    var hall_wall_mesh = BoxMesh.new()
    hall_wall_mesh.size = Vector3(C_SIZE, HALL_HEIGHT, wall_thick)
    var h_hall_wall_mesh = BoxMesh.new()
    h_hall_wall_mesh.size = Vector3(wall_thick, HALL_HEIGHT, C_SIZE)
    
    var floor_mat = StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.2, 0.2, 0.25)
    floor_mat.metallic = 0.8
    floor_mat.roughness = 0.2
    
    # Dark specular marble floor for halls
    var hall_floor_mat = ShaderMaterial.new()
    var marble_shader = Shader.new()
    # ... Skipped marble shader text
    
    var video_carpet_mat = ShaderMaterial.new()
    var green_marble_shader = Shader.new()
    green_marble_shader.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.05, 0.28, 0.15, 1.0);
void fragment() {
    vec2 uv = UV * 10.0;
    float m = sin(uv.x * 2.5 + sin(uv.y * 3.14) * 2.5) * 0.5 + 0.5;
    m = pow(m, 1.8);
    vec3 veining = vec3(0.02, 0.05, 0.02);
    vec3 col = mix(veining, base_color.rgb, m);
    ALBEDO = col;
    METALLIC = 0.9;
    ROUGHNESS = 0.05;
    SPECULAR = 1.0;
}
"""
    video_carpet_mat.shader = green_marble_shader
    marble_shader.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.06, 0.07, 0.09, 1.0);
void fragment() {
    vec2 uv = UV * 6.0;
    float m = sin(uv.x * 3.14 + sin(uv.y * 2.5) * 3.0) * 0.5 + 0.5;
    m = pow(m, 1.5);
    vec3 dark = base_color.rgb * 0.3;
    vec3 col = mix(dark, base_color.rgb, m);
    ALBEDO = col;
    METALLIC = 0.95;
    ROUGHNESS = 0.02;
    SPECULAR = 1.0;
}
"""
    hall_floor_mat.shader = marble_shader
    
    var ceil_mat = StandardMaterial3D.new()
    ceil_mat.albedo_color = Color(0.05, 0.05, 0.05)
    ceil_mat.metallic = 0.8; ceil_mat.roughness = 0.4
    
    var tile_mesh = PlaneMesh.new()
    tile_mesh.size = Vector2(C_SIZE, C_SIZE)
    var f_shape = BoxShape3D.new()
    f_shape.size = Vector3(C_SIZE, 0.1, C_SIZE)
    
    var neon_mesh = CylinderMesh.new()
    neon_mesh.top_radius = 0.1; neon_mesh.bottom_radius = 0.1; neon_mesh.height = 2.5
    
    # Store shared refs for _finalize_multimeshes
    _tile_mesh = tile_mesh
    _floor_mat = floor_mat
    _hall_floor_mat = hall_floor_mat
    _video_carpet_mat = video_carpet_mat
    _ceil_mat = ceil_mat
    _mm_wall_meshes = [wall_mesh, h_wall_mesh, hall_wall_mesh, h_hall_wall_mesh]
    _mm_floors = [[], [], [], []]
    _mm_walls = []
    for _mt in range(4):
        var zone_list = []
        for _z in range(4):
            zone_list.append([])
        _mm_walls.append(zone_list)
    
    # Shared collision bodies (merge thousands of StaticBody3D into 3)
    _collision_body_floor = StaticBody3D.new()
    _collision_body_floor.name = "FloorCollisions"
    _collision_body_ceil = StaticBody3D.new()
    _collision_body_ceil.name = "CeilCollisions"
    _collision_body_walls = StaticBody3D.new()
    _collision_body_walls.name = "WallCollisions"
    _wall_coll_shapes = []
    for wm in _mm_wall_meshes:
        var ws = BoxShape3D.new()
        ws.size = wm.size
        _wall_coll_shapes.append(ws)
    
    # Neon material pool (12 shared colors for MultiMesh batching)
    _neon_mesh = neon_mesh
    _neon_colors = [
        Color(1.0, 0.3, 0.3), Color(0.3, 1.0, 0.4), Color(0.3, 0.5, 1.0),
        Color(1.0, 0.85, 0.2), Color(0.8, 0.3, 1.0), Color(0.3, 1.0, 1.0),
        Color(1.0, 0.55, 0.1), Color(0.5, 1.0, 0.3), Color(1.0, 0.3, 0.7),
        Color(0.4, 0.8, 1.0), Color(1.0, 1.0, 0.4), Color(0.7, 0.4, 1.0)
    ]
    _neon_mat_pool = []
    _mm_neons = []
    for nc in _neon_colors:
        var nmat = StandardMaterial3D.new()
        nmat.albedo_color = nc
        nmat.emission_enabled = true
        nmat.emission = nc
        nmat.emission_energy_multiplier = 4.0
        _neon_mat_pool.append(nmat)
        _mm_neons.append([])
    
    # Chevron mesh + material (shared for MultiMesh)
    _chevron_mesh = PrismMesh.new()
    _chevron_mesh.left_to_right = 0.5
    _chevron_mesh.size = Vector3(0.5, 0.66, 0.05)
    _chevron_mat = StandardMaterial3D.new()
    _chevron_mat.albedo_color = Color(0, 1.0, 0.8)
    _chevron_mat.emission_enabled = true
    _chevron_mat.emission = Color(0, 1.0, 0.8)
    _chevron_mat.emission_energy_multiplier = 4.0
    _mm_chevrons = []
    
    _frame_mesh = BoxMesh.new()
    _frame_mesh.size = Vector3(1.0, 1.0, 1.0)
    _frame_mat = StandardMaterial3D.new()
    _frame_mat.albedo_color = Color(0.8, 0.0, 0.0) # Shiny metallic red
    _frame_mat.metallic = 1.0
    _frame_mat.roughness = 0.1
    _mm_frames = []
    
    _cp("CP_BUILD_before_loop")
    print("Spawning cells...")
    for l in range(MAZE_L):
        print("Floor ", l)
        var y_base = l * L_OFFSET
        for x in range(MAZE_W):
            for z in range(MAZE_H):
                if computed % 50 == 0:
                    print("Progress: ", computed, "/", total_cells)
                var px = x * C_SIZE
                var pz = z * C_SIZE
                var cell = maze[l][x][z]
                var zone_idx = (x/(MAZE_W/2)) + 2*(z/(MAZE_H/2))
                var c_mat = wall_mats[zone_idx]
                
                # Floors and Ceilings — MultiMesh: collect transforms, spawn collision separately
                var eff_height = HALL_HEIGHT if cell.is_hall else WALL_HEIGHT
                
                if not (cell.D and cell.type == "elevator") and not (cell.type == "stairs" and cell.D):
                    # Floor → collect into MultiMesh group
                    var fi = 0
                    if cell.is_hall: fi = 1
                    if cell.is_vid_corr: fi = 2
                    _mm_floors[fi].append(Transform3D(Basis.IDENTITY, Vector3(px, y_base, pz)))
                    # Floor collision (merged into shared StaticBody3D)
                    var f_coll = CollisionShape3D.new()
                    f_coll.shape = f_shape
                    f_coll.position = Vector3(px, y_base, pz)
                    _collision_body_floor.add_child(f_coll)
                    
                if not (cell.U and cell.type == "elevator") and not (cell.type == "stairs" and cell.U):
                    # Ceiling → collect into MultiMesh group (index 3), rotated 180° around X
                    var ceil_basis = Basis(Vector3(1, 0, 0), PI)
                    _mm_floors[3].append(Transform3D(ceil_basis, Vector3(px, y_base + eff_height, pz)))
                    # Ceiling collision (merged into shared StaticBody3D)
                    var c_coll = CollisionShape3D.new()
                    c_coll.shape = f_shape
                    c_coll.position = Vector3(px, y_base + eff_height, pz)
                    _collision_body_ceil.add_child(c_coll)
                    
                # Walls - Use taller meshes for hall cells OR cells adjacent to a hall
                var north_is_hall = (z > 0 and maze[l][x][z-1].is_hall)
                var south_is_hall = (z < MAZE_H-1 and maze[l][x][z+1].is_hall)
                var west_is_hall  = (x > 0 and maze[l][x-1][z].is_hall)
                var east_is_hall  = (x < MAZE_W-1 and maze[l][x+1][z].is_hall)
                var wall_n = hall_wall_mesh   if (cell.is_hall or north_is_hall) else wall_mesh
                var wall_s = hall_wall_mesh   if (cell.is_hall or south_is_hall) else wall_mesh
                var wall_w = h_hall_wall_mesh if (cell.is_hall or west_is_hall)  else h_wall_mesh
                var wall_e = h_hall_wall_mesh if (cell.is_hall or east_is_hall)  else h_wall_mesh
                var wall_y_n = y_base + (HALL_HEIGHT if (cell.is_hall or north_is_hall) else WALL_HEIGHT) / 2.0
                var wall_y_s = y_base + (HALL_HEIGHT if (cell.is_hall or south_is_hall) else WALL_HEIGHT) / 2.0
                var wall_y_w = y_base + (HALL_HEIGHT if (cell.is_hall or west_is_hall)  else WALL_HEIGHT) / 2.0
                var wall_y_e = y_base + (HALL_HEIGHT if (cell.is_hall or east_is_hall)  else WALL_HEIGHT) / 2.0
                if cell.N: create_wall(Vector3(px, wall_y_n, pz - C_SIZE/2.0), wall_n, c_mat, Vector3(0, 0, 1), cell, zone_idx)
                if cell.S: create_wall(Vector3(px, wall_y_s, pz + C_SIZE/2.0), wall_s, c_mat, Vector3(0, 0, -1), cell, zone_idx)
                if cell.W: create_wall(Vector3(px - C_SIZE/2.0, wall_y_w, pz), wall_w, c_mat, Vector3(1, 0, 0), cell, zone_idx)
                if cell.E: create_wall(Vector3(px + C_SIZE/2.0, wall_y_e, pz), wall_e, c_mat, Vector3(-1, 0, 0), cell, zone_idx)
                # Neons
                if randf() > (1.0 - mgr.neon_density):
                    spawn_neon(px, y_base, pz, cell.is_hall)
                    
                # Monsters
                if x <= 1 and z <= 1: continue # spawn protect
                if mgr.monster_density > 0.0 and all_monsters.size() < MAX_MONSTERS and randf() > (1.0 - mgr.monster_density):
                    var m
                    if randf() > 0.5:
                        var MonsterClass = preload("res://Monster.gd")
                        m = MonsterClass.new()
                        m.position = Vector3(px, y_base + 1.0, pz)
                    else:
                        var HumanClass = preload("res://Human.gd")
                        m = HumanClass.new()
                        m.position = Vector3(px, y_base + 0.0, pz)
                    m.set_physics_process(false)  # Start frozen, proximity activates
                    add_child(m)
                    all_monsters.append(m)

                # Abstract Statues
                if cell.get("has_statue", false):
                    var StatueClass = preload("res://AbstractStatue.gd")
                    var st = StatueClass.new()
                    st.position = Vector3(px, y_base, pz)
                    add_child(st)

                # Runway Path
                if not cell.is_hall and cell.path_to != null and cell.dist > 1:
                    create_floor_chevron(px, y_base, pz, cell)
                    
                # GPU Particle dust in halls
                if cell.is_hall and randf() > 0.6:
                    spawn_hall_particles(px, y_base, pz)
                    
                # Ambient twilight light
                if cell.is_hall:
                    spawn_hall_ambient(px, y_base, pz)
                    
                # Portal arches at hall boundary exits
                if cell.is_hall and cell.get("portal_facing", "") != "":
                    var pf = cell.portal_facing
                    var fvec = Vector3(0, 0, -1)
                    if pf == "S": fvec = Vector3(0, 0, 1)
                    elif pf == "E": fvec = Vector3(1, 0, 0)
                    elif pf == "W": fvec = Vector3(-1, 0, 0)
                    spawn_portal_arch(Vector3(px, y_base, pz), fvec, c_mat)

                computed += 1
            if is_instance_valid(progress_bar):
                progress_bar.value = (float(computed) / total_cells) * 100.0
            if x % 5 == 0:
                _cp("CP_LOOP_x" + str(x))  # Fortschritt-Checkpoint jede 5. Spalte
                await get_tree().process_frame
    
    _cp("CP_BUILD_loop_done")
    
    # Add fully constructed collision bodies to tree at once
    _cp("CP_COLL_before_floor")
    add_child(_collision_body_floor)
    _cp("CP_COLL_after_floor")
    add_child(_collision_body_ceil)
    _cp("CP_COLL_after_ceil")
    add_child(_collision_body_walls)
    _cp("CP_COLL_after_walls")
    
    # Build all MultiMesh batches in one go after the loop
    _cp("CP_MM_before_finalize")
    _finalize_multimeshes()
    _cp("CP_MM_after_finalize")

func _chunk_key(pos: Vector3) -> Vector2i:
    ## Map a world position to a chunk grid coordinate
    var cx = int(int(pos.x / C_SIZE) / int(mgr.chunk_cells))
    var cz = int(int(pos.z / C_SIZE) / int(mgr.chunk_cells))
    return Vector2i(clampi(cx, 0, 99), clampi(cz, 0, 99))

func _chunk_aabb(ck: Vector2i) -> AABB:
    ## Return the axis-aligned bounding box for a chunk (with padding)
    var pad = C_SIZE
    var x0 = ck.x * mgr.chunk_cells * C_SIZE - pad
    var z0 = ck.y * mgr.chunk_cells * C_SIZE - pad
    var w  = mgr.chunk_cells * C_SIZE + pad * 2
    var h  = WALL_HEIGHT * 3.0 + 2.0
    return AABB(Vector3(x0, -0.5, z0), Vector3(w, h, w))

func _build_chunked_mm(transforms: Array, mesh: Mesh, mat: Material, base_name: String):
    ## Split transforms into spatial chunks and create one MultiMeshInstance3D per chunk
    if transforms.size() == 0: return
    var buckets: Dictionary = {}   # Vector2i -> Array[Transform3D]
    for xform in transforms:
        var ck = _chunk_key(xform.origin)
        if not buckets.has(ck): buckets[ck] = []
        buckets[ck].append(xform)
    for ck in buckets:
        var arr = buckets[ck]
        var mm = MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = mesh
        mm.instance_count = arr.size()
        for i in range(arr.size()):
            mm.set_instance_transform(i, arr[i])
        var mmi = MultiMeshInstance3D.new()
        mmi.multimesh = mm
        mmi.material_override = mat
        mmi.custom_aabb = _chunk_aabb(ck)
        mmi.name = base_name + "_c" + str(ck.x) + "_" + str(ck.y)
        add_child(mmi)

func _finalize_multimeshes():
    _cp("CP_FIN_start")
    print("[MAZE] Building chunked MultiMesh batches...")
    var floor_mats = [_floor_mat, _hall_floor_mat, _video_carpet_mat, _ceil_mat]
    var floor_names = ["floor_std", "floor_hall", "floor_vid", "ceil"]
    
    # Floors + Ceilings (chunked)
    for fi in range(4):
        _build_chunked_mm(_mm_floors[fi], _tile_mesh, floor_mats[fi], "MM_" + floor_names[fi])
        if _mm_floors[fi].size() > 0:
            print("[MAZE] MM ", floor_names[fi], ": ", _mm_floors[fi].size(), " instances (chunked)")
    
    # Walls (chunked by mesh_type × zone_material)
    var wall_type_names = ["wall_NS", "wall_EW", "hall_NS", "hall_EW"]
    for mt in range(4):
        for zone in range(4):
            _build_chunked_mm(_mm_walls[mt][zone], _mm_wall_meshes[mt], wall_mats[zone],
                "MM_" + wall_type_names[mt] + "_z" + str(zone))
    
    # Neons (chunked by color)
    for ci in range(_neon_colors.size()):
        _build_chunked_mm(_mm_neons[ci], _neon_mesh, _neon_mat_pool[ci], "MM_neon_" + str(ci))
        if _mm_neons[ci].size() > 0:
            print("[MAZE] MM neon color ", ci, ": ", _mm_neons[ci].size(), " instances (chunked)")
    
    # Chevrons (chunked)
    _build_chunked_mm(_mm_chevrons, _chevron_mesh, _chevron_mat, "MM_chevrons")
    if _mm_chevrons.size() > 0:
        print("[MAZE] MM chevrons: ", _mm_chevrons.size(), " instances (chunked)")
        
    # Frames (chunked)
    _build_chunked_mm(_mm_frames, _frame_mesh, _frame_mat, "MM_frames")
    if _mm_frames.size() > 0:
        print("[MAZE] MM frames: ", _mm_frames.size(), " instances (chunked)")
    
    print("[MAZE] MultiMesh finalized (chunked).")
    # Free accumulators
    _mm_floors.clear()
    _mm_walls.clear()
    _mm_neons.clear()
    _mm_chevrons.clear()
    _mm_frames.clear()

func spawn_hall_particles(px: float, y_base: float, pz: float):
    var particles = GPUParticles3D.new()
    particles.position = Vector3(px, y_base + WALL_HEIGHT * 2.0, pz)
    particles.amount = 24
    particles.lifetime = 6.0
    particles.explosiveness = 0.0
    particles.randomness = 1.0
    particles.visibility_aabb = AABB(Vector3(-10,-8,-10), Vector3(20,16,20))
    
    var pm = ParticleProcessMaterial.new()
    pm.spread = 180.0
    pm.initial_velocity_min = 0.0
    pm.initial_velocity_max = 0.3
    pm.gravity = Vector3(0, -0.03, 0)
    pm.scale_min = 0.02; pm.scale_max = 0.08
    pm.color = Color(1.0, 0.9, 0.6, 0.4)
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    pm.emission_box_extents = Vector3(C_SIZE/2.0, 2.0, C_SIZE/2.0)
    particles.process_material = pm
    
    var quad = QuadMesh.new()
    quad.size = Vector2(0.06, 0.06)
    var pmat = StandardMaterial3D.new()
    pmat.albedo_color = Color(1.0, 0.95, 0.7, 0.6)
    pmat.emission_enabled = true
    pmat.emission = Color(1.0, 0.85, 0.5)
    pmat.emission_energy_multiplier = 2.0
    pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    quad.material = pmat
    particles.draw_pass_1 = quad
    add_child(particles)

func spawn_hall_ambient(px: float, y_base: float, pz: float):
    # Twilight ambient light to softly illuminate walls
    var a_light = OmniLight3D.new()
    a_light.position = Vector3(px, y_base + 3.0, pz)
    a_light.light_color = Color(0.15, 0.25, 0.5) # Twilight Blue
    a_light.light_energy = 0.35
    a_light.omni_range = C_SIZE * 5.0
    a_light.shadow_enabled = false
    add_child(a_light)

func spawn_portal_arch(cell_pos: Vector3, facing: Vector3, mat: Material):
    var arch_color = Color(0.0, 0.8, 1.0)
    var arch_mat = StandardMaterial3D.new()
    arch_mat.albedo_color = arch_color
    arch_mat.emission_enabled = true; arch_mat.emission = arch_color
    arch_mat.emission_energy_multiplier = 3.0
    
    var side = facing.cross(Vector3.UP).normalized()
    var half_w = C_SIZE / 2.0 - 0.3
    var arch_h = WALL_HEIGHT * 3.0
    
    var base = cell_pos + facing * (C_SIZE / 2.0 - 0.1)
    
    # Left pillar
    for i in range(2):
        var sign = 1.0 if i == 0 else -1.0
        var pillar = MeshInstance3D.new()
        pillar.mesh = BoxMesh.new(); pillar.mesh.size = Vector3(0.25, arch_h, 0.25)
        pillar.material_override = arch_mat
        pillar.position = base + side * sign * half_w + Vector3(0, arch_h/2.0, 0)
        add_child(pillar)
    # Top beam
    var beam = MeshInstance3D.new()
    beam.mesh = BoxMesh.new(); beam.mesh.size = Vector3(C_SIZE + 0.25, 0.25, 0.25)
    if facing.z != 0: beam.mesh.size = Vector3(0.25, 0.25, C_SIZE)
    beam.material_override = arch_mat
    beam.position = base + Vector3(0, arch_h + 0.1, 0)
    add_child(beam)
    
    # Corner spark particles
    for i in range(4):
        var cx = int(i < 2) * 2 - 1
        var cy = int(i % 2 == 0) * 2 - 1
        var sp = GPUParticles3D.new()
        sp.position = base + side * cx * half_w + Vector3(0, arch_h * (0.5 + cy * 0.45), 0)
        sp.amount = 6; sp.lifetime = 0.8; sp.explosiveness = 0.0
        var pm = ParticleProcessMaterial.new()
        pm.spread = 60.0; pm.initial_velocity_min = 0.5; pm.initial_velocity_max = 1.5
        pm.gravity = Vector3(0, -3, 0); pm.scale_min = 0.03; pm.scale_max = 0.08
        pm.color = arch_color
        sp.process_material = pm
        var qm = QuadMesh.new(); qm.size = Vector2(0.05, 0.05)
        var qmat = StandardMaterial3D.new()
        qmat.albedo_color = arch_color; qmat.emission_enabled = true; qmat.emission = arch_color
        qmat.emission_energy_multiplier = 5.0; qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
        qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; qm.material = qmat
        sp.draw_pass_1 = qm; add_child(sp)

func spawn_neon(px, y_base, pz, is_hall: bool = false):
    var lamp_y = (y_base + WALL_HEIGHT * 3.0 - 0.5) if is_hall else (y_base + WALL_HEIGHT - 0.2)
    var color_idx = randi() % _neon_mat_pool.size()
    var nc = _neon_colors[color_idx]
    # Accumulate transform for MultiMesh batching (no individual MeshInstance3D)
    var rot_x = randf() > 0.5
    var basis = Basis(Vector3(1, 0, 0), deg_to_rad(90)) if rot_x else Basis(Vector3(0, 0, 1), deg_to_rad(90))
    _mm_neons[color_idx].append(Transform3D(basis, Vector3(px, lamp_y, pz)))
    # Light remains individual (lights don't cause draw calls)
    var omni = OmniLight3D.new()
    var l_range = C_SIZE * 1.8 if not is_hall else C_SIZE * 3.0
    omni.light_color = nc; omni.light_energy = 2.5; omni.shadow_enabled = false; omni.omni_range = l_range
    omni.position = Vector3(px, lamp_y, pz)
    add_child(omni)

func create_wall(pos: Vector3, mesh: Mesh, mat: Material, facing: Vector3, cell: Dictionary, zone_idx: int):
    # Determine mesh type index for MultiMesh grouping
    var mesh_type = 0
    if _mm_wall_meshes.size() == 4:
        if mesh == _mm_wall_meshes[1]: mesh_type = 1
        elif mesh == _mm_wall_meshes[2]: mesh_type = 2
        elif mesh == _mm_wall_meshes[3]: mesh_type = 3
    
    # Decide painting BEFORE creating anything
    var theme = cell.get("hall_theme", -1)
    var gets_generative = cell.is_hall and not cell.is_vid_corr and theme >= 0
    var chance = mgr.gallery_density if not cell.is_hall else 0.7
    if cell.is_vid_corr: chance = mgr.video_density
    var gets_photo = painting_textures.size() > 0 and randf() > (1.0 - chance)
    var gets_painting = gets_generative or gets_photo
    
    # Collision (merged into shared WallCollisions StaticBody3D)
    var coll = CollisionShape3D.new()
    var shape_idx = _mm_wall_meshes.find(mesh)
    if shape_idx >= 0:
        coll.shape = _wall_coll_shapes[shape_idx]
    else:
        var fallback = BoxShape3D.new()
        fallback.size = mesh.size
        coll.shape = fallback
    coll.position = pos
    _collision_body_walls.add_child(coll)
    
    # Plain wall -> always add to MultiMesh batch (zero individual nodes!)
    _mm_walls[mesh_type][zone_idx].append(Transform3D(Basis.IDENTITY, pos))
    
    if gets_painting:
        if gets_generative:
            create_generative_painting(self, pos, facing, theme)
        else:
            create_painting(self, pos, facing, cell.is_hall, cell.is_vid_corr)

func create_floor_chevron(px, y_base, pz, cell):
    var target = cell.path_to
    var dir = Vector3(target.x - cell.pos.x, 0, target.z - cell.pos.z).normalized()
    # Collect transform for MultiMesh batching
    var y_vec = dir
    var z_vec = Vector3.UP
    var x_vec = y_vec.cross(z_vec).normalized()
    _mm_chevrons.append(Transform3D(Basis(x_vec, y_vec, z_vec), Vector3(px, y_base + 0.02, pz)))

func create_painting(parent: Node3D, pos: Vector3, facing: Vector3, is_hall: bool = false, is_vid_corr: bool = false):
    var is_video = false
    if video_files.size() > 0:
        if is_vid_corr or randf() <= mgr.video_density:
            is_video = true

    var max_w = C_SIZE * 0.7
    var max_h = WALL_HEIGHT * 0.65
    if is_hall:
        max_w = C_SIZE * 0.85
        max_h = WALL_HEIGHT * 1.5
        
    var final_w = max_w
    var final_h = max_h
    
    var tex = null
    var video_path_str = ""
    
    if not is_video:
        tex = painting_textures[randi() % painting_textures.size()]
        if tex != null and tex.get_height() > 0:
            var aspect = float(tex.get_width()) / float(tex.get_height())
            final_h = max_w / aspect
            if final_h > max_h:
                final_h = max_h
                final_w = max_h * aspect
        else:
            final_h = max_h
            final_w = max_w
    else:
        var aspect = 16.0 / 9.0 # standard generic aspect for videos
        final_h = max_w / aspect
        if final_h > max_h:
            final_h = max_h
            final_w = max_h * aspect
        video_path_str = video_files[video_increment_index % video_files.size()]
        video_increment_index += 1

    var pic_mesh = QuadMesh.new()
    pic_mesh.size = Vector2(final_w, final_h)
    
    var pic_mat = StandardMaterial3D.new()
    pic_mat.roughness = 0.6
    pic_mat.metallic = 0.0
    
    var pic_inst = MeshInstance3D.new()
    pic_inst.mesh = pic_mesh
    pic_inst.material_override = pic_mat
    pic_inst.position = pos + facing * 0.28
    # add_child() wird erst GANZ AM ENDE gemacht, wenn der Node fertig konfiguriert ist!
    # Das ist extrem wichtig fuer die Ladezeit, weil Godot sonst das ganze Labyrinth updatet.
    
    if not is_video:
        pic_mat.albedo_color = Color(1.0, 1.0, 1.0)
        pic_mat.albedo_texture = tex
    else:
        pic_mat.albedo_color = Color(0.01, 0.01, 0.01)
        pic_mat.emission_enabled = true
        pic_mat.emission_energy_multiplier = 1.0
        pic_mat.roughness = 0.1
        
        # Statt hier den Godot Scenebaum mit 900 SubViewports zu fluten
        # wird das Bild einfach im Array als Video markiert.
        # Der 0.5s Timer weist dann nachher einen unserer 12 Pool-Viewports zu.
        all_video_screens.append({
            "pos": null,
            "inst": pic_inst,
            "mat": pic_mat,
            "video_path": video_path_str,
            "pool_idx": -1
        })
        
    var rot_y = 0.0
    var frame_basis = Basis.IDENTITY
    if facing.z > 0.5: 
        rot_y = 0.0
    elif facing.z < -0.5: 
        rot_y = 180.0
        frame_basis = frame_basis.rotated(Vector3.UP, PI)
    elif facing.x > 0.5: 
        rot_y = 90.0
        frame_basis = frame_basis.rotated(Vector3.UP, PI/2.0)
    elif facing.x < -0.5: 
        rot_y = -90.0
        frame_basis = frame_basis.rotated(Vector3.UP, -PI/2.0)
        
    pic_inst.rotation_degrees = Vector3(0, rot_y, 0)
    
    # ------------------ PERFORMANCE FIX ------------------
    # Jetzt, wo das Bild / das Video fertiggebaut + rotiert ist, haengen wir es in den Baum.
    parent.add_child(pic_inst)

    if is_video:
        all_video_screens[all_video_screens.size()-1]["pos"] = pic_inst.position

    # Golden Frame (Batched into MultiMesh)
    var frame_dt = 0.1
    var fw = final_w + frame_dt*2
    var fh = final_h + frame_dt*2
    var fd = 0.05
    var frame_pos = pos + facing * 0.25
    var scale_basis = Basis().scaled(Vector3(fw, fh, fd))
    _mm_frames.append(Transform3D(frame_basis * scale_basis, frame_pos))

    # Spotlight above painting
    var spot = SpotLight3D.new()
    spot.spot_angle = 65.0
    if is_video:
        spot.light_energy = 0.0 # pure glowing emission
    else:
        spot.light_energy = 25.0 # Bright spotlight so the painting is visible in dark corridors
        pic_mat.emission_enabled = true
        pic_mat.emission_energy_multiplier = 0.05 # Tiny baseline glow
        pic_mat.emission_texture = tex
    spot.light_color = Color(1.0, 0.95, 0.8)
    spot.spot_range = 8.0
    spot.shadow_enabled = false  # PERF: 300+ shadow maps pro Frame = FPS-Killer
    spot.position = frame_pos + frame_basis * Vector3(0, final_h/2.0 + 0.35, 0.3)
    spot.transform.basis = frame_basis.rotated(Vector3(1, 0, 0), deg_to_rad(-55))
    parent.add_child(spot)

func get_art_shader(theme: int) -> String:
    match theme:
        0: # Mandelbrot Fractal (gold)
            return """
shader_type spatial;
render_mode unshaded;
void fragment() {
    vec2 uv = (UV - 0.5) * 3.2 + vec2(-0.5, 0.0);
    vec2 c = uv + vec2(0.0, sin(TIME * 0.05) * 0.1);
    vec2 z = vec2(0.0);
    float i = 0.0;
    for (int n = 0; n < 48; n++) {
        if (dot(z,z) > 4.0) break;
        z = vec2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        i += 1.0;
    }
    float t = i / 48.0;
    vec3 gold = mix(vec3(0.05,0.02,0.0), vec3(1.0,0.75,0.1), pow(t,0.5));
    ALBEDO = gold;
    EMISSION = gold * 0.4;
}
"""
        1: # Plasma Waves (rainbow)
            return """
shader_type spatial;
render_mode unshaded;
void fragment() {
    vec2 uv = UV;
    float v = sin(uv.x * 12.0 + TIME * 1.5)
            + sin(uv.y * 9.0 + TIME * 1.2)
            + sin((uv.x + uv.y) * 6.0 + TIME * 2.0)
            + sin(length(uv - 0.5) * 15.0 - TIME * 3.0);
    vec3 col = 0.5 + 0.5 * cos(v * 2.0 + vec3(0.0, 2.094, 4.188) + TIME * 0.3);
    ALBEDO = col;
    EMISSION = col * 0.5;
}
"""
        2: # Lava Lamp (orange/red)
            return """
shader_type spatial;
render_mode unshaded;
void fragment() {
    vec2 uv = UV;
    vec2 b1 = vec2(0.5 + sin(TIME*0.7)*0.3, 0.3 + cos(TIME*0.5)*0.25);
    vec2 b2 = vec2(0.5 + cos(TIME*1.1)*0.28, 0.7 + sin(TIME*0.8)*0.2);
    vec2 b3 = vec2(0.3 + sin(TIME*0.9)*0.2, 0.5 + cos(TIME*1.3)*0.3);
    float d = 0.18/distance(uv,b1) + 0.14/distance(uv,b2) + 0.12/distance(uv,b3);
    d = smoothstep(1.2, 2.5, d);
    vec3 col = mix(vec3(0.05,0.0,0.0), mix(vec3(0.9,0.2,0.0), vec3(1.0,0.8,0.2), d), d);
    ALBEDO = col;
    EMISSION = col * 0.6;
}
"""
        3: # Voronoi Cells (cyberpunk blue)
            return """
shader_type spatial;
render_mode unshaded;
vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}
void fragment() {
    vec2 uv = UV * 5.0;
    vec2 i = floor(uv); vec2 f = fract(uv);
    float min_d = 10.0; vec3 col = vec3(0.0);
    for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        vec2 cell = vec2(float(x),float(y));
        vec2 pt = hash2(i+cell) + 0.5 + 0.4*sin(TIME*0.5 + 6.28*hash2(i+cell+0.5));
        float d = length(cell + pt - f);
        if(d < min_d) { min_d = d; col = vec3(hash2(i+cell), 0.9); }
    }
    vec3 c = vec3(col.x*0.2, col.y*0.5+0.3, 1.0) * (0.8 - min_d * 0.6);
    ALBEDO = c; EMISSION = c * 0.7;
}
"""
        _: # Ripples / Interference (ocean)
            return """
shader_type spatial;
render_mode unshaded;
void fragment() {
    vec2 uv = UV - 0.5;
    float r = length(uv);
    float a = atan(uv.y, uv.x);
    float wave1 = sin(r * 20.0 - TIME * 3.0) * 0.5 + 0.5;
    float wave2 = sin(r * 15.0 + a * 3.0 - TIME * 2.0) * 0.5 + 0.5;
    float wave3 = sin(dot(uv, vec2(1.0,0.7)) * 18.0 - TIME * 2.5) * 0.5 + 0.5;
    float v = (wave1 + wave2 + wave3) / 3.0;
    vec3 deep = vec3(0.0, 0.1, 0.4);
    vec3 bright = vec3(0.3, 0.8, 1.0);
    vec3 c = mix(deep, bright, v);
    ALBEDO = c; EMISSION = c * 0.4;
}
"""

func create_generative_painting(parent: Node3D, pos: Vector3, facing: Vector3, theme: int):
    var pic_mesh = QuadMesh.new()
    pic_mesh.size = Vector2(C_SIZE * 0.88, WALL_HEIGHT * 2.2)
    
    var shader = Shader.new()
    shader.code = get_art_shader(theme)
    var pic_mat = ShaderMaterial.new()
    pic_mat.shader = shader
    
    var pic_inst = MeshInstance3D.new()
    pic_inst.mesh = pic_mesh
    pic_inst.material_override = pic_mat
    pic_inst.position = pos + facing * 0.26
    parent.add_child(pic_inst)
    
    if facing.z > 0.5: pic_inst.rotation_degrees = Vector3(0, 0, 0)
    elif facing.z < -0.5: pic_inst.rotation_degrees = Vector3(0, 180, 0)
    elif facing.x > 0.5: pic_inst.rotation_degrees = Vector3(0, 90, 0)
    elif facing.x < -0.5: pic_inst.rotation_degrees = Vector3(0, -90, 0)

func _on_settings_updated():
    for mat in wall_mats:
        mat.metallic = mgr.wall_metallic
        mat.roughness = mgr.wall_roughness
    _update_lighting()

func _update_lighting():
    var dir_light = get_node("../DirectionalLight3D")
    var world_env = get_node("../WorldEnvironment")
    if dir_light != null: dir_light.light_energy = mgr.world_brightness
    if world_env != null: world_env.environment.ambient_light_energy = mgr.world_brightness


func _process(_delta):
    # Use cached player ref to avoid costly find_child() every frame
    if not is_instance_valid(_player_cached):
        _player_cached = get_tree().root.find_child("Player", true, false)
    var p_node = _player_cached
    if not p_node: return
    var p_pos = p_node.global_position
    
    # --- Proximity-basierte Monster-Aktivierung ---
    for m in all_monsters:
        if not is_instance_valid(m): continue
        var dist = m.global_position.distance_to(p_pos)
        var should_active = dist <= MONSTER_ACTIVE_RANGE
        if should_active != m.is_physics_processing():
            m.set_physics_process(should_active)
    
    pass
