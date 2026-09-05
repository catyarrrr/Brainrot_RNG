local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)

local CreateSlot, UpdateSwitchMode = nil
local self : any = {FeedList = {}, IsSwitchMode = false, CurSlot = 1}

local function GetSlotField(slot)
    return slot == 1 and 'Equipped' or 'Equipped' .. slot
end

local function GetEquippedUIDs(playerData)
    local totemData = playerData and playerData.Totem
    if totemData == nil then return {} end

    local uids = {}
    for slot = 1, 3 do
        local uid = totemData[GetSlotField(slot)]
        if uid ~= false and uid ~= nil then uids[uid] = true end
    end
    return uids
end

--	槽位解锁规则：槽位1免费；槽位2解锁标记 Slot2Unlocked；槽位3需购买 PASSID_TOTEMSLOT
local function GetSlotCount(playerData)
    if playerData == nil or playerData.Totem == nil then return 1 end

    local count = 1
    if playerData.Totem.Slot2Unlocked == true then
        count = 2
    end

    if playerData.VIP and playerData.VIP.TotemSlot == true then
        count = 3
    end

    return count
end

function self.Init(frame)
	self.Main = shared.Frame.new(frame.Menu.TotemFrame)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.InvScrolling = self.Frame.UpgradeFrame.Bag.ScrollingFrame
    self.FeedScrolling = self.Frame.UpgradeFrame.Feed.ScrollingFrame
    self.SelectedSlot = self.Frame.UpgradeFrame.Totem.Totem
    self.MainInfo = self.Frame.UpgradeFrame.Totem.PrimaryAttribute
    self.SubInfo = self.Frame.UpgradeFrame.Totem.SecondaryAttribute

    self.UpgradeParticles = self.Frame.Particles
    for k, v in self.UpgradeParticles:GetChildren() do if v:IsA('Configuration') then v:SetAttribute('Enabled', false) end end
    self.UpgradeBtn = self.Frame.UpgradeFrame.Upgrade
    self.AddAllBtn = self.Frame.UpgradeFrame.AddAll
    self.CancelBtn = self.Frame.UpgradeFrame.Cancel
    self.RemoveAllBtn = self.Frame.UpgradeFrame.RemoveAll
    self.SwitchBtn = self.Frame.UpgradeFrame.Select
    self.SwitchVisal = self.Frame.UpgradeFrame.Bag.SwitchMark
    self.TabSlots = { self.Frame.Tab.Equipped, self.Frame.Tab.Equipped2, self.Frame.Tab.Equipped3 }

    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        self:Close()
    end)
    self.UpgradeBtn.MouseButton1Click:Connect(function()
        if #self.FeedList == 0 then return end

        ReplicatedStorage.Remote.Tower.FeedTotem:FireServer(self.FeedList, self.CurSlot)
        self.FeedList = {}
        self:Update()
    end)
    self.AddAllBtn.MouseButton1Click:Connect(function()
        local playerData = shared.PlayerDataHandler.GetData()
        if playerData == nil then return end

        local equippedUIDs = GetEquippedUIDs(playerData)
        self.FeedList = {}
        for uid, totem in pairs(playerData.Totem.Inv) do
            if equippedUIDs[uid] then continue end
            if type(totem) ~= 'table' then continue end
            table.insert(self.FeedList, uid)
        end
        self:Update()
    end)
    self.RemoveAllBtn.MouseButton1Click:Connect(function()
        self.FeedList = {}
        self:Update()
    end)
    self.CancelBtn.MouseButton1Click:Connect(function()
        self.FeedList = {}
        self:Update()
    end)
    self.SwitchBtn.MouseButton1Click:Connect(function()
        self.IsSwitchMode = not self.IsSwitchMode
        self.SwitchVisal.Enabled = self.IsSwitchMode
        self.FeedList = {}
        self:Update()
    end)
    self.Frame.Tab.Equipped.Btn.MouseButton1Click:Connect(function()
        self:SwitchSlot(1)
    end)
    self.Frame.Tab.Equipped2.Btn.MouseButton1Click:Connect(function()
        self:SwitchSlot(2)
    end)
    self.Frame.Tab.Equipped3.Btn.MouseButton1Click:Connect(function()
        self:SwitchSlot(3)
    end)
end

function self:SwitchSlot(slot)
    if slot < 1 or slot > 3 then return end

    local playerData = shared.PlayerDataHandler.GetData()
    if slot == 2 then
        if playerData == nil or playerData.Totem == nil or playerData.Totem.Slot2Unlocked ~= true then
            shared.UIHandler.ServerWarn('Upgrade a Totem to level 10 to unlock this slot!')
            return
        end
    elseif slot == 3 then
        if playerData == nil or playerData.VIP == nil or playerData.VIP.TotemSlot ~= true then
            shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_TOTEMSLOT)
            return
        end
    end

    if self.CurSlot == slot then
        self:Update()
        return
    end

    self.CurSlot = slot
    self.FeedList = {}
    self.IsSwitchMode = false
    if self.SwitchVisal then self.SwitchVisal.Enabled = false end
    self:Update()
end

