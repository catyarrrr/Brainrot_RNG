local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)

local TriggerSelectFrame = nil
local self = {Evolving = nil, Selected = nil, EvoPool = nil, CountdownTask = nil, Tips = nil}

function self.Init(frame)
	self.Main = shared.Frame.new(frame.Menu.EvoMachine)
    self.Main:Visible(false)
    
    self.PoolInitiated = false
    self.Frame = self.Main.Frame.Frame
    self.SelectFrame = self.Main.Frame.Select
    self.SelectFrame.Visible = false
    self.EvoPoolFrame = self.Frame.EvoPool
    self.EvoPoolTemplate = self.EvoPoolFrame.ScrollingFrame.Templates
    self.InfoFrame = self.Frame.Info
    self.Item1Template = self.InfoFrame.Item1
    self.Item1Template.Visible = false
    self.Item2Template = self.InfoFrame.Item2
    self.Item2Template.Visible = false
    self.RequireTemplate = self.InfoFrame.RequireTemplate
    self.SelectTemplate = self.InfoFrame.SelectTemplate
    self.NameLabel = self.InfoFrame.NameLabel
    self.TraitLabel = self.InfoFrame.Trait.ONText
    self.QualityLabel = self.InfoFrame.Quality.OFFText
    self.ScrollingFrame = self.SelectFrame.ScrollingFrame
    self.ClaimBtn = self.InfoFrame.ClaimBtn
    self.EvoBtn = self.InfoFrame.EvoBtn
    self.Tips = self.InfoFrame.Tips
    self.CashFrame = self.InfoFrame.CashCost

    
    self.InfoFrame.SelectBtn.MouseButton1Click:Connect(function()
        if self.Evolving then return end
        shared.SoundHandler:Play('UI_Success')
        TriggerSelectFrame()
    end)
    self.InfoFrame.TimeBtn.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas['-50%Time_Evolve'])
    end)
    self.InfoFrame.EvoBtn.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Tower.Evolve:FireServer(self.Selected, self.EvoPool)
    end)
    self.InfoFrame.ClaimBtn.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Tower.CompleteEvolve:FireServer()
    end)

    self.SelectFrame.Title.Close.MouseButton1Click:Connect(function()
        self.Selected = nil
        shared.SoundHandler:Play('UI_Fail')
        self.SelectFrame.Visible = false
    end)
    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        self:Close()
    end)
end

function self.Update(playerData)
    local evoDict = TowerData.GetEvolutionDict()

    if self.PoolInitiated == false then
        for k, v in evoDict do
            local targetStaticData = TowerData.GetData(v.Target)
            local clone = self.EvoPoolTemplate:FindFirstChild(v.Quality):Clone()

            clone.Icon.Image = AssetsData[targetStaticData.AssetId].Icon
            clone.Visible = true
            clone.NameText.Text = targetStaticData.DisplayName
            
            clone.MouseButton1Click:Connect(function()
                if self.Evolving then return end
                self.Selected = nil
                self.Fresh(shared.PlayerDataHandler.GetData(), k)
            end)
            clone.Parent = self.EvoPoolFrame.ScrollingFrame
        end
        self.PoolInitiated = true
        self.Fresh(playerData, 1)
    else
        self.Fresh(playerData, nil)
    end

end

