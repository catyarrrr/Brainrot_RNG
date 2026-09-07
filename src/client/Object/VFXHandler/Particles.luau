local ReplicatedStorage = game:GetService('ReplicatedStorage')

local POOL_SIZE, PARTICLE_RECYCLE_TIME = 20, 1.5
local module = {}

function module.Init()
    -- PlaneParticleInit(1)
	module.ParticleInit('EnemyDeadParticle')
	module.ParticleInit('UpgradeEffect', 5)
end

function module.Play(name, pos, time, orientation)
    local tarParticles = shared.ObjectPool.Get(name)
	
	if tarParticles == nil then return end
    -- print('play particle:' .. poolName)

	if orientation then
		tarParticles:PivotTo(CFrame.new(pos) * orientation.Rotation)
	else
		tarParticles.Position = pos
	end
	
	for k, v in tarParticles:GetDescendants() do
		if v:IsA('ParticleEmitter') then
			v:Emit(time)
		end
	end

    task.delay(PARTICLE_RECYCLE_TIME, function()
        shared.ObjectPool.Return(name, tarParticles)
    end)
	
end


function module.EnableParticle(particle)
    for k, v in particle:GetDescendants() do
        if v:IsA('ParticleEmitter') then
            v.Enabled = true
        end
    end
end
function module.DisableParticle(particle)
    for k, v in particle:GetDescendants() do
        if v:IsA('ParticleEmitter') then
            v.Enabled = false
        end
    end
end
function module.EmitParticle(particle, time)
    for k, v in particle:GetDescendants() do
        if v:IsA('ParticleEmitter') then
            v:Emit(time)
        end
    end
end
function module.ToggleVisual(instance, toggle)
    for _, v in instance:GetDescendants() do
        if v:IsA('ParticleEmitter') or v:IsA('Beam') then
            v.Enabled = toggle
        end
    end
end

function module.ParticleInit(name : string, size : any, tag)
	local template = ReplicatedStorage.Assets.Particles:FindFirstChild(name)
	if template == nil then return end
	local particle = template:Clone()
	
	for k, v in particle:GetDescendants() do
		if v:IsA('ParticleEmitter') then
			v.Enabled = false
		end
	end
	
	shared.ObjectPool.Create(name, particle, POOL_SIZE, tag)
	particle:Destroy()
end

return module
