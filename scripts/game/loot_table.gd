class_name LootTable
extends RefCounted

enum WreckTier { TUTORIAL, SALVAGE, MILITARY }


static func roll_for_wreck(tier: WreckTier) -> Array[LootItem]:
	var items: Array[LootItem] = []
	match tier:
		WreckTier.TUTORIAL:
			var count := randi_range(1, 2)
			for i in count:
				items.append(LootItem.antenna_part())
		WreckTier.SALVAGE:
			var count := randi_range(2, 3)
			for i in count:
				if randf() < 0.35:
					items.append(LootItem.scrap())
				else:
					items.append(LootItem.antenna_part())
		WreckTier.MILITARY:
			var count := randi_range(3, 4)
			for i in count:
				if randf() < 0.5:
					items.append(LootItem.scrap())
				else:
					items.append(LootItem.antenna_part())
	return items


static func breach_duration_for_tier(tier: WreckTier) -> float:
	match tier:
		WreckTier.TUTORIAL:
			return 0.6
		WreckTier.SALVAGE:
			return 0.75
		WreckTier.MILITARY:
			return 1.0
		_:
			return 0.75
