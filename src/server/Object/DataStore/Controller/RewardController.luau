local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PVPData = require(ReplicatedStorage.Datas.PVPData :: ModuleScript)
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)

local self = {}
local LoginRewardConfig = {
    {Cash = 10680},
    {Tower = 1070401},
    {Items = {[101] = 18}},
    {Items = {[111] = 16, [112] = 16}},
    {Cash = 15680000},
    {Items = {[113] = 18, [114] = 18}},
    {Tower = 1220601},
}

--	PVP 商店每日刷新：返回当天（UTC 天数），跨天则清空购买次数
local function GetPVPShopDay()
    return math.floor(workspace:GetServerTimeNow() / 86400)
end
local function RefreshPVPShopData(tarData)
    tarData.PVP = tarData.PVP or {}
    local shop = tarData.PVP.Shop
    if shop == nil then
        shop = { Day = GetPVPShopDay(), Count = {} }
        tarData.PVP.Shop = shop
    elseif shop.Day ~= GetPVPShopDay() then
        shop.Day = GetPVPShopDay()
        shop.Count = {}
    end
    return shop
end

--	PVP 挑战次数：每 PVPCHALLENGE_RECOVER 秒恢复 1 次，最多 PVPCHALLENGE_MAXCOUNT
local function RecoverPVPChallengeData(tarData)
    tarData.PVP = tarData.PVP or {}
    tarData.PVP.Challenge = tarData.PVP.Challenge or { Count = shared.Config.PVPCHALLENGE_MAXCOUNT, RecoverTime = 0 }
    local challenge = tarData.PVP.Challenge
    local now = workspace:GetServerTimeNow()

    if challenge.Count < shared.Config.PVPCHALLENGE_MAXCOUNT and now >= challenge.RecoverTime then
        local recoverCount = math.floor((now - challenge.RecoverTime) / shared.Config.PVPCHALLENGE_RECOVER + 1)
        challenge.Count = math.min(shared.Config.PVPCHALLENGE_MAXCOUNT, challenge.Count + recoverCount)

        if challenge.Count >= shared.Config.PVPCHALLENGE_MAXCOUNT then
            challenge.RecoverTime = 0
        else
            challenge.RecoverTime += recoverCount * shared.Config.PVPCHALLENGE_RECOVER
        end
    end

    return challenge
end

function self.Init(context)
    self.GetData = context.GetData
    self.SetPlayerData = context.SetPlayerData
    self.ItemModule = context.ItemModule
    self.TowerModule = context.TowerModule
    self.TotemModule = context.TotemModule
end

function self.GetItem(player, itemId, amount)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.ItemModule.AddItem(tarData.Item, itemId, amount)

    self.SetPlayerData(player)
end

function self.BuyFragments(player, itemId)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.ItemModule.AddItem(tarData.Item, itemId, 10)

    self.SetPlayerData(player, 'Item')
    ReplicatedStorage.Remote.Loot:FireClient(player, { Items = { [itemId] = 10 } })
end
function self.GetEventFragments(player, itemId, amount)
    local tarData = self.GetData(player)
    if not tarData then return end

    amount = amount or 1
    self.ItemModule.AddItem(tarData.Item, itemId, amount)

    self.SetPlayerData(player, 'Item')
    ReplicatedStorage.Remote.Loot:FireClient(player, { Items = { [itemId] = amount } })
end

function self.EnemyDrop(player, itemIds)
    local tarData = self.GetData(player)
    if not tarData then return end

    if tarData.VIP.Dropx2 == true then
        for id, amount in itemIds do
            itemIds[id] = amount * 2
        end
    end
    for id, amount in itemIds do
        self.ItemModule.AddItem(tarData.Item, id, amount)
    end

   self.SetPlayerData(player)
   ReplicatedStorage.Remote.Game.GameLoot:FireClient(player, {Items = itemIds})
end

function self.BossDrop(player, itemIds)
    local tarData = self.GetData(player)
    if not tarData then return end
    
    tarData.Profile.BossKills += 1

    for id, amount in itemIds do
        self.ItemModule.AddItem(tarData.Item, id, amount)
    end

   self.SetPlayerData(player, 'Profile')
   ReplicatedStorage.Remote.Game.GameLoot:FireClient(player, {Items = itemIds})
end

function self.ClaimVIPDaily(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local now = workspace:GetServerTimeNow()
    tarData.States.VIPDaily = now + 86400

    local items = {[101] = 25, [105] = 3, [106] = 1, [107] = 1, [108] = 1}
    for id, amount in items do
        self.ItemModule.AddItem(tarData.Item, id, amount)
    end

    local towerUID = shared.RewardData.GachaBundle(10)
    local newUID = HttpService:GenerateGUID(false)
    self.TowerModule.AddTower(tarData.Tower, towerUID, newUID)

    shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)

    ReplicatedStorage.Remote.Tower.Summon:FireClient(player, towerUID)

    self.SetPlayerData(player, 'VIPDaily')
