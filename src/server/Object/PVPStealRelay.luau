--[[
	PVPStealRelay (Server)
	PVP 偷钱跨服中转：
		当对手不在本服（存档被锁 = 在别的服务器在线）时，通过 MessagingService 请求
		对方所在服务器实时扣款并提示，再把实偷金额回传给攻击方所在服务器发放。

	消息：
		{ Type = 'Steal',  RequestId, TargetUserId, AttackerUserId, AttackerName, Rate }
		{ Type = 'Result', RequestId, ReplyTo, AttackerUserId, Amount }
]]

local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local TOPIC = 'PVPSteal'
local WAIT_TIMEOUT = 3
local DEDUPE_TTL = 5 * 60
local MAX_DEDUPE = 1024

local self : any = {}

local processed = {}   -- requestId -> clock
local waiters = {}     -- requestId(请求) -> BindableEvent

--	消息投递可能重复，按 RequestId 去重
local function IsDuplicate(requestId)
	local now = os.clock()
	local seen = processed[requestId]
	if seen ~= nil and (now - seen) < DEDUPE_TTL then return true end
	processed[requestId] = now

	if #processed > 0 then
		local count = 0
		for id, time in pairs(processed) do
			count += 1
			if (now - time) >= DEDUPE_TTL then processed[id] = nil end
		end
		while count > MAX_DEDUPE do
			for id in pairs(processed) do
				processed[id] = nil
				count -= 1
				break
			end
		end
	end
	return false
end

local function OnMessage(message)
	local data = message and message.Data
	if type(data) ~= 'table' or type(data.Type) ~= 'string' then return end
	if type(data.RequestId) ~= 'string' then return end
	if IsDuplicate(data.RequestId) then return end

	if data.Type == 'Steal' then
		local target = Players:GetPlayerByUserId(data.TargetUserId)
		if target == nil then return end

		local stolen = shared.DataStore.ApplyOnlineSteal(target, data.AttackerName, data.Rate)
		if stolen > 0 then
			pcall(function()
				MessagingService:PublishAsync(TOPIC, {
					Type = 'Result',
					RequestId = HttpService:GenerateGUID(false),
					ReplyTo = data.RequestId,
					AttackerUserId = data.AttackerUserId,
					Amount = stolen,
				})
			end)
		end
	elseif data.Type == 'Result' then
		local waiter = waiters[data.ReplyTo]
		if waiter ~= nil then
			waiter:Fire(data.Amount or 0)
			return
		end

		--	请求方已超时：攻击者若还在线，直接补发
		local attacker = Players:GetPlayerByUserId(data.AttackerUserId)
		if attacker ~= nil then
			shared.DataStore.CreditSteal(attacker, data.Amount or 0)
		end
	end
end

--	请求对方所在服务器代扣，等待回包（带超时），返回实偷金额
function self.StealRemote(targetUserId, attacker, rate)
	local requestId = HttpService:GenerateGUID(false)
	local waiter = Instance.new('BindableEvent')
	waiters[requestId] = waiter

	local ok = pcall(function()
		MessagingService:PublishAsync(TOPIC, {
			Type = 'Steal',
			RequestId = requestId,
			TargetUserId = targetUserId,
			AttackerUserId = attacker.UserId,
			AttackerName = attacker.DisplayName,
			Rate = rate,
		})
	end)

	local amount = 0
	if ok then
		local timeoutThread = task.delay(WAIT_TIMEOUT, function() waiter:Fire(nil) end)
		amount = waiter.Event:Wait() or 0
		task.cancel(timeoutThread)
	end

	waiters[requestId] = nil
	waiter:Destroy()
	return amount
end

function self.start()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, OnMessage)
		end)
		if not ok then warn('[PVPStealRelay] subscribe failed:', err) end
	end)
end

return self
