local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local self = {}

function self.Init(context)
    self.GetData = context.GetData
    self.SetPlayerData = context.SetPlayerData
    self.TowerModule = context.TowerModule
    self.GridModule = context.GridModule
    self.ItemModule = context.ItemModule
end

function self.Place(player, uid, towerUID, gridXY, shapeName)
    local tarData = self.GetData(player)
    if not tarData then return end

    local chk = self.GridModule.CheckPlace(tarData.Grid, shared.ShapeData[shapeName].Cells, gridXY[1], gridXY[2])
    if chk == true then
        self.GridModule.Place(tarData.Grid, shared.ShapeData[shapeName].Cells, gridXY[1], gridXY[2], uid)
        self.TowerModule.SetTowerGrid(tarData.Tower, uid, gridXY)
        self.SetPlayerData(player)
        return true
    end
    return false
end

function self.Remove(player, uid, towerUID, gridXY, shapeName)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.GridModule.Remove(tarData.Grid, shared.ShapeData[shapeName].Cells, gridXY[1], gridXY[2])
    self.TowerModule.SetTowerGrid(tarData.Tower, uid, nil)
    self.SetPlayerData(player)
end

function self.RemoveAll(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    for k, v in tarData.Tower.Inv do
        if v.GridXY == nil then continue end
        local staticData = TowerData.GetData(v.TowerUID)
        self.GridModule.Remove(tarData.Grid, shared.ShapeData[staticData.Shape].Cells, v.GridXY[1], v.GridXY[2])
        self.TowerModule.SetTowerGrid(tarData.Tower, v.UID, nil)
        self.TowerModule.UnEquip(tarData.Tower, v.UID)
    end

    self.SetPlayerData(player, 'TowerInv')
end

function self.AutoMerge(player)
	local tarData = self.GetData(player)
	if not tarData then return end
	local towerData = tarData.Tower

	while true do
		local byType = {}
		for uid, entry in towerData.Inv do
			if entry.GridXY ~= nil then continue end
			if entry.Cloning then continue end
			if entry.IsEvolving then continue end
			if TowerData.GetTowerNext(entry.TowerUID) == nil then continue end
			if byType[entry.TowerUID] == nil then byType[entry.TowerUID] = {} end
			table.insert(byType[entry.TowerUID], uid)
		end

		local baseUID, consumeUID = nil, nil
		for _, uids in byType do
			if #uids >= 2 then
				table.sort(uids, function(a, b)
					return (towerData.Inv[a].Trait or 0) > (towerData.Inv[b].Trait or 0)
				end)
				baseUID = uids[1]
				consumeUID = uids[2]
				break
			end
		end

		if baseUID == nil then break end

		shared.BackpackHandler.RemovePlayerBackpackTool(player, baseUID)
		shared.BackpackHandler.RemovePlayerBackpackTool(player, consumeUID)

		self.TowerModule.UpgradeTower(towerData, baseUID)
		self.TowerModule.DeleteTower(towerData, consumeUID)

		-- shared.BackpackHandler.AddPlayerBackpackTool(player, baseUID)
	end

	self.SetPlayerData(player, 'AutoMerge')
end

function self.GetTowerUIDByUID(player, uid)
    local tarData = self.GetData(player)
    if not tarData then return end

    local tarTowerUID = self.TowerModule.GetTowerUIDByUID(tarData.Tower, uid)
    if tarTowerUID == nil then return end
    return tarTowerUID
end

function self.Upgrade(player, uid, deletUID)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.TowerModule.UpgradeTower(tarData.Tower, uid)
    self.TowerModule.DeleteTower(tarData.Tower, deletUID)
    self.SetPlayerData(player)
end

function self.Trait(player, uid, traitId, rollCount)
    local tarData = self.GetData(player)
    if not tarData then return end

    local towerUID = self.TowerModule.GetTowerUIDByUID(tarData.Tower, uid)
    if towerUID == nil then return end
    -- local qualityData = TowerData.GetQualityDictByTowerUID(towerUID)
    -- if qualityData == nil then return end

    self.ItemModule.Remove(tarData.Item, shared.Config.TRAIT_ID, rollCount or 1)

    self.TowerModule.TraitTower(tarData.Tower, uid, traitId)
    self.SetPlayerData(player)

    ReplicatedStorage.Remote.Tower.RollTrait:FireClient(player, uid, traitId)
end

function self.Add(player, towerUID, newUID)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.TowerModule.AddTower(tarData.Tower, towerUID, newUID)
    self.SetPlayerData(player)
end

function self.AddTarget(player, towerUID, trait, uid)
    local tarData = self.GetData(player)
    if not tarData then return end

    if TowerData.GetData(towerUID) == nil then return end

    local newUID = uid or HttpService:GenerateGUID(false)
    self.TowerModule.AddTower(tarData.Tower, towerUID, newUID)

    if trait ~= 0 then
        self.TowerModule.TraitTower(tarData.Tower, newUID, trait)
    end

    self.SetPlayerData(player)
end

function self.Keep(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local pending = shared.GachaMachine.PendingAlien[player.UserId]
    if pending == nil then return end
    local towerUID = pending[1]
    local newUID = HttpService:GenerateGUID(false)
    self.TowerModule.AddTower(tarData.Tower, towerUID, newUID)

    shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)
    self.SetPlayerData(player)
end

function self.Gift(giver, receiver, uid)
	local giverData = self.GetData(giver)
	local receiverData = self.GetData(receiver)
	if not giverData or not receiverData then return end

	if not self.TowerModule.GiftTower(giverData.Tower, receiverData.Tower, uid) then return end

	self.SetPlayerData(giver)
	self.SetPlayerData(receiver)
end

function self.Delete(player, uid)
	local tarData = self.GetData(player)
	if not tarData then return end

	self.TowerModule.DeleteTower(tarData.Tower, uid)
	self.SetPlayerData(player, 'TowerInv')
end

function self.DeleteMany(player, uids)
	local tarData = self.GetData(player)
	if not tarData then return end

	for _, uid in uids do
		self.TowerModule.DeleteTower(tarData.Tower, uid)
	end
	self.SetPlayerData(player, 'TowerInv')
end

function self.SetTool(player, uid, isEquip)
    local tarData = self.GetData(player)
    if not tarData then return end

    if isEquip then
        self.TowerModule.Equip(tarData.Tower, uid)
    else
        self.TowerModule.UnEquip(tarData.Tower, uid)
    end

    self.SetPlayerData(player)
end

function self.UnToolAll(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    for uid, tower in tarData.Tower.Inv do
        self.TowerModule.UnEquip(tarData.Tower, uid)
    end

    self.SetPlayerData(player, 'TowerInv')
end

function self.BuyBundle(player, bundleType)
    local tarData = self.GetData(player)
    if not tarData then return end

    local newUID = HttpService:GenerateGUID(false)
    local towerUID = shared.RewardData.GachaBundle(bundleType)
    self.TowerModule.AddTower(tarData.Tower, towerUID, newUID)

    shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)
    self.SetPlayerData(player)
    ReplicatedStorage.Remote.Tower.Summon:FireClient(player, towerUID)
end

function self.BuyStarterPack(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Coin.Cash += 25000
    tarData.VIP.StarterPack = true
    local newUID = HttpService:GenerateGUID(false)
    local towerUID = 10001 + math.random(1, 6) * 100
    self.TowerModule.AddTower(tarData.Tower, towerUID, newUID)

    shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)
    self.SetPlayerData(player, 'VIP')
end

function self.BuyCloneTime(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local cloneData = tarData.Tower.Clone
    local remaining = cloneData.EndTime - workspace:GetServerTimeNow()
    cloneData.EndTime = workspace:GetServerTimeNow() + remaining / 2

    self.SetPlayerData(player, 'Clone')
end

function self.BuyEvolveTime(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local evolveData = tarData.Tower.Evolve
    local remaining = evolveData.EndTime - workspace:GetServerTimeNow()
    evolveData.EndTime = workspace:GetServerTimeNow() + remaining / 2

    self.SetPlayerData(player, 'Evolve')
end

function self.RepairCloneEvolve(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local towerData = tarData.Tower
    local cloneSource = towerData.Clone and towerData.Clone.SourceUID
    local evolveSource = towerData.Evolve and towerData.Evolve.SourceUID

    for uid, entry in towerData.Inv do
        if entry.Cloning and cloneSource ~= uid then
            entry.Cloning = nil
        end
        if entry.IsEvolving and evolveSource ~= uid then
            entry.IsEvolving = nil
        end
    end

    self.SetPlayerData(player)
end

function self.StartClone(player, uid)
    local tarData = self.GetData(player)
    if not tarData then return end

    local towerEntry = tarData.Tower.Inv[uid]
    if towerEntry == nil then return end

    local towerUID = towerEntry.TowerUID
    local qualityData = TowerData.GetQualityDictByTowerUID(towerUID)
    local itemNeeded = shared.CalculateData.GetItemNeededForClone(towerUID)
    local cashNeeded = shared.CalculateData.GetCashNeededForClone(towerUID)
    if qualityData == nil or itemNeeded == nil or cashNeeded == nil then return end

    local shardId = qualityData.Item

    self.ItemModule.Remove(tarData.Item, shardId, itemNeeded)
    shared.DataStore.CoinController.Consume(player, cashNeeded)

    local timeNeeded = shared.CalculateData.GetTimeNeededForClone(towerUID)
    local endTime = workspace:GetServerTimeNow() + timeNeeded * 60

    self.TowerModule.UnEquip(tarData.Tower, uid)
    shared.BackpackHandler.RemovePlayerBackpackTool(player, uid)

    self.TowerModule.StartClone(tarData.Tower, uid, endTime)
    self.SetPlayerData(player, 'Clone')
end
function self.ClaimClone(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    if not self.TowerModule.CheckClone(tarData.Tower) then return end

    local newUID = HttpService:GenerateGUID(false)
    local resultUID, towerUID = self.TowerModule.CompleteClone(tarData.Tower, newUID)
    if resultUID then
        shared.BackpackHandler.AddPlayerBackpackTool(player, resultUID)
        self.SetPlayerData(player, 'CloneCompleted')

        ReplicatedStorage.Remote.Loot:FireClient(player, {Tower = towerUID})
    end
end


function self.StartEvolve(player, uid, targetTowerUID, evolveTime, items)
    local tarData = self.GetData(player)
    if not tarData then return end

    local towerEntry = tarData.Tower.Inv[uid]
    if towerEntry == nil then return end

    for itemId, count in items do
        self.ItemModule.Remove(tarData.Item, tonumber(itemId), count)
    end

    local endTime = workspace:GetServerTimeNow() + evolveTime

    self.TowerModule.UnEquip(tarData.Tower, uid)
    shared.BackpackHandler.RemovePlayerBackpackTool(player, uid)

    self.TowerModule.StartEvolve(tarData.Tower, uid, targetTowerUID, endTime)
    self.SetPlayerData(player, 'Evolve')
end
function self.ClaimEvolve(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    if not self.TowerModule.CheckEvolve(tarData.Tower) then return end

    local resultUID, towerUID = self.TowerModule.CompleteEvolve(tarData.Tower)
    if resultUID then
        shared.BackpackHandler.AddPlayerBackpackTool(player, resultUID)
        self.SetPlayerData(player, 'EvolveCompleted')

        ReplicatedStorage.Remote.Loot:FireClient(player, {Tower = towerUID})
    end
end

return self
