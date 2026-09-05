local self = {}
local Info, CurData = nil

function self.init()
    
end

function self.CountItem(itemData, id)
    local item = itemData.Inv[id]
    if item == nil or item == 0 then
        return false
    else
        return true
    end
end
function self.Chk(itemData, id, amount)
    local item = itemData.Inv[id]

    if item >= amount then
        return true
    else
        return false
    end
end

return self
