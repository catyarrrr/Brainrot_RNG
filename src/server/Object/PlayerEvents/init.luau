local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = ReplicatedStorage

local self = {}

function self.init()
	for _, module in pairs(script:GetChildren()) do
		if module:IsA('ModuleScript') then
			if self[module.Name] then warn('duplicate:', module.Name) end
			self[module.Name] = require(module)
		end
	end
end

function self.start()
	shared.CharHandler.GiftEvent:Connect(self.GiftHandler.CreateTrade)
	rs.Remote.Tower.TowerSpawn.OnServerEvent:Connect(self.TowerHandler.SpawnTower)
	rs.Remote.Tower.TowerDespawn.OnServerEvent:Connect(self.TowerHandler.DespawnTower)
	rs.Remote.Tower.TowerPickUpAll.OnServerEvent:Connect(self.TowerHandler.PickUpAll)
	rs.Remote.Tower.Equip.OnServerEvent:Connect(self.TowerHandler.EquipTower)
	rs.Remote.Tower.QuickMerge.OnServerEvent:Connect(self.TowerHandler.QuickMerge)
	rs.Remote.Tower.SetTool.OnServerEvent:Connect(self.TowerHandler.SetTool)
	rs.Remote.Tower.UnToolAll.OnServerEvent:Connect(self.TowerHandler.UnToolAll)
	rs.Remote.Tower.RollTrait.OnServerEvent:Connect(self.TowerHandler.TraitTower)
	rs.Remote.Tower.TowerClone.OnServerEvent:Connect(self.TowerHandler.CloneTower)
	rs.Remote.Tower.CompleteClone.OnServerEvent:Connect(self.TowerHandler.CompleteClone)
	rs.Remote.Tower.Evolve.OnServerEvent:Connect(self.TowerHandler.EvolveTower)
	rs.Remote.Tower.CompleteEvolve.OnServerEvent:Connect(self.TowerHandler.CompleteEvolve)
	rs.Remote.Tower.AutoMerge.OnServerEvent:Connect(self.TowerHandler.AutoMerge)
	rs.Remote.Tower.Sell.OnServerEvent:Connect(self.TowerHandler.SellTower)
	rs.Remote.Tower.Estimate.OnServerEvent:Connect(self.TowerHandler.EstimateTower)
	rs.Remote.Tower.SellAll.OnServerEvent:Connect(self.TowerHandler.SellAllTowers)
	rs.Remote.Tower.Combine.OnServerEvent:Connect(self.TowerHandler.CombineTower)
	rs.Remote.PlayerPathInitiated.OnServerEvent:Connect(shared.Tower.AsyncTower)
	rs.Remote.Tower.ClaimTotem.OnServerEvent:Connect(self.TotemHandler.ClaimTotem)
	rs.Remote.Tower.PrayTotem.OnServerEvent:Connect(self.TotemHandler.PrayTotem)
	rs.Remote.Tower.FeedTotem.OnServerEvent:Connect(self.TotemHandler.FeedTotem)
	rs.Remote.Tower.EquipTotem.OnServerEvent:Connect(self.TotemHandler.EquipTotem)
	rs.Remote.PlayerGift.OnServerEvent:Connect(self.GiftHandler.CheckTrade)
	rs.Remote.Game.GameStart.OnServerEvent:Connect(self.GameHandler.GameStart)
	rs.Remote.Game.RushStart.OnServerEvent:Connect(self.GameHandler.RushStart)
	rs.Remote.Game.GameStop.OnServerEvent:Connect(self.GameHandler.GameStop)
	rs.Remote.Game.GameAuto.OnServerEvent:Connect(self.GameHandler.GameAuto)
	rs.Remote.Game.GameSpeedModify.OnServerEvent:Connect(self.GameHandler.ModifyGameSpeed)
	rs.Remote.Fuse.OnServerEvent:Connect(self.GameHandler.FuseFragment)
	rs.Remote.PlayerUpgradeGrid.OnServerEvent:Connect(self.UpgradeHandler.UpgradeGrid)
	rs.Remote.PlayerUpgradeCash.OnServerEvent:Connect(self.UpgradeHandler.UpgradeCash)
	rs.Remote.PlayerUpgradeLuck.OnServerEvent:Connect(self.UpgradeHandler.UpgradeLuck)
	rs.Remote.PlayerUpgradeStartLevel.OnServerEvent:Connect(self.UpgradeHandler.UpgradeStartLevel)
	rs.Remote.PlayerUpgradeCard.OnServerEvent:Connect(self.UpgradeHandler.UpgradeCard)
	rs.Remote.PlayerBuyTeri.OnServerEvent:Connect(self.UpgradeHandler.BuyTerritory)
	rs.Remote.PlayerClaimVIPDaily.OnServerEvent:Connect(self.RewardHandler.ClaimVIPDaily)
	rs.Remote.PlayerClaimGroupReward.OnServerEvent:Connect(self.RewardHandler.ClaimFreeReward)
	rs.Remote.PlayerClaimTask.OnServerEvent:Connect(self.RewardHandler.CheckTask)
	rs.Remote.PlayerSpin.OnServerEvent:Connect(self.RewardHandler.ClaimWheelReward)
	rs.Remote.PlayerSpinUpdate.OnServerEvent:Connect(self.RewardHandler.OpenWheelFrame)
	rs.Remote.PlayerClaimOfflineReward.OnServerEvent:Connect(self.RewardHandler.ClaimOfflineReward)
	rs.Remote.PlayerClaimLoginReward.OnServerEvent:Connect(self.RewardHandler.ClaimLoginReward)
	rs.Remote.PlayerClaimWeeklyLoginReward.OnServerEvent:Connect(self.RewardHandler.ClaimWeeklyDaily)

	rs.Remote.Tower.PremiumSlot.OnServerEvent:Connect(self.TowerHandler.UnlockCloneSlot)
end

return self
