extends SceneTree

func _init():
    var iface = XRServer.find_interface("OpenXR")
    if iface:
        print("Init result: ", iface.initialize())
    else:
        print("No interface found")
    quit()
