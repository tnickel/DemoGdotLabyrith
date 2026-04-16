extends Node

var config = ConfigFile.new()
var config_path = "user://settings.cfg"

# Default values
var world_brightness = 1.0 # 0.1 to 3.0
var flash_brightness = 2.0 # 0.0 to 10.0
var wall_metallic = 0.8 # 0.0 to 1.0
var wall_roughness = 0.2 # 0.0 to 1.0
var monster_density = 0.20 # 0.0 to 1.0 (20%)
var neon_density = 0.35 # 0.0 to 1.0 (35%)
var gallery_density = 0.10 # 0.0 to 1.0 (10%)
var video_density = 0.50 # 0.0 to 1.0 (50% of spawned frames)
var chunk_cells = 15    # cells per chunk side (5-30, affects MultiMesh batching)
var music_volume_db = -12.0 # Master bus volume in dB (-40 = near silent, 0 = full)
var resolution_index = 1 # 1 = 1600x900
var graphics_quality = 2 # 0: Low, 1: Medium, 2: High
var is_vr = false # Runtime flag evaluating if OpenXR was initialized
var show_perf_hud = true # Show FPS/Stats overlay in-game

var resolutions = [
    Vector2i(1280, 720),
    Vector2i(1600, 900),
    Vector2i(1920, 1080),
    Vector2i(2560, 1440),
    Vector2i(3840, 2160)
]

# Signal emitted when visual values change
signal settings_updated

func _ready():
    load_settings()

func load_settings():
    if config.load(config_path) == OK:
        world_brightness = config.get_value("visuals", "world_brightness", world_brightness)
        flash_brightness = config.get_value("visuals", "flash_brightness", flash_brightness)
        wall_metallic = config.get_value("visuals", "wall_metallic", wall_metallic)
        wall_roughness = config.get_value("visuals", "wall_roughness", wall_roughness)
        monster_density = config.get_value("game", "monster_density", monster_density)
        neon_density = config.get_value("game", "neon_density", neon_density)
        gallery_density = config.get_value("game", "gallery_density", gallery_density)
        video_density = config.get_value("game", "video_density", video_density)
        chunk_cells = config.get_value("game", "chunk_cells", chunk_cells)
        resolution_index = config.get_value("display", "resolution_index", resolution_index)
        graphics_quality = config.get_value("display", "graphics_quality", graphics_quality)
        music_volume_db = config.get_value("audio", "music_volume_db", music_volume_db)
        show_perf_hud  = config.get_value("display", "show_perf_hud",  show_perf_hud)
        
    _apply_resolution()
    apply_audio()

func save_settings():
    config.set_value("visuals", "world_brightness", world_brightness)
    config.set_value("visuals", "flash_brightness", flash_brightness)
    config.set_value("visuals", "wall_metallic", wall_metallic)
    config.set_value("visuals", "wall_roughness", wall_roughness)
    config.set_value("game", "monster_density", monster_density)
    config.set_value("game", "neon_density", neon_density)
    config.set_value("game", "gallery_density", gallery_density)
    config.set_value("game", "video_density", video_density)
    config.set_value("game", "chunk_cells", chunk_cells)
    config.set_value("display", "resolution_index", resolution_index)
    config.set_value("display", "graphics_quality", graphics_quality)
    config.set_value("audio",   "music_volume_db", music_volume_db)
    config.set_value("display", "show_perf_hud",   show_perf_hud)
    config.save(config_path)

func apply_audio():
    var bus_idx = AudioServer.get_bus_index("Master")
    if bus_idx >= 0:
        AudioServer.set_bus_volume_db(bus_idx, music_volume_db)

func apply_graphics_settings():
    var effective_quality = graphics_quality
    # In VR, stereoscopic rendering doubles GPU load. Volumetric Fog and SSAO cause massive stutter on mid/high-end GPUs.
    if is_vr:
        effective_quality = 0 # Force "Low" preset visually

    var env_node = get_tree().root.find_child("WorldEnvironment", true, false)
    if env_node and env_node.environment:
        var env = env_node.environment
        env.ssao_enabled = (effective_quality >= 1)
        env.volumetric_fog_enabled = (effective_quality >= 1)
        
    var dir_light = get_tree().root.find_child("DirectionalLight3D", true, false)
    if dir_light:
        dir_light.shadow_enabled = (effective_quality >= 1)

    var spot_light = get_tree().root.find_child("SpotLight3D", true, false)
    if spot_light:
        spot_light.shadow_enabled = (effective_quality >= 2)

    var vp = get_viewport()
    if vp:
        vp.msaa_3d = Viewport.MSAA_2X if effective_quality == 2 else Viewport.MSAA_DISABLED
        vp.scaling_3d_scale = 0.8 if is_vr else 1.0

func set_resolution(idx):
    resolution_index = idx
    _apply_resolution()

func _apply_resolution():
    var res = resolutions[resolution_index]
    DisplayServer.window_set_size(res)
    var screen = DisplayServer.screen_get_size()
    DisplayServer.window_set_position((screen - res) / 2)

func apply_visuals():
    settings_updated.emit()
