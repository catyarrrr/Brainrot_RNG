local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)

local TriggerSelectFrame = nil
local self : any = {}

local function GetCloneField(slot, field)
    if slot == 2 then return field .. '2' end
    return field
end

function self.Init(frame)
	self.Main = shared.Frame.new(frame.Menu.CloneMachine)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.SelectFrame = self.Main.Frame.Select
    self.SelectFrame.Visible = false
    self.SelectBtn = self.Frame.SelectBtn
    self.TimeBtn = self.Frame.TimeBtn
    self.NormalSlotBtn = self.Frame.Slot1Btn
    self.BasicGradient = self.Frame.AutoRollBG.BasicGradient
    self.PremiumGradient = self.Frame.AutoRollBG.PremiumGradient
    self.PremiumSlotBtn = self.Frame.Slot2Btn
    self.CloneBtn = self.Frame.CloneBtn
    self.ClaimBtn = self.Frame.ClaimBtn
    self.SlotTemplate = self.Frame.SlotTemplate
    self.ItemTemplate = self.Frame.ItemTemplate
    self.CashLabel = self.Frame.CashCount.CashLabel
    self.ScrollingFrame = self.SelectFrame.ScrollingFrame
    self.Tips = self.Frame.Tips
    self.Slot = 1
    self.Lock = self.PremiumSlotBtn.Lock
    self.PremiumSlotRemote = ReplicatedStorage.Remote.Tower.PremiumSlot
    self:UpdateGradient()
    self:UpdateLock(shared.PlayerDataHandler.GetData())

    self.TimeBtn.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas['-50%Time_Clone'])
    end)
    self.Frame.ClaimBtn.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Tower.CompleteClone:FireServer(self.Selected, self.Slot)
    end)
    self.Frame.CloneBtn.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Tower.TowerClone:FireServer(self.Selected, self.Slot)
    end)
    self.Frame.SelectBtn.MouseButton1Click:Connect(function()
        TriggerSelectFrame()
    end)
    self.NormalSlotBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self:SwitchSlot(1)
    end)
    self.PremiumSlotBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self:SwitchSlot(2)
    end)
    self.SelectFrame.Title.Close.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self.SelectFrame.Visible = false
    end)
    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        self:Close()
    end)
end

function self:SwitchSlot(slot)
    if self.Slot == slot then return end

    if slot == 2 then
        local playerData = shared.PlayerDataHandler.GetData()
        if playerData == nil then return end
        if playerData.VIP == nil or playerData.VIP.CloneSlot ~= true then
            local gems = playerData.Coin and playerData.Coin.Gems or 0
            if gems >= shared.Config.CLONE_SLOT_GEM_COST then
                self.PremiumSlotRemote:FireServer()
            else
                shared.UIHandler.ServerWarn('Unlock the Premium Clone Slot with the pass or 100k Gems!')
                shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_CLONESLOT)
                return
            end
        end
    end

    self.Slot = slot
    self.Selected = nil
    self.Countdown = false
    self:UpdateGradient()
    self:PlayGradientRotation()

    local playerData = shared.PlayerDataHandler.GetData()
    if playerData then self.Update(playerData) end
end

function self:UpdateGradient()
    if self.BasicGradient then self.BasicGradient.Enabled = (self.Slot == 1) end
    if self.PremiumGradient then self.PremiumGradient.Enabled = (self.Slot == 2) end
end

function self:UpdateLock(playerData)
    if self.Lock == nil then return end
    local unlocked = playerData ~= nil and playerData.VIP ~= nil and playerData.VIP.CloneSlot == true
    self.Lock.Visible = not unlocked
    if self.PremiumSlotBtn.ONText then self.PremiumSlotBtn.ONText.Visible = unlocked end
end

function self:PlayGradientRotation()
    local gradient = self.Slot == 1 and self.BasicGradient or self.PremiumGradient
    if gradient == nil then return end

    if self.GradientTween then
        self.GradientTween:Cancel()
        self.GradientTween = nil
    end

    gradient.Rotation = 0
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    self.GradientTween = TweenService:Create(gradient, tweenInfo, {Rotation = 360})
    self.GradientTween:Play()
end

