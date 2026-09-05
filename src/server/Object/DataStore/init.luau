local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService('DataStoreService')
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local LevelData = require(ReplicatedStorage.Datas.LevelData :: ModuleScript)
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)
local PlayerData = DataStoreService:GetDataStore('PlayerData')

local self : any = {}

local loaded = {}
local collections = {}
local dirty = {}
local SAVE_INTERVAL, SAVE_MAX_RETRY, SAVE_RETRY_DELAY = 60, 5, 5
local LEADERBOARD_UPDATE_INTERVAL = 60
local UpdateKillLeaderstats, UpdateCashLeaderstats, UpdateBossKillLeaderstats, UpdateRobuxLeaderstats, InitTowerCollection, AsyncEvent, InitPlayerPath, ClearPlayerPath, Reconcile, SetOfflineReward, AsyncServerEvent, UpdatePlayerPasses, SavePlayer, StartAutoSave = nil

function self.init()
    self.PlayerDataLoadedEvent = shared.Event.new()
    self.PlayerExitEvent = shared.Event.new()
	self.TowerModule = require(script.Data.TowerData)
	self.GridModule = require(script.Data.GridData)
    self.ItemModule = require(script.Data.ItemData)
    self.TotemModule = require(script.Data.TotemData)

    for _, module in pairs(script.Controller:GetChildren()) do
        if module:IsA('ModuleScript') then
            if self[module.Name] then
                warn('duplicate:', module.Name)
            end
            self[module.Name] = require(module)
        end
    end

    self.Module = {
        TowerModule = self.TowerModule,
        GridModule = self.GridModule,
        ItemModule = self.ItemModule,
        TotemModule = self.TotemModule,
        SetPlayerData = self.SetPlayerData,
        GetData = self.GetData,
    }

    for _, module in pairs(script.Controller:GetChildren()) do
        if module:IsA('ModuleScript') then
            self[module.Name].Init(self.Module)
        end
    end

    game:BindToClose(function()
        local players = {}
        for player in collections do
            table.insert(players, player)
        end
        for _, player in ipairs(players) do
            SavePlayer(player)
        end
        local deadline = os.clock() + 30
        while next(loaded) ~= nil and os.clock() < deadline do
            task.wait(0)
        end
    end)
end
function self.start()
    shared.Game.GameFarmEvent:Connect(function(_, player, reward)
        self.CoinController.Farm(player, reward)
    end)
    shared.Game.GameOverEvent:Connect(function(self, player, pathId, round, rush)
        if rush then
            self.PlayerUpdateMaxChallenge(player, round)
        else
            self.PlayerUpdateMaxLevel(player, round)
        end
    end, self)
    shared.Game.GameWinEvent:Connect(function(self, player, pathId, round, rush)
        if rush then
            self.PlayerUpdateMaxChallenge(player, round)
        else
            self.PlayerUpdateMaxLevel(player, round)
        end
    end, self)
    shared.ServerEvent.EventChangeEvent:Connect(AsyncServerEvent)
    Players.PlayerRemoving:Connect(self.PlayerExit)
    for i, player in Players:GetChildren() do
        self.PlayerEnter(player)
    end
	Players.PlayerAdded:Connect(self.PlayerEnter)
    UpdateKillLeaderstats(); UpdateCashLeaderstats(); UpdateBossKillLeaderstats(); UpdateRobuxLeaderstats()
    StartAutoSave()
end

--- 	玩家进入
function self.PlayerEnter(player)
    if loaded[player] == true then return end

    local result, value = pcall(PlayerData.GetAsync, PlayerData, player.UserId)
	if result == false then player:Kick('datastore fail to load'); return end 

	local foundData = value or {}
	-- print('data loaded:', foundData)
	local defaultData = Reconcile(foundData, shared.PlayerDatas)
    for _, totem in pairs(defaultData.Totem.Inv) do
        if totem.Point == nil then
            totem.Point = 1
        end
    end

	loaded[player] = true
	collections[player] = defaultData
    
    ServerEnterInit(player, defaultData)
    self.GridModule.GridInit(defaultData.Grid)
    InitPlayerPath(player, defaultData)
    InitTowerCollection(player, defaultData)
    AsyncEvent(defaultData)

    -- print('data initiated:', defaultData)

    self.PlayerDataLoadedEvent:Fire(player, defaultData.Tower.Inv)
	ReplicatedStorage.Remote.SetPlayerData:FireClient(player, defaultData)
    task.spawn(UpdatePlayerPasses, player)
