local HttpService = game:GetService("HttpService")

local self = {}

local MAX_SLOT = 3
local SLOT_FIELDS = {
    [1] = 'Equipped',
    [2] = 'Equipped2',
    [3] = 'Equipped3',
}

function self.init()
end

function self.GetEquippedBySlot(totemData, slot)
    local field = SLOT_FIELDS[slot]
    if field == nil then return end

    local uid = totemData[field]
    if uid == false or uid == nil then return end
    return uid
end

function self.GetEquippedUIDs(totemData)
    local result = {}
    for slot = 1, MAX_SLOT do
        local uid = self.GetEquippedBySlot(totemData, slot)
        if uid ~= nil then
            table.insert(result, uid)
        end
    end
    return result
end

function self.GetEquippedList(totemData)
    local uids = self.GetEquippedUIDs(totemData)
    local result = {}
    for _, uid in uids do
        local tarData = totemData.Inv[uid]
        if tarData ~= nil then
            table.insert(result, tarData)
        end
    end
    return result
end

function self.UnEquipFromAll(totemData, uid)
    for _, field in pairs(SLOT_FIELDS) do
        if totemData[field] == uid then
            totemData[field] = false
        end
    end
end

function self.IsSlot2Unlocked(totemData)
    return totemData.Slot2Unlocked == true
end

function self.UnlockSlot2(totemData)
    if totemData.Slot2Unlocked == true then return false end

    totemData.Slot2Unlocked = true
    return true
end

function self.AddTotem(totemData, totemUID, newUID)
    local uid = newUID or HttpService:GenerateGUID(false)

    local newTotemData = {UID = uid, TotemUID = totemUID, Point = 1}
    totemData.Inv[uid] = newTotemData

    return newTotemData
end

function self.DeleteTotem(totemData, uid)
    local tarData = totemData.Inv[uid]
    if tarData == nil then return end

    totemData.Inv[uid] = nil
end

function self.GetTotemByUID(totemData, uid)
    local tarData = totemData.Inv[uid]
    if tarData == nil then return end

    return tarData
end

function self.AddPoint(totemData, uid, amount)
    local tarData = totemData.Inv[uid]
    if tarData == nil then return end

    tarData.Point = (tarData.Point or 1) + (amount or 1)
    return tarData
end

function self.Equip(totemData, uid, slot)
    local tarData = totemData.Inv[uid]
    if tarData == nil then return end
    local field = SLOT_FIELDS[slot]
    if field == nil then return end

    -- 同一图腾只能装备在一个槽位
    for _, otherField in pairs(SLOT_FIELDS) do
        if otherField ~= field and totemData[otherField] == uid then
            totemData[otherField] = false
        end
    end

    totemData[field] = uid
    return tarData
end

function self.UnEquip(totemData, uid, slot)
    local field = SLOT_FIELDS[slot]
    if field == nil then return end
    if totemData[field] ~= uid then return end

    totemData[field] = false
end

function self.GetEquipped(totemData)
    return self.GetEquippedList(totemData)
end

-- function self.Upgrade(totemData, feedUIDs)
--     local tarUID = self.GetEquipped(totemData)
--     if tarUID == nil then return end

--     local tar = totemData.Inv[tarUID]
--     if tar == nil then return end

--     local totalPoint = 0
--     for _, uid in ipairs(feedUIDs) do
--         if uid == tarUID then return end
--         local feed = totemData.Inv[uid]
--         if feed == nil then return end
--         if uid == totemData.Equipped then return end
--         totalPoint += feed.Point or 1
--     end
--     if totalPoint <= 0 then return end

--     for _, uid in ipairs(feedUIDs) do
--         self.DeleteTotem(totemData, uid)
--     end

--     tar.Point = (tar.Point or 1) + totalPoint
--     return true
-- end

return self
