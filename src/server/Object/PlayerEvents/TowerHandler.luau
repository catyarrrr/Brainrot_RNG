local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = ReplicatedStorage
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local SummonData = require(ReplicatedStorage.Datas.SummonData :: ModuleScript)
local TraitData = require(ReplicatedStorage.Datas.TraitData :: ModuleScript)

local raycastParams, rng = RaycastParams.new(), Random.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

local COMBINE_GEM_COST = { [1] = 1200, [2] = 3000, [3] = 9000, [4] = 12000, [5] = 16000 }
local self = {}

local function IsGoldMut()
	local event = shared.ServerEvent
	if event.State and event.State.name == event.StateDict.GoldMut then
		return true
	end
	return false
end

function self.SpawnTower(player, uid, towerName, cframe: CFrame, towerUID, gridXY, shapeName)
	raycastParams.FilterDescendantsInstances = {workspace.Platforms}
	if not workspace:Raycast(cframe.Position + cframe.UpVector*.2, -cframe.UpVector*1, raycastParams) then warn('can not place here'); return end

	local isUpgrade = true
	local curUID = shared.DataStore.GridController.GetUIDByGrid(player, gridXY)
	local curTowerUID = curUID and shared.DataStore.TowerController.GetTowerUIDByUID(player, curUID)
	if curTowerUID == nil or curTowerUID ~= towerUID then isUpgrade = false end
	local nextTowerUID = curTowerUID and TowerData.GetTowerNext(curTowerUID)
	if nextTowerUID == nil then isUpgrade = false end

	if isUpgrade then
		rs.Remote.Tower.TowerUpgrade:FireClient(player, cframe)
		self.UpgradeTower(player, curUID, uid)
	else
		local chk = shared.DataStore.TowerController.Place(player, uid, towerUID, gridXY, shapeName)
		if chk == false then
			ReplicatedStorage.Remote.Sound.AlienPlace_Fail:FireClient(player)
			ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Can not place Brainrot here!!!')
			return
		end
		local pathId = shared.DataStore.GetPlayerCurPath(player)
		local playerData = shared.DataStore.GetData(player)
		local towerInvData = playerData and playerData.Tower.Inv[uid]
		local traitId = towerInvData and towerInvData.Trait
		shared.DataStore.PlayerConfirmGuide(player, 3)
		shared.SoundHandler:PlayAt('AlienPlace_Success', cframe.Position)
		shared.Tower.new(player, towerUID, uid, towerName, cframe, 1, nil, gridXY, shapeName, pathId, traitId)
		shared.BackpackHandler.RemovePlayerBackpackTool(player, uid)
	end
end
function self.DespawnTower(player, id)
	local targetTower = shared.Tower.collections[id]
	if not targetTower then warn('id not correct or not exist'); return end

	if targetTower.Owner ~= player then warn('this is not your tower'); return end

	shared.DataStore.TowerController.Remove(player, targetTower.UID, targetTower.TowerUID, targetTower.GridXY, targetTower.Shape)
	shared.BackpackHandler.AddPlayerBackpackTool(player, targetTower.UID)

	targetTower:Destroy()
end
function self.PickUpAll(player)
	shared.DataStore.TowerController.RemoveAll(player)
	shared.Tower.PickupAllEvent:Fire(player)
end
function self.UnToolAll(player)
	shared.BackpackHandler.ClearPlayerBackpack(player)
	shared.DataStore.TowerController.UnToolAll(player)
end
function self.EquipTower(player, isEquip, tool)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if isEquip == true then
		humanoid:EquipTool(tool)
	else
		humanoid:UnequipTools()
	end
end
function self.UpgradeTower(player, uid, deleteUID)
	local targetTower = shared.Tower.GetByUID(uid)
	if not targetTower then warn('fetch tower error for uid:', uid); return end

	if targetTower.Owner ~= player then warn('this is not your tower'); return end

	shared.DataStore.TowerController.Upgrade(player, uid, deleteUID)
	shared.BackpackHandler.RemovePlayerBackpackTool(player, deleteUID)

	targetTower:Upgrade()
