local ReplicatedStorage = game:GetService("ReplicatedStorage")
local self : any = {}


function self.Init(frame)
	self.Main = shared.Frame.new(frame.PopUp.Gift)
    self.Main:Visible(false)

    self.Frame = self.Main.Frame.Frame
    self.ConfirmBtn = self.Frame.Confirm
    self.CancelBtn = self.Frame.Cancel
    self.Content = self.Frame.Frame.Content

    self.Frame.Close.MouseButton1Click:Connect(function()
        self:Send(false)
    end)
    self.ConfirmBtn.MouseButton1Click:Connect(function()
        self:Send(true)
    end)
    self.CancelBtn.MouseButton1Click:Connect(function()
        self:Send(false)
    end)
end

-- 按钮防连点：一次交易只允许发送一次请求，避免重复触发 notice
function self:Send(confirm)
    if self.Sending then return end
    self.Sending = true
    ReplicatedStorage.Remote.PlayerGift:FireServer(confirm)
end

function self.ToggleGiver(other : Player, alienName)
    self.Sending = false

    self.Content.Text = string.format('Waiting for %s \n to accept yr %s', other.DisplayName, alienName)

    self.ConfirmBtn.ONText.Text = 'Waiting'
    self.CancelBtn.ONText.Text = 'Cancel'

end 
function self.ToggleReceiver(other : Player, alienName)
    self.Sending = false

    self.Content.Text = string.format('%s wants to give u \n %s', other.DisplayName, alienName)
    
    self.ConfirmBtn.ONText.Text = 'Accept'
    self.CancelBtn.ONText.Text = 'Decline'
end 

function self:Open()
    self.Sending = false
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end


return self