end
--- 	玩家退出
function self.PlayerExit(player)
	if loaded[player] == nil then warn('player data not loaded'); return end
	
    self.PlayerExitEvent:Fire(player)

	local data = self.GetData(player)
	data.States.LastTime = os.time()
    data.States.IsNew = false
    data.States.PlaceVersion = game.PlaceVersion
    data.States.OfflineReward = {Items = {}, Cash = 0}
	
    SavePlayer(player)

    ClearPlayerPath(player, data)
	
	loaded[player] = nil
	collections[player] = nil
	dirty[player] = nil
end

function SavePlayer(player)
    local data = collections[player]
    if data == nil then
        dirty[player] = nil
        return true
    end

    for attempt = 1, SAVE_MAX_RETRY do
        local success, _ = pcall(PlayerData.SetAsync, PlayerData, player.UserId, data)
        if success then
            dirty[player] = nil
            return true
        end
        if attempt < SAVE_MAX_RETRY then
            task.wait(SAVE_RETRY_DELAY)
        end
    end

    warn('player data save failed after retries:', player)
    return false
end

function StartAutoSave()
    task.spawn(function()
        while true do
            task.wait(SAVE_INTERVAL)
            local players = {}
            for player in dirty do
                table.insert(players, player)
            end
            for _, player in ipairs(players) do
                if collections[player] == nil then
                    dirty[player] = nil
                else
                    SavePlayer(player)
                    task.wait(1)
                end
            end
        end
    end)
end

function self.GetData(player)
    if loaded[player] == nil then warn('data not loaded for player:', player); return nil end

    return collections[player]
end
function self.SetPlayerData(player, tag)
    local tarData = collections[player]
    if tarData == nil then warn('player data not found'); return end
    dirty[player] = true
    if type(tag) == "string" then tag = {tag} end
    ReplicatedStorage.Remote.SetPlayerData:FireClient(player, tarData, tag)
end

---------------- Path相关
function self.GetPlayerCurPath(player)
    local tarData = collections[player]
    if tarData == nil then return nil end

    local curPath = tarData.States.CurPath
    if curPath == nil then warn('curpath fetch error for plr:', player); return nil end

    return curPath
end
function InitPlayerPath(plr, data)
    while not shared.Path.Initiated do
        task.wait()
	end

    for k, v in shared.Path.Paths do
        if v.Owner == nil then
            v.Owner = plr.UserId
            data.States.CurPath = k
            -- print('set', plr, 'path to :', k)
            break
        end
    end

    shared.Area.EnterEvent:Fire(data.States.CurPath, data, plr)
end
function ClearPlayerPath(plr, data)
    while not shared.Path.Initiated do
        task.wait()
	end

    shared.Path.Paths[self.GetPlayerCurPath(plr)].Owner = nil
    shared.Area.ExitEvent:Fire(data.States.CurPath)
end

function self.PlayerConfirmGuide(player, step)
    local tarData = collections[player]
    if tarData == nil then warn('player data not found'); return end

    if tarData.Guide[step] == false then
        tarData.Guide[step] = true
    end

    self.SetPlayerData(player, 'Guide')
end
function AsyncServerEvent()
    for plr, data in collections do
        AsyncEvent(data)
        self.SetPlayerData(plr, 'Event')
    end
end

---------------- Profile相关
function self.PlayerUpdateMaxLevel(player, maxLevel)
    local tarData = collections[player]
    if tarData == nil then warn('player data not found'); return end

    if maxLevel > tarData.Profile.MaxLevel then
        tarData.Profile.MaxLevel = maxLevel
    end

    self.SetPlayerData(player)
