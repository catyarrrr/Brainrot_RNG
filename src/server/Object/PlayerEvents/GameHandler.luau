local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = ReplicatedStorage
local LevelData = require(ReplicatedStorage.Datas.LevelData :: ModuleScript)

local GAMESPEEDPASS_ID = 1
local self = {}

function self.ModifyGameSpeed(player, speed)
	print(speed)
	if speed == 3 and MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMESPEEDPASS_ID) == false then
		MarketplaceService:PromptGamePassPurchase(player, GAMESPEEDPASS_ID)
		return
	end

	local joinData = shared.MapHandler.JoinData

	if player.UserId ~= joinData.Starter then ReplicatedStorage.Remote.GameSpeedModify:FireClient(player); return end

	local game = shared.Game.Get(player)
	if not game then return end

	if speed == 1 then
		game.Task:SetSpeed(48)
	elseif speed == 2 then
		game.Task:SetSpeed(96)
	elseif speed == 3 then
		game.Task:SetSpeed(144)
	end

	rs.Remote.GameSpeedModify:FireAllClients(game.Task.StartTime, game.Task.TickPerSecond, speed)
end
function self.GameStart(player)
	local game = shared.Game.Get(player)
	if game.Started == true then return end
	local maxLevel = LevelData.MAXLEVEL

	local playerData = shared.DataStore.GetData(player)
	if not playerData then return end
	shared.DataStore.PlayerConfirmGuide(player, 1)
	game:Start(maxLevel, nil, playerData.Profile.StartLevel)
end
function self.RushStart(player, multi)
	local game = shared.Game.Get(player)
	if game.Started == true then rs.Remote.ServerWarn:FireClient(player, 'Finish yr current game to start the Boss Challenge'); return end
	local chk, needed
	chk, needed = shared.DataStore.GachaController.StartChallenge(player, multi)
	if chk == false then
		rs.Remote.ServerWarn:FireClient(player, 'Please wait for next attempt')
		rs.Remote.Game.RushStart:FireClient(player, needed)
		return
	end

	local maxLevel = LevelData.MAXRUSH

	shared.DataStore.PlayerConfirmGuide(player, 1)
	game:Start(maxLevel, multi)
end
function self.GameStop(player)
	local game = shared.Game.Get(player)
	game.Auto = false
	game:GameOver()

	rs.Remote.Game.GameAuto:FireClient(player, game.Auto)
end
function self.GameAuto(player)
	local game = shared.Game.Get(player)
	game.Auto = not game.Auto
	if game.Started == false then
		local playerData = shared.DataStore.GetData(player)
		if playerData then game:Start(LevelData.MAXLEVEL, nil, playerData.Profile.StartLevel) end
	end

	rs.Remote.Game.GameAuto:FireClient(player, game.Auto)
end
function self.FuseFragment(player, itemId)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end
	if itemId == nil then return end

	local config = shared.CalculateData.GetFragmentConfig(itemId)
	if config == nil then return end

	local itemChk = shared.DataStore.ItemModule.Chk(playerData.Item, itemId, config.NeedCount)
	if itemChk == false then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Not enough Fragments')
		return
	end

	local cashChk = shared.DataStore.CoinController.CheckCash(player, config.NeedCash)
	if cashChk == false then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Not enough Cash')
		return
	end

	shared.DataStore.CoinController.FuseFragment(player, itemId)
end
function self.IfGameStarted(player)
	local game = shared.Game.Get(player)
	if game == nil then warn('game not found for player:' ,player); return end
	if game.Started == true then
		return true
	end

	return false
end

return self
