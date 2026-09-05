local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage.Datas.TowerData :: ModuleScript)
local AssetsData = require(ReplicatedStorage.Datas.AssetsData :: ModuleScript)

local self = {}
local FormatNumber = nil

function self.start()

end

function self.GenerateTowerGui(parent, towerData)
    local gui =  ReplicatedStorage.Assets.UI.TowerGui:Clone()
    for _, label in gui:GetChildren() do
        if label:IsA('TextLabel') then 
            label.Visible = false
        end
    end
    gui.Price.Visible = true
    gui.Price.Text = '$ ' .. FormatNumber(towerData.Cost)
    local qualityLabel = gui:FindFirstChild(towerData.Quality)
    if qualityLabel then 
        qualityLabel.Visible = true 
        qualityLabel.Text = towerData.Chance
    end
    local mutId = TowerData.GetMutIdByTowerUID(towerData.TowerUID)
    local mutLabel = gui:FindFirstChild(tostring(mutId))
    if mutLabel then mutLabel.Visible = true end
    -- gui.DisplayName.Visible = true
    -- gui.DisplayName.Text = towerData.DisplayName
    gui.DPS.Visible = true
    gui.DPS.RichText = true
    gui.DPS.Text = '<font color="rgb(255,255,0)">DPS:</font>'.. '<font color="#ff0000"> ' .. tostring(TowerData.GetTowerDPSByTowerUID(towerData.TowerUID)) .. '</font>'

    gui.Adornee = parent.Gui
    gui.Parent = parent

    return gui
end

function self.GenerateMutParticle(model, mutId)
    if mutId > 1 then
        local particle = ReplicatedStorage.Assets.Particles:FindFirstChild('Mut' .. tostring(mutId)):Clone()
        local center = model:GetBoundingBox().Position
        local att
		for _, v in model:GetDescendants() do
			if v.Name == 'AttachmentMid' then att = v; break end
		end
		if att == nil then 
			warn('attMid not found'); 
			center = model:GetBoundingBox().Position
		else
			center = att.WorldCFrame.Position
		end

        particle:PivotTo(CFrame.new(center))
        particle.Parent = model
    end
end

function FormatNumber(num)
	local suffixes = {
		"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"
	}

	local index = 1

	while num >= 1000 and index < #suffixes do
		num = num / 1000
		index += 1
	end

	if index == 1 then
		return tostring(math.floor(num))
	end

	local formatted = string.format("%.2f", num)

	-- 去掉末尾无用的0
    
	formatted = formatted:gsub("%.?0+$", "")

	return formatted .. suffixes[index]
end

function self.EnableParticle(container)
    for k, v in container:GetDescendants() do
        if v:IsA('ParticleEmitter') then
            v.Enabled = true
        end
    end
end
function self.DisableParticle(container)
    for k, v in container:GetDescendants() do
        if v:IsA('ParticleEmitter') then
            v.Enabled = false
        end
    end
end
function self.EmitParticle(particle, time)
    for k, v in particle:GetDescendants() do
        if v:IsA('ParticleEmitter') then
            v:Emit(time)
        end
    end
end


return self