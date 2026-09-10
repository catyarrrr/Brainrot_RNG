local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)
local RewardData = require(ReplicatedStorage.Datas.Reward :: ModuleScript)
local Init, SwitchGround, StartLoop, GetNextEvent, SpawnInstancesInPart, SpawnEventCash, SpawnMKFood, SpawnFragment, ClaimFragmentReward = nil
local self : any = {}
self.StateDict = {
	Idle = 'Idle',
	GoldMut = 'GoldMut',
	DiamondMut = 'DiamondMut',
	SixSevenFeast = 'SixSevenFeast',
	CashDrop = 'CashDrop',

}

local EnumState = {
    
	Idle = {
		name = 'Idle',

		enter = function(self)
			SwitchGround('Ground')
		end,

		exit = function(self)
			
		end,

	},

	GoldMut = {
		name = 'GoldMut',

		enter = function(self)
			GetNextEvent()
			self.EventChangeEvent:Fire()
			SwitchGround('Gold')
		end,

		exit = function(self)
		end,
	},

	DiamondMut = {
		name = 'DiamondMut',

		enter = function(self)
			self.IsMut = true
			GetNextEvent()
			self.EventChangeEvent:Fire()
			SwitchGround('Diamond')
		end,

		exit = function(self)
			self.IsMut = false
		end,
	},

	SixSevenFeast = {
		name = 'SixSevenFeast',

		enter = function(self)
			GetNextEvent()
			self.EventChangeEvent:Fire()
			--#region 马克
			workspace.NPCs.BR109:ScaleTo(10)
			-- local animationController = workspace.NPCs.TianMaKe:FindFirstChild('AnimationController', true)
			-- if animationController then
			-- 	local animation = animationController:FindFirstChild('EventAnimation')
			-- 	local animator = animationController.Animator
			-- 	if self.MKTrack == nil then
			-- 		self.MKTrack = animator:LoadAnimation(animation)
			-- 		self.MKTrack.Priority = Enum.AnimationPriority.Action
			-- 		self.MKTrack.Looped = true
			-- 	end
			-- 	self.MKTrack:Play()
			-- end	
			--#endregion
			workspace.SceneLogic.MKEvent.ProximityPrompt.Enabled = true
			self.MKPromptConn = workspace.SceneLogic.MKEvent.ProximityPrompt.Triggered:Connect(MKPrompt)
			SpawnMKFood()
			SwitchGround('SixSevenFeast')
		end,

		exit = function(self)
			self.IsMut = false
			ReplicatedStorage.Remote.MKEvent:FireAllClients(nil)
			self.MKPromptConn:Disconnect()
			for _, v in self.MKFoods do v:Destroy() end
			if self.Fragments then
				for _, v in self.Fragments do v:Destroy() end
				self.Fragments = nil
			end
			workspace.NPCs.BR109:ScaleTo(1)
			workspace.SceneLogic.MKEvent.ProximityPrompt.Enabled = false
		end,
	},

	CashDrop = {
		name = 'CashDrop',

		enter = function(self)
			GetNextEvent()
			self.EventChangeEvent:Fire()
			SwitchGround('Cash')
			
			SpawnEventCash()
		end,

		exit = function(self)
			for _, v in self.Cashes do v:Destroy() end
		end,
	},
}

function self.init()
	self.EventChangeEvent = shared.Event.new()
end

function self.start()
	Init()
end 

function Init()
    self.NextEventTime = workspace:GetServerTimeNow() + shared.Config.EVENT_INTERVAL
	GetNextEvent()
    StartLoop()
    self.Initiated = true
end

function StartLoop()
    task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()

            if now > self.NextEventTime then
                self.EventEndTime = now + shared.Config.EVENT_DURATION
				self.NextEventTime = now + shared.Config.EVENT_INTERVAL
				
				self.SetState(self.NextEvent)

				task.delay(shared.Config.EVENT_DURATION, function()
					self.SetState('Idle')
				end)
            end

			task.wait(.2)
		end

	end)
end

function self.AddServerLuck(player)
    if self.ServerLuckEndTime then
        self.ServerLuckEndTime += shared.Config.EVENT_SERVERLUCK_DURATION
    else
        self.ServerLuckEndTime = workspace:GetServerTimeNow() + shared.Config.EVENT_SERVERLUCK_DURATION
    end

    ReplicatedStorage.Remote.ServerLuck:FireAllClients(self.ServerLuckEndTime)
	shared.GachaMachine.UpdateAllEvent:Fire()
	
	ReplicatedStorage.Remote.Message:FireAllClients(player)
	
	if self.ServerLuckThread then
		task.cancel(self.ServerLuckThread)
		self.ServerLuckThread = nil
	end
	self.ServerLuckThread = task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()

			if self.ServerLuckEndTime and now >= self.ServerLuckEndTime then
				self.ServerLuckEndTime = nil
				break
			end

			task.wait(1)
		end

		shared.GachaMachine.UpdateAllEvent:Fire()
		self.ServerLuckThread = nil
	end)
end

function SwitchGround(groundName)
	local ground = workspace.Scenes.Ground
	if ground then ground:Destroy() end
	local curSky = Lighting:FindFirstChildOfClass('Sky')
	if curSky then curSky:Destroy() end

	local newGround = ServerStorage.Ground:FindFirstChild(groundName)
	if newGround == nil then warn('new ground not found'); return end

	local clone = newGround:clone()
	local sky = clone:FindFirstChildOfClass('Sky')
	if sky then sky.Parent = Lighting end
	clone.Name = 'Ground'
	clone.Parent = workspace.Scenes
end

