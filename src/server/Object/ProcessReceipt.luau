local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)

local self = {}
local ProductHandlers = nil

function self.init()
	local KeepAlienHandler = function(player)
		shared.DataStore.TowerController.Keep(player)
		shared.GachaMachine.ClearPendingAien(player)
		return true
	end
	local PrayOnce = function(player)
		local roll = Random.new():NextNumber(0, 1)
		local count = 1
		if roll <= 0.001 then
			count = 3
		elseif roll <= 0.001 + 0.099 then
			count = 2
		end
		for i = 1, count do
			local totemUID = TotemData.Gacha()
			if totemUID == nil then return false end
			ReplicatedStorage.Remote.Tower.PrayTotem:FireClient(player, totemUID)
			task.wait(.2)
		end
		return true
	end

	local BuyExclusiveAlien = function(player, alienIds)
		local towerUID = alienIds[Random.new():NextInteger(1, #alienIds)]
		local newUID = HttpService:GenerateGUID(false)
		shared.DataStore.TowerController.Add(player, towerUID, newUID)
		shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)
		ReplicatedStorage.Remote.Tower.Summon:FireClient(player, towerUID)
		return true
	end

	ProductHandlers = {
	---------------- cash购买
		[shared.ProductDatas['29999xCash']] = function(player) shared.DataStore.CoinController.BuyCash(player, 29999); return true end,
		[shared.ProductDatas['89999xCash']] = function(player) shared.DataStore.CoinController.BuyCash(player, 89999); return true end,
		[shared.ProductDatas['229999xCash']] = function(player) shared.DataStore.CoinController.BuyCash(player, 229999); return true end,
		[shared.ProductDatas['599999xCash']] = function(player) shared.DataStore.CoinController.BuyCash(player, 599999); return true end,

		---------------- Bundle购买
		[shared.ProductDatas['RanBrainrot']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 0); return true end,
		[shared.ProductDatas['LegendaryBundle']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 1); return true end,
		[shared.ProductDatas['MythicBundle']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 2); return true end,
		[shared.ProductDatas['SecretBundle']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 3); return true end,
		[shared.ProductDatas['GodBundle']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 4); return true end,
		[shared.ProductDatas['DivineBundle']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 5); return true end,
		[shared.ProductDatas['LimitedBundle']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 6); return true end,
		
		[shared.ProductDatas['Mut1Bundle']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 13); return true end,
		[shared.ProductDatas['Mut2Bundle']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 12); return true end,
		[shared.ProductDatas['Legendary&MythicBundle']] = function(player) shared.DataStore.TowerController.BuyBundle(player, 11); return true end,

		---------------- 转盘购买
		[shared.ProductDatas.x1Spin] = function(player) shared.DataStore.GachaController.BuySpin(player, 1); return true end,
		[shared.ProductDatas.x5Spin] = function(player) shared.DataStore.GachaController.BuySpin(player, 5); return true end,

		[shared.ProductDatas['x3Offline']] = function(player) shared.DataStore.RewardController.ClaimOfflineReward(player, true); return true end,

		---------------- 升级购买
		[shared.ProductDatas.BaseUpgrade] = function(player) 
			local pathId = shared.DataStore.GetPlayerCurPath(player)
			shared.Area.UpgradeEvent:Fire(pathId)
			shared.DataStore.GridController.BuyGridUpgrade(player); 
			return true 
		end,
		[shared.ProductDatas.LuckUpgrade] = function(player) 
			local playerData = shared.DataStore.GetData(player)
			local luck = playerData.Gacha.Luck
			local doubleluck = playerData.VIP.DoubleLuck
			local tripleluck = playerData.VIP.TripleLuck
			if doubleluck then luck -= 1 end
			if tripleluck then luck -= 1 end

			if luck >= TempData.MAX_LUCK then 
				return false
			else
				shared.DataStore.GachaController.BuyLuckUpgrade(player)
			end
			return true 
		end,
		[shared.ProductDatas.CashUpgrade] = function(player) 
			local playerData = shared.DataStore.GetData(player)
			local cashMuti = playerData.Coin.CashMultiplier
			local curLevel = TempData.GetCashLvlByMultiplier(cashMuti)

			if TempData.CashDict[curLevel + 1] == nil then 
				return false
			else
				shared.DataStore.CoinController.BuyCashUpgrade(player, curLevel + 1)
			end
			return true 
		end,
		[shared.ProductDatas.StartLevelUpgrade] = function(player) 
			local playerData = shared.DataStore.GetData(player)
			local startLevel = playerData.Profile.StartLevel
			local startLevelData = TempData.StartLevelDict[startLevel]

			if startLevelData.Next == nil then 
				return false
			else
				shared.DataStore.CoinController.BuyStartLevelUpgrade(player, startLevelData.Next)
			end
			return true 
		end,
		---------------- 服务器幸运购买
		[shared.ProductDatas['2xServerLuck']] = function(player) 
			shared.ServerEvent.AddServerLuck(player)
			return true 
		end,

		---------------- 碎片购买
		[shared.ProductDatas.LegendaryFragments] = function(player) shared.DataStore.RewardController.BuyFragments(player, 105); return true end,
		[shared.ProductDatas.MythicFragments] = function(player) shared.DataStore.RewardController.BuyFragments(player, 106); return true end,
		[shared.ProductDatas.SecretFragments] = function(player) shared.DataStore.RewardController.BuyFragments(player, 107); return true end,
		[shared.ProductDatas.GodFragments] = function(player) shared.DataStore.RewardController.BuyFragments(player, 108); return true end,
		[shared.ProductDatas.LimitedGodFragments] = function(player) shared.DataStore.RewardController.BuyFragments(player, 108); return true end,

		---------------- trait购买
		[shared.ProductDatas['x1Trait']] = function(player) shared.DataStore.CoinController.BuyTrait(player, 1); return true end,
		[shared.ProductDatas['x10Trait']] = function(player) shared.DataStore.CoinController.BuyTrait(player, 10); return true end,
		[shared.ProductDatas['x25Trait']] = function(player) shared.DataStore.CoinController.BuyTrait(player, 25); return true end,
		[shared.ProductDatas['x100Trait']] = function(player) shared.DataStore.CoinController.BuyTrait(player, 100); return true end,

		---------------- time购买
		[shared.ProductDatas['-50%Time_Clone']] = function(player) shared.DataStore.TowerController.BuyCloneTime(player); return true end,
		[shared.ProductDatas['-50%Time_Evolve']] = function(player) shared.DataStore.TowerController.BuyEvolveTime(player); return true end,

		---------------- boss挑战购买
		[shared.ProductDatas['x1BossChallenge']] = function(player) shared.DataStore.GachaController.BuyChallenge(player, 1); return true end,
		[shared.ProductDatas['x2BossChallenge']] = function(player) shared.DataStore.GachaController.BuyChallenge(player, 2); return true end,
		[shared.ProductDatas['x3BossChallenge']] = function(player) shared.DataStore.GachaController.BuyChallenge(player, 3); return true end,

		---------------- alien保留
		[shared.ProductDatas.KeepAlienEpic] = KeepAlienHandler,
		[shared.ProductDatas.KeepAlienLegendary] = KeepAlienHandler,
		[shared.ProductDatas.KeepAlienMythic] = KeepAlienHandler,
		[shared.ProductDatas.KeepAlienSecret] = KeepAlienHandler,
		[shared.ProductDatas.KeepAlienGod] = KeepAlienHandler,
		[shared.ProductDatas.KeepAlienDivine] = KeepAlienHandler,
		[shared.ProductDatas.KeepAlienLimited] = KeepAlienHandler,

		---------------- totem许愿购买
		[shared.ProductDatas['PrayTotem']] = function(player) 
			return PrayOnce(player)
		end,
		[shared.ProductDatas['PrayTotemx10']] = function(player)
			for i = 1, 10 do
				if PrayOnce(player) == false then return false end
			end
			return true
		end,
	}
end

function self.start()
	MarketplaceService.ProcessReceipt = self.Process
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passID, wasPurchased)
		if wasPurchased then
			shared.DataStore.AddSpend(player, self.GetRobuxPrice(passID, Enum.InfoType.GamePass))
		end
		if wasPurchased and passID == shared.ProductDatas.PASSID_VIP then
			shared.DataStore.CoinController.BuyVIP(player)
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_2XCash then
			shared.DataStore.CoinController.BuyDoubleCash(player)
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_2XLuck then
			shared.DataStore.GachaController.BuyDoubleLuck(player)
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_3XLuck then
			shared.DataStore.GachaController.BuyTripleLuck(player)
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_StarterPack then
			shared.DataStore.TowerController.BuyStarterPack(player)
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_2XDROP then
			shared.DataStore.GachaController.BuyPass(player, 'Dropx2')
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_2XMUTATION then
			shared.DataStore.GachaController.BuyPass(player, 'Mutationx2')
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_FASTROLL then
			shared.DataStore.GachaController.BuyPass(player, 'FastRoll')
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_AUTOMERGE then
			shared.DataStore.GachaController.BuyPass(player, 'AutoMerge')
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_TOTEMSLOT then
			shared.DataStore.TotemController.UnlockTotemSlot(player)
		elseif wasPurchased and passID == shared.ProductDatas.PASSID_CLONESLOT then
			shared.DataStore.TowerController.UnlockCloneSlot(player)
		end
	end)
end 

function self.GetRobuxPrice(id, infoType)
	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	if success and info and type(info.PriceInRobux) == "number" then
		return info.PriceInRobux
	end
	return 0
end

function self.Process(receiptInfo)
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local player = Players:GetPlayerByUserId(playerId)
	
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	local handler = ProductHandlers[productId]
	local result, success
	if handler then
		success, result = pcall(handler, player)
		if success and result then
			shared.DataStore.AddSpend(player, self.GetRobuxPrice(productId, Enum.InfoType.Product))
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	warn('purchase failed for error', result)
	
	return Enum.ProductPurchaseDecision.NotProcessedYet
end


return self