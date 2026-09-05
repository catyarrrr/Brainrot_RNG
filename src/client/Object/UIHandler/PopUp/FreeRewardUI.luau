local GroupService = game:GetService("GroupService")
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GROUP_ID = 406167420

local self = {Main = nil}

function self.init()
    self.FreeRewardEvent = shared.Event.new()
end

function self.start()
    shared.PlayerDataHandler.DataChangedEvent:Connect(function(data, tag)
        if tag and table.find(tag, 'Group') then
            self.Update()
        end
    end)
end

function self.Init(main)
	self.Main = shared.Frame.new(main.PopUp.FreeRewardFrame)
    self.Main:Visible(false)

    self.Main.Frame.Frame.Claim.MouseButton1Click:Connect(function()
        local player = Players.LocalPlayer
        if player:IsInGroupAsync(GROUP_ID) then
            ReplicatedStorage.Remote.PlayerClaimGroupReward:FireServer()
        else
            shared.SoundHandler:Play('UI_Fail')
        end
    end)

    self.Main.Frame.Frame.JoinTheGroup.MouseButton1Click:Connect(function()
        GroupService:PromptJoinAsync(GROUP_ID)
    end)

    self.Main.Frame.Frame.Title.CloseBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self:Close()
    end)
end

function self.Update()
    local playerData = shared.PlayerDataHandler.GetData()

    if playerData.States.GroupReward == true then
        self.Main.Frame.Frame.Claim.Text = 'Claimed'
        self.Main.Frame.Frame.Claim.BackgroundColor3 = Color3.fromRGB(66, 63, 63)
    end
end

function self:Open()
    self.Main:TweenOpen()
end

function self:Close()
    self.Main:TweenClose()
end

return self
