extends SceneTree

func _init():
    print("OpenXR Available: ", XRServer.find_interface("OpenXR") != null)
    quit()
