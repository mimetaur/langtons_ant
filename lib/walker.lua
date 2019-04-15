--- Walker class.
-- A walker moves randomly around the World.
--
-- @classmod Walker
-- @release v0.0.1
-- @author Mimetaur

local Walker = {}
Walker.__index = Walker
Walker.COUNT = 0

-------------------------------------------------------------------------------
-- Class Level Constants
-------------------------------------------------------------------------------

Walker.DEFAULT_BRIGHTNESS = 12

-------------------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------------------
local RELOAD_LIBS = true

local libs = {}
libs.cell_path = "agents/lib/cell"
if RELOAD_LIBS == true then
    local reload_libraries = require "agents/lib/reload_libraries"
    reload_libraries.with_table(libs)
end

local Cell = require(libs.cell_path)

-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------
local function wrap_edges(self, w, h)
    if self.x_ > w then
        self.x_ = 1
    end
    if self.x_ < 1 then
        self.x_ = w
    end

    if self.y_ > h then
        self.y_ = 1
    end
    if self.y_ < 1 then
        self.y_ = h
    end
end

local function change_heading(self)
    local h = math.random(4) -- clockwise, 1 = N, 2 = E, 3 = S, 4 = W
    self.heading_ = h
end

local function move(self, width, height)
    -- clockwise, 1 = N, 2 = E, 3 = S, 4 = W
    local h = self.heading_
    if h == 1 then
        self.y_ = self.y_ - 1
    end
    if h == 2 then
        self.x_ = self.x_ + 1
    end
    if h == 3 then
        self.y_ = self.y_ + 1
    end
    if h == 4 then
        self.x_ = self.x_ - 1
    end

    wrap_edges(self, width, height)
end

local function calculate_highlight(self)
    local is_highlight = self.is_highlighting_
    if is_highlight then
        self.is_highlighting_ = false
    end
    return is_highlight
end

--- Create a new Walker object.
-- @int x X position at start
-- @int y Y position at start
-- @int i An identifying number assigned to walker.
-- @int cell_size size of cell in world
-- @treturn Walker An instance of Walker.
function Walker.new(x, y, i)
    Walker.COUNT = Walker.COUNT + 1

    local walker = {}
    walker.initial_x_ = x or 0
    walker.initial_y_ = y or 0
    walker.x_ = x or 0
    walker.y_ = y or 0
    walker.heading_ = 1 -- clockwise, 1 = N, 2 = E, 3 = S, 4 = W
    walker.index_ = Walker.COUNT
    walker.i_ = i
    walker.is_highlighting_ = false
    walker.cell_size_ = cell_size
    setmetatable(walker, Walker)

    return walker
end

--- Get walker X position
-- @treturn int x position
function Walker:x()
    return self.x_
end

--- Get walker Y position
-- @treturn int y position
function Walker:y()
    return self.y_
end

--- Get walker position
-- @treturn int x position
-- @treturn int y position
function Walker:position()
    return self.x_, self.y_
end

--- Get walker heading.
-- @treturn int heading.
--
-- 1 = N, 2 = E, 3 = S, 4 = W
function Walker:heading()
    return self.heading_
end

--- Update Walker.
--
-- 1. Set a new random heading.
--
-- 2. Move in that direction.
--
-- 3. Add a cell at new position.
--
-- In most scripts this will be called
-- from a metro or BeatClock callback. i.e.
--      clock.on_step = function()
--        walker:update(world)
--        redraw()
--      end
function Walker:update(world)
    local w, h = world:size()
    change_heading(self)
    move(self, w, h)

    local new_pos = Cell.new(world, Walker.DEFAULT_BRIGHTNESS, 1, calculate_highlight(self))
    world:add_cell(self.x_, self.y_, new_pos)
end

--- Get walker index.
-- @treturn int index.
--
-- This is a permanent ID regardless of
-- how many new Walkers have been created/destroyed.
function Walker:index()
    return self.index_
end

--- Get walker num.
-- @treturn int num.
--
-- This number is derived from the current
-- number of existing walkers at the time.
function Walker:num()
    return self.i_
end

--- Highlight walker on screen.
function Walker:highlight()
    self.is_highlighting_ = true
end

return Walker
