Instance.new('Folder', 	workspace).Name = 'Characters'
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService("RunService")
local LevelData = require(ReplicatedStorage.Datas.LevelData :: ModuleScript) 
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local SPEED, SPEED_RUSH, OFFSET_X, OFFSET_Y = 10, 1, 15, .125
local RUSH_FARM_DEBOUNCE = .35
local VisualTask, pathEnemies, enemies, primaryParts, cFrames, ClearAll, GetReward = {}, {}, {}, {}, {}, nil
local Class : any = {}
Class.__index = Class

function Class.init()
	Class.BossGeneratedEvent = shared.Event.new()
	Class.BossHurtEvent = shared.Event.new()
	Class.MyEnemiesDestroyedEvent = shared.Event.new()
end

function Class.start()
	shared.Task.PostTick:Connect(BulkMove)
	shared.Game.GameOverEvent:Connect(ClearAll)
	ReplicatedStorage.Remote.Game.PlayerGameStart.OnClientEvent:Connect(StartPlayerEnemies)
	ReplicatedStorage.Remote.Game.PlayerGameOver.OnClientEvent:Connect(StopPlayerEnemies)
	ReplicatedStorage.Remote.Game.PlayerExit.OnClientEvent:Connect(StopPlayerEnemies)
end

function Class.new(round, type, assetId, pathId, health, reward)
	-- print('assetId = ', assetId)
	-- print('pathid : ', pathId)
	local index = #enemies + 1
	local assetsData = AssetsData[assetId]
	if assetsData == nil then print('enemy assets not found for id:', assetId); return end
	local self = setmetatable(table.clone(assetsData), Class)
	local model = ReplicatedStorage.Assets.Enemies[self.Model]
	self.Index = index
	self.PathId = pathId
	self.Type = type
	self.CFrameIndex = 1
	self.WaypointIndex = 1
	self.Model = model:Clone()
	self.CFrame = shared.Path.Paths[pathId].CFrames[self.CFrameIndex]
	if pathId == shared.PlayerDataHandler.GetCurPath() then
		self.Offset = CFrame.new(shared.Game.SpawnRandom:NextInteger(-OFFSET_X, OFFSET_X), 0, 0) + Vector3.new(0, OFFSET_Y, 0)
	else
		self.Offset = CFrame.new(Class.rng:NextInteger(-OFFSET_X, OFFSET_X), 0, 0) + Vector3.new(0, OFFSET_Y, 0)
	end
	if type == 'Rush' then self.Offset = CFrame.new(0, OFFSET_Y, 0) end
	self.Waypoint = shared.Path.Paths[pathId].Waypoints[self.WaypointIndex]
	self.Model:PivotTo(self.CFrame*self.Offset)
	self.Model.Parent = workspace.Characters
	if type == 'Rush' then
		self.RawSpeed = SPEED_RUSH
		self.Speed = SPEED_RUSH
	else
		self.RawSpeed = SPEED
		self.Speed = SPEED
	end
	self.Animation = self.Model.AnimationController.Animator:LoadAnimation(self.Model.AnimationController.Animation)
	self.Animation:Play(nil, nil, self.Speed * self.AnimationSpeed)
	
	if pathId == shared.PlayerDataHandler.GetCurPath() then
		self.TickConnection = shared.Task.OnTick:Connect(Step, self)
	else
		self.TickConnection = RunService.Heartbeat:Connect(function(dt)
			OtherStep(self, dt)
		end)
	end
	self.Destroyed = false
	self.Towers = shared.HybridList.new()
	self.Reward = reward or GetReward(round, type)
	self.Health = health or shared.LevelData.GetHealthByRoundType(round, type)
	self.MaxHealth = self.Health
	self.ReservedDamage = 0

	if type == 'Rush' and shared.UIHandler and shared.UIHandler.TopUI then
		shared.UIHandler.NewBossBarEvent:Fire(self.Health, self.MaxHealth)
	end

	enemies[index] = self
	pathEnemies[pathId] = pathEnemies[pathId] or {}
	table.insert(pathEnemies[pathId], self)
	
	primaryParts[index] = self.Model.PrimaryPart
	cFrames[index] = self.Model.PrimaryPart.CFrame
	
	if self.RotationOffset then
		self.Offset *= CFrame.Angles(0, math.rad(self.RotationOffset), 0)
	end
	
	self.Waypoint:AddCharacter(self)
	if type == 'Rush' then
		local myTowers = shared.Tower.GetMyTowers()
		if myTowers then
			for _, tower in pairs(myTowers) do
				tower:AddCharacter(self)
			end
		end
	end
	
	return self
end

function Class:Destroy()
	if self.Destroyed then return end
	-- print('destroy')
	if self.PathId == shared.PlayerDataHandler.GetCurPath() then
		Class.MyEnemiesDestroyedEvent:Fire()
	end

	self.Waypoint:RemoveCharacter(self)
	local towerlink = self.Towers.Next
	while towerlink ~= self.Towers do
		towerlink.Value:RemoveCharacter(self)
		towerlink = towerlink.Next
	end
	
	if self.Bar then self.Bar:Destroy() end
	self.TickConnection:Disconnect()
	self.Model:Destroy()
	self.Destroyed = true
	
	----------- 从enemies中移除自己
	local lastCharacter = table.remove(enemies)
	if lastCharacter == self then
		-- 自己在enemies中的末节点时
		table.remove(primaryParts)
		table.remove(cFrames)
	else
		-- 其他情况时
		enemies[self.Index] = lastCharacter
		primaryParts[self.Index] = table.remove(primaryParts)
		cFrames[self.Index] = table.remove(cFrames)
		lastCharacter.Index = self.Index
	end
	-----------
	
	-- shared.UIHandler.EnemyCountUI()
