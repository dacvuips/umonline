extends Node

func _ready() -> void:
    await get_tree().create_timer(1.0).timeout
    var img = get_viewport().get_texture().get_image()
    img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/34469ea3-3fa7-4382-8923-5097c7ddbe7b/final_verified_login_s9.png")
    print("SAVED_FINAL_SCREENSHOT")
    get_tree().quit()
