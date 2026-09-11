local self : any = {}

function self.Init(main)
	self.RightFrame = main.Hud.Right
	self.Announcements = main.PopUp.Announcements
end

function self.Update(playerData)
	self.RightFrame.RandomHero.Btn.MouseButton1Click:Connect(function()
		shared.BuyHandler.BuyProduct(shared.ProductDatas.RanBrainrot)
	end)
	self.RightFrame.StarterPack.Btn.MouseButton1Click:Connect(function()
		shared.BuyHandler.BuyPass(shared.ProductDatas.PASSID_StarterPack)
	end)
	self.RightFrame.LegendaryBundle.Btn.MouseButton1Click:Connect(function()
		shared.BuyHandler.BuyProduct(shared.ProductDatas.LegendaryBundle)
	end)
	if playerData.States.GroupReward == true then
		self.RightFrame.Reward.FreeReward.Visible = false
	else
		self.RightFrame.Reward.FreeReward.Visible = true
		self.RightFrame.Reward.FreeReward.MouseButton1Click:Connect(function()
			shared.SoundHandler:Play('UI_Success')
			shared.UIHandler.TriggerFreeRewardEvent:Fire()
		end)
	end
	
	self.RightFrame.Reward.DailyReward.Visible = true
	self.RightFrame.Reward.DailyReward.MouseButton1Click:Connect(function()
		shared.SoundHandler:Play('UI_Success')
		if playerData.States.LoginReward.Day <= shared.Config.LOGIN_MAXDAY then
			shared.UIHandler.DailyUI.Update(playerData)
			shared.UIHandler.DailyUI:Open()
		else
			shared.UIHandler.WeeklyDailyUI.Update(playerData)
			shared.UIHandler.WeeklyDailyUI:Open()
		end
	end)

	self.UpdateVIP(playerData.VIP)
end

function self.UpdateVIP(vipData)
	if vipData.StarterPack == true then
		self.RightFrame.LegendaryBundle.Visible = true
		self.RightFrame.StarterPack.Visible = false
	else
		self.RightFrame.LegendaryBundle.Visible = false
		self.RightFrame.StarterPack.Visible = true
	end
end

return self
