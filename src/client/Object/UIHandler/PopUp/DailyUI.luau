local ReplicatedStorage = game:GetService("ReplicatedStorage")
local self : any = {}


function self.Init(frame)
	self.Main = shared.Frame.new(frame.PopUp.Daily)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.DayFrame = {}
    table.insert(self.DayFrame, self.Frame.FrameLeft.day1)
    table.insert(self.DayFrame, self.Frame.FrameLeft.day2)
    table.insert(self.DayFrame, self.Frame.FrameLeft.day3)
    table.insert(self.DayFrame, self.Frame.FrameLeft.day4)
    table.insert(self.DayFrame, self.Frame.FrameRight.day5)
    table.insert(self.DayFrame, self.Frame.FrameRight.day6)
    table.insert(self.DayFrame, self.Frame.FrameRight.day7)

    for day, frame in self.DayFrame do
        frame.ClaimButton.MouseButton1Click:Connect(function()
            ReplicatedStorage.Remote.PlayerClaimLoginReward:FireServer(day)
        end)
    end 

    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self:Close()
    end)
end

function self.Update(playerData)

    for i = 1, playerData.States.LoginReward.Day - 1 do
        self.DayFrame[i].Purchased.Visible = true
    end

end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end


return self
