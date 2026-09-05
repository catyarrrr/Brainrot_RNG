local self = {Trade = {},}
local tradeId = 0

function self.Create(giver, receiver, uid, name)
    local id = tradeId + 1
    self.Trade[id] = {
        Id = id,

        Giver = {giver.UserId, true},
        Receiver = {receiver.UserId, false},
        AlienName = name, 

        UID = uid
    }
end

function self.Find(userId)
    for k, v in pairs(self.Trade) do
        if v.Giver[1] == userId or v.Receiver[1] == userId then
            return v
        end
    end

    warn('find no trade')
    return nil
end

function self.Confirm(tradeId, userId)
    if self.Trade[tradeId] == nil then warn('find trade error'); return end
    
    if self.Trade[tradeId].Giver[1] == userId then
        self.Trade[tradeId].Giver[2] = true
    elseif self.Trade[tradeId].Receiver[1] == userId then
        self.Trade[tradeId].Receiver[2] = true
    end

    if self.Trade[tradeId].Giver[2] == true and self.Trade[tradeId].Receiver[2] == true then
        return true
    end

    return false
end

function self.Destroy(id)
    if self.Trade[id] == nil then warn('destroy trade error'); return  end
    self.Trade[id] = nil
end 

return self