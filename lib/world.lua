--- World class.
-- An instance represents a 2D grid on the Norns.
-- A World is a 2D sparse matrix with some helper methods.
-- When a position in the World isn't empty, it is filled
-- with an instance of the Cell class.
-- @see Cell
--
-- @classmod World
-- @release v0.0.1
-- @author Mimetaur

local World = {}
World.__index = World

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
local function update_cell_default(self, x, y, cell)
    -- do nothing
end

local function create_cell_default(self, x, y)
    -- create a default cell
    local new_cell = Cell.new(self)
    self:set_cell(x, y, new_cell)
end

local function draw_default(self)
    -- callback for injecting OSC messages
    -- do nothing
end

local function merge_defaults(options)
    local defaults = {}
    defaults.cell_size = 1
    defaults.h_offset = 0
    defaults.v_offset = 0
    defaults.default_brightness = 8
    defaults.screen_width = 128
    defaults.screen_height = 64
    defaults.update_cell_func = update_cell_default
    defaults.create_cell_func = create_cell_default
    defaults.draw_func = draw_default

    for key, value in pairs(defaults) do
        options[key] = options[key] or value
    end

    return options
end

local function in_bounds(self, x, y)
    local w, h = self:size()
    local in_bounds = false
    if (x > 0 and x <= w and y > 0 and y <= h) then
        in_bounds = true
    end
    return in_bounds
end

local function reset_grid(self)
    for y = 1, self.height_ do
        self.grid_[y] = {}
        for x = 1, self.width_ do
            self.grid_[y][x] = nil
        end
    end
end

local function clear_world_frame(self)
    screen.level(0)
    screen.rect(self.h_offset_, self.v_offset_, self.width_ * self.cell_size_, self.height_ * self.cell_size_)
    screen.fill()
end

local function draw_cell(self, x, y, cell)
    local b = cell.brightness or self.default_brightness_

    screen.level(b)
    local coord_x = (x + self.h_offset_) * cell.size
    local coord_y = self.v_offset_ + (cell.size * y)
    screen.rect(coord_x, coord_y, cell.size, cell.size)
    screen.fill()

    if cell.highlight then
        local radius = cell.size * 2.5
        local bright = math.ceil(b / 2)

        screen.level(bright)
        screen.circle(coord_x, coord_y, math.ceil(radius))
        screen.stroke()
    end
end

--- Create a new World object.
-- @tparam table options Table of options. *(Optional)*
-- @func options.update_cell_func callback for when a cell updates:
-- `update_cell(self, x, y, cell)`
-- @func options.create_cell_func callback for when a cell is created:
-- `create_cell(self, x, y)`
-- @int options.h_offset Horizontal offset
-- @int options.v_offset Vertical offset
-- @int options.default_brightness Default screen brightness (default = 8)
-- @int options.screen_width Screen width. (default = 128)
-- @int options.screen_height Screen height. (default = 64)
-- @int options.cell_size Cell size (default = 1). (`width = screen_width / cell_size`)
-- @treturn World Instance of World.
function World.new(options)
    local world = {}
    world.grid_ = {}

    options = options or {}
    options = merge_defaults(options)

    world.cell_size_ = options.cell_size
    world.update_cell = options.update_cell_func
    world.create_cell = options.create_cell_func
    world.draw_callback = options.draw_func

    world.width_ = math.ceil(options.screen_width / world.cell_size_)
    world.height_ = math.ceil(options.screen_height / world.cell_size_)

    world.h_offset_ = options.h_offset
    world.v_offset_ = options.v_offset
    reset_grid(world)

    setmetatable(world, World)

    return world
end

--- Get the size of the World.
-- @treturn int width of world.
-- @treturn int height of world.
function World:size()
    return self.width_, self.height_
end

--- Get the World's offsets.
-- @treturn int x offset of world.
-- @treturn int y offset of world.
function World:offsets()
    return self.x_offset_, self.y_offset_
end

--- Update World.
-- Executes a callback on each cell in the World:
-- `update_cell(self, x, y, cell)`
--
-- In most scripts this will be called
-- from a metro or BeatClock callback. i.e.
--      clock.on_step = function()
--        world:update()
--        redraw()
--      end
function World:update()
    for y = 1, self.height_ do
        for x = 1, self.width_ do
            local cell = self:get_cell(x, y)
            if cell then
                if cell.highlight then
                    cell.highlight = false
                end
                self:update_cell(x, y, cell)
            end
        end
    end
end

--- Draw World.
-- Call inside Norns' redraw() method.
function World:draw()
    clear_world_frame(self)
    for y = 1, self.height_ do
        for x = 1, self.width_ do
            local cell = self:get_cell(x, y)
            if cell then
                draw_cell(self, x, y, cell)
            end
        end
    end
    self:draw_callback()
end

--- Reset World.
-- Nukes every cell in the World.
function World:reset()
    reset_grid(self)
end

--- Add cell.
-- Syntactic sugar around set_cell()
-- @int x X position (to create cell at)
-- @int y Y position (to create cell at)
-- @cell cell Cell object to add.
function World:add_cell(x, y, cell)
    self:set_cell(x, y, cell)
end

--- Get cell.
-- @int x X position
-- @int y Y position
-- @treturn Cell Cell object (or nil if nothing there)
function World:get_cell(x, y)
    local col = self.grid_[y] or {}
    local cell = col[x] or nil
    return cell
end

--- Set cell.
-- @int x X position
-- @int y Y position
-- @cell cell Cell object to set x,y location to
function World:set_cell(x, y, cell)
    if in_bounds(self, x, y) then
        self.grid_[y][x] = cell
    end
end

--- Delete cell.
-- Sets that position in the grid to nil.
-- @int x X position
-- @int y Y position
function World:delete_cell(x, y)
    self:set_cell(x, y, nil)
end

--- Cell size.
-- @treturn int the size of each cell in grid
function World:cell_size()
    return self.cell_size_
end

--- Toggle cell.
-- It will create a cell if one does not exist
-- (or turn an existing cell nil).
-- Calls `create_cell(self, x, y)` callback
-- @int x X position
-- @int y Y position
function World:toggle_cell(x, y)
    local cell = self:get_cell(x, y)
    if cell then
        cell = self:delete_cell(x, y)
    else
        cell = self:create_cell(x, y)
    end
end

--- World as 2D array.
-- Each array item is an integer representing that cell's brightness
-- @treturn table array of arrays of ints
function World:to_2d_array()
    local arr2d = {}
    for y = 1, self.height_ do
        arr2d[y] = {}
        for x = 1, self.width_ do
            local cell = self.grid_[y][x]
            if cell then
                arr2d[y][x] = cell.brightness
            else
                arr2d[y][x] = 0
            end
        end
    end
    return arr2d
end

--- World as 1D array.
-- Each array item is an integer representing that cell's brightness
-- @treturn table array of ints
function World:to_array()
    local arr = {}
    for y = 1, self.height_ do
        for x = 1, self.width_ do
            local location = ((y - 1) * self.width_) + x
            local cell = self.grid_[y][x]
            if cell then
                arr[location] = cell.brightness
            else
                arr[location] = 0
            end
            -- table.insert(arr, b)
        end
    end

    return arr
end

-- function World:to_array()
--     local arr = {}
--     for y = 0, self.height_ do
--         for x = 1, self.width_ do
--             local cell = self:get_cell(x, y)
--             if cell then
--                 arr[(y * x) + x] = cell.brightness
--             else
--                 arr[(y * x) + x] = 1
--             end
--         end
--     end
--     return arr
-- end

return World
