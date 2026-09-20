local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local PVPData = require(ReplicatedStorage.Datas.PVPData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local IMAGE_WARN = "rbxassetid://74510074950181"
local MAX_DEPLOY = 4
local TriggerSelectFrame = nil
local self : any = {}

--	刷新对手的冷却规则：免费刷新 REFRESH_LIMIT 次后进入 REFRESH_COOLDOWN 秒冷却（纯客户端）
local REFRESH_LIMIT = 10
local REFRESH_COOLDOWN = 15 * 60

--	取按钮上的消耗 label（与道具名 label 同名，取数值型的那一个）
local function FindCostLabel(btn)
    local fallback
    for _, child in ipairs(btn:GetChildren()) do
        if child:IsA('TextLabel') then
            if tonumber(child.Text) ~= nil then return child end
            fallback = fallback or child
        end
    end
    return fallback
end

function self.Init(frame)
	self.Main = shared.Frame.new(frame.Menu.PVP)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.UI
    self.Frame.Visible = true
    self.CrystalFrame = self.Frame.CrystalsCount
    self.SlotFrame = self.Frame.Main
    self.SlotFrame.Visible = true
    self.SlotScrolling = self.SlotFrame.ScrollingFrame
    self.SelectFrame = self.Main.Frame.Select
    self.SelectFrame.Visible = false
    self.ScrollingFrame = self.SelectFrame.ScrollingFrame
    self.FightChoose = self.Frame.FightChoose
    self.FightChoose.Visible = false
    self.Deployed = {}
    self.PendingSlot = nil
    self.Fighting = false

    self.ItemFrame = self.Frame.Item
    self:InitItemShop()

    self.FightButton = self.SlotFrame.Buttons.Fight
    self.ChallengeCountLabel = self.FightButton:FindFirstChild('ChallengeCount')
    self.CountdownLabel = self.FightButton:FindFirstChild('Countdown')

    self.SlotTemplates = {}
    for _, btn in self.SlotScrolling:GetChildren() do
        if btn:IsA('ImageButton') then
            local index = tonumber(btn.Name)
            if index == nil then continue end
            self.SlotTemplates[index] = btn:Clone()
            btn.MouseButton1Click:Connect(function()
                self:OpenSelect(index)
            end)
        end
    end

    self.SlotFrame.Buttons.Clear.MouseButton1Click:Connect(function()
        self:UndeployAll()
    end)
    self.SlotFrame.Buttons.EquipBest.MouseButton1Click:Connect(function()
        local playerData = shared.PlayerDataHandler.GetData()
        if playerData == nil then return end

        self:UndeployAll()

        local sortedData = shared.TowerListHelper.GetSortedTowerTable(playerData.Tower.Inv, 'DPS')
        local count = 0
        for _, tower in sortedData do
            if count >= MAX_DEPLOY then break end
            count += 1
            self:Deploy(count, tower.UID)
        end
        shared.SoundHandler:Play('UI_Success')
    end)

    self.SlotFrame.Buttons.Fight.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Success')
        self.SlotFrame.Visible = false
        self.FightChoose.Visible = true
        self.Opponents = nil
        self:RefreshOpponents()
    end)
    self.FightChoose.Buttons.Back.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self.FightChoose.Visible = false
        self.SlotFrame.Visible = true
    end)
    self.FightChoose.Buttons.Switch.MouseButton1Click:Connect(function()
        self:OnSwitch()
    end)

    --	对手挑选（服务端匹配）：6 个对手卡片（Easy/Medium/Hard 各两个）
    ReplicatedStorage.Remote.PVP.Opponents.OnClientEvent:Connect(function(payload)
        self:OnOpponents(payload)
    end)
    self.Opponents = nil
    self.RefreshCount = 0
    self.RefreshCooldownEnd = 0
    self.SwitchCountdownLabel = self.FightChoose.Buttons.Switch:FindFirstChild('Countdown')
    if self.SwitchCountdownLabel then self.SwitchCountdownLabel.Text = '' end

    --	收集对手卡片，按难度分组排序后写回 LayoutOrder，保证网格排列稳定
    self.OpponentFrames = {}
    for _, child in ipairs(self.FightChoose.ScrollingFrame:GetChildren()) do
        if child:IsA('Frame') then
            table.insert(self.OpponentFrames, child)
        end
    end
    local difficultyRank = {Easy = 1, Medium = 2, Hard = 3}
    table.sort(self.OpponentFrames, function(a, b)
        local rankA = difficultyRank[a.Name] or 99
        local rankB = difficultyRank[b.Name] or 99
        return rankA < rankB
    end)
    for index, frame in ipairs(self.OpponentFrames) do
        frame.LayoutOrder = index
        local challenge = frame:FindFirstChild('Challenge')
        if challenge and challenge:IsA('TextButton') then
            challenge.MouseButton1Click:Connect(function()
                shared.SoundHandler:Play('UI_Success')
                local pick = self.Opponents and self.Opponents[index]
                self:RequestFight(pick)
            end)
        end
    end

    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        self:Close()
    end)
    self.SelectFrame.Title.Close.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self.SelectFrame.Visible = false
        self.PendingSlot = nil
    end)
