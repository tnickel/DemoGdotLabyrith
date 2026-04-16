extends SceneTree

func _init():
    var m = OpenXRActionMap.new()
    var set = OpenXRActionSet.new()
    set.name = "default"
    set.localized_name = "Default"
    m.add_action_set(set)
    var act = OpenXRAction.new()
    act.name = "move"
    act.localized_name = "Move"
    act.action_type = OpenXRAction.OPENXR_ACTION_VECTOR2
    set.add_action(act)
    ResourceSaver.save(m, "res://default_xr_map.tres")
    print("Saved map")
    quit()
