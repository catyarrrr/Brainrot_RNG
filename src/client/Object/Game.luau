local rs = game:GetService('ReplicatedStorage')
local LevelData = require(rs.Datas.LevelData :: ModuleScript)
-- local EnemyData = require(rs.Datas.EnemyData :: ModuleScript)

local SPAWN_DELAY = 12
local self = {}
self.State, self.LevelData = nil
-- self.StateEnum = {
-- 	Waiting = 'Waiting',
-- 	Spawning = 'Spawning',
-- }
local EnumState = {

	-- Waiting = {
	-- 	name = 'Waiting',

	-- 	enter = function(self)
	-- 		self.EnterWaitingEvent:Fire()
	-- 	end,

	-- 	exit = function(self)

	-- 	end,
	-- },

	BeforeSpawning = {
		name = 'BeforeSpawning',

		enter = function(self)
		end,

		exit = function(self)

		end,

	},

	Spawning = {
		name = 'Spawning',

		enter = function(self)
			shared.Thread:Spawn(function()
				if self.Rush then
					local levelData = LevelData.GetRushData(self.Round)
					self.RoundStartedEvent:Fire(self.Round, 1)
					shared.Enemy.new(self.Round, 'Rush', levelData.Mob, shared.PlayerDataHandler.GetCurPath(), levelData.Health, levelData.Cash)
				else
					local levelData = LevelData.GetData(self.Round)
					self.RoundStartedEvent:Fire(self.Round, levelData.Amount)

					for i=1, levelData.Amount do
						local id = levelData.Mobs[self.SpawnRandom:NextInteger(1, #levelData.Mobs)]
						shared.Enemy.new(self.Round, 'Mob', id, shared.PlayerDataHandler.GetCurPath())
						shared.Task:Wait(SPAWN_DELAY)
					end
					if levelData.Elite then
						shared.Enemy.new(self.Round, 'Elite', levelData.Elite, shared.PlayerDataHandler.GetCurPath())
					elseif levelData.Boss then
						shared.Enemy.new(self.Round, 'Boss', levelData.Boss, shared.PlayerDataHandler.GetCurPath())
					end
				end
			end)
		end,

		exit = function(self)
			
		end,

	},

	InRound = {
		name = 'InRound',

		enter = function(self)
			if self.Round ~= self.EndRound then
				self.RoundEndedEvent:Fire()
			end
		end,

		exit = function(self)
			self.Round += 1
		end,
	}
}

function self.init()
	-- self.TowerCounter = 0
	self.Started = false
	
	self.EnterWaitingEvent = shared.Event.new()
	self.GameWaitedEvent = shared.Event.new()
	self.GameStartedEvent = shared.Event.new()
	self.GameOverEvent = shared.Event.new()
	self.GameEndedEvent = shared.Event.new()
	self.RoundStartedEvent = shared.Event.new()
	self.RoundEndedEvent = shared.Event.new()
	self.GameWinEvent = shared.Event.new()
end

function self.start()
	rs.Remote.Game.GameStart.OnClientEvent:Connect(Start)
	rs.Remote.Game.GameStop.OnClientEvent:Connect(Stop)
	rs.Remote.Game.GameOver.OnClientEvent:Connect(GameOver)
	rs.Remote.Game.GameWin.OnClientEvent:Connect(GameWin)
	rs.Remote.Game.GameStateChanged.OnClientEvent:Connect(function(newState)
		self.SetState(newState)
	end)
end

--------  设置状态，执行进入、退出状态的函数
function self.SetState(newState)
	local state = EnumState[newState]
	if not state then warn('state not found');  return end
	
	if self.State and self.State.exit then self.State.exit(self) end
	
	self.State = state
	self.Timer = self.State.duration
	
	if state.enter then state.enter(self) end
end

function Start(round, spawnSeed, damageSeed, critSeed, startTime, endRound, rush)
	if shared.Task:Start(startTime + .01) then
		self.Started = true
		self.SpawnRandom = Random.new(spawnSeed)
		self.DamageRandom = Random.new(damageSeed)
		self.CritRandom = Random.new(critSeed)
		self.Round = round
		self.EndRound = endRound
		self.Rush = rush
		-- self.LevelData = LevelData.GetData(mapId, difficulty)

		shared.SoundHandler:Play('Operate_Success')
		self.GameStartedEvent:Fire()
	end
end

function Stop()
	shared.Task:Stop()
end

function GameOver()
	shared.SoundHandler:Play('Operate_Fail')
	shared.Task:Stop()
	self.GameOverEvent:Fire()
	self.GameEndedEvent:Fire(self.Round)
end

function GameWin()
	shared.Task:Stop()
	task.wait(.5)
	self.GameWinEvent:Fire()
	self.GameEndedEvent:Fire(self.Round)
end

return self
