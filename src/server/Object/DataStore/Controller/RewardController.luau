local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function self.Init(context)
    self.GetData = context.GetData
    self.SetPlayerData = context.SetPlayerData
    self.ItemModule = context.ItemModule
    self.TowerModule = context.TowerModule
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

return self
