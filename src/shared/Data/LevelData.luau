local self = {}

function self.GetHealthByRoundType(round, type)
	local baseHealth = 0.88 * round ^ 1.98 + 1

	if round >= 100 then
		baseHealth *= round * 0.03 - 2
	end

	if type == 'Elite' then
		baseHealth *= 2.5
	elseif type == 'Boss' then
		baseHealth *= 6
	end

	return math.ceil(baseHealth)
end

return self