-- Langton's Ant
-- A 2D Turing machine with
-- simple rules but complex
-- emergent behavior

engine.name = "Sines"

-- DEPENDENCIES --
local MusicUtil = require("musicutil")
local json = include("langtons_ant/lib/json")
local BeatClock = require "beatclock"

-- SCRIPT VARS --
local Ant = include("langtons_ant/lib/ant")
local World = include("langtons_ant/lib/world")

local ants = {}
local world = {}

local scale_names = {}
local notes = {}

local clk = BeatClock.new()
local clk_midi = midi.connect()
clk_midi.event = function(data)
    clk:process_midi(data)
end

local note_amp = 0.3
local num_sines = 0
local is_paused = false

local MAX_AMP = 0.75
local MAX_AGE = 20000

-- OSC
dest = {"192.168.1.12", 10112}
local connected_osc = false

-- arc
local ar = arc.connect()
local ArcParams = include("arc_params/lib/arc_params")
local arc_params = ArcParams.new(ar)

function ar.delta(n, delta)
    arc_params:update(n, delta)
end

-------------------------------------------------------------------------------
-- OSC
-------------------------------------------------------------------------------
local function send_world_size()
    local w, h = world:size()
    osc.send(dest, "/world/size", {w, h, world:cell_size()})
end

function osc_in(path, args, from)
    if path == "/hello" then
        print("received /hello")
        dest[1] = from[1]
        osc.send(dest, "/hello")
        send_world_size()
        connected_osc = true
    else
        print("osc from " .. from[1] .. " port " .. from[2])
    end
end
osc.event = osc_in

-- throttling osc output
-- TODO parameterize this
local counter = 1
local osc_threshold = 1
local function on_world_draw(self)
    if not connected_osc then
        return
    end
    counter = counter + 1
    if counter > osc_threshold then
        local world2d = self:to_2d_array()
        local w, h = self:size()
        for col_num = 1, h do
            -- remember that every other programming language uses 0 based arrays!
            osc.send(dest, "/world/update/column", {col_num - 1, json.encode(world2d[col_num])})
        end
        counter = 1
    end
end

-- idea taken from Tehn's Awake sketch
-- https://github.com/monome/dust/blob/master/scripts/tehn/awake.lua
local options = {}
options.STEP_LENGTH_DIVIDERS = {1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64}
options.STEP_LENGTH_NAMES = {"1 bar", "1/2", "1/3", "1/4", "1/6", "1/8", "1/12", "1/16", "1/24", "1/32", "1/48", "1/64"}

local function generate_scale()
    notes = MusicUtil.generate_scale(params:get("root_note"), params:get("scale_mode"), params:get("octave_range"))
end

local function generate_fundamental(ant)
    ant.is_playing = false
    local sine = {}
    sine.frequency = MusicUtil.note_num_to_freq(ant.root_note)
    sine.index = ant.ant_number
    sine.pan = 0.0
    sine.amp = 1.0
    num_sines = num_sines + 1
    return sine
end