end

function self.Update(playerData)
    playerData = playerData or shared.PlayerDataHandler.GetData()
    if playerData == nil then return end

    self:LoadDeployed(playerData)

    for index, uid in pairs(self.Deployed) do
        if playerData.Tower.Inv[uid] == nil then
            self.Deployed[index] = nil
            self:ClearSlot(index)
        else
            self:RenderSlot(index, uid)
        end
    end
    self:RefreshSlots()
    self:RenderCrystal(playerData)
    self:RefreshItemCosts(playerData)
    self:UpdateChallenge(playerData)
end

--	从服务端保存的 States.PVPDeploy 恢复上阵顺序（本地已有阵位时不覆盖）
function self:LoadDeployed(playerData)
    if next(self.Deployed) ~= nil then return end

    local saved = playerData.States and playerData.States.PVPDeploy
    if type(saved) ~= 'table' then return end

    local slotIndex = 0
    for _, uid in ipairs(saved) do
        if slotIndex >= MAX_DEPLOY then break end
        if playerData.Tower.Inv[uid] == nil then continue end
        slotIndex += 1
        self.Deployed[slotIndex] = uid
    end
end

--	展示玩家持有的 Crystals
function self:RenderCrystal(playerData)
    if self.CrystalFrame == nil then return end
    playerData = playerData or shared.PlayerDataHandler.GetData()
    if playerData == nil or playerData.Coin == nil then return end
    self.CrystalFrame.CrystalsCountText.Text = shared.VFXHandler.FormatNumber(playerData.Coin.Crystals or 0)
end

--	初始化 PVP 商店的 5 个购买按钮
function self:InitItemShop()
    self.ItemButtons = {}

    if self.ItemFrame ~= nil then
        for _, btn in ipairs(self.ItemFrame:GetChildren()) do
            if not btn:IsA('TextButton') then continue end

            local costLabel = FindCostLabel(btn)
            self.ItemButtons[btn.Name] = { Button = btn, Cost = costLabel }

            btn.MouseButton1Click:Connect(function()
                if self.Buying then return end
                if PVPData.GetPurchaseConfig(btn.Name) == nil then return end

                self.Buying = true
                ReplicatedStorage.Remote.PVP.Buy:FireServer(btn.Name)
                task.delay(1, function() self.Buying = false end)
            end)
        end
    end

    ReplicatedStorage.Remote.PVP.BuyResult.OnClientEvent:Connect(function(result)
        self:OnBuyResult(result)
    end)
    shared.PlayerDataHandler.DataChangedEvent:Connect(function()
        self:RefreshItemCosts()
        self:UpdateChallenge()
    end)

    task.spawn(function()
        while not shared.PlayerDataHandler.InitData do task.wait() end
        self:RefreshItemCosts()
        self:UpdateChallenge()
    end)
end

--	按每日购买次数刷新按钮上的消耗 label
function self:RefreshItemCosts(playerData)
    if self.ItemButtons == nil then return end
    playerData = playerData or shared.PlayerDataHandler.GetData()
    if playerData == nil then return end

    local shop = playerData.PVP and playerData.PVP.Shop
    for buttonName, entry in pairs(self.ItemButtons) do
        local config = PVPData.GetPurchaseConfig(buttonName)
        if config ~= nil and entry.Cost ~= nil then
            local count = (shop and shop.Count and shop.Count[config.Key]) or 0
            local cost = PVPData.GetPurchaseValue(config.Key, count + 1)
            if cost ~= nil then
                entry.Cost.Text = shared.VFXHandler.FormatNumber(cost)
            end
        end
    end
end

