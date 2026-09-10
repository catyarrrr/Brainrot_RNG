local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local ItemData = require(ReplicatedStorage.Datas.ItemData :: ModuleScript)
local QuestData = require(ReplicatedStorage.Datas.QuestData :: ModuleScript)

local player = Players.LocalPlayer
local self : any = {NoticeRunning = false, }
local NOTICE_DISAPPEAR, NOTICE_INTERVAL = 1.5, .4
local AddClickEffect, InitAfterData, UIInit, CashFrameInit, CashFrameUpdate, StageGuiBtnUpdate, BaseBtnInit, AddNotice = nil

function self.init()
	self.TriggerTraitEvent = shared.Event.new()
	self.TriggerCloneEvent = shared.Event.new()
	self.TriggerEvoEvent = shared.Event.new()
	self.TriggerTowerDetailEvent = shared.Event.new()
	self.TriggerVIPDailyEvent = shared.Event.new()
	self.TriggerFreeRewardEvent = shared.Event.new()
	self.TriggerWheelEvent = shared.Event.new()
	self.TriggerRushEvent = shared.Event.new()
    self.ToggleTopUIEvent = shared.Event.new()
	self.NewBossBarEvent = shared.Event.new()
	self.UpdateBossBarEvent = shared.Event.new()
	self.TriggerFuseEvent = shared.Event.new()
end

