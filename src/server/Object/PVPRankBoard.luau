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
local CANDIDATE_CACHE_TTL = 20
local CANDIDATE_CACHE_MAX = 200
local MAX_DEPLOY = 4
local MAX_CANDIDATE_FETCH = 50
local RANK_PAGE = 100
local RANK_SCAN_MAX = 2000

local self : any = {}

--	userId -> { Team = {...}, CachedAt = number }
local teamCache = {}

--	分数区间 -> { List = {...}, CachedAt = number }，降低刷新对手时的 DataStore 请求量
local candidateCache = {}
local candidateCacheCount = 0

--	塔是否仍存在于当前静态数据：对手存档里可能残留已下架的塔，直接查表避免 GetCloneData 报警
local function TowerExists(towerUID)
	local dict = TowerData.Datas and TowerData.Datas.TowerDict
	return type(dict) == 'table' and dict[towerUID] ~= nil
end

--	单个塔的 DPS（含 trait 修正）
function self.GetTowerDPS(towerUID, traitId)
	if not TowerExists(towerUID) then return 0 end

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
		if not TowerExists(towerData.TowerUID) then continue end
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

local function CopyList(list)
	local copy = {}
	for index, entry in ipairs(list) do
		copy[index] = entry
	end
	return copy
end

--	缓存过多时先清理过期项，仍超限则整体清空，避免无限增长
local function PruneCandidateCache(now)
	if candidateCacheCount < CANDIDATE_CACHE_MAX then return end

	for key, entry in pairs(candidateCache) do
		if (now - entry.CachedAt) >= CANDIDATE_CACHE_TTL then
			candidateCache[key] = nil
			candidateCacheCount -= 1
		end
	end

	if candidateCacheCount >= CANDIDATE_CACHE_MAX then
		candidateCache = {}
		candidateCacheCount = 0
	end
end

--	按分数区间查询候选玩家，返回 { UserId, Total }；同区间短期内复用缓存
function self.QueryCandidates(lo, hi, limit)
	local now = os.time()
	local key = string.format('%d:%d:%d', math.floor(lo), math.ceil(hi), limit)

	local cached = candidateCache[key]
	if cached ~= nil and (now - cached.CachedAt) < CANDIDATE_CACHE_TTL then
		return CopyList(cached.List)
	end

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

	PruneCandidateCache(now)
	if candidateCache[key] == nil then candidateCacheCount += 1 end
	candidateCache[key] = { List = CopyList(result), CachedAt = now }
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

--	按累计 Crystals 计算排名（高于自己的玩家数 + 1）；扫描超过上限返回 nil
function self.GetRank(total)
	total = math.floor(total or 0)
	local success, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore(BOARD_STORE):GetSortedAsync(false, RANK_PAGE, total + 1, nil)
	end)
	if success ~= true or pages == nil then return nil end

	local above = 0
	while true do
		local page = pages:GetCurrentPage()
		above += #page
		if above >= RANK_SCAN_MAX then return nil end
		if pages.IsFinished then break end

		local ok = pcall(function() pages:AdvanceToNextPageAsync() end)
		if not ok then break end
	end
	return above + 1
end

--	计算并写回玩家自己的排名
function self.RefreshRank(player)
	local playerData = shared.DataStore.GetData(player)
	if playerData == nil or playerData.Profile == nil then return end

	local rank = self.GetRank(playerData.Profile.CrystalsTotal or 0)
	if rank == nil then return end

	playerData.Profile.PVPRank = rank
	shared.DataStore.SetPlayerData(player, 'Profile')
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
