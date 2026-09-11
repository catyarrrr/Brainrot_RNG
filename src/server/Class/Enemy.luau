local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)

local Class = {}
Class.__index = Class

local SPEED, SPEED_BOSS, SPEED_RUSH = 10, 3, 1
local pathEnemies, enemies, GetReward, ClearAll = {}, {}, nil

function Class.start()
	shared.Game.GameOverEvent:Connect(ClearAll)
	shared.Game.GameWinEvent:Connect(ClearAll)
end

function Class.new(game, round, enemyType, pathId, health, reward)
	local index = #enemies + 1
	game.SpawnRandom:NextInteger(0, 0)
	--local model = game.ReplicatedStorage.Characters[name]
	--local self = setmetatable(model:GetAttributes(), Class)
	local self = setmetatable({}, Class)
	self.CFrameIndex = 1
	self.Index = index
	self.PathId = pathId
	self.Type = enemyType
	self.WaypointIndex = 1
	self.Waypoint = shared.Path.Paths[pathId].Waypoints[self.WaypointIndex]
	if enemyType == 'Rush' then
		self.RawSpeed = SPEED_RUSH
		self.Speed = SPEED_RUSH
	elseif enemyType == 'Elite' or enemyType == 'Boss' then
		self.RawSpeed = SPEED_BOSS
		self.Speed = SPEED_BOSS
	else
		self.RawSpeed = SPEED
		self.Speed = SPEED
	end
	self.Game = game
	self.TickConnection = self.Game.Task.OnTick:Connect(Step, self)
	self.Destroyed = false
	self.Towers = shared.HybridList.new()
	self.Reward = reward or GetReward(round, enemyType)
	self.Health = health or shared.LevelData.GetHealthByRoundType(round, enemyType)
	self.MaxHealth = self.Health
	self.ReservedDamage = 0
	
	enemies[index] = self
	pathEnemies[pathId] = pathEnemies[pathId] or {}
	table.insert(pathEnemies[pathId], self)
	
	self.Waypoint:AddCharacter(self)

	if enemyType == 'Rush' then
		local pathTowers = shared.Tower.GetByPathId(pathId)
		if pathTowers then
			for _, tower in pairs(pathTowers) do
				tower:AddCharacter(self)
			end
		end
	end

	return self
end

function Class:Destroy()
	if self.Destroyed then return end
	self.Waypoint:RemoveCharacter(self)
	local towerlink = self.Towers.Next
	while towerlink ~= self.Towers do
		towerlink.Value:RemoveCharacter(self)
		towerlink = towerlink.Next
	end
	
	self.TickConnection:Disconnect()
	self.Destroyed = true
	
	----------- 从enemies中移除自己
	local lastCharacter = table.remove(enemies)
	if lastCharacter ~= self then
		-- 当前character不在enemies的末尾时
		enemies[self.Index] = lastCharacter
		lastCharacter.Index = self.Index
	end
	-----------
	local list = pathEnemies[self.PathId]
	if list then
		local index = table.find(list, self)
		if index then
			table.remove(list, index)
		end
	end
end

function Class:ModifyHealth(amount, owner, cash)
	if self.Health <= 0 then return end

	-- warn(amount)
	self.Health -= amount
	self.ReservedDamage -= amount

	if self.Type == 'Rush' then
		local farm = self.Reward * math.min(amount, self.Health + amount) / self.MaxHealth
		self.Game:Farm(farm)
	end

	if self.Health <= 0 then
		if self.Type ~= 'Rush' then self.Game:Farm(self.Reward * (cash or 1)) end
		TryLoot(self)
		self:Destroy()
	end
end

function Class:ModifySpeed(amount)
	self.RawSpeed += amount
	self.Speed = math.max(self.RawSpeed, 1) 
end

-- 每tick执行以下
function Step(self)
	-- 更新waypoint, 设置对应waypoint的character
	self.CFrameIndex += self.Speed
	local waypointIndex = shared.Path.Paths[self.PathId]:GetWaypointIndex(self.CFrameIndex)
	if waypointIndex ~= self.WaypointIndex then
		self.Waypoint:RemoveCharacter(self)
		if self.Destroyed then return end
		self.WaypointIndex += 1
		self.Waypoint = shared.Path.Paths[self.PathId].Waypoints[self.WaypointIndex]
		self.Waypoint:AddCharacter(self)
		if self.Destroyed then return end
	end
	
	-- 走到道路尽头
	if not shared.Path.Paths[self.PathId].CFrames[self.CFrameIndex] then 
		-- warn('hurt')
		-- shared.HealthHandler:ReduceHealth(GetDamageByType(self.Type))
		self.Game:ReduceHealth(GetDamageByType(self.Type))
		
		self:Destroy() 
	end
end

function Class.GetCharactersCount()
	return #enemies
end
function Class.CheckEnemiesClearByPathId(pathId)
	local chk = true
	if pathEnemies[pathId] and next(pathEnemies[pathId]) ~= nil then
		chk = false
	end

	return chk
end

function GetDamageByType(type)
	local damage = 0
	if type == 'Mob' then
		damage = 10
	elseif type == 'Elite' then
		damage = 25
	elseif type == 'Boss'then
		damage = 50
	elseif type == 'Rush' then
		damage = 100
	end

	if damage == 0 	then warn('damage calculate error for type', type); return end
	return damage
end
function ClearAll(_, _, pathId)
	if pathEnemies[pathId] == nil then return end
	for i = #pathEnemies[pathId], 1, -1 do
		pathEnemies[pathId][i]:Destroy()
	end

	pathEnemies[pathId] = nil
end
function GetReward(round, type)
	local baseReward = 10 * round

	return math.ceil(baseReward)
end
function TryLoot(self)
	if self.Type ~= 'Mob' then
		local loots = {}
		local curRound = self.Game.Round
		if self.Type == 'Rush' then
			local time = shared.CalculateData.GetBossDrop(curRound)
			for i=1, time do
				local key = ItemData.GetRushItemByRound(curRound)
				loots[key] = (loots[key] or 0) + 1
			end

			for k, v in loots do
				loots[k] *= self.Game.Rush or 1
			end
			shared.DataStore.RewardController.BossDrop(self.Game.Player, loots)
		else
			local key = ItemData.GetGachaKeyByRound(curRound)
			if self.Type == 'Boss' then
				for i=1, ItemData.BOSS_TIME do
					local itemId = ItemData.GachaItem(key)
					loots[itemId] = (loots[itemId] or 0) + 1
				end
			else
				local itemId = ItemData.GachaItem(key)
				
				loots[itemId] = (loots[itemId] or 0) + 1
			end
			shared.DataStore.RewardController.EnemyDrop(self.Game.Player, loots)
		end
		
	end
end	

return Class