function self.start()
	if player.Character then
		UIInit()
	else
		player.CharacterAdded:Connect(function() UIInit() end)
	end
	shared.PlayerDataHandler.DataChangedEvent:Connect(DataChangeUpdate)
	self.TriggerVIPDailyEvent:Connect(function(_, isShow)
		if isShow == false then self.VIPDailyUI:Close(); return end
		local playerData = shared.PlayerDataHandler.GetData()
		if playerData == nil then return end
		-- if playerData.VIP.VIP == false then
		-- 	shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_VIP)
		-- 	return 
		-- end
		self.VIPDailyUI.Update(playerData)
		self.VIPDailyUI:Open()
	end)
	self.TriggerTowerDetailEvent:Connect(function(_, isShow, towerData, isTool) 
		if isShow then self.RightFrame.Visible = false else self.RightFrame.Visible = true end
		self.TowerDetailUI.Trigger(isShow, towerData, isTool) 
	end)
	self.TriggerFreeRewardEvent:Connect(function() self.FreeRewardUI.Update(); self.FreeRewardUI:Open() end)
	self.TriggerWheelEvent:Connect(function() 
		ReplicatedStorage.Remote.PlayerSpinUpdate:FireServer()
		self.WheelUI.Update(shared.PlayerDataHandler.GetData())
		self.WheelUI:Open()
	end)
	self.TriggerRushEvent:Connect(function()
		self.BossUI.Update(shared.PlayerDataHandler.GetData())
		self.BossUI:Open()
	end)
	self.TriggerTraitEvent:Connect(function(_, isShow) 
		if isShow then
			self.TraitUI.Update(shared.PlayerDataHandler.GetData())
			self.TraitUI:Open()
		else
			self.TraitUI:Close()
		end
	end)
	self.TriggerEvoEvent:Connect(function(_, isShow) 
		if isShow then
			self.EvoUI.Update(shared.PlayerDataHandler.GetData())
			self.EvoUI:Open()
		else
			self.EvoUI:Close()
		end
	end)
	self.TriggerFuseEvent:Connect(function(_, isShow) 
		if isShow then self.FuseUI:Open() else self.FuseUI:Close() end
	end)
	self.TriggerCloneEvent:Connect(function(_, isShow)
		if isShow then
			self.CloneUI.Update(shared.PlayerDataHandler.GetData())
			self.CloneUI:Open()
		else
			self.CloneUI:Close()
		end
	end)
	self.ToggleTopUIEvent:Connect(function(_, isShow) self.TopUI.Main:Visible(isShow) end)
	self.NewBossBarEvent:Connect(function(_, curHP, maxHP) self.TopUI.ShowRushBossBar(true, maxHP) end)
	self.UpdateBossBarEvent:Connect(function(_, curHP, maxHP) self.TopUI.UpdateBossBar(curHP, maxHP) end)
	ReplicatedStorage.Remote.ServerWarn.OnClientEvent:Connect(self.ServerWarn)
	ReplicatedStorage.Remote.ServerTip.OnClientEvent:Connect(function(text) AddNotice(text) end)
	ReplicatedStorage.Remote.Game.GameLoot.OnClientEvent:Connect(NoticeReward)
	ReplicatedStorage.Remote.PlayerClaimOfflineReward.OnClientEvent:Connect(NoticeReward)
	ReplicatedStorage.Remote.Loot.OnClientEvent:Connect(NoticeReward)
	ReplicatedStorage.Remote.PlayerClaimLoginReward.OnClientEvent:Connect(NoticeReward)
	ReplicatedStorage.Remote.PlayerSpin.OnClientEvent:Connect(function(wheelConfig) self.WheelUI.Spin(wheelConfig.Rotate) end)
	ReplicatedStorage.Remote.PlayerGift.OnClientEvent:Connect(function(otherPlayer, isShow, isGive, alienName)
		if isShow == true then
			if isGive == true then
				self.GiftUI:Open()
				self.GiftUI.ToggleGiver(otherPlayer, alienName)
			else
				self.GiftUI:Open()
				self.GiftUI.ToggleReceiver(otherPlayer, alienName)
			end
		else
			self.GiftUI:Close()
		end
	end)
	ReplicatedStorage.Remote.Tower.RollTrait.OnClientEvent:Connect(function(uid, traitId)
		self.TraitUI.Trait(shared.PlayerDataHandler.GetData())
	end)
	ReplicatedStorage.Remote.ServerLuck.OnClientEvent:Connect(function(endtime)
		while not self.InitCompleted do task.wait() end

		self.EventUI.Event('Luck', endtime)
	end)
	ReplicatedStorage.Remote.MKEvent.OnClientEvent:Connect(function(foods, time) 
		-- print(foods, time)
		if foods == nil then
			self.EventUI.EndEvent('SixSevenFeast')
			self.MKEventUI.Update(foods, time) 
			self.EventUI.Event('BigMut', time)
		else
			self.MKEventUI.Update(foods, time) 
		end

	end)
	shared.Game.GameEndedEvent:Connect(function(_, round) if not shared.Game.Rush then self.TopUI.TogglePupOut(round) end end)
	shared.Game.GameStartedEvent:Connect(function() if shared.Game.Rush then self.BossUI:Close() end end)
	GuiService.MenuOpened:Connect(function()
		self.AFKUI.ToggleAFKHUD(shared.PlayerDataHandler.GetData(), true)
	end)
	GuiService.MenuClosed:Connect(function()
		self.AFKUI.ToggleAFKHUD(shared.PlayerDataHandler.GetData(), false)
	end)
end

function self.ServerWarn(text, pos)
	if self.Warn == nil then return end

	task.spawn(function()
		self.Warn.Visible = true
		self.Warn.Position = pos or UDim2.new(0.5, 0, 0.725, 0)
		self.Warn.TextSize = 24
		self.Warn.Text = text
		self.Warn.TextColor3 = Color3.fromRGB(255, 0, 21)
		self.Warn.Parent = self.MainGui
		self.Warn.TextTransparency = .5
	
		for i = 1, 3 do
			self.Warn.TextTransparency = .5
			local fadeIn = TweenService:Create(self.Warn, TweenInfo.new(.25), {TextTransparency = 0})
			fadeIn:Play()
			fadeIn.Completed:Wait()
			
			local fadeOut = TweenService:Create(self.Warn, TweenInfo.new(.25), {TextTransparency = .5})
			fadeOut:Play()
			fadeOut.Completed:Wait()
		end
		self.Warn.Visible = false
	end)
end

