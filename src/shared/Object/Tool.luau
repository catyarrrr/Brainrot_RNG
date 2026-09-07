local self = {}
local rng = Random.new()

function self.RichColor(text, color3)
    return string.format(
        '<font color="#%s">%s</font>',
        color3:ToHex(),
        text
    )
end

function self.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))

    local hour = math.floor(seconds / 3600)
    local minute = math.floor(seconds % 3600 / 60)
    local second = seconds % 60

    if hour > 0 then
        return string.format("%02d:%02d:%02d", hour, minute, second)
    else
        return string.format("%02d:%02d", minute, second)
    end
end

function self.FormatNumber(num)
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

function self.FormatTowerType(towerType)
	local str = string.format("%03d", towerType)
	return str
end

function self.GetWeekId()
    local id = math.floor(os.time() / (7 * 24 * 60 * 60))
	
	return tostring(id)
end

function self.GachaByDict(list)	--返回键
	local totalWeight = 0

	for k, v in pairs(list) do
		if typeof(v) == "number" then
			totalWeight += v
		elseif typeof(v) == 'table' then
			totalWeight += v.Weight or 0
		end
	end

	local ranWeight = rng:NextNumber() * totalWeight
	local curWeight = 0

	for k, v in pairs(list) do
		if typeof(v) == "number" then
			curWeight += v
		elseif typeof(v) == 'table' then
			curWeight += v.Weight or 0
		end
		if curWeight >= ranWeight then
			return k
		end
	end
	return nil
end

return self
