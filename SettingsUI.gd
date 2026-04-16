extends Control

var panel: Panel
var sliders = {}
var mgr

func _ready():
    mgr = get_node("/root/SettingsManager")
    
    panel = Panel.new()
    panel.set_anchors_preset(PRESET_CENTER_TOP)
    panel.set_offsets_preset(PRESET_CENTER_TOP)
    panel.position.y = 30
    panel.custom_minimum_size = Vector2(460, 600)
    panel.visible = false
    add_child(panel)
    
    var vbox = VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 10)
    panel.add_child(vbox)
    
    var title = Label.new()
    title.text = "SETTINGS (Press ESC)"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    var res_hbox = HBoxContainer.new()
    var res_lbl = Label.new()
    res_lbl.text = "Resolution"
    res_lbl.custom_minimum_size.x = 200
    res_hbox.add_child(res_lbl)
    
    var res_opt = OptionButton.new()
    res_opt.add_item("1280 x 720 (HD)")
    res_opt.add_item("1600 x 900")
    res_opt.add_item("1920 x 1080 (FHD)")
    res_opt.add_item("2560 x 1440 (QHD)")
    res_opt.add_item("3840 x 2160 (4K UHD)")
    res_opt.selected = mgr.resolution_index
    res_opt.size_flags_horizontal = SIZE_EXPAND_FILL
    res_opt.item_selected.connect(func(idx): mgr.set_resolution(idx))
    res_hbox.add_child(res_opt)
    vbox.add_child(res_hbox)
    
    var qual_hbox = HBoxContainer.new()
    var qual_lbl = Label.new()
    qual_lbl.text = "Graphics Quality"
    qual_lbl.custom_minimum_size.x = 200
    qual_hbox.add_child(qual_lbl)
    
    var qual_opt = OptionButton.new()
    qual_opt.add_item("Low (No Post-FX, No Shadows)")
    qual_opt.add_item("Medium (SSAO, Fog, Directional Shadows)")
    qual_opt.add_item("High (Full Shadows, MSAA)")
    qual_opt.selected = mgr.graphics_quality
    qual_opt.size_flags_horizontal = SIZE_EXPAND_FILL
    qual_opt.item_selected.connect(func(idx): 
        mgr.graphics_quality = idx
        mgr.apply_graphics_settings()
    )
    qual_hbox.add_child(qual_opt)
    vbox.add_child(qual_hbox)
    
    create_slider(vbox, "World Brightness", "world_brightness", 0.1, 5.0, mgr.world_brightness)
    create_slider(vbox, "Flashlight Brightness", "flash_brightness", 0.0, 10.0, mgr.flash_brightness)
    create_slider(vbox, "Wall Metallic", "wall_metallic", 0.0, 1.0, mgr.wall_metallic)
    create_slider(vbox, "Wall Roughness", "wall_roughness", 0.0, 1.0, mgr.wall_roughness)
    create_slider(vbox, "Monster Density", "monster_density", 0.0, 1.0, mgr.monster_density)
    create_slider(vbox, "Neon Density", "neon_density", 0.0, 1.0, mgr.neon_density)
    create_slider(vbox, "Gallery Density", "gallery_density", 0.0, 1.0, mgr.gallery_density)
    create_slider(vbox, "Video Density", "video_density", 0.0, 1.0, mgr.video_density)
    create_slider(vbox, "Chunk Size", "chunk_cells", 5, 30, mgr.chunk_cells, 1)
    
    # --- Audio ---
    var audio_sep = HSeparator.new()
    vbox.add_child(audio_sep)
    
    var vol_hbox = HBoxContainer.new()
    var vol_lbl = Label.new()
    vol_lbl.text = "Musiklautstärke"
    vol_lbl.custom_minimum_size.x = 200
    vol_hbox.add_child(vol_lbl)
    
    var vol_slider = HSlider.new()
    vol_slider.min_value = -40.0
    vol_slider.max_value = 0.0
    vol_slider.step = 0.5
    vol_slider.value = mgr.music_volume_db
    vol_slider.size_flags_horizontal = SIZE_EXPAND_FILL
    
    var vol_val_lbl = Label.new()
    vol_val_lbl.custom_minimum_size.x = 60
    vol_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    vol_val_lbl.text = _db_label(mgr.music_volume_db)
    
    vol_slider.value_changed.connect(func(v: float):
        mgr.music_volume_db = v
        mgr.apply_audio()
        mgr.save_settings()
        vol_val_lbl.text = _db_label(v)
    )
    vol_hbox.add_child(vol_slider)
    vol_hbox.add_child(vol_val_lbl)
    vbox.add_child(vol_hbox)
    
    # VSync toggle
    var vsync_hbox = HBoxContainer.new()
    var vsync_lbl = Label.new()
    vsync_lbl.text = "VSync"
    vsync_lbl.custom_minimum_size.x = 200
    vsync_hbox.add_child(vsync_lbl)
    var vsync_chk = CheckBox.new()
    vsync_chk.text = "Enabled"
    vsync_chk.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
    vsync_chk.toggled.connect(func(on):
        if on:
            DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
        else:
            DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    )
    vsync_hbox.add_child(vsync_chk)
    vbox.add_child(vsync_hbox)
    
    # Performance-HUD toggle
    var hud_hbox = HBoxContainer.new()
    var hud_lbl = Label.new()
    hud_lbl.text = "Performance-Anzeige"
    hud_lbl.custom_minimum_size.x = 200
    hud_hbox.add_child(hud_lbl)
    var hud_chk = CheckBox.new()
    hud_chk.text = "Sichtbar"
    hud_chk.button_pressed = mgr.show_perf_hud
    hud_chk.toggled.connect(func(on):
        mgr.show_perf_hud = on
        mgr.save_settings()
        # Der Performance-Timer reagiert automatisch beim naechsten Tick (0.5s)
    )
    hud_hbox.add_child(hud_chk)
    vbox.add_child(hud_hbox)
    
    var btn_save = Button.new()
    btn_save.text = "Save Settings"
    btn_save.pressed.connect(func(): mgr.save_settings())
    vbox.add_child(btn_save)
    
    var btn_restart = Button.new()
    btn_restart.text = "Restart Labyrinth"
    btn_restart.pressed.connect(func():
        mgr.save_settings()
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        get_tree().change_scene_to_file("res://main.tscn")
    )
    vbox.add_child(btn_restart)

