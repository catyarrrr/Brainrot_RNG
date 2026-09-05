local Players = game:GetService("Players")
local player = Players.LocalPlayer

local self : any = {}

function self.start()
    
end

function self.Init(main)
	self.Main = shared.Frame.new(main.Touch)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame
    self.Frame.CancelBtn.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
		local tool = player.Character:FindFirstChildWhichIsA('Tool')
		if tool then tool.Parent = player.Backpack end
    end)
    self.Frame.PlaceBtn.MouseButton1Click:Connect(function()
		local tool = player.Character:FindFirstChildWhichIsA('Tool')
		if tool then tool:Activate() end
    end)
end

function self:Open()
    self.Main:Visible(true)
end
function self:Close()
    self.Main:Visible(false)
end


return self