function GetNextEvent()
	local eventDict = {}
	for k, v in TempData.EventDict do
		if self.State == nil or k ~= self.State.name then
			eventDict[k] = v
		end
	end
	local event = shared.Tool.GachaByDict(eventDict)
	self.NextEvent = event
end

function MKPrompt(player)
	local character = player.Character
	if not character then return end

	for _, child in character:GetChildren() do
		if child:HasTag('EventFood') then
			local type = child:GetAttribute('Type')
			self.Foods[tostring(type)] = true 
			child:Destroy()
		end
	end

	local chk = true
	for i=1, 5 do
		if self.Foods[tostring(i)] == nil then chk = false; break end
	end

	if chk == true then
		self.IsMut = true
		ReplicatedStorage.Remote.MKEvent:FireAllClients(nil, self.EventEndTime)
		ReplicatedStorage.Remote.ServerTip:FireAllClients('Fragment Drop Begin !!!')
		SpawnFragment()

		self.MKPromptConn:Disconnect()
		workspace.SceneLogic.MKEvent.ProximityPrompt.Enabled = false
	else
		ReplicatedStorage.Remote.MKEvent:FireAllClients(self.Foods)
	end
end
function SpawnMKFood()
	self.Foods = {}
	self.Positions = {}
	self.MKFoods = {}

	ReplicatedStorage.Remote.MKEvent:FireAllClients(self.Foods)
	local spawnArea = workspace.SceneLogic.EventCashSpawnArea
	local folder = ReplicatedStorage.Assets.Parts.EventFoods:Clone()
	for k, v in pairs(folder:GetChildren()) do
		
		local instances = SpawnInstancesInPart(spawnArea, v, 1, 10)
		for _, v in instances do
			table.insert(self.MKFoods, v)
		end
	end
	for _, instance in ipairs(self.MKFoods) do
		instance:FindFirstChildOfClass('Script').Enabled = true
	end
	
	folder:Destroy()
end
function SpawnEventCash()
	self.CashLeft = 7
	self.Positions = {}
	self.Cashes = {}

	local spawnArea = workspace.SceneLogic.EventCashSpawnArea
	local folder = ReplicatedStorage.Assets.Parts.EventCash:Clone()
	for k, v in pairs(folder:GetChildren()) do
		local amount = v:GetAttribute('Amount')
		local type = v:GetAttribute('Type')
		
		local instances = SpawnInstancesInPart(spawnArea, v, amount, 10)
		for _, instance in ipairs(instances) do
			table.insert(self.Cashes, instance)
			instance.ProximityPrompt.Triggered:Connect(function(player)
				shared.DataStore.RewardController.ClaimEventCash(player, type)
				self.CashLeft -= 1
				if self.CashLeft == 0 and self.State.name == 'CashDrop' then
					task.delay(20, function() SpawnEventCash() end)
				end
				instance:Destroy()
			end)
		end
	end

	folder:Destroy()
end

function ClaimFragmentReward(player)
	-- TODO: 在這裡指定 Prompt 觸發後給的獎勵
	-- e.g. shared.DataStore.RewardController.GetItem(player, itemId, amount)
	-- e.g. ReplicatedStorage.Remote.Loot:FireClient(player, { Items = { [itemId] = amount } })
end

function SpawnFragment()
	self.FragmentLeft = 20
	self.Positions = {}
	self.Fragments = {}

	local spawnArea = workspace.SceneLogic.EventCashSpawnArea
	local template = ReplicatedStorage.Assets.Parts.FragmentGacha

	local instances = SpawnInstancesInPart(spawnArea, template, 20, 10)
	for _, instance in ipairs(instances) do
		table.insert(self.Fragments, instance)
		instance:FindFirstChildOfClass('Script').Enabled = true
		instance.ProximityPrompt.Triggered:Connect(function(player)
			local list = RewardData.FragmentEvent
			local itemId = shared.Tool.GachaByDict(list)
			shared.DataStore.RewardController.GetEventFragments(player, itemId, 1)
			self.FragmentLeft -= 1
			if self.FragmentLeft == 0 and self.State.name == 'SixSevenFeast' then
				task.delay(5, function() SpawnFragment() end)
			end
			instance:Destroy()
		end)
	end
end

function SpawnInstancesInPart(container, template, amount, minDistance)
	local instances = {}

	local size = container.Size

	local function GetRandomPosition()
		local x = math.random(-size.X / 2, size.X / 2)
		local y = math.random(-size.Y / 2, size.Y / 2)
		local z = math.random(-size.Z / 2, size.Z / 2)

		return container.CFrame:PointToWorldSpace(
			Vector3.new(x, y, z)
		)
	end

	local function IsValidPosition(pos)
		for _, oldPos in ipairs(self.Positions) do
			if (pos - oldPos).Magnitude < minDistance then
				return false
			end
		end

		return true
	end

	for i = 1, amount do
		local pos
		local retry = 0

		repeat
			pos = GetRandomPosition()
			retry += 1
		until IsValidPosition(pos) or retry >= 100

		if retry < 100 then
			local instance = template:Clone()

			if instance:IsA("Model") then
				instance:PivotTo(CFrame.new(pos))
			elseif instance:IsA("BasePart") then
				instance.Position = pos
			end

			instance.Parent = container
			table.insert(instances, instance)
			table.insert(self.Positions, pos)
		end
	end

	return instances
end


--------  设置状态，执行进入、退出状态的函数
function self.SetState(newState)
	local state = EnumState[newState]
	if not state then warn('state not found');  return end
	
	if self.State and self.State.exit then self.State.exit(self) end
	
	self.State = state
	-- print('set state:', self.State.name)
	self.Timer = self.State.duration
	
	if state.enter then state.enter(self) end
end

return self