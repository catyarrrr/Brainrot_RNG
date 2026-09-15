local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local QuickZone = require(ReplicatedStorage.QuickZone :: ModuleScript)
local LevelData = require(ReplicatedStorage.Datas.LevelData :: ModuleScript)
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local HEIGHT_ORI, HEIGHT_HIDDEN = 2, -100
local Class = {collections = {}, Initiated = nil}
Class.__index = Class

function Class.init()
	Class.EnterEvent = shared.Event.new()
	Class.ExitEvent = shared.Event.new()
	Class.UpgradeEvent = shared.Event.new()
	Class.NextMapEvent = shared.Event.new()
	Class.PrayEvent = shared.Event.new()
end

function Class.start()
	Class.EnterEvent:Connect(function(Class, pathId, data, player)
		while Class.Initiated == nil do
			task.wait()
		end
		Class.collections[pathId]:Enter(data, player)
	end, Class)
	Class.ExitEvent:Connect(function(Class, pathId)
		while Class.Initiated == nil do
			task.wait()
		end
		Class.collections[pathId]:Reset()
	end, Class)
	Class.PrayEvent:Connect(function(Class, player)
		while Class.Initiated == nil do
			task.wait()
		end
		local pathId = shared.DataStore.GetPlayerCurPath(player)
		if pathId == nil then return end

		shared.VFXHandler.EmitParticle(Class.collections[pathId].TotemModel.TriggerEffect, 5)
		
	end, Class)
	Class.UpgradeEvent:Connect(function(Class, pathId)
		while Class.Initiated == nil do
			task.wait()
		end
		Class.collections[pathId]:Upgrade()
	end, Class)
	Class.NextMapEvent:Connect(function(Class, pathId, round, rush)
		while Class.Initiated == nil do
			task.wait()
		end
		local area = Class.collections[pathId]
		local map
		if rush then map = 0 else map = LevelData.GetMapByRound(round) end
		if map == area.Map then return end
		area:SwitchMap(map)
	end, Class)
	shared.Tower.SpawnEvent:Connect(function(_, player, pathId) 
		while Class.Initiated == nil do
			task.wait()
		end

		UpdateDPS(player, pathId)

		local area = Class.collections[pathId]
		if area then area:UpdateCardBoard() end
	end)
	shared.Tower.DespawnEvent:Connect(function(_, player, pathId)
		while Class.Initiated == nil do
			task.wait()
		end

		local area = Class.collections[pathId]
		if area then area:UpdateCardBoard() end
	end)
	shared.Game.GameOverEvent:Connect(function(_, player, pathId, round, rush)
		UpdateAreaBest(player, pathId, round, rush)
	end)
	shared.Game.GameWinEvent:Connect(function(_, player, pathId, round, rush)
		UpdateAreaBest(player, pathId, round, rush)
	end)

	for k, v in workspace.SceneLogic.Areas:GetChildren() do
		Class.new(v)
	end

	Class.Initiated = true

	task.spawn(function()
		while true do
			task.wait(1)
			for _, area in Class.collections do
				area:UpdateCardBoardIncome(true)
			end
		end
	end)
end

function Class.new(model)
	local self = setmetatable({}, Class)

	self.SpawnCF = model.SpawnPos.WorldCFrame
	self.AreaCF = model.AreaPos.WorldCFrame
	self.DPSCF = model.DPSPos.WorldCFrame
	self.MapCF = model.MapPos.WorldCFrame
	self.CardCF = model.CardPos.WorldCFrame
	self.TerritoryCF = model.TerritoryPos.WorldCFrame
	self.TotemCF = model.TotemPos.WorldCFrame
	self.TowerAreaFolder = model.TowerArea
	self.Id = tonumber(model.Name)
	self.OwnerFrame = model.OwnerGui

	local dpsBoard = ServerStorage.DPSBoard:Clone()
	dpsBoard:PivotTo(self.DPSCF)
	dpsBoard.Parent = model
	self.DPSBoard = dpsBoard
	self.DPSGui = dpsBoard:FindFirstChild('SurfaceGui', true)
	self.DPSGui.Enabled = true
	self.DPSGui.DPS.Text = '0'

	-- totem
	-- self.TotemModel = ServerStorage.Totem:Clone()
	-- shared.VFXHandler.DisableParticle(self.TotemModel.TriggerEffect)
	-- self.TotemModel:PivotTo(self.TotemCF)
	-- self.TotemModel.Parent = model
	--

	--#region		CardBoard
	self.CardBoard = ServerStorage.CardBoard:Clone()
	self.CardBoard:PivotTo(self.CardCF)
	self.CardBoard.Parent = model
	self.CardBoardScrollingFrame = self.CardBoard.CardFrame.ScrollingFrame
	self.CardBoardTitle = self.CardBoard.CardTitle
	self.CardBoardIncomeBtn = self.CardBoard.IncomeBtn.TextButton
	local observer = QuickZone.Observer.new()
		:attach(QuickZone.Zone.fromPart(self.CardBoard.TriggerZone))
		:subscribe(QuickZone.Group.players())
	observer:onPlayerEnter(function(player, zone)
		if player == self.Owner then
			self:ClaimCardIncome(player)
		end
	end)
	self.Cards = {}
	self.CardIncome = 0
	--#endregion

	WaitForGachaMachine(self)
	-- print(self.Id)

	self:Reset()

	Class.collections[tonumber(model.Name)] = self

	return self
