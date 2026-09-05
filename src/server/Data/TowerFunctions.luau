local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)

local PROJECTILE_TICKS = 7

local DamageCalculation = function(towerData, charData)
	local damage = towerData.Damage
	-- warn(damage)	
	for _, equippedTotem in ipairs(shared.DataStore.TotemController.GetEquipped(towerData.Owner)) do
		if equippedTotem and equippedTotem.TotemUID then
			local staticData = TotemData.GetData(equippedTotem.TotemUID)
			local modifier  = shared.CalculateData.GetModifierByPoints(equippedTotem.Point)
			modifier *= towerData.ActionDelay / shared.Config.TICKPERSECOND_DEFAULT
			if modifier then
				if staticData.MainType == towerData.TotemType then
					damage += modifier * 3
				end
				if staticData.SubType == towerData.TotemType then
					damage += modifier
				end
			end
		end
	end
	-- warn(damage)
	
	if towerData.CritChance and towerData.CritDamage then
		if towerData.Game.CritRandom:NextNumber() <= towerData.CritChance then
			damage = damage * towerData.CritDamage
		end
	end

	return math.floor(damage)
end

local ChooseCharacter = function(towerData)
	local characterlink = towerData.Characters.Next
	while characterlink ~= towerData.Characters do
		local damage = DamageCalculation(towerData, characterlink.Value)
		local enemy = characterlink.Value
		local remaining = enemy.Health - enemy.ReservedDamage
		if remaining > 0 then
			enemy.ReservedDamage += damage
			return enemy, damage
		end
		characterlink = characterlink.Next
	end

	return nil
end

local ChooseCharacters = function(towerData, count)
	local characters = {}
	local damage = DamageCalculation(towerData)
	local characterlink = towerData.Characters.Next
	while characterlink ~= towerData.Characters and #characters < count do
		local enemy = characterlink.Value
		if enemy.Health - enemy.ReservedDamage > 0 then
			enemy.ReservedDamage += damage
			table.insert(characters, enemy)
		end
		characterlink = characterlink.Next
	end

	return characters, damage
end

TowerFunction = {
	['DamageProjectile'] = {
		Action = function(tower)
			local animationDelay = 24
			tower.Game.Task:Wait(PROJECTILE_TICKS + animationDelay)

			local character, damage = ChooseCharacter(tower)
			if character == nil then return end

			character:ModifyHealth(damage, tower.Owner, tower.Cash)
		end,
	},
	--- 攻击范围内下一个
	['MultiDamageProjectile'] = {
		Action = function(tower)
			tower.Game.Task:Wait(24 + PROJECTILE_TICKS)

			local characters, damage = ChooseCharacters(tower, 3)

			for i, v in characters do
				v:ModifyHealth(damage, tower.Owner, tower.Cash)
			end
		end,
	},
	
}

return TowerFunction