--	购买回包：刷新消耗 label
function self:OnBuyResult(result)
    self.Buying = false
    if type(result) ~= 'table' then return end

    local entry = result.Button and self.ItemButtons and self.ItemButtons[result.Button]
    if entry ~= nil and entry.Cost ~= nil and result.NextCost ~= nil then
        entry.Cost.Text = shared.VFXHandler.FormatNumber(result.NextCost)
    end

    shared.SoundHandler:Play('UI_Success')
end

--	刷新 Fight 按钮上的挑战次数与恢复倒计时
function self:UpdateChallenge(playerData)
    if self.ChallengeCountLabel == nil then return end

    playerData = playerData or shared.PlayerDataHandler.GetData()
    if playerData == nil or playerData.PVP == nil then return end

    local challengeData = playerData.PVP.Challenge
    if challengeData == nil then return end

    local maxCount = shared.Config.PVPCHALLENGE_MAXCOUNT
    local recover = shared.Config.PVPCHALLENGE_RECOVER
    local now = workspace:GetServerTimeNow()

    local recoverCount = 0
    if challengeData.Count < maxCount and now >= challengeData.RecoverTime then
        recoverCount = math.floor((now - challengeData.RecoverTime) / recover + 1)
    end

    local count = math.min(challengeData.Count + recoverCount, maxCount)
    self.ChallengeCountLabel.Text = 'Attempts: ' .. tostring(count)

    --	上限时不再显示倒计时，否则显示到下一次恢复的剩余时间
    local nextRecoverTime = 0
    if count < maxCount then
        nextRecoverTime = challengeData.RecoverTime + recoverCount * recover
    end
    self:StartTick(nextRecoverTime)
end

--	挑战次数恢复倒计时
function self:StartTick(recoverTime)
    self.CountdownRunning = false
    if self.CountdownTask then
        task.cancel(self.CountdownTask)
        self.CountdownTask = nil
    end

    if (recoverTime or 0) - workspace:GetServerTimeNow() <= 0 then
        if self.CountdownLabel then self.CountdownLabel.Text = '' end
        return
    end

    self.CountdownRunning = true
    self.CountdownTask = task.spawn(function()
        while self.CountdownRunning do
            local remain = recoverTime - workspace:GetServerTimeNow()
            if remain <= 0 then break end
            if self.CountdownLabel then self.CountdownLabel.Text = shared.Tool.FormatTime(remain) end
            task.wait(1)
        end

        if not self.CountdownRunning then return end
        self.CountdownRunning = false
        self.CountdownTask = nil
        if self.CountdownLabel then self.CountdownLabel.Text = '' end
        --	到点恢复一次，刷新次数并进入下一轮倒计时
        self:UpdateChallenge()
    end)
end

function self:Open()
    self:RefreshSlots()
    self:RefreshItemCosts()
    self:UpdateChallenge()
    if not self:CanRefresh() then
        self:StartRefreshCooldownTick()
    elseif self.SwitchCountdownLabel then
        self.SwitchCountdownLabel.Text = ''
    end
    self.Main:TweenOpen()
end
function self:Close()
    self.SelectFrame.Visible = false
    self.PendingSlot = nil
    self.Fighting = false
    local fightUI = shared.UIHandler.FightUI
    if fightUI then fightUI:Hide() end
    self.Frame.Visible = true
    self.SlotFrame.Visible = true
    self.FightChoose.Visible = false
    self.Main:TweenClose()
end

--	战斗结算面板 Quit 后返回上阵界面
function self:ReturnToDeploy()
    self.Frame.Visible = true
    self.SlotFrame.Visible = true
    self.FightChoose.Visible = false
    self:RefreshSlots()
    self:RenderCrystal(shared.PlayerDataHandler.GetData())
end

function self:OpenSelect(index)
    if index == nil then return end
    if self.Deployed[index] == nil and self:GetDeployedCount() >= MAX_DEPLOY then
        shared.SoundHandler:Play('UI_Fail')
        return
    end
    shared.SoundHandler:Play('UI_Success')
    self.PendingSlot = index
    TriggerSelectFrame()
end

function self:IsDeployed(uid)
    for _, deployed in self.Deployed do
        if deployed == uid then return true end
    end
    return false
end

function self:CreateEmptySlot(index)
    local template = self.SlotTemplates[index]
    if template == nil then return end
    local btn = template:Clone()
    btn.MouseButton1Click:Connect(function()
        self:OpenSelect(index)
    end)
    btn.Parent = self.SlotScrolling
