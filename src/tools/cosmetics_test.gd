extends Node

# Cosmetics verification harness (design/COSMETICS.md + design/SEASON.md).
# PASS 1: catalog integrity — every track id resolves, 30 tiers, art paths exist,
#         and the design invariants hold (NO prestige on the track; milestones = towers).
# PASS 2: track math — tier unlocks, states, next-reward.
# PASS 3: save round-trip — grant / equip / claim against SaveData (state restored after).
# PASS 4: both screens instantiate and build against a mid-season save without errors.
# Drive headlessly: godot --headless --path src res://tools/cosmetics_test.tscn

const Catalog := preload("res://scripts/cosmetics_catalog.gd")

var _fails := 0

func _ready() -> void:
	_test_catalog()
	_test_track_math()
	_test_save_roundtrip()
	await _test_screens()
	if _fails == 0:
		print("RESULT ✅ COSMETICS OK (catalog + track math + save + screens)")
	else:
		print("RESULT ❌ COSMETICS FAILED — ", _fails, " check(s) above")
	get_tree().quit(_fails)

func _check(label: String, got, want) -> void:
	if got == want:
		print("  ✅ ", label)
	else:
		print("  ❌ ", label, "  got=", got, "  want=", want)
		_fails += 1

func _check_true(label: String, cond: bool) -> void:
	_check(label, cond, true)

# --- PASS 1: catalog integrity --------------------------------------------------

func _test_catalog() -> void:
	print("catalog:")
	_check("track has 30 tiers", Catalog.TRACK.size(), Catalog.TIER_COUNT)
	var slot_ids: Array = []
	for s in Catalog.SLOTS:
		slot_ids.append(s["id"])
	_check("9 slots (8 + board sticker)", slot_ids.size(), 9)

	var bad_refs := 0
	var prestige_on_track := 0
	for t in Catalog.TRACK:
		for id in t["items"]:
			var it := Catalog.item(id)
			if it.is_empty():
				bad_refs += 1
				print("        ! tier %d references unknown item '%s'" % [t["tier"], id])
			elif it["rarity"] == "prestige":
				prestige_on_track += 1
				print("        ! tier %d carries PRESTIGE item '%s'" % [t["tier"], id])
	_check("every track id resolves", bad_refs, 0)
	_check("prestige NEVER on the track (COSMETICS.md)", prestige_on_track, 0)

	for m in Catalog.MILESTONES:
		var first := Catalog.item(Catalog.tier_items(m)[0])
		_check("milestone %d is a tower" % m, String(first["slot"]), "tower")

	var bad_art := 0
	var bad_slot := 0
	for it in Catalog.ITEMS:
		var art := String(it.get("art", ""))
		if art != "" and not ResourceLoader.exists(art):
			bad_art += 1
			print("        ! '%s' art missing: %s" % [it["id"], art])
		if not slot_ids.has(it["slot"]):
			bad_slot += 1
	_check("all declared art paths exist", bad_art, 0)
	_check("all items map to a real slot", bad_slot, 0)

	var eq := Catalog.default_equipped()
	for slot in ["tower", "board", "zone", "proj", "mob", "frame", "banner"]:
		_check_true("default equipped covers %s" % slot, eq.has(slot))

# --- PASS 2: track math ----------------------------------------------------------

func _test_track_math() -> void:
	print("track math:")
	_check("0 pts → tier 0", Catalog.unlocked_tier(0), 0)
	_check("999 pts → tier 0", Catalog.unlocked_tier(999), 0)
	_check("1000 pts → tier 1", Catalog.unlocked_tier(1000), 1)
	_check("30000 pts → tier 30", Catalog.unlocked_tier(30000), 30)
	_check("90000 pts caps at 30", Catalog.unlocked_tier(90000), 30)
	_check("state: reached unclaimed = claimable", Catalog.tier_state(1, 1000, []), "claimable")
	_check("state: claimed", Catalog.tier_state(1, 1000, [1]), "claimed")
	_check("state: the next tier = current", Catalog.tier_state(2, 1000, [1]), "current")
	_check("state: beyond next = locked", Catalog.tier_state(3, 1000, [1]), "locked")
	_check("next reward skips claimed", Catalog.next_reward_tier(2000, [1]), 2)
	_check("next reward at zero = tier 1", Catalog.next_reward_tier(0, []), 1)

# --- PASS 3: save round-trip ------------------------------------------------------

func _test_save_roundtrip() -> void:
	print("save round-trip:")
	var saved = SaveData.data.get("cosmetics", {}).duplicate(true)

	SaveData.data["cosmetics"] = {}
	_check("fresh save: nothing owned", SaveData.cosmetics_owned().size(), 0)
	_check("fresh save: 0 points", SaveData.season_points(), 0)
	_check("fresh save: defaults are owned via catalog",
		Catalog.is_owned("tower_arrow", SaveData.cosmetics_owned()), true)
	_check("fresh save: track item not owned",
		Catalog.is_owned("tower_fire_crystal", SaveData.cosmetics_owned()), false)

	SaveData.add_season_points(2500)
	_check("points accumulate", SaveData.season_points(), 2500)
	_check("2500 pts unlocks tier 2", Catalog.unlocked_tier(SaveData.season_points()), 2)

	# Claim tier 1 the way the Season screen does.
	for id in Catalog.tier_items(1):
		SaveData.grant_cosmetic(id)
	SaveData.claim_season_tier(1)
	_check_true("claim granted the tier-1 title", SaveData.cosmetics_owned().has("title_recruit"))
	_check_true("tier 1 recorded claimed", SaveData.claimed_season_tiers().has(1))
	_check("tier 1 state is claimed", Catalog.tier_state(1, SaveData.season_points(), SaveData.claimed_season_tiers()), "claimed")

	SaveData.equip_cosmetic("title", "title_recruit")
	_check("equip persists", SaveData.equipped_cosmetic("title"), "title_recruit")
	_check("unset slot reads empty", SaveData.equipped_cosmetic("sticker"), "")

	var owned: Array = SaveData.cosmetics_owned()
	_check_true("completion rises above zero", Catalog.overall_completion(owned) > 0.0)
	var done: Vector2i = Catalog.slot_completion("title", owned)
	_check("title slot completion counts the claim", done.x, 1)

	SaveData.data["cosmetics"] = saved  # restore (don't leak test state into the save file)
	SaveData.save()

# --- PASS 4: the two screens build ------------------------------------------------

func _test_screens() -> void:
	print("screens:")
	var saved = SaveData.data.get("cosmetics", {}).duplicate(true)
	# A believable mid-season save: tier 12, tiers 1-9 claimed, a few things equipped.
	var owned: Array = []
	for t in range(1, 10):
		for id in Catalog.tier_items(t):
			owned.append(id)
	SaveData.data["cosmetics"] = {
		"owned": owned, "equipped": {"title": "title_pathfinder", "frame": "frame_wood"},
		"season_points": 12250, "claimed_tiers": range(1, 10),
	}

	for scene_path in ["res://scenes/collection.tscn", "res://scenes/season.tscn"]:
		var scene = load(scene_path).instantiate()
		add_child(scene)
		await get_tree().process_frame
		await get_tree().process_frame
		_check_true("%s builds children" % scene_path.get_file(), scene.get_child_count() > 0)
		scene.queue_free()
		await get_tree().process_frame

	SaveData.data["cosmetics"] = saved
	SaveData.save()