end
function self.TraitTower(player, uid, isX5)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local towerData = playerData.Tower.Inv[uid]
	if towerData == nil then warn('tower not found for trait'); return end
	local qualityData = TowerData.GetQualityDictByTowerUID(towerData.TowerUID)
	if qualityData == nil then return end

	local rollCount = 1
	if isX5 == true then rollCount = 5 end

	local chk = true
	local cashChk = shared.DataStore.CoinController.CheckCash(player, qualityData.TraitCost[1])
	if cashChk == false then chk = false end
	local traitCount = playerData.Item.Inv[tostring(shared.Config.TRAIT_ID)] or 0
	if traitCount < rollCount then chk = false end

	if chk == false then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Not enough Cash or Trait Shard')
		return
	end

	local traitDict = TraitData.GetAll()
	if isX5 == true then traitDict = TraitData.GetAllBoost() end
	local key = shared.Tool.GachaByDict(traitDict)
	shared.DataStore.CoinController.Consume(player, qualityData.TraitCost[1])
	shared.DataStore.TowerController.Trait(player, uid, key, rollCount)
end
function self.CloneTower(player, uid)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local towerEntry = playerData.Tower.Inv[uid]
	if towerEntry == nil then return end
	if playerData.Tower.Clone.SourceUID then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Already cloning a Brainrot')
		return
	end

	local towerUID = towerEntry.TowerUID
	local qualityData = TowerData.GetQualityDictByTowerUID(towerUID)
	if qualityData == nil then return end

	local shardId = qualityData.Item
	local itemNeeded = shared.CalculateData.GetItemNeededForClone(towerUID)
	if itemNeeded == nil then return end

	local itemChk = shared.DataStore.ItemModule.Chk(playerData.Item, shardId, itemNeeded)
	if itemChk == false then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Not enough Clone Shards')
		return
	end

	local cashNeeded = shared.CalculateData.GetCashNeededForClone(towerUID)
	if cashNeeded == nil then return end

	local cashChk = shared.DataStore.CoinController.CheckCash(player, cashNeeded)
	if cashChk == false then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Not enough Cash')
		return
	end

	shared.DataStore.TowerController.StartClone(player, uid)

	shared.SoundHandler:PlayAtPlayer('AlienClone', player)
end
function self.CompleteClone(player, uid)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local cloneData = playerData.Tower.Clone
	if cloneData.SourceUID == false then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'No clone in progress')
		return
	end

	if workspace:GetServerTimeNow() < cloneData.EndTime then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Clone is not complete yet')
		return
	end

	shared.DataStore.TowerController.ClaimClone(player)
end
function self.EvolveTower(player, uid, evoKey)
	if uid == nil then rs.Remote.ServerWarn:FireClient(player, 'Select a Brainrot !!!'); return end
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local towerEntry = playerData.Tower.Inv[uid]
	if towerEntry == nil then return end

	local evoDict = TowerData.GetEvolutionDict()
	local curDict = evoDict[evoKey]
	if curDict == nil then warn('evoDict fetch error for key:', evoKey); return end

	if playerData.Tower.Evolve.SourceUID then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Already evolving a Brainrot')
		return
	end

	local itemChk = true
	for k, v in curDict.NeedItems do
		local needed = v
		local cur = playerData.Item.Inv[tostring(k)] or 0
		if needed > cur then itemChk = false; break end
	end
	if itemChk == false then rs.Remote.ServerWarn:FireClient(player, 'Items not enough!!!'); return end

	local chk = shared.DataStore.CoinController.CheckCash(player, curDict.NeedCoin)
	if chk == false then rs.Remote.ServerWarn:FireClient(player, 'Cash not enough!!!'); return end
	shared.DataStore.CoinController.Consume(player, curDict.NeedCoin)

	shared.DataStore.TowerController.StartEvolve(player, uid, curDict.Target, curDict.NeedTime, curDict.NeedItems)
	shared.SoundHandler:PlayAtPlayer('AlienEvolve', player)
end
function self.CompleteEvolve(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local evolveData = playerData.Tower.Evolve
	if evolveData.SourceUID == false then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'No evolve in progress')
		return
	end

	if workspace:GetServerTimeNow() < evolveData.EndTime then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Evolve is not complete yet')
		return
	end

	shared.DataStore.TowerController.ClaimEvolve(player)
end
function self.SetTool(player, uid, isEquip)
	if isEquip then
		shared.DataStore.TowerController.SetTool(player, uid, isEquip)
		shared.BackpackHandler.AddPlayerBackpackTool(player, uid)
	else
		shared.DataStore.TowerController.SetTool(player, uid, isEquip)
		shared.BackpackHandler.RemovePlayerBackpackTool(player, uid)
	end
