local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = ReplicatedStorage
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)

local self = {}

function self.UpgradeGrid(player)
	local playerData = shared.DataStore.GetData(player)
	local pathId = shared.DataStore.GetPlayerCurPath(player)

	local gridLevel = TempData.GetLevelByGrid(playerData.Grid)
	if gridLevel == shared.DataStore.GridModule.LEVEL_MAX then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Level Max!!!')
		return
	end
	local cost = TempData.BaseDict[gridLevel].NextCost
	local chk = shared.DataStore.CoinController.CheckCash(player, cost)
	if chk == false then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Cash not enough!!!')
		return
	end

	shared.DataStore.GridController.UpgradeGrid(player)
	shared.Area.UpgradeEvent:Fire(pathId)

	rs.Remote.PlayerUpgradeGrid:FireClient(player)
end
function self.UpgradeCash(player)
	local playerData = shared.DataStore.GetData(player)
	local cashMuti = playerData.Coin.CashMultiplier
	local curLevel = TempData.GetCashLvlByMultiplier(cashMuti)

	if TempData.CashDict[curLevel + 1] == nil then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Level Max!!!')
		return
	else
		local cost = TempData.CashDict[curLevel].NextCost
		local chk = shared.DataStore.CoinController.CheckCash(player, cost)
		if chk == true then
			shared.DataStore.CoinController.UpgradeCash(player, cost, curLevel + 1)
		else
			ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Cash not Enough!!!')
			return
		end
	end
end
function self.UpgradeLuck(player)
	local playerData = shared.DataStore.GetData(player)
	local luck = playerData.Gacha.Luck
	if playerData.VIP.DoubleLuck then luck -= 1 end
	if playerData.VIP.TripleLuck then luck -= 1 end
	if luck >= TempData.MAX_LUCK then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Level MAX!!!')
		return
	else
		local cost = TempData.LuckDict[luck].NextCost
		local chk = shared.DataStore.CoinController.CheckCash(player, cost)
		if chk == true then
			shared.DataStore.GachaController.UpgradeLuck(player, cost)
		else
			ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Cash not enough!!!')
			return
		end
	end
end
function self.UpgradeStartLevel(player)
	local playerData = shared.DataStore.GetData(player)
	local startLevel = playerData.Profile.StartLevel
	local startLevelData = TempData.StartLevelDict[startLevel]

	if startLevelData.Next == nil then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Level MAX!!!')
		return
	else
		local cost = startLevelData.Cost
		local chk = shared.DataStore.CoinController.CheckCash(player, cost)
		if chk == true then
			shared.DataStore.CoinController.UpgradeStartLevel(player, cost, startLevelData.Next)
		else
			ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Cash not enough!!!')
			return
		end
	end
end
function self.BuyTerritory(player, terrId)
	local playerData = shared.DataStore.GetData(player)

	local hasSkin = playerData.Grid.Skins[terrId]
	if hasSkin == true then
		rs.Remote.ServerWarn:FireClient(player, 'Already own this territory')
		return
	else
		local cost = TempData.TerrDict[terrId].Cost
		local chk = shared.DataStore.CoinController.CheckCash(player, cost)
		if chk == true then
			shared.DataStore.GridController.BuyAreaSkin(player, terrId, cost)
			local curPath = shared.DataStore.GetPlayerCurPath(player)
			shared.Area.collections[curPath]:SwitchSkin(terrId)
			shared.DataStore.GridController.SetAreaSkin(player, terrId)
		else
			rs.Remote.ServerWarn:FireClient(player, 'Cash not enough!!!')
			return
		end
	end
end

return self
