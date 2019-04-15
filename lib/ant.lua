--- Ant class.
-- An Ant moves according to Langton's Ant algorithm.
--
-- @classmod Ant
-- @release v0.0.1
-- @author Mimetaur

local Ant = {}
Ant.__index = Ant
--- @field MAX_NEIGHBORS max possible neighbors to ant in world
Ant.MAX_NEIGHBORS = 8

-- private methods
local function wrap_edges(self, w, h)
    if self._x > w then
        self._x = 1
    end
    if self._x < 1 then
        self._x = w
    end

    if self._y > h then
        self._y = 1
    end
    if self._y < 1 then
        self._y = h
    end
end

local function move_ant(self, w, h)
    local heading = self._heading
    if heading == 1 then
        self._y = self._y - 1
    end
    if heading == 2 then
        self._x = self._x + 1
    end
    if heading == 3 then
        self._y = self._y + 1
    end
    if heading == 4 then
        self._x = self._x - 1
    end
    wrap_edges(self, w, h)
end

local function change_ant_heading(self, amount)
    local new_heading = self._heading + amount
    if new_heading > 4 then
        new_heading = 1
    end
    if new_heading < 1 then
        new_heading = 4
    end
    self._heading = new_heading
end

local function turn_ant(self, cell)
    local x = self._x
    local y = self._y

    local cw = 1
    local ccw = -1
    if cell then
        change_ant_heading(self, cw)
    else
        change_ant_heading(self, ccw)
    end
end

local function get_trail(self, cell)
    local is_white = false
    if cell then
        is_white = true
    end
    return is_white
end

local function get_neighbors(self, world)
    local cells = {}
    local qty = 0
    for y = (self._y - 1), (self._y + 1) do
        for x = (self._x - 1), (self._x + 1) do
            local cell = world:get_cell(x, y)
            if x == self._x and y == self._y then
                -- do nothing
                -- don't include yourself
            else
                if cell then
                    qty = qty + 1
                    table.insert(cells, cell)
                else
                    table.insert(cells, false)
                end
            end
        end
    end
    return cells, qty
end

--- Create a new Ant object.
-- @int x X position at start
-- @int y Y position at start
-- @treturn Ant An instance of Ant.
function Ant.new(x, y)
    local ant = {}
    ant._start_x = x or 0
    ant._start_y = y or 0
    ant._x = x or 0
    ant._y = y or 0
    ant._heading = 1 -- clockwise, 1 = N, 2 = E, 3 = S, 4 = W
    ant._brightness = 4
    ant._did_hit_trail = false
    setmetatable(ant, Ant)
    return ant
end

--- Get ant X position
-- @treturn int x position
function Ant:x()
    return self._x
end

--- Get ant Y position
-- @treturn int y position
function Ant:y()
    return self._y
end

--- Get ant position
-- @treturn int x position
-- @treturn int y position
function Ant:position()
    pos = {}
    pos.x = self._x
    pos.y = self._y
    return pos
end

--- Get ant heading.
-- @treturn int heading.
--
-- 1 = N, 2 = E, 3 = S, 4 = W
function Ant:heading()
    return self._heading
end

--- Get ant brightness
-- @treturn int brightness
function Ant:brightness()
    return self._brightness
end

--- Did the ant hit the trail?
-- @treturn bool did_hit_trail
function Ant:did_hit_trail()
    return self._did_hit_trail
end

--- Get number of neighbors to ant
-- @treturn int num_neighbors
function Ant:neighbors()
    return self._neighbors
end

--- Get an array of Cells.
-- One for each neighbor of the ant.
-- @treturn tab neighbors_as_cells
function Ant:neighbors_as_cells()
    return self._neighbors_as_cells
end

--- Update ant.
-- @world world Ant uses information about world to move.
function Ant:update(world)
    local cell = world:get_cell(self._x, self._y)
    turn_ant(self, cell)

    self._did_hit_trail = get_trail(self, cell)
    local neighbor_cells, num_neighbors = get_neighbors(self, world)
    self._neighbors = num_neighbors
    self._neighbors_as_cells = neighbor_cells

    world:toggle_cell(self._x, self._y)

    local w, h = world:size()
    move_ant(self, w, h)
end

--- Reset ant back to starting state.
function Ant:reset()
    self._x = self._start_x
    self._y = self._start_y

    self._heading = 1 -- clockwise, 1 = N, 2 = E, 3 = S, 4 = W
    self._did_hit_trail = false
end

return Ant
