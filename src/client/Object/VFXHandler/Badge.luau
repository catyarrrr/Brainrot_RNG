local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}
module.__index = module

local collection = {}
local badge = ReplicatedStorage.Assets.UI.Badge


function module.new(_, btn)
    if btn == nil then return end
    if collection[btn] ~= nil then return end

	local self = setmetatable({}, module)
	self.Btn = btn
    self.Badge = badge:Clone()
    self.Badge:WaitForChild('LocalScript').Enabled = true
    self.Badge.Size = UDim2.new(0.7, 0, 0.7, 0)
    self.Badge.Position = UDim2.new(0.705, 0, -0.295, 0)
    self.Badge.Parent = self.Btn
    self.Destroyed = false

    if self.Btn:IsA('GuiButton') then
        self.Btn.MouseButton1Click:Connect(function()
            self:Destroy()
        end)
    end

    collection[self.Btn] = self
end

function module:Destroy()
    self.Destroyed = true
    self.Badge:Destroy()
    collection[self.Btn] = nil
end

return module