function UIInit()
	if self.Initiated == true then return end
	self.Initiated = true

	self.PlayerGui = player:WaitForChild('PlayerGui')
	self.WorldGui = self.PlayerGui:WaitForChild('WorldGui')
	self.StageBtnGui = self.WorldGui:WaitForChild('StageBtn')
	self.TaskGui = self.WorldGui:WaitForChild('TaskFrame')
	self.BaseBtnGui = self.WorldGui:WaitForChild('BaseBtn')
	self.LuckBtnGui = self.WorldGui:WaitForChild('LuckBtn')
	self.TotemGui = self.WorldGui:WaitForChild('TotemFrame')
	self.MainGui = self.PlayerGui:WaitForChild('MainGui')
	self.MainGui.Enabled = true
	self.Hud = self.MainGui:WaitForChild('Hud')
	self.Hud.Visible = true
	self.Menu = self.MainGui:WaitForChild('Menu')
	self.Menu.Visible = true
	self.PopUp = self.MainGui:WaitForChild('PopUp')
	self.PopUp.Visible = true
	self.Warn = self.PopUp.Warn
	self.Notice = self.PopUp.Notice
	self.Notice.Visible = true
	self.Guide = self.PopUp.Guide
	self.Guide.Visible = false
	self.GuideCover = self.PopUp.GuideCover
	self.GuideCover.Visible = false
	self.RightFrame = self.Hud.Right
	self.RightFrame.Visible = true
	self.MergeBtn = self.PopUp.QuickMerge
	self.MergeBtn.Visible = false
	self.Announcements = self.PopUp.Announcements
	self.Announcements.Visible = false
	self.Announcements.Close.MouseButton1Click:Connect(function() self.Announcements.Visible = false end)

	for _, item in pairs(script:GetChildren()) do
		if item:IsA('Folder') then
			for _, moduleScript in pairs(item:GetChildren()) do
				if moduleScript:IsA('ModuleScript') then
					self[moduleScript.Name] = require(moduleScript)
					local ok, err = pcall(function() self[moduleScript.Name].Init(self.MainGui) end)
					if not ok then warn(`{moduleScript.Name} Init error: {err}`) end
				end
			end
		end
	end

	self.TouchUI = require(script.TouchUI)
	self.TouchUI.Init(self.MainGui)

	task.spawn(function()
		for _, btn in CollectionService:GetTagged('Btn') do
			AddClickEffect(btn)
		end
		CollectionService:GetInstanceAddedSignal('Btn'):Connect(AddClickEffect)
	end)
	
	InitAfterData()