function self.Fresh(playerData, key)
    local evolveData = playerData.Tower.Evolve
    local evoDict = TowerData.GetEvolutionDict()
    local curDict = evoDict[self.EvoPool]
    if evolveData.SourceUID then
        self.Selected = evolveData.SourceUID
        self.Evolving = true
        self.EvoBtn.Visible = false
        self.ClaimBtn.Visible = true
    else
        self.Evolving = false
        self.EvoBtn.Visible = true
        self.ClaimBtn.Visible = false
    end

    if key ~= nil and key ~= self.EvoPool then
        for k, v in self.InfoFrame:GetChildren() do
            if v.Name == 'Temp' then v:Destroy() end
        end
        self.EvoPool = key
        curDict = evoDict[self.EvoPool]
    
        local needHeroStatic = TowerData.GetData(curDict.NeedHero)
        local levelNeeded = TowerData.GetLvlByTowerUID(curDict.NeedHero)
        local slot = shared.TowerListHelper.GetSlotByStaticData(needHeroStatic)
        slot.Size = self.RequireTemplate.Size
        slot.Position = self.RequireTemplate.Position
        slot.NameText.Text = string.format('required Lv.%d', levelNeeded)
        slot.Name = 'Temp'
        slot.Parent = self.InfoFrame
    
        --#region 所需物品刷新
        local cot = 1
        for k, v in curDict.NeedItems do
            local itemData = ItemData[k]
            slot = ReplicatedStorage.Assets.UI.ItemSlot:FindFirstChild(itemData.Quality):Clone()
            slot.ItemNameText.Text = itemData.Name
            slot.Icon.Image = itemData.Icon
            slot.Position = self['Item' .. tostring(cot) .. 'Template'].Position
            slot.Size = self['Item' .. tostring(cot) .. 'Template'].Size
            local cur = playerData.Item.Inv[tostring(k)] or 0
            local needed = v
            -- print(cur, needed)
            slot.ItemCountText.Text = string.format('%d/%d', cur, needed)
            if cur >= needed then
                slot.ItemCountText.TextColor3 = Color3.new(1, 1, 1)
            else
                slot.ItemCountText.TextColor3 = Color3.new(1, 0, 0)
            end
            slot.Name = 'Temp'
            slot.Parent = self.InfoFrame
            cot += 1
        end
        --#endregion

        self.CashFrame.CashCost.Text = string.format('$%s', shared.Tool.FormatNumber(curDict.NeedCoin))

    end
    self.Tips.Text = string.format('%s', shared.Tool.FormatTime(curDict.NeedTime))

    do  --  选择英雄时
        if self.Selected then
            local panel = self.InfoFrame:FindFirstChild('AlienSlot')
            if panel then panel:Destroy() end

            if evolveData.SourceUID then
                self.CashFrame.Visible = false
                self.StartTick(evolveData)
            else
                self.CashFrame.Visible = true

                local time = curDict.NeedTime
                if time then self.Tips.Text = shared.Tool.FormatTime(time) end
                local cash = curDict.NeedCoin
                if cash then  self.CashFrame.CashCost.Text = string.format('$ %s', shared.Tool.FormatNumber(cash)) end
            end

            local towerUID = shared.PlayerDataHandler.GetTowerUIDByUID(self.Selected)
            local towerStaticData = TowerData.GetData(towerUID)
            local trait = shared.PlayerDataHandler.GetTowerTraitByUID(self.Selected)
            local slot = shared.TowerListHelper.GetSlotByStaticData(towerStaticData, trait)
            slot.Size = self.SelectTemplate.Size
            slot.Position = self.SelectTemplate.Position
            slot.MouseButton1Click:Connect(function()
                if self.Evolving then return end
                shared.SoundHandler:Play('UI_Success')
                TriggerSelectFrame()
            end)
            slot.Name = 'AlienSlot'
            slot.Parent = self.InfoFrame

            self.NameLabel.Text = towerStaticData.DisplayName
            self.QualityLabel.Text = towerStaticData.Quality
            self.QualityLabel.TextColor3 = TowerData.GetRGBByTowerUID(towerUID)
        else
            local panel = self.InfoFrame:FindFirstChild('AlienSlot')
            if panel then panel:Destroy() end
        end
    end

end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Selected = nil
    self.Countdown = false
    self.Main:TweenClose()
end

function self.StartTick(evoData)
    if self.CountdownTask then
        task.cancel(self.CountdownTask)
        self.CountdownTask = nil
    end
        
    local remaining = evoData.EndTime - workspace:GetServerTimeNow()
    if remaining > 0 then
        self.Countdown = true
        self.CountdownTask = task.spawn(function()
            while self.Countdown do
                local r = evoData.EndTime - workspace:GetServerTimeNow()
                if r <= 0 then
                    self.Tips.Text = 'Evolve complete!'
                    self.Countdown = false
                    break
                end
                self.Tips.Text = shared.Tool.FormatTime(r)
                task.wait(1)
            end
        end)
    else
        self.Tips.Text = 'Evolve complete!'
    end
end

function TriggerSelectFrame()
    local playerData = shared.PlayerDataHandler.GetData()
    if playerData == nil then return end
    local playerInv = playerData.Tower.Inv

    self.SelectFrame.Visible = true
    local evoDict = TowerData.GetEvolutionDict()
    local curEvo = evoDict[self.EvoPool]
    local towerType = TowerData.GetTowerTypeByTowerUID(curEvo.NeedHero)
    
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
        local curType = TowerData.GetTowerTypeByTowerUID(tower.TowerUID)
        if curType ~= towerType then continue end
        local needLevel = TowerData.GetLvlByTowerUID(curEvo.NeedHero)
        local curLevel = TowerData.GetLvlByTowerUID(tower.TowerUID)
        if needLevel > curLevel then continue end
        local towerStaticData = TowerData.GetData(tower.TowerUID)
        local slot = shared.TowerListHelper.GetSlotByStaticData(towerStaticData, tower.Trait)
        slot.MouseButton1Click:Connect(function()
            self.Selected = tower.UID
            self.Fresh(playerData, nil)
            self.SelectFrame.Visible = false

            shared.SoundHandler:Play('UI_Success')
        end)

        slot.Parent = self.ScrollingFrame
    end
end

return self
