--- Cell class.
-- An instance is one cell.
-- Because a World is a sparse matrix, empty cells are nil.
-- @see World
--
-- @classmod Cell
-- @release v0.0.1
-- @author Mimetaur

local Cell = {}
Cell.__index = Cell

-------------------------------------------------------------------------------
-- Class Level Constants
-------------------------------------------------------------------------------

Cell.DEFAULT_BRIGHTNESS = 8

--- Create a new Cell object.
-- @world world The world this cell will be a part of
-- @int brightness brightness of cell (defaults to `Cell.DEFAULT_BRIGHTNESS`)
-- @int age Age of cell
-- @bool highlight If cell is highlighted
-- @treturn Cell Instance of Cell.
-- @todo move X and Y into cell so other methods don't need to pass them around
function Cell.new(world, brightness, age, highlight)
    local cell = {}
    local w = world or {}
    cell.size = world.cell_size_ or 1
    cell.brightness = brightness or Cell.DEFAULT_BRIGHTNESS
    cell.age = age or 1
    cell.highlight = highlight or false

    setmetatable(cell, Cell)
    return cell
end

return Cell
