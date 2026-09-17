local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)
local SummonData = require(ReplicatedStorage.Datas.SummonData :: ModuleScript)
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)

local Class, collections = {Initiated = false, PendingAlien = {}}, {}
Class.__index = Class

function Class.init()
    Class.GachaDataUpdateEvent = shared.Event.new()
    Class.UpdateAllEvent = shared.Event.new()
end

function Class.start()
    Class.GachaDataUpdateEvent:Connect(function(_, plr)
        local path = shared.DataStore.GetPlayerCurPath(plr)
        local machine = Class.Get(path)
        machine:Update()
    end)
    Class.UpdateAllEvent:Connect(function()
        for k, v in pairs(collections) do
            v:Update()
        end
    end)

	local Machines = workspace.SceneLogic.GachaMachine
    for k, v in Machines:GetChildren() do
        New(v)
    end

    Class.Initiated = true
end

function Class.Get(id)
    local machine = collections[id]
    if machine == nil then warn('machine fetch error for id:', id); return end

    return machine
end


function New(model)
	local self = setmetatable({}, Class)

	local id = string.match(model.Name, 'e(%d+)$')
    self.Id = tonumber(id)
    self.PosFolder = model.SpawnPos
    self.GuaranteeGui = model.Guarantee.SurfaceGui
    self.LuckGui = model.Luckpoint.SurfaceGui
    self.LuckGui.TextButton.MouseButton1Click:Connect(function(player)
        print(player)
    end)
    self.LuckLabel = self.LuckGui.Luckpoint.LuckpointText
    self.SpawnPos = {}
    for k, v in model.SpawnPos:GetChildren() do
        table.insert(self.SpawnPos, v.WorldCFrame)
    end
    self.Rolling = false

    local rollPrompt = Instance.new('ProximityPrompt')
    rollPrompt.HoldDuration = .3
    rollPrompt.ActionText = 'Roll'
    rollPrompt.RequiresLineOfSight = false
    rollPrompt.Parent = model.Roll

    rollPrompt.Triggered:Connect(function(player)
        if self.Rolling then return end
        local pathId = shared.DataStore.GetPlayerCurPath(player)
        if pathId == nil then return end
        if pathId ~= self.Id then return end

        local playData = shared.DataStore.GetData(player)
        local fastRoll = playData.VIP.FastRoll
        if fastRoll then
            shared.VFXHandler.EmitParticle(self.PosFolder, 1)
            shared.SoundHandler:PlayAt('RollFast', model.Roll.Position)
        else
            ReplicatedStorage.Remote.PlayerRoll:FireClient(player, fastRoll)
            shared.VFXHandler.EnableParticle(self.PosFolder)
            shared.SoundHandler:PlayAt('Roll', model.Roll.Position)
        end
        self:Clear()
        self:Gacha(player)
        self.Rolling = true

        local debounce
        if fastRoll then debounce = .5 else debounce = 3 end
        task.delay(debounce, function() 
            self.Rolling = false; 
            shared.VFXHandler.DisableParticle(self.PosFolder) 
        end)
    end)

	collections[self.Id] = self

	return self
end

function Class:Gacha(player)
    local playerData = shared.DataStore.GetData(player)
    local luck = playerData.Gacha.Luck
    if luck == nil then warn('luck fetch failed for plr:', player); return end
    if shared.ServerEvent.ServerLuckEndTime then luck += 1 end
    local towers = {}
    local vipMut = playerData.VIP.Mutationx2
    for i=1, 3 do
        local key = shared.DataStore.GachaController.Gacha(player, luck)
        table.insert(towers, SummonData.Gacha(luck, key, vipMut))
    end

    -- print(towers)
    --  事件影响突变
    if shared.ServerEvent.IsMut and shared.ServerEvent.IsMut == true then
        local gachaDict
        if playerData.VIP.Mutationx2 == true then
            gachaDict = table.clone(SummonData.Datas.VIPMutationDict)
        else
            gachaDict = table.clone(SummonData.Datas.MutationDict)
        end
        if shared.ServerEvent.State.name == shared.ServerEvent.StateDict.DiamondMut then
            gachaDict[2] += 1000
            gachaDict[3] += 500
            gachaDict[4] += 50
        -- elseif shared.ServerEvent.State.name == shared.ServerEvent.StateDict.SixSevenFeast then
        --     gachaDict[2] += 500
        --     gachaDict[3] += 500
        --     gachaDict[4] += 500
        end

        print(gachaDict)

        for k, v in towers do
            local curMutId = math.floor(v/100)%100
            towers[k] -= curMutId * 100

            local newMut = shared.Tool.GachaByDict(gachaDict)
            towers[k] += newMut*100
        end
        -- print(towers)
    end

    self.Towers = {}
    local fastRoll = playerData.VIP.FastRoll
    for index, towerUID in towers do
        local tower = TowerData.GetData(towerUID)
        local assets = AssetsData[tower.AssetId]
        local model, offset = InitTowerModel(assets, tower)
        offset = offset or CFrame.new(0, 0, 0)
        if fastRoll then
            model:PivotTo(self.SpawnPos[index] * offset)
        else
            model:PivotTo((self.SpawnPos[index] + Vector3.new(0, -20, 0)))
            task.delay(3.2, function() model:PivotTo(self.SpawnPos[index]* offset) end)
        end
        table.insert(self.Towers, model)
        local buyPrompt = Instance.new('ProximityPrompt')
        buyPrompt.HoldDuration = .3
        buyPrompt.ActionText = 'Buy'
        buyPrompt.Parent = model

        buyPrompt.Triggered:Connect(function(player)
            local playerPath = shared.DataStore.GetPlayerCurPath(player)
            if playerPath ~= self.Id then return end
            if shared.DataStore.CoinController.CheckCash(player, tower.Cost) == true then
                shared.DataStore.PlayerConfirmGuide(player, 2)
                shared.SoundHandler:PlayAt('AlienBuy_Success', self.SpawnPos[index].Position)
                local newUID = HttpService:GenerateGUID(false)
                shared.DataStore.CoinController.Consume(player, tower.Cost)
                shared.DataStore.TowerController.Add(player, tower.TowerUID, newUID)
	            shared.BackpackHandler.AddPlayerBackpackTool(player, newUID)
                model:Destroy()
            else
                Class.PendingAlien[player.UserId] = {towerUID, model}
                shared.SoundHandler:PlayAt('AlienBuy_Fail', self.SpawnPos[index].Position)
			    ReplicatedStorage.Remote.ServerWarn:FireClient(player, 'Cash Not Enough!!!')
                ReplicatedStorage.Remote.Tower.KeepThis:FireClient(player, towerUID)
            end
        end)
    end

    self:Update()
