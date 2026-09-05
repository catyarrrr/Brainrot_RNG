local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)
Instance.new('Folder', workspace).Name = 'Towers'

local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local CheckAlienMerge, New, Destroy, UpdateAnimationVisibility = nil
local towerPlacements, PlayerTowers, VisualTask, TowerList, myTowers = {}, {}, {}, {}, {}
local VIEW_DISTANCE = 300
local Class : any = {collections = {}, }
Class.__index = Class

function Class.init()
	-- Class.MyTowerUpdate = shared.Event.new()
	Class.SpawnTowerEvent = shared.Event.new()
	Class.DespawnTowerEvent = shared.Event.new()
	Class.CheckMergeEvent = shared.Event.new()
	Class.MyTowerChangeEvent = shared.Event.new()
end

function Class.start()
	ReplicatedStorage.Remote.Tower.TowerSpawn.OnClientEvent:Connect(New)
	ReplicatedStorage.Remote.Tower.TowerDespawn.OnClientEvent:Connect(Destroy)
	ReplicatedStorage.Remote.Tower.TowerReset.OnClientEvent:Connect(function(uid)
		local tower = Class.collections[uid]
		if tower == nil then warn('reset tower not found');return end

		tower:Reset()
		-- print('reset')
	end)
	ReplicatedStorage.Remote.Game.PlayerGameStart.OnClientEvent:Connect(StartPlayerTowerAction)
	ReplicatedStorage.Remote.Game.PlayerGameOver.OnClientEvent:Connect(StopPlayerTowerAction)
	ReplicatedStorage.Remote.Game.PlayerExit.OnClientEvent:Connect(StopPlayerTowerAction)
	Class.CheckMergeEvent:Connect(CheckAlienMerge)
	task.spawn(UpdateAnimationVisibility)
end

function New(towerUID, uid, name, cFrame, player, waypointIndices, level, towerId, gridXY, shapeName, pathId, traitId)
	-- print('******************************')
	-- print(towerUID, towerUID, name, cFrame, player, waypointIndices, level, towerId)

	-- print('pathinitiated =', shared.Path.Initiated)
	if Class.collections[uid] ~= nil then return end

	local self = setmetatable(TowerData.GetCloneData(towerUID), Class)

	if traitId then
		shared.CalculateData.ApplyModifiers(self, traitId)
	end

	local assetsData = AssetsData[self.AssetId]
	local model = ReplicatedStorage.Assets.Towers:FindFirstChild(assetsData.Model):Clone()

	Class.SpawnTowerEvent:Fire(player, towerUID, towerId, gridXY, shapeName, model, cFrame)
	self.Destroyed = false
	self.Upgraded = false
	self.Id = towerId
	self.UID = uid
	self.TowerUID = towerUID
	self.Trait = traitId
	self.Owner = player
	self.Level = level
	self.GridXY = gridXY
	self.Shape = shapeName
	self.PathId = pathId
	self.TotemType = TotemData.GetTotemTypeByTowerUID(self.TowerUID)

	--#region		模型初始化
	self.Model = model
	self.CFrame = cFrame
	self.Model:PivotTo(cFrame)
	self.Model.Circle.Size = Vector3.new(self.Range*2, model.Circle.Size.Y, self.Range*2)
	self.Model.Range.CanQuery = false
	self.Model.Circle.Transparency = 1
	self.Model.Parent = workspace.Towers
	
	self.Position = self.Model.PrimaryPart.Position
	self.Rig = self.Model:FindFirstChildOfClass('Model')
	self.CFrameOffset = self.Model:GetAttribute('CF') or CFrame.new(0, 0, 0)
	self.Rig:PivotTo(self.Rig:GetPivot() * self.CFrameOffset)
	self.Rig.PrimaryPart.Anchored = true
	-- if TowerData.GetTowerTypeByTowerUID(self.TowerUID) == 32 then self.Rig:ScaleTo(SCALE_WAYBIG) end
	self.Highlight = self.Rig.Highlight
	if assetsData.IdleAnimation then
		self.IdleAnimationTrack = shared.AnimationHandler.GetAnimationTrack(self.Rig, assetsData.IdleAnimation)
		self.IdleAnimationTrack.Priority = Enum.AnimationPriority.Idle
		self.IdleAnimationTrack.Looped = true
		self.IdleAnimationTrack:AdjustWeight(0)
	end
	if assetsData.AttackAnimation then
		self.AttackAnimationTrack = shared.AnimationHandler.GetAnimationTrack(self.Rig, assetsData.AttackAnimation)
		self.AttackAnimationTrack.Priority = Enum.AnimationPriority.Action
		self.AttackAnimationTrack.Looped = false
		self.AttackAnimationTrack:AdjustWeight(1)
	end
	local wing = self.Rig:FindFirstChild('Wing')
	if wing then
		local offset = wing:GetAttribute('Offset')
		if offset then wing:PivotTo(wing:GetPivot() + offset) end
		self.WingAnimationTrack = shared.AnimationHandler.GetAnimationTrack(wing)
		self.WingAnimationTrack.Looped = true
	end

	self.InView = self:IsInView(workspace.CurrentCamera)
	self:SetAnimationsActive(self.InView)
	table.insert(TowerList, self)
	--#endregion 
	
	self.Connection = {}
	self.Characters = shared.HybridList.new()
	
	game.CollectionService:AddTag(self.Rig, 'Tower')

	if self.Owner == game:GetService('Players').LocalPlayer then
		if towerPlacements[self.UID] == nil then
			towerPlacements[self.UID] = 1
		else
			towerPlacements[self.UID] += 1
		end
		myTowers[self.UID] = self
	end
	
	for _, child in self.Rig:GetDescendants() do
		if child:IsA('BasePart') then
			child.CollisionGroup = 'Tower'
		end
	end
	
	-- 根据当前tower的type属性引入tower行为
	for index, func in shared.TowerFunctions[self.Type] do self[index] = func end
	
	if self.Owner == Players.LocalPlayer then
		Construct(self, waypointIndices)
	end
	
	Class.collections[self.Model] = self
	Class.collections[self.Id] = self
	Class.collections[self.UID] = self
	
	if self.Owner == Players.LocalPlayer then
		Class.MyTowerChangeEvent:Fire()
	end

	return self
