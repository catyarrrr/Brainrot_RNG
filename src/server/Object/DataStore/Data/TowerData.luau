local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local CollectTower = nil
local self = {}

local function GetCloneField(slot, field)
    if slot == 2 then return field .. '2' end
    return field
end

function self.init()
    
end

function self.SetTowerGrid(towerData, uid, gridXY)
    -- print(uid, gridXY)
    local tarData = towerData.Inv[uid]
    if tarData == nil then warn('towerUID error for uid', uid); return end

    if gridXY then
        tarData.IsTool = false
    else
        local toolCount = self.GetInvSize(towerData)
        local isTool = toolCount < shared.Config.BACKPACK_MAXTOOL
        tarData.IsTool = isTool
    end
    tarData.GridXY = gridXY
end
function self.UpgradeTowerGrid(towerData, nextLevel)
    
    if nextLevel == 2 or nextLevel == 3 then
        for _, data in towerData.Inv do
            if data.GridXY then
                data.GridXY[1] += 1
            end
        end
    end
end

function self.GetTowerUIDByUID(towerData, uid)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return end

    return tarData.TowerUID
end

function self.UpgradeTower(towerData, uid)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return end

    local nextTowerUID = TowerData.GetTowerNext(tarData.TowerUID)
    if nextTowerUID == nil then return end

    tarData.TowerUID = nextTowerUID

    CollectTower(towerData, nextTowerUID)
end

function self.TraitTower(towerData, uid, traitId)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return end

    tarData.Trait = traitId
end

function self.DeleteTower(towerData, uid)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return end

    towerData.Inv[uid] = nil
end

function self.AddTower(towerData, towerUID, newUID)
    local uid = newUID or HttpService:GenerateGUID(false)

    local toolCount = self.GetInvSize(towerData)
    local isTool = toolCount < shared.Config.BACKPACK_MAXTOOL

    local newTowerData = {UID = uid, TowerUID = towerUID, IsTool = isTool}
    towerData.Inv[uid] = newTowerData

    CollectTower(towerData, towerUID)
end

function self.GetInvSize(towerData)
    local toolCount = 0
    for _, v in towerData.Inv do
        if v.IsTool == true then toolCount += 1 end
    end
    return toolCount
end

function self.GiftTower(giverTowerData, receiverTowerData, uid)
    local towerEntry = giverTowerData.Inv[uid]
    if towerEntry == nil then return false end

    giverTowerData.Inv[uid] = nil

    local toolCount = self.GetInvSize(receiverTowerData)
    towerEntry.IsTool = toolCount < shared.Config.BACKPACK_MAXTOOL
    receiverTowerData.Inv[uid] = towerEntry

    return true
end

function self.UnequipAll(towerData)
    for k, v in towerData.Inv do
        v.IsTool = false
    end
end
function self.Equip(towerData, uid)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return end

    tarData.IsTool = true
end
function self.UnEquip(towerData, uid)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return end

    tarData.IsTool = false
end

function self.StartClone(towerData, uid, endTime, slot)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return false end
    if tarData.Cloning then return false end

    slot = slot or 1
    local cloneData = towerData.Clone
    if cloneData == nil then
        cloneData = {SourceUID = false, EndTime = 0, SourceUID2 = false, EndTime2 = 0}
        towerData.Clone = cloneData
    end

    tarData.Cloning = true
    cloneData[GetCloneField(slot, 'SourceUID')] = uid
    cloneData[GetCloneField(slot, 'EndTime')] = endTime
    return true
end

function self.StartEvolve(towerData, uid, targetTowerUID, endTime)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return false end
    if tarData.IsEvolving then return false end

    tarData.IsEvolving = true
    towerData.Evolve = {
        SourceUID = uid,
        TargetTowerUID = targetTowerUID,
        EndTime = endTime,
    }
    return true
end

function self.CheckEvolve(towerData)
    local evolveData = towerData.Evolve
    if evolveData == nil or evolveData.SourceUID == false then return false end

    return workspace:GetServerTimeNow() >= evolveData.EndTime
end

function self.CompleteEvolve(towerData)
    local evolveData = towerData.Evolve
    if evolveData == nil or evolveData.SourceUID == false then return end

    local sourceUID = evolveData.SourceUID
    local sourceData = towerData.Inv[sourceUID]
    if sourceData == nil then
        towerData.Evolve = {SourceUID = false, EndTime = 0}
        return
    end

    sourceData.IsEvolving = nil

    local srcMutId = TowerData.GetMutIdByTowerUID(sourceData.TowerUID)
    local targetMutId = TowerData.GetMutIdByTowerUID(evolveData.TargetTowerUID)
    sourceData.TowerUID = evolveData.TargetTowerUID - targetMutId * 100 + srcMutId * 100

    CollectTower(towerData, sourceData.TowerUID)

    towerData.Evolve = {SourceUID = false, EndTime = 0}

    return sourceUID, sourceData.TowerUID
end

function self.CheckClone(towerData, slot)
    local cloneData = towerData.Clone
    if cloneData == nil then return false end

    slot = slot or 1
    local sourceUID = cloneData[GetCloneField(slot, 'SourceUID')]
    if sourceUID == false or sourceUID == nil then return false end

    return workspace:GetServerTimeNow() >= cloneData[GetCloneField(slot, 'EndTime')]
end

function self.CompleteClone(towerData, newUID, slot)
    local cloneData = towerData.Clone
    if cloneData == nil then return end

    slot = slot or 1
    local sourceField = GetCloneField(slot, 'SourceUID')
    local endTimeField = GetCloneField(slot, 'EndTime')

    local sourceUID = cloneData[sourceField]
    if sourceUID == false or sourceUID == nil then return end

    local sourceData = towerData.Inv[sourceUID]
    if sourceData == nil then
        cloneData[sourceField] = false
        cloneData[endTimeField] = 0
        return
    end

    sourceData.Cloning = nil
    sourceData.IsTool = false

    self.AddTower(towerData, sourceData.TowerUID, newUID)

    cloneData[sourceField] = false
    cloneData[endTimeField] = 0

    return newUID, sourceData.TowerUID, sourceUID
end

function CollectTower(towerData, towerUID)
    if towerData.Collection == nil then
        towerData.Collection = {
            List = {},
            Total = 0
        }
    end

    -- 去掉最后两位
    local collectionUID = math.floor(towerUID / 100) * 100
    collectionUID = tostring(collectionUID)

    if towerData.Collection[collectionUID] then return end

    towerData.Collection[collectionUID] = true
    towerData.Collection.Total += 1
end

return self
