local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = game:GetService('ReplicatedStorage')
local LevelData = require(rs.Datas.LevelData :: ModuleScript)

local SPAWN_SEED, DAMAGE_SEED, CRIT_SEED, SPAWN_DELAY = 1312423412, 810498141, 987654321, 12

local Class, collections, self = {loaded = {}}, {}, nil
Class.__index = Class

local EnumState = {
	BeforeSpawning = {
		name = 'BeforeSpawning',

		enter = function(self)
			self.Valid = true
		end,

		duration = 0,

		next = 'Spawning',
	},

	Spawning = {
		name = 'Spawning',

		enter = function(self)
			shared.Area.NextMapEvent:Fire(self.PathId, self.Round, self.Rush)
			self.Valid = false
			
			shared.Thread:Spawn(function()
				if self.Rush then
					local levelData = LevelData.GetRushData(self.Round)
					shared.Enemy.new(self, self.Round, 'Rush', self.PathId, levelData.Health, levelData.Cash)
				else
					local levelData = LevelData.GetData(self.Round)
					
					for i=1, levelData.Amount do
						self.SpawnRandom:NextInteger(0, 0)
						shared.Enemy.new(self, self.Round, 'Mob', self.PathId)
						self.Task:Wait(SPAWN_DELAY)
					end
					if levelData.Elite then
						shared.Enemy.new(self, self.Round, 'Elite', self.PathId)
					elseif levelData.Boss then
						shared.Enemy.new(self, self.Round, 'Boss', self.PathId)
					end
				end

				self.Valid = true
			end)
		end,

		duration = 0,

		exit = function(self)

		end,

		next = 'InRound',
	},

	InRound = {
		name = 'InRound',

		enter = function(self)
			self.Valid = true
		end,

		duration = 0,

		exit = function(self)
			self.Round += 1
		end,

		next = 'BeforeSpawning'
	},
}

function Class.init()
	Class.GameWinEvent = shared.Event.new()
	Class.GameOverEvent = shared.Event.new()
	Class.GameStartedEvent = shared.Event.new()
	Class.GameFarmEvent = shared.Event.new()
end

function Class.start()
	shared.DataStore.PlayerDataLoadedEvent:Connect(Class.new)
	shared.DataStore.PlayerExitEvent:Connect(function(self, player)
		local game = collections[player]
		if game == nil then warn('player game not found for player:', player); return end

		ReplicatedStorage.Remote.Game.PlayerExit:FireAllClients(player, game.PathId)
		game:Destroy()
	end, self)
end

function Class.new(_, player)
	-- print('new game for player:', player)
	if collections[player] ~= nil then warn('player game already exist for player :', player); return end

	local self = setmetatable({}, Class)

	self.Task = shared.Task.new(player)
	self.State = nil
	self.WaitingCount = 0
	self.Round = 0
	self.Timer = 0
	self.PathId = shared.DataStore.GetPlayerCurPath(player)
	self.Player = player
	self.Destroyed = false
	self.Auto = false
	self.Started = false

	collections[player] = self
	Class.loaded[player] = true
	
	return self
end

function Class.Get(player)
	local game = collections[player]
	if game == nil then warn('game not exist for player:', player); return end

	return game
end

