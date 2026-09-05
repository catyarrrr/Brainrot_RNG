local self = {ExpIncEvent = nil, LEVEL_MAX = 4}

function self.init()
    
end

function self.CheckPlace(gridData, shape, gridX, gridY)
    for _, offset in ipairs(shape) do

        local x = gridX + offset[1]
        local y = gridY + offset[2]

        -- 越界
        if x < 1 or x > gridData.Width then
            return false
        end

        if y < 1 or y > gridData.Height then
            return false
        end

        -- 已占用
        if gridData.Cells[x][y] ~= 0 then
            return false
        end
    end

    return true
end

function self.Place(gridData, shape, gridX, gridY, uid)
    for _, offset in ipairs(shape) do

        local x = gridX + offset[1]
        local y = gridY + offset[2]

        gridData.Cells[x][y] = uid
    end
end

function self.Remove(gridData, shape, gridX, gridY)
    for _, offset in ipairs(shape) do

        local x = gridX + offset[1]
        local y = gridY + offset[2]

        gridData.Cells[x][y] = 0
    end
end

function self.GridUpgrade(playerGrid, nextLevel)
    local dict = {[1] = {4, 4}, [2] = {8, 4}, [3] = {8, 6}, [4] = {8, 8}}
    local scale = dict[nextLevel]
    if scale == nil then warn('upgrade grid error for nextlevel:', nextLevel); return end

    playerGrid.Width = scale[1]
    playerGrid.Height = scale[2]

    self.GridInit(playerGrid)
end
function self.GridInit(playerGrid)
    playerGrid.Cells = {}
    for x = 1, playerGrid.Width do
        playerGrid.Cells[x] = {}
        for y = 1, playerGrid.Height do
            playerGrid.Cells[x][y] = 0
        end
    end
end
function self.GetUIDByGrid(playerGrid, gridX, gridY)
    local uid = playerGrid.Cells[gridX][gridY] 
    if uid == 0 then return end

    return uid
end

function self.GetLevel(playerGrid)
    local wid, hei = playerGrid.Width, playerGrid.Height

	local dict = {
		[4] = {[4] = 1},
		[8] = {[4] = 2, [6] = 3, [8] = 4},
	}

	local level = dict[wid]
	level = level and level[hei]
	if level == nil then warn('level not fetch for wid/hei :', wid, hei); return end

	return level
end

return self
