local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Debris = game:GetService('Debris')
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService("UserInputService")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local visualFolder = Instance.new('Folder')
visualFolder.Name = 'Visuals'
visualFolder.Parent = workspace
local upgradeTowerHighlight = Instance.new('Highlight')
upgradeTowerHighlight.Enabled = false
upgradeTowerHighlight.FillColor = Color3.fromRGB(8, 255, 29)
upgradeTowerHighlight.Parent = visualFolder
local towerHighlight = Instance.new('Highlight')
towerHighlight.Enabled = false
towerHighlight.Parent = visualFolder

local SPEED_OFFSET, SPEED_SPIN, HIDDEN_CFRAME = 2, 45, CFrame.new(0, -500, 0)
local gachaTowers, gachaPartsCache = {}, {}
local gachaTowerSlot = {}
local gachaPositioned = false
local GradientHorizontalMove, GradientVerticalMove, GradientSpin, InitTowerParticle, PlayTowerParticle, GenerateTowerGui, InitTowerSwitchVisual = nil
local self : any = {ParticleModule = nil, GuideArrow = nil, RayCastHit = nil, Ray = nil, CurGrid = {},}
local rng = Random.new()


function self.init()
	self.ParticleModule = require(script.Particles)
	self.ParticleModule.Init()
    self.BadgeModule = require(script.Badge) :: ModuleScript

	self.PlayParticleEvent = shared.Event.new()
	self.PlayTowerParticleEvent = shared.Event.new()
	self.TriggerDamageTextEvent = shared.Event.new()
	self.TriggerParticleEvent = shared.Event.new()
	self.TriggerPlusOneTextEvent = shared.Event.new()
	self.CreateBadgeEvent = shared.Event.new()
	self.EnemyFarmEvent = shared.Event.new()
end

function self.start()
	self.PlayParticleEvent:Connect(self.PlayParticle)
	self.PlayTowerParticleEvent:Connect(PlayTowerParticle)
	self.EnemyFarmEvent:Connect(EnemyFarm)
	self.CreateBadgeEvent:Connect(self.BadgeModule.new, self)
	shared.Tower.SpawnTowerEvent:Connect(GenerateTowerGui, self)
	shared.Tower.SpawnTowerEvent:Connect(function(_, _, towerUID, _, _, _, model) self.GenerateMutParticle(_, towerUID, model) end)
	shared.Game.GameStartedEvent:Connect(function() InitTowerParticle(); self.StartTotemSpin() end)
	shared.Game.GameEndedEvent:Connect(function()
        self.StopTotemSpin()
        shared.ObjectPool.DestroyByTag('TowerParticle')
    end)

	ReplicatedStorage.Remote.PlayerRoll.OnClientEvent:Connect(RollTower)
	ReplicatedStorage.Remote.CardIncome.OnClientEvent:Connect(function(position, reward)
		self.EnemyFarmEvent:Fire(position, reward)
	end)
	ReplicatedStorage.Remote.Tower.TowerUpgrade.OnClientEvent:Connect(function(cf)
		self.PlayParticle(nil, 'UpgradeEffect', cf.Position + Vector3.new(0, 4, 0), 2)
	end)
	InitTowerSwitchVisual(); GradientSpin(); GradientHorizontalMove(); GradientVerticalMove(); InitEnemyLoot()
end

function self.FormatNumber(num)
	local suffixes = {
		"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"
	}

	local index = 1

	while num >= 1000 and index < #suffixes do
		num = num / 1000
		index += 1
	end

	if index == 1 then
		return tostring(math.floor(num))
	end

	local formatted = string.format("%.2f", num)

	-- 去掉末尾无用的0
	formatted = formatted:gsub("%.?0+$", "")

	return formatted .. suffixes[index]
end

function self.PlayParticle(_, name, pos, time)
	self.ParticleModule.Play(name, pos, time)
end
function PlayTowerParticle(_, towerUID, pos, time, orientation)
	local towerType = TowerData.GetTowerTypeByTowerUID(towerUID)
	local name = 'BR' .. tostring(towerType) .. 'Particle'
	self.ParticleModule.Play(name, pos, time, orientation)
end

