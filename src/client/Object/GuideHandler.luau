local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local self = {}
local CheckGuide, GuideToRoll = nil

local GuideConfig = {
    [1] = 'GuideToRoll',
    [2] = 'GuideToEquip',
    [3] = 'GuideToPlace',
    [4] = 'GuideToStart',
}
local GuideStep = {
    GuideToRoll = function()
        local char = player.Character
        local root = char and char:WaitForChild('HumanoidRootPart')
        if root == nil then return end

        local rollPart = shared.GridHandler.GachaMachine.Roll
        shared.UIHandler.ToggleGuide(true, 'Roll and buy yr first brainrot')
        shared.VFXHandler.ShowGuideBeam('GuideToRoll', rollPart, nil, root, nil)
    end,
    GuideToEquip = function()   
        local char = player.Character
        local root = char and char:WaitForChild('HumanoidRootPart')
        if root == nil then return end

        shared.UIHandler.ToggleGuide(true, 'Equip yr first brainrot')
        shared.UIHandler.SetMask(shared.UIHandler.GuideCover.EquipGuide)
    end,
    GuideToPlace = function()   
        local char = player.Character
        local root = char and char:WaitForChild('HumanoidRootPart')
        if root == nil then return end
        local area = shared.GridHandler.Area

        shared.UIHandler.ToggleGuide(true, 'Place yr first brainrot')
        shared.VFXHandler.ShowGuideBeam('GuideToRoll', area.AreaPos, Vector3.new(0, 0, 10), root, nil)
    end,
    GuideToStart = function()   
        local char = player.Character
        local root = char and char:WaitForChild('HumanoidRootPart')
        if root == nil then return end

        shared.UIHandler.ToggleGuide(true, 'Start yr first Battle!!!')
        shared.UIHandler.SetMask(shared.UIHandler.TopUI.StartBtn)
    end,
}

function self.init()
	
end

function self.start()
    shared.PlayerDataHandler.DataChangedEvent:Connect(function(self, tag)
        if tag and table.find(tag, 'Guide') then DisableGuide(); CheckGuide() end
    end, self)
	while shared.GridHandler.Initiated == false do task.wait() end

    CheckGuide()
end 

function CheckGuide()
    local playerData = shared.PlayerDataHandler.GetData()
    if playerData == nil then return end
    local guideData = playerData.Guide

    for k, v in guideData do
        if v == false then
            GuideStep[GuideConfig[k]]()
            break;
        end
    end
end

function DisableGuide()
    shared.VFXHandler.HideGuideBeam()
    shared.UIHandler.ToggleGuide(false)
    shared.UIHandler.DisableMask()
end

return self
