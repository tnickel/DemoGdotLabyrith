extends Control

func _ready():
    # Make sure we have a mouse pointer for the UI
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_btn_2d_pressed():
    SettingsManager.is_vr = false
    # VSync + 60 FPS Cap: damit Bandicam/OBS gleichmaessige Frames bekommt.
    # Ohne Limit laeuft das Spiel mit 300+ FPS, aber Recorder nimmt nur 30-60 ab
    # → ungleichmaessige Frame-Abstaende → Ruckeln im Video trotz fliessendem Spiel.
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
    Engine.max_fps = 60
    get_tree().change_scene_to_file("res://main.tscn")
    
func _on_btn_vr_pressed():
    var xr_interface = XRServer.find_interface("OpenXR")
    if xr_interface == null:
        OS.alert(
            "OpenXR Interface nicht gefunden!\n\n" +
            "Fuer VR-Modus: In Godot Editor unter\n" +
            "Project > Project Settings > XR > OpenXR\n" +
            "'Enabled' aktivieren und das Projekt neu starten.\n\n" +
            "Tipp: Starte das Programm mit der VR-Brille per Godot Editor\n" +
            "oder lege eine separate start_vr.bat an."
        )
        return
    if xr_interface.is_initialized() or xr_interface.initialize():
        get_viewport().use_xr = true
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        Engine.max_fps = 0
        SettingsManager.is_vr = true
        get_tree().change_scene_to_file("res://main.tscn")
    else:
        OS.alert("OpenXR initialization failed. Please ensure SteamVR or PSVR2 App is running.")
