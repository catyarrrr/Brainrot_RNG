local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local TraitData = require(ReplicatedStorage.Datas.TraitData :: ModuleScript)
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local self : any = {}

function self.Init(main)
	self.Main = shared.Frame.new(main.PopUp.TowerDetailFrame)
    self.Main:Visible(false)

    self.Frame = self.Main.Frame.Frame
    self.Frame.Pickup.Btn.MouseButton1Click:Connect(function()
        -- print(self.SelectedId)
        shared.TowerHandler.DespawnEvent:Fire(self.SelectedId)
        self:Close()
    end)
    self.Frame.Exit.Btn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        -- print(self.SelectedId)
        -- shared.TowerHandler.DespawnEvent:Fire(self.SelectedId)
        self:Close()
    end)

end

function self.Trigger(isShow, towerData, isTool)
    if isTool then
        self.Frame.Pickup.Visible = false
        self.Frame.Exit.Visible = false
        self.Frame.ShapeIcon.Visible = true
        self.Frame.Rotate.Visible = false
    else
        self.Frame.Pickup.Visible = true
        self.Frame.Exit.Visible = true
        self.Frame.ShapeIcon.Visible = false
        self.Frame.Rotate.Visible = false
    end

    if isShow then
        if self.Main.IsOpen == true then
            self.Update(towerData)
            return
        else
            self.Update(towerData)
            self:Open()
        end
    else
        self:Close()
    end
end

function self.Update(towerData)
    if towerData == nil then return end

    self.SelectedId = towerData.Id
    self.Frame.Label.NameText.Text = towerData.DisplayName
    self.Frame.Label.Icon.Image = AssetsData[towerData.AssetId].Icon
    self.Frame.ShapeIcon.ImageLabel.Image = shared.ShapeData[towerData.Shape].Icon
    self.Frame.Info.QualityText.Text = towerData.Quality
    self.Frame.Info.QualityText.TextColor3 = TowerData.GetRGBByTowerUID(towerData.TowerUID)
    local lvl = TowerData.GetLvlByTowerUID(towerData.TowerUID)
    if lvl then self.Frame.Info.LevelText.Text = 'Lv.' .. tostring(lvl) end
    local mutId = TowerData.GetMutIdByTowerUID(towerData.TowerUID)
    if mutId then
        for k, v in self.Frame.Label.Mutations:GetChildren() do if v:IsA('TextLabel') then v.Visible = false end end
        if mutId > 1 then self.Frame.Label.Mutations:FindFirstChild(tostring(mutId)).Visible = true end
    end

    self.Frame.DPS.DPSLabel.Text = shared.CalculateData.GetDPS(towerData.Damage, towerData.ActionDelay)
    self.Frame.RNG.RNGLabel.Text = towerData.Range
    self.Frame.CD.CDLabel.Text = string.format('%.2f', towerData.ActionDelay / shared.Config.TICKPERSECOND_DEFAULT)
    local totemType = TotemData.GetTotemTypeByTowerUID(towerData.TowerUID)
    if totemType then self.Frame.Totem.Text = TotemData.Type[totemType] end

    local traitData = towerData.Trait and TraitData.GetData(towerData.Trait)
    self.Frame.Trait.NameLabel.Text = (traitData and traitData.Name) or 'None'
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end


return self
