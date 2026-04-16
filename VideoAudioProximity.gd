extends VideoStreamPlayer

# MazeGenerator.gd timer verwaltet play/stop zentral (O(n) alle 0.5s).
# Dieses Skript macht nur noch: Lautstaerke-Fading basierend auf Distanz (O(1) pro Frame).

var player_node: Node3D = null
var max_dist = 15.0
var anchor_node: Node3D = null

func _ready():
    add_to_group("gallery_videos")

func _process(_delta):
    # Anchor einmalig cachen
    if not anchor_node:
        var p = get_parent()
        if p: anchor_node = p.get_parent()
        if not (anchor_node is Node3D):
            return
    
    # Player einmalig cachen
    if not player_node:
        player_node = get_tree().root.find_child("Player", true, false)
        return
    
    # Nur Lautstaerke-Fading — kein O(n^2) Scan mehr!
    var dist = anchor_node.global_position.distance_to(player_node.global_position)
    if dist > max_dist:
        volume_db = -80.0
    else:
        var ratio = clamp(1.0 - (dist / max_dist), 0.0, 1.0)
        volume_db = lerp(-60.0, 5.0, ratio)