end
function self.QuickMerge(player, id)
	local tower = shared.Tower.collections[id]
	if tower == nil then warn('upgrade tower not found for id:', id); return end
	local nextTowerUID = TowerData.GetTowerNext(tower.TowerUID)
	if nextTowerUID == nil then warn('tower can not upgrade for id:', id); return end
	local tool = player.Character:FindFirstChildOfClass('Tool')
	if tool == nil then warn('upgrade tool not found for id:', id); return end
	if tool:GetAttribute('TowerUID') ~= tower.TowerUID or tower.Owner ~= player then warn('data error for merge'); return end
	local deleteUID = tool:GetAttribute('UID')
	if deleteUID == nil then warn('delete uid not found for id:', id); return end
	tool:Destroy()

	rs.Remote.Tower.TowerUpgrade:FireClient(player, tower.CFrame)
	shared.DataStore.TowerController.Upgrade(player, tower.UID, deleteUID)

	tower:Upgrade()
end
function self.AutoMerge(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	if playerData.VIP.AutoMerge == false then return end

	shared.DataStore.TowerController.AutoMerge(player)
end
function self.CombineTower(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local toolUIDs = {}
	local function collect(parent)
		if not parent then return end
		for _, child in parent:GetChildren() do
			if child:IsA('Tool') then
				local uid = child:GetAttribute('UID')
				if uid then toolUIDs[uid] = true end
			end
		end
	end
	collect(player:FindFirstChild('Backpack'))
	collect(player.Character)

	local byMut = {}
	for uid in toolUIDs do
		local towerUID = shared.DataStore.TowerController.GetTowerUIDByUID(player, uid)
		if towerUID == nil then continue end
		local mutId = TowerData.GetMutIdByTowerUID(towerUID)
		if mutId == nil then continue end
		if byMut[mutId] == nil then byMut[mutId] = {} end
		table.insert(byMut[mutId], uid)
	end

	local targetMutId, targetUIDs
	for mutId, uids in byMut do
		if #uids >= 5 then
			targetMutId = mutId
			targetUIDs = uids
			break
		end
	end

	if targetMutId == nil then
		rs.Remote.Tower.Combine:FireClient(player, false, 'You need 5 Aliens with the same Mutation to mutate')
		return
	end

	local gemCost = COMBINE_GEM_COST[targetMutId]
	if gemCost and not shared.DataStore.CoinController.CheckGems(player, gemCost) then
		rs.Remote.Tower.Combine:FireClient(player, false, 'Not enough Gems! You need ' .. gemCost .. ' Gems to mutate!')
		return
	end

	local pool = SummonData.GachaEvoPool(targetMutId)
	if pool == nil then
		rs.Remote.Tower.Combine:FireClient(player, false, "They're already maxed out. Can't fuse them!")
		return
	end

	local consumeUIDs = {}
	for i = 1, 5 do table.insert(consumeUIDs, targetUIDs[i]) end
	for _, uid in consumeUIDs do
		shared.BackpackHandler.RemovePlayerBackpackTool(player, uid)
	end
	shared.DataStore.TowerController.DeleteMany(player, consumeUIDs)
	if gemCost then shared.DataStore.CoinController.ConsumeGems(player, gemCost) end

	local newTowerUID = shared.Tool.GachaByDict(pool)

	local newUID = HttpService:GenerateGUID(false)
	shared.DataStore.TowerController.Add(player, newTowerUID, newUID)
	shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)

	rs.Remote.Loot:FireClient(player, { Tower = newTowerUID })
	rs.Remote.Tower.Combine:FireClient(player, true)
end
function self.SellTower(player)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass('Tool')

	local backpack = player:FindFirstChild('Backpack')
	local hasBackpackTool = false
	if backpack then for _, child in backpack:GetChildren() do if child:IsA('Tool') and child:GetAttribute('UID') then hasBackpackTool = true; break end end end
	if not tool and hasBackpackTool then rs.Remote.Tower.Sell:FireClient(player, false, "Don't be shy, take that little guy out!"); return end

	if not tool then rs.Remote.Tower.Sell:FireClient(player, false, "Where's the goods, buddy?"); return end
	local uid = tool:GetAttribute('UID')
	if not uid then rs.Remote.Tower.Sell:FireClient(player, false, "Where's the goods, buddy?"); return end

	local towerUID = shared.DataStore.TowerController.GetTowerUIDByUID(player, uid)
	if towerUID == nil then rs.Remote.Tower.Sell:FireClient(player, false, 'Alien not found'); return end

	local staticData = TowerData.GetData(towerUID)
	if staticData == nil or staticData.Cost == nil then rs.Remote.Tower.Sell:FireClient(player, false, 'Alien not found'); return end

	local cash = math.floor(staticData.Cost * rng:NextNumber(.1, 1.5))
	if IsGoldMut() then cash *= 2 end

	local playerData = shared.DataStore.GetData(player)
	local towerEntry = playerData and playerData.Tower.Inv[uid]
	local traitId = towerEntry and towerEntry.Trait
	local gems = shared.CalculateData.GetSellGems(towerUID, traitId)
	if IsGoldMut() then gems *= 2 end

	tool:Destroy()
	shared.BackpackHandler.RemovePlayerBackpackTool(player, uid)
	shared.DataStore.TowerController.Delete(player, uid)
	shared.DataStore.CoinController.SellForCash(player, cash)
	shared.DataStore.CoinController.GemsInc(player, gems)

	rs.Remote.Loot:FireClient(player, { Cash = cash, Gems = gems })
	rs.Remote.Tower.Sell:FireClient(player, true, cash)
end
function self.EstimateTower(player)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass('Tool')

	if not tool then rs.Remote.Tower.Estimate:FireClient(player, false, "Where's the goods, buddy?"); return end
	local uid = tool:GetAttribute('UID')
	if not uid then rs.Remote.Tower.Estimate:FireClient(player, false, "Where's the goods, buddy?"); return end

	local towerUID = shared.DataStore.TowerController.GetTowerUIDByUID(player, uid)
	if towerUID == nil then rs.Remote.Tower.Estimate:FireClient(player, false, 'Alien not found'); return end

	local staticData = TowerData.GetData(towerUID)
	if staticData == nil or staticData.Cost == nil then rs.Remote.Tower.Estimate:FireClient(player, false, 'Alien not found'); return end

	local cashMin = math.floor(staticData.Cost * 0.1)
	local cashMax = math.floor(staticData.Cost * 1.5)

	local playerData = shared.DataStore.GetData(player)
	local towerEntry = playerData and playerData.Tower.Inv[uid]
	local traitId = towerEntry and towerEntry.Trait
	local gems = shared.CalculateData.GetSellGems(towerUID, traitId)

	rs.Remote.Tower.Estimate:FireClient(player, true, gems, cashMin, cashMax)
end
function self.SellAllTowers(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local uids = {}
	local function collect(parent)
		if not parent then return end
		for _, tool in parent:GetChildren() do
			if tool:IsA('Tool') then
				local uid = tool:GetAttribute('UID')
				if uid then uids[uid] = true end
			end
		end
	end
	collect(player:FindFirstChild('Backpack'))
	collect(player.Character)

	local totalCash = 0
	local totalGems = 0
	local count = 0
	local multiplier = IsGoldMut() and 2 or 1
	local toDelete = {}
	for uid in uids do
		local towerUID = shared.DataStore.TowerController.GetTowerUIDByUID(player, uid)
		if towerUID == nil then continue end
		local staticData = TowerData.GetData(towerUID)
		if staticData == nil or staticData.Cost == nil then continue end

		totalCash += math.floor(staticData.Cost * rng:NextNumber(.1, 1.5)) * multiplier
		local towerEntry = playerData.Tower.Inv[uid]
		local traitId = towerEntry and towerEntry.Trait
		totalGems += shared.CalculateData.GetSellGems(towerUID, traitId) * multiplier
		table.insert(toDelete, uid)
		shared.BackpackHandler.RemovePlayerBackpackTool(player, uid)
		count += 1
	end

	if count == 0 then
		rs.Remote.Tower.SellAll:FireClient(player, false, "Where's the goods, buddy?")
		return
	end

	shared.DataStore.TowerController.DeleteMany(player, toDelete)
	shared.DataStore.CoinController.SellForCash(player, totalCash)
	shared.DataStore.CoinController.GemsInc(player, totalGems)
	rs.Remote.Loot:FireClient(player, { Cash = totalCash, Gems = totalGems })
	rs.Remote.Tower.SellAll:FireClient(player, true, totalCash)
end

return self