end

function Destroy(towerId)
	local targetTower = Class.collections[towerId]
	if not targetTower then print('id not correct or not exist'); return end
	if targetTower.Destroyed then return end
	targetTower.Destroyed = true
	
	Class.DespawnTowerEvent:Fire(targetTower.Owner, targetTower.Id, targetTower.GridXY, targetTower.Shape)
	Deconstruct(targetTower)

	if targetTower.Owner == Players.LocalPlayer then
		Class.MyTowerChangeEvent:Fire()
	end
	-- Class.MyTowerUpdate:Fire()
end

-- 角色进入攻击范围时
function Class:AddCharacter(character)
	if self.Characters.Links[character] ~= nil then return end
	self.Characters:InsertBack(character)
	character.Towers:InsertBack(self)
	if self.Enter then shared.Thread:Spawn(self.Enter, self, character) end
	if self.Action and self.ActionTask == nil then Action(self) end
end
-- 角色退出攻击范围时
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
	
	----  根据服务端传来的waypointindices设置防御塔的攻击范围
	for index = 1, #waypointIndices, 2 do
		local enterWaypoint = shared.Path.Paths[shared.PlayerDataHandler.GetCurPath()].Waypoints[waypointIndices[index]]
		local exitWaypoint = shared.Path.Paths[shared.PlayerDataHandler.GetCurPath()].Waypoints[waypointIndices[index + 1]]
		
		--- 对已经在防御塔范围的敌人执行攻击逻辑
		for index = exitWaypoint.Index, enterWaypoint.Index, -1 do
			local characters = shared.Path.Paths[shared.PlayerDataHandler.GetCurPath()].Waypoints[index].Characters
			local characterlink = characters.Next
			while characterlink ~= characters do
				self:AddCharacter(characterlink.Value)
				characterlink = characterlink.Next
			end
		end
		
		--- 对将来进入或退出防御塔范围的敌人连接或断开攻击逻辑
		table.insert(self.Connection, enterWaypoint.CharacterAdded:Connect(self.AddCharacter, self))
		table.insert(self.Connection, exitWaypoint.CharacterRemoved:Connect(self.RemoveCharacter, self))
	end
end