end
function self.PlayerUpdateMaxChallenge(player, maxChallenge)
    local tarData = collections[player]
    if tarData == nil then warn('player data not found'); return end

    if maxChallenge > tarData.Profile.MaxChallenge then
        tarData.Profile.MaxChallenge = maxChallenge
    end

    self.SetPlayerData(player)
end

--- 	记录Robux花费
function self.AddSpend(player, robux)
    local tarData = collections[player]
    if tarData == nil then warn('player data not found'); return end
    if type(robux) ~= "number" or robux <= 0 then return end

    tarData.Profile.Spend += robux
    self.SetPlayerData(player, 'Profile')
end

function UpdateKillLeaderstats()
    local TopKillLeaderstats = DataStoreService:GetOrderedDataStore('TopKill' .. shared.Tool.GetWeekId())
    task.spawn(function()
        while true do
            for plr, data in collections do
                TopKillLeaderstats:SetAsync('Kill'..plr.UserId, math.ceil(data.Profile.Kills))
                task.wait(.1)
            end
            task.wait(LEADERBOARD_UPDATE_INTERVAL)
        end
    end)
end
function UpdateCashLeaderstats()
    local TopKillLeaderstats = DataStoreService:GetOrderedDataStore('TopCash' .. shared.Tool.GetWeekId())
    task.spawn(function()
        while true do
            for plr, data in collections do
                if plr.UserId == 1694842986 or plr.UserId == 3811927185 then continue end
                TopKillLeaderstats:SetAsync('Cash'..plr.UserId, math.ceil(data.Coin.Cash))
                task.wait(.1)
            end
            task.wait(LEADERBOARD_UPDATE_INTERVAL)
        end
    end)
end
function UpdateBossKillLeaderstats()
    local TopKillLeaderstats = DataStoreService:GetOrderedDataStore('TopBossKill' .. shared.Tool.GetWeekId())
    task.spawn(function()
        while true do
            for plr, data in collections do
                TopKillLeaderstats:SetAsync('BossKill'..plr.UserId, math.ceil(data.Profile.BossKills))
                task.wait(.1)
            end
            task.wait(LEADERBOARD_UPDATE_INTERVAL)
        end
    end)
end
function UpdateRobuxLeaderstats()
    local TopRobuxLeaderstats = DataStoreService:GetOrderedDataStore('TopSpend')
    task.spawn(function()
        while true do
            for plr, data in collections do
                TopRobuxLeaderstats:SetAsync('Spend'..plr.UserId, math.ceil(data.Profile.Spend))
                task.wait(.1)
            end
            task.wait(LEADERBOARD_UPDATE_INTERVAL)
        end
    end)
end

function Reconcile(data, template)
    for k, v in pairs(template) do
        if type(v) == "table" then
            -- 如果默认数据里这是一个表，但玩家数据里没有或者类型不对，就初始化为空表
            if type(data[k]) ~= "table" then
                data[k] = {}
            end
            -- 递归进入内层表进行补全
            Reconcile(data[k], v)
        else
            -- 如果是普通值且玩家数据里没有这个键，则写入默认值
            if data[k] == nil then
                data[k] = v
            end
        end
    end
    return data
end
function ServerEnterInit(player, data)
    dirty[player] = true

    self.TowerController.RepairCloneEvolve(player)

    local lastTime = data.States.LastTime
    local now = os.time()

    local lastDate = os.date('*t', lastTime)
    local nowDate = os.date('*t', now)
    if lastDate.yday ~= nowDate.yday then
        data.Gacha.Spins += 1
    end

    if data.States.LastTime ~= nil then SetOfflineReward(data) end

	-- data.States.LastTime = os.time()
    data.Gacha.LastSpin = workspace:GetServerTimeNow()
    self.GachaController.SpinUpdate(player)
    
    --boss挑战数据初始化
    self.GachaController.ChallengeUpdate(player)
    
    self.TotemController.CheckSlot2Unlock(player)