end

function self:ClearSlot(index)
    local current = self.SlotScrolling:FindFirstChild(tostring(index))
    if current then current:Destroy() end
    self:CreateEmptySlot(index)
end

function self:GetDeployedCount()
    local count = 0
    for _ in pairs(self.Deployed) do
        count += 1
    end
    return count
end

function self:RefreshSlots()
    local full = self:GetDeployedCount() >= MAX_DEPLOY
    for index in pairs(self.SlotTemplates) do
        if self.Deployed[index] ~= nil then continue end
        local current = self.SlotScrolling:FindFirstChild(tostring(index))
        if current == nil then continue end
        local icon = current:FindFirstChild('Icon')
        if icon == nil then continue end
        if full then
            icon.Image = IMAGE_WARN
        else
            local template = self.SlotTemplates[index]
            local templateIcon = template and template:FindFirstChild('Icon')
            if templateIcon then icon.Image = templateIcon.Image end
        end
    end
end

function self:Undeploy(index)
    if index == nil then return end
    self.Deployed[index] = nil
    self:ClearSlot(index)
    self:RefreshSlots()
end

function self:UndeployAll()
    for index in pairs(self.Deployed) do
        self.Deployed[index] = nil
        self:ClearSlot(index)
    end
    self:RefreshSlots()
end

function self:RenderSlot(index, uid)
    local current = self.SlotScrolling:FindFirstChild(tostring(index))
    if current == nil then return end

    local playerData = shared.PlayerDataHandler.GetData()
    if playerData == nil then return end
    local towerData = playerData.Tower.Inv[uid]
    if towerData == nil then return end
    local towerStaticData = TowerData.GetData(towerData.TowerUID)
    if towerStaticData == nil then return end

    local slot = shared.TowerListHelper.GetSlotByStaticData(towerStaticData, towerData.Trait)
    if slot == nil then return end
    slot.Name = tostring(index)
    slot.LayoutOrder = current.LayoutOrder
    --	与空阵位同宽，避免 UIListLayout 因塔位与空位尺寸不同而重新排版造成位移
    local template = self.SlotTemplates[index]
    if template ~= nil then
        slot.Size = template.Size
    end
    slot.MouseButton1Click:Connect(function()
        self:OpenSelect(index)
    end)
    current:Destroy()
    slot.Parent = self.SlotScrolling
end

function self:Deploy(index, uid)
    if index == nil or uid == nil then return end
    if self.Deployed[index] == nil and self:GetDeployedCount() >= MAX_DEPLOY then return end
    self.Deployed[index] = uid
    self:RenderSlot(index, uid)
    self:RefreshSlots()
end

--	向服务端请求对手候选（带上当前上阵顺序，服务端据此估算机器人强度）
function self:RefreshOpponents()
    local deployed = {}
    for index = 1, MAX_DEPLOY do
        local uid = self.Deployed[index]
        if uid ~= nil then table.insert(deployed, uid) end
    end
    ReplicatedStorage.Remote.PVP.RequestOpponents:FireServer(deployed)
end

--	收到服务端候选后缓存并渲染
function self:OnOpponents(payload)
    if type(payload) ~= 'table' or type(payload.List) ~= 'table' then return end
    self.Opponents = payload.List
    self:RenderOpponents()
end

--	刷新每个对手卡片：真玩家显示名字/头像，机器人显示随机塔卡面；两者都显示其累计 Crystals
function self:RenderOpponents()
    for index, frame in ipairs(self.OpponentFrames or {}) do
        local pick = self.Opponents and self.Opponents[index]
        if pick == nil then continue end

        local nameText = frame:FindFirstChild('NameText')
        local descText = frame:FindFirstChild('DescText')
        local cashText = frame:FindFirstChild('CashText')
        local icon = frame:FindFirstChild('PlayerIcon')

        if nameText then nameText.Text = pick.Name or '' end
        if descText then descText.Text = shared.VFXHandler.FormatNumber(pick.CrystalReward or 0) end
        if cashText then cashText.Text = shared.VFXHandler.FormatNumber(pick.CashReward or 0) end

        if icon then
            if pick.Kind == 'Player' and pick.UserId ~= nil then
                icon.Image = string.format('rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150', pick.UserId)
            elseif pick.TowerUID ~= nil then
                local assetId = TowerData.GetAssetIdByTowerUID(pick.TowerUID)
                local asset = assetId and AssetsData[assetId]
                if asset and asset.Icon then icon.Image = asset.Icon end
            end
        end
    end
