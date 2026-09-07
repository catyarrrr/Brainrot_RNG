local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = game:GetService('ReplicatedStorage')

local VFXHandler = require(script.Parent.VFXHandler)
local TowerData = require(rs.Datas.TowerData :: ModuleScript)

local self = {}

function self.init()
	self.CurrentTower = nil
	self.SpawnEvent = shared.Event.new()
	self.DespawnEvent = shared.Event.new()
	self.UpgradeEvent = shared.Event.new()
	self.FailEvent = shared.Event.new()
	self.EstimateEvent = shared.Event.new()
	self.EstimateResultEvent = shared.Event.new()
end

function self.start()
	self.SpawnEvent:Connect(SpawnTower, self)
	self.DespawnEvent:Connect(DespawnTower, self)
	self.EstimateEvent:Connect(EstimateTower, self)
	rs.Remote.Tower.Estimate.OnClientEvent:Connect(function(...)
		self.EstimateResultEvent:Fire(...)
	end)
	-- self.UpgradeEvent:Connect(UpgradeTower, self)
end

-- 请求服务器生成tower
function SpawnTower(self, towerData, curGrid, uid)
	-- if raycastHit == nil then return end
	local spawnable = true
	local text = ''
	-- if game.CollectionService:HasTag(raycastHit.Instance, 'Path') == true then spawnable = false; text = 'Can Not Spawn Tower Here' end

	if spawnable then
		local gridX, gridY = shared.VFXHandler.CurGrid[1], shared.VFXHandler.CurGrid[2]
		local cframe = shared.GridHandler.GridToWorld(gridX, gridY)
		rs.Remote.Tower.TowerSpawn:FireServer(uid, towerData.DisplayName, cframe, towerData.TowerUID, {gridX, gridY}, towerData.Shape)

	else
		shared.UIHandler.Warn(text)
		shared.SoundHandler:Play('AlienPlace_Fail')
	end
end

-- 请求服务器估价
function EstimateTower(self)
	rs.Remote.Tower.Estimate:FireServer()
end

-- 请求服务器销毁tower
function DespawnTower(self, towerId)
	local tower = shared.Tower.collections[towerId]
	
	if game.Players.LocalPlayer ~= tower.Owner then return end
	
	rs.Remote.Tower.TowerDespawn:FireServer(towerId)
end

-- 请求服务器升级tower
function self.UpgradeTower(towerId)
	local tower = shared.Tower.collections[towerId]
	tower.Upgraded = true

	if game.Players.LocalPlayer ~= tower.Owner then return end
	
	if TowerData[tower.UID].Level[tower.Level + 1] ~= nil then
		--- 能升级时
		
		---------- 金币校验
		--local cost = math.floor(tower.Cost * (tower.UpgradeRate ^ tower.Level))
		-- local cost = tower.UpgradeCost
		-- local leaderstats = game.Players.LocalPlayer:WaitForChild('leaderstats')
		-- local gold = leaderstats.Gold
		-- if gold.Value - cost < 0 then
		-- 	--self.FailEvent:Fire()
		-- 	--shared.UIHandler.Warn('Not Enough Gold')
		-- 	return false
		-- end
		----------

		shared.VFXHandler.PlayParticleEvent:Fire('TowerUpgradeParticle', tower.Model.Circle.Position, 10)
		shared.UIHandler.UpdateTowerDetailInfo(TowerData.GetData(tower.UID, tower.Level + 1), tower.Level + 1)
		
		return true
	end
	
	return false
end

function self.InitTowerModel(towerUID, model)
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

return self