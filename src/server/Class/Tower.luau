local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)

local worldModel = Instance.new('WorldModel', game:GetService('ServerStorage'))
local towers = game.ReplicatedStorage.Assets.Towers:Clone()

local raycastParams, towerIndex = RaycastParams.new(), 0
raycastParams.FilterType = Enum.RaycastFilterType.Include
local PathTowers, VisualTask = {}, {}
local Class : any = {collections = {}}
Class.__index = Class

function Class.init()
	Class.PickupAllEvent = shared.Event.new()
	Class.SpawnEvent = shared.Event.new()
end

function Class.start()
	shared.Game.GameOverEvent:Connect(Reset)
	shared.DataStore.PlayerExitEvent:Connect(DeleteTowerByPlayer)
	Class.PickupAllEvent:Connect(DeleteTowerByPlayer)
	-- ReplicatedStorage.Remote.PlayerPathInitiated.OnServerEvent:Connect(AsyncTower)
end

function Class.GetByUID(uid)
	local tower = Class.collections[uid]
	if tower == nil then return end

	return tower
end

function Class.GetByPathId(pathId)
	return PathTowers[pathId]
end

function DeleteTowerByPlayer(_, player)
	local pathId = shared.DataStore.GetPlayerCurPath(player)
	local pathTowers = PathTowers[pathId]
	if pathTowers == nil then return end
	local towersToDestroy = {}
	for k, v in pathTowers do
		table.insert(towersToDestroy, v)
	end
	for _, v in towersToDestroy do
		v:Destroy()
	end
end
function Class.AsyncTower(player)
	-- print('try async')
	local playerPathId = shared.DataStore.GetPlayerCurPath(player)
	for pathId, pathTowers in PathTowers do
		if pathId == playerPathId then continue end
		for uid, tower in pathTowers do
			-- print('async tower by uid', uid)
			ReplicatedStorage.Remote.Tower.TowerSpawn:FireClient(player, tower.TowerUID, tower.UID, nil, tower.CFrame, tower.Owner, tower.WaypointIndices, tower.Level, tower.Id, tower.GridXY, tower.Shape, tower.PathId, tower.Trait)
		end
	end
end
function Class.GetTotalDPSByPlayer(player)
	local pathId = shared.DataStore.GetPlayerCurPath(player)
	local dict = PathTowers[pathId]
	if dict == nil then warn('PathTower not found'); return end

	local dps = 0
	for k, v in pairs(dict) do
		local cur = shared.CalculateData.GetDPS(v.Damage, v.ActionDelay)
		dps += cur
	end

	return dps
end

