local listClass, linkClass = {}, {}
listClass.__index, linkClass.__index = listClass, linkClass

function listClass.new()
	local self = setmetatable({}, listClass)
	self.List = self
	self.Next = self
	self.Previous = self
	return self
end

function listClass:InsertFront(link)
	link.Previous = self
	link.Next = self.Next
	self.Next.Previous = link
	self.Next = link
	return setmetatable(link, linkClass)
end

function listClass:InsertAfter(link)
	link.Previous = self
	link.Next = self.Next
	self.Next.Previous = link
	self.Next = link
	return setmetatable(link, linkClass)
end

function listClass:InsertBack(link)
	link.Next = self
	link.Previous = self.Previous
	self.Previous.Next = link
	self.Previous = link
	return setmetatable(link, linkClass)
end

function listClass:InsertBefore(link)
	link.Next = self
	link.Previous = self.Previous
	self.Previous.Next = link
	self.Previous = link
	return setmetatable(link, linkClass)
end

function listClass:GetNext(link)
	link = (link or self).Next
	if link ~= self then return link end
end

function listClass:GetPrevious(link)
	link = (link or self).Previous
	if link ~= self then return link end
end

function listClass:IterateForward(link)
	return listClass.GetNext, self, link
end

function listClass:IterateBackward(link)
	return listClass.GetPrevious, self, link
end

function listClass:RemoveFirst()
	local link = self.Next
	if link ~= self then
		link.Previous.Next = link.Next
		link.Next.Previous = link.Previous
		return link
	end
end

function listClass:RemoveLast()
	local link = self.Previous
	if link ~= self then
		link.Previous.Next = link.Next
		link.Next.Previous = link.Previous
		return link
	end
end

function listClass:RemoveUpTo(link)
	self.Next = link
	link.Previous = self
end

function listClass:RemoveDownTo(link)
	self.Previous = link
	link.Next = self
end

function listClass:RemoveAll()
	self.Next = self
	self.Previous = self
end

function linkClass:InsertAfter(link)
	link.Previous = self
	link.Next = self.Next
	self.Next.Previous = link
	self.Next = link
	return setmetatable(link, linkClass)
end

function linkClass:InsertBefore(link)
	link.Next = self
	link.Previous = self.Previous
	self.Previous.Next = link
	self.Previous = link
	return setmetatable(link, linkClass)
end

function linkClass:GetNext()
	local link = self.Next
	if link ~= link.List then return link end
end

function linkClass:GetPrevious()
	local link = self.Previous
	if link ~= link.List then return link end
end

function linkClass:Remove()
	self.Previous.Next = self.Next
	self.Next.Previous = self.Previous
end

function linkClass:Clean()
	setmetatable(self, nil)
	self.Next = nil
	self.Previous = nil
end

return listClass