local ReplicatedStorage = game:GetService("ReplicatedStorage")
local self = {}
self.StartTime = nil
local connection = nil
local taskLists = {}

function self.init()
	self.Tick = 0
	self.TickPerSecond = 48
	self.OnTick = shared.Event.new()
	self.PostTick = shared.Event.new()
end

function self.start()
	ReplicatedStorage.Remote.Game.GameSpeedModify.OnClientEvent:Connect(function(startTime, tickpersec)
		if tickpersec == nil or startTime == nil then return end
		self:SetSpeed(startTime, tickpersec)
	end)
end

function self:Start(startTime)
	if connection ~= nil then return false end
	self.Tick = 0
	self.StartTime = startTime
	connection = game:GetService('RunService').Heartbeat:Connect(Loop)
	return true
end

function self:Stop()
	if connection == nil then return false end
	-- print('stop task')
	connection:Disconnect()
	connection = nil
	table.clear(taskLists)
	-- self.Tick = 0
	return true
end

function self:Wait(amount)
	local scheduledTick = self.Tick + math.max(amount, 1)
	local taskList = taskLists[scheduledTick]
	if not taskList then taskList = shared.LinkedList.new() taskLists[scheduledTick] = taskList end
	taskList:InsertBack({Thread = coroutine.running()})
	return coroutine.yield()
end

function self:Delay(amount, func, ...)
	local scheduledTick = self.Tick + math.max(amount, 1)
	local taskList = taskLists[scheduledTick]
	if not taskList then taskList = shared.LinkedList.new() taskLists[scheduledTick] = taskList end
	return taskList:InsertBack({Function = func, Parameters = {...}})
end

function self:SetSpeed(startTime, speed)
	self.StartTime = startTime
	self.TickPerSecond = speed
end

function Loop()
	local currentTick = math.floor((workspace:GetServerTimeNow() - self.StartTime) * self.TickPerSecond)
	if self.Tick >= currentTick then return end
	while self.Tick < currentTick do
		self.Tick += 1
		self.OnTick:Fire(self.Tick)
		local taskList = taskLists[self.Tick]
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
		taskLists[self.Tick] = nil
	end
	self.PostTick:Fire(self.Tick)
end

return self
