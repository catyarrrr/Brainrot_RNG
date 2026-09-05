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
        self:Close()
    end)
    self.ConfirmBtn.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.PlayerGift:FireServer(true)
    end)
    self.CancelBtn.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.PlayerGift:FireServer(false)
    end)
end

function self.ToggleGiver(other : Player, alienName)
    -- if self.ConfirmConn then
    --     self.ConfirmConn:Disconnect()
    --     self.ConfirmConn = nil
    -- end
    -- if self.CancelConn then
    --     self.CancelConn:Disconnect()
    --     self.CancelConn = nil
    -- end

    self.Content.Text = string.format('Waiting for %s \n to accept yr %s', other.DisplayName, alienName)

    self.ConfirmBtn.ONText.Text = 'Waiting'
    self.CancelBtn.ONText.Text = 'Cancel'

end 
function self.ToggleReceiver(other : Player, alienName)
    -- if self.ConfirmConn then
    --     self.ConfirmConn:Disconnect()
    --     self.ConfirmConn = nil
    -- end
    -- if self.CancelConn then
    --     self.CancelConn:Disconnect()
    --     self.CancelConn = nil
    -- end

    self.Content.Text = string.format('%s wants to give u \n %s', other.DisplayName, alienName)
    
    self.ConfirmBtn.ONText.Text = 'Accept'
    self.CancelBtn.ONText.Text = 'Decline'
end 

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end


return self