function self.Update(playerData)
    self.Countdown = false
    self:UpdateLock(playerData)
    local cloneData = playerData.Tower.Clone
    local sourceUID = cloneData[GetCloneField(self.Slot, 'SourceUID')]
    local endTime = cloneData[GetCloneField(self.Slot, 'EndTime')]

    if sourceUID then
        self.Selected = sourceUID
        self.Cloning = true
        self.CloneBtn.Visible = false
        self.ClaimBtn.Visible = true
    else
        self.CloneBtn.Visible = true
        self.ClaimBtn.Visible = false
    end

    if self.Selected then
        if self.Frame:FindFirstChild('AlienSlot') then self.Frame:FindFirstChild('AlienSlot'):Destroy() end
        if self.Frame:FindFirstChild('ItemSlot') then self.Frame:FindFirstChild('ItemSlot'):Destroy() end
        local towerData = playerData.Tower.Inv[self.Selected]
        if towerData == nil then warn('towerdata not found in player bp'); return end
        local trait = towerData.Trait
        local towerStaticData = TowerData.GetData(towerData.TowerUID)
        if towerStaticData == nil then return end
        local qualityData = TowerData.GetQualityDictByTowerUID(towerData.TowerUID)

        if sourceUID then
            self.Frame.CashCount.Visible = false
            self.StartTick(endTime)
        else
            self.Frame.CashCount.Visible = true

            local time = shared.CalculateData.GetTimeNeededForClone(towerData.TowerUID)
            if time then self.Tips.Text = shared.Tool.FormatTime(time * 60) end
            local cash = shared.CalculateData.GetCashNeededForClone(towerData.TowerUID)
            if cash then  self.CashLabel.Text = string.format('$ %s', shared.Tool.FormatNumber(cash)) end
        end
        
        local shardId = qualityData.Item
        local itemData = ItemData[shardId]
        local itemSlot = ReplicatedStorage.Assets.UI.ItemSlot:FindFirstChild(itemData.Quality):Clone()
        itemSlot.Icon.Image = itemData.Icon
        itemSlot.ItemNameText.Text = itemData.Name
        itemSlot.ItemCountText.Text = 'x ' .. shared.CalculateData.GetItemNeededForClone(towerData.TowerUID)
        itemSlot.Name = 'ItemSlot'
        itemSlot.Position = self.ItemTemplate.Position
        itemSlot.Size = self.ItemTemplate.Size
        itemSlot.Parent = self.Frame

        local slot = shared.TowerListHelper.GetSlotByStaticData(towerStaticData, trait)
        slot.Size = self.SlotTemplate.Size
        slot.Position = self.SlotTemplate.Position
        slot.MouseButton1Click:Connect(function()
            if sourceUID then return end
            shared.SoundHandler:Play('UI_Success')
            TriggerSelectFrame()
        end)
        slot.Name = 'AlienSlot'
        slot.Parent = self.Frame
    else
        if self.Frame:FindFirstChild('AlienSlot') then self.Frame:FindFirstChild('AlienSlot'):Destroy() end
        if self.Frame:FindFirstChild('ItemSlot') then self.Frame:FindFirstChild('ItemSlot'):Destroy() end
        self.Frame.CashCount.Visible = false
        self.Tips.Text = 'Select an alien'
    end
end 

function self.StartTick(endTime)
    if self.CountdownTask then
        task.cancel(self.CountdownTask)
        self.CountdownTask = nil
    end
        
    local remaining = endTime - workspace:GetServerTimeNow()
    if remaining > 0 then
        self.Countdown = true
        self.CountdownTask = task.spawn(function()
            while self.Countdown do
                local r = endTime - workspace:GetServerTimeNow()
                if r <= 0 then
                    self.Tips.Text = 'Clone complete!'
                    self.Countdown = false
                    break
                end
                self.Tips.Text = shared.Tool.FormatTime(r)
                task.wait(1)
            end
        end)
    else
        self.Tips.Text = 'Clone complete!'
    end
end

function self:Open()
    self:UpdateGradient()
    self:UpdateLock(shared.PlayerDataHandler.GetData())
    self.Main:TweenOpen()
end
function self:Close()
    self.Selected = nil
    self.Countdown = false
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
return self
