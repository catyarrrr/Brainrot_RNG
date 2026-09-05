local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TempData = require(ReplicatedStorage.Datas.TempData :: ModuleScript)

local self : any = {}

function self.init()
    self.LuckUpgradeBtnClickedEvent = shared.Event.new()
    self.BaseUpgradeBtnClickedEvent = shared.Event.new()
    self.CashUpgradeBtnClickedEvent = shared.Event.new()
end
function self.start()
    shared.LeftUI.UpgradeBtnClickedEvent:Connect(function()
        self.Update()
        self:Open()
    end)
end 

function self.Init(main)
	self.Main = shared.Frame.new(main.Menu.Upgrade)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.RegionFrame = self.Frame.StageFrame
    self.RegionFrame.Visible = false
    self.StatsFrame = self.Frame.StatsFrame
    self.StatsFrame.Visible = true
    self.BaseFrame = self.StatsFrame.Base
    self.LuckFrame = self.StatsFrame.Luck
    self.WaveFrame = self.StatsFrame.Wave
    self.CashFrame = self.StatsFrame.Cash
    self.Title = self.Frame.Title
    self.SkinFrame = {
        [1] = self.RegionFrame.ClassicRegionalSkinFrame,
        [2] = self.RegionFrame.DesertRegionalSkinFrame,
        [3] = self.RegionFrame.FrozenRegionalSkinFrame,
        [4] = self.RegionFrame.VolcanicRegionalSkinFrame,
        [5] = self.RegionFrame.WaterfallRegionalSkinFrame
    }

    self.Title.Close.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self:Close()
    end)
    self.Frame.Tab.RegionButtonFrame.Btn.MouseButton1Click:Connect(function()
        self.RegionFrame.Visible = true
        self.StatsFrame.Visible = false
    end)
    self.Frame.Tab.StatsButtonFrame.Btn.MouseButton1Click:Connect(function()
        self.RegionFrame.Visible = false
        self.StatsFrame.Visible = true
    end)
    self.BaseFrame.CashButton.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.PlayerUpgradeGrid:FireServer()
        self:Close()
    end)
    self.BaseFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.BaseUpgrade)
        self:Close()
    end)
    self.LuckFrame.CashButton.MouseButton1Click:Connect(function()
        self.LuckUpgradeBtnClickedEvent:Fire()
        ReplicatedStorage.Remote.PlayerUpgradeLuck:FireServer()
        self:Close()
    end)
    self.LuckFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.LuckUpgrade)
        self:Close()
    end)
    self.LuckFrame.MaxButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_2XLuck)
        self:Close()
    end)
    self.CashFrame.CashButton.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.PlayerUpgradeCash:FireServer()
        self:Close()
    end)
    self.CashFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.CashUpgrade)
        self:Close()
    end)
    self.WaveFrame.CashButton.MouseButton1Click:Connect(function()
        ReplicatedStorage.Remote.PlayerUpgradeStartLevel:FireServer()
        self:Close()
    end)
    self.WaveFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.StartLevelUpgrade)
        self:Close()
    end)
    
    -- for k, v in self.SkinFrame do
    --     v.CashButton.MouseButton1Click:Connect(function()
    --         ReplicatedStorage.Remote.PlayerBuyTeri:FireServer(k)
    --     end)
    --     v.SwitchButton.MouseButton1Click:Connect(function()
    --         ReplicatedStorage.Remote.PlayerSwitchTeri:FireServer(k)
    --     end)
    --     if k ~= 1 then
    --         self.SkinFrame[k].CashButton.TextLabel.Text = shared.VFXHandler.FormatNumber(TempData.TerrDict[k].Cost)
    --     end
    -- end
end

function self.Update()
    local playerData = shared.PlayerDataHandler.GetData()
    if playerData == nil then return end

    -----------     现金升级
    local cashMulti = playerData.Coin.CashMultiplier
    local cashLevel = TempData.GetCashLvlByMultiplier(cashMulti)
    local nextCost = TempData.CashDict[cashLevel].NextCost
    if nextCost then
        self.CashFrame.CashButton.TextLabel.Text = shared.VFXHandler.FormatNumber(nextCost)
        self.CashFrame.DataText.Text = string.format('%.1fx -> %.1fx Cash', TempData.CashDict[cashLevel].Display[1], TempData.CashDict[cashLevel].Display[2])
    else
        self.CashFrame.CashButton.TextLabel.Text = 'MAX'
        self.CashFrame.RBXButton.Visible = false
        self.CashFrame.DataText.Text = string.format('%.1fx Cash', TempData.CashDict[cashLevel].Display)
    end

    -----------     基地升级
    local baseLevel = TempData.GetLevelByGrid(playerData.Grid)
    local data1, data2 = TempData.BaseDict[baseLevel], TempData.BaseDict[baseLevel+1]
    if data2 == nil then
        self.BaseFrame.DataText.Text = string.format('%d*%d BaseSize', data1.Size[1], data1.Size[2])
        self.BaseFrame.CashButton.TextLabel.Text = 'MAX'
        self.BaseFrame.RBXButton.Visible = false
    else
        self.BaseFrame.DataText.Text = string.format('%d*%d -> %d*%d BaseSize', data1.Size[1], data1.Size[2], data2.Size[1], data2.Size[2])
        self.BaseFrame.CashButton.TextLabel.Text = shared.VFXHandler.FormatNumber(data1.NextCost)
    end

    -----------     幸运升级
    local doubleluck = playerData.VIP.DoubleLuck
    local tripleluck = playerData.VIP.TripleLuck
    local luckLevel = playerData.Gacha.Luck
    if doubleluck then luckLevel -= 1 end
    if tripleluck then luckLevel -= 1 end
    local luckData = TempData.LuckDict[luckLevel]
    if luckData.NextCost == nil then
        self.LuckFrame.CashButton.TextLabel.Text = 'MAX'
        self.LuckFrame.RBXButton.Visible = false
        self.LuckFrame.DataText.Text = string.format('%d%% Luck', luckData.Display)
        if doubleluck == true then
            self.LuckFrame.MaxButton.Visible = false
        else
            self.LuckFrame.MaxButton.Visible = true
        end
    else
        self.LuckFrame.MaxButton.Visible = false
        self.LuckFrame.CashButton.TextLabel.Text = shared.VFXHandler.FormatNumber(luckData.NextCost)
        self.LuckFrame.DataText.Text = string.format('%d%% -> %d%% Luck', luckData.Display[1], luckData.Display[2])
        
    end
    
    -----------     开始回合升级
    local startLevel = playerData.Profile.StartLevel
    local startLevelData = TempData.StartLevelDict[startLevel]
    if startLevelData.Next == nil then
        self.WaveFrame.CashButton.TextLabel.Text = 'MAX'
        self.WaveFrame.RBXButton.Visible = false
        self.WaveFrame.DataText.Text = string.format('%d Start Wave', startLevel)
    else
        self.WaveFrame.CashButton.TextLabel.Text = shared.VFXHandler.FormatNumber(startLevelData.Cost)
        self.WaveFrame.DataText.Text = string.format('%d -> %d Start Wave', startLevel, startLevelData.Next)
        
    end
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end


return self
