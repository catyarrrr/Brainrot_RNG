local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local ToggleSelect = nil
local self : any = {Selected = {}}

function self.start()
    shared.LeftUI.HeroBtnClickedEvent:Connect(function()
        local data = shared.PlayerDataHandler.GetData()
        -- self.Selected = {}
        self.Update(data)
        self:Open()
    end)
end

function self.Init(main)
	self.Main = shared.Frame.new(main.Menu.Alien)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.ScrollingFrame = self.Frame.ScrollingFrame
    self.CountLabel = self.Frame.CountA
    self.Title = self.Frame.Title
    self.Tab = self.Frame.Tab
    self.SortTab = self.Title.SortFrame

    self.SortBtn = self.Title.SortButton
    self.SortTab.Visible = false
    self.SortMode = 'DPS'
    self.SortBtn.SortText.Text = self.SortMode
    self.SortBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self.SortTab.Visible = true
    end)
    local sortButtons = {
        { Button = self.SortTab.Frame.CDButton, Mode = 'CD' },
        { Button = self.SortTab.Frame.DPSButton, Mode = 'DPS' },
        { Button = self.SortTab.Frame.RangeButton, Mode = 'Range' },
        { Button = self.SortTab.Frame.RarityButton, Mode = 'Rarity' },
    }
    for _, entry in sortButtons do
        entry.Button.MouseButton1Click:Connect(function()
            shared.SoundHandler:Play('UI_Success')
            self.SortMode = entry.Mode
            self.SortBtn.SortText.Text = self.SortMode
            self.SortTab.Visible = false
            self.Update(shared.PlayerDataHandler.GetData())
        end)
    end

    self.AutoMergeBtn = self.Tab.MergeAllButton
    self.AutoMergeBtn.Visible = true

    self.Title.Close.MouseButton1Click:Connect(function()
        -- ReplicatedStorage.Remote.Tower.SetTool:FireServer(self.Selected)
        shared.SoundHandler:Play('UI_Fail')
        self:Close()
    end)
    self.Tab.UnequipAllButton.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Tower.UnToolAll:FireServer()
    end)
    self.Tab.PickupAllButton.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Tower.TowerPickUpAll:FireServer()
    end)
    self.AutoMergeBtn.MouseButton1Click:Connect(function()
        local vipData = shared.PlayerDataHandler.GetVIPData()
        if vipData.AutoMerge == false then
            shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_AUTOMERGE)
        else
            ReplicatedStorage.Remote.Tower.AutoMerge:FireServer()
        end
    end)
end

function self.Update(playerData)
    self.Selected = {}
    for _, slot in self.ScrollingFrame:GetChildren() do
        if slot:IsA('ImageButton') then
            slot:Destroy()
        end
    end

    local playerInv = playerData.Tower.Inv
    local sortedData = shared.TowerListHelper.GetSortedTowerTable(playerInv, self.SortMode)
    for _, tower in sortedData do
        if tower.GridXY ~= nil then continue end
        if tower.Cloning then continue end
        if tower.IsEvolving then continue end
        local towerStaticData = TowerData.GetData(tower.TowerUID)
        local slot = shared.TowerListHelper.GetSlotByStaticData(towerStaticData, tower.Trait)
        if shared.PlayerDataHandler.CheckTowerIsTool(tower.UID) == true then 
            self.Selected[tower.UID] = true
            slot.Marking.Visible = true
        end
        slot.MouseButton1Click:Connect(function()
            ToggleSelect(tower.UID, slot)
        end)

        slot.Parent = self.ScrollingFrame
    end
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end

function ToggleSelect(uid, slot)

    if self.Selected[uid] then

        ReplicatedStorage.Remote.Tower.SetTool:FireServer(uid, false)
        self.Selected[uid] = nil
        slot.Marking.Visible = false

    else
        
        local cot = 0
        for _, v in pairs(self.Selected) do cot += 1 end
        if cot >= shared.Config.BACKPACK_MAXTOOL then shared.UIHandler.ServerWarn('Alien Slots are full !'); return end
        
        ReplicatedStorage.Remote.Tower.SetTool:FireServer(uid, true)
        self.Selected[uid] = true
        slot.Marking.Visible = true

    end
end
return self
