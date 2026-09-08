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


return self
