
local self = {}

function self.init()
    
end

function self.AddItem(itemData, id, amount)
    id = tostring(id)
    local item = itemData.Inv[id] or 0
    item += amount or 1
    itemData.Inv[id] = item
end
function self.Remove(itemData, id, cot)
    id = tostring(id)
    local item = itemData.Inv[id]
    item -= cot or 1 
    itemData.Inv[id] = item
end
function self.Chk(itemData, id, amount)
    id = tostring(id)
    local item = itemData.Inv[id]
    if item == nil then return false end

    if item >= amount then
        return true
    else
        return false
    end
end

return self
