local ReplicatedStorage = game:GetService("ReplicatedStorage")

local self = {}

function self.init()
end

function self.Init()
end

function self.GetTowerByUID(towerData, uid)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return end

    return tarData
end

function self.GetTowerUIDByUID(towerData, uid)
    local tarData = towerData.Inv[uid]
    if tarData == nil then return end

    return tarData.TowerUID
end
function self.CheckTool(towerData, uid)
	local tower = towerData.Inv[uid]
	if tower == nil then warn('check tool fail for uid:', uid); return end

	if tower.IsTool then
		return true
	else
		return false
	end
end

function self.GetTowerTraitByUID(towerData, uid)
	local tarData = towerData.Inv[uid]
	if tarData == nil then return end

	return tarData.Trait
end

return self