end

function self:CanRefresh()
    return (self.RefreshCooldownEnd or 0) <= workspace:GetServerTimeNow()
end

--	Switch：冷却期间不可刷新；刷新满 REFRESH_LIMIT 次进入冷却
function self:OnSwitch()
    local now = workspace:GetServerTimeNow()
    if not self:CanRefresh() then
        shared.SoundHandler:Play('UI_Fail')
        shared.UIHandler.ServerWarn(string.format('Refresh again in %s', shared.Tool.FormatTime(self.RefreshCooldownEnd - now)))
        return
    end

    self.RefreshCount = (self.RefreshCount or 0) + 1
    if self.RefreshCount >= REFRESH_LIMIT then
        self.RefreshCount = 0
        self.RefreshCooldownEnd = now + REFRESH_COOLDOWN
        self:StartRefreshCooldownTick()
    end

    shared.SoundHandler:Play('UI_Success')
    self:RefreshOpponents()
end

--	在 Switch 按钮的 Countdown 上显示刷新冷却倒计时
function self:StartRefreshCooldownTick()
    if self.RefreshCooldownTask then
        task.cancel(self.RefreshCooldownTask)
        self.RefreshCooldownTask = nil
    end

    local label = self.SwitchCountdownLabel
    self.RefreshCooldownTask = task.spawn(function()
        while true do
            local remain = (self.RefreshCooldownEnd or 0) - workspace:GetServerTimeNow()
            if remain <= 0 then break end
            if label then label.Text = shared.Tool.FormatTime(remain) end
            task.wait(1)
        end
        if label then label.Text = '' end
        self.RefreshCooldownTask = nil
    end)
end

--	向服务端发起战斗请求：上报按阵位顺序排列的出战 uid 数组与服务端签发的对手 token
function self:RequestFight(candidate)
    if self.Fighting then return end
    if candidate == nil or candidate.Id == nil then
        shared.UIHandler.ServerWarn('Opponent unavailable, please refresh')
        return
    end

    local deployed = {}
    for index = 1, MAX_DEPLOY do
        local uid = self.Deployed[index]
        if uid ~= nil then
            table.insert(deployed, uid)
        end
    end
    if #deployed == 0 then
        shared.UIHandler.ServerWarn('Deploy some brainrots first !!!')
        return
    end

    self.Fighting = true
    --	服务端可能因校验失败而不回包，超时后解除锁定
    task.delay(5, function() self.Fighting = false end)
    ReplicatedStorage.Remote.PVP.Fight:FireServer(deployed, candidate.Id)
end

--	收到服务端战斗结果后交给 FightUI 播放战斗动画
function self:PlayResult(result)
    self.Fighting = false
    if result == nil or result.Ally == nil or result.Enemy == nil then return end

    self.Frame.Visible = false
    local fightUI = shared.UIHandler.FightUI
    if fightUI == nil then return end
    fightUI:PlayResult(result, function()
        self:ReturnToDeploy()
    end)
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

    local unequipTemplate = self.SlotTemplates[1]
    if unequipTemplate then
        local unequip = unequipTemplate:Clone()
        unequip.Name = 'Undeploy'
        unequip.LayoutOrder = -1
        local icon = unequip:FindFirstChild('Icon')
        if icon then icon.Image = IMAGE_WARN end
        unequip.MouseButton1Click:Connect(function()
            self:Undeploy(self.PendingSlot)
            self.SelectFrame.Visible = false
            self.PendingSlot = nil
            shared.SoundHandler:Play('UI_Fail')
        end)
        unequip.Parent = self.ScrollingFrame
    end

    local sortedData = shared.TowerListHelper.GetSortedTowerTable(playerInv)
    for _, tower in sortedData do
        if self:IsDeployed(tower.UID) then continue end
        local towerStaticData = TowerData.GetData(tower.TowerUID)
        local slot = shared.TowerListHelper.GetSlotByStaticData(towerStaticData, tower.Trait)
        if slot == nil then continue end
        slot.MouseButton1Click:Connect(function()
            self:Deploy(self.PendingSlot, tower.UID)
            self.SelectFrame.Visible = false
            self.PendingSlot = nil
            shared.SoundHandler:Play('UI_Success')
        end)

        slot.Parent = self.ScrollingFrame
    end
end

return self
