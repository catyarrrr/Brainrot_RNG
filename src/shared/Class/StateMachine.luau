local Class = {}
Class.__index = Class

function Class.new(states)
	local self = setmetatable({}, Class)

	self.States = states
	self.Current = nil

	return self
end

function Class:SetState(name)

	local newState = self.States[name]

	if not newState then
		warn("State not found:", name)
		return
	end

	if self.Current and self.Current.exit then
		self.Current.exit(self)
	end

	self.Current = newState

	if newState.enter then
		newState.enter(self)
	end
end

function Class:Update()
	if self.Current and self.Current.update then
		self.Current.update(self)
	end
end

function Class:GetState()
	return self.Current
end

return Class