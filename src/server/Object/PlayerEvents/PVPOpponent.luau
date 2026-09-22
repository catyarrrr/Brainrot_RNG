--[[
	PVPOpponent (Server)
	PVP 对手匹配与生成：
		- 以我方累计 Crystals（Profile.CrystalsTotal）为中心，按难度取相近玩家
		- 真玩家：读取其存档中 DPS 最高的 4 个塔（随机序）
		- 读不到数据 / 无候选：回退机器人
			Easy   = 我方上阵平均 DPS * 0.8，上阵 3 个
			Medium = 我方上阵平均 DPS * 0.9，上阵 4 个
			Hard   = 我方上阵平均 DPS * 1.0，上阵 4 个
		- 机器人卡面使用随机塔
		- 通过一次性 token 下发并校验对手，防止客户端伪造
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local MAX_DEPLOY = 4
local CANDIDATE_PER_DIFFICULTY = 2
local DIFFICULTIES = { 'Easy', 'Medium', 'Hard' }

--	难度 -> 机器人 DPS 系数 / 上阵数量
local BOT_MULTIPLIER = { Easy = 0.8, Medium = 0.9, Hard = 1.0 }
local BOT_COUNT = { Easy = 3, Medium = 4, Hard = 4 }

--	难度 -> 相对我方累计 Crystals 的区间（[下限比例, 上限比例]）
local BAND = {
	Easy = { 0.5, 0.9 },
	Medium = { 0.9, 1.2 },
	Hard = { 1.2, 1.8 },
}
local BAND_FLOOR = 50
local TOKEN_TTL = 5 * 60
local CANDIDATE_FETCH = 20

local self : any = {}

--	机器人卡面用的随机塔池（取自全部有效塔）
local BotTowerPool = {}

--	player -> { Tokens = { [token] = { Enemy, Difficulty } }, CreatedAt = clock }
local sessions = {}
local nameCache = {}

local function GetName(userId)
	local cached = nameCache[userId]
	if cached ~= nil then return cached end

	local player = Players:GetPlayerByUserId(userId)
	local name = player and player.Name
	if name == nil then
		local success, fetched = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		name = success and fetched or ('Player' .. tostring(userId))
	end

	nameCache[userId] = name
	return name
end

--	按难度取相对我方 total 的分数区间
local function GetBand(total, difficulty)
	local range = BAND[difficulty] or BAND.Medium
	local lower = math.floor(total * range[1])
	local upper = math.ceil(total * range[2])

	--	区间过窄时（含 0 分）用绝对下限撑开，保证能匹配到人
	if upper - lower < BAND_FLOOR then
		local center = (lower + upper) / 2
		lower = math.max(0, math.floor(center - BAND_FLOOR / 2))
		upper = math.ceil(center + BAND_FLOOR / 2)
	end
	return lower, upper
end

local function RandomBotTowerUID()
	if #BotTowerPool == 0 then return 0 end
	return BotTowerPool[math.random(#BotTowerPool)]
end

--	生成机器人队伍：DPS 统一为 平均 DPS * 系数，卡面用随机塔
local function BuildBotTeam(averageDPS, difficulty)
	local multiplier = BOT_MULTIPLIER[difficulty] or 1
	local count = BOT_COUNT[difficulty] or MAX_DEPLOY
	local dps = math.max(1, math.floor(averageDPS * multiplier))

	local team = {}
	for index = 1, count do
		team[index] = { TowerUID = RandomBotTowerUID(), DPS = dps }
	end
	return team
end

--	我方上阵队伍的平均 DPS（机器人基数）
local function GetDeployedAverageDPS(playerData, deployed)
	local total, count = 0, 0
	for _, uid in ipairs(deployed) do
		if count >= MAX_DEPLOY then break end
		local towerData = playerData.Tower.Inv[uid]
		if towerData == nil then continue end

		total += shared.PVPRankBoard.GetTowerDPS(towerData.TowerUID, towerData.Trait)
		count += 1
	end
	if count == 0 then return 0 end
	return total / count
end

--	机器人获胜奖励现金 = 该难度对应分钟数的离线奖励（10 * 等级 * 8 * 分钟）
function self.GetBotCashReward(maxLevel, difficulty)
	local minutes = (shared.Config.PVP_BOTCASH_MIN or {})[difficulty] or 0
	return math.ceil(10 * maxLevel * 8 * minutes)
end

--	记录对手并签发一次性 token，返回给客户端展示的候选信息
local function IssueToken(player, candidate, enemy)
	local token = HttpService:GenerateGUID(false)
	sessions[player].Tokens[token] = {
		Enemy = enemy,
		Difficulty = candidate.Difficulty,
		UserId = candidate.UserId,
		Name = candidate.Name,
		Kind = candidate.Kind,
	}
	candidate.Id = token
	return candidate
end

--	客户端请求候选：每档取 CANDIDATE_PER_DIFFICULTY 个
function self.RequestOpponents(player, deployed)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil then return end
	if type(deployed) ~= 'table' then deployed = playerData.States.PVPDeploy or {} end

	local total = (playerData.Profile and playerData.Profile.CrystalsTotal) or 0
	local maxLevel = (playerData.Profile and playerData.Profile.MaxLevel) or 1
	local averageDPS = GetDeployedAverageDPS(playerData, deployed)
	local stealRate = shared.Config.PVPSTEAL_RATE

	sessions[player] = { Tokens = {}, CreatedAt = os.clock() }
	local used = {}
	local list = {}

	for _, difficulty in ipairs(DIFFICULTIES) do
		local crystalReward = shared.Config.PVP_REWARD[difficulty] or 0
		local lower, upper = GetBand(total, difficulty)
		local candidates = shared.PVPRankBoard.QueryCandidates(lower, upper, CANDIDATE_FETCH)

		for i = #candidates, 2, -1 do
			local j = math.random(i)
			candidates[i], candidates[j] = candidates[j], candidates[i]
		end

		local filled = 0
		for _, candidate in ipairs(candidates) do
			if filled >= CANDIDATE_PER_DIFFICULTY then break end
			if candidate.UserId == player.UserId or used[candidate.UserId] then continue end

			local team, cash = shared.PVPRankBoard.ReadTeam(candidate.UserId)
			if team == nil then continue end

			used[candidate.UserId] = true
			filled += 1
			table.insert(list, IssueToken(player, {
				Kind = 'Player',
				Difficulty = difficulty,
				Name = GetName(candidate.UserId),
				UserId = candidate.UserId,
				Total = candidate.Total,
				CrystalReward = crystalReward,
				CashReward = math.floor((cash or 0) * stealRate),
			}, team))
		end

		--	候选不足用机器人补齐（现金 = 该难度对应分钟数的离线奖励）
		while filled < CANDIDATE_PER_DIFFICULTY do
			filled += 1
			local team = BuildBotTeam(averageDPS, difficulty)
			table.insert(list, IssueToken(player, {
				Kind = 'Bot',
				Difficulty = difficulty,
				Name = 'Bot',
				TowerUID = team[1] and team[1].TowerUID,
				Total = total,
				CrystalReward = crystalReward,
				CashReward = self.GetBotCashReward(maxLevel, difficulty),
			}, team))
		end
	end

	ReplicatedStorage.Remote.PVP.Opponents:FireClient(player, { List = list })
end

--	战斗时校验 token 并取出对手；同一个 token 只能用一次
function self.Resolve(player, token)
	local session = sessions[player]
	if session == nil or type(token) ~= 'string' then return nil end
	if (os.clock() - session.CreatedAt) > TOKEN_TTL then return nil end

	local entry = session.Tokens[token]
	if entry == nil then return nil end

	session.Tokens[token] = nil
	return entry
end

function self.init()
	local dict = TowerData.Datas and TowerData.Datas.TowerDict
	if type(dict) ~= 'table' then return end

	for uid, towerData in pairs(dict) do
		if type(uid) == 'number' and type(towerData) == 'table' and towerData.AssetId ~= nil then
			table.insert(BotTowerPool, uid)
		end
	end
end

function self.start()
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return self