end
function SetOfflineReward(data)
    local now = os.time()
    local totalMin = math.ceil((now - data.States.LastTime) / 60)
    totalMin = math.min(shared.Config.EVENT_MAXMIN, totalMin)

    local round = data.Profile.MaxLevel
    local levelData = LevelData.GetData(round)
    if levelData == nil then warn('levelData not found for maxlevel:', round); return end

	local baseReward = 10 * round * 8 * totalMin
    local cash = math.ceil(baseReward)
    data.States.OfflineReward.Cash = cash

    if totalMin >= 10 then
        local itemGachaKey = ItemData.GetGachaKeyByRound(round)
        local time = math.floor(totalMin / 10)
        for i=1, time do
            local itemId = ItemData.GachaItem(itemGachaKey)

            if data.States.OfflineReward.Items[itemId] then
                data.States.OfflineReward.Items[itemId] += 1
            else
                data.States.OfflineReward.Items[itemId] = 1
            end
            
        end
    end

    data.States.OfflineReward.TotalMin = totalMin
end
function InitTowerCollection(player, data)
    if data.Tower.Collection.Initiated then return end

    local collection = { Total = 0, Initiated = true }
    local inv = data.Tower.Inv

    for _, towerData in pairs(inv) do
        
        local towerUID = towerData.TowerUID

        -- 去掉最后两位
        local collectionId = math.floor(towerUID / 100) * 100

        -- 转string作为key
        collectionId = tostring(collectionId)

        if collection[collectionId] == nil then
            collection[collectionId] = true
            collection.Total += 1
        end
    end

    data.Tower.Collection = collection
end
function UpdatePlayerPasses(player)
    local tarData = self.GetData(player)
    if tarData == nil then return end

    local passMap = {
        [shared.ProductDatas.PASSID_VIP] = { vip = 'VIP', handler = function() shared.DataStore.CoinController.BuyVIP(player) end },
        [shared.ProductDatas.PASSID_2XCash] = { vip = 'DoubleCash', handler = function() shared.DataStore.CoinController.BuyDoubleCash(player) end },
        [shared.ProductDatas.PASSID_2XLuck] = { vip = 'DoubleLuck', handler = function() shared.DataStore.GachaController.BuyDoubleLuck(player) end },
        [shared.ProductDatas.PASSID_3XLuck] = { vip = 'TripleLuck', handler = function() shared.DataStore.GachaController.BuyTripleLuck(player) end },
        [shared.ProductDatas.PASSID_StarterPack] = { vip = 'StarterPack', handler = function() shared.DataStore.TowerController.BuyStarterPack(player) end },
        [shared.ProductDatas.PASSID_2XDROP] = { vip = 'Dropx2', handler = function() shared.DataStore.GachaController.BuyPass(player, 'Dropx2') end },
        [shared.ProductDatas.PASSID_2XMUTATION] = { vip = 'Mutationx2', handler = function() shared.DataStore.GachaController.BuyPass(player, 'Mutationx2') end },
        [shared.ProductDatas.PASSID_FASTROLL] = { vip = 'FastRoll', handler = function() shared.DataStore.GachaController.BuyPass(player, 'FastRoll') end },
        [shared.ProductDatas.PASSID_AUTOMERGE] = { vip = 'AutoMerge', handler = function() shared.DataStore.GachaController.BuyPass(player, 'AutoMerge') end },
        [shared.ProductDatas.PASSID_TOTEMSLOT] = { vip = 'TotemSlot', handler = function() shared.DataStore.TotemController.UnlockTotemSlot(player) end },
    }

    for passId, entry in passMap do
        local success, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
        end)
        if success and owns == true and tarData.VIP[entry.vip] == false then
            local ok, info = pcall(function()
                return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
            end)
            if ok and info and type(info.PriceInRobux) == "number" then
                tarData.Profile.Spend += info.PriceInRobux
            end
            entry.handler()
        end
    end
end
function AsyncEvent(data)
    while not shared.ServerEvent.Initiated do task.wait() end

    local Event = {}
    Event.NextEventTime = shared.ServerEvent.NextEventTime
    Event.NextEvent = shared.ServerEvent.NextEvent
    Event.ServerLuckEndTime = shared.ServerEvent.ServerLuckEndTime
    if shared.ServerEvent.State then
        Event.CurEvent = shared.ServerEvent.State.name
        Event.EventEndTime = shared.ServerEvent.EventEndTime
    end

    data.States.Event = Event
end

return self
