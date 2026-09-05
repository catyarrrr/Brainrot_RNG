local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local TraitData = require(ReplicatedStorage.Datas.TraitData :: ModuleScript)
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)

local self : any = {}


function self.Init(frame)
	self.Main = shared.Frame.new(frame.PopUp.AlienTips)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame
    self.CDLabel = self.Frame.CD.CDLabel
    self.DPSLabel = self.Frame.DPS.DPSLabel
    self.RNGLabel = self.Frame.RNG.RNGLabel
    self.TraitLabel = self.Frame.Trait.TraitLabel
    self.TotemLabel = self.Frame.Totem
end

function self.Update(staticData, traitId)
    if staticData == nil then return end
    local stats = TowerData.GetCloneData(staticData.TowerUID)
    if stats == nil then return end
    shared.CalculateData.ApplyModifiers(stats, traitId)

    self.CDLabel.Text = string.format('%.2f', stats.ActionDelay / shared.Config.TICKPERSECOND_DEFAULT)
    self.DPSLabel.Text = shared.CalculateData.GetDPS(stats.Damage, stats.ActionDelay)
    self.RNGLabel.Text = stats.Range
    local traitData = traitId and TraitData.GetData(traitId)
    self.TraitLabel.Text = (traitData and traitData.Name) or 'None'

    local totemType = TotemData.GetTotemTypeByTowerUID(staticData.TowerUID)
    self.TotemLabel.Text = (totemType and TotemData.Type[totemType]) or 'None'
end

function self.Show(slot, staticData, traitId)
    self.HoveredSlot = slot
    self.Update(staticData, traitId)
    self:Open()
    self:StartFollowMouse()
end

function self.Hide(slot)
    if self.HoveredSlot ~= slot then return end
    self.HoveredSlot = nil
    self:StopFollowMouse()
    self:Close()
end

function self:StartFollowMouse()
    if self.FollowConnection then return end
    self.FollowConnection = RunService.RenderStepped:Connect(function()
        self:UpdatePosition()
    end)
end

function self:StopFollowMouse()
    if self.FollowConnection then
        self.FollowConnection:Disconnect()
        self.FollowConnection = nil
    end
end

function self:UpdatePosition()
    local frame = self.Frame
    local parent = frame.Parent
    if parent == nil then return end

    local mousePos = UserInputService:GetMouseLocation()
    local parentPos = parent.AbsolutePosition
    local parentSize = parent.AbsoluteSize
    if parentSize.X <= 0 or parentSize.Y <= 0 then return end

    local gap = 12
    local x = (mousePos.X - parentPos.X + gap) / parentSize.X
    local y = (mousePos.Y - parentPos.Y + gap) / parentSize.Y

    local frameSize = frame.AbsoluteSize
    local tipW = frameSize.X / parentSize.X
    local tipH = frameSize.Y / parentSize.Y
    if x + tipW > 1 then x = (mousePos.X - parentPos.X - gap) / parentSize.X - tipW end
    if y + tipH > 1 then y = (mousePos.Y - parentPos.Y - gap) / parentSize.Y - tipH end

    frame.Position = UDim2.new(math.clamp(x, 0, 1), 0, math.clamp(y, 0, 1), 0)
end

function self:Open()
    self.Main:Visible(true)
end
function self:Close()
    self.Main:Visible(false)
end


return self
