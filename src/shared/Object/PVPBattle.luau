--[[
	PVPBattle (Shared)
	客户端与服务端共用的战斗运算模块，双方使用同一 seed 复现完全一致的结果。

	车轮战规则：
		双方各自持有一个「按上阵顺序排列」的单位列表，每次各派出一名单位相撞，
		同时互相扣血；某一方当前单位阵亡后，由列表中的下一名替补，直到一方全部阵亡。

	数据格式：
		allyData / enemyData = { { TowerUID, DPS }, ... }（按出战顺序排列）
	返回：
		{
			Winner = 'L' | 'R',
			Seed = number,
			AllyCount = number,
			EnemyCount = number,
			Turns = {
				{
					AllyIndex = number,                     -- 我方本回合出战单位下标
					EnemyIndex = number,                    -- 敌方本回合出战单位下标
					Ally = {                                -- 我方造成的伤害与自身受击结果
						Miss = boolean,
						Damage = number,                    -- 我方对敌方造成的伤害
						HP = number,                        -- 我方受击后的剩余血量
						Dead = boolean,
					},
					Enemy = { ... },                        -- 敌方造成的伤害与自身受击结果
				}, ...
			},
		}
]]

local MAX_TURNS = 1024
local MISS_CHANCE = 0.2          -- 每次攻击 Miss 概率

local self : any = {}

-- 伤害公式：纯 DPS 比拼，攻击方 DPS^2 / (攻击方DPS + 受击方DPS)
local function ComputeDamage(attacker, defender)
	local total = attacker.DPS + defender.DPS
	if total <= 0 then return 1 end

	return math.max(1, math.floor((attacker.DPS * attacker.DPS) / total))
end

-- 按出战顺序把数组数据构建为战斗单位（HP 等于 DPS）
local function BuildCombatants(data)
	local list = {}
	if type(data) ~= 'table' then return list end

	for _, info in ipairs(data) do
		table.insert(list, {
			TowerUID = info.TowerUID,
			DPS = info.DPS or 0,
			HP = info.DPS or 0,
		})
	end
	return list
end

-- 执行一次完整车轮战模拟，返回胜负与逐回合日志
function self.Simulate(allyData, enemyData, seed)
	seed = seed or 0
	local rng = Random.new(seed)

	local ally = BuildCombatants(allyData)
	local enemy = BuildCombatants(enemyData)

	local turns = {}
	local allyIndex, enemyIndex = 1, 1
	local guard = 0

	while allyIndex <= #ally and enemyIndex <= #enemy and guard < MAX_TURNS do
		guard += 1

		local a = ally[allyIndex]
		local e = enemy[enemyIndex]

		-- 相撞：双方各判定一次 Miss，未 Miss 则互相扣血
		local allyMiss = rng:NextNumber() < MISS_CHANCE
		local enemyMiss = rng:NextNumber() < MISS_CHANCE

		local allyDamage, enemyDamage = 0, 0

		if not allyMiss then
			allyDamage = ComputeDamage(a, e)
			e.HP = math.max(0, e.HP - allyDamage)
		end

		if not enemyMiss then
			enemyDamage = ComputeDamage(e, a)
			a.HP = math.max(0, a.HP - enemyDamage)
		end

		local allyDead = a.HP <= 0
		local enemyDead = e.HP <= 0

		table.insert(turns, {
			AllyIndex = allyIndex,
			EnemyIndex = enemyIndex,
			Ally = {
				Miss = allyMiss,
				Damage = allyDamage,
				HP = a.HP,
				Dead = allyDead,
			},
			Enemy = {
				Miss = enemyMiss,
				Damage = enemyDamage,
				HP = e.HP,
				Dead = enemyDead,
			},
		})

		-- 阵亡者由下一名替补；我方全灭即失败
		if allyDead then allyIndex += 1 end
		if enemyDead then enemyIndex += 1 end
	end

	return {
		Winner = allyIndex <= #ally and 'L' or 'R',
		Seed = seed,
		AllyCount = #ally,
		EnemyCount = #enemy,
		Turns = turns,
	}
end

return self