end

function self.ClaimFreeReward(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local newUID = HttpService:GenerateGUID(false)
    local towerUID = 1120201
    self.TowerModule.AddTower(tarData.Tower, towerUID, newUID)
    tarData.Coin.Cash += 10000
    tarData.States.GroupReward = true

    shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)

    self.SetPlayerData(player, {'Group', 'Cash'})
end

function self.ClaimEventCash(player, cashType)
    local tarData = self.GetData(player)
    if not tarData then return end

    local maxLevel = tarData.Profile.MaxLevel
    local cash = maxLevel * maxLevel * 10 * 3 * shared.Config['EVENT_CASH' .. tostring(cashType)]
    tarData.Coin.Cash += cash

    self.SetPlayerData(player, 'Cash')
    ReplicatedStorage.Remote.Loot:FireClient(player, {Cash = cash})
end

function self.ClaimTaskReward(player, taskName, key, reward, taskType)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Task[taskName][key] = true
	if taskType == 2 then
		tarData.Coin.Cash += reward

		ReplicatedStorage.Remote.Loot:FireClient(player, { Cash = reward })
	elseif taskType == 3 or taskType == 4 or taskType == 5 or taskType == 6 or taskType == 7 then
		local towerUID = shared.RewardData.GachaBundle(reward)
		local newUID = HttpService:GenerateGUID(false)
		self.TowerModule.AddTower(tarData.Tower, towerUID, newUID)

		ReplicatedStorage.Remote.Loot:FireClient(player, { Tower = towerUID })
		shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)
        ReplicatedStorage.Remote.Tower.Summon:FireClient(player, towerUID)
	end

    self.SetPlayerData(player, 'Task')
end

function self.ClaimOfflineReward(player, isBuy)
    local tarData = self.GetData(player)
    if not tarData then return end

    local reward = tarData.States.OfflineReward

    if isBuy == true then
        tarData.Coin.Cash += reward.Cash * 3
        for itemId, amount in reward.Items do
            self.ItemModule.AddItem(tarData.Item, itemId, amount * 3)
        end
        local buyReward = table.clone(reward)
        buyReward.Cash *= 3
        for itemId, amount in buyReward.Items do
            buyReward.Items[itemId] *= 3
        end
        ReplicatedStorage.Remote.PlayerClaimOfflineReward:FireClient(player, buyReward)
    else
        tarData.Coin.Cash += reward.Cash
        for itemId, amount in reward.Items do
            self.ItemModule.AddItem(tarData.Item, itemId, amount)
        end
        ReplicatedStorage.Remote.PlayerClaimOfflineReward:FireClient(player, reward)
    end

    self.SetPlayerData(player, 'OfflineReward')
end

function self.ClaimLoginReward(player, day)
    local tarData = self.GetData(player)
    if not tarData then return end

    local loginReward = tarData.States.LoginReward
    local now = workspace:GetServerTimeNow()

    -- if loginReward.Day > shared.Config.LOGIN_MAXDAY then
    --     return
    -- end

    if loginReward.LastLoginDay == math.floor(now / 86400) then return end

    -- if loginReward.NextClaim > now then return end

    local dayConfig = LoginRewardConfig[day]
    if not dayConfig then return end

    if dayConfig.Cash then tarData.Coin.Cash += dayConfig.Cash end

    if dayConfig.Items then
        for itemId, amount in dayConfig.Items do
            self.ItemModule.AddItem(tarData.Item, itemId, amount)
        end
    end

    if dayConfig.Tower then
        local newUID = HttpService:GenerateGUID(false)
        self.TowerModule.AddTower(tarData.Tower, dayConfig.Tower, newUID)
        shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)
        ReplicatedStorage.Remote.Tower.Summon:FireClient(player, dayConfig.Tower)
    end

    loginReward.Day += 1
    loginReward.LastLoginDay = math.floor(now / 86400)

    self.SetPlayerData(player, 'LoginReward')
    ReplicatedStorage.Remote.PlayerClaimLoginReward:FireClient(player, dayConfig)

end