function self.UpdateTabs()
    local playerData = shared.PlayerDataHandler.GetData()
    local slotCount = GetSlotCount(playerData)

    for i, tab in ipairs(self.TabSlots) do
        local selected = tab:FindFirstChild('Selected')
        if selected then selected.Visible = (i == self.CurSlot) end

        local lock = tab:FindFirstChild('Lock')
        if lock then lock.Visible = (i > slotCount) end
    end
end

function self.Update()
    local playerData = shared.PlayerDataHandler.GetData()
    if playerData == nil or playerData.Totem == nil then return end

    local totemInv = playerData.Totem.Inv
    if totemInv == nil then return end

    local equippedUIDs = GetEquippedUIDs(playerData)

    --	剔除已经不存在的素材
    local feedList = {}
    for _, uid in self.FeedList do
        if totemInv[uid] ~= nil then table.insert(feedList, uid) end
    end
    self.FeedList = feedList

    for _, slot in self.InvScrolling:GetChildren() do
        if slot:IsA('ImageButton') then slot:Destroy() end
    end
    for _, slot in self.FeedScrolling:GetChildren() do
        if slot:IsA('ImageButton') then slot:Destroy() end
    end

    local sortedTotems = {}
    for _, totem in pairs(totemInv) do
        if type(totem) ~= 'table' then continue end
        table.insert(sortedTotems, totem)
    end
    table.sort(sortedTotems, function(a, b) return a.TotemUID < b.TotemUID end)

    for _, totem in sortedTotems do
        if type(totem) ~= 'table' then continue end
        if equippedUIDs[totem.UID] then continue end

        local staticData = TotemData.GetData(totem.TotemUID)
        if staticData == nil then continue end

        local isFeed = table.find(self.FeedList, totem.UID)
        if self.IsSwitchMode then
            if isFeed then continue end

            local slot = CreateSlot(totem, staticData)
            slot.MouseButton1Click:Connect(function()
                ReplicatedStorage.Remote.Tower.EquipTotem:FireServer(totem.UID, self.CurSlot)
                self.SwitchVisal.Enabled = false
                self.IsSwitchMode = false
                self:Update()
            end)
            slot.Parent = self.InvScrolling
        elseif isFeed then
            local slot = CreateSlot(totem, staticData)
            slot.MouseButton1Click:Connect(function()
                table.remove(self.FeedList, table.find(self.FeedList, totem.UID))
                self:Update()
            end)
            slot.Parent = self.FeedScrolling
        else
            local slot = CreateSlot(totem, staticData)
            slot.MouseButton1Click:Connect(function()
                table.insert(self.FeedList, totem.UID)
                self:Update()
            end)
            slot.Parent = self.InvScrolling
        end
    end

    self.UpdateTabs()
    self.UpdateSelected(playerData.Totem[GetSlotField(self.CurSlot)])
end

function self.UpdateSelected(selectedUID)
    -- print(selectedUID)
    if selectedUID == false or selectedUID == nil then
        self.SelectedSlot.Visible = false
        self.MainInfo.Text = ''
        self.SubInfo.Text = ''
    else
        local totemData = shared.PlayerDataHandler.GetTotemByUID(selectedUID)
        local totemUID = shared.PlayerDataHandler.GetTotemUIDByUID(selectedUID)
        if totemUID == nil or totemData == nil then return end
        local staticData = TotemData.GetData(totemUID)
        if staticData == nil then return end

        self.SelectedSlot.Level.Text = TotemData.GetTotemLevel(totemData.Point)
        self.SelectedSlot.Evaluate.Text = staticData.Rating
        self.SelectedSlot.Icon.Image = staticData.MainIcon
        local mainType = TotemData.Type[staticData.MainType]
        local subType = TotemData.Type[staticData.SubType]
        self.SelectedSlot.PrimaryAttribute.Text = mainType
        self.SelectedSlot.SecondaryAttribute.Text = subType

        local modifier = shared.CalculateData.GetModifierByPoints(totemData.Point)
        self.MainInfo.Text = string.format('%s + %d', mainType, modifier*3)
        self.SubInfo.Text = string.format('%s + %d', subType, modifier)

        self.SelectedSlot.Visible = true

    end

end

function self.UpgradeEffect()
    task.spawn(function()
        for k, v in self.UpgradeParticles:GetChildren() do
            if v:IsA('Configuration') then
                v:SetAttribute('Enabled', true)
            end
        end

        task.wait(1)

        for k, v in self.UpgradeParticles:GetChildren() do
            if v:IsA('Configuration') then
                v:SetAttribute('Enabled', false)
            end
        end
    end)
end

function self:Open()
    self.IsSwitchMode = false
    self.UpdateTabs()
    self.Main:TweenOpen()
end
function self:Close()
    self.FeedList = {}
    self.Main:TweenClose()
end

function CreateSlot(totem, staticData)
    local slot = ReplicatedStorage.Assets.UI.TotemSlot:FindFirstChild('Totem' .. staticData.Rating):Clone()
    slot.Icon.Image = staticData.MainIcon
    slot.Level.Text = TotemData.GetTotemLevel(totem.Point)
    slot.PrimaryAttribute.Text = TotemData.Type[staticData.MainType]
    slot.SecondaryAttribute.Text = TotemData.Type[staticData.SubType]
    return slot
end

return self