end
function InitAfterData()
	task.spawn(function()
		while not shared.PlayerDataHandler.InitData do task.wait() end
		local playerData = shared.PlayerDataHandler.GetData()

		task.spawn(function()--	领地初始化之后进行的初始化
			while shared.GridHandler.Initiated == false do task.wait() end

			-- StageSurfaceGuiInit(playerData)
			TaskSurfaceGuiInit(playerData)
			BaseBtnInit(playerData)
			self.LuckBtnGui.Adornee = shared.GridHandler.GachaMachine.Luckpoint
			self.LuckBtnGui.TextButton.MouseButton1Click:Connect(function()
				local playerData = shared.PlayerDataHandler.GetData()
				local doubleluck = playerData.VIP.DoubleLuck
				local tripleluck = playerData.VIP.TripleLuck
				local luckLevel = playerData.Gacha.Luck
				if doubleluck then luckLevel -= 1 end
				if tripleluck then luckLevel -= 1 end
    			local luckData = TempData.LuckDict[luckLevel]
				if luckData.NextCost == nil then
					if doubleluck == false then
						shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_2XLuck)
					elseif tripleluck == false then
						shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_3XLuck)
					else 
						shared.BuyHandler.BuyProduct(shared.ProductDatas['2xServerLuck'])
					end
				else
					ReplicatedStorage.Remote.PlayerUpgradeLuck:FireServer()
				end
			end)

			-- self.TotemGui.Adornee = shared.GridHandler.Area.TotemPos
			-- local prayCashDebounce = false
			-- self.TotemGui.Frame.Frame.PrayCash.MouseButton1Click:Connect(function()
			-- 	if prayCashDebounce then return end
			-- 	prayCashDebounce = true
			-- 	ReplicatedStorage.Remote.Tower.PrayTotem:FireServer()
			-- 	task.wait(3)
			-- 	prayCashDebounce = false
			-- end)
			-- self.TotemGui.Frame.Frame.PrayRBX.MouseButton1Click:Connect(function()
			-- 	shared.BuyHandler.BuyProduct(shared.ProductDatas.PrayTotem)
			-- end)
			-- self.TotemGui.Frame.Frame.x10PrayRBX.MouseButton1Click:Connect(function()
			-- 	shared.BuyHandler.BuyProduct(shared.ProductDatas.PrayTotemx10)
			-- end)
		end)
		self.TopUI.BestWaveFrame.TextLabel.Text = playerData.Profile.MaxLevel
		self.TopUI.BestWave = playerData.Profile.MaxLevel
		self.TopUI.Update(playerData)
		CashFrameInit()
		CashFrameUpdate(playerData)
		self.RightUI.Update(playerData)
		self.RightUI.TopBarInit(playerData)
		self.AFKUI.Update(playerData)
		self.EventUI.Update(playerData.States.Event)
		self.MergeBtn.MouseButton1Click:Connect(function()
			local tool = player.Character:FindFirstChildOfClass('Tool')
			if tool == nil then warn('tool not found for upgrade'); return end

			ReplicatedStorage.Remote.Tower.QuickMerge:FireServer(tool:GetAttribute('TargetId'))
		end)
		
		local now = workspace:GetServerTimeNow()
		local today = math.floor(now / 86400)
		if playerData.States.LoginReward.Day <= shared.Config.LOGIN_MAXDAY and playerData.States.LoginReward.LastLoginDay ~= today then
			self.DailyUI.Update(playerData)
			self.DailyUI:Open()
		end
		if playerData.States.WeeklyDaily.LastLoginDay ~= today and playerData.States.LoginReward.Day > shared.Config.LOGIN_MAXDAY then
			self.WeeklyDailyUI.Update(playerData)
			self.WeeklyDailyUI:Open()
		end
		
		Players.PlayerRemoving:Connect(function() CashFrameUpdate(playerData) end)
		Players.PlayerAdded:Connect(function() CashFrameUpdate(playerData) end)

		self.InitCompleted = true
	end)
end
function DataChangeUpdate(_, tag)
	local playerData = shared.PlayerDataHandler.GetData()
	if tag and table.find(tag, 'Terr') then
		self.UpgradeUI.Update()
	end
	if tag and table.find(tag, 'TowerInv') then
		self.AlienUI.Update(playerData)
	end
	if tag and table.find(tag, 'AutoMerge') then
		self.AlienUI.Update(playerData)
	end
	if tag and table.find(tag, 'Cash') then
		CashFrameUpdate(playerData)
	end
	if tag and table.find(tag, 'Item') then
		self.FuseUI.RefreshRequired()
	end
	if tag and table.find(tag, 'Event') then
		self.EventUI.Update(playerData.States.Event)
	end
	if tag and table.find(tag, 'VIP') then
		self.StoreUI.Update(playerData.VIP)
		self.RightUI.UpdateVIP(playerData.VIP)
	end
	if tag and table.find(tag, 'Rush') then
		self.BossUI.Update(playerData)
	end
	if tag and table.find(tag, 'VIPDaily') then
		self.VIPDailyUI.Update(playerData)
	end
	if tag and table.find(tag, 'Grid') then
		self.TopUI.Update(playerData)
		BaseBtnUpdate(playerData)
		self.UpgradeUI.Update()
	end
	if tag and table.find(tag, 'Task') then
		shared.SoundHandler:Play('Operate_Success')
		CashFrameUpdate(playerData)
		TaskGuiBtnUpdate(playerData)
	end
	if tag and table.find(tag, 'Wheel') then
		self.WheelUI.Update(playerData)
		CashFrameUpdate(playerData)
	end
	if tag and table.find(tag, 'WheelUpdate') then
		self.WheelUI.Countdown(playerData)
	end
	if tag and table.find(tag, 'Level') then
		self.TopUI.Update(playerData)
	end
	if tag and table.find(tag, 'OfflineReward') then
		CashFrameUpdate(playerData)
		self.AFKUI.AFKFrame.Visible = false
	end
	if tag and table.find(tag, 'LoginReward') then
		self.DailyUI.Update(playerData)
		CashFrameUpdate(playerData)
	end
	if tag and table.find(tag, 'Trait') then
		self.TraitUI.Update(playerData)
	end
	if tag and table.find(tag, 'Clone') then
		self.CloneUI.Update(playerData)
	end
	if tag and table.find(tag, 'CloneCompleted') then
		self.CloneUI.Selected = nil
		self.CloneUI.Update(playerData)
	end
	if tag and table.find(tag, 'Evolve') then
		self.EvoUI.Update(playerData)
	end
	if tag and table.find(tag, 'EvolveCompleted') then
		self.EvoUI.Selected = nil
		self.EvoUI.Update(playerData)
	end
	if tag and table.find(tag, 'Totem') then
		self.TotemUI.Update()
	end
	if tag and table.find(tag, 'WeeklyDaily') then
		self.WeeklyDailyUI.Update(playerData)
	end
	if tag and table.find(tag, 'TotemUpgrade') then
		shared.SoundHandler:Play('FeedTotem')
		self.TotemUI.UpgradeEffect()
		self.TotemUI.Update()
	end