end

function Class:ModifyHealth(amount)
	if self.PathId ~= shared.PlayerDataHandler.GetCurPath() then return end
	if self.Health <= 0 or self.Destroyed then return end
	
	-- print(amount)
	local oriHealth = self.Health
	self.Health -= amount 
	self.ReservedDamage -= amount
	if self.Type == 'Rush' and shared.UIHandler and shared.UIHandler.TopUI then
		shared.UIHandler.UpdateBossBarEvent:Fire(self.Health, self.MaxHealth)
	end
	shared.VFXHandler.TriggerDamageTextEvent:Fire(self.Model.Head, amount)
	-- if self.Type == 'Boss' then self.BossHurtEvent:Fire(self.Health/bossHealth) end

	if self.Type == 'Rush' then
		local now = os.clock()
		if self.FarmDebounce == nil or now - self.FarmDebounce >= RUSH_FARM_DEBOUNCE then
			self.FarmDebounce = now
			shared.VFXHandler.EnemyFarmEvent:Fire(self.Model:GetPivot().Position, 10000)
		end
	end
	
	if self.Health > 0 then
		-- 未死亡
		if self.Bar then
			self.Bar:Set(self.Health)
		else
			self.Bar = shared.Bar.new(self.Model.Head, self.Health, self.Health+amount, Color3.new(.92, .22, .2))
		end
	else
		if oriHealth < amount then 
			shared.Bar.PlayEmptyEffect(self.Model.Head)
		end
		-- shared.SoundHandler:PlayRanAt('CharacterDestroy', self.Model.PrimaryPart.Position)
		shared.VFXHandler.PlayParticleEvent:Fire('EnemyDeadParticle', self.Model.Torso.Position, 1)
		if self.Type ~= 'Rush' then
			shared.VFXHandler.EnemyFarmEvent:Fire(self.Model:GetPivot().Position, self.Reward)
		end
		if self.Bar then self.Bar:Destroy() end
		self:Destroy()
	end

end

function Class:ModifySpeed(amount)
	self.RawSpeed += amount
	self.Speed = math.max(self.RawSpeed, 1)
	self.Animation:AdjustSpeed(self.Speed * self.AnimationSpeed)
end

function Class.GetCharactersLength()
	return #enemies
end

-- 每tick执行以下
function Step(self)
	self.CFrameIndex += self.Speed
	self.CFrame = shared.Path.Paths[self.PathId].CFrames[self.CFrameIndex]
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
	if not self.CFrame then
		self:Destroy() 
	end
end
function OtherStep(self, dt)
	self.CFrameIndex += self.Speed * shared.Task.TickPerSecond * dt
	self.CFrame = shared.Path.Paths[self.PathId].CFrames[math.floor(self.CFrameIndex)]
	local waypointIndex = shared.Path.Paths[self.PathId]:GetWaypointIndex(self.CFrameIndex)
	if waypointIndex ~= self.WaypointIndex then
		self.Waypoint:RemoveCharacter(self)
		if self.Destroyed then return end
		self.WaypointIndex += 1
		self.Waypoint = shared.Path.Paths[self.PathId].Waypoints[self.WaypointIndex]
		self.Waypoint:AddCharacter(self)
		if self.Destroyed then return end
	end
	if not shared.Path.Paths[self.PathId].CFrames[math.floor(self.CFrameIndex + #shared.Path.Paths[self.PathId].CFrames/2)] then
		self:Destroy()
	elseif not self.Destroyed then
		local part = self.Model.PrimaryPart
		if part then
			part.CFrame = self.CFrame * self.Offset
		end
	end
end

function BulkMove()
	for index, character in enemies do
		cFrames[index] = character.CFrame * character.Offset
	end
	workspace:BulkMoveTo(primaryParts, cFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

function ClearAll()
	local pathId = shared.PlayerDataHandler.GetCurPath()
	local list = pathEnemies[pathId]
	if not list then return end
	for i = #list, 1, -1 do
		list[i]:Destroy()
	end

	pathEnemies[pathId] = nil
end
function GetReward(round, type)
	local baseReward = 10 * round

	return math.ceil(baseReward)
end

function StartPlayerEnemies(player, pathId)
	if player ~= Players.LocalPlayer then
		if VisualTask[player] then
			task.cancel(VisualTask[player])
			VisualTask[player] = nil 
		end

		if Class.rng == nil then Class.rng = Random.new() end
		VisualTask[player] = task.spawn(function()
			local round = 1
			while true do
				local levelData = LevelData.GetData(round)

				for i=1, levelData.Amount do
					local id = levelData.Mobs[Class.rng:NextInteger(1, #levelData.Mobs)]
					shared.Enemy.new(round, 'Mob', id, pathId)
					task.wait(.25)
				end
				if levelData.Elite then
					shared.Enemy.new(round, 'Elite', levelData.Elite, pathId)
				elseif levelData.Boss then
					shared.Enemy.new(round, 'Boss', levelData.Boss, pathId)
				end

				round += 1
				task.wait(1)
			end	
		end)

	end	
end
function StopPlayerEnemies(player, pathId)
	if player ~= Players.LocalPlayer then
		if VisualTask[player] then
			task.cancel(VisualTask[player])
			VisualTask[player] = nil 
		end

		local list = pathEnemies[pathId]
		if list then
			for i = #list, 1, -1 do
				list[i]:Destroy()
			end
		end
	end	
end


return Class
