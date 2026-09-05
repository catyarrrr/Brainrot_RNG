local Class = {}
Class.__index = Class

function Class.new(index)
	local self = setmetatable({}, Class)
	self.Index = index
	self.Characters = shared.HybridList.new()
	self.CharacterAdded = shared.Event.new()
	self.CharacterRemoved = shared.Event.new()
	
	return self
end

function Class:AddCharacter(character)
	self.Characters:InsertBack(character)
	self.CharacterAdded:Fire(character)
end

function Class:RemoveCharacter(character)
	self.Characters:Remove(character)
	self.CharacterRemoved:Fire(character)
end

return Class
