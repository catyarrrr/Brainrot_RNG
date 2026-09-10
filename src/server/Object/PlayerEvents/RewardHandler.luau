local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestData = require(ReplicatedStorage.Datas.QuestData :: ModuleScript)
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)
local SummonData = require(ReplicatedStorage.Datas.SummonData :: ModuleScript)

local self = {}

function self.ClaimVIPDaily(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local now = workspace:GetServerTimeNow()
	if playerData.States.VIPDaily >= now then return end

	shared.DataStore.RewardController.ClaimVIPDaily(player)
end
function self.ClaimFreeReward(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	if playerData.States.GroupReward == true then return end
	shared.DataStore.RewardController.ClaimFreeReward(player)
end
function self.CheckTask(player, line)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local taskName = QuestData[line].DataName
	local taskKey
	for k, v in playerData.Task[taskName] do
		if v == false then taskKey = k; break end
	end

	local chk = false
	local text = ''
	local taskConfig = QuestData[line][taskKey]

	if taskConfig.Type == 2 then
		if playerData.Tower.Collection.Total >= taskConfig.Collect then chk = true end
		text = 'Collect more Brainrot to claim the reward!!!'

	elseif taskConfig.Type == 3 then
		local curLevel = TempData.GetLevelByGrid(playerData.Grid)
		if curLevel >= taskConfig.NeedLevel then chk = true end
		text = 'Upgrade yr base to claim the reward!!!'

	elseif taskConfig.Type == 4 then
		if playerData.Gacha.Luck >= taskConfig.NeedLevel then chk = true end
		text = 'Upgrade yr Luck to claim the reward!!!'

	elseif taskConfig.Type == 5 then
		local curLevel = TempData.GetCashLvlByMultiplier(playerData.Coin.CashMultiplier)
		if curLevel >= taskConfig.NeedLevel then chk = true end
		text = 'Upgrade yr CashMultiplier to claim the reward!!!'

	elseif taskConfig.Type == 6 then
		if playerData.Profile.MaxLevel >= taskConfig.NeedLevel then chk = true end
		text = 'Reach higher Wave to claim the reward!!!'

	elseif taskConfig.Type == 7 then
		if playerData.Profile.StartLevel >= taskConfig.NeedLevel then chk = true end
		text = 'Upgrade yr startingwave to claim the reward!!!'

	end

	if chk == true then
		shared.DataStore.RewardController.ClaimTaskReward(player, taskName, taskKey, taskConfig.Reward, taskConfig.Type)
	else
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, text)
	end
end
function self.ClaimWheelReward(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	shared.DataStore.GachaController.SpinUpdate(player)

	if playerData.Gacha.Spins <= 0 then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Come back later for yr next spin')
		return
	end

	local wheelConfig = TempData.GetWheelConfig()
	if wheelConfig.Type == 1 then
		local cash = 10 * playerData.Profile.MaxLevel * 8 * wheelConfig.Reward
		shared.DataStore.GachaController.ClaimWheelReward(player, wheelConfig.Type, cash, wheelConfig.Count)
		task.delay(4, function()
			ReplicatedStorage.Remote.Loot:FireClient(player, { Cash = cash })
		end)
	elseif wheelConfig.Type == 2 then
		shared.DataStore.GachaController.ClaimWheelReward(player, wheelConfig.Type, wheelConfig.Reward, wheelConfig.Count)
		task.delay(4, function()
			ReplicatedStorage.Remote.Loot:FireClient(player, { Items = {[wheelConfig.Reward] = wheelConfig.Count} })
		end)
	elseif wheelConfig.Type == 3 then
		local item = ItemData.GachaWheelItem()
		shared.DataStore.GachaController.ClaimWheelReward(player, wheelConfig.Type, item, wheelConfig.Count)
		task.delay(4, function()
			ReplicatedStorage.Remote.Loot:FireClient(player, { Items = {[item] = wheelConfig.Count} })
		end)
	elseif wheelConfig.Type == 4 then
		local towerUID = shared.RewardData.GachaBundle(0)
		shared.DataStore.GachaController.ClaimWheelReward(player, wheelConfig.Type, towerUID, wheelConfig.Count)
		task.delay(4, function()
			ReplicatedStorage.Remote.Loot:FireClient(player, { Tower = towerUID })
		end)
	end

	ReplicatedStorage.Remote.PlayerSpin:FireClient(player, wheelConfig)
end
function self.ClaimOfflineReward(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	shared.DataStore.RewardController.ClaimOfflineReward(player)
end
function self.ClaimLoginReward(player, day)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local loginData = playerData.States.LoginReward

	local now = workspace:GetServerTimeNow()
	local today = math.floor(now / 86400)
	if loginData.LastLoginDay == today then ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Come back next day !!!'); return end
	if loginData.Day > shared.Config.LOGIN_MAXDAY then return end
	if day ~= loginData.Day then return end

	shared.DataStore.RewardController.ClaimLoginReward(player, day)
end
function self.ClaimWeeklyDaily(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end

	local weekly = playerData.States.WeeklyDaily
	if weekly == nil then return end

	local now = workspace:GetServerTimeNow()
	local today = math.floor(now / 86400)
	if weekly.LastLoginDay == today then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Come back next day !!!')
		return
	end

	shared.DataStore.RewardController.ClaimWeeklyDaily(player)
end
function self.OpenWheelFrame(player)
	shared.DataStore.GachaController.CheckWheel(player)
end

return self
