extends SceneTree

func _init():
    var packed = load("res://player.glb")
    var instance = packed.instantiate()
    var anim_player = instance.get_node(^"AnimationPlayer")
    print("ANIMATION LIST:")
    for a in anim_player.get_animation_list():
        print(a)
    quit()