end

function Class:Enter(data, plr)
	local playerLevel = TempData.GetLevelByGrid(data.Grid)
	if playerLevel == nil then return end

	self:ChangeLevel(playerLevel)
	self:SwitchMap(1)

	if self.Platform then self.Platform:Destroy() end
	local platform = ReplicatedStorage.Assets.Parts.Area:FindFirstChild(tostring(playerLevel)):Clone()
	platform:PivotTo(self.AreaCF)
	platform.Name = 'Platform'
	platform.Parent = workspace.Platforms:WaitForChild(tostring(self.Id))
	self.Platform = platform
	self.Level = playerLevel
	self.Owner = plr
	self.OwnerFrame.Enabled = true
	self.OwnerFrame.OwnerName.Text = self.Owner.DisplayName
	local content, isReady = Players:GetUserThumbnailAsync(
		self.Owner.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size180x180
	)
	if isReady then self.OwnerFrame.OwnerIcon.Image = content end
	self.MaxLevel = data.Profile.MaxLevel
	self.OwnerFrame.BestWave.Text = string.format('Best Wave: %d', self.MaxLevel)
	self.MaxChallenge = data.Profile.MaxChallenge
	self.OwnerFrame.BossChallenge.Text = string.format('Boss Challenge: %d', self.MaxChallenge)

	-- local equippedTotems = {}
	-- if data.Totem then
	-- 	equippedTotems = shared.DataStore.TotemController.GetEquippedSlots(plr)
	-- end
	-- self:UpdateTotem(equippedTotems)

	if self.GachaMachine then
		self.GachaMachine:Enter(plr)
	end

	self:UpdateCardBoard()
	self:SetOfflineCardIncome(data)
end

function Class:SetOfflineCardIncome(data)
	local lastTime = data.States and data.States.LastTime
	if lastTime == nil then return end

	local cardData = TempData.CardDict[data.Profile.CardLevel]
	if cardData == nil then return end

	local offlineSeconds = math.min(os.time() - lastTime, cardData.MaxTime)
	if offlineSeconds <= 0 then return end

	local totalRate = 0
	for _, entry in data.Tower.Inv do
		if entry.GridXY == nil then continue end

		local staticData = TowerData.GetData(entry.TowerUID)
		if staticData == nil then continue end

		totalRate += staticData.Income or 0
	end

	self.CardIncome += totalRate * offlineSeconds

	self:UpdateCardBoardIncome(false)
end

function Class:UpdateCardBoard()
	if self.CardBoardScrollingFrame == nil then return end

	for _, v in self.CardBoardScrollingFrame:GetChildren() do
		if v:IsA('Frame') then
			v:Destroy()
		end
	end
	self.Cards = {}

	local pathTowers = shared.Tower.GetByPathId(self.Id)
	if pathTowers == nil then
		self:UpdateCardBoardIncome(false)
		return
	end

	for _, tower in pathTowers do
		local staticData = TowerData.GetData(tower.TowerUID)
		if staticData == nil then continue end

		local template = ReplicatedStorage.Assets.UI.CardSlot:FindFirstChild('Card' .. staticData.Quality)
		if template == nil then warn('card slot not found for quality:', staticData.Quality); continue end

		local card = template:Clone()
		local asset = AssetsData[TowerData.GetAssetIdByTowerUID(tower.TowerUID)]
		if asset then card.Frame.Label.Icon.Image = asset.Icon end
		card.Frame.Label.NameText.Text = staticData.DisplayName
		card.Parent = self.CardBoardScrollingFrame
		table.insert(self.Cards, { Frame = card, Tower = tower })
	end

	self:UpdateCardBoardIncome(false)
