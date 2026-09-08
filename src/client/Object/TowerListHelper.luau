local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local GetSortValue = nil
local self = {}


function self.GetSortedTowerTable(inv, sortMode)
    sortMode = sortMode or 'DPS'

    local clone = {}
    for k, v in inv do
        table.insert(clone, v)
    end

    local values = {}
    for _, tower in clone do
        values[tower] = GetSortValue(tower, sortMode)
    end

    local descending = sortMode ~= 'CD'
    table.sort(clone, function(a, b)
        if descending then
            return values[a] > values[b]
        else
            return values[a] < values[b]
        end
    end)

    return clone
end

function self.GetSlotByStaticData(staticData, traitId, inIndex)
    local assetId = TowerData.GetAssetIdByTowerUID(staticData.TowerUID)
    if assetId == nil then warn('asset data not found for toweruid:', staticData.TowerUID); return end
    local template = ReplicatedStorage.Assets.UI.AlienSlot:FindFirstChild(staticData.Quality)
    if template == nil then warn('slot ui not found for quality:', staticData.Quality); return end
    local clone = template:Clone()

    clone.LevelText.Text = TowerData.GetLvlByTowerUID(staticData.TowerUID)
    clone.NameText.Text = staticData.DisplayName
    clone.Icon.Image = AssetsData[assetId].Icon
    if not inIndex then
        clone.ShapeIcon.Shape.Image = shared.ShapeData[staticData.Shape].Icon
        clone.ShapeIcon.Visible = true
    end
    local mutId = TowerData.GetMutIdByTowerUID(staticData.TowerUID)
    if clone.Mutations:FindFirstChild(tostring(mutId)) then
        clone.Mutations:FindFirstChild(tostring(mutId)).Visible = true
    end
    if traitId then
        local trait = ReplicatedStorage.Assets.UI.TraitIcon:FindFirstChild(tostring(traitId))
        if trait == nil then return end
        trait = trait:Clone()
        trait.Size = clone.TraitIcon.Size
        trait.Position = clone.TraitIcon.Position
        trait.Parent = clone
    end
    
    CollectionService:AddTag(clone, 'Btn')

    if not inIndex then
        clone.MouseEnter:Connect(function()
            shared.UIHandler.AlienTips.Show(clone, staticData, traitId)
        end)
        clone.MouseLeave:Connect(function()
            shared.UIHandler.AlienTips.Hide(clone)
        end)
    end

    return clone
end



function GetSortValue(tower, sortMode)
    if sortMode == 'Rarity' then
        local qualityData = TowerData.GetQualityDictByTowerUID(tower.TowerUID)
        return qualityData and qualityData.Value or 0
    end

    local stats = TowerData.GetCloneData(tower.TowerUID)
    if stats == nil then
        return sortMode == 'CD' and math.huge or 0
    end
    shared.CalculateData.ApplyModifiers(stats, tower.Trait)

    if sortMode == 'CD' then
        return stats.ActionDelay or math.huge
    elseif sortMode == 'Range' then
        return stats.Range or 0
    end
    return shared.CalculateData.GetDPS(stats.Damage, stats.ActionDelay)
end

return self
