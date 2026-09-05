local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local TraitData = require(ReplicatedStorage.Datas.TraitData :: ModuleScript)
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)

local self = {}

function self.ApplyModifiers(baseStats, traitId)
	if traitId == nil then return baseStats end

	local traitInfo = TraitData.GetData(traitId)
	if traitInfo == nil or traitInfo.Modifiers == nil then return baseStats end

	for _, modifier in traitInfo.Modifiers do
		local stat = modifier.Stat
		if baseStats[stat] == nil then
			baseStats[stat] = modifier.Value
		elseif modifier.Type == 'Percent' then
			baseStats[stat] = math.floor(baseStats[stat] * modifier.Value)
		elseif modifier.Type == 'Plus' then
			baseStats[stat] = math.floor(baseStats[stat] + modifier.Value)
		end
	end

	return baseStats
end

function self.GetDPS(damage, delay)
    local sec = delay / shared.Config.TICKPERSECOND_DEFAULT

    return math.floor(damage / sec)
end

function self.GetSellGems(towerUID, traitId)
	local towerData = TowerData.GetCloneData(towerUID)
	if towerData == nil then return 0 end

	self.ApplyModifiers(towerData, traitId)

	local dps = self.GetDPS(towerData.Damage, towerData.ActionDelay)
	return math.floor(dps / 10)
end

function self.GetBossDrop(round)
	return math.ceil(round / 5) + 3
end

function self.GetModifierByPoints(points)
	return math.floor(44.19 * math.sqrt(points))
end

--#region 克隆相关
function self.GetItemNeededForClone(towerUID : number)
	local qualityData = TowerData.GetQualityDictByTowerUID(towerUID)
	local mutId = TowerData.GetMutIdByTowerUID(towerUID)
	local level = TowerData.GetLvlByTowerUID(towerUID)

	if qualityData == nil or mutId == nil or level == nil then
		warn('clone data cal error')
		return
	end

	local result = qualityData.Value * 3 + level * 2 * mutId
	-- print(result)
	return result
end
function self.GetTimeNeededForClone(towerUID : number)
	local qualityData = TowerData.GetQualityDictByTowerUID(towerUID)
	local mutId = TowerData.GetMutIdByTowerUID(towerUID)
	local level = TowerData.GetLvlByTowerUID(towerUID)

	if qualityData == nil or mutId == nil or level == nil then
		warn('clone data cal error')
		return
	end

	local result = qualityData.Value * 30 + level * 12 * mutId
	-- print(result)
	return result
end
function self.GetCashNeededForClone(towerUID : number)
	local towerData = TowerData.GetData(towerUID)
	if towerData.Cost then
		return towerData.Cost
	end

	return nil
end
--#endregion

--#region 碎片合成相关
function self.GetFragmentConfig(itemId)
	local config = ItemData.FragmentConfig[itemId]
	if config == nil then warn('fragmentconfig fetch fail for itemId:', itemId); return end

	return config
end
--#endregion

return self