function self.EnableGuideArrow(BeamName)
    self.DisableGuideArrow()

    self.GuideArrow = ReplicatedStorage.Assets.Beams[BeamName]:Clone()
    self.GuideArrow.Parent = workspace:WaitForChild('Visuals')
    local humanoidRootPart = Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart')

    local beamAttachment = humanoidRootPart:FindFirstChild('BeamAttachment')
    if beamAttachment == nil then
        beamAttachment = Instance.new('Attachment')
        beamAttachment.Name = 'BeamAttachment'
        beamAttachment.Parent = humanoidRootPart
    end

    self.GuideArrow.Attachment1 = beamAttachment
end
function self.DisableGuideArrow()
    if self.GuideArrow ~= nil then
        -- print('destroy')
        self.GuideArrow:Destroy()
        -- self.GuideArrowDisableEvent:Fire()
    end
end

function self.SetTowerHighlight(rig, fillColor, fillTransparency, outlineTransparency)
	towerHighlight.Adornee = rig
	towerHighlight.FillColor = fillColor or Color3.fromRGB(255, 255, 255)
	towerHighlight.FillTransparency = fillTransparency or 0.6
	towerHighlight.OutlineTransparency = outlineTransparency or 0
	towerHighlight.Enabled = true
end
function self.ClearTowerHighlight()
	towerHighlight.Enabled = false
	towerHighlight.Adornee = nil
end

-- 鼠标指向显示幽灵塔
function self.ShowTowerOnMouse(modelName, towerUID)
	local targetTower = ReplicatedStorage.Assets.Towers:FindFirstChild(modelName)
	if not targetTower then print('targetTower not found'); return end 

	--- 初始化幽灵塔
	visualTower = targetTower:Clone()
	visualTower = shared.TowerHandler.InitTowerModel(towerUID, visualTower)
	for _, v in visualTower:GetDescendants() do
		if v:IsA('BasePart') then
			v.CanCollide = false
			v.Anchored = true
			v.CanQuery = false
		end
	end

	--- 根据数据设置防御塔Range
	local data = TowerData.GetData(towerUID)
	visualTower.Circle.Size = Vector3.new(data.Range*2, visualTower.Circle.Size.Y, data.Range*2)

	visualTower.Parent = visualFolder
	self.SetTowerHighlight(visualTower:FindFirstChildWhichIsA('Model'), Color3.fromRGB(206, 202, 202), .5, .5)
	-- shared.VFXHandler.AttackRangeVisualEvent:Fire(visualTower.Circle, true)
	---

	self.CurGrid[1], self.CurGrid[2] = 3, 3
	visualTower:PivotTo(shared.GridHandler.GridToWorld(self.CurGrid[1], self.CurGrid[2]))
	shared.GridHandler.SpawnGhostCell(self.CurGrid[1], self.CurGrid[2], shared.ShapeData[data.Shape].Cells)
		
	-------  点击按钮时静止移动幽灵塔位置
	local isTouching = false
	self.VisualTowerInputBegan = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then isTouching = true end
	end)
	self.VisualTowerInputEnded = UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then isTouching = false end
	end)

	self.VisualTowerConnection = RunService.RenderStepped:Connect(function()
		if isTouching == true then return end

		--- 指到ui时返回
		-- local mousePos = UserInputService:GetMouseLocation()
		-- local guiObjects = playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
		-- for _, gui in guiObjects do
		-- 	if gui.Active == true and gui.Visible == true then return end
		-- end
		---

		self.RayCastHit, self.Ray = shared.Input:PlatformRayCast()
		if self.RayCastHit then
			self.CurGrid[1], self.CurGrid[2] = shared.GridHandler.GetGridXYByRayhitPos(self.RayCastHit.Position)

			visualTower:PivotTo(shared.GridHandler.GridToWorld(self.CurGrid[1], self.CurGrid[2]))

			-- local towerCollections = game.CollectionService:GetTagged('Tower')
			--warn(self.RayCastHit.Instance.Name)
			local isUpgrade = true
			local curUID = shared.GridHandler.GetUIDByGrid(self.CurGrid[1], self.CurGrid[2])
			-- if curUID == nil then isUpgrade = false end
			local curTowerUID = curUID and shared.PlayerDataHandler.GetTowerUIDByUID(curUID)
			-- if curTowerUID == nil then isUpgrade = false end
			if curTowerUID ~= towerUID then isUpgrade = false end
			local nextTowerUID = curTowerUID and TowerData.GetTowerNext(curTowerUID)
			if nextTowerUID == nil then isUpgrade = false end

			if isUpgrade then
				shared.GridHandler.DespawnGhostCell()
				visualTower:PivotTo(HIDDEN_CFRAME)
				local tarTower = shared.Tower.GetByUID(curUID)
				if tarTower == nil then warn('fetch tower error for uid:', curUID); return end

				-- print('set adornee')
				upgradeTowerHighlight.Adornee = tarTower.Rig
				upgradeTowerHighlight.Enabled = true
			else
				upgradeTowerHighlight.Enabled = false
				shared.GridHandler.SpawnGhostCell(self.CurGrid[1], self.CurGrid[2], shared.ShapeData[data.Shape].Cells)
			end
			
			-- if spawnable then
			-- 	highlight.FillColor = Color3.fromRGB(62, 211, 104)
			-- 	visualTower.Circle.Color = Color3.fromRGB(49, 162, 41)
			-- else
			-- 	highlight.FillColor = Color3.fromRGB(208, 0, 0)
			-- 	visualTower.Circle.Color = Color3.fromRGB(208, 0, 0)
			-- end
		else
			upgradeTowerHighlight.Enabled = false
		end

	end)


