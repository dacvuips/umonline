extends SceneTree

const MuDropItemRes = preload("res://src/entities/MuDropItem.gd")
const MuPlayerRes = preload("res://src/entities/MuPlayer.gd")

func _init() -> void:
	print("--- TEST DROP ITEM ---")
	
	# Test 1: Drop equipment item with fresh drop animation
	var drop_equip = MuDropItemRes.new()
	var sword_item = {
		"id": "sword_01",
		"group": 0,
		"number": 0,
		"level": 3,
		"name": "Kiris"
	}
	drop_equip.item_dict = sword_item
	drop_equip.setup_drop(Vector3(5, 0, 5), Vector3(3, 1.1, 5))
	print("Equip category after set: ", drop_equip.category, " (expected: ", MuDropItemRes.ItemCategory.EQUIPMENT, ")")
	assert(drop_equip.category == MuDropItemRes.ItemCategory.EQUIPMENT, "Equipment category must be EQUIPMENT")
	
	drop_equip._ready()
	var label = drop_equip.get_node_or_null("ItemLabel")
	assert(label != null, "Label must exist after ready")
	print("Equip label text: ", label.text)
	assert("Kris" in label.text or "Kiếm" in label.text, "Label text should contain item name")
	assert(drop_equip.get_node_or_null("ItemMesh") != null, "ItemMesh should exist")
	
	# Mid-air check: label should be hidden while falling
	assert(drop_equip._is_falling == true, "Must be falling initially")
	assert(label.visible == false, "Label must be hidden while falling in mid-air")
	
	# Simulate physics tick mid-air (t = 0.24s)
	drop_equip._update_falling(0.24)
	assert(drop_equip._is_falling == true, "Still falling mid-air")
	print("Mid-air position: ", drop_equip.position)
	assert(drop_equip.position.y > 0.0, "Must be above ground mid-air")
	
	# Simulate landing (t += 0.3s -> total 0.54s > duration 0.48s)
	drop_equip._update_falling(0.30)
	assert(drop_equip._is_falling == false, "Should have landed")
	assert(label.visible == true, "Label must become visible after landing")
	assert(drop_equip.position.is_equal_approx(Vector3(5, 0, 5)), "Must land at target position")
	print("Landed position: ", drop_equip.position)
	
	# Test 2: Drop Jewel of Bless
	var drop_bless = MuDropItemRes.new()
	var bless_item = {
		"id": "jewel_bless",
		"group": 14,
		"number": 13,
		"name": "Ngọc Ước Nguyện"
	}
	drop_bless.item_dict = bless_item
	print("Bless category: ", drop_bless.category, " (expected: ", MuDropItemRes.ItemCategory.BLESS, ")")
	assert(drop_bless.category == MuDropItemRes.ItemCategory.BLESS, "Bless category must be BLESS")
	
	# Test 3: Drop Zen
	var drop_zen = MuDropItemRes.new()
	drop_zen.amount = 1000
	drop_zen.is_fresh_drop = false # Direct ground spawn
	drop_zen._ready()
	print("Zen category: ", drop_zen.category, " (expected: ", MuDropItemRes.ItemCategory.ZEN, ")")
	assert(drop_zen.category == MuDropItemRes.ItemCategory.ZEN, "Zen category must be ZEN")
	var zen_label = drop_zen.get_node("ItemLabel")
	print("Zen label text: ", zen_label.text)
	assert("Zen" in zen_label.text, "Zen label should have Zen")
	assert(zen_label.visible == true, "Non-fresh drop label visible immediately")
	
	# Test 4: Pickup equipment item
	var player = MuPlayerRes.new()
	var initial_zen = player.zen
	var inv_count_before = player.inventory.size()
	drop_equip.pickup(player)
	print("Player Zen after picking equip: ", player.zen, " (initial: ", initial_zen, ")")
	assert(player.zen == initial_zen, "Player Zen must not increase when picking up equipment!")
	assert(player.inventory.size() == inv_count_before + 1, "Player inventory should receive the item!")
	print("Picked item in inv: ", player.inventory[-1])
	
	# Test 5: Pickup Zen
	var drop_zen2 = MuDropItemRes.new()
	drop_zen2.amount = 5000
	drop_zen2.is_fresh_drop = false
	drop_zen2._ready()
	drop_zen2.pickup(player)
	print("Player Zen after picking Zen: ", player.zen)
	assert(player.zen == initial_zen + 5000, "Player Zen must increase by 5000")
	
	# Test 6: Despawn lifetime on ground
	var drop_expiring = MuDropItemRes.new()
	drop_expiring.amount = 100
	drop_expiring.is_fresh_drop = false
	drop_expiring.despawn_duration = 60.0
	drop_expiring._ready()
	assert(drop_expiring.despawn_duration == 60.0, "Default despawn duration should be 60.0s")
	assert(drop_expiring.is_despawned == false, "Item should not be despawned initially")
	
	# Tick 45s -> still on ground, no blink
	drop_expiring._update_despawn(45.0)
	assert(drop_expiring.is_despawned == false, "Should still be alive at 45s")
	
	# Tick +10s (55s) -> within 10s warning window, blinking active
	drop_expiring._update_despawn(10.0)
	assert(drop_expiring.is_despawned == false, "Should still be alive at 55s")
	
	# Tick +6s (61s) -> expired, despawned
	drop_expiring._update_despawn(6.0)
	assert(drop_expiring.is_despawned == true, "Item should be despawned after 60s")
	
	print("--- ALL DROP ITEM TESTS PASSED! ---")
	quit(0)