end

--	cash面板
function CashFrameInit()
	self.CashFrame = self.Hud.LeftCorner

	self.CashFrame.InviteButton.MouseButton1Click:Connect(function()
		SocialService:PromptGameInvite(player)
	end)

end
function CashFrameUpdate(playerData)
	local cash = playerData.Coin.Cash
	local gems = playerData.Coin.Gems

	self.CashFrame.CashCount.CashCountText.Text = '$' .. shared.VFXHandler.FormatNumber(cash)
	self.CashFrame.GemsCount.GemsCountText.Text = shared.VFXHandler.FormatNumber(gems)
	local friendBoost = 0
	
	for _, plr in Players:GetPlayers() do
		if plr ~= Players.LocalPlayer and Players.LocalPlayer:IsFriendsWithAsync(plr.UserId) then
			friendBoost += shared.Config.COIN_FRIENDBOOST * 100
		end
	end

	self.CashFrame.CashText.Text = string.format('Friends Cash Boost: %d%%', friendBoost)
end

--	Task面板
function TaskSurfaceGuiInit(playerData)
	task.spawn(function()
		while shared.GridHandler.Initiated == false do
			task.wait()
		end

		self.TaskGui.Task1.ClaimButton.MouseButton1Click:Connect(function()
			ReplicatedStorage.Remote.PlayerClaimTask:FireServer(1)
		end)
		self.TaskGui.Task2.ClaimButton.MouseButton1Click:Connect(function()
			ReplicatedStorage.Remote.PlayerClaimTask:FireServer(2)
		end)
		self.TaskGui.Task3.ClaimButton.MouseButton1Click:Connect(function()
			ReplicatedStorage.Remote.PlayerClaimTask:FireServer(3)
		end)
		self.TaskGui.Adornee = shared.GridHandler.TaskModel.Main
		
		TaskGuiBtnUpdate(playerData)

		--	Tips切换提醒
		local tipsFrame = self.TaskGui:WaitForChild('Tips')
		local tipLabels = {}
		for _, child in tipsFrame:GetChildren() do
			if child:IsA('TextLabel') then
				table.insert(tipLabels, child)
				child.Visible = false
			end
		end
		task.spawn(function()
			local currentIndex = 0
			while true do
				currentIndex = currentIndex % 6 + 1
				local label = tipLabels[currentIndex]
				if label then
					for _, other in tipsFrame:GetChildren() do
						if other:IsA('TextLabel') then
							other.Visible = false
						end
					end
					label.Visible = true
				end
				task.wait(60)
			end
		end)
	end)
