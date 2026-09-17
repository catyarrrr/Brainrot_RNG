local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = ReplicatedStorage
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local self = {}

function self.start()
	Players.PlayerRemoving:Connect(function(player)
		self.CancelTrade(player)
	end)
end

function self.CreateTrade(_, giver, receiver)
	if giver == nil or receiver == nil or giver == receiver then return end

	if shared.TradeHandler.Find(giver.UserId) or shared.TradeHandler.Find(receiver.UserId) then
		rs.Remote.ServerWarn:FireClient(giver, 'u or the other player is already trading')
		return
	end

	local character = giver.Character

	local tool = character and character:FindFirstChildOfClass('Tool')
	if not tool then warn('tool not found for giver:', giver); return end
	local uid = tool:GetAttribute('UID')
	if not uid then warn('uid not found in tool'); return end

	local towerUID = shared.DataStore.TowerController.GetTowerUIDByUID(giver, uid)
	if towerUID == nil then return end

	local towerData = TowerData.GetData(towerUID)
	local displayName = towerData and towerData.DisplayName
	if displayName == nil then warn('displayName not found for tower:', towerUID); return end

	shared.TradeHandler.Create(giver, receiver, uid, displayName)
	rs.Remote.PlayerGift:FireClient(giver, receiver, true, true ,displayName)
	rs.Remote.PlayerGift:FireClient(receiver, giver, true, false ,displayName)
end
function self.CheckTrade(plr, confirm)
	local trade = shared.TradeHandler.Find(plr.UserId)
	if trade == nil then return end
	local giver = Players:GetPlayerByUserId(trade.Giver[1])
	local receiver = Players:GetPlayerByUserId(trade.Receiver[1])

	-- 交易一方已经离开，直接清理，避免对 nil 玩家调用 FireClient / GiftTower
	if giver == nil or receiver == nil then
		shared.TradeHandler.Destroy(trade.Id)

		local remaining = giver or receiver
		if remaining then
			rs.Remote.PlayerGift:FireClient(remaining, nil, false)
			rs.Remote.ServerWarn:FireClient(remaining, 'the other player left, gifting cancelled')
		end

		return
	end

	if confirm == true then
		local chk = shared.TradeHandler.Confirm(trade.Id, plr.UserId)
		if chk then
			-- 先销毁交易再执行，防止重复点击 / 重复 FireServer 再次触发奖励和提示
			shared.TradeHandler.Destroy(trade.Id)

			self.GiftTower(giver, receiver)
			rs.Remote.ServerTip:FireClient(giver, 'u gift ' .. receiver.DisplayName .. ' yr ' .. trade.AlienName)
			rs.Remote.ServerTip:FireClient(receiver, 'u got ' .. trade.AlienName .. ' from ' .. giver.DisplayName)
			rs.Remote.PlayerGift:FireClient(giver, receiver, false)
			rs.Remote.PlayerGift:FireClient(receiver, giver, false)
		end
	else
		shared.TradeHandler.Destroy(trade.Id)
		rs.Remote.PlayerGift:FireClient(giver, receiver, false)
		rs.Remote.PlayerGift:FireClient(receiver, giver, false)

		if plr == giver then
			rs.Remote.ServerWarn:FireClient(receiver, plr.DisplayName .. ' cancel gifting')
		elseif plr == receiver then
			rs.Remote.ServerWarn:FireClient(giver, plr.DisplayName .. ' decline yr gift')
		end
	end
end
-- 玩家离开时取消其未完成的交易，并通知另一方关闭界面
function self.CancelTrade(player)
	local trade = shared.TradeHandler.Find(player.UserId)
	if trade == nil then return end

	shared.TradeHandler.Destroy(trade.Id)

	local otherId = shared.TradeHandler.GetOtherUserId(trade, player.UserId)
	local other = otherId and Players:GetPlayerByUserId(otherId)

	if other then
		rs.Remote.PlayerGift:FireClient(other, player, false)
		rs.Remote.ServerWarn:FireClient(other, player.DisplayName .. ' left, gifting cancelled')
	end
end
function self.GiftTower(giver, receiver)
	if giver == nil or receiver == nil then return end

	local character = giver.Character

	local tool = character and character:FindFirstChildOfClass('Tool')
	if not tool then warn('tool not found for giver:', giver); return end
	local uid = tool:GetAttribute('UID')
	if not uid then warn('uid not found in tool'); return end

	tool:Destroy()

	shared.BackpackHandler.RemovePlayerBackpackTool(giver, uid)

	shared.DataStore.TowerController.Gift(giver, receiver, uid)

	shared.BackpackHandler.AddPlayerBackpackTool(receiver, uid)
end

return self
