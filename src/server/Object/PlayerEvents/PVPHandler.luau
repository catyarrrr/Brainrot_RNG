local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local MAX_DEPLOY = 4

local self = {}

local function GetTowerDPS(towerUID, traitId)
	local stats = TowerData.GetCloneData(towerUID)
	if stats == nil then return 0 end

	shared.CalculateData.ApplyModifiers(stats, traitId)
	return shared.CalculateData.GetDPS(stats.Damage, stats.ActionDelay)
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
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'No PVP attempts left, please wait for recovery')
		return
	end

	--	保存玩家本次的出战顺序
	playerData.States.PVPDeploy = deployed
	shared.DataStore.SetPlayerData(player, 'PVPDeploy')

	local allyData = BuildAllyData(playerData, deployed)
	if #allyData == 0 then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Deploy some brainrots first !!!')
		return
	end

	--	取出并校验候选 token（一次性、限时），防止客户端伪造对手
	local opponent = shared.PVPOpponent.Resolve(player, opponentToken)
	if opponent == nil then
		ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Opponent expired, please refresh')
		return
	end
	local enemyData = opponent.Enemy
	local difficulty = opponent.Difficulty

	--	生成本局种子，客户端用相同种子复现战斗
	local seed = Random.new():NextInteger(1, 2147483647)
	local result = shared.PVPBattle.Simulate(allyData, enemyData, seed)

	--	胜利时发放 Crystals 与现金，并消耗一次挑战次数
	local crystalReward = 0
	local cashReward = 0
	if result.Winner == 'L' then
		crystalReward = shared.Config.PVP_REWARD[difficulty] or 0
		if crystalReward > 0 then
			shared.DataStore.RewardController.GivePVPReward(player, crystalReward)
		end
		shared.DataStore.RewardController.ConsumePVPChallenge(player)

		if opponent.UserId ~= nil then
			--	真玩家：偷取对方 10% 现金
			cashReward = shared.DataStore.StealCash(player, opponent.UserId, shared.Config.PVPSTEAL_RATE)
		else
			--	机器人：按难度补发对应分钟数的离线奖励现金
			local maxLevel = (playerData.Profile and playerData.Profile.MaxLevel) or 1
			cashReward = shared.PVPOpponent.GetBotCashReward(maxLevel, difficulty)
			shared.DataStore.CreditSteal(player, cashReward)
		end
	end

	result.Ally = allyData
	result.Enemy = enemyData
	result.Seed = seed
	result.Difficulty = difficulty
	result.Crystal = crystalReward
	result.Cash = cashReward

	ReplicatedStorage.Remote.PVP.Result:FireClient(player, result)
end

return self
