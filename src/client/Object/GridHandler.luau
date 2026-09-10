local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local InitAfterData, ModelInit, ResetHealthBar, ModifyHealthBar, TowerPlacementInit, UpdateDPS = nil
local SIZE_CELL= 5
local self : any = {GhostX = nil, GhostY = nil, GhostCells = {}, GhostShape = nil, GridToWorld = nil, SpawnArea = nil, Cells = {}, Initiated = false}
local Grid : any = {}

function self.init()
end

function self.start()
    shared.Tower.SpawnTowerEvent:Connect(self.SpawnCell, self)
    shared.Tower.SpawnTowerEvent:Connect(self.SpawnPlayerCell, self)
    -- shared.Tower.MyTowerChangeEvent:Connect(UpdateDPS)
    shared.Tower.DespawnTowerEvent:Connect(self.DespawnCell, self)
    shared.Tower.DespawnTowerEvent:Connect(self.DespawnCell, self)
    -- shared.Game.GameStartedEvent:Connect(ResetHealthBar)
    shared.Game.GameEndedEvent:Connect(function() self.HealthFrame.Visible = false end)
    ReplicatedStorage.Remote.Game.HealthReset.OnClientEvent:Connect(ResetHealthBar)
    ReplicatedStorage.Remote.Game.HealthModify.OnClientEvent:Connect(ModifyHealthBar)
    ReplicatedStorage.Remote.PlayerUpgradeGrid.OnClientEvent:Connect(function() 
        local curPath = tostring(shared.PlayerDataHandler.GetCurPath())
	    self.SpawnArea = workspace:WaitForChild('Platforms'):WaitForChild(curPath):WaitForChild('Platform')
    end)
    
    shared.ObjectPool.Create('Cell', ReplicatedStorage.Assets.Parts.Cell, 70, 'Cell')
    
    InitAfterData()
end

function self.SpawnCell(_, plr, towerUID, id, gridXY, shapeName)
    if plr ~= game:GetService('Players').LocalPlayer then return end

    local model = Instance.new('Model')
    model.Parent = workspace
    for _, offset in ipairs(shared.ShapeData[shapeName].Cells) do
        local x = gridXY[1] + offset[1]
        local y = gridXY[2] + offset[2]
        local worldPos = self.GridToWorld(x, y)

        local cell = shared.ObjectPool.Get('Cell')
        cell.CFrame = worldPos
        cell.Color = Color3.fromRGB(163, 162, 165)
        cell.Parent = model

        self.Cells[id] = model
    end

    local highlight = ReplicatedStorage.Assets.Parts.CellHighlight:Clone()
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    local rgb = TowerData.GetRGBByTowerUID(towerUID)
    highlight.FillColor = rgb
    highlight.OutlineColor = rgb
    highlight.Adornee = model
    highlight.Parent = model
end
function self.SpawnPlayerCell(_, plr, towerUID, id, gridXY, shapeName, _, cframe)
    if plr == game:GetService('Players').LocalPlayer then return end

    local model = Instance.new('Model')
    model.Parent = workspace

    for _, offset in ipairs(shared.ShapeData[shapeName].Cells) do
        local offsetX = offset[1]
        local offsetY = offset[2]

        -- 根据传入CFrame计算偏移位置
        local cellCFrame = cframe * CFrame.new(
            offsetX * SIZE_CELL,
            0,
            offsetY * SIZE_CELL
        )

        local cell = shared.ObjectPool.Get('Cell')
        cell.CFrame = cellCFrame
        cell.Color = Color3.fromRGB(163, 162, 165)
        cell.Parent = model
    end

    self.Cells[id] = model

    local highlight = ReplicatedStorage.Assets.Parts.CellHighlight:Clone()
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded

    local rgb = TowerData.GetRGBByTowerUID(towerUID)
    highlight.FillColor = rgb
    highlight.OutlineColor = rgb
    highlight.Parent = model
end
function self.DespawnCell(_, plr, id, gridXY, shapeName)
    -- if plr ~= game:GetService('Players').LocalPlayer then return end

    if self.Cells[id] == nil then return end

    for _, child in self.Cells[id]:GetChildren() do
        if child:IsA('BasePart') then 
            shared.ObjectPool.Return('Cell', child)
        end
    end

    self.Cells[id]:Destroy()
end

function self.SpawnGhostCell(gridX, gridY, shape)
    if self.GhostX == gridX and self.GhostY == gridY then return end
    self.DespawnGhostCell()
    self.GhostX = gridX; self.GhostY = gridY

    local canPlace = self.CanPlace(shape, gridX, gridY)
    for _, offset in ipairs(shape) do
        local x = gridX + offset[1]
        local y = gridY + offset[2]
        local worldPos = self.GridToWorld(x, y)

        local cell = shared.ObjectPool.Get('Cell')
        cell.CFrame = worldPos
        if canPlace then cell.Color = Color3.fromRGB(75, 226, 15) else cell.Color = Color3.fromRGB(214, 13, 13) end

        table.insert(self.GhostCells, cell)
    end
end
function self.DespawnGhostCell()
    for _, cell in self.GhostCells do
        shared.ObjectPool.Return('Cell', cell)
    end
    table.clear(self.GhostCells)
    self.GhostX = nil
    self.GhostY = nil
    self.GhostShape = nil
