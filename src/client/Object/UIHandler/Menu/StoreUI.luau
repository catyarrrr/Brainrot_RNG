local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SummonData = require(ReplicatedStorage.Datas.SummonData :: ModuleScript)

local self : any = {}

function self.start()
    shared.LeftUI.ShopBtnClickedEvent:Connect(function()
        local playerData = shared.PlayerDataHandler.GetData()
        self.Update(playerData.VIP)
        self:Open()
    end)
end

function self.Init(main)
	self.Main = shared.Frame.new(main.Menu.StoreFrame)
    self.Main:Visible(false)
    
    self.Frame = self.Main.Frame.Frame
    self.OddTips = self.Frame.OddTips
    self.OddTips.Visible = false
    self.ScrollingFrame = self.Frame.ScrollingFrame
    self.Pass1Frame = self.ScrollingFrame.Pass1
    self.Pass2Frame = self.ScrollingFrame.Pass2
    self.Pass3Frame = self.ScrollingFrame.Pass3
    
    self.ScrollingFrame.LuckMultiplierFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas['2xServerLuck'])
    end)
    self.ScrollingFrame.BeginnerPackFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_StarterPack)
    end)
    self.Pass1Frame.DoubleCash.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_2XCash)
    end)
    self.Pass1Frame.Doubleluck.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_2XLuck)
    end)
    self.Pass1Frame.VIP.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_VIP)
    end)
    self.Pass2Frame.Dropx2.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_2XDROP)
    end)
    self.Pass2Frame.Mutationx2.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_2XMUTATION)
    end)
    self.Pass2Frame.FastRoll.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_FASTROLL)
    end)
    self.Pass3Frame.AutoMerge.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_AUTOMERGE)
    end)
    self.Pass3Frame.TripleLuck.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_3XLuck)
    end)

    self.ScrollingFrame.Cash.Cash5000.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas['29999xCash'])
    end)
    self.ScrollingFrame.Cash.Cash20000.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas['89999xCash'])
    end)
    self.ScrollingFrame.Cash.Cash60000.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas['229999xCash'])
    end)
    self.ScrollingFrame.Cash175000.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas['599999xCash'])
    end)
    self.ScrollingFrame.GodPackFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.GodBundle)
    end)
    self.ScrollingFrame.DivinePackFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.DivineBundle)
    end)
    self.ScrollingFrame.LimitedPackFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.LimitedBundle)
    end)
    self.ScrollingFrame.MythicPackFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.MythicBundle)
    end)
    self.ScrollingFrame.SecretPackFrame.RBXButton.MouseButton1Click:Connect(function()
        shared.BuyHandler.BuyProduct(shared.ProductDatas.SecretBundle)
    end)

    --#region  概率按钮
    self.ScrollingFrame.LimitedPackFrame.ODDS.MouseButton1Click:Connect(function()
        self.OpenOddTips(6)
    end)
    self.ScrollingFrame.DivinePackFrame.ODDS.MouseButton1Click:Connect(function()
        self.OpenOddTips(5)
    end)
    self.ScrollingFrame.GodPackFrame.ODDS.MouseButton1Click:Connect(function()
        self.OpenOddTips(4)
    end)
    self.ScrollingFrame.SecretPackFrame.ODDS.MouseButton1Click:Connect(function()
        self.OpenOddTips(3)
    end)
    self.ScrollingFrame.MythicPackFrame.ODDS.MouseButton1Click:Connect(function()
        self.OpenOddTips(2)
    end)
    --#endregion

    self.Frame.OddTips.Close.MouseButton1Click:Connect(function()
        self.OddTips.Visible = false
    end)
    self.Frame.Title.Close.MouseButton1Click:Connect(function()
        shared.SoundHandler:Play('UI_Fail')
        self:Close()
    end)

end

function self.Update(vipData)
    self.ScrollingFrame.BeginnerPackFrame.Purchased.Visible = vipData.StarterPack
    self.Pass1Frame.DoubleCash.Purchased.Visible = vipData.DoubleCash
    self.Pass1Frame.Doubleluck.Purchased.Visible = vipData.DoubleLuck
    self.Pass1Frame.VIP.Purchased.Visible = vipData.VIP
    self.Pass2Frame.Dropx2.Purchased.Visible = vipData.Dropx2
    self.Pass2Frame.Mutationx2.Purchased.Visible = vipData.Mutationx2
    self.Pass2Frame.FastRoll.Purchased.Visible = vipData.FastRoll
    self.Pass3Frame.AutoMerge.Purchased.Visible = vipData.AutoMerge
    self.Pass3Frame.TripleLuck.Purchased.Visible = vipData.TripleLuck
end

function self:Open()
    self.Main:TweenOpen()
end
function self:Close()
    self.Main:TweenClose()
end

function self.OpenOddTips(key)
    local data = SummonData.GetOddDict(key)
    if data == nil then return end

    self.OddTips.Title.TextLabel.Text = data.name
    self.OddTips.Desc.TextLabel.Text = data.desc

    local names = {}
    local rates = {}
    for key, value in pairs(data.odds) do
        table.insert(names, key)
        table.insert(rates, tostring(value) .. '%')
    end

    self.OddTips.Countend.name.Text = table.concat(names, "\n")
    self.OddTips.Countend.rate.Text = table.concat(rates, "\n")

    self.OddTips.Visible = true
end


return self
