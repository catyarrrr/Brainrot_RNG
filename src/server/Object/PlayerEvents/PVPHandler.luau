local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local MAX_DEPLOY = 4

local self = {}

--	塔是否仍存在于当前静态数据（存档可能残留已下架的塔）
local function TowerExists(towerUID)
	local dict = TowerData.Datas and TowerData.Datas.TowerDict
	return type(dict) == 'table' and dict[towerUID] ~= nil
end

local function GetTowerDPS(towerUID, traitId)
	if not TowerExists(towerUID) then return 0 end

	local stats = TowerData.GetCloneData(towerUID)
	if stats == nil then return 0 end

	shared.CalculateData.ApplyModifiers(stats, traitId)
	return shared.CalculateData.GetDPS(stats.Damage, stats.ActionDelay)
end

--	拒绝开战：提示原因并回传一个空结果，让客户端立刻解除请求锁（否则会卡到超时）
local function RejectFight(player, message)
	ReplicatedStorage.Remote.ServerWarn:FireClient(player, message)
	ReplicatedStorage.Remote.PVP.Result:FireClient(player, { Error = message })
end

--	将客户端上报的出战顺序数组（{ uid, uid, ... }）从服务端数据重新构建为战斗数据
local function BuildAllyData(playerData, deployed)
	local allyData = {}
	local count = 0

	for _, uid in ipairs(deployed) do
		if count >= MAX_DEPLOY then break end

		local towerData = playerData.Tower.Inv[uid]
		if towerData == nil then continue end

		local towerUID = towerData.TowerUID
		table.insert(allyData, {
			TowerUID = towerUID,
			DPS = GetTowerDPS(towerUID, towerData.Trait),
		})
		count += 1
	end

	return allyData
end

--	客户端点击战斗按钮后上报出战顺序与对手 token，服务端校验、生成种子并运算，回传结果供客户端复现
function self.StartFight(player, deployed, opponentToken)
    local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end
	if type(deployed) ~= 'table' then return end

	--	挑战次数校验：次数为 0 不能开战（失败不消耗，胜利才消耗）
	if shared.DataStore.RewardController.GetPVPChallenge(player) <= 0 then
		RejectFight(player, 'No PVP attempts left, please wait for recovery')
		return
	end

	--	保存玩家本次的出战顺序
	playerData.States.PVPDeploy = deployed
	shared.DataStore.SetPlayerData(player, 'PVPDeploy')

	local allyData = BuildAllyData(playerData, deployed)
	if #allyData == 0 then
		RejectFight(player, 'Deploy some brainrots first !!!')
		return
	end

	--	取出并校验候选 token（一次性、限时），防止客户端伪造对手
	local opponent = shared.PVPOpponent.Resolve(player, opponentToken)
	if opponent == nil then
		RejectFight(player, 'Opponent expired, please refresh')
		return
	end
	local enemyData = opponent.Enemy
	local difficulty = opponent.Difficulty
	local enemyName = opponent.Name or (opponent.Kind == 'Bot' and 'Bot') or 'Opponent'

	--	生成本局种子，客户端用相同种子复现战斗
	local seed = Random.new():NextInteger(1, 2147483647)
	local result = shared.PVPBattle.Simulate(allyData, enemyData, seed)

	-- 胜利时发放 Crystals 与现金，并消耗一次挑战次数
	local crystalReward = 0
	local cashReward = 0
	if result.Winner == 'L' then
		crystalReward = shared.Config.PVP_REWARD[difficulty] or 0

		--	发奖涉及读档 / 跨服中转等可能失败的调用，用 pcall 包住；
		--	否则中途报错会导致 Result 不回包，客户端卡住且 token 已被消耗（再点报 Opponent expired）
		local granted, grantErr = pcall(function()
			if crystalReward > 0 then
				shared.DataStore.RewardController.GivePVPReward(player, crystalReward)

				local pathId = shared.DataStore.GetPlayerCurPath(player)
				if pathId then shared.Area.UpdateEvent:Fire(player, {Cardrottini = true}, pathId) end
			end
			shared.DataStore.RewardController.ConsumePVPChallenge(player)

			if opponent.UserId ~= nil then
				--	真玩家：偷取对方 10% 现金
				cashReward = shared.DataStore.StealCash(player, opponent.UserId, shared.Config.PVPSTEAL_RATE) or 0
			else
				--	机器人：按难度补发对应分钟数的离线奖励现金
				local maxLevel = (playerData.Profile and playerData.Profile.MaxLevel) or 1
				cashReward = shared.PVPOpponent.GetBotCashReward(maxLevel, difficulty)
				shared.DataStore.CreditSteal(player, cashReward)
			end
		end)
		if not granted then
			warn('[PVP] grant reward failed:', grantErr)
		end

		task.spawn(function() shared.PVPRankBoard.RefreshRank(player) end)
	end

	result.Ally = allyData
	result.Enemy = enemyData
	result.Seed = seed
	result.Difficulty = difficulty
	result.EnemyName = enemyName
	result.Crystal = crystalReward
	result.Cash = cashReward

	ReplicatedStorage.Remote.PVP.Result:FireClient(player, result)
end

return self
