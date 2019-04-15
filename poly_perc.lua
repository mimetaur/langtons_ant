-- Langton's Ant
-- A 2D Turing machine with
-- simple rules but complex
-- emergent behavior

engine.name = "PolyPercPannable"

local RELOAD_LIBS = true

-- DEPENDENCIES --
local BeatClock = require("beatclock")
local MusicUtil = require("musicutil")
local json = include("langtons_ant/lib/json")

local Ant = include("langtons_ant/lib/ant")
local World = include("langtons_ant/lib/world")
local ArcParams = include("arc_params/lib/arc_params")

local Billboard = include("billboard/lib/billboard")
local billboard = Billboard.new()

-- SCRIPT VARS --
local ants = {}
local world = {}

local scale_names = {}
local notes = {}
local is_paused = false

local clk = BeatClock.new()
local clk_midi = midi.connect()
clk_midi.event = function(data)
    clk:process_midi(data)
end

local note_amp = 0.3

-- arc
local ar = arc.connect()
local arc_params = ArcParams.new(ar)

function ar.delta(n, delta)
    arc_params:update(n, delta)
end

-- OSC
dest = {"192.168.1.12", 10112}
local connected_osc = false

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

local function play_note(ant)
    -- derive note from location in vertical space
    local w, h = world:size()
    local note_idx = math.ceil(util.linlin(1, h, 1, #notes, ant:y()))
    local note = notes[note_idx]
    local f = MusicUtil.note_num_to_freq(note)

    -- derive release amount from number of neighbors
    local r = util.linlin(1, 9, params:get("min_release"), params:get("max_release"), ant:neighbors())

    -- derive cutoff from location in horizontal space
    local cut = util.linexp(1, w, params:get("min_cutoff"), params:get("max_cutoff"), ant:x())

    -- dervive pan from location in horizontal space
    local pan = util.linlin(1, w, -1.0, 1.0, ant:x())

    -- leaving pulse width random to have a little variation
    -- not dependent on world layout
    local pw = math.random()

    engine.pan(pan)
    engine.amp(note_amp)
    engine.release(r)
    engine.pw(pw)
    engine.cutoff(cut)
    engine.hz(f)
end

local function step()
    if not is_paused then
        for i, ant in ipairs(ants) do
            ant:update(world)
            if ant:did_hit_trail() then
                play_note(ant)
            end
        end
        redraw()
    end
end

local function reset_ants(num)
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
    local x_offset = 0
    local line_height = 10
    if is_paused then
        y_offset = 26
        x_offset = 8
    end

    screen.move(x_offset, y_offset)
    screen.text("Langton's Ant")
    screen.move(x_offset + 64, y_offset)
    screen.text("[PolyPerc]")
    if is_paused then
        screen.move(40, y_offset + line_height)
        screen.text("- PAUSED -")
        screen.move(33, y_offset + (line_height * 2))
        screen.text("[press btn 3]")
    end
end

local function init_params()
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
        default = 36,
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
        end
    }
    params:add {
        type = "number",
        id = "octave_range",
        name = "octave range",
        min = 1,
        max = 6,
        default = 3,
        action = function()
            generate_scale()
        end
    }
    params:add_separator()
    -- TODO restrict these values
    -- so that min can't be higher than max
    -- and vice versa
    params:add {
        type = "number",
        id = "min_release",
        name = "min release time",
        min = 0.25,
        max = 4,
        default = 0.5,
        action = function(value)
            billboard:display_param("min release", math.ceil(value))
        end
    }
    params:add {
        type = "number",
        id = "max_release",
        name = "max release time",
        min = 0.5,
        max = 12,
        default = 6,
        action = function(value)
            billboard:display_param("max release", math.ceil(value))
        end
    }
    params:add {
        type = "number",
        id = "min_cutoff",
        name = "min cutoff amount",
        min = 100,
        max = 800,
        default = 400,
        action = function(value)
            billboard:display_param("min cutoff", math.ceil(value))
        end
    }
    params:add {
        type = "number",
        id = "max_cutoff",
        name = "max cutoff amount",
        min = 600,
        max = 1400,
        default = 900,
        action = function(value)
            billboard:display_param("max cutoff", math.ceil(value))
        end
    }

    arc_params:register("min_release", 0.25)
    arc_params:register("max_release", 0.25)
    arc_params:register("min_cutoff", 10)
    arc_params:register("max_cutoff", 10)

    arc_params:add_arc_params()

    params:default()

    generate_scale()
end

local function init_scale_names()
    for i = 1, #MusicUtil.SCALES do
        table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
    end
end

local function toggle_pause()
    if is_paused == true then
        is_paused = false
    else
        is_paused = true
    end
end

local function init_ants()
    local num = params:get("num_ants")
    reset_ants(num)
end

function init()
    init_scale_names()

    clk.on_step = step
    clk.on_select_external = reset
    clk.on_select_internal = function()
        clk:start()
    end
    clk.on_stop = function()
        -- do something if needed
    end

    world = World.new({cell_size = 2, v_offset = 10, draw_func = on_world_draw})

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
    billboard:draw()
    draw_ui()
    screen.update()
end