function Class.new(player, towerUID, uid, name, cFrame, level, towerId, gridXY, shapeName , pathId, traitId)
	-- local self = setmetatable(TowerDatas.GetData(tonumber(string.match(name, 'r(%d+)$')), level), Class)

	local self = setmetatable(TowerData.GetCloneData(towerUID), Class)

	if traitId then
		shared.CalculateData.ApplyModifiers(self, traitId)
	end

	self.Destroyed = false
	self.CFrame = cFrame

	local assetId = TowerData.GetAssetIdByTowerUID(towerUID)
	local asset = AssetsData[assetId]
	local model = towers:FindFirstChild(asset.Model):Clone()
	model = Class.InitTowerModel(towerUID, model)
	model:PivotTo(cFrame)
	model.Parent = worldModel
	model.Range.Size = Vector3.new(self.Range*2, model.Range.Size.Y, self.Range*2)
	
	if towerId == nil then
		towerIndex += 1
		self.Id = towerIndex
	else
		self.Id = towerId
	end
	--print('generate tower with id:', self.Id)
	
	self.UID = uid
	self.Level = level
	self.Owner = player
	self.Connection = {}
	self.Characters = shared.HybridList.new()
	self.GridXY = gridXY
	self.Shape = shapeName
	self.PathId = pathId
	self.TowerUID = towerUID
	self.TotemType = TotemData.GetTotemTypeByTowerUID(self.TowerUID)
	self.Trait = traitId
	self.Game = shared.Game.Get(self.Owner)
	
	-- 根据当前tower的type属性引入tower行为
	for index, func in shared.TowerFunctions[self.Type] do self[index] = func end
	
	raycastParams.FilterDescendantsInstances = {model.Range}
	
	local waypointIndices = {}		-- 包含waypoint对, 表示进入和离开防御塔攻击范围的waypointindex, 可能含一对以上
	
	local path = shared.Path.Paths[self.PathId]
	
	-- 通过水平距离判断路径点是否在圆柱形攻击范围内（path 与塔都在地面，忽略 Y 差）
	local rangeCenter = model.Range.Position
	local rangeSqr = self.Range * self.Range
	local function IsPositionInRange(position)
		local dx = position.X - rangeCenter.X
		local dz = position.Z - rangeCenter.Z
		return dx * dx + dz * dz <= rangeSqr
	end
	
	-- 判断路径起点是否在范围内，若在内则以第 1 个 waypoint 作为 enter
	local inside = IsPositionInRange(path.Positions[1])
	if inside then
		table.insert(waypointIndices, 1)
	end
	
	for index, direction in path.Directions do
		local nextInside = IsPositionInRange(path.Positions[index + 1])
		
		if not inside and nextInside then
			-- 从外进入：沿 direction 方向发射射线检测 enter waypoint
			local result = worldModel:Raycast(path.Positions[index], direction, raycastParams)
			
			if result ~= nil then
				local rayDistance = math.max(result.Distance - path.Offsets[index], 0)
				local waypoint = path:GetWaypoint(path.Distances[index] + rayDistance)
				table.insert(waypointIndices, waypoint.Index)
				
				-- 画出所属cframe和最近的waypoint
				-- path:Debug(path.Distances[index] + rayDistance)
			end
		elseif inside and not nextInside then
			-- 从内离开：沿 direction 反方向发射射线检测 exit waypoint
			local result = worldModel:Raycast(path.Positions[index + 1], -direction, raycastParams)
			
			if result ~= nil then
				local rayDistance = math.max(result.Distance - path.Offsets[index + 1], 0)
				local waypoint = path:GetWaypoint(path.Distances[index + 1] - rayDistance)
				table.insert(waypointIndices, waypoint.Index)
				
				-- 画出所属cframe和最近的waypoint
				-- path:Debug(path.Distances[index + 1] - rayDistance)
			end
		end
		
		inside = nextInside
	end
	
	-- 路径终点仍在范围内，以最后一个 waypoint 作为 exit
	if inside then
		table.insert(waypointIndices, path:GetWaypoint(math.huge).Index)
	end

	self.WaypointIndices = waypointIndices
	
	model:Destroy()
	ReplicatedStorage.Remote.Tower.TowerSpawn:FireAllClients(towerUID, uid, name, cFrame, self.Owner, waypointIndices, self.Level, self.Id, gridXY, shapeName, self.PathId, traitId)
	--self.ConstructTask = shared.Task:Delay(self.ConstructDelay, Construct, self, waypointIndices)
	Construct(self, waypointIndices)
	
	Class.collections[self.Id] = self
	Class.collections[self.UID] = self

	PathTowers[self.PathId] = PathTowers[self.PathId] or {}
	PathTowers[self.PathId][self.UID] = self
	
	Class.SpawnEvent:Fire(self.Owner, self.PathId)

	return self
end

function Class:Upgrade()
	local nextTowerUID = TowerData.GetTowerNext(self.TowerUID)
	local owner, uid, towerName, cFrame, level, id, gridXY, shapeName, pathId, traitId = self.Owner, self.UID, self.TowerName, self.CFrame, self.Level + 1, self.Id, self.GridXY, self.Shape, self.PathId, self.Trait
	self:Destroy()
	
	shared.SoundHandler:PlayAt('AlienUpgrade', self.CFrame.Position)
	self.new(owner, nextTowerUID, uid, towerName, cFrame, level, id, gridXY, shapeName, pathId, traitId)