function self.ClaimWeeklyDaily(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local weekly = tarData.States.WeeklyDaily
    if weekly == nil then return end

    local reward = shared.RewardData.GetWeeklyDaily(weekly.Day)
    if reward == nil then return end

    if reward.Cash then
        tarData.Coin.Cash += reward.Cash
    end
    if reward.Gems then
        tarData.Coin.Gems += reward.Gems
    end
    if reward.Item then
        self.ItemModule.AddItem(tarData.Item, reward.Item, reward.Amount)
    end

    local lootData = {}
    if reward.Cash then lootData.Cash = reward.Cash end
    if reward.Gems then lootData.Gems = reward.Gems end
    if reward.Item then lootData.Items = { [reward.Item] = reward.Amount } end

    weekly.LastLoginDay = math.floor(workspace:GetServerTimeNow() / 86400)
    weekly.Day = weekly.Day % shared.Config.WEEKLYLOGIN_MAXDAY + 1

    self.SetPlayerData(player, {'WeeklyDaily', 'Cash'})
    ReplicatedStorage.Remote.Loot:FireClient(player, lootData)
end

--	PVP 胜利奖励：发放 Crystals，返回玩家当前的 Crystals 总数
--	Coin.Crystals 为可花费余额；Profile.CrystalsTotal 为累计获得总量（只增不减，用于 PVP 匹配）
function self.GivePVPReward(player, amount)
    local tarData = self.GetData(player)
    if not tarData then return nil end
    if type(amount) ~= 'number' or amount <= 0 then return tarData.Coin.Crystals end

    tarData.Coin.Crystals = (tarData.Coin.Crystals or 0) + amount
    tarData.Profile.CrystalsTotal = (tarData.Profile.CrystalsTotal or 0) + amount

    self.SetPlayerData(player, {'Crystals', 'Profile'})
    return tarData.Coin.Crystals
end

--	玩家进入时刷新 PVP 商店的每日购买次数
function self.RefreshPVPShop(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    RefreshPVPShopData(tarData)
    self.SetPlayerData(player, 'PVPShop')
end

--	玩家进入时刷新 PVP 挑战次数
function self.RefreshPVPChallenge(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    RecoverPVPChallengeData(tarData)
end

--	获取当前可用挑战次数（先结算恢复）
function self.GetPVPChallenge(player)
    local tarData = self.GetData(player)
    if not tarData then return 0 end

    return RecoverPVPChallengeData(tarData).Count
end

--	消耗一次挑战次数（战斗胜利时调用）
function self.ConsumePVPChallenge(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local challenge = RecoverPVPChallengeData(tarData)
    if challenge.Count <= 0 then return end

    challenge.Count -= 1
    if challenge.RecoverTime == 0 and challenge.Count < shared.Config.PVPCHALLENGE_MAXCOUNT then
        challenge.RecoverTime = workspace:GetServerTimeNow() + shared.Config.PVPCHALLENGE_RECOVER
    end

    self.SetPlayerData(player, 'PVPChallenge')
end

--	校验一次 PVP 购买：返回 (是否可购买, 本次消耗, 失败原因)
function self.CheckPVPBuy(player, buttonName)
    local tarData = self.GetData(player)
    if not tarData then return false, nil, 'noData' end

    local config = PVPData.GetPurchaseConfig(buttonName)
    if config == nil then return false, nil, 'noConfig' end

    local shop = RefreshPVPShopData(tarData)
    local count = shop.Count[config.Key] or 0

    local cost = PVPData.GetPurchaseValue(config.Key, count + 1)
    if cost == nil then return false, nil, 'noValue' end
    if (tarData.Coin.Crystals or 0) < cost then return false, cost, 'noCrystal' end

    return true, cost
end

--	执行一次 PVP 购买：扣除 Crystals、累加购买次数、发放奖励并回包客户端
function self.BuyPVPItem(player, buttonName)
    local tarData = self.GetData(player)
    if not tarData then return end

    local config = PVPData.GetPurchaseConfig(buttonName)
    if config == nil then return end

    local shop = RefreshPVPShopData(tarData)
    local count = shop.Count[config.Key] or 0

    local cost = PVPData.GetPurchaseValue(config.Key, count + 1)
    if cost == nil then return end
    if (tarData.Coin.Crystals or 0) < cost then return end

    tarData.Coin.Crystals -= cost
    shop.Count[config.Key] = count + 1

    if config.Type == 'Item' and config.ItemId ~= nil then
        self.ItemModule.AddItem(tarData.Item, config.ItemId, 1)
        ReplicatedStorage.Remote.Loot:FireClient(player, { Items = { [config.ItemId] = 1 } })
    elseif config.Type == 'Totem' then
        local totemUID = TotemData.Gacha()
        if totemUID ~= nil then
            --	与祈祷一致：只下发掉落，玩家 Claim 时服务端才入包
            ReplicatedStorage.Remote.Tower.PrayTotem:FireClient(player, totemUID)
        end
    end

    self.SetPlayerData(player, {'Crystals', 'Item', 'Totem'})

    ReplicatedStorage.Remote.PVP.BuyResult:FireClient(player, {
        Button = buttonName,
        Key = config.Key,
        Count = shop.Count[config.Key],
        NextCost = PVPData.GetPurchaseValue(config.Key, shop.Count[config.Key] + 1),
    })
end

return self
