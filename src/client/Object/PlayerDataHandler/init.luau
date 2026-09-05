local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FACTOR_AFK = 2
local self = {LevelUpEvent = nil, RebirthEvent = nil, DataChangedEvent = nil, InitData = false, SetIncEvent = nil}
local CurData : any = {}
local SyncCurData, GetPetValue, BuyPower, DeletePet, WinsDec, UnequipPet, EquipPet, SetData, WinsInc, SetInc, Rebirth =  nil

function self.init()
    self.RebirthEvent = shared.Event.new()
    self.DataChangedEvent = shared.Event.new()
    self.TriggerSetIncEvent = shared.Event.new()

	self.TowerModule = require(script.TowerData)
end

function self.start()
    ReplicatedStorage.Remote.SetPlayerData.OnClientEvent:Connect(SetData)
end

function self.GetData()
	return CurData
end
function self.GetVIPData()
    return CurData.VIP
end

function self.GetTowerUIDByUID(uid)
    local towerUID = self.TowerModule.GetTowerUIDByUID(CurData.Tower, uid)
    if towerUID == nil then warn('toweruid not found for uid:', uid); return end

    return towerUID
end

function self.GetTowerTraitByUID(uid)
    return self.TowerModule.GetTowerTraitByUID(CurData.Tower, uid)
end
function self.GetTowerByUID(uid)
    return self.TowerModule.GetTowerByUID(CurData.Tower, uid)
end

function self.GetEquippedTotem()
    local equipped = CurData.Totem.Equipped
    if equipped == false then
        return false
    else
        return CurData.Totem.Inv[equipped]
    end
end
function self.GetEquippedTotems()
    local totemData = CurData.Totem
    if totemData == nil then return {} end

    local result = {}
    for slot = 1, 3 do
        local field = slot == 1 and 'Equipped' or ('Equipped' .. slot)
        local uid = totemData[field]
        local inv = totemData.Inv[uid]
        if uid ~= false and uid ~= nil and inv ~= nil then
            table.insert(result, inv)
        end
    end
    return result
end
function self.GetTotemUIDByUID(uid)
    local totemUID = CurData.Totem.Inv[uid].TotemUID
    if totemUID == nil then warn('toweruid not found for uid:', uid); return end

    return totemUID
end
function self.GetTotemByUID(uid)
    local totemData = CurData.Totem.Inv[uid]
    if totemData == nil then warn('totemdata not found for uid:', uid); return end

    return totemData
end
function self.CheckTowerIsTool(uid)
    local chk = self.TowerModule.CheckTool(CurData.Tower, uid)
    if chk then 
        return true 
    else
        return false
    end
end

function self.GetCurPath()
    local curPath = CurData.States.CurPath
    if curPath == nil then warn('player path not found'); return end

    return curPath
end

function SetData(data, tag)
    SyncCurData(CurData, data)

    if self.InitData == true then self.DataChangedEvent:Fire(tag) end
    if self.InitData == false then self.InitData = true end
end 

function SyncCurData(curData, newData)
    -- 删除旧数据中不存在的键
    for key in pairs(curData) do
        if newData[key] == nil then
            curData[key] = nil
        end
    end

    -- 同步新数据
    for key, value in pairs(newData) do
        if type(value) == "table" and type(curData[key]) == "table" then
            -- 保留第一层 table 的引用
            table.clear(curData[key])

            for k, v in pairs(value) do
                curData[key][k] = v
            end
        else
            curData[key] = value
        end
    end
end


return self