end
-- 消除幽灵塔
function self.HideTowerOnMouse()
	upgradeTowerHighlight.Enabled = false
	self.ClearTowerHighlight()
	visualTower:Destroy()
	if self.VisualTowerConnection then
		self.VisualTowerConnection:Disconnect()
		self.VisualTowerConnection = nil
	end
	if self.VisualTowerInputBegan then
		self.VisualTowerInputBegan:Disconnect()
		self.VisualTowerInputBegan = nil
	end
	if self.VisualTowerInputEnded then
		self.VisualTowerInputEnded:Disconnect()
		self.VisualTowerInputEnded = nil
	end
end

-- 塔Gui
function GenerateTowerGui(_, _, towerUID, _, _, _, parent)
	local towerData = TowerData.GetData(towerUID)

    local gui =  ReplicatedStorage.Assets.UI.TowerGui:Clone()
    for _, label in gui:GetChildren() do
        if label:IsA('TextLabel') then 
            label.Visible = false
        end
    end
    gui.Level.Visible = true
    gui.Level.Text = 'Lv. ' .. TowerData.GetLvlByTowerUID(towerData.TowerUID)
    local mutId = TowerData.GetMutIdByTowerUID(towerData.TowerUID)
    local mutLabel = gui:FindFirstChild(tostring(mutId))
    if mutLabel then mutLabel.Visible = true end

    gui.Adornee = parent:FindFirstChildOfClass('Model').Gui
    gui.Parent = parent

    return gui
end
-- 塔突变效果
function self.GenerateMutParticle(_, towerUID, model)
	local rig = model:FindFirstChildOfClass('Model')
	local mutId = TowerData.GetMutIdByTowerUID(towerUID)
    if mutId > 1 then
        local particle = ReplicatedStorage.Assets.Particles:FindFirstChild('Mut' .. tostring(mutId)):Clone()
        local center = rig:GetBoundingBox().Position
		local att
		for _, v in rig:GetDescendants() do
			if v.Name == 'AttachmentMid' then att = v; break end
		end
		if att == nil then 
			warn('attMid not found for tower:', towerUID); 
			center = rig:GetBoundingBox().Position
		else
			center = att.WorldCFrame.Position
		end

        particle:PivotTo(CFrame.new(center))
        particle.Parent = model
    end
end

-- 抽塔模型

