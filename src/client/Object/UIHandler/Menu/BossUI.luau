local ReplicatedStorage = game:GetService("ReplicatedStorage")
local self : any = {}


function self.Init(frame)
	self.Main = shared.Frame.new(frame.Menu.BOSS)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.Tips = self.Frame.Countdown
    self.ChallengeCount = self.Frame.ChallengeCount
    self.ChallengeButtons = {self.Frame.Button.x1Challenge, self.Frame.Button.x2Challenge, self.Frame.Button.x3Challenge}
    
    self.Frame.Button:FindFirstChild('x1Challenge').MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Game.RushStart:FireServer(1)
    end)
    self.Frame.Button:FindFirstChild('x2Challenge').MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Game.RushStart:FireServer(2)
    end)
    self.Frame.Button:FindFirstChild('x3Challenge').MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.Game.RushStart:FireServer(3)
    end)

    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        self:Close()
    end)
end

function self.Update(playerData)
    self.StartTick(playerData.BossChallenge)

    local now = workspace:GetServerTimeNow()
    local challengeData = playerData.BossChallenge
    local challengeCount = challengeData.Count
    local recoverCount = 0
    if now >= challengeData.RecoverTime then
        recoverCount = math.floor((now - challengeData.RecoverTime) / shared.Config.BOSSCHALLENGE_RECOVER + 1)
    end
    local count = math.min(challengeCount + recoverCount, shared.Config.BOSSCHALLENGE_MAXCOUNT)
    self.ChallengeCount.Text = 'Attempts: ' .. tostring(count)

    for k, v in self.ChallengeButtons do
        if k > count then
            v.CanChallenge.Visible = false
            v.CantChallenge.Visible = true
        else
            v.CanChallenge.Visible = true
            v.CantChallenge.Visible = false
        end
    end
end

function self.StartTick(challengeData)
    if self.CountdownTask then
        task.cancel(self.CountdownTask)
        self.CountdownTask = nil
    end
        
    local remaining = challengeData.RecoverTime - workspace:GetServerTimeNow()
    if remaining > 0 then
        self.Countdown = true
        self.CountdownTask = task.spawn(function()
            while self.Countdown do
                local r = challengeData.RecoverTime - workspace:GetServerTimeNow()
                if r <= 0 then
                    self.Tips.Text = ''
                    self.Countdown = false
                    break
                end
                self.Tips.Text = shared.Tool.FormatTime(r)
                task.wait(1)
            end
        end)
    else
        self.Tips.Text = ''
    end
end


function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Countdown = nil
    self.Main:TweenClose()
end


return self
