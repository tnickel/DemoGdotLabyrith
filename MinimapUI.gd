extends Control

var maze_ref = null
var c_size = 5.0
var maze_w = 20
var maze_h = 20

var player_ref: Node3D = null
var redraw_timer = 0.0

const MAP_SIZE = 200.0

func _ready():
    # Explicit size and position - no anchor preset
    size = Vector2(MAP_SIZE, MAP_SIZE)
    position = Vector2(20, 0)  # Will be corrected in _process when viewport is ready
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 100
    
    # Force first draw after 2 frames
    await get_tree().process_frame
    await get_tree().process_frame
    player_ref = get_tree().root.find_child("Player", true, false)
    # Fix Y position now that viewport is initialized
    position = Vector2(20, get_viewport_rect().size.y - MAP_SIZE - 20)
    queue_redraw()
    print("[MINIMAP] initialized, size=", size, " pos=", position, " maze_ref=", maze_ref != null)

func _process(delta):
    redraw_timer -= delta
    if redraw_timer <= 0.0:
        redraw_timer = 0.1
        queue_redraw()

func _draw():
    if maze_ref == null:
        # Draw error indicator so we know it's alive
        draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color(1, 0, 0, 0.5))
        return
    
    var cell_w = MAP_SIZE / float(maze_w)
    var cell_h = MAP_SIZE / float(maze_h)
    
    # Background
    draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color(0, 0, 0, 0.7))
    
    # Draw cells
    for x in range(maze_w):
        for z in range(maze_h):
            var cell = maze_ref[0][x][z]
            var rx = x * cell_w
            var rz = z * cell_h
            
            if cell.is_hall:
                draw_rect(Rect2(rx + 1, rz + 1, cell_w - 2, cell_h - 2), Color(0.2, 0.55, 0.9, 0.5))
            else:
                if cell.N: draw_line(Vector2(rx, rz), Vector2(rx + cell_w, rz), Color.CYAN, 1.0)
                if cell.S: draw_line(Vector2(rx, rz + cell_h), Vector2(rx + cell_w, rz + cell_h), Color.CYAN, 1.0)
                if cell.W: draw_line(Vector2(rx, rz), Vector2(rx, rz + cell_h), Color.CYAN, 1.0)
                if cell.E: draw_line(Vector2(rx + cell_w, rz), Vector2(rx + cell_w, rz + cell_h), Color.CYAN, 1.0)
    
    # Player dot
    if player_ref != null and is_instance_valid(player_ref):
        var px = player_ref.global_position.x / c_size
        var pz = player_ref.global_position.z / c_size
        var dot = Vector2(px * cell_w, pz * cell_h)
        draw_circle(dot, 4.0, Color(1, 0.15, 0.15))
        var fwd = -player_ref.global_transform.basis.z
        draw_line(dot, dot + Vector2(fwd.x, fwd.z).normalized() * 8.0, Color(1, 0.6, 0.6), 1.5)
