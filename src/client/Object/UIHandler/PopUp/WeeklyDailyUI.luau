local ReplicatedStorage = game:GetService("ReplicatedStorage")
local self : any = {}


function self.Init(frame)
	self.Main = shared.Frame.new(frame.PopUp.WeeklyDaily)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.Days = {}
    for _, v in self.Frame.DailyReward:GetChildren() do
        if v:IsA('Frame') then
            v.Purchased.Visible = false
            self.Days[tonumber(v.Name)] = v
        end
    end

    self.Tips = self.Frame.Tips
    self.ClaimBtn = self.Frame.Claim

    self.ClaimBtn.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.PlayerClaimWeeklyLoginReward:FireServer()
    end)

    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        self:Close()
    end)
end

function self.Update(playerData)
    local weekly = playerData.States.WeeklyDaily
    if weekly == nil then return end
	local today = math.floor(workspace:GetServerTimeNow() / 86400)
    if weekly.LastLoginDay == today then
        self.ClaimBtn.Visible = false
        self.Tips.Visible = true
    else
        self.ClaimBtn.Visible = true
        self.Tips.Visible = false
    end


    for day, frame in pairs(self.Days) do
        if frame.Purchased then
            frame.Purchased.Visible = day < weekly.Day
        end
    end
end

function self:Open()
    self.Update(shared.PlayerDataHandler.GetData())
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end


return self