function RollTower(isVIP)
	local function GetTowerParts(model)
		local parts = gachaPartsCache[model]
		if not parts then
			parts = {}
			for _, v in model:GetDescendants() do
				if v:IsA('BasePart') and v ~= model.PrimaryPart then
					table.insert(parts, v)
				end
			end
			gachaPartsCache[model] = parts
		end
		return parts
	end
	local function SetTowerVisible(model, visible)
		local transparency = visible and 0 or 1
		for _, part in GetTowerParts(model) do
			if part.Transparency ~= transparency then
				part.Transparency = transparency
			end
		end
	end
	local duration = isVIP and 1 or 3

	if #gachaTowers == 0 then
		InitTowerSwitchVisual()
	end

	while not gachaPositioned do
		task.wait(0.1)
	end

	local bySlot = {}
	for i, model in ipairs(gachaTowers) do
		local slot = gachaTowerSlot[i]
		bySlot[slot] = bySlot[slot] or {}
		table.insert(bySlot[slot], model)
	end

	local shown = {}
	for slot, list in bySlot do
		shown[slot] = 1
		SetTowerVisible(list[1], true)
	end

	local slotList = {}
	for slot, list in bySlot do
		if #list > 1 then
			table.insert(slotList, slot)
		end
	end

	local startTime = os.clock()
	local slotCursor = 0
	while os.clock() - startTime < duration do
		local alpha = (os.clock() - startTime) / duration
		task.wait(0.04 + 0.08 * alpha * alpha)

		if #slotList > 0 then
			slotCursor = slotCursor % #slotList + 1
			local slot = slotList[slotCursor]
			local list = bySlot[slot]
			local next = shown[slot] % #list + 1
			SetTowerVisible(list[shown[slot]], false)
			SetTowerVisible(list[next], true)
			shown[slot] = next
		end
	end

	for slot, list in bySlot do
		SetTowerVisible(list[shown[slot]], false)
	end
end
--

--	UI视觉效果 
function GradientSpin()
	local function getAngle(elapsed)
		local angle = (elapsed * SPEED_SPIN) % 360
		if angle > 180 then angle = angle - 360 end
			return angle
	end
	local startTime = os.clock()
	RunService.Heartbeat:Connect(function()
		local angle = getAngle(os.clock() - startTime)
		for _, gradient in CollectionService:GetTagged('Spin') do
			if gradient:IsA('UIGradient') or gradient:IsA('ImageLabel') then
				gradient.Rotation = angle
			end
		end
	end)
end
function GradientHorizontalMove()
	local function getOffset(elapsed)
		local x = math.sin(elapsed * SPEED_OFFSET) 
		return x
	end

	local startTime = os.clock()

	RunService.Heartbeat:Connect(function()
		local offsetX = getOffset(os.clock() - startTime)

		for _, gradient in CollectionService:GetTagged('Horizontal') do
			if gradient:IsA('UIGradient') then
				gradient.Offset = Vector2.new(offsetX, 0)
			end
		end
	end)
end
function GradientVerticalMove()
	local function getOffset(elapsed)
		local x = math.sin(elapsed * SPEED_OFFSET) 
		return x
	end

	local startTime = os.clock()

	RunService.Heartbeat:Connect(function()
		local offsetY = getOffset(os.clock() - startTime)

		for _, gradient in CollectionService:GetTagged('Vertical') do
			if gradient:IsA('UIGradient') then
				gradient.Offset = Vector2.new(0, offsetY)
			end
		end
	end)
end

