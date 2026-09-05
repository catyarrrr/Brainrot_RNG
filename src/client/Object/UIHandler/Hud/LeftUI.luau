local self : any = {}

function self.init()
    self.HeroBtnClickedEvent = shared.Event.new()
    self.ItemBtnClickedEvent = shared.Event.new()
    self.UpgradeBtnClickedEvent = shared.Event.new()
    self.IndexBtnClickedEvent = shared.Event.new()
    self.ShopBtnClickedEvent = shared.Event.new()
end

function self.Init(main)
	self.Main = shared.Frame.new(main.Hud.Left)
    self.Main:Visible(true)
    
    self.Frame = self.Main.Frame
    self.Frame:FindFirstChild('Items&Heros').HerosButton.MouseButton1Click:Connect(function()
        self.HeroBtnClickedEvent:Fire()
    end)
    self.Frame:FindFirstChild('Items&Heros').ItemsButton.MouseButton1Click:Connect(function()
        self.ItemBtnClickedEvent:Fire()
    end)
    self.Frame:FindFirstChild('Profile&Upgrade').IndexButton.MouseButton1Click:Connect(function()
        self.IndexBtnClickedEvent:Fire()
    end)
    self.Frame:FindFirstChild('Profile&Upgrade').UpgradeButton.MouseButton1Click:Connect(function()
        self.UpgradeBtnClickedEvent:Fire()
    end)
    self.Frame:FindFirstChild('Profile&Totem').TotemButton.MouseButton1Click:Connect(function()
        shared.UIHandler.TotemUI.Update()
        shared.UIHandler.TotemUI:Open()
    end)
    self.Frame.ShopButton.MouseButton1Click:Connect(function()
        self.ShopBtnClickedEvent:Fire()
    end)

end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end


return self