end
function Class:UpdateCardBoardIncome(accumulate)
	local totalRate, delta = 0, 0

	local maxTime
	if accumulate and self.Owner then
		local playerData = shared.DataStore.GetData(self.Owner)
		local cardData = playerData and TempData.CardDict[playerData.Profile.CardLevel]
		if cardData then maxTime = cardData.MaxTime end
	end

	for _, entry in self.Cards do
		local staticData = TowerData.GetData(entry.Tower.TowerUID)
		if staticData == nil then continue end

		local income = staticData.Income or 0
		local before = entry.Tower.CardIncome or 0
		if accumulate then
			local cap = math.huge
			if maxTime then cap = income * maxTime end
			entry.Tower.CardIncome = math.min(before + income, cap)
		end
		local accumulated = entry.Tower.CardIncome or 0
		delta += accumulated - before

		totalRate += income

		local mutations = entry.Frame.Frame.Label.Mutations
		local mutId = TowerData.GetMutIdByTowerUID(entry.Tower.TowerUID)
		for _, label in mutations:GetChildren() do
			if label:IsA('TextLabel') then
				label.Visible = label.Name == tostring(mutId)
			end
		end
		local mutLabel = mutId and mutations:FindFirstChild(tostring(mutId))
		if mutLabel then
			mutLabel.Text = string.format('%s ($%s/s)', shared.Tool.FormatNumber(accumulated), shared.Tool.FormatNumber(income))
		end
	end

	if accumulate then
		self.CardIncome += delta
	end

	if self.CardBoardIncomeBtn then
		self.CardBoardIncomeBtn.Text = '$'  .. shared.Tool.FormatNumber(self.CardIncome)
	end
	if self.CardBoardTitle then
		self.CardBoardTitle.TextLabel.Text = string.format('Total %s/s', shared.Tool.FormatNumber(totalRate))
	end
end
function Class:ClaimCardIncome(player)
	if player ~= nil and self.Owner ~= player then return end

	local amount = self.CardIncome
	if amount <= 0 then return end

	for _, entry in self.Cards do
		entry.Tower.CardIncome = 0
	end
	self.CardIncome = 0
	self:UpdateCardBoardIncome(false)

	local owner = player or self.Owner
	shared.DataStore.CoinController.CardIncome(owner, amount)
	ReplicatedStorage.Remote.CardIncome:FireClient(owner, self.CardBoard.TriggerZone.Position, amount)

	return amount
end

function Class:SwitchMap(id)	--切换关卡
	local map = ServerStorage.Map:FindFirstChild(tostring(id))
	if map == nil then warn('map not found for id:', id); return end

	local curMap = workspace.Area.Map:FindFirstChild(tostring(self.Id))
	if curMap then curMap:Destroy() end
	self.Map = id


	map = map:Clone()
	map.Name = tostring(self.Id)
	map:PivotTo(self.MapCF)
	map.Parent = workspace.Area.Map
end

function Class:Upgrade()
	if self.Level == nil then return end
	local nextLevel = self.Level + 1
	local template = ReplicatedStorage.Assets.Parts.Area:FindFirstChild(tostring(nextLevel))
	if template == nil then warn('area upgrade error for nextlevel:', nextLevel); return end

	self.Platform:Destroy()
	self:ChangeLevel(nextLevel)

	local clone = template:Clone()
	clone:PivotTo(self.AreaCF)
	clone.Name = 'Platform'
	clone.Parent = workspace.Platforms:WaitForChild(tostring(self.Id))
	
	self.Platform = clone
	self.Level = nextLevel
end
function Class:ChangeLevel(tarLevel)
	for _, area in self.TowerAreaFolder:GetChildren() do
		local level = string.match(area.Name, 'a(%d+)$')
		level = tonumber(level)
		-- print(level)

		local pivot = area:GetPivot()
		local pos = pivot.Position
		if level == tarLevel then
			area:PivotTo(CFrame.new(pos.X, HEIGHT_ORI, pos.Z) * pivot.Rotation)
		else
			area:PivotTo(CFrame.new(pos.X, HEIGHT_HIDDEN, pos.Z) * pivot.Rotation)
		end
	end
end

