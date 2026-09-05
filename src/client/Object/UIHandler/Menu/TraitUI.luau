local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TraitData = require(ReplicatedStorage.Datas.TraitData :: ModuleScript)
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local TriggerSelectFrame, SetTrait = nil
local self : any = {}

function self.Init(frame)
	self.Main = shared.Frame.new(frame.Menu.TraitMachine)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.SelectFrame = self.Main.Frame.Select
    self.SelectFrame.Visible = false
    self.Index = self.Frame.Index
    self.Index.Visible = true
    self.ScrollingFrame = self.SelectFrame.ScrollingFrame
    self.ShardCountLabel = self.Frame.ShardCount
    self.SelectBtn = self.Frame.SelectBtn
    self.SlotTemplate = self.Frame.Slot
    self.CashLabel = self.Frame.RollBtn.CashCount.CashCountText
    self.TraitLabelFolder = self.Frame.Traits
    self.SwitchBtn = self.Index.x10Roll.SwitchBtn
    self.CostLabel = self.Frame.x10ShardCount
    self.TraitsSwitch = {}
    for _, child in self.Index.Traits:GetChildren() do
        if child:GetAttribute('IsSwitch') and child:GetAttribute('IsSwitch') == true then
            table.insert(self.TraitsSwitch, child)
        end
    end
    self.SetX10(false)
    self.SwitchBtn.MouseButton1Click:Connect(function()
        self.SetX10(not self.IsX5)
    end)

    self.Frame.Tab.TraitShards9.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.x1Trait)
    end)
    self.Frame.Tab.TraitShards79.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.x10Trait)
    end)
    self.Frame.Tab.TraitShards199.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.x25Trait)
    end)
    self.Frame.Tab.TraitShards799.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.x100Trait)
    end)

    self.Frame.ConfirmBtn.MouseButton1Click:Connect(function()
        if self.Selected then
            shared.SoundHandler:Play('UI_Success')
            self.Selected = nil
            self.Update(shared.PlayerDataHandler.GetData())
        end
    end)
    self.Frame.RollBtn.MouseButton1Click:Connect(function()
        if self.Selected then
            ReplicatedStorage.Remote.Tower.RollTrait:FireServer(self.Selected, self.IsX5)
        end
    end)
    self.Frame.SelectBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        TriggerSelectFrame()
    end)
    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        self:Close()
    end)
    self.SelectFrame.Title.Close.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self.SelectFrame.Visible = false
        self.Selected = nil
        self.Update(shared.PlayerDataHandler.GetData())
    end)

    
end

function self.Update(playerData)
    local traitCount = playerData.Item.Inv[tostring(shared.Config.TRAIT_ID)] or 0

    if self.Frame:FindFirstChild('AlienSlot') then
        self.Frame.AlienSlot:Destroy()
    end
    self.ShardCountLabel.Text = string.format('%d', traitCount)
    self.CashLabel.Visible = false
    self.SelectBtn.Visible = true
    self.TraitEmitter = self.Frame.TraitEmitter.ParticleEmitter
    SetTrait(0)

    if self.Selected then
        local towerData = playerData.Tower.Inv[self.Selected]
        if towerData == nil then warn('towerdata not found in player bp'); return end
        local trait = towerData.Trait
        local towerStaticData = TowerData.GetData(towerData.TowerUID)
        if towerStaticData == nil then return end
        
        self.SelectBtn.Visible = false
        self.CashLabel.Visible = true
        local qualityData = TowerData.GetQualityDictByTowerUID(towerData.TowerUID)
        if qualityData == nil then return end
        local slot = shared.TowerListHelper.GetSlotByStaticData(towerStaticData, trait)
        slot.Size = self.SlotTemplate.Size
        slot.Position = self.SlotTemplate.Position
        slot.MouseButton1Click:Connect(function()
            shared.SoundHandler:Play('UI_Success')
            TriggerSelectFrame()
        end)
        slot.Name = 'AlienSlot'
        slot.Parent = self.Frame

        -- self.TraitCountLabel.Text = string.format('x%d - <font color="rgb(255,0,0)">%d</font>', traitCount, qualityData.TraitCost[2])
        self.CashLabel.Text = string.format('$%s', shared.Tool.FormatNumber(qualityData.TraitCost[1]))

        SetTrait(trait)
    end
end

function self.SetX10(IsX5)
    self.IsX5 = IsX5
    for _, v in self.TraitsSwitch do
        v.Visible = not IsX5
    end
    self.CostLabel.Visible = IsX5
    if self.SwitchBtn:FindFirstChild('On') then self.SwitchBtn:FindFirstChild('On').Visible = IsX5 end
    if self.SwitchBtn:FindFirstChild('Off') then self.SwitchBtn:FindFirstChild('Off').Visible = not IsX5 end
end

function self.Trait(playerData)
    for k, v in self.SlotTemplate:GetChildren() do
        if v:IsA('Configuration') then
            v:SetAttribute('Enabled', true)
        end
    end

    task.spawn(function()
        for i = 1, 4 do
            shared.SoundHandler:Play('Trait_Inhale')
            task.wait(.5)
        end
    end)
    SetTrait(nil)

    task.wait(2)

    for k, v in self.SlotTemplate:GetChildren() do
        if v:IsA('Configuration') then
            v:SetAttribute('Enabled', false)
        end
    end
    shared.SoundHandler:Play('Trait_Result')
    self.TraitEmitter.Emit:Fire(10)
    self.Update(playerData)
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Selected = nil
    self.Main:TweenClose()
end

function TriggerSelectFrame()
    local playerData = shared.PlayerDataHandler.GetData()
    if playerData == nil then return end
    local playerInv = playerData.Tower.Inv

    self.SelectFrame.Visible = true
    
    for _, slot in self.ScrollingFrame:GetChildren() do
        if slot:IsA('ImageButton') then
            slot:Destroy()
        end
    end

    local sortedData = shared.TowerListHelper.GetSortedTowerTable(playerInv)
    for _, tower in sortedData do
        if tower.GridXY ~= nil then continue end
        if tower.Cloning then continue end
        if tower.IsEvolving then continue end
        local towerStaticData = TowerData.GetData(tower.TowerUID)
        local slot = shared.TowerListHelper.GetSlotByStaticData(towerStaticData, tower.Trait)
        slot.MouseButton1Click:Connect(function()
            self.Selected = tower.UID
            self.Update(playerData)
            self.SelectFrame.Visible = false

            shared.SoundHandler:Play('UI_Success')
        end)

        slot.Parent = self.ScrollingFrame
    end
end
function SetTrait(traitId)
    for _, v in self.TraitLabelFolder:GetChildren() do
        if v:IsA('TextLabel') then
            v.Visible = false
        end
    end

    local label = self.TraitLabelFolder:FindFirstChild(tostring(traitId))
    if label == nil then return end

    label.Visible = true
end

return self
