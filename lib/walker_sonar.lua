--- Walker Sonar class.
-- Manages the walkers pulse, used to emit sound.
--
-- @classmod WalkerSonar
-- @release v0.0.1
-- @author Mimetaur

local WalkerSonar = {}
WalkerSonar.__index = WalkerSonar

WalkerSonar.RELEASE_TIMES = {0.25, 0.5, 1, 2}
--- @field MAX_DISTANCE max possible distance in world
WalkerSonar.MAX_DISTANCE = 180

local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

--- Create a new WalkerSonar object.
-- @walker parent_walker Parent walker.
-- @number note Each WalkerSonar plays one note.
-- @func on_emit_func on_emit Callback on Emit. e.g. `on_emit(self)`
-- @int emit_rate Emits at a slower rate than `step()` is called. This is the multiplier.
-- @int release_idx The index used to pick a release time from `WalkerSonar.RELEASE_TIMES` table.
-- @int max_dist The maximum distance the Sonar uses to calculate emission.
-- @treturn WalkerSonar An instance of WalkerSonar.
function WalkerSonar.new(parent_walker, note, on_emit_func, emit_rate, release_idx, max_dist)
    local ws = {}
    ws.parent_ = parent_walker
    ws.note_ = note
    ws.on_emit = on_emit_func
    ws.emit_rate_ = emit_rate
    ws.release_amount_ = WalkerSonar.RELEASE_TIMES[release_idx]
    ws.counter_ = 1
    ws.max_dist_ = max_dist or 64 -- true max is 180
    setmetatable(ws, WalkerSonar)
    return ws
end

--- Step Sonar.
-- Executes at the emit rate.
-- Calls the `on_emit_func` callback
function WalkerSonar:step()
    self.counter_ = self.counter_ + 1
    if self.counter_ > self.emit_rate_ then
        self:on_emit()
        local parent = self.parent_
        parent:highlight()
        self.counter_ = 1
    end
end

--- Get Parent Walker.
-- @treturn Walker parent
function WalkerSonar:get_parent()
    return self.parent_
end

--- Emit rate.
-- @treturn int emit rate
function WalkerSonar:emit_rate()
    return self.emit_rate_
end

--- Get Note.
-- @treturn number Note.
function WalkerSonar:get_note()
    return self.note_
end

--- Get Release Amount.
-- @treturn number Release Amount.
function WalkerSonar:get_release_amount()
    return self.release_amount_
end

--- Set note.
-- @number new_note New note number.
function WalkerSonar:set_note(new_note)
    self.note_ = new_note
end

--- Set maximum distance.
-- @number new_max_dist New maximum distance.
-- Max dist is used to calculate amplitude
-- of pulse sound
function WalkerSonar:set_max_dist(new_max_dist)
    self.max_dist_ = math.ceil(new_max_dist)
end

--- Get Distance to Nearest Neighbor.
-- @tab walkers Array of Walker objects.
-- @see Walker
-- @treturn number Distance to nearest neighbor.
function WalkerSonar:get_distance_to_nearest_neighbor(walkers)
    local closest_distance = WalkerSonar.MAX_DISTANCE
    for i, walker in ipairs(walkers) do
        local me = self.parent_
        local my_x, my_y = me:position()
        local x, y = walker:position()
        local dist = distance(my_x, my_y, x, y)
        if dist < closest_distance then
            if me:index() == walker:index() then
                -- do nothing
            else
                closest_distance = dist
            end
        end
    end
    return closest_distance
end

--- Inverted, Normalized Distance to Nearest Neighbor
-- @tab walkers Array of Walker objects.
-- @see Walker
-- @treturn number number between 1 and 0 representing the distance to the nearest neighbor. Lower is farther.
function WalkerSonar:inverted_normalized_distance_to_nearest_neighbor(walkers)
    local dist = self:get_distance_to_nearest_neighbor(walkers)
    local mapped_dist = util.linlin(0, self.max_dist_, 0, 1.0, dist)
    local normalized_dist = util.clamp(mapped_dist, 0, 1.0)

    local inverted_dist = 1.0 - normalized_dist
    return inverted_dist
end

return WalkerSonar