function Class:UpdateTotem(equippedTotems)
	local totemFolder = self.TotemModel:FindFirstChild('Totem')
	if totemFolder == nil then return end

	-- 兼容旧调用：传入单个图腾数据
	if type(equippedTotems) == 'table' and equippedTotems.TotemUID ~= nil then
		equippedTotems = { [1] = equippedTotems }
	elseif type(equippedTotems) ~= 'table' then
		equippedTotems = {}
	end

	-- 主显示（槽位1）用于图腾层级堆叠
	local level = 1
	local tarData = equippedTotems[1]
	if type(tarData) == 'table' then
		local staticData = TotemData.GetData(tarData.TotemUID)
		if staticData ~= nil then
			level = TotemData.GetTotemLevel(tarData.Point)
		end
	end

	if self.TotemOffsets == nil then
		self.TotemOffsets = {}
		for _, layer in totemFolder:GetChildren() do
			if string.match(layer.Name, '^TotemLayer%d+$') then
				self.TotemOffsets[layer] = self.TotemCF:ToObjectSpace(layer:GetPivot())
			end
		end
	end

	for _, layer in totemFolder:GetChildren() do
		local num = tonumber(string.match(layer.Name, '^TotemLayer(%d+)$'))
		if num ~= nil then
			local base = self.TotemCF * self.TotemOffsets[layer]
			if num <= level then
				layer:PivotTo(base)
			else
				layer:PivotTo(base * CFrame.new(0, HEIGHT_HIDDEN, 0))
			end
		end
	end

	local layer1 = totemFolder:FindFirstChild('TotemLayer1')
	if layer1 == nil then return end

	--	三个装备槽位的图腾显示：Equipped / Equipped1 / Equipped2
	local slotNames = { [1] = 'Equipped', [2] = 'Equipped1', [3] = 'Equipped2' }
	for slot = 1, 3 do
		local target = layer1:FindFirstChild(slotNames[slot])
		if target == nil then continue end

		local slotData = equippedTotems[slot]
		local staticData = type(slotData) == 'table' and TotemData.GetData(slotData.TotemUID) or nil

		local icon = target:FindFirstChild('Icon')
		if icon then icon.Image = staticData and staticData.MainIcon or '' end

		local totemName = target:FindFirstChild('TotemName')
		if totemName then
			totemName.Text = staticData and (TotemData.Type[staticData.MainType] or '') or ''
		end
	end
end

function Class:Reset()
	self.OwnerFrame.Enabled = false
	self.DPSGui.DPS.Text = '0'

	--	platform位置重置
	for _, area in self.TowerAreaFolder:GetChildren() do
		local level = string.match(area.Name, 'a(%d+)$')
		level = tonumber(level)
		-- print(level)

		local pivot = area:GetPivot()
		local pos = pivot.Position
		if level == 1 then
			area:PivotTo(CFrame.new(pos.X, HEIGHT_ORI, pos.Z) * pivot.Rotation)
		else
			area:PivotTo(CFrame.new(pos.X, HEIGHT_HIDDEN, pos.Z) * pivot.Rotation)
		end
	end

	if self.GachaMachine then self.GachaMachine:Reset() end

	-- self:UpdateTotem(nil)

	for k, v in self.CardBoardScrollingFrame:GetChildren() do
		if v:IsA('Frame') then
			v:Destroy()
		end
	end
	self.Cards = {}
	self.CardIncome = 0
	self:UpdateCardBoardIncome(false)

	self:SwitchMap(1)
	self.Level = nil
	if self.Platform then self.Platform:Destroy() end
end

function UpdateDPS(player, pathId)
	local area = Class.collections[pathId]
	if area == nil then return end
    
	local dps = shared.Tower.GetTotalDPSByPlayer(player)
    area.DPSGui.DPS.Text = shared.Tool.FormatNumber(dps)
end

function UpdateAreaBest(player, pathId, round, rush)
	local area = Class.collections[pathId]
	if area == nil then return end

	if rush then
		if round > area.MaxChallenge then
			area.MaxChallenge = round
			area.OwnerFrame.BossChallenge.Text = string.format('Boss Challenge: %d', area.MaxChallenge)
		end
	elseif round > area.MaxLevel then
		area.MaxLevel = round
		area.OwnerFrame.BestWave.Text = string.format('Best Wave: %d', area.MaxLevel)
	end
end

function WaitForGachaMachine(self)
	while not shared.GachaMachine.Initiated do
		task.wait()
	end

	self.GachaMachine = shared.GachaMachine.Get(self.Id)
end	

return Class