end

function Class:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	
	ReplicatedStorage.Remote.Tower.TowerDespawn:FireAllClients(self.Id)
	
	Class.collections[self.Id] = nil
	Class.collections[self.UID] = nil

	local pathTowers = PathTowers[self.PathId]
	if pathTowers then
		pathTowers[self.UID] = nil
		if next(pathTowers) == nil then PathTowers[self.PathId] = nil end
	end
	
	--if self.ConstructTask then self.ConstructTask:Remove() end
	
	for _, connection in self.Connection do connection:Disconnect() end
	if self.ActionTask then self.ActionTask:Remove() end
	-- Deconstruct(self)
end

-- Enemy进入攻击范围时执行的逻辑
function Class:AddCharacter(character)
	if self.Characters.Links[character] ~= nil then return end
	self.Characters:InsertBack(character)
	character.Towers:InsertBack(self)
	if self.Enter then shared.Thread:Spawn(self.Enter, self, character) end
	if self.Action and self.ActionTask == nil then Action(self) end
end
-- Enemy退出攻击范围时执行的逻辑
function Class:RemoveCharacter(character)
	self.Characters:Remove(character)
	character.Towers:Remove(self)
	
	if self.Exit then shared.Thread:Spawn(self.Exit, self, character) end
end

function Class:Reset()
	if self.ActionTask then
		self.ActionTask:Remove()
		self.ActionTask = nil
	end

	self.Characters = shared.HybridList.new()
end

function Construct(self, waypointIndices)
	--self.ConstructTask = nil

	local path = shared.Path.Paths[shared.DataStore.GetPlayerCurPath(self.Owner)]
	for index = 1, #waypointIndices, 2 do
		local enterWaypoint = path.Waypoints[waypointIndices[index]]
		local exitWaypoint = path.Waypoints[waypointIndices[index + 1]]
		for index = exitWaypoint.Index, enterWaypoint.Index, -1 do
			local characters = path.Waypoints[index].Characters
			local characterlink = characters.Next
			while characterlink ~= characters do
				self:AddCharacter(characterlink.Value)
				characterlink = characterlink.Next
			end
		end
		table.insert(self.Connection, enterWaypoint.CharacterAdded:Connect(self.AddCharacter, self)) 
		table.insert(self.Connection, exitWaypoint.CharacterRemoved:Connect(self.RemoveCharacter, self)) 
	end
end

function Action(self)
	if self.Characters.Length == 0 then
		self.ActionTask = nil
	elseif self.Game and self.Game.Started then
		self.ActionTask = self.Game.Task:Delay(self.ActionDelay, Action, self)
		shared.Thread:Spawn(self.Action, self)
	end
end

function Reset(_, player)
	-- print(player)
	local pathId = shared.DataStore.GetPlayerCurPath(player)
	local pathTowers = PathTowers[pathId]
	if pathTowers == nil then return end
	for k, v in pathTowers do
		v:Reset()
		ReplicatedStorage.Remote.Tower.TowerReset:FireAllClients(v.UID)
	end
end

function Class.InitTowerModel(towerUID, model)
	local staticData = TowerData.GetData(towerUID)
	if staticData == nil then return end
	
	local outerModel = Instance.new('Model')
	outerModel.Name = model.Name
	outerModel.PrimaryPart = model.PrimaryPart
	model.Parent = outerModel
	local circle = ReplicatedStorage.Assets.Parts.TowerParts.Circle:Clone()
	circle:PivotTo(model:GetPivot())
	circle.Size = Vector3.new(staticData.Range, circle.Size.Y, staticData.Range)
	circle.Parent = outerModel

	local range = ReplicatedStorage.Assets.Parts.TowerParts.Range:Clone()
	range:PivotTo(model:GetPivot())
	range.Size = Vector3.new(staticData.Range, range.Size.Y, staticData.Range)
	range.Parent = outerModel

	return outerModel
end

return Class