function Class:Start(endRound, multi, startRound)
	if self.Started == true then warn('already started'); return end
	if self.Task:Start(workspace:GetServerTimeNow()) then
		-- print('start')
		self.SpawnRandom = Random.new(SPAWN_SEED)
		self.CritRandom = Random.new(CRIT_SEED)
		self.Started = true
		self.Valid = true
		self.Round = startRound
		self.SpawnSeed = SPAWN_SEED
		self.DamageSeed = DAMAGE_SEED
		self.CritSeed = CRIT_SEED
		self.EndRound = endRound
		self.Rush = multi
		if self.Rush then self.Round = 1 end
		self:ResetHealth()

		self:SetState('BeforeSpawning')
		self.GameStartedEvent:Fire(self.Player)
		self.Task:Wait(48)
		rs.Remote.Game.GameStart:FireClient(self.Player, self.Round, self.SpawnSeed, self.DamageSeed, self.CritSeed, self.Task.StartTime, self.EndRound, self.Rush)
		rs.Remote.Game.PlayerGameStart:FireAllClients(self.Player, self.PathId)
		
		self.StateTask = task.spawn(function()
			while true do
				-- warn('curstate:', self.State.name, '             timer:', self.Timer)

				if self.State and self.State.update then self.State.update() end
				self.Task:Wait(48)
				self.Timer -= 1
				-- print(self.Timer)
				-- print(self.State.name)

				-- 仅在valid为true时可以切换状态
				if self.Valid == true then 
					if self.State.name == 'InRound' and shared.Enemy.CheckEnemiesClearByPathId(self.PathId) == true and self.Round == self.EndRound then
						---		当前为回合为最后回合且怪物数量为0
						self:GameWin()
						return

					elseif self.State.name == 'InRound' and shared.Enemy.CheckEnemiesClearByPathId(self.PathId) == true then
						---		当前为回合内状态且怪物数量为0
						self:SetState(self.State.next)
						-- print('next round')

					elseif self.Timer <= 0 and not (self.Rush and self.State.name == 'InRound') then 
						--- 	倒计时结束，准备切换到下一回合（Rush模式下必须清完怪才切）

						if self.State.next == 'BeforeSpawning' and self.Round == self.EndRound then
							---下回合准备生成且当前回合为最终回合时， 不允许切换
						-- elseif self.State.name == 'InRound'  then
						-- 	---Inround状态倒计时结束, 不允许切换

						else
							self:SetState(self.State.next) 
						end

					end

				end
				
			end
		end)
		
	end
end

--------  设置状态，执行进入、退出状态的函数
function Class:SetState(newState)
	local state = EnumState[newState]
	if not state then warn('state not found for new state:', newState);  return end
	
	if self.State and self.State.exit then self.State.exit(self) end
	
	self.State = state
	rs.Remote.Game.GameStateChanged:FireClient(self.Player, self.State.name)
	self.Timer = self.State.duration
	
	if state.enter then state.enter(self) end
end

function Class:GameOver()
	if self.Task:Stop() then
		self.GameOverEvent:Fire(self.Player, self.PathId, self.Round, self.Rush)
		task.cancel(self.StateTask)
		self.State = nil
		self.Started = false
		rs.Remote.Game.GameOver:FireClient(self.Player)
		rs.Remote.Game.PlayerGameOver:FireAllClients(self.Player, self.PathId)
		CheckAuto(self)
	end
end
function Class:GameWin()
	if self.Task:Stop() then
		self.GameWinEvent:Fire(self.Player, self.PathId, self.Round, self.Rush)
		-- print(self.StateTask)
		-- task.cancel(self.StateTask)
		self.State = nil
		self.Started = false
		rs.Remote.Game.GameWin:FireClient(self.Player)
		rs.Remote.Game.PlayerGameOver:FireAllClients(self.Player, self.PathId)
		CheckAuto(self)
	end
end

function Class:Destroy()
	if self.Destroyed == true then return end
	self.Destroyed = true

	self.Task:Destroy()

	if self.StateTask then
		task.cancel(self.StateTask)
		self.StateTask = nil
	end

	collections[self.Player] = nil
	Class.loaded[self.Player] = nil
end

function Class:Farm(reward)
	Class.GameFarmEvent:Fire(self.Player, reward * (self.Rush or 1))
end

----------------------------		health相关
function Class:ResetHealth()
	self.Health = 100
	
	rs.Remote.Game.HealthReset:FireClient(self.Player, self.Health)
end
function Class:ReduceHealth(amount)
	if self.Health  == 0 then return end

	self.Health = math.max(self.Health - amount, 0)
	-- warn('health: ' .. self.Health)
	
	if self.Health == 0 then
		rs.Remote.Game.HealthModify:FireClient(self.Player, self.Health)
		self:GameOver()
	else
		rs.Remote.Game.HealthModify:FireClient(self.Player, self.Health)
	end
	
end

function CheckAuto(self)
	if self.Auto == true then
		task.wait(1)
		if self.Rush then return end
		local playerData = shared.DataStore.GetData(self.Player)
		if not playerData then return end
		self:Start(LevelData.MAXLEVEL, nil, playerData.Profile.StartLevel)
	end
end

return Class