end
function self.GridToWorld(gridX, gridY)
    local localX = (gridX - 0.5) * SIZE_CELL - self.SpawnArea.Size.X / 2
    local localZ = (gridY - 0.5) * SIZE_CELL - self.SpawnArea.Size.Z / 2

    -- local vector3 = self.SpawnArea.CFrame:PointToWorldSpace(
    --     Vector3.new(localX, 0.75, localZ)
    -- )

    -- return CFrame.new(vector3 * self.SpawnArea.Orientation)

    return self.SpawnArea.CFrame * CFrame.new(localX, 0.75, localZ)
end
function self.GetGridXYByRayhitPos(pos)
    local localPos = self.SpawnArea.CFrame:PointToObjectSpace(pos)
    local startX = localPos.X + self.SpawnArea.Size.X / 2
    local startZ = localPos.Z + self.SpawnArea.Size.Z / 2

    local gridX = math.floor(startX / SIZE_CELL) + 1
    local gridY = math.floor(startZ / SIZE_CELL) + 1

    -- print(gridX, gridY)
    return gridX, gridY
end
function self.CanPlace(shape, baseX, baseY)

    for _, offset in ipairs(shape) do

        local x = baseX + offset[1]
        local y = baseY + offset[2]

        -- 越界
        if x < 1 or x > Grid.Width then
            return false
        end

        if y < 1 or y > Grid.Height then
            return false
        end

        -- 已占用
        if Grid.Cells[x][y] ~= 0 then
            return false
        end
    end

    return true
end
function self.GetUIDByGrid(gridX, gridY)
    -- print('x, y : ', gridX, gridY)
    local chk = Grid.Cells[gridX]
    chk = chk and chk[gridY]
    if chk == nil then return end
    local uid = Grid.Cells[gridX][gridY] 
    if uid == 0 then return end

    return uid
end

function InitAfterData()
	task.spawn(function()
		while true do
			if shared.PlayerDataHandler.InitData == true then break end
			task.wait(.5)
		end

        Grid = shared.PlayerDataHandler.GetData().Grid
        local curPath = tostring(shared.PlayerDataHandler.GetCurPath())
	    self.SpawnArea = workspace:WaitForChild('Platforms'):WaitForChild(curPath):WaitForChild('Platform')
        self.Area = workspace:WaitForChild('SceneLogic'):WaitForChild('Areas'):WaitForChild(curPath)
        self.GachaMachine = workspace:WaitForChild('SceneLogic'):WaitForChild('GachaMachine'):WaitForChild('Machine' .. tostring(curPath))
        self.HealthFrame = self.Area.HealthGui:WaitForChild('HealthFrame')
        self.DPSGui = self.Area.DPSGui
        self.DPSGui.DPS.Text = 0
        self.DPSGui.Enabled = true
        
        ModelInit(self)
        TowerPlacementInit(shared.PlayerDataHandler.GetData())
        
        self.Initiated = true
	end)
end

function TowerPlacementInit(playerData)
    while true do
        if shared.Path.Initiated == true and self.SpawnArea ~= nil then break end
        task.wait(.1)
	end

    for k, v in pairs(playerData.Tower.Inv) do
        if v.GridXY == nil then continue end
        local towerStaticData = TowerData.GetData(v.TowerUID)
        ReplicatedStorage.Remote.Tower.TowerSpawn:FireServer(v.UID, towerStaticData.DisplayName, self.GridToWorld(v.GridXY[1], v.GridXY[2]), v.TowerUID, v.GridXY, towerStaticData.Shape)
    end
end

function ResetHealthBar()
	self.HealthFrame.Visible = true
    self.Health = 100
    self.HealthFrame.Health.Text = string.format('%d/100', self.Health)
    self.HealthFrame.InnerFrame.Size = UDim2.new(.5, 0, 1, 0)
	TweenService:Create(self.HealthFrame.InnerFrame, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 1, 0)
	}):Play()
end
function ModifyHealthBar(amount)
	-- print(amount)
    self.HealthFrame.Health.Text = string.format('%d/100', amount)
	local conn = TweenService:Create(self.HealthFrame.InnerFrame, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Size = UDim2.new(amount / self.Health, 0, 1, 0)
	})
	conn:Play()

	if amount <= 0 then self.HealthFrame.Visible = false end
end

function ModelInit(self)
    local buyTrigger = ReplicatedStorage.Assets.Parts.BuyTrigger
    for _, v in buyTrigger:GetDescendants() do if v:IsA('Script') then v.Enabled = true  end end
    buyTrigger:PivotTo(self.Area.BuyPos.WorldCFrame)
    buyTrigger.Parent = workspace
    self.UpgradeModel = ReplicatedStorage.Assets.Parts.Upgrade
    self.UpgradeModel:PivotTo(self.Area.UpgradePos.WorldCFrame)
    self.UpgradeModel.Parent = workspace
    self.TaskModel = ReplicatedStorage.Assets.Parts.Task
    self.TaskModel:PivotTo(self.Area.TaskPos.WorldCFrame)
    self.TaskModel.Parent = workspace
    local gachaZone = ReplicatedStorage.Assets.Parts.GachaTriggerPart
    gachaZone:PivotTo(CFrame.new(self.GachaMachine.Roll.Position))
    gachaZone:FindFirstChildOfClass('Script').Enabled = true
    gachaZone.Parent = workspace
end

return self
