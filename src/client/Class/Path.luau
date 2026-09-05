local ReplicatedStorage = game:GetService("ReplicatedStorage")
local wayPointsFolder = Instance.new('Folder')
wayPointsFolder.Name = 'Waypoints'
wayPointsFolder.Parent = workspace

local PathInit = nil
local Class = {Paths = {}, Initiated = false}
Class.__index = Class

function Class.start()
	PathInit()
end

function PathInit()
	local paths = workspace:WaitForChild('Paths')

	repeat
		task.wait()
	until paths:GetAttribute("Initiated") == true

	for _, model in pairs(paths:GetChildren()) do
		Class.Paths[tonumber(model.Name)] = Class.new(model)
	end

	Class.Initiated = true
	ReplicatedStorage.Remote.PlayerPathInitiated:FireServer()
end

function Class.new(paths)
	local self = setmetatable({}, Class)

	self.Id = tonumber(paths.Name)
	self.StepStuds = 2		-- 相邻两个waypoint之间的距离
	self.SubSteps = 100		-- waypoint 之间被切成多少个 CFrame
	self.SubStepStuds = self.StepStuds / self.SubSteps	-- 真正的位移单位
	local turnPerStud = .2
	local turnPerStep = turnPerStud * self.SubStepStuds
	local turnRadius = 1 / turnPerStud
	local turnCircumference = 2 * turnRadius * math.pi
	-- local paths = workspace:WaitForChild('Path')
	
	self.Parts = paths:GetChildren()
	table.sort(self.Parts, function(a, b) return a.Name < b.Name end)
	
	self.Positions = table.create(#self.Parts)		--存储part的position
	for _, part in self.Parts do
		part.Transparency = 1
		table.insert(self.Positions, part.Position)
	end
	
	self.Directions = table.create(#self.Positions - 1)		--存储part之间的方向向量
	for index = 2, #self.Positions do
		table.insert(self.Directions, self.Positions[index] - self.Positions[index - 1])
	end
	
	self.Angles = table.create(#self.Positions)
	table.insert(self.Angles, 0)
	for index = 2, #self.Directions do
		table.insert(self.Angles, self.Directions[index - 1]:Angle(self.Directions[index]))
	end
	table.insert(self.Angles, 0)
	
	self.Distances = table.create(#self.Positions)
	self.Offsets = table.create(#self.Positions)
	self.Distance = 0
	table.insert(self.Distances, self.Distance)
	table.insert(self.Offsets, 0)
	
	---------------------- 设置self.CFrame
	local cframe = CFrame.lookAt(self.Positions[1], self.Positions[2])
	self.CFrames = {cframe}
	self.Waypoints = {}
	for index = 2, #self.Positions do
		local targetPosition = self.Positions[index]
		local direction = targetPosition - cframe.Position
		local magnitude = math.tan(self.Angles[index] / 2) * turnRadius
		
		local angle = self.Angles[index] / 2
		local normalizedAngle = angle / (math.pi * 2)
		local turnMagnitude = turnCircumference * normalizedAngle
		
		self.Distance += self.Directions[index - 1].Magnitude - magnitude + turnMagnitude
		table.insert(self.Distances, self.Distance)
		table.insert(self.Offsets, magnitude - turnMagnitude)
		self.Distance = self.Distance - magnitude + turnMagnitude
		
		magnitude = math.max(magnitude, self.SubStepStuds)
		while direction.Magnitude > magnitude do
			local newAngle = cframe.LookVector:Angle(direction, Vector3.yAxis)
			newAngle = math.clamp(newAngle, -turnPerStep, turnPerStep)
			cframe *= CFrame.fromAxisAngle(Vector3.yAxis, newAngle)
			cframe += cframe.LookVector * self.SubStepStuds
			table.insert(self.CFrames, cframe)
			if #self.CFrames % self.SubSteps == 0 then
				table.insert(self.Waypoints, shared.Waypoint.new(#self.Waypoints + 1))
			end
			direction = targetPosition - cframe.Position
		end
	end
	----------------------
	
	local waypoints = paths:GetAttribute('Waypoints')
	while waypoints < #self.Waypoints do table.remove(self.Waypoints) end
	while waypoints > #self.Waypoints do table.insert(self.Waypoints, shared.Waypoint.new(#self.Waypoints + 1)) end
	local cframes = paths:GetAttribute('CFrames')
	while cframes < #self.CFrames do table.remove(self.CFrames) end
	while cframes > #self.CFrames do table.insert(self.CFrames, cframe) end
	
	Instance.new('Folder', wayPointsFolder).Name = 'Waypoints' .. tostring(self.Id)
	
	for index, waypoint in self.Waypoints do
		local part  = Instance.new('Part')
		part.Transparency = 1
		part.Color = Color3.new(1, 0, 0)
		part.Anchored = true
		part.CanTouch = false
		part.CanCollide = false
		part.CanQuery = false
		part.CFrame = self.CFrames[index * self.SubSteps]
		part.Size = Vector3.one
		part.Parent = workspace.Waypoints
		part.Shape = Enum.PartType.Ball
	end

	return self
end

function Class:GetWaypointIndex(subStep)
	return math.clamp(math.round(subStep / self.SubSteps), 1, #self.Waypoints)
end

function Class:GetWaypoint(distance)
	return self.Waypoints[math.clamp(math.round(distance / self.StepStuds), 1, #self.Waypoints)]
end

function Class:GetWaypointCFrame(distance)
	return self.CFrames[math.clamp(math.round(distance / self.StepStuds) * self.SubSteps, 1, #self.CFrames)]
end

function Class:GetCFrame(distance)
	return self.CFrames[math.clamp(math.round(distance / self.SubStepStuds), 1, #self.CFrames)]
end

-- function Class:Debug(distance)
-- 	local part  = Instance.new('Part')
-- 	part.Transparency = .5
-- 	part.Color = Color3.new(0, 0, 1)
-- 	part.Anchored = true
-- 	part.CanTouch = false
-- 	part.CanCollide = false
-- 	part.CanQuery = false
-- 	part.CFrame = self:GetWaypointCFrame(distance)
-- 	part.Size = Vector3.one * 1.1
-- 	part.Parent = workspace
-- 	part.Shape = Enum.PartType.Ball
	
-- 	local part1  = Instance.new('Part')
-- 	part1.Transparency = .5
-- 	part1.Color = Color3.new(0, 1, 0)
-- 	part1.Anchored = true
-- 	part1.CanTouch = false
-- 	part1.CanCollide = false
-- 	part1.CanQuery = false
-- 	part1.CFrame = self:GetCFrame(distance)
-- 	part1.Size = Vector3.one * 1.1
-- 	part1.Parent = workspace
-- 	part1.Shape = Enum.PartType.Ball
-- end

return Class