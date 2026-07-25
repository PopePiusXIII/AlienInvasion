--!strict

local MatchHUD = require(game.ReplicatedStorage.Shared.vide.MatchHUD)

local function story(target: Instance)
	local controls, unmount = MatchHUD.createMatchHUD({
		parentGui = target,
		inventorySize = 5,
	})

	controls.setWaveNumber(7)
	controls.setZombiesRemaining(18)
	controls.setKills(42)
	controls.setCoins(1250)
	controls.setTimerSeconds(142)
	controls.setAreaName("AREA-7")
	controls.setHP(76, 100)
	controls.setArmor(48, 100)
	controls.setPerks({
		{ name = "RAPID FIRE", active = true },
		{ name = "ARMOR UP", active = false },
	})
	controls.setObjectives({
		{ text = "Secure the landing zone", done = true },
		{ text = "Survive the wave", done = false },
	})
	controls.setXP(3250, 5000)
	controls.setActiveWeaponAmmo(24, 120)
	controls.setInventory({ "Rifle", "Pistol", "Knife", "Grenade", "Medkit" }, 1)
	controls.setSlotAmmo(1, 24, 30)
	controls.setSlotAmmo(2, 12, 60)
	controls.addKillFeedEntry("NOVA", "PLASMA RIFLE")
	controls.addKillFeedEntry("RAVEN", "MELEE")

	return unmount
end

return story
