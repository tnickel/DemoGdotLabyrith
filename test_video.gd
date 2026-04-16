extends SceneTree

func _init():
    var player = VideoStreamPlayer.new()
    var stream = VideoStreamTheora.new()
    player.stream = stream
    print("Texture: ", player.get_video_texture())
    quit()
