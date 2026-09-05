local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedTotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)

local self = {}

local TOTEM_SLOT2_LEVEL = 10

function self.Init(context)
    self.GetData = context.GetData
    self.SetPlayerData = context.SetPlayerData
    self.TotemModule = context.TotemModule
end

--	槽位解锁规则：槽位1免费；槽位2解锁标记 Slot2Unlocked；槽位3需购买 PASSID_TOTEMSLOT
function self.GetSlotCount(player)
    local tarData = self.GetData(player)
    if not tarData then return 1 end

    local count = 1
    if self.TotemModule.IsSlot2Unlocked(tarData.Totem) then
        count = 2
    end

    if tarData.VIP and tarData.VIP.TotemSlot == true then
        count = 3
    end

    return count
end

function self.IsSlotUnlocked(player, slot)
    if type(slot) ~= 'number' then return false end
    return slot >= 1 and slot <= self.GetSlotCount(player)
end

--	升级图腾到达10级时解锁槽位2标记
function self.CheckSlot2Unlock(player)
    local tarData = self.GetData(player)
    if not tarData then return end
    if self.TotemModule.IsSlot2Unlocked(tarData.Totem) then return end

    local unlock = false
    for _, totem in pairs(tarData.Totem.Inv) do
        if type(totem) == 'table' and SharedTotemData.GetTotemLevel(totem.Point) >= TOTEM_SLOT2_LEVEL then
            unlock = true
            break
        end
    end
    if unlock then
        self.TotemModule.UnlockSlot2(tarData.Totem)
    end
end

function self.UnlockTotemSlot(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.VIP.TotemSlot = true
    self.SetPlayerData(player, 'VIP')
    return true
end

function self.GetEquipped(player)
    local tarData = self.GetData(player)
    if not tarData then return {} end

    return self.TotemModule.GetEquippedList(tarData.Totem)
end

function self.GetEquippedBySlot(player, slot)
    local tarData = self.GetData(player)
    if not tarData then return end

    local uid = self.TotemModule.GetEquippedBySlot(tarData.Totem, slot)
    if uid == nil then return end
    return tarData.Totem.Inv[uid]
end

function self.GetEquippedSlots(player)
    local tarData = self.GetData(player)
    if not tarData then return {} end

    local result = {}
    for slot = 1, 3 do
        local uid = self.TotemModule.GetEquippedBySlot(tarData.Totem, slot)
        if uid ~= nil then
            result[slot] = tarData.Totem.Inv[uid]
        end
    end
    return result
end

function self.Add(player, totemUID, newUID)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.TotemModule.AddTotem(tarData.Totem, totemUID, newUID)
    self.SetPlayerData(player)
end

function self.Remove(player, uid)
    local tarData = self.GetData(player)
    if not tarData then return end

    -- 卸下所有槽位中的该图腾
    self.TotemModule.UnEquipFromAll(tarData.Totem, uid)
    self.TotemModule.DeleteTotem(tarData.Totem, uid)
    self.SetPlayerData(player)
end

function self.Equip(player, uid, slot)
    local tarData = self.GetData(player)
    if not tarData then return end
    if self.IsSlotUnlocked(player, slot) == false then return end

    local result = self.TotemModule.Equip(tarData.Totem, uid, slot)
    if result == nil then return end

    self.SetPlayerData(player, 'Totem')
    return result
end

function self.UnEquip(player, uid, slot)
    local tarData = self.GetData(player)
    if not tarData then return end

    self.TotemModule.UnEquip(tarData.Totem, uid, slot)
    self.SetPlayerData(player, 'Totem')
end

function self.AddPoint(player, amount, slot)
    local tarData = self.GetData(player)
    if not tarData then return end

    local uid = self.TotemModule.GetEquippedBySlot(tarData.Totem, slot)
    if uid == nil then return end
    local result = self.TotemModule.AddPoint(tarData.Totem, uid, amount)
    if result == nil then return end

    -- 升级到达10级时解锁槽位2标记
    local tag = 'TotemUpgrade'
    if self.TotemModule.IsSlot2Unlocked(tarData.Totem) == false
        and SharedTotemData.GetTotemLevel(result.Point) >= TOTEM_SLOT2_LEVEL then
        if self.TotemModule.UnlockSlot2(tarData.Totem) then
            tag = {'TotemUpgrade', 'Totem'}
        end
    end

    self.SetPlayerData(player, tag)
end

return self