end
function TaskGuiBtnUpdate(playerData)

	for line = 1, 3 do
		local key, text
		for k, v in playerData.Task[QuestData[line].DataName] do
			if v == false then key = k; break end
		end
		if key == nil then 
			self.TaskGui:FindFirstChild('Task'.. tostring(line)).Visible = false
			continue
		end

		local taskConfig = QuestData[line][key]

		if taskConfig.Type == 2 then
			--	收集
			text = string.format('Collect %d different Brainrots', taskConfig.Collect)
			self.TaskGui:FindFirstChild('Task'.. tostring(line)).ClaimButton.TextLabel.Text = string.format('%s \n Claim!', shared.Tool.FormatNumber(taskConfig.Reward)
)
		elseif taskConfig.Type == 3 then
			--	基地
			text = string.format('Raise base level to %d', taskConfig.NeedLevel)

		elseif taskConfig.Type == 4 then
			--	幸运
			text = string.format('Raise luck level to %d', taskConfig.NeedLevel)

		elseif taskConfig.Type == 5 then
			--	现金
			text = string.format('Raise cashMultiplier level to %d', taskConfig.NeedLevel)

		elseif taskConfig.Type == 6 then
			--	关卡
			text = string.format('Reach Wave %d', taskConfig.NeedLevel)

		elseif taskConfig.Type == 7 then
			--	开始波次
			text = string.format('Raise startingwave level to %d', taskConfig.NeedLevel)

		end

		if taskConfig.Type ~= 2 then
			local packName = self.TaskGui:FindFirstChild('Task'.. tostring(line)).ClaimButton.PackName
			for _, child in packName:GetChildren() do
				if child:IsA('TextLabel') and child.Name == tostring(taskConfig.Reward) then
					child.Visible = true
				else
					child.Visible = false
				end
			end
		end

		self.TaskGui:FindFirstChild('Task'.. tostring(line)).TaskDesc.Text = text
	end
	
end
--	基地升级按钮
function BaseBtnInit(playerData)
	self.BaseBtnGui:WaitForChild('CashButton').MouseButton1Click:Connect(function()
		ReplicatedStorage.Remote.PlayerUpgradeGrid:FireServer()
	end)
	self.BaseBtnGui.Adornee = shared.GridHandler.UpgradeModel.Panel

	BaseBtnUpdate(playerData)
end
function BaseBtnUpdate(playerData)
	local baseLevel = TempData.GetLevelByGrid(playerData.Grid)
    local data1, data2 = TempData.BaseDict[baseLevel], TempData.BaseDict[baseLevel+1]
    if data2 == nil then
        self.BaseBtnGui.CashButton.CostText.Text = 'MAX'
    else
        self.BaseBtnGui.CashButton.CostText.Text = shared.VFXHandler.FormatNumber(data1.NextCost)
    end
end
-- Notice
function AddNotice(text)
	if text == nil then warn('notice nil error'); return end

	if self.NoticeQueue == nil then self.NoticeQueue = shared.Queue.new() end
	self.NoticeQueue:Push(text)

	if self.NoticeRunning then
		return
	end

	self.NoticeRunning = true

	while not self.NoticeQueue:IsEmpty() do
		local message = self.NoticeQueue:Pop()

		local clone = self.Notice.Template:Clone()
		clone.Text = message
		clone.TextTransparency = 1
		clone.Visible = true
		clone.Parent = self.Notice

		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(clone, tweenInfo, {TextTransparency = 0}):Play()

		Debris:AddItem(clone, NOTICE_DISAPPEAR)
		shared.SoundHandler:Play('Collect_Loot')

		task.wait(NOTICE_INTERVAL)
	end

	self.NoticeRunning = false
end
function NoticeReward(rewardData)
	if rewardData.Cash and rewardData.Cash > 0 then
		local itemMessage = 'x' .. shared.Tool.FormatNumber(rewardData.Cash) .. ' Cash'
		local text = string.format('You got %s !!', shared.Tool.RichColor(itemMessage, Color3.fromRGB(255, 252, 67)))
		AddNotice(text)
	end
	if rewardData.Gems and rewardData.Gems > 0 then
		local itemMessage = 'x' .. shared.Tool.FormatNumber(rewardData.Gems) .. ' Gems'
		local text = string.format('You got %s !!', shared.Tool.RichColor(itemMessage, Color3.fromRGB(120, 255, 180)))
		AddNotice(text)
	end
	if rewardData.Items then
		for itemId, amount in pairs(rewardData.Items) do
			local staticData = ItemData[tonumber(itemId)]
			local itemMessage = 'x' .. tostring(amount) .. ' ' .. staticData.Name
			local text = string.format('You got %s !!', shared.Tool.RichColor(itemMessage, ItemData.GetRGBByItemId(staticData.Id)))
			AddNotice(text)
		end
	end
	if rewardData.Tower then
		local staticData = TowerData.GetData(tonumber(rewardData.Tower))
		local rgb = TowerData.GetRGBByTowerUID(staticData.TowerUID)
		local itemMessage = 'x1 ' .. staticData.DisplayName
		local text = string.format('You got %s !!', shared.Tool.RichColor(itemMessage, rgb))
		AddNotice(text)
	end