function EnemyFarm(_, position, reward)
	position = position + Vector3.new(0, .5, 0)

    -- 根据奖励决定视觉金币数量
    local coinCount = math.clamp(math.floor(math.sqrt(reward)), 3, 10)

    local coins = {}

    for i = 1, coinCount do

        local coin = shared.ObjectPool.Get("Loot")

        coin:PivotTo(CFrame.new(position))
        coin.Trail.Enabled = true

        local angle = rng:NextNumber(0, math.pi * 2)
        local speed = rng:NextNumber(8, 14)

        coins[i] = {
            Model = coin,

            State = "Scatter",
            Time = 0,
            Delay = (i - 1) * 0.02,

            Start = position,

            -- 初速度（爆开）
            Velocity = Vector3.new(
                math.cos(angle) * speed,
                rng:NextNumber(10, 14),
                math.sin(angle) * speed
            ),
        }
    end

    local gravity = 45

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)

        local finished = 0

        local character = Players.LocalPlayer.Character
        if not character or not character.PrimaryPart then
            return
        end

        local playerPos = character.PrimaryPart.Position

        for _, coin in ipairs(coins) do

            coin.Time += dt

            if coin.State == "Scatter" then

                local t = coin.Time

                local pos =
                    coin.Start +
                    coin.Velocity * t +
                    Vector3.new(0, -0.5 * gravity * t * t, 0)

                -- 掉到地面
                if pos.Y <= coin.Start.Y then

                    pos = Vector3.new(
                        pos.X,
                        coin.Start.Y,
                        pos.Z
                    )

                    coin.Model:PivotTo(CFrame.new(pos))

                    coin.State = "Wait"
                    coin.Time = 0

                    -- 记录落地位置
                    coin.Start = pos

                else

                    coin.Model:PivotTo(CFrame.new(pos))

                end

            elseif coin.State == "Wait" then

                if coin.Time >= 0.25 + coin.Delay then
                    coin.State = "Collect"
                    coin.Time = 0
                end

            elseif coin.State == "Collect" then

                local alpha = math.clamp(coin.Time / 0.4, 0, 1)

                -- EaseOut，让最后越来越快
                alpha = 1 - (1 - alpha) ^ 3

                local pos = coin.Start:Lerp(playerPos, alpha)

                coin.Model:PivotTo(CFrame.new(pos))

                if alpha >= 1 then

                    coin.Model.Trail.Enabled = false
					shared.SoundHandler:Play('Collect_Coin')
                    shared.ObjectPool.Return("Loot", coin.Model)

                    coin.State = "Done"

                end

            elseif coin.State == "Done" then

                finished += 1

            end

        end

        if finished == #coins then
            connection:Disconnect()
        end

    end)

end

function InitTowerParticle()
	local playerInv = shared.PlayerDataHandler.GetData().Tower.Inv

	for _, tower in playerInv do
		if tower.GridXY ~= nil then
			local towerType = TowerData.GetTowerTypeByTowerUID(tower.TowerUID)
			local name = 'BR' .. tostring(towerType) .. 'Particle'
			self.ParticleModule.ParticleInit(name, nil, 'TowerParticle')
		end
	end
end
function InitEnemyLoot()
	local template = ReplicatedStorage.Assets.Parts.Cash

	shared.ObjectPool.Create('Loot', template, nil, 'Loot')
end

function InitTowerSwitchVisual()
    local towerFolder = ReplicatedStorage.Assets.Parts.GachaTower

	gachaTowers = {}
	gachaPartsCache = {}
	gachaTowerSlot = {}
	gachaPositioned = false

    for _, template in towerFolder:GetChildren() do
		local model = template:Clone()
		for _, v in model:GetDescendants() do
			if v:IsA('BasePart') then
				v.Anchored = true
				v.CanCollide = false
				v.CanQuery = false
				v.CanTouch = false
				v.CastShadow = false
				v.Transparency = 1
			end
		end
		if workspace.StreamingEnabled then
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end
		model.Parent = workspace
		table.insert(gachaTowers, model)
    end


	task.spawn(function()
		local machine
		while true do
			machine = shared.GridHandler and shared.GridHandler.GachaMachine
			if machine and machine.SpawnPos and #machine.SpawnPos:GetChildren() >= 3 then
				break
			end
			task.wait(0.1)
		end

		local slots = {}
		for _, v in machine.SpawnPos:GetChildren() do
			table.insert(slots, v.WorldCFrame)
		end

		local slotIndex = 0
		for i, model in ipairs(gachaTowers) do
			if #slots > 0 then
				slotIndex = slotIndex % #slots + 1
				model:PivotTo(slots[slotIndex])
			end
			gachaTowerSlot[i] = slotIndex
		end

		ContentProvider:PreloadAsync(gachaTowers)

		gachaPositioned = true
	end)
end

