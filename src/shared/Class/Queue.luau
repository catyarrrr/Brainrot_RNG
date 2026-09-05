local Queue = {}
Queue.__index = Queue


function Queue.new()
	local self = setmetatable({}, Queue)

	self.First = 1
	self.Last = 0
	self.Data = {}

	return self
end

-- 入队
function Queue:Push(value)

	self.Last += 1
	self.Data[self.Last] = value

end

-- 出队
function Queue:Pop()

	if self:IsEmpty() then
		return nil
	end

	local value = self.Data[self.First]

	self.Data[self.First] = nil
	self.First += 1

	return value
end


-- 查看队首
function Queue:Peek()

	if self:IsEmpty() then
		return nil
	end

	return self.Data[self.First]
end


function Queue:IsEmpty()

	return self.First > self.Last

end


function Queue:Size()
	return self.Last - self.First + 1

end

function Queue:Clear()

	self.First = 1
	self.Last = 0
	self.Data = {}

end


return Queue