local function generate_harmonics(fundamental, ant)
    local neighbors = ant:neighbors_as_cells()
    local valid_neighbors = {}
    for i = 1, Ant.MAX_NEIGHBORS do
        if neighbors[i] then
            table.insert(valid_neighbors, neighbors[i])
        end
    end
    table.sort(
        valid_neighbors,
        function(k1, k2)
            return k1.age < k2.age
        end
    )
    oldest_neighbor_age = 1
    if valid_neighbors[#valid_neighbors] then
        oldest_neighbor_age = valid_neighbors[#valid_neighbors].age
    end
    local sines = {}
    for i = 1, Ant.MAX_NEIGHBORS do
        sines[i] = {}
        sines[i].index = ant.ant_number + i
        sines[i].is_playing = false
        if neighbors[i] then
            sines[i].frequency = fundamental.frequency * (2 * i)
            sines[i].is_playing = true
            sines[i].pan = util.linexp(1, Ant.MAX_NEIGHBORS, -1.0, 1.0, i)
            sines[i].amp = util.linexp(oldest_neighbor_age, 1, 0.0, 1.0, neighbors[i].age)
            num_sines = num_sines + 1
        end
    end
    return sines
end

local function note_on(idx, freq, pan, amp)
    local amp_on_max = (1 / num_sines) * MAX_AMP
    local amp = amp or 1.0
    local pan = pan or 0.0

    engine.amp_atk(idx, params:get("attack_time"))
    engine.amp_rel(idx, params:get("release_time"))

    -- detune
    local r = 1.0 - math.random()
    freq = freq + r

    engine.hz(idx, freq)
    engine.pan(idx, pan)
    engine.amp(idx, amp_on_max * amp)
end

local function note_off(idx)
    engine.amp(idx, 0)
end

local function play_note(fundamental, harmonics, ant)
    if not ant.is_playing then
        note_on(fundamental.index, fundamental.frequency)
        ant.is_playing = true
    end

    for i, harmonic in ipairs(harmonics) do
        local is_playing = harmonic.is_playing
        if is_playing then
            note_on(harmonic.index, harmonic.frequency, harmonic.pan)
        else
            note_off(harmonic.index)
        end
    end
end

local function attach_sines(ant, num)
    local r = #notes or false
    if r and r > 0 then
        local note_idx = math.random(r)
        local note = notes[note_idx]
        ant.root_note = note
        ant.ant_number = num * 10
    end
end

local function step()
    if not is_paused then
        world:update()
        num_sines = 0
        for i, ant in ipairs(ants) do
            ant:update(world)
            local fundamental = generate_fundamental(ant)

            local harmonics = generate_harmonics(fundamental, ant)
            play_note(fundamental, harmonics, ant)
        end
        redraw()
    end
end

local function reset_ants(num)
    if not num then
        num = #ants
    end
    ants = nil
    ants = {}

    local w, h = world:size()

    if num then
        for i = 1, num do
            local xpos = math.random(w)
            local ypos = math.random(h)
            if num == 1 then
                xpos = math.ceil(w / 2)
                ypos = math.ceil(h / 2)
            end
            ants[i] = Ant.new(xpos, ypos)
            attach_sines(ants[i], i)
        end
    end
end

local function reset(options)
    world:reset()
    local num = 1

    if options then
        num = options.num_ants
        if num > 0 then
            note_amp = 0.6 / num
        end
    else
        num = params:get("num_ants")
    end

    reset_ants(num)

    clk:reset()
end

local function draw_ui()
    local y_offset = 6
    local line_height = 10
    if is_paused then
        y_offset = 26
    end
    screen.move(0, y_offset)
    screen.text("Langton's Ant")
    screen.move(64, y_offset)
    screen.text("[Additive Sines]")
    if is_paused then
        screen.move(40, y_offset + line_height)
        screen.text("- PAUSED -")
        screen.move(33, y_offset + (line_height * 2))
        screen.text("[press btn 3]")
    end
end

local function init_params()
    clk:add_clock_params()
    params:set("bpm", 92)

    params:add {
        type = "option",
        id = "step_length",
        name = "step length",
        options = options.STEP_LENGTH_NAMES,
        default = 6,
        action = function(value)
            clk.ticks_per_step = 96 / options.STEP_LENGTH_DIVIDERS[value]
            clk.steps_per_beat = options.STEP_LENGTH_DIVIDERS[value] / 4
            clk:bpm_change(clk.bpm)
        end
    }
    params:add_separator()
    params:add {
        type = "number",
        id = "root_note",
        name = "root note",
        min = 0,
        max = 127,
        default = 24,
        formatter = function(param)
            return MusicUtil.note_num_to_name(param:get("root_note"), true)
        end,
        action = function()
            generate_scale()
        end
    }
    -- default scale is Overtone (#39)
    params:add {
        type = "option",
        id = "scale_mode",
        name = "scale mode",
        options = scale_names,
        default = 39,
        action = function()
            generate_scale()
            reset_ants()
        end
    }
    params:add {
        type = "number",
        id = "octave_range",
        name = "octave range",
        min = 1,
        max = 6,
        default = 2,
        action = function()
            generate_scale()
            reset_ants()
        end
    }
    params:add_separator()
    params:add {
        type = "number",
        id = "num_ants",
        name = "number_of_ants",
        min = 0,
        max = 8,
        default = 1,
        action = function(value)
            local opt = {}
            opt.num_ants = value
            reset(opt)
        end
    }

    params:add_separator()

    params:add {
        type = "number",
        id = "attack_time",
        name = "attack time",
        min = 0.25,
        max = 4.0,
        default = 2.0
    }
    params:add {
        type = "number",
        id = "release_time",
        name = "release_time",
        min = 0.25,
        max = 4.0,
        default = 2.0
    }

    arc_params:register("attack_time", 0.1)
    arc_params:register("release_time", 0.1)
    arc_params:register("num_ants", 0.1)
    arc_params:register("octave_range", 0.1)

    arc_params:add_arc_params()

    params:default()

    generate_scale()
end

local function init_scale_names()
    for i = 1, #MusicUtil.SCALES do
        table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
    end
end

local function init_clock()
    clk.on_step = step

    clk.on_select_external = reset

    clk.on_select_internal = function()
        clk:start()
    end

    clk.on_stop = function()
        -- do something if needed
    end
end

local function init_world()
    local update_cell = function(self, x, y, cell)
        cell.age = cell.age + 1
        if cell.age > MAX_AGE then
            self:delete_cell(x, y)
        end
    end

    world = World.new({cell_size = 2, v_offset = 10, update_cell_func = update_cell, draw_func = on_world_draw})
end

local function init_ants()
    local num = params:get("num_ants")
    reset_ants(num)
end

local function toggle_pause()
    if is_paused == true then
        is_paused = false
    else
        is_paused = true
    end
end

function init()
    init_scale_names()

    init_clock()

    init_world()

    init_params()

    init_ants()

    clk:start()
end

function key(n, z)
    if n == 2 and z == 1 then
        reset()
    end

    if n == 3 and z == 1 then
        toggle_pause()
    end

    redraw()
end

function redraw()
    screen.clear()
    if not is_paused then
        world:draw()
    end
    draw_ui()
    screen.update()
end