end

function Class:Clear()
    if self.Towers and next(self.Towers) ~= nil then 
        for _, tower in self.Towers do
            tower:Destroy()
        end
    end
    
end
function Class.ClearPendingAien(player)
    local pending = Class.PendingAlien[player.UserId]
    if pending == nil then return end

    pending[2]:Destroy()
    Class.PendingAlien[player.UserId] = nil
end

function Class:Reset()
    self.GuaranteeGui.Enabled = false
    self.LuckGui.Enabled = false
    self:Clear()

    self.Owner = nil
end
function Class:Update()
    if self.Owner == nil then return end
    local playerData = shared.DataStore.GetData(self.Owner)
    self.GuaranteeGui.Legendary.RollsCount.Text = string.format('in %d Rolls', math.floor((SummonData.Pitys.Legendary - playerData.Gacha.LegendaryPity)/3))
    self.GuaranteeGui.Mythic.RollsCount.Text = string.format('in %d Rolls', math.floor((SummonData.Pitys.Mythic - playerData.Gacha.MythicPity)/3))
    self.GuaranteeGui.Secret.RollsCount.Text = string.format('in %d Rolls', math.floor((SummonData.Pitys.Secret - playerData.Gacha.SecretPity)/3))

    if shared.ServerEvent.ServerLuckEndTime then
        self.LuckLabel.Text = tostring(playerData.Gacha.Luck + 1) .. 'x'
    else
        self.LuckLabel.Text = tostring(playerData.Gacha.Luck) .. 'x'
    end
    local luckLevel = playerData.Gacha.Luck
    if playerData.VIP.DoubleLuck then luckLevel -= 1 end
    if playerData.VIP.TripleLuck then luckLevel -= 1 end
    local luckData = TempData.LuckDict[luckLevel]
    if luckData.NextCost == nil then
        self.LuckLabel.Text = self.LuckLabel.Text .. '\n' .. 'MAX'
    else
        self.LuckLabel.Text = self.LuckLabel.Text .. '\n' .. shared.Tool.FormatNumber(luckData.NextCost)
    end
end

function Class:Enter(player)
    self.Owner = player

    self.GuaranteeGui.Enabled = true
    self.LuckGui.Enabled = true

    self:Update()
end

function InitTowerModel(assets, towerData)
    local model = ReplicatedStorage.Assets.Towers:FindFirstChild(assets.Model)
    local clone = model:Clone()
    local mutId = TowerData.GetMutIdByTowerUID(towerData.TowerUID)

    clone.PrimaryPart.Anchored = true
    for _, child in clone:GetDescendants() do
		if child:IsA('BasePart') then
			child.CollisionGroup = 'Tower'
		end
	end

    shared.VFXHandler.GenerateTowerGui(clone, towerData)

    shared.VFXHandler.GenerateMutParticle(clone, mutId)

    clone.Parent = workspace
    
    ----------------        播放idle动画
    if assets.IdleAnimation ~= nil then
        local targetAnimation = Instance.new('Animation')
        targetAnimation.AnimationId = assets.IdleAnimation
        targetAnimation.Parent = clone

        local animationController = clone:FindFirstChild('AnimationController')
        if not animationController then print('animationController not found'); return end
        
        local animator = animationController:FindFirstChild('Animator')
        if animator == nil then 
            animator = Instance.new('Animator')
            animator.Parent = animationController
        end
        local animationTrack : AnimationTrack = animator:LoadAnimation(targetAnimation)
        animationTrack.Looped = true
        animationTrack:Play()
    end


    return clone, model:GetAttribute('CF')
end


return Class