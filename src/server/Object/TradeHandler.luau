local self = {Trade = {},}
local tradeId = 0

function self.Create(giver, receiver, uid, name)
    tradeId += 1
    local id = tradeId

    self.Trade[id] = {
        Id = id,

        Giver = {giver.UserId, true},
        Receiver = {receiver.UserId, false},
        AlienName = name, 

        UID = uid
    }

    return id
end

function self.Find(userId)
    for _, v in pairs(self.Trade) do
        if v.Giver[1] == userId or v.Receiver[1] == userId then
            return v
        end
    end

    return nil
end

function self.GetOtherUserId(trade, userId)
    if trade.Giver[1] == userId then
        return trade.Receiver[1]
    elseif trade.Receiver[1] == userId then
        return trade.Giver[1]
    end

    return nil
end

function self.Confirm(tradeId, userId)
    if self.Trade[tradeId] == nil then warn('find trade error'); return false end
    
    if self.Trade[tradeId].Giver[1] == userId then
        self.Trade[tradeId].Giver[2] = true
    elseif self.Trade[tradeId].Receiver[1] == userId then
        self.Trade[tradeId].Receiver[2] = true
    end

    return self.Trade[tradeId].Giver[2] == true and self.Trade[tradeId].Receiver[2] == true
end

function self.Destroy(id)
    if self.Trade[id] == nil then return end
    self.Trade[id] = nil
end 

return self
