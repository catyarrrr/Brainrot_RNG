local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local projectileFolder = Instance.new('Folder')
projectileFolder.Name = 'Projectiles'
projectileFolder.Parent = workspace

local projectiles, parts, cFrames, InitProjectile, BeamDestroy, BeamStep = {}, {}, {}, nil

local Class = {}
Class.__index = Class

function Class.init()
	Class.FireEvent = shared.Event.new()
	Class.BeamFireEvent = shared.Event.new()
end

function Class.start()
	shared.Task.PostTick:Connect(BulkMove)
	shared.Game.GameStartedEvent:Connect(InitProjectile)
	shared.Game.GameEndedEvent:Connect(function() shared.ObjectPool.DestroyByTag('TowerProjectile') end)
	Class.FireEvent:Connect(Class.new, Class)
	Class.BeamFireEvent:Connect(Class.newBeam, Class)
end

function Class.new(_, poolName, position, target, ticks)
	local part = shared.ObjectPool.Get(poolName)
	if part == nil then return end
	shared.VFXHandler.ParticleModule.ToggleVisual(part, true)
	local index = #projectiles + 1
	
	local self = setmetatable({}, Class)
	self.PoolName = poolName
	self.Target = target
	self.Index = index
	self.Ticks = ticks 
	self.TotalTicks = ticks 
	self.Position = position
	self.StartPosition = position
	self.Part = part
	self.Part.CFrame = CFrame.lookAt(self.Position, self.Target.Position)
	-- self.Part.Parent = projectileFolder
	self.TickConnection = shared.Task.OnTick:Connect(Step, self)
	
	projectiles[index] = self
	parts[index] = self.Part
	cFrames[index] = self.Part.CFrame
	
	return self
end
function Class.newBeam(_, poolName, position, target, ticks)
	local model = shared.ObjectPool.Get(poolName)
	if model == nil then return end

	local beam1 = model:FindFirstChild("Beam1")
	if beam1 == nil then return end

	-- shared.VFXHandler.ParticleModule.ToggleVisual(model, true)

	local self = setmetatable({}, Class)
	self.PoolName = poolName
	self.Target = target
	self.Ticks = ticks
	self.TotalTicks = ticks
	self.Position = position
	self.StartPosition = position
	self.Model = model
	self.Beam1 = beam1
	self.Model.Beam0:PivotTo(CFrame.new(position))
	self.Model.Beam1:PivotTo(CFrame.new(position))
	self.Beam1OriginalSize = beam1.Size

	self.TickConnection = shared.Task.OnTick:Connect(BeamStep, self)

	return self
end

function Destroy(self)
	self.TickConnection:Disconnect()

	shared.VFXHandler.ParticleModule.ToggleVisual(self.Part, false)
	shared.ObjectPool.Return(self.PoolName, self.Part)
	
	local lastProjectile = table.remove(projectiles)
	if lastProjectile == self then
		table.remove(parts)
		table.remove(cFrames)
	else
		projectiles[self.Index] = lastProjectile
		parts[self.Index] = lastProjectile.Part
		cFrames[self.Index] = lastProjectile.Part.CFrame
		lastProjectile.Index = self.Index
	end
end
function Step(self)
	self.Ticks -= 1
	local t = math.clamp((1 - self.Ticks / self.TotalTicks), 0, 1)
	
	self.Position = self.StartPosition:Lerp(self.Target.Position, t)
	
	if t >= 1 then
		Destroy(self)
	end
end
function BulkMove()
	for index, projectile in projectiles do cFrames[index] = CFrame.new(projectile.Position) end
	workspace:BulkMoveTo(parts, cFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

function BeamDestroy(self)
	-- print('destroy beam')
	self.TickConnection:Disconnect()
	self.Beam1.Size = self.Beam1OriginalSize
	-- shared.VFXHandler.ParticleModule.ToggleVisual(self.Model, false)
	task.wait(.5)
	shared.ObjectPool.Return(self.PoolName, self.Model)
end

function BeamStep(self)
	self.Ticks -= 1
	local t = math.clamp((1 - self.Ticks / self.TotalTicks), 0, 1)

	self.Position = self.StartPosition:Lerp(self.Target.Position, t)
	self.Beam1.CFrame = CFrame.new(self.Position)

	if t >= 1 then
		BeamDestroy(self)
	end
end

function InitProjectile()
	-- print('init particle')
    for _, tower in shared.Tower.collections do
		local selected = {}
		if tower.Owner == Players.LocalPlayer and selected[tower.Id] == nil then
			-- print('ready')
			selected[tower.Id] = true

			local towerType = TowerData.GetTowerTypeByTowerUID(tower.TowerUID)
			if tower.Visual == 1 or tower.Visual == 2 then
				local name = 'BR' .. tostring(towerType) .. 'Projectile'
			
				local template = ReplicatedStorage.Assets.Projectiles:FindFirstChild(name)
				if template == nil then continue end

				shared.VFXHandler.ParticleModule.ToggleVisual(template, true)
				shared.ObjectPool.Create(name, template, nil, 'TowerProjectile')

			elseif tower.Visual == 3 then
				local name = 'BR' .. tostring(towerType) .. 'Beam'
				
				local template = ReplicatedStorage.Assets.Beams:FindFirstChild(name)
				if template == nil then continue end

				shared.VFXHandler.ParticleModule.ToggleVisual(template, true)
				shared.ObjectPool.Create(name, template, 1, 'TowerProjectile')
			end
		end
	end
end


return Class