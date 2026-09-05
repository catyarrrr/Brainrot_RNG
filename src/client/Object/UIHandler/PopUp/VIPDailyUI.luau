local ReplicatedStorage = game:GetService("ReplicatedStorage")
local self : any = {}
local StartTimer = nil

function self.start()
    
end

function self.Init(main)
	self.Main = shared.Frame.new(main.PopUp.VIPDaily)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.Frame.ClaimStart.MouseButton1Click:Connect(function()
        local playerData = shared.PlayerDataHandler.GetData()
        if playerData.VIP.VIP == false then shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_VIP); return end
        ReplicatedStorage.Remote.PlayerClaimVIPDaily:FireServer()
    end)
    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        if self.TimerTask then 
            task.cancel(self.TimerTask)
            self.TimerTask = nil
        end
        self:Close()
    end)
end

function self.Update(playerData)
    local now = workspace:GetServerTimeNow()
    if playerData.States.VIPDaily >= now then 
        StartTimer(self)
        self.Frame.ClaimStart.Visible = false
        self.Frame.ClaimRewardText.Visible = true
    else
        self.Frame.ClaimStart.Visible = true
        self.Frame.ClaimRewardText.Visible = false
    end
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end

function StartTimer(self)
    if self.TimerTask then return end
    self.TimerTask = task.spawn(function()
        local endTime = shared.PlayerDataHandler.GetData().States.VIPDaily
        while true do
            local remain = math.ceil(endTime - workspace:GetServerTimeNow())
            if remain <= 0 then break  end

            self.Frame.ClaimRewardText.Text = string.format('Come back in %s to claim your reward!', shared.Tool.FormatTime(remain))

            task.wait(.2)
        end 
    end)
end

return self