func create_slider(parent: Control, label_text: String, prop: String, min_v: float, max_v: float, curr_v: float, step_v: float = 0.01):
    var hbox = HBoxContainer.new()
    var lbl = Label.new()
    lbl.text = label_text
    lbl.custom_minimum_size.x = 200
    hbox.add_child(lbl)
    
    var sl = HSlider.new()
    sl.min_value = min_v
    sl.max_value = max_v
    sl.value = curr_v
    sl.step = step_v
    sl.size_flags_horizontal = SIZE_EXPAND_FILL
    
    # Value label for integer sliders
    var val_lbl: Label = null
    if step_v >= 1:
        val_lbl = Label.new()
        val_lbl.text = str(int(curr_v))
        val_lbl.custom_minimum_size.x = 30
        val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    
    sl.value_changed.connect(func(v): 
        mgr.set(prop, int(v) if step_v >= 1 else v)
        if val_lbl: val_lbl.text = str(int(v))
        mgr.apply_visuals()
    )
    hbox.add_child(sl)
    if val_lbl: hbox.add_child(val_lbl)
    parent.add_child(hbox)
    sliders[prop] = sl

func _process(delta):
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
        panel.visible = true
    else:
        panel.visible = false

func _db_label(db: float) -> String:
    if db <= -39.5:
        return "STUMM"
    return "%+.0f dB" % db