--------------------------------------------	射线
function self.ShowGuideBeam(modelName, part1, offset1, part2, offset2)
	self.HideGuideBeam()

	if not part1 or not part2 then return end

	local attachment1 = Instance.new('Attachment')
	attachment1.Name = 'GuideBeam_0'
	attachment1.Orientation = part1.Orientation
	attachment1.CFrame += offset1 or Vector3.zero
	attachment1.Parent = part1

	local attachment2 = Instance.new('Attachment')
	attachment2.Name = 'GuideBeam_1'
	attachment2.Orientation = part2.Orientation
	attachment2.CFrame += offset2 or Vector3.zero
	attachment2.Parent = part2

	local template = ReplicatedStorage.Assets.Beams:FindFirstChild(modelName)
	if not template then warn('guide beam model not found:', modelName)
		attachment1:Destroy()
		attachment2:Destroy()
		return
	end

	local clone = template:Clone()
	for _, beam in clone:GetDescendants() do
		if beam:IsA('Beam') then
			beam.Attachment0 = attachment1
			beam.Attachment1 = attachment2
		end
	end

	clone.Parent = visualFolder
	self.GuideBeam = clone
	self.GuideBeamAttachments = {attachment1, attachment2}
end
function self.HideGuideBeam()
	if self.GuideBeam then
		self.GuideBeam:Destroy()
		self.GuideBeam = nil
	end
	if self.GuideBeamAttachments then
		for _, attachment in self.GuideBeamAttachments do
			attachment:Destroy()
		end
		self.GuideBeamAttachments = nil
	end
end
function self.CreateMergeBeam(modelName, part1, part2)
	self.HideMergeBeam()

	if not part1 or not part2 then return end

	local attachment1 = Instance.new('Attachment')
	attachment1.Name = 'GuideBeam_0'
	attachment1.Parent = part1

	local attachment2 = Instance.new('Attachment')
	attachment2.Name = 'GuideBeam_1'
	attachment2.CFrame += Vector3.new(0, 6, 0)
	attachment2.Parent = part2

	local template = ReplicatedStorage.Assets.Beams:FindFirstChild(modelName)
	if not template then warn('guide beam model not found:', modelName)
		attachment1:Destroy()
		attachment2:Destroy()
		return
	end

	local clone = template:Clone()
	for _, beam in clone:GetDescendants() do
		if beam:IsA('Beam') then
			beam.Attachment0 = attachment1
			beam.Attachment1 = attachment2
		end
	end

	clone.Parent = visualFolder
	self.MergeBeams = self.MergeBeams or {}
	table.insert(self.MergeBeams, clone)
	self.MergeBeamAttachments = self.MergeBeamAttachments or {}
	table.insert(self.MergeBeamAttachments, {attachment1, attachment2})
end
function self.HideMergeBeam()
	if self.MergeBeams then
		for _, beam in self.MergeBeams do
			beam:Destroy()
		end
		self.MergeBeams = nil
	end
	if self.MergeBeamAttachments then
		for _, attachments in self.MergeBeamAttachments do
			for _, attachment in attachments do
				attachment:Destroy()
			end
		end
		self.MergeBeamAttachments = nil
	end
end

function self.ToggleAllPrompt(isShow)
	for _,other in Players:GetPlayers() do
		if other ~= Players.LocalPlayer and other.Character then
			local prompt = other.Character:FindFirstChild("GiftPrompt", true)

			if prompt then
				prompt.Enabled = isShow
			end
		end
	end
end

--	图腾旋转特效（游戏开始时开启，结束时关闭）
local TOTEM_SPIN_SPEED = math.rad(90)

function self.StartTotemSpin()
	self.StopTotemSpin()

	local area = shared.GridHandler and shared.GridHandler.Area
	local totem = area and area:FindFirstChild('Totem')
	if totem == nil then return end

	local particles = totem.Particles.Value
	if particles then self.ParticleModule.ToggleVisual(particles, true) end

	local spinModel = totem.SpinModel.Value
	if spinModel == nil then return end

	local lastTick = os.clock()
	self.TotemSpinConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local delta = now - lastTick
		lastTick = now
		spinModel:PivotTo(spinModel:GetPivot() * CFrame.Angles(0, delta * TOTEM_SPIN_SPEED, 0))
	end)
end

function self.StopTotemSpin()
	if self.TotemSpinConnection then
		self.TotemSpinConnection:Disconnect()
		self.TotemSpinConnection = nil
	end

	local area = shared.GridHandler and shared.GridHandler.Area
	local totem = area and area:FindFirstChild('Totem')
	if totem == nil then return end

	local particles = totem.Particles.Value
	if particles then self.ParticleModule.ToggleVisual(particles, false) end
end

return self