end

function self.ToggleGuide(isShow, text)
	if isShow then
		self.Guide.Visible = true
		self.Guide.Text = text
	else	
		self.Guide.Visible = false
	end
end

function self.SetMask(targetFrame)
	self.GuideCover.Visible = true

	local top = self.GuideCover.Top
	local bottom = self.GuideCover.Bottom
	local left = self.GuideCover.Left
	local right = self.GuideCover.Right

	local maskSize = self.GuideCover.AbsoluteSize
	local maskPos = self.GuideCover.AbsolutePosition

	local targetPos = targetFrame.AbsolutePosition - maskPos
	local targetSize = targetFrame.AbsoluteSize

	local x1 = targetPos.X
	local y1 = targetPos.Y
	local x2 = x1 + targetSize.X
	local y2 = y1 + targetSize.Y


	local function XScale(x)
		return x / maskSize.X
	end

	local function YScale(y)
		return y / maskSize.Y
	end


	-- Top
	top.Size = UDim2.fromScale(
		1,
		YScale(y1)
	)

	top.Position = UDim2.fromScale(
		0.5,
		YScale(y1) / 2
	)


	-- Bottom
	local bottomHeight = maskSize.Y - y2

	bottom.Size = UDim2.fromScale(
		1,
		YScale(bottomHeight)
	)

	bottom.Position = UDim2.fromScale(
		0.5,
		YScale(y2) + YScale(bottomHeight) / 2
	)


	-- Left
	left.Size = UDim2.fromScale(
		XScale(x1),
		YScale(targetSize.Y)
	)

	left.Position = UDim2.fromScale(
		XScale(x1) / 2,
		YScale(y1) + YScale(targetSize.Y) / 2
	)


	-- Right
	local rightWidth = maskSize.X - x2

	right.Size = UDim2.fromScale(
		XScale(rightWidth),
		YScale(targetSize.Y)
	)

	right.Position = UDim2.fromScale(
		XScale(x2) + XScale(rightWidth) / 2,
		YScale(y1) + YScale(targetSize.Y) / 2
	)
end
function self.DisableMask()
	self.GuideCover.Visible = false
end


function AddClickEffect(btn)
	local uiScale
	if btn:FindFirstChildOfClass('UIScale') then
		uiScale = btn:FindFirstChildOfClass('UIScale')
	else
		uiScale = Instance.new('UIScale')
		uiScale.Parent = btn
	end

    local activeTween: Tween? = nil

    -- 每次只允许一个 tween 驱动 Scale，避免多个 tween 同时改同一属性互相打架
    local function playTween(tween: Tween)
        if activeTween then
            activeTween:Cancel()
        end
        activeTween = tween
        tween:Play()
    end

    local tweenInfo = TweenInfo.new(.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    btn.MouseEnter:Connect(function()
        playTween(TweenService:Create(uiScale, tweenInfo, {Scale = .9}))
    end)
    btn.MouseLeave:Connect(function()
        playTween(TweenService:Create(uiScale, tweenInfo, {Scale = 1}))
    end)

    btn.MouseButton1Click:Connect(function()
        local baseScale = uiScale.Scale
        local tweenIn = TweenService:Create(uiScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = baseScale * 1.1})
        local tweenOut = TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = baseScale})
        playTween(tweenIn)
        tweenIn.Completed:Connect(function()
            -- 只有当 tweenIn 仍未被取消时，才接着播放回弹动画
            if activeTween == tweenIn then
                playTween(tweenOut)
            end
        end)
    end)
end

return self
 