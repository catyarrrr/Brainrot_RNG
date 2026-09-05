local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)

local self = {}

function self.Init(context)
    self.GetData = context.GetData
    self.SetPlayerData = context.SetPlayerData
    self.GridModule = context.GridModule
    self.TowerModule = context.TowerModule
end

function self.GetUIDByGrid(player, gridXY)
    local tarData = self.GetData(player)
    if not tarData then return end

    local taruid = self.GridModule.GetUIDByGrid(tarData.Grid, gridXY[1], gridXY[2])
    if taruid == nil then return end
    return taruid
end

function self.UpgradeGrid(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local curLevel = self.GridModule.GetLevel(tarData.Grid)
    local nextLevel = curLevel + 1

    local cost = TempData.BaseDict[curLevel].NextCost
    tarData.Coin.Cash -= cost

    self.TowerModule.UpgradeTowerGrid(tarData.Tower, nextLevel)
    self.GridModule.GridUpgrade(tarData.Grid, nextLevel)

    for _, tower in tarData.Tower.Inv do
        if tower.GridXY then
            local towerStaticData = TowerData.GetData(tower.TowerUID)
            self.GridModule.Place(tarData.Grid, shared.ShapeData[towerStaticData.Shape], tower.GridXY[1], tower.GridXY[2], tower.UID)
        end
    end

    self.SetPlayerData(player, 'Grid')
end

function self.BuyGridUpgrade(player)
    local tarData = self.GetData(player)
    if not tarData then return end

    local curLevel = self.GridModule.GetLevel(tarData.Grid)
    local dict = TempData.BaseDict[curLevel + 1]
    if dict == nil then return end

    self.TowerModule.UpgradeTowerGrid(tarData.Tower, curLevel + 1)
    self.GridModule.GridUpgrade(tarData.Grid, curLevel + 1)

    for _, tower in tarData.Tower.Inv do
        if tower.GridXY then
            local towerStaticData = TowerData.GetData(tower.TowerUID)
            self.GridModule.Place(tarData.Grid, shared.ShapeData[towerStaticData.Shape], tower.GridXY[1], tower.GridXY[2], tower.UID)
        end
    end

    self.SetPlayerData(player, 'Grid')
end

function self.BuyAreaSkin(player, id, cost)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Grid.Skins[id] = true
    tarData.Coin.Cash -= cost
    
    self.SetPlayerData(player, 'Area')
end

function self.SetAreaSkin(player, id)
    local tarData = self.GetData(player)
    if not tarData then return end

    tarData.Grid.CurSkin = id

    self.SetPlayerData(player, 'Terr')
end

return self
