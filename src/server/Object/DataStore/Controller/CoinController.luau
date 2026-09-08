local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)

local rng = Random.new()
local self = {FriendMap = {}, FriendCount = {}}

function self.Init(context)
    self.GetData = context.GetData
    self.SetPlayerData = context.SetPlayerData
    self.ItemModule = context.ItemModule
end

function self.ClearFriendOnExit(player)
    local friends = self.FriendMap[player]
    if friends then
        for other, _ in pairs(friends) do
            if self.FriendCount[other] then
                self.FriendCount[other] -= 1
            end
            if self.FriendMap[other] then
                self.FriendMap[other][player] = nil
            end
        end
    end
    self.FriendMap[player] = nil
    self.FriendCount[player] = nil
end

function self.UpdateFriendOnEnter(player)
    self.FriendCount[player] = 0
    self.FriendMap[player] = {}

    for _, other in Players:GetPlayers() do
        if other ~= player then
            local success, isFriend = pcall(player.IsFriendsWithAsync, player, other.UserId)
            if success and isFriend then
                self.FriendCount[player] += 1
                self.FriendMap[player][other] = true

                if self.FriendCount[other] then
                    self.FriendCount[other] += 1
                end
                if self.FriendMap[other] then
                    self.FriendMap[other][player] = true
                end
            end
        end
    end
end

function self.Farm(player, reward)
    local tarData = self.GetData(player)
    if not tarData then return end
    
    local friendBoost = (self.FriendCount[player] or 0) * shared.Config.COIN_FRIENDBOOST + 1
    local boost = shared.Config.COIN_COLLECTIONBOOST
    local collectionMulti = math.floor(tarData.Tower.Collection.Total / boost) * boost / 100 + 1
    tarData.Coin.Cash += reward * (tarData.Coin.CashMultiplier + tarData.Coin.VipMultiplier + collectionMulti + friendBoost)
    tarData.Profile.Kills += 1

    self.SetPlayerData(player, 'Cash')
end

function self.CheckCash(player, cost)
    local tarData = self.GetData(player)
    if not tarData then return end

    local tarCash = tarData.Coin.Cash - cost
 
    if tarCash < 0 then
        return false
    else
        return true
    end
end

function self.Consume(player, cost)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Coin.Cash -= cost

    self.SetPlayerData(player, 'Cash')
end

function self.CheckGems(player, cost)
    local tarData = self.GetData(player)
    if not tarData then return end

    local tarGems = tarData.Coin.Gems - cost

    if tarGems < 0 then
        return false
    else
        return true
    end
end

function self.ConsumeGems(player, cost)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Coin.Gems -= cost

    self.SetPlayerData(player, 'Cash')
end

function self.UpgradeCash(player, cost, nextLevel)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.Consume(player, cost)
    local multi = TempData.CashDict[nextLevel].Multiplier
    tarData.Coin.CashMultiplier = multi

    self.SetPlayerData(player)
end
function self.UpgradeStartLevel(player, cost, nextStartLevel)
    local tarData = self.GetData(player)
    if not tarData then return end

    local chk = self.CheckCash(player, cost)
    if chk == nil then return end

    self.Consume(player, cost)
    tarData.Profile.StartLevel = nextStartLevel

    self.SetPlayerData(player)
end

function self.BuyDoubleCash(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Coin.VipMultiplier = 2
    tarData.VIP.DoubleCash = true

    self.SetPlayerData(player, 'VIP')
end

function self.BuyVIP(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.VIP.VIP = true

    self.SetPlayerData(player, 'VIP')
end

function self.BuyCash(player, amount)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Coin.Cash += amount

    self.SetPlayerData(player, 'Cash')
end

function self.SellForCash(player, amount)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Coin.Cash += amount

    self.SetPlayerData(player, 'Cash')
end

function self.GemsInc(player, amount)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Coin.Gems += amount

    self.SetPlayerData(player, 'Cash')
end

function self.BuyCashUpgrade(player, nextLevel)
    local tarData = self.GetData(player)
    if not tarData then return end

    local multi = TempData.CashDict[nextLevel].Multiplier
    tarData.Coin.CashMultiplier = multi

    self.SetPlayerData(player)
end
function self.BuyStartLevelUpgrade(player, nextLevel)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Profile.StartLevel = nextLevel

    self.SetPlayerData(player)
end

function self.BuyTrait(player, amount)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.ItemModule.AddItem(tarData.Item, shared.Config.TRAIT_ID, amount)

    self.SetPlayerData(player, {'Trait'})
end

function self.FuseFragment(player, itemId)
    local tarData = self.GetData(player)
    if not tarData then return end

    local config = shared.CalculateData.GetFragmentConfig(itemId)
    if config == nil then return end

    self.Consume(player, config.NeedCash)
    self.ItemModule.Remove(tarData.Item, itemId, config.NeedCount)

    if rng:NextNumber() < config.SuccessRate then
        self.ItemModule.AddItem(tarData.Item, config.ResultID, 1)
        ReplicatedStorage.Remote.Loot:FireClient(player, { Items = { [config.ResultID] = 1 } })
    else
        self.ItemModule.AddItem(tarData.Item, itemId, 1)
        ReplicatedStorage.Remote.Loot:FireClient(player, { Items = { [itemId] = 1 } })
    end

    self.SetPlayerData(player, {'Cash', 'Item'})
end

return self
