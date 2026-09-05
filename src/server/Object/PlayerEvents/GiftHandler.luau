local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = ReplicatedStorage
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)

local self = {}

function self.CreateTrade(_, giver, receiver)
	local character = giver.Character

	local tool = character and character:FindFirstChildOfClass('Tool')
	if not tool then warn('tool not found for giver:', giver); return end
	local uid = tool:GetAttribute('UID')
	if not uid then warn('uid not found in tool'); return end

	local towerUID = shared.DataStore.TowerController.GetTowerUIDByUID(giver, uid)
	if towerUID == nil then return end

	local displayName = TowerData.GetData(towerUID).DisplayName
	shared.TradeHandler.Create(giver, receiver, uid, displayName)
	rs.Remote.PlayerGift:FireClient(giver, receiver, true, true ,displayName)
	rs.Remote.PlayerGift:FireClient(receiver, giver, true, false ,displayName)
end
function self.CheckTrade(plr, confirm)
	local trade = shared.TradeHandler.Find(plr.UserId)
	if trade == nil then return end
	local giver = Players:GetPlayerByUserId(trade.Giver[1])
	local receiver = Players:GetPlayerByUserId(trade.Receiver[1])

	if confirm == true then
		local chk = shared.TradeHandler.Confirm(trade.Id, plr.UserId)
		if chk then
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
function self.GiftTower(giver, receiver)
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
