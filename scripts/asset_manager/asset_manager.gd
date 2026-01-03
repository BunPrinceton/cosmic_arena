# scripts/asset_manager/asset_manager.gd

extends Object
class_name AssetManager

const HUMAN_FEMALE_PATH = "res://assets/models/humanoid/human_female.glb"

var cache = {}

func load_glb(path: String) -> Node:
	if path in cache:
		return cache[path].instantiate()
	
	var scene = load(path)
	cache[path] = scene
	return scene.instantiate()

# New method that uses load_glb with the constant path
func load_my_test_glb() -> Node:
	return load_glb(HUMAN_FEMALE_PATH)
