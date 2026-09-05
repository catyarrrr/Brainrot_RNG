local TICKPERSECOND = 48

local Class = {}
Class.__index = Class
local collections = {}

function Class.new(player)
	if collections[player] ~= nil then warn('player ticksys all exist for player = ', player); return end

	local self = setmetatable({}, Class)
	self.TaskLists = {}
	self.TickPerSecond = TICKPERSECOND
	self.OnTick = shared.Event.new()
	self.PostTick = shared.Event.new()
	self.Connection = nil
	self.Player = player
	-- self.PathId = pathId

	collections[player] = self
	-- collections[self.PathId] = self

	return self
end

function Class:Start(startTime)
	if self.Connection ~= nil then return false end
	self.Tick = 0
	self.StartTime = startTime
	self.Connection = game:GetService('RunService').Heartbeat:Connect(function(dt) self:Loop() end)
	return true
end

function Class:Stop()
	if self.Connection == nil then return false end
	self.Connection:Disconnect()
	self.Connection = nil
	table.clear(self.TaskLists)
	-- self.Tick = 0
	-- print('self.tick = ', self.Tick)
	return true
end

function Class:Wait(amount)
	local scheduledTick = self.Tick + math.max(amount, 1)
	local taskList = self.TaskLists[scheduledTick]
	if not taskList then taskList = shared.LinkedList.new() self.TaskLists[scheduledTick] = taskList end
	taskList:InsertBack({Thread = coroutine.running()})
	return coroutine.yield()
end

function Class:Delay(amount, func, ...)
	local scheduledTick = self.Tick + math.max(amount, 1)
	local taskList = self.TaskLists[scheduledTick]
	if not taskList then taskList = shared.LinkedList.new() self.TaskLists[scheduledTick] = taskList end
	return taskList:InsertBack({Function = func, Parameters = {...}})
end

function Class:SetSpeed(speed)
	self.StartTime = workspace:GetServerTimeNow() - (self.Tick / speed)
	self.TickPerSecond = speed
end

function Class:Loop()
	local currentTick = math.floor((workspace:GetServerTimeNow() - self.StartTime) * self.TickPerSecond)
	-- print('tick = ', self.Tick, 'curtick = ', currentTick)
	if self.Tick >= currentTick then return end
	while self.Tick < currentTick do
		self.Tick += 1
		self.OnTick:Fire(self.Tick)
		local taskList = self.TaskLists[self.Tick]
		if not taskList then continue end
		local scheduledTask = taskList.Next
		while scheduledTask ~= taskList do
			if scheduledTask.Thread then
				task.spawn(scheduledTask.Thread, self.Tick)
			else
				shared.Thread:Spawn(scheduledTask.Function, table.unpack(scheduledTask.Parameters))
			end
			scheduledTask = scheduledTask.Next
		end
		self.TaskLists[self.Tick] = nil
	end
	self.PostTick:Fire(self.Tick)
end

function Class:Destroy()
	self:Stop()

	collections[self.Player] = nil
end

return Class