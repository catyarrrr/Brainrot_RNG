--[[
	PVPRankBoard (Server)
	PVP 匹配用的「累计 Crystals」数据源：
		- 以 Profile.CrystalsTotal 为分数写入 OrderedDataStore（索引）
		- 提供按分数区间查询「数据相近」的玩家
		- 读取任意玩家存档，取收藏中 DPS 最高的 4 个塔（随机序）
		- 内存缓存，降低 DataStore 读取压力
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local BOARD_STORE = 'PVPCrystalTotal'
local ARCHIVE_STORE, ARCHIVE_SCOPE = 'PlayerData', 'global'
local MIRROR_INTERVAL = 60
local TEAM_CACHE_TTL = 5 * 60
local MAX_DEPLOY = 4
local MAX_CANDIDATE_FETCH = 50

local self : any = {}

--	userId -> { Team = {...}, CachedAt = number }
local teamCache = {}

--	单个塔的 DPS（含 trait 修正）
function self.GetTowerDPS(towerUID, traitId)
	local stats = TowerData.GetCloneData(towerUID)
	if stats == nil then return 0 end

	shared.CalculateData.ApplyModifiers(stats, traitId)
	return shared.CalculateData.GetDPS(stats.Damage, stats.ActionDelay)
end

--	从玩家存档的收藏中取 DPS 最高的 MAX_DEPLOY 个塔，并随机排列
local function BuildTeamFromArchive(archive)
	local list = {}
	for _, towerData in pairs(archive.Tower.Inv) do
		if type(towerData) ~= 'table' or type(towerData.TowerUID) ~= 'number' then continue end
		table.insert(list, {
			TowerUID = towerData.TowerUID,
			DPS = self.GetTowerDPS(towerData.TowerUID, towerData.Trait),
		})
	end
	table.sort(list, function(a, b) return a.DPS > b.DPS end)

	local team = {}
	for index = 1, math.min(MAX_DEPLOY, #list) do
		team[index] = list[index]
	end
	for i = #team, 2, -1 do
		local j = math.random(i)
		team[i], team[j] = team[j], team[i]
	end
	return team
end

--	读取指定玩家存档并换算成队伍；读取失败返回 nil。第二返回值是对方当前现金
function self.ReadTeam(userId)
	local cached = teamCache[userId]
	if cached ~= nil and (os.clock() - cached.CachedAt) < TEAM_CACHE_TTL then
		return cached.Team, cached.Cash
	end

	local success, archive = pcall(function()
		return DataStoreService:GetDataStore(ARCHIVE_STORE, ARCHIVE_SCOPE):GetAsync(tostring(userId))
	end)
	if success ~= true or type(archive) ~= 'table' then return nil end
	if type(archive.Tower) ~= 'table' or type(archive.Tower.Inv) ~= 'table' then return nil end

	local team = BuildTeamFromArchive(archive)
	if #team == 0 then return nil end

	local cash = (archive.Coin and archive.Coin.Cash) or 0
	teamCache[userId] = { Team = team, Cash = cash, CachedAt = os.clock() }
	return team, cash
end

--	按分数区间查询候选玩家，返回 { UserId, Total }
function self.QueryCandidates(lo, hi, limit)
	local success, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore(BOARD_STORE):GetSortedAsync(
			false, math.min(limit, MAX_CANDIDATE_FETCH), math.max(0, math.floor(lo)), math.ceil(hi))
	end)
	if success ~= true or pages == nil then return {} end

	local result = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key)
		if userId ~= nil then
			table.insert(result, { UserId = userId, Total = entry.value })
		end
	end
	return result
end

--	把单个在线玩家的累计 Crystals 写入索引
function self.UpdateEntry(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil or playerData.Profile == nil then return end

	pcall(function()
		DataStoreService:GetOrderedDataStore(BOARD_STORE):SetAsync(
			tostring(player.UserId), math.floor(playerData.Profile.CrystalsTotal or 0))
	end)
end

--	周期性把在线玩家的累计 Crystals 镜像到索引
function self.start()
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				self.UpdateEntry(player)
				task.wait(.1)
			end
			task.wait(MIRROR_INTERVAL)
		end
	end)
end

return self
