local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local TotemData = require(ReplicatedStorage.Datas.TotemData :: ModuleScript)
local PROJECTILE_TICKS = 7

local DamageCalculation = function(towerData, charData)
	local damage = towerData.Damage or 0
	-- print(damage)
	for _, equippedTotem in ipairs(shared.PlayerDataHandler.GetEquippedTotems()) do
		if equippedTotem and equippedTotem.TotemUID then
			local staticData = TotemData.GetData(equippedTotem.TotemUID)
			local modifier = shared.CalculateData.GetModifierByPoints(equippedTotem.Point)
			modifier *= towerData.ActionDelay / shared.Config.TICKPERSECOND_DEFAULT
			if modifier and staticData then
				if staticData.MainType == towerData.TotemType then
					damage += modifier * 3
				end
				if staticData.SubType == towerData.TotemType then
					damage += modifier
				end
			end
		end
	end
	-- print(damage)

	if towerData.CritChance and towerData.CritDamage then
		if shared.Game.CritRandom:NextNumber() <= towerData.CritChance then
			damage = damage * towerData.CritDamage
		end
	end

	return math.floor(damage)
end

local ChooseCharacter = function(towerData)
	local characterlink = towerData.Characters.Next
	while characterlink ~= towerData.Characters do
		local damage = DamageCalculation(towerData, characterlink.Value)
		local enemy = characterlink.Value
		local remaining = enemy.Health - enemy.ReservedDamage
		if remaining > 0 then
			enemy.ReservedDamage += damage
			return enemy, damage
		end
		characterlink = characterlink.Next
	end

	return nil
end

local GetFirstCharacter = function(towerData)
	local characterlink = towerData.Characters.Next
	while characterlink ~= towerData.Characters do
		local enemy = characterlink.Value
		if enemy.Health - enemy.ReservedDamage > 0 then
			return enemy
		end
		characterlink = characterlink.Next
	end

	return nil
end

local ChooseCharacters = function(towerData, count)
	local characters = {}
	local damage = DamageCalculation(towerData)
	local characterlink = towerData.Characters.Next
	while characterlink ~= towerData.Characters and #characters < count do
		local enemy = characterlink.Value
		if enemy.Health - enemy.ReservedDamage > 0 then
			enemy.ReservedDamage += damage
			table.insert(characters, enemy)
		end
		characterlink = characterlink.Next
	end

	return characters, damage
end

local PlayVisual = function(tower, enemy)
	shared.SoundHandler.TowerHitEvent:Fire(tower.TowerUID, enemy.Model:FindFirstChild('Torso').Position)
	
	local att
	for _, v in tower.Rig:GetDescendants() do
		if v.Name == 'AttackPos' then
			att = v
			break
		end
	end
	if att == nil then warn('attack pos not found for tower:', tower.TowerUID); return end

	local towerType = TowerData.GetTowerTypeByTowerUID(tower.TowerUID)
	if tower.Visual == 1 then
		local projectileName = 'BR' .. tostring(towerType) .. 'Projectile'
		shared.Projectile.FireEvent:Fire(projectileName, att.WorldCFrame.Position, enemy.Model.Torso, PROJECTILE_TICKS)
	
	elseif tower.Visual == 2 then
		local projectileName = 'BR' .. tostring(towerType) .. 'Projectile'
		local part = shared.ObjectPool.Get(projectileName)
		if part == nil then return end
		part:PivotTo(CFrame.lookAt(att.WorldCFrame.Position, enemy.Model.Torso.Position))
		shared.VFXHandler.ParticleModule.EmitParticle(part, 1)
		task.delay(1, function() 
			shared.ObjectPool.Return(projectileName, part) 
		end)
	elseif tower.Visual == 3 then
		local projectileName = 'BR' .. tostring(towerType) .. 'Beam'
		shared.Projectile.BeamFireEvent:Fire(projectileName, att.WorldCFrame.Position, enemy.Model.Torso, PROJECTILE_TICKS)
	elseif tower.Visual == 4 then
		local vfxName = 'BR' .. tostring(towerType) .. 'VFX'
		local model = shared.ObjectPool.Get(vfxName)
		if model == nil then return end

		--- 生成在目标面前并正对目标
		local targetPos = enemy.Model.Torso.Position
		local look = enemy.Model:GetPivot().LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
		model:PivotTo(CFrame.lookAt(targetPos + flatLook * 6, targetPos))

		--- 播放模型自带动画
		local track = shared.AnimationHandler.GetAnimationTrack(model)
		if track then track:Play() end
		task.delay(1, function()
			if track then track:Stop() end
			shared.ObjectPool.Return(vfxName, model)
		end)
	end
		
end

TowerFunction = {

	['DamageProjectile'] = {
		Action = function(tower)
			local target = GetFirstCharacter(tower)
			if target == nil then return end

			--- 控制角色朝向
			local pivot = tower.Model:GetPivot()
			local pivotPos = pivot.Position
			local targetPos = target.Model.Torso.Position
			local direction = Vector3.new(targetPos.X - pivotPos.X, 0, targetPos.Z - pivotPos.Z)
			local targetCFrame = CFrame.new(pivotPos, pivotPos + direction)
			tower.Model:PivotTo(targetCFrame * tower.CFrameOffset)
			---

			-- 控制动画播放
			tower:PlayAttack()
			shared.Task:Wait(24)
			
			if target.Model:FindFirstChild('Torso') then PlayVisual(tower, target) end
			shared.Task:Wait(PROJECTILE_TICKS)

			local character, damage = ChooseCharacter(tower)
			if character == nil then return end

			if character.Model:FindFirstChild('Torso') then 
				shared.VFXHandler.PlayTowerParticleEvent:Fire(tower.TowerUID, character.Model.Torso.Position, 1, CFrame.lookAt(pivotPos, character.Model.Torso.Position))
			end

			character:ModifyHealth(damage)
		end,
	},

	--- 多重伤害投射物，攻击多个目标但不分散伤害
	['MultiDamageProjectile'] = {
		Action = function(tower)
			local target = GetFirstCharacter(tower)
			if target == nil then return end

			--- 控制角色朝向
			local pivot = tower.Model:GetPivot()
			local pivotPos = pivot.Position
			local targetPos = target.Model.Torso.Position
			local direction = Vector3.new(targetPos.X - pivotPos.X, 0, targetPos.Z - pivotPos.Z)
			local targetCFrame = CFrame.new(pivotPos, pivotPos + direction)
			tower.Model:PivotTo(targetCFrame * tower.CFrameOffset)
			---

			-- 控制动画播放
			tower:PlayAttack()
			
			shared.Task:Wait(24)
			if target.Model:FindFirstChild('Torso') then PlayVisual(tower, target) end

			shared.Task:Wait(PROJECTILE_TICKS)

			local characters, damage = ChooseCharacters(tower, 3)

			for k, v in characters do
				if v.Model:FindFirstChild('Torso') then
					shared.VFXHandler.PlayTowerParticleEvent:Fire(tower.TowerUID, v.Model.Torso.Position, 1, CFrame.lookAt(pivotPos, v.Model.Torso.Position))
				end
			end

			for i, v in characters do
				v:ModifyHealth(damage)
			end
		end,
	},

}

return TowerFunction