function Deconstruct(self)
	Class.collections[self.Model] = nil
	Class.collections[self.Id] = nil 
	Class.collections[self.UID] = nil

	if self.Owner == game:GetService('Players').LocalPlayer then
		towerPlacements[self.UID] -= 1
		if towerPlacements[self.UID] < 0 then warn('error tower placements') end
		myTowers[self.UID] = nil
	end
	
	if self.Exit then
		local characterlink = self.Characters.Next
		while characterlink ~= self.Characters do
			self:RemoveCharacter(characterlink.Value)
			characterlink = characterlink.Next
		end
	end
	
	for _, connection in self.Connection do connection:Disconnect(); connection = nil end
	if self.ActionTask then self.ActionTask:Remove() end

	for index, tower in ipairs(TowerList) do
		if tower == self then
			table.remove(TowerList, index)
			break
		end
	end

	self.Model:Destroy()
end

function Action(self)
	if self.Characters.Length == 0 then
		self.ActionTask = nil
	else
		self.ActionTask = shared.Task:Delay(self.ActionDelay, Action, self)
		shared.Thread:Spawn(self.Action, self)
	end
end

--#region 动画优化
function Class:IsInView(camera)
	if self.Destroyed then return false end
	if not camera then return false end

	local position = self.Position
	if (camera.CFrame.Position - position).Magnitude > VIEW_DISTANCE then return false end

	local _, onScreen = camera:WorldToScreenPoint(position)
	return onScreen
end
function Class:SetAnimationsActive(active)
	if self.IdleAnimationTrack then
		if active then self.IdleAnimationTrack:Play() else self.IdleAnimationTrack:Stop() end
	end
	if self.WingAnimationTrack then
		if active then self.WingAnimationTrack:Play() else self.WingAnimationTrack:Stop() end
	end
	if self.AttackAnimationTrack and not active and self.AttackAnimationTrack.IsPlaying then
		self.AttackAnimationTrack:Stop()
	end
end
function Class:PlayAttack()
	if self.InView and self.AttackAnimationTrack then
		self.AttackAnimationTrack:Play()
	end
end
function UpdateAnimationVisibility()
	while true do
		local camera = workspace.CurrentCamera
		for _, tower in ipairs(TowerList) do
			if tower.Destroyed then continue end

			local inView = tower:IsInView(camera)
			if inView ~= tower.InView then
				tower.InView = inView
				tower:SetAnimationsActive(inView)
			end
		end
		task.wait(0.25)
	end
end
--#endregion

function Class.GetPlacementsByUID(uid)
	local placements = towerPlacements[uid]
	if placements == nil then return end

	return placements
end	

function Class.GetByUID(uid)
	local tower = Class.collections[uid]
	if tower == nil then warn('tower not found in tower module'); return end

	return tower
end

function Class.GetMyTowers()
	return myTowers
end

function CheckAlienMerge(_, tool)
	local towerUID = tool:GetAttribute('TowerUID')
	local lvl = TowerData.GetLvlByTowerUID(towerUID)
	if lvl == TowerData.MAXLEVEL then return end
	for k, v in Class.collections do
		if v.Owner == Players.LocalPlayer and v.TowerUID == towerUID then
			tool:SetAttribute('TargetId', v.Id)

			shared.UIHandler.MergeBtn.Visible = true
			shared.VFXHandler.CreateMergeBeam('AlienMerge', tool, v.Model)
			break;
		end
	end
end

function StartPlayerTowerAction(player, pathId)
	if player ~= Players.LocalPlayer then
		if VisualTask[player] then
			task.cancel(VisualTask[player])
			VisualTask[player] = nil 
		end

		if Class.rng == nil then Class.rng = Random.new() end
		VisualTask[player] = task.spawn(function()
			while true do
				local played = {}
				for _, v in pairs(Class.collections) do
					if v.PathId == pathId then
						if played[v.Id] then continue end
						played[v.Id] = true
						task.delay(Class.rng:NextNumber(0, 2), function()
							v:PlayAttack()
						end)
					end
				end

				task.wait(2)
			end
		end)

	end	
end
function StopPlayerTowerAction(player, pathId)
	if player ~= Players.LocalPlayer then
		if VisualTask[player] then
			task.cancel(VisualTask[player])
			VisualTask[player] = nil 
		end
	end	
end

return Class
