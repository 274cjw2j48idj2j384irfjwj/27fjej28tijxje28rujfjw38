-- ── DEV BUILD ─────────────────────────────────────────────────────────
-- The normal Specter script without login, auth gate, integrity monitor or loader: every feature unlocked.
-- Generated from specter_cloud.lua by tools/make_dev.py - do not edit by hand, edit specter_cloud.lua and run the tool.
--
-- Only the cloud loadouts talk to the license server: the server lists / loads them, a key + HWID also shares / deletes.
local DEV_SERVER_URL = "https://specter-license-mh111-production.up.railway.app"
local DEV_KEY        = ""
local DEV_HWID       = ""

local _auth_data = { user = "dev", plan = "debug", key = DEV_KEY, hwid = DEV_HWID, server_url = DEV_SERVER_URL }
_USER_NAME = _auth_data.user
-- ── END DEV BUILD ─────────────────────────────────────────────────────

-- ── TIER GATE ─────────────────────────────────────────────────────────
local _PLAN = _auth_data.plan
local TIER = {
    HAS_RESOLVER      = (_PLAN == "debug" or _PLAN == "specter"),
    HAS_RAGEBOT_EXTRA = (_PLAN == "debug" or _PLAN == "specter" or _PLAN == "nightly"),
    HAS_TUNING        = (_PLAN == "debug" or _PLAN == "specter" or _PLAN == "nightly"),
    HAS_BUILDER       = (_PLAN == "debug" or _PLAN == "specter" or _PLAN == "nightly"),
    HAS_AA_STEALER    = (_PLAN == "debug"),
    HAS_DEFENSIVE     = (_PLAN == "debug" or _PLAN == "specter" or _PLAN == "nightly"),
    plan = _PLAN,
}
-- ── END TIER GATE ─────────────────────────────────────────────────────

-- ══ CONTENTS ══════════════════════════════════════════════════════════════════════════════════════════
-- Search for the marker in quotes to jump to a part.
--   "--- Dependencies"            gamesense libraries (pui, csgo_weapons, vector, ...)
--   "--- Modules"                 resolver ("[resolver:begin]"), aa_noise (the noise of the presets)
--   "--- Constant section"        presets, state lists
--   "--- UI library"              menu helpers (mui: headers, rows, hints)
--   "--- Reference"               gamesense menu references (rage, AA, misc)
--   "--- Menu"                    the menu: navigation, Ragebot page (Accuracy / Body aim & safety / Targeting /
--                                 Exploits), Resolver, Tuning (hit chance, weapon profiles, peek assist, Movement,
--                                 Peek bot), statistics
--   "--- FFI"                     memory helpers (animstate, animation layers, usercmd) + the resolver's layer reader
--   "--- Player class"            local player state (state, on ground, defensive, body yaw)
--   "--- Fake lag"                fake lag
--   "--- Anti-aim"                anti-aim: presets, builder, defensive, anti brute-force, manual / legit / safe head
--   "--- Builder"                 the Constructor (custom states)
--   "--- Visuals"                 indicators, hitlogs, keybinds / spectators, scope, watermark
--   "--- Miscellaneous"           clantag, autobuy, anti zeus, FPS booster, auto teleport, jumpscout
--   "--- Settings"                configs, recommended config
--   "--- Antiaim presets"         preset tables
--   "--- Menu state"              which item shows on which page
--   "--- Callbacks"               event callbacks
--   "-- ── rage override"          (end of file) hit chance / damage overrides, smart peek assist
--   "-- ── movement helpers"       (end of file) quick stops, knife swap, peek bot
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

local _ui_get = ui.get
local function safe_ui_get(ref)
    if type(ref) == "table" then
        ref = ref[1]
    end
    return _ui_get(ref)
end
ui.get = safe_ui_get

local user do
    user = {} do
        user.name = _USER_NAME or "admin"
        user.role = _PLAN
        user.debug = false
        user.version = "3.0"
        user.updated = "Sep 30"
        user.is_day = function()
            local ok, h = pcall(client.system_time)
            h = ok and tonumber(h) or 12
            return h >= 6 and h < 19
        end
        user.sky = function()
            return user.is_day() and "☀" or "☾"
        end

        if not LPH_OBFUSCATED then
            LPH_ENCSTR = function (...) return ... end
            LPH_NO_VIRTUALIZE = function (...) return ... end
            LPH_CRASH = function (...) print('Triggered self-descruction and crash of VM') end
        end
    end
end

LPH_NO_VIRTUALIZE(function ()
    local ffi = require 'ffi';
    -- gamesense normally provides toticks; keep a fallback so defensive timing never errors
    local toticks = toticks or function(t) return math.floor(0.5 + (t or 0) / globals.tickinterval()) end

    local ui_get, ui_set, ui_reference, ui_set_visible, ui_is_menu_open = ui.get, ui.set, ui.reference, ui.set_visible, ui.is_menu_open
    local entity_get_local_player, entity_get_prop, entity_get_player_name = entity.get_local_player, entity.get_prop, entity.get_player_name
    local globals_tickcount, globals_curtime, globals_frametime, globals_tickinterval = globals.tickcount, globals.curtime, globals.frametime, globals.tickinterval
    local client_random_int, client_trace_line = client.random_int, client.trace_line
    local math_abs, math_min, math_max, math_sqrt, math_floor, math_ceil = math.abs, math.min, math.max, math.sqrt, math.floor, math.ceil
    local table_insert, table_remove, table_sort, table_concat = table.insert, table.remove, table.sort, table.concat
    local string_format = string.format

    ---
    --- Dependencies manager
    ---
    do
        local dependencies = {
            ['csgo_weapons'] = {
                name = 'gamesense/csgo_weapons',
                type = 'workshop',
                link = 'https://gamesense.pub/forums/viewtopic.php?id=18807'
            },
            ['base64'] = {
                name = 'gamesense/base64',
                type = 'workshop',
                link = 'https://gamesense.pub/forums/viewtopic.php?id=21619'
            },
            ['clipboard'] = {
                name = 'gamesense/clipboard',
                type = 'workshop',
                link = 'https://gamesense.pub/forums/viewtopic.php?id=28678'
            },
            ['surface'] = {
                name = 'gamesense/surface',
                type = 'workshop',
                link = 'https://gamesense.pub/forums/viewtopic.php?id=18793'
            },
            ['json'] = {
                name = 'json',
                type = 'local',
                link = 'built-in'
            }
        }

        if user.debug then
            dependencies['inspect'] = {
                name = 'gamesense/inspect',
                type = 'workshop',
                link = ''
            }
        end

        local located = true

        for gname, method in pairs(dependencies) do
            local success = pcall(require, method.name)

            if not success then
                if method.type == 'workshop' then
                    client.error_log(string_format('[-] Unable to locate %s library. You need to subscribe to it here %s', gname, method.link))
                elseif method.type == 'local' then
                    client.error_log(string_format('[-] Unable to locate %s library. You need to download it and put in script folder. Link is %s', gname, method.link))
                end

                located = false
            end
        end

        if not located then
            return error('[~] Script was unable to start. You can investigate error above.')
        end
    end

    ---
    --- Dependencies
    ---
    local vector = require 'vector'
    local csgo_weapons = require 'gamesense/csgo_weapons'
    local base64 = require 'gamesense/base64'
    local clipboard = require 'gamesense/clipboard'
    local surface = require 'gamesense/surface'
    local json = require 'json'
    -- only the cloud configs need it: a missing library must not stop the whole script from loading
    local http_ok, http = pcall(require, 'gamesense/http')
    if not http_ok then http = nil end


    local hitlog_data = {}
    local function add_hitlog(entry)
        if type(entry) ~= "table" then entry = { kind = "info", text = tostring(entry) } end
        entry.time, entry.alpha, entry.slide = globals.realtime(), 0, 0
        table_insert(hitlog_data, entry)
        local max = hitlog_data.max or 7
        while #hitlog_data > max do
            table_remove(hitlog_data, 1)
        end
    end
    local inspect do
        if user.debug then
            inspect = require 'gamesense/inspect'
        end
    end

    ---
    --- Internal modules
    ---
    local c_math, c_logger, c_table, c_string, c_animations, c_tweening, c_grams do
        c_math = {} do
            c_math.min = (function (a, b)
                return a > b and b or a
            end)

            c_math.max = (function (a, b)
                return a > b and a or b
            end)

            c_math.abs = (function (a)
                return a > 0 and a or -a
            end)

            c_math.round = (function (a)
                return math_floor(a+0.5)
            end)

            c_math.normalize_yaw = (function (a)
                -- one step for any value: the old loops (minus 360 until <= 180) never ended on inf and ran for minutes
                -- on a huge value (a bad memory read gives 1e12 .. 1e38), the game froze. Same result as the loops
                if a ~= a or a == math.huge or a == -math.huge then return 0 end
                if a > 540 or a < -540 then a = math.fmod(a, 360) end
                if a > 180 then
                    a = a - 360
                elseif a < -180 then
                    a = a + 360
                end

                return a
            end)

            c_math.clamp = (function (v, min, max)
                if v == nil then return min or 0 end
                if min == nil then min = v end
                if max == nil then max = v end
                if v > max then
                    return max
                elseif v < min then
                    return min
                end

                return v
            end)

            c_math.abs = math_abs

            c_math.random = client_random_int

            c_math.randomf = (function (min, max)
                return min + (max-min)*math.random()
            end)

            c_math.lerp = (function (a, b, v)
                local delta = (b - a)

                if math_abs(delta) <= 0.095 then
                    return b
                end

                return a + delta*v
            end)

            -- where `origin` (a point on `ent`) is `ticks` ticks from now. On the ground the height stays; in the air the
            -- server's movement: v * t - g * t^2 / 2 (it used to add the jump impulse when falling and skip gravity going up).
            -- ONE trace to the end point: a wall or the floor in the way stops it at the last whole tick before it
            c_math.extrapolate = (function (ent, origin, ticks)
                local ti = globals_tickinterval()
                local g = cvar.sv_gravity:get_float()
                local vx, vy, vz = entity_get_prop(ent, 'm_vecVelocity')
                vx, vy, vz = vx or 0, vy or 0, vz or 0
                local on_ground = bit.band(entity_get_prop(ent, 'm_fFlags') or 1, 1) == 1

                local function at(n)
                    local t = n * ti
                    local dz = on_ground and 0 or (vz * t - 0.5 * g * t * t)
                    return origin.x + vx * t, origin.y + vy * t, origin.z + dz
                end

                local ex, ey, ez = at(ticks)
                local fraction = client_trace_line(-1, origin.x, origin.y, origin.z, ex, ey, ez)
                local steps = ticks
                if fraction <= 0.99 then
                    steps = math_floor(fraction * ticks)
                end
                return vector(at(steps))
            end)
        end

        c_logger = {} do
            c_logger.log = (function (format, ...)
                client.color_log(180, 160, 255, 'specter  \1\0')
                client.color_log(61, 212, 197, ('[%02d:%02d:%02d] \1\0'):format(client.system_time()))
                client.color_log(255, 255, 255, format:format(...))
            end)

            c_logger.log_error = (function (format, ...)
                client.color_log(180, 160, 255, 'specter  \1\0')
                client.color_log(61, 212, 197, ('[%02d:%02d:%02d] \1\0'):format(client.system_time()))
                client.color_log(255, 0, 255, format:format(...))
            end)

        end

        c_table = {} do
            c_table.unpack_keywise = (function (keys, ...)
                local new_table = {}
                local args = {...}

                for i=1, #keys do
                    local val = args[i]
                    if val ~= nil then
                        new_table[keys[i]] = val
                    end
                end

                return new_table
            end)

            c_table.combine_arrays = (function (...)
                local new_table = {}

                local arrays = {...}
                local cnt = 1

                for i=1, #arrays do
                    for _, value in pairs(arrays[i]) do
                        new_table[cnt] = value
                        cnt = cnt + 1
                    end
                end

                return new_table
            end)

            c_table.is_hotkey_active = (function (element)
                if not element or not element[1] or not element[2] then return false end
                return ui_get(element[1]) and ui_get(element[2])
            end)

            c_table.contains = (function (tbl, value)
                local tbl_len = #tbl

                for i=1, tbl_len do
                    if tbl[i] == value then
                        return true
                    end
                end

                return false
            end)

            c_table.keys = (function (table)
                local keys = {}

                for key in next, table, nil do
                    keys[#keys+1] = key
                end

                return keys
            end)

        end

        c_string = {} do
            c_string.trim = (function (str)
                while str:sub(1, 1) == ' ' do
                    str = str:sub(2)
                end

                while str:sub(#str, #str) == ' ' do
                    str = str:sub(1, #str-1)
                end

                if #str == 0 or str == '' then
                    str = 'Unnamed'
                end

                return str
            end)

            c_string.split = (function (str, sep)
                local result = {}
                local start = str:find(sep)

                if not start then
                    return {str}
                end

                local pos = 1

                while start do
                    result[#result+1] = str:sub(pos, start)

                    pos = start+sep:len()

                    start = str:find(sep, pos)

                    if not start then
                        result[#result+1] = str:sub(pos)
                    end
                end

                return result
            end)
        end

        c_animations = {} do
            c_animations.data = {}

            function c_animations:new(key, increasing, speed, modifier, initial_value)
                self.data[key] = self.data[key] or {
                    method = 'lerp',
                    increasing = increasing,
                    speed = speed or 4,
                    modifier = modifier or 0,
                    value = initial_value or 0
                }

                return self.data[key]
            end

            function c_animations:sway(key, from, to, speed, iterations, initial_value)
                self.data[key] = self.data[key] or {
                    active = 0,
                    method = 'sway',
                    increasing = false,
                    start = c_math.min(from, to),
                    target = c_math.max(from, to),
                    speed = speed or 4,
                    iterations = iterations or 1,
                    value = initial_value or from
                }

                local this = self.data[key]

                this.start, this.target = c_math.min(from, to), c_math.max(from, to)
                this.speed, this.iterations = speed, iterations

                return this
            end

            function c_animations:spin(key, from, to, speed, iterations, initial_value)
                self.data[key] = self.data[key] or {
                    active = 0,
                    method = 'spin',
                    start = c_math.min(from, to),
                    target = c_math.max(from, to),
                    speed = speed or 4,
                    iterations = iterations or 1,
                    value = initial_value or from
                }

                local this = self.data[key]

                this.start, this.target = c_math.min(from, to), c_math.max(from, to)
                this.speed, this.iterations = speed, iterations

                return this
            end

            function c_animations:flick(key, from, to, speed, initial_value)
                self.data[key] = self.data[key] or {
                    active = 0,
                    method = 'flick',
                    start = c_math.min(from, to),
                    target = c_math.max(from, to),
                    speed = speed or 4,
                    value = initial_value or from
                }

                local this = self.data[key]

                this.start, this.target = c_math.min(from, to), c_math.max(from, to)
                this.speed = speed

                return this
            end

            function c_animations:frame()
                local frametime = globals_frametime()

                for key, state in pairs(self.data) do
                    if state.method == 'lerp' then
                        state.value = c_math.clamp(state.value + (state.increasing and 1 or -1) * state.speed * frametime, 0, 1)
                    end
                end
            end

            function c_animations:tick(tick)
                for key, state in pairs(self.data) do
                    if state.method == 'sway' then
                        local difference = tick - state.active

                        if difference > state.speed or c_math.abs(difference) > 64 then
                            for i=1, state.iterations do
                                if state.increasing then
                                    if state.value < state.target then
                                        state.value = state.value + 1
                                    else
                                        state.increasing = false
                                    end
                                else
                                    if state.value > state.start then
                                        state.value = state.value - 1
                                    else
                                        state.increasing = true
                                    end
                                end
                            end

                            state.active = tick
                        end
                    end

                    if state.method == 'spin' then
                        local difference = tick - state.active

                        if difference > state.speed or c_math.abs(difference) > 64 then
                            for i=1, state.iterations do
                                if state.value < state.target then
                                    state.value = state.value + 1
                                else
                                    state.value = state.start
                                end
                            end

                            state.active = tick
                        end
                    end

                    if state.method == 'flick' then
                        local difference = tick - state.active

                        if difference > state.speed or c_math.abs(difference) > 64 then
                            state.increasing = not state.increasing
                            state.value = state.increasing and state.start or state.target
                            state.active = tick
                        end
                    end
                end
            end
        end

        c_tweening = {} do
            -- the engine's time scale: the vtable call, or the host_timescale cvar when the call is not there (an update)
            local native_GetTimescale do
                local ok, fn = pcall(vtable_bind, 'engine.dll', 'VEngineClient014', 91, 'float(__thiscall*)(void*)')
                if not ok then fn = nil end
                local function from_cvar()
                    local ok2, v = pcall(function() return cvar.host_timescale:get_float() end)
                    return (ok2 and type(v) == "number" and v > 0) and v or 1
                end
                native_GetTimescale = function()
                    if fn then
                        local ok3, v = pcall(fn)
                        if ok3 and type(v) == "number" and v > 0 and v < 100 then return v end
                        fn = nil
                    end
                    return from_cvar()
                end
            end

            local function solve(easings_fn, prev, new, clock, duration)
                local prev = easings_fn(clock, prev, new - prev, duration)

                if type(prev) == 'number' then
                    if math_abs(new - prev) <= .01 then
                        return new
                    end

                    local fmod = prev % 1

                    if fmod < .001 then
                        return math_floor(prev)
                    end

                    if fmod > .999 then
                        return math_ceil(prev)
                    end
                end

                return prev
            end

            local mt = {}; do
                local function update(self, duration, target, easings_fn)
                    if duration == nil and target == nil and easings_fn == nil then
                        return self.value
                    end

                    local value_type = type(self.value)
                    local target_type = type(target)

                    if target_type == 'boolean' then
                        target = target and 1 or 0
                        target_type = 'number'
                    end

                    assert(value_type == target_type, string_format('type mismatch, expected %s (received %s)', value_type, target_type))

                    if target ~= self.to then
                        self.clock = 0

                        self.from = self.value
                        self.to = target
                    end

                    local clock = globals_frametime() / native_GetTimescale()
                    local duration = duration or .15

                    if self.clock == duration then
                        return target
                    end

                    if clock <= 0 and clock >= duration then
                        self.clock = 0

                        self.from = target
                        self.to = target

                        self.value = target

                        return target
                    end

                    self.clock = math_min(self.clock + clock, duration)
                    self.value = solve(easings_fn or self.easings, self.from, self.to, self.clock, duration)

                    return self.value;
                end

                mt.__metatable = false
                mt.__call = update
                mt.__index = mt
            end

            function c_tweening:new(default, easings_fn)
                if type(default) == 'boolean' then
                    default = default and 1 or 0
                end

                local this = {}

                this.clock = 0
                this.value = default or 0

                this.easings = easings_fn or function(t, b, c, d)
                    return c * t / d + b
                end

                return setmetatable(this, mt)
            end
        end

        c_grams = {} do
            c_grams.update_gram = (function (gram, v, maxlen)
                while #gram > maxlen-1 do
                    table_remove(gram, 1)
                end

                table_insert(gram, v)
            end)

            c_grams.average = (function (gram)
                local sum, cnt = 0, 0

                for i=1, #gram do
                    sum = sum + gram[i]
                    cnt = cnt + 1
                end

                if cnt == 0 then
                    return 0
                end

                return sum / cnt
            end)
        end
    end

    local config = {}
    local aa_stealer
    local player, reference, ffi_helpers

    -- [ping:begin]
    -- Our real ping in ms (round trip), without the fake ping of the ping spike / extended backtrack: the results of our
    -- shots and the enemies' answers come with the real one. gamesense's real latency is the net channel's one way
    -- latency without the fake part. The scoreboard ping is not used (owners, Oct 2026: "scoreboardrol szedi, nem jol
    -- meri"): it has the fake ping in it, the server updates it every few seconds, and the old real / total scaling put
    -- a 200 ms spike on the 150 ms row
    local function real_ping()
        local function latency(fn)
            if not fn then return nil end
            local ok, v = pcall(fn)
            return (ok and type(v) == "number" and v >= 0 and v < 5) and v or nil
        end
        return (latency(client.real_latency) or latency(client.latency) or 0) * 2000
    end
    -- [ping:end]

    ---
    --- Modules
    ---
    local resolver, aa_noise do
        resolver = {} do
        if not TIER.HAS_RESOLVER then
            resolver.database, resolver.memory, resolver.shots, resolver.forced = {}, {}, {}, {}
            resolver.release = function() end
            resolver.release_all = function() end
            resolver.new_round = function() end
            resolver.reset_player = function() end
            resolver.reset_all = function() end
            resolver.on_fire = function() end
            resolver.on_hit = function() end
            resolver.on_miss = function() end
            -- the hitlog still reads the backtrack of every shot on tiers without the resolver
            resolver.shot_backtrack = function(event)
                return tonumber(type(event) == "table" and event.backtrack) or 0
            end
        else
            -- [resolver:begin]
            -- Specter resolver. No list of guesses, no hand-tuned order: the angle is computed, the rest is learned.
            --
            -- The server decides a player's body yaw with its feet logic: standing, the feet turn to the lower body yaw target;
            -- moving, they follow the eye yaw; never further than the max desync from the eye. The resolver runs the same logic
            -- on what the server sends us (eye yaw, lower body yaw target, speed, sim time): the COMPUTED body yaw of a record.
            -- What it cannot see (the choked ticks, a side the cheat picks) is LEARNED from the shots.
            --
            -- Per player and situation (stance, jitter side, defensive record) it keeps a probability for every angle
            -- (-60 .. 60), from three models:
            --   computed   the computed body yaw + a learned offset
            --   mirrored   minus the computed body yaw + a learned offset
            --   side       a learned size, on the side the target is on now: a side it may switch after a hit, after a miss
            --              or at random moments, how often and how quickly is learned per player (see "side switches")
            -- A head hit says the body yaw was within TOL of the angle the record got, a resolver miss says it was not (Bayes).
            -- Each model is weighted by how well it predicted the shots, and the angle most likely to hit is forced.
            -- A shot is judged by what the RECORD it went at got (backtrack). Misses that are not about the angle are ignored.
            -- A tickbase shifted update (defensive) is no record: the server adds a lag record only when the sim time moves
            -- forward, a shot at the shifted model is tested against the newest normal record at or before its sim time.
            -- So it gets no angle of its own (the forced value stays the one of the jitter / desync record), and a shot
            -- fired at it is judged by that record; its miss is about lag comp, not the angle.
            local MAX_DESYNC = 58
            local JITTER_SPREAD = 30          -- degrees of yaw spread (with 2+ side flips) that make a jitterer
            local ZERO_MIN = 20               -- |angle| below this: "no desync" (it can hit neither side of a real desync)
            local STEP, TOL = 4, 12           -- angles -60 .. 60 in steps of 4; within TOL of the body yaw the head is hit
            local NB, NM = 31, 16             -- angle bins (-60 .. 60), size bins (0 .. 60)
            local HIST_TIME = 1.0             -- seconds of records per player: the most the server lag compensates (sv_maxunlag
                                              -- is capped at 1 s): 64 ticks on 64 tick, 128 on 128 tick
            local WINDOW = 12                 -- records the jitter detection looks at
            local GAP_RESET = 64              -- ticks without an update (dormant, lag spike): the old records say nothing any more
            local P_HIT, P_LUCK = 0.85, 0.05  -- the right angle hits the head / a wrong one still does
            local FORGET = 0.02               -- per result, this much of a belief goes back to where it started (targets change)
            local DECAY = 0.9                 -- model scores: weight of the older results
            local RDECAY = 0.97               -- side switch delays: weight of the older results

            -- Ping scale: the numbers above that depend on the ping (results arrive later, the target answers later).
            -- set_tune is called with the row of the ping table for the current ping; nil = the defaults
            local TUNE_DEFAULT = { forget = FORGET, p_hit = P_HIT, decay = DECAY, tol = TOL, rdecay = RDECAY }
            resolver.tune_default = TUNE_DEFAULT
            resolver.set_tune = function(t)
                t = t or TUNE_DEFAULT
                local function num(v, d, lo, hi)
                    v = tonumber(v)
                    if not v or v ~= v then return d end
                    return math.min(math.max(v, lo), hi)
                end
                FORGET = num(t.forget, TUNE_DEFAULT.forget, 0.001, 0.2)
                P_HIT = num(t.p_hit, TUNE_DEFAULT.p_hit, 0.5, 0.98)
                DECAY = num(t.decay, TUNE_DEFAULT.decay, 0.5, 0.995)
                TOL = math.floor(num(t.tol, TUNE_DEFAULT.tol, 6, 20) + 0.5)
                RDECAY = num(t.rdecay, TUNE_DEFAULT.rdecay, 0.8, 0.998)
            end

            local A = {}                      -- angle of each bin
            for i = 1, NB do A[i] = (i - 1) * STEP - 60 end

            local players = {}        -- [entindex] = see player_of (this round)
            local mem = {}            -- [player key] = { b = beliefs per situation, rates = side switch numbers, hit_value }
            local global = {}         -- beliefs over all players per situation: where a new player starts
            local shots = {}          -- [shot id] = what the record the shot went at got
            local saved = {}          -- [entindex] = { ok, correction } "Correction active" before we touched it (= forced by us)
            local forced = {}         -- [entindex] = the value written to "Force body yaw value"

            local function publish()
                resolver.database, resolver.memory, resolver.shots, resolver.forced = players, mem, shots, forced
            end
            publish()

            local function enabled()
                local item = config.resolver and config.resolver.enabled
                return item ~= nil and item:get() == true
            end

            -- a menu value, or the default when the item does not exist (tiers / tests without it)
            local function option(name, default)
                local item = config.resolver and config.resolver[name]
                if item == nil then return default end
                local ok, v = pcall(item.get, item)
                if not ok or v == nil then return default end
                return v
            end

            -- ── helpers ────────────────────────────────────────────────────────────
            local function clamp(v, lo, hi)
                if v < lo then return lo end
                if v > hi then return hi end
                return v
            end

            local function finite(v)
                return type(v) == "number" and v == v and v > -1e9 and v < 1e9
            end

            local function normalize(a)
                return (a + 180) % 360 - 180
            end

            local function approach(target, value, step)
                local d = normalize(target - value)
                if d > step then return normalize(value + step) end
                if d < -step then return normalize(value - step) end
                return normalize(target)
            end

            local function key_of(idx)
                local ok, sid = pcall(entity.get_steam64, idx)
                if ok and sid ~= nil then
                    sid = tostring(sid)
                    if sid ~= "0" and sid ~= "" then return "id" .. sid end
                end
                local okn, name = pcall(entity.get_player_name, idx)
                return "n" .. tostring(okn and name or idx)
            end

            local function name_of(idx)
                local ok, name = pcall(entity.get_player_name, idx)
                return ok and name and tostring(name) or tostring(idx)
            end

            local function memory_of(key)
                local m = mem[key]
                if not m then
                    m = { b = {}, hit_value = {}, zero = {} }
                    mem[key] = m
                end
                return m
            end

            -- "no desync" (a body yaw near 0) has to be earned: almost every HvH player desyncs, and the feet model says ~0
            -- whenever the netvars show nothing (micromovement keeps the lower body yaw on the eye yaw). On a record whose
            -- computed body yaw is ~0, a near-0 angle is only given after a head hit near 0 on such records of this player in
            -- this situation, or after 2 resolver misses away from 0 since the last hit (then it may really not desync).
            -- Jitter records too (micromovement + fakelag: the feet model lands near 0 on half of them, they got 0 / +-12
            -- against a real desync), there after 3 misses: the body side switches, misses on both sides are normal.
            -- That near-0 try is one shot: when it misses too, the misses are counted again and each failed try doubles
            -- how many it takes (2, 4, 8 .. 32): a target we keep missing for other reasons (lag comp breakers counted as
            -- resolver misses) got a near-0 shot after every 2 misses. A player who sent every tick for the last 16
            -- updates (no choke, no tickbase shift) can not desync at all: near 0 is fine there.
            -- (Defensive records used to be exempt: they got the computed body yaw of the flick, often ~0, "res 0°")
            local function zero_of(key, ctx)
                local m = memory_of(key)
                m.zero = m.zero or {}
                local z = m.zero[ctx]
                if not z then z = { hits = 0, mp = 0, mn = 0 }; m.zero[ctx] = z end
                return z
            end
            local function zero_allowed(key, ctx, p)
                if p and (p.nochoke or 0) >= 16 then return true end
                local z = zero_of(key, ctx)
                return z.hits >= 0.3 or z.mp + z.mn >= ((ctx == "j+" or ctx == "j-") and 3 or 2) * 2 ^ math.min(z.tries or 0, 4)
            end
            local function zero_result(key, ctx, v, hit)
                local z = zero_of(key, ctx)
                local near = math.abs(v) < ZERO_MIN
                if hit then
                    z.hits = near and (z.hits + 1) or z.hits * 0.5
                    z.mp, z.mn = 0, 0
                    if near then z.tries = 0 end
                elseif near then
                    z.hits = z.hits * 0.6
                    z.mp, z.mn = 0, 0
                    z.tries = (z.tries or 0) + 1
                elseif v > 0 then z.mp = z.mp + 1
                else z.mn = z.mn + 1 end
            end

            local function likelihood(a, v, hit, ph)
                local near = math.abs(a - v) <= TOL
                ph = ph or P_HIT
                if hit then return near and ph or P_LUCK end
                return near and (1 - ph) or (1 - P_LUCK)
            end

            -- How often a shot at the right side still misses on this player (spread is not counted, it is reported as
            -- spread): learned from what comes after a resolver miss. The next head hit on the same side = the miss was
            -- noise (prediction, animation ...); on the other side = the side had switched. A clean target needs one miss to
            -- switch the side guess, a noisy one keeps the side through a single miss. Starts at P_HIT (17 : 3).
            local grel = { hit = 17, noise = 3 }
            local function rel_of(key)
                local m = memory_of(key)
                if not m.rel then m.rel = { hit = grel.hit * 20 / (grel.hit + grel.noise), noise = grel.noise * 20 / (grel.hit + grel.noise) } end
                return m.rel
            end
            local function rel_count(r, hit, noise, w)
                r.hit, r.noise = r.hit + hit * w, r.noise + noise * w
                local n = r.hit + r.noise
                if n > 120 then r.hit, r.noise = r.hit * 120 / n, r.noise * 120 / n end
            end
            local function reliability(key)
                local r = rel_of(key)
                return clamp(r.hit / (r.hit + r.noise), 0.7, 0.97)
            end

            -- Body side patterns: a body yaw that switches on its own cycle (every packet, every 2 packets, ...), not with the
            -- yaw jitter (gamesense "Jitter" body yaw with a random / skitter / delayed / offset yaw). The side of record n is
            -- learned per n mod P for P = 2, 3, 4, 6; a cycle is used only when it predicted the results better than the side
            -- filter did on the same records (log score), so a static or yaw-tied side keeps the filter
            local PATTERNS = { 2, 3, 4, 6 }
            local function pat_of(key)
                local m = memory_of(key)
                if not m.pat then
                    m.pat = { obs = 0, base = 0 }
                    for _, P in ipairs(PATTERNS) do m.pat[P] = { score = 0, c = {} } end
                end
                return m.pat
            end
            local function pat_class(t, P, n)
                local r = n % P
                local cl = t[P].c[r]
                if not cl then cl = { a = 0, b = 0 }; t[P].c[r] = cl end
                return cl
            end
            local function pat_predict(key, n)
                local t = mem[key] and mem[key].pat
                if not t or not n or t.obs < 6 then return nil end
                local best, bs = nil, t.base + 1.5
                for _, P in ipairs(PATTERNS) do
                    if t[P].score > bs then best, bs = P, t[P].score end
                end
                if not best then return nil end
                local cl = pat_class(t, best, n)
                return clamp((cl.a + 0.5) / (cl.a + cl.b + 1), 0.03, 0.97), best, bs - t.base
            end

            -- Animation layer 6 (movement) of a running target: its playback rate depends on where the feet point against
            -- the direction of the run, so with a desync the rate sits a little above or below the player's normal one,
            -- per side. resolver.read_layer6(idx) (set by the ffi part; nil = no layer reading) gives the rate; the record
            -- gets a class by how far the rate is from this player's running mean (in its own spread), and the side is
            -- learned per class like the cycles above. Used only when it predicted better than the side filter
            local LAYER_EDGES = { -1, -0.3, 0.3, 1 }
            local function layer_class(p, idx)
                local reader = resolver.read_layer6
                if not reader or p.stance ~= "move" then return nil end
                local ok, rate = pcall(reader, idx)
                if not ok or not finite(rate) or rate <= 0 or rate > 5 then return nil end
                local m, v = p.l6m, p.l6v
                local cls
                if m and v and (p.l6n or 0) >= 8 then
                    local z = (rate - m) / math.sqrt(v + 1e-8)
                    cls = #LAYER_EDGES + 1
                    for i, e in ipairs(LAYER_EDGES) do if z < e then cls = i; break end end
                end
                if not m then p.l6m, p.l6v = rate, 0
                else
                    local d = rate - m
                    p.l6m = m + 0.05 * d
                    p.l6v = 0.95 * (v + 0.05 * d * d)
                end
                p.l6n = (p.l6n or 0) + 1
                return cls
            end
            -- Freestanding: two traces from our eye to points 45 units left and right of the enemy's head (across the line
            -- to us). Which one a wall cuts gives a class (left blocked / right blocked / both / none): a "freestanding body
            -- yaw" puts the side by the walls. Traces cost: the threat every 4 ticks, the others every 16, the class is kept
            -- Hide head predictor: the enemy's freestanding put its head by a wall as seen from where IT saw us, and it saw
            -- us late: our one-way ping + its ping + interp. Our eye position is kept per tick and the traces start from
            -- that old position (a peek of ours moves us 20-60 units in that time: the wall cuts the other side by then)
            local eye_hist = {}
            local function eye_record(tick)
                local ok, x, y, z = pcall(client.eye_position)
                if ok and finite(x) and finite(y) and finite(z) then eye_hist[tick % 64] = { tick, x, y, z } end
            end
            resolver.eye_record = eye_record
            local function eye_seen_by(idx, tick)
                local x, y, z = client.eye_position()
                local ping = 0
                local okr, res = pcall(entity.get_player_resource)
                if okr and res then
                    local okp, v = pcall(entity.get_prop, res, "m_iPing", idx)
                    if okp and finite(v) then ping = clamp(v, 0, 400) end
                end
                -- our side of it: the real one way latency (a fake ping does not delay what they see of us)
                local lat = clamp(real_ping() / 2000, 0, 0.4)
                local back = clamp(math.floor((ping / 1000 + lat + 0.016) / globals.tickinterval() + 0.5), 0, 48)
                local e = back > 0 and eye_hist[(tick - back) % 64]
                if e and e[1] == tick - back then return e[2], e[3], e[4] end
                return x, y, z
            end

            local function fs_class(p, idx, tick)
                if p.fs_t and tick - p.fs_t < ((client.current_threat() == idx) and 4 or 16) and tick >= p.fs_t then return p.fcls end
                p.fs_t = tick
                local ok, cls = pcall(function()
                    local ox, oy, oz = entity.get_prop(idx, "m_vecOrigin")
                    local lx, ly, lz = eye_seen_by(idx, tick)
                    if not (finite(ox) and finite(oy) and finite(lx) and finite(ly)) then return nil end
                    oz, lz = (finite(oz) and oz or 0) + 64, finite(lz) and lz or 64
                    local a = math.atan2(ly - oy, lx - ox)
                    local rx, ry = ox + math.cos(a + math.pi / 2) * 45, oy + math.sin(a + math.pi / 2) * 45
                    local bx, by = ox + math.cos(a - math.pi / 2) * 45, oy + math.sin(a - math.pi / 2) * 45
                    local me = entity.get_local_player()
                    local fr = client.trace_line(me, lx, ly, lz, rx, ry, oz)
                    local fb = client.trace_line(me, lx, ly, lz, bx, by, oz)
                    if not (finite(fr) and finite(fb)) then return nil end
                    local r_cut, b_cut = fr < 0.97, fb < 0.97
                    if r_cut and not b_cut then return 1 elseif b_cut and not r_cut then return 2 elseif r_cut then return 3 end
                    return 4
                end)
                p.fcls = ok and cls or nil
                return p.fcls
            end

            -- a feature model per player: "lay" (layer 6 class), "fs" (freestanding class)
            local function feat_of(key, name)
                local m = memory_of(key)
                m.feat = m.feat or {}
                if not m.feat[name] then m.feat[name] = { obs = 0, base = 0, score = 0, c = {} } end
                return m.feat[name]
            end
            local function feat_predict(key, name, cls)
                local t = mem[key] and mem[key].feat and mem[key].feat[name]
                if not t or not cls or t.obs < 6 or t.score <= t.base + 1.5 then return nil end
                local cl = t.c[cls]
                if not cl then return nil end
                return clamp((cl.a + 0.5) / (cl.a + cl.b + 1), 0.03, 0.97), t.score - t.base
            end
            -- the same models over ALL players (hide head predictor): most cheats hide the head the same way, so what
            -- the shots at the others showed is used for a player of whom too little is known yet. It is used only while
            -- it predicts better than the side model over everyone (score > base), so mixed conventions switch it off
            local gfeat = {}
            local function gfeat_predict(name, cls)
                local t = gfeat[name]
                if not t or not cls or t.obs < 12 or t.score <= t.base + 3 then return nil end
                local cl = t.c[cls]
                if not cl or cl.a + cl.b < 3 then return nil end
                return clamp((cl.a + 0.5) / (cl.a + cl.b + 1), 0.05, 0.95), (t.score - t.base) * 0.25
            end
            local function feat_learn(key, name, cls, side, pi_base)
                do
                    local g = gfeat[name]
                    if not g then g = { obs = 0, base = 0, score = 0, c = {} }; gfeat[name] = g end
                    local function lg(pr) return math.log(math.max(side > 0 and pr or 1 - pr, 0.02)) end
                    local gc = g.c[cls]
                    if not gc then gc = { a = 0, b = 0 }; g.c[cls] = gc end
                    g.obs = g.obs + 1
                    g.base = g.base * 0.98 + lg(pi_base)
                    g.score = g.score * 0.98 + lg((gc.a + 0.5) / (gc.a + gc.b + 1))
                    gc.a, gc.b = gc.a * 0.98 + (side > 0 and 1 or 0), gc.b * 0.98 + (side < 0 and 1 or 0)
                end
                local t = feat_of(key, name)
                t.obs = t.obs + 1
                local function lg(pr) return math.log(math.max(side > 0 and pr or 1 - pr, 0.02)) end
                local cl = t.c[cls]
                if not cl then cl = { a = 0, b = 0 }; t.c[cls] = cl end
                t.base = t.base * 0.97 + lg(pi_base)
                t.score = t.score * 0.97 + lg((cl.a + 0.5) / (cl.a + cl.b + 1))
                cl.a, cl.b = cl.a * 0.95 + (side > 0 and 1 or 0), cl.b * 0.95 + (side < 0 and 1 or 0)
            end
            local function pat_learn(key, n, side, pi_base)
                local t = pat_of(key)
                t.obs = t.obs + 1
                local function lg(pr) return math.log(math.max(side > 0 and pr or 1 - pr, 0.02)) end
                t.base = t.base * 0.97 + lg(pi_base)
                for _, P in ipairs(PATTERNS) do
                    local cl = pat_class(t, P, n)
                    t[P].score = t[P].score * 0.97 + lg((cl.a + 0.5) / (cl.a + cl.b + 1))
                    cl.a, cl.b = cl.a * 0.95 + (side > 0 and 1 or 0), cl.b * 0.95 + (side < 0 and 1 or 0)
                end
            end

            -- ── beliefs ────────────────────────────────────────────────────────────
            -- where a belief starts: computed / mirrored trust the computation half (offset 0), the side model knows nothing.
            -- The side model has a size per side (3 = positive, 4 = negative): a target can sit at -20 on one side and +50
            -- on the other (one size for both sides hit 0.19 there)
            local function prior(f)
                local n = f >= 3 and NM or NB
                local h = {}
                for i = 1, n do h[i] = 1 / n end
                -- sizes: a desync is mostly as big as the server lets it be. A flat start made the first shots on a new
                -- player go at the middle (0 / +-20, the best window of a flat histogram), the bigger sizes weigh more
                -- (x0.5 .. x1.5); results move it from there
                if f >= 3 then
                    local sum = 0
                    for i = 1, n do h[i] = 0.5 + (i - 1) / (n - 1); sum = sum + h[i] end
                    for i = 1, n do h[i] = h[i] / sum end
                end
                if f < 3 then
                    for i = 1, n do h[i] = h[i] * 0.5 end
                    h[16] = h[16] + 0.5
                end
                return h
            end

            local function new_belief(from)
                local b = { s = {} }
                for f = 1, 4 do
                    b[f] = {}
                    local src = from and from[f] or prior(f)
                    for i = 1, #src do b[f][i] = src[i] end
                end
                for f = 1, 3 do
                    -- a new situation starts trusting the side model a little more: most desyncs are a side + a size, and the
                    -- computed model, when it agrees by chance on the first shots, used to take over and drift for 5-7 misses
                    b.s[f] = from and from.s[f] or (f == 3 and 1 or 0)
                end
                return b
            end

            local function belief_of(key, ctx)
                local m = memory_of(key)
                local b = m.b[ctx]
                if not b then
                    if not global[ctx] then global[ctx] = new_belief() end
                    b = new_belief(global[ctx])
                    m.b[ctx] = b
                end
                return b
            end

            local function weights(b)
                local top = math.max(b.s[1], b.s[2], b.s[3])
                local w, sum = {}, 0
                for f = 1, 3 do
                    w[f] = math.exp(b.s[f] - top)
                    sum = sum + w[f]
                end
                for f = 1, 3 do w[f] = w[f] / sum end
                return w
            end

            -- every angle the three models give a record whose computed body yaw is c, with its probability; pi = how likely
            -- the target is on the positive side (side model)
            local function components(b, c, pi, maxd)
                local w = weights(b)
                local ang, prob = {}, {}
                for i = 1, NB do
                    ang[#ang + 1], prob[#prob + 1] = clamp(c + A[i], -60, 60), w[1] * b[1][i]
                    ang[#ang + 1], prob[#prob + 1] = clamp(-c + A[i], -60, 60), w[2] * b[2][i]
                end
                local Mp, Mn = b[3], b[4]
                for j = 1, NM do
                    local size = (j - 1) * STEP
                    ang[#ang + 1], prob[#prob + 1] = size, w[3] * Mp[j] * pi
                    ang[#ang + 1], prob[#prob + 1] = -size, w[3] * Mn[j] * (1 - pi)
                end
                return ang, prob
            end

            -- the angle most likely to hit (the most probability within TOL); ties: the one nearest to the computed body yaw
            local function decide(b, c, pi, maxd, nozero)
                local ang, prob = components(b, c, pi, maxd)
                local best, best_p = 0, -1
                local function try(a)
                    a = clamp(a, -60, 60)
                    if nozero and math.abs(a) < ZERO_MIN then return end
                    local p = 0
                    for i = 1, #ang do
                        if math.abs(ang[i] - a) <= TOL then p = p + prob[i] end
                    end
                    p = p - math.abs(a - c) * 1e-6
                    if p > best_p then best, best_p = a, p end
                end
                try(c)
                try(-c)
                for i = 1, NB do try(A[i]) end
                if best_p < 0 and nozero then return decide(b, c, pi, maxd, false) end
                return math.floor(best + 0.5), best_p
            end

            -- how likely a result is with the size model if the target was on the positive / negative side
            local function side_likelihoods(b, v, hit, ph)
                local lp, lm = 0, 0
                for j = 1, NM do
                    local size = (j - 1) * STEP
                    lp = lp + b[3][j] * likelihood(size, v, hit, ph)
                    lm = lm + b[4][j] * likelihood(-size, v, hit, ph)
                end
                return lp, lm
            end

            -- one shot result: the record got v, its computed body yaw was c, the target was on the positive side with
            -- probability pi. temper < 1 for the beliefs of everybody
            local function update(b, c, v, hit, pi, temper)
                for f = 1, 2 do
                    local h = b[f]
                    local pred, sum = 0, 0
                    for i = 1, #h do
                        local l = likelihood(clamp((f == 1 and c or -c) + A[i], -60, 60), v, hit)
                        pred = pred + h[i] * l
                        h[i] = h[i] * (temper == 1 and l or l ^ temper)
                        sum = sum + h[i]
                    end
                    local p0 = prior(f)
                    for i = 1, #h do h[i] = (1 - FORGET) * h[i] / sum + FORGET * p0[i] end
                    b.s[f] = DECAY * b.s[f] + temper * math.log(math.max(pred, 1e-6))
                end
                -- side model: which side the result was on (posterior), and each side's size learns as much as it was that side
                -- (a miss with a 50 / 50 side says little about either size; with one size for both, it used to eat the size)
                local lp, lm = side_likelihoods(b, v, hit)
                local pred = pi * lp + (1 - pi) * lm
                local post = pi * lp / math.max(pred, 1e-9)
                for f = 3, 4 do
                    -- what a result says about one side's size also counts (less) for the other side, mirrored: most
                    -- desyncs are symmetric, and an uneven one still separates on its own results
                    local sign = f == 3 and 1 or -1
                    local own = temper * (f == 3 and post or (1 - post))
                    local other = temper * 0.3 * (f == 3 and (1 - post) or post)
                    local h, sum = b[f], 0
                    for j = 1, NM do
                        local size = sign * (j - 1) * STEP
                        local l1, l2 = likelihood(size, v, hit), likelihood(size, -v, hit)
                        h[j] = h[j] * (l1 ^ own) * (l2 ^ other)
                        sum = sum + h[j]
                    end
                    local p0 = prior(3)
                    for j = 1, NM do h[j] = (1 - FORGET) * h[j] / sum + FORGET * p0[j] end
                end
                b.s[3] = DECAY * b.s[3] + temper * math.log(math.max(pred, 1e-6))
            end

            -- ── side switches ──────────────────────────────────────────────────────
            -- Some targets switch the side of their body yaw: after a hit, after a miss, on every shot, or at random moments.
            -- z = what the resolver knows about the side in a situation: 1 = surely positive, -1 = surely negative, 0 = no idea.
            -- Every shot the target sees can flip it, with the probability learned on this player after a hit / after a miss,
            -- and some per tick. When the answer to a shot shows in the records (the target's ping, choke, own delay) is
            -- learned too: every delay of DELAYS keeps its own z and numbers, and the one that predicted the results best is
            -- used. A result is a measurement of the side on its record (Bayes), carried to now through the flips since.
            -- when the answer shows, two ways: ticks after our shot (a target that reacts to the bullet itself), or ticks after
            -- the result reached us (a target that reacts to the hit / miss: it gets the result about when we do, so this
            -- delay does not grow with the ping, and the result is known when the flip is applied)
            local DELAYS = {}
            for _, d in ipairs({ 1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 27, 30, 34 }) do DELAYS[#DELAYS + 1] = { fire = d } end
            for _, d in ipairs({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 17, 20 }) do DELAYS[#DELAYS + 1] = { res = d } end
            local ND = #DELAYS

            -- the tick the answer to shot ev is due under delay k (nil: its result has not arrived yet)
            local function due(ev, k)
                local D = DELAYS[k]
                if D.fire then return ev.fire + D.fire end
                return ev.res and ev.res + D.res or nil
            end

            local function new_rates(from, w)
                local F = {}
                for k = 1, ND do
                    local g = from and from[k]
                    F[k] = { score = g and g.score * w or 0, nh = g and g.nh * w or 0, fh = g and g.fh * w or 0,
                             nm = g and g.nm * w or 0, fm = g and g.fm * w or 0, ticks = g and g.ticks * w or 0, ft = g and g.ft * w or 0 }
                end
                return F
            end
            local grates = new_rates()

            local function rates_of(key)
                local m = memory_of(key)
                if not m.rates then m.rates = new_rates(grates, 0.3) end
                return m.rates
            end

            local function best_delay(F)
                local best, bs = 1, -math.huge
                for k = 1, ND do
                    if F[k].score > bs then best, bs = k, F[k].score end
                end
                return best
            end

            local function q_of(R, kind, phit)
                local qh, qm = (R.fh + 0.5) / (R.nh + 2.5), (R.fm + 0.5) / (R.nm + 2.5)
                if kind == "hit" then return qh end
                if kind == "miss" then return qm end
                return phit * qh + (1 - phit) * qm
            end

            local function per_tick(R)
                return (R.ft + 0.5) / (R.ticks + 3000)
            end

            local function z_of(p, ctx)
                local z = p.z[ctx]
                if not z then
                    z = {}
                    for k = 1, ND do z[k] = 0 end
                    p.z[ctx] = z
                end
                return z
            end

            -- brings every z of the player to tick t: the time that passed, the shots whose answer is due
            local function side_advance(p, t)
                local F = rates_of(p.key)
                local dt = p.z_t and math.max(t - p.z_t, 0) or 0
                p.z_t = t
                for k = 1, ND do
                    local R = F[k]
                    local keep = (1 - 2 * per_tick(R)) ^ dt
                    for _, z in pairs(p.z) do z[k] = z[k] * keep end
                    for i = 1, #p.events do
                        local ev = p.events[i]
                        local at = not ev.q[k] and due(ev, k)
                        if at and at <= t then
                            local q = q_of(R, ev.kind, ev.phit)
                            ev.q[k], ev.at[k] = q, at
                            for _, z in pairs(p.z) do z[k] = z[k] * (1 - 2 * q) end
                        end
                    end
                end
            end

            -- the result of a shot is known: where its answer was taken with a guess, the guess is replaced (flips commute)
            local function side_result(p, ev, kind)
                ev.kind, ev.res = kind, globals.tickcount()
                local F = rates_of(p.key)
                for k = 1, ND do
                    local old = ev.q[k]
                    if old then
                        local q = q_of(F[k], kind)
                        local a = 1 - 2 * old
                        if math.abs(a) > 0.05 then
                            for _, z in pairs(p.z) do z[k] = clamp(z[k] * (1 - 2 * q) / a, -1, 1) end
                        end
                        ev.q[k] = q
                    end
                end
            end

            -- a shot result on the record of tick t in situation ctx: lp / lm = how likely it is if the target was on the
            -- positive / negative side; zs = the z of every delay on that record
            local function side_measure(p, ctx, t, zs, lp, lm)
                local F = rates_of(p.key)
                local z = z_of(p, ctx)
                local last = p.obs[ctx]
                -- the side this result shows on its own (not what was believed before): for counting the flips
                local side = (lp >= 3 * lm and 1) or (lm >= 3 * lp and -1) or nil
                for k = 1, ND do
                    local R, G = F[k], grates[k]
                    local pr = (1 + zs[k]) / 2
                    local pred = math.max(pr * lp + (1 - pr) * lm, 1e-4)
                    R.score = R.score * RDECAY + math.log(pred)
                    G.score = G.score * 0.99 + 0.3 * math.log(pred)

                    -- learn the flip rates: two sides in a row with the answer to one shot between them (a flip after a hit /
                    -- after a miss), or with nothing between them (a flip per tick)
                    if side and last and t > last.t then
                        local only, n = nil, 0
                        for i = 1, #p.events do
                            local at = p.events[i].at[k]
                            if at and at > last.t and at <= t then only, n = p.events[i], n + 1 end
                        end
                        local flip = side ~= last.side and 1 or 0
                        if n == 1 and only.kind then
                            local f = only.kind == "hit" and "h" or "m"
                            R["n" .. f], R["f" .. f] = R["n" .. f] + 1, R["f" .. f] + flip
                            G["n" .. f], G["f" .. f] = G["n" .. f] + 0.3, G["f" .. f] + 0.3 * flip
                        elseif n == 0 then
                            R.ticks, R.ft = R.ticks + (t - last.t), R.ft + flip
                            G.ticks, G.ft = G.ticks + 0.3 * (t - last.t), G.ft + 0.3 * flip
                        end
                    end

                    -- the measurement, carried from its record to now through the flips since
                    local keep = (1 - 2 * per_tick(R)) ^ math.max((p.z_t or t) - t, 0)
                    for i = 1, #p.events do
                        local ev = p.events[i]
                        if ev.at[k] and ev.at[k] > t then keep = keep * (1 - 2 * ev.q[k]) end
                    end
                    local q = (1 - keep) / 2
                    local np, nm = (1 - q) * lp + q * lm, (1 - q) * lm + q * lp
                    local cur = (1 + z[k]) / 2
                    z[k] = clamp(2 * cur * np / math.max(cur * np + (1 - cur) * nm, 1e-9) - 1, -1, 1)
                end
                if side and (not last or t > last.t) then p.obs[ctx] = { t = t, side = side } end
            end

            -- ── feet model ─────────────────────────────────────────────────────────
            -- Standing, the feet turn to the lower body yaw target (100 deg/s); moving, they follow the eye yaw (30-50 deg/s).
            -- They are never further than the max body yaw away from the eye yaw. Eye yaw minus feet = body yaw of the record.
            local function feet_update(p, eye, lby, t)
                local moving = p.speed > 5 or p.stance == "air"
                local target = moving and eye or lby
                if target == nil then p.model = nil; return end
                if p.feet == nil or p.feet_t == nil or t < p.feet_t then p.feet, p.feet_t = target, t end
                local dt = clamp((t - p.feet_t) * globals.tickinterval(), 0, 0.25)
                p.feet_t = t
                local rate = moving and (30 + 20 * clamp((p.speed - 70) / 65, 0, 1)) or 100
                p.feet = approach(target, p.feet, rate * dt)
                local d = normalize(eye - p.feet)
                if d > p.maxd then
                    p.feet = normalize(eye - p.maxd)
                elseif d < -p.maxd then
                    p.feet = normalize(eye + p.maxd)
                end
                p.model = normalize(eye - p.feet)
            end

            -- ── jitter: the eye yaw (relative to us) keeps switching between two sides ─────
            local function jitter_of(p)
                local r = p.records
                local n = math.min(#r, WINDOW)
                if n < 5 then p.jitter, p.side = false, 0; return end
                local newest = r[#r]
                local v, lo, hi = {}, math.huge, -math.huge
                for i = 1, n do
                    local x = newest + normalize(r[#r - n + i] - newest)
                    v[i] = x
                    if x < lo then lo = x end
                    if x > hi then hi = x end
                end
                local spread, mid = hi - lo, (hi + lo) / 2
                local flips, last = 0, 0
                for i = 1, n do
                    local d = v[i] - mid
                    local s = d > spread * 0.15 and 1 or (d < -spread * 0.15 and -1 or 0)
                    if s ~= 0 and last ~= 0 and s ~= last then flips = flips + 1 end
                    if s ~= 0 then last = s end
                end
                -- the yaw spread that makes a target a jitterer (it stays one down to 2/3 of it); fixed, the owners want the
                -- resolver to need nothing but its switch
                p.jitter = spread >= (p.jitter and JITTER_SPREAD * 2 / 3 or JITTER_SPREAD) and flips >= 2
                p.side = p.jitter and last or 0
            end

            -- ── players and records ────────────────────────────────────────────────
            local function new_player(key)
                return { key = key, records = {}, hist = {}, events = {}, z = {}, obs = {}, lc_state = "ok", lc_dist = 0, choke = 0, jitter = false, side = 0, speed = 0,
                         maxd = MAX_DESYNC, stance = "stand", consecutive_misses = 0, key_tick = -1000 }
            end

            local function player_of(idx, tick)
                local p = players[idx]
                -- the steam id is looked up for a new slot and then every 64 ticks: a player who took over the slot of one
                -- who left is a new player, not the old one's memory
                if p and tick >= p.key_tick and tick - p.key_tick < 64 then return p end
                local key = key_of(idx)
                if not p or p.key ~= key then
                    p = new_player(key)
                    players[idx] = p
                    memory_of(key)
                end
                p.key_tick = tick
                return p
            end

            -- reads a new network update of the enemy: "record", "defensive" (tickbase shift) or nil (nothing new)
            local function ingest(idx, p, me)
                local sim = entity.get_prop(idx, "m_flSimulationTime")
                if not finite(sim) or sim <= 0 then return nil end
                local st = math.floor(sim / globals.tickinterval() + 0.5)
                if p.last_st == st then return nil end
                p.last_st = st
                -- every update is one packet of the target (also a shifted one): the clock of the body side patterns. With
                -- a steady choke (the last 8 updates the same number of ticks apart) a gap of 2-4 of those steps = updates we
                -- did not get (loss), they count too, or the cycle would slip by one
                local step = 1
                if p.max_st and st > p.max_st then
                    local dst = st - p.max_st
                    local hist = p.dst_hist or {}
                    p.dst_hist = hist
                    local m, steady = hist[1], #hist >= 8
                    for i = 2, #hist do if hist[i] ~= m then steady = false end end
                    if steady and m and m > 0 and dst % m == 0 and dst / m >= 2 and dst / m <= 4 then
                        -- the shifted updates in between were counted already
                        step = math.max(1, dst / m - (p.shifts_since or 0))
                    elseif (p.shifts_since or 0) == 0 then
                        hist[#hist + 1] = dst
                        while #hist > 8 do table.remove(hist, 1) end
                    end
                    p.shifts_since = 0
                else
                    p.shifts_since = (p.shifts_since or 0) + 1
                end
                p.rec_n = (p.rec_n or 0) + step
                -- a jump back by more than a tickbase shift (map change, reconnect) or a long gap: start over
                if p.max_st and (st < p.max_st - 32 or st - p.max_st > GAP_RESET) then
                    p.records, p.hist, p.max_st, p.feet, p.feet_t, p.jitter, p.side = {}, {}, nil, nil, nil, false, 0
                end
                local _, eye = entity.get_prop(idx, "m_angEyeAngles")
                if not finite(eye) then return nil end
                local lby = entity.get_prop(idx, "m_flLowerBodyYawTarget")
                lby = finite(lby) and lby or nil
                -- the feet logic's clock is the tick the update arrived: a shifted update's sim time says nothing about how
                -- long the server animated
                local now = globals.tickcount()

                -- sim time that does not move forward: a tickbase shift (defensive). Its angles say nothing about the real AA
                -- (they stay out of the jitter detection) and the server keeps no lag record of it, but it animates them.
                -- The shifted packet carries ticks the server animates at once: no "can not desync" from no choke
                if p.max_st and st <= p.max_st then
                    feet_update(p, eye, lby, now)
                    p.lc_state, p.lc_tick, p.lc_rec, p.shifting, p.nochoke, p.shift_st = "shifting", now, true, true, 0, st
                    return "defensive"
                end
                if p.lc_tick and now - p.lc_tick > 64 then p.lc_state = "ok" end

                local ox, oy, oz = entity.get_prop(idx, "m_vecOrigin")
                local mx, my = entity.get_prop(me, "m_vecOrigin")
                if not (finite(ox) and finite(oy) and finite(mx) and finite(my)) then return nil end
                -- lag compensation: more than 64 units between two records = the old records are gone on the server (teleport),
                -- the aimbot can only shoot the newest one, extrapolated; misses on it are about the position, not the angle
                p.choke = p.max_st and clamp(st - p.max_st - 1, 0, 64) or 0
                p.nochoke = p.choke == 0 and (p.nochoke or 0) + 1 or 0     -- updates in a row without a choked tick
                p.lc_rec, p.shifting = false, false
                oz = finite(oz) and oz or 0
                if p.last_o and p.max_st and st - p.max_st <= 32 then
                    local dx, dy, dz = ox - p.last_o[1], oy - p.last_o[2], oz - p.last_o[3]
                    p.lc_dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if p.lc_dist > 64 then p.lc_state, p.lc_tick, p.lc_rec = "breaking", now, true end
                end
                p.last_o = { ox, oy, oz }
                p.max_st, p.st = st, st
                local vx, vy = entity.get_prop(idx, "m_vecVelocity")
                p.speed = (finite(vx) and finite(vy)) and clamp(math.sqrt(vx * vx + vy * vy), 0, 320) or 0
                local flags = entity.get_prop(idx, "m_fFlags")
                if not finite(flags) then flags = 1 end
                p.stance = bit.band(flags, 1) == 0 and "air" or (p.speed > 5 and "move" or "stand")
                p.lcls = layer_class(p, idx)
                p.fcls_now = fs_class(p, idx, globals.tickcount())
                -- the server's max desync gets smaller when the player runs, and more when it runs crouched
                local ratio = 1 - 0.35 * clamp(p.speed / 250, 0, 1)
                local duck = entity.get_prop(idx, "m_flDuckAmount")
                if finite(duck) and duck > 0 then
                    ratio = ratio + clamp(duck, 0, 1) * clamp(p.speed / 85, 0, 1) * (0.5 - ratio)
                end
                p.maxd = MAX_DESYNC * ratio
                feet_update(p, eye, lby, now)

                p.records[#p.records + 1] = normalize(eye - math.deg(math.atan2(my - oy, mx - ox)) - 180)
                while #p.records > WINDOW do table.remove(p.records, 1) end
                jitter_of(p)
                return "record"
            end

            -- the situation a record is learned in
            local function situation(p)
                if p.jitter then return p.side > 0 and "j+" or "j-" end
                return p.stance
            end

            -- ticks of records kept (HIST_TIME): a shot at any of them is judged by what it got
            local function hist_ticks()
                return math.ceil(HIST_TIME / globals.tickinterval())
            end

            -- what was given to the record a shot went at: `bt` ticks behind the newest one. The records are sorted by sim
            -- tick (shifted updates are none): the newest one at or before the target, like the server takes it for a target
            -- time between two records and for the sim time of a shifted model (a shift goes back 2-14+ ticks)
            local function applied_for(p, bt)
                local h = p.hist
                if #h == 0 or not p.max_st then return nil end
                local target = p.max_st - math.max(bt, 0)
                for i = #h, 1, -1 do
                    if h[i].st <= target then return h[i] end
                end
                return nil
            end

            -- ── player list ────────────────────────────────────────────────────────
            local function unforce(idx)
                local s = saved[idx]
                if not s then return end
                pcall(plist.set, idx, "Force body yaw", false)
                if s.ok and s.correction ~= nil then pcall(plist.set, idx, "Correction active", s.correction) end
                saved[idx], forced[idx] = nil, nil
            end

            -- the switches are written when we take a player over and every 64 ticks after (in case something else turned
            -- them off), the value only when it changes
            local function force(idx, value)
                local s = saved[idx]
                local tick = globals.tickcount()
                if not s then
                    local ok, cur = pcall(plist.get, idx, "Correction active")
                    s = { ok = ok, correction = cur }
                    saved[idx] = s
                end
                if not s.tick or tick < s.tick or tick - s.tick >= 64 then
                    s.tick = tick
                    pcall(plist.set, idx, "Correction active", true)
                    pcall(plist.set, idx, "Force body yaw", true)
                    forced[idx] = nil
                end
                if forced[idx] ~= value then
                    pcall(plist.set, idx, "Force body yaw value", value)
                    forced[idx] = value
                end
            end

            local function release_all()
                for idx in pairs(saved) do unforce(idx) end
            end
            resolver.release_all = release_all
            resolver.release = unforce

            -- ── ping scale ─────────────────────────────────────────────────────────
            -- the resolver numbers that work best per ping (0 .. 150 ms in steps of 5), found in the simulation
            -- (a ping sweep: every row beat the defaults on its ping). "Auto" reads our real ping (real_ping: the fake
            -- ping of the ping spike / extended backtrack left out, the results and the enemies' answers come with the
            -- real one; the scoreboard ping with a 200 ms spike put every player on the 150 ms row), "Manual" the
            -- slider. Re-checked every 32 ticks, a row changes only when the ping is 1+ ms into the next step
            local PING_TABLE = {
                [0] = { forget = 0.0200, decay = 0.950, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [5] = { forget = 0.0200, decay = 0.951, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [10] = { forget = 0.0200, decay = 0.951, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [15] = { forget = 0.0200, decay = 0.952, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [20] = { forget = 0.0200, decay = 0.953, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [25] = { forget = 0.0200, decay = 0.953, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [30] = { forget = 0.0200, decay = 0.954, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [35] = { forget = 0.0200, decay = 0.955, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [40] = { forget = 0.0200, decay = 0.955, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [45] = { forget = 0.0200, decay = 0.956, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [50] = { forget = 0.0200, decay = 0.957, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [55] = { forget = 0.0174, decay = 0.957, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [60] = { forget = 0.0152, decay = 0.958, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [65] = { forget = 0.0132, decay = 0.959, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [70] = { forget = 0.0115, decay = 0.959, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [75] = { forget = 0.0100, decay = 0.960, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [80] = { forget = 0.0087, decay = 0.961, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [85] = { forget = 0.0076, decay = 0.961, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [90] = { forget = 0.0066, decay = 0.962, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [95] = { forget = 0.0057, decay = 0.963, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [100] = { forget = 0.0050, decay = 0.963, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [105] = { forget = 0.0050, decay = 0.964, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [110] = { forget = 0.0050, decay = 0.965, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [115] = { forget = 0.0050, decay = 0.965, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [120] = { forget = 0.0050, decay = 0.966, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [125] = { forget = 0.0050, decay = 0.967, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [130] = { forget = 0.0050, decay = 0.967, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [135] = { forget = 0.0050, decay = 0.968, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [140] = { forget = 0.0050, decay = 0.969, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [145] = { forget = 0.0050, decay = 0.969, p_hit = 0.85, rdecay = 0.97, tol = 12 },
                [150] = { forget = 0.0050, decay = 0.970, p_hit = 0.85, rdecay = 0.97, tol = 12 },
            }
            local ping_state = { tick = -100, bucket = nil, ping = 0 }
            resolver.ping_state = ping_state
            local function ping_update(tick)
                if tick - ping_state.tick < 32 and tick >= ping_state.tick then return end
                ping_state.tick = tick
                if option("ping_scale", true) ~= true or next(PING_TABLE) == nil then
                    if ping_state.bucket ~= nil then ping_state.bucket = nil; resolver.set_tune(nil) end
                    return
                end
                local ping
                if option("ping_mode", "Auto") == "Manual" then
                    ping = tonumber(option("ping_manual", 50)) or 50
                else
                    ping = real_ping()
                    -- smoothed: one lag spike does not switch the row
                    ping = ping_state.ping + (ping - ping_state.ping) * (ping_state.bucket and 0.35 or 1)
                end
                ping = clamp(ping, 0, 150)
                ping_state.ping = ping
                local bucket = math.floor(ping / 5 + 0.5) * 5
                if ping_state.bucket and math.abs(ping - ping_state.bucket) < 3.5 then bucket = ping_state.bucket end
                if bucket ~= ping_state.bucket then
                    ping_state.bucket = bucket
                    resolver.set_tune(PING_TABLE[bucket])
                end
            end

            resolver.net_update = function()
                local me = entity.get_local_player()
                if not me or not enabled() then
                    if next(saved) then release_all() end
                    return
                end
                local tick = globals.tickcount()
                ping_update(tick)
                eye_record(tick)
                local seen = {}
                for _, idx in ipairs(entity.get_players(true)) do
                    if entity.is_alive(idx) and not entity.is_dormant(idx) then
                        seen[idx] = true
                        local p = player_of(idx, tick)
                        local kind = ingest(idx, p, me)
                        if kind == "defensive" then
                            -- no record: the forced value stays the one of the newest normal record, the one the server
                            -- tests a shot at the shifted model against
                            p.method = p.method and (p.method:gsub(" / defensive$", "") .. " / defensive") or "Defensive"
                        elseif kind then
                            local ctx = situation(p)
                            local c = p.model or 0
                            side_advance(p, tick)
                            local z = z_of(p, ctx)
                            local zs = {}
                            for k = 1, ND do zs[k] = z[k] end
                            local b = belief_of(p.key, ctx)
                            local pi = (1 + zs[best_delay(rates_of(p.key))]) / 2
                            local pi_base, n = pi, p.rec_n
                            local pp, period, pgain = pat_predict(p.key, n)
                            local lcls, fcls = p.lcls, p.fcls_now
                            local lp_, lgain = feat_predict(p.key, "lay", lcls)
                            local fp_, fgain = feat_predict(p.key, "fs", fcls)
                            -- nothing proven on this player yet: what the other players showed
                            if not lp_ then lp_, lgain = gfeat_predict("lay", lcls) end
                            if not fp_ then fp_, fgain = gfeat_predict("fs", fcls) end
                            p.layers_used, p.fs_used = nil, nil
                            local best_gain = pp and pgain or 0
                            if pp then pi = pp end
                            if lp_ and lgain > best_gain then pi, period, p.layers_used, best_gain = lp_, nil, true, lgain end
                            if fp_ and fgain > best_gain then pi, period, p.layers_used, p.fs_used = fp_, nil, nil, true end
                            local value, phit = decide(b, c, pi, p.maxd, math.abs(c) < ZERO_MIN and not zero_allowed(p.key, ctx, p))
                            local w = weights(b)
                            local model = (w[1] >= w[2] and w[1] >= w[3]) and "computed" or (w[2] >= w[3] and "mirrored" or "side")
                            p.mode, p.value, p.ctx, p.phit, p.model_name = p.jitter and "j" or "d", value, ctx, phit, model
                            p.method = p.jitter and "Jitter" or (model ~= "side" and (p.stance == "stand" and "LBY" or "Dynamic") or "Static")
                            if period then p.method = p.method .. " / cycle " .. period end
                            if p.layers_used then p.method = p.method .. " / layers" end
                            if p.fs_used then p.method = p.method .. " / hide head" end
                            -- remember what this record got: a shot at it later (backtrack) is judged by this. Kept for
                            -- HIST_TIME (a fixed count covered 64 ticks only without choke on 64 tick)
                            local h = p.hist
                            h[#h + 1] = { st = p.st, value = value, c = c, ctx = ctx, stance = p.stance, at = tick, phit = phit, zs = zs,
                                          n = n, pi_base = pi_base, lcls = lcls, fcls = fcls, mode = p.mode, lc = p.lc_rec, o = p.last_o }
                            local oldest = p.st - hist_ticks()
                            while #h > 1 and h[1].st < oldest do table.remove(h, 1) end
                            force(idx, value)
                        end
                    end
                end
                -- dead, dormant or gone (get_players does not list them): give them back to the native resolver
                for idx in pairs(saved) do
                    if not seen[idx] then unforce(idx) end
                end
            end

            -- ── shots ──────────────────────────────────────────────────────────────
            local function shot_id(e)
                return e.id or ("t" .. tostring(e.target))
            end

            -- how many ticks back the shot went. gamesense's "backtrack" of aim_fire says 0 with fake ping (extended
            -- backtrack): it counts from the oldest record the fake latency allows, not from the newest. So it is measured:
            -- the aim point minus where that hitbox sits on the newest record (the same offset on every record) gives the
            -- origin of the record the aimbot used; the stored record with the nearest origin is it. Only when the target
            -- moved enough between records to tell them apart; otherwise gamesense's number
            local HITBOX_OF = { [1] = 0, [2] = 5, [3] = 3, [4] = 17, [5] = 15, [6] = 8, [7] = 7, [8] = 1 }
            -- the record the aim point belongs to (ticks back), nil when the position can not tell
            local function measured_backtrack(p, idx, event)
                local ax, ay, az = tonumber(event.x), tonumber(event.y), tonumber(event.z)
                if not (#p.hist > 1 and finite(ax) and finite(ay) and finite(az)) then return nil end
                local newest
                for i = #p.hist, 1, -1 do
                    if p.hist[i].o and p.hist[i].st == p.max_st then newest = p.hist[i]; break end
                end
                if not newest then return nil end
                -- hitbox and origin of the drawn (interpolated) model: their difference is the hitbox offset
                local hx, hy, hz = entity.hitbox_position(idx, HITBOX_OF[tonumber(event.hitgroup) or 1] or 0)
                local ox, oy, oz = entity.get_origin(idx)
                if not (finite(hx) and finite(hy) and finite(hz) and finite(ox) and finite(oy) and finite(oz)) then return nil end
                -- the origin the aim point belongs to
                local tx, ty = ax - (hx - ox), ay - (hy - oy)
                local best, bd, d2 = nil, math.huge, math.huge
                for i = #p.hist, 1, -1 do
                    local h = p.hist[i]
                    if h.o and p.max_st - h.st >= 0 and p.max_st - h.st <= hist_ticks() then
                        local d = (h.o[1] - tx) ^ 2 + (h.o[2] - ty) ^ 2
                        if d < bd then best, bd, d2 = h, d, bd elseif d < d2 then d2 = d end
                    end
                end
                if not best then return nil end
                local no, bo = newest.o, best.o
                -- the records have to be apart (more than the multipoint error), the aim point near the chosen one and
                -- clearly nearer to it than to any other (where the target turns, the records lie on each other)
                if (no[1] - bo[1]) ^ 2 + (no[2] - bo[2]) ^ 2 < 5 * 5 or bd > 10 * 10 then return nil end
                if math.sqrt(d2) - math.sqrt(bd) < 2 then return nil end
                return p.max_st - best.st
            end

            -- A target that stands still: the position can not tell the record. Then what the shots it could tell say:
            -- with a ping spike gamesense counts its number from another record than the newest (owners: "bt 0t" on
            -- backtracked shots), and the shot's tick (aim_fire `tick`) may be its record's tick + the interpolation.
            -- Each is used once its last 8 measured shots agree (all but one within 1 tick), else gamesense's number
            local cal = { tick = {}, native = {} }
            local function cal_push(list, v)
                list[#list + 1] = v
                while #list > 8 do table.remove(list, 1) end
            end
            local function cal_get(list)
                if #list < 8 then return nil end
                local sorted = {}
                for i = 1, #list do sorted[i] = list[i] end
                table.sort(sorted)
                local mid, agree = sorted[4], 0
                for i = 1, #list do if math.abs(list[i] - mid) <= 1 then agree = agree + 1 end end
                return agree >= #list - 1 and mid or nil
            end

            -- -> ticks back (what the log shows, the record the shot is judged by), gamesense's / the measured number
            -- before the standing target estimate (a shot at the drawn shifted model is 0 there)
            resolver.shot_backtrack = function(event)
                if type(event) ~= "table" then return 0, 0 end
                local native = math.max(0, tonumber(event.backtrack) or 0)
                local idx = event.target
                local p = idx and players[idx]
                if not (p and p.max_st and #p.hist > 0) then return native, native end
                local tk = tonumber(event.tick)
                if not finite(tk) then tk = nil end
                local m = measured_backtrack(p, idx, event)
                if m then
                    -- not while it shifts: the drawn model is the shifted one
                    if not p.shifting then
                        if tk then cal_push(cal.tick, tk - (p.max_st - m)) end
                        cal_push(cal.native, m - native)
                    end
                    local bt = math.max(native, m)
                    return bt, bt
                end
                local off = cal_get(cal.tick)
                if off and tk then
                    for i = #p.hist, 1, -1 do
                        local h = p.hist[i]
                        if h.st <= tk - off then
                            if p.max_st - h.st <= hist_ticks() then return p.max_st - h.st, native end
                            break
                        end
                    end
                end
                off = cal_get(cal.native)
                if off then return clamp(native + off, 0, hist_ticks()), native end
                return native, native
            end

            resolver.on_fire = function(e)
                if type(e) ~= "table" or not e.target then return end
                local now = globals.realtime()
                for id, s in pairs(shots) do
                    if now - s.time > 5 or now < s.time then shots[id] = nil end
                end
                local p = players[e.target]
                local bt, raw = resolver.shot_backtrack(e)
                -- fired at the drawn model (0 ticks back) while the target's newest update is a shifted one: the server does
                -- not have it and tests the shot against the newest normal record at or before its sim time. That record's
                -- age is the backtrack of the shot, its value the angle (gamesense says 0 ticks)
                local defensive = p and p.shifting and raw == 0 and p.shift_st or nil
                if defensive then
                    for i = #p.hist, 1, -1 do
                        if p.hist[i].st <= p.shift_st then bt = p.max_st - p.hist[i].st; break end
                    end
                end
                local h = p and applied_for(p, bt)
                local shot = { idx = e.target, key = p and p.key, bt = bt, time = now, reason = "native", defensive = defensive and true or nil }
                if p then
                    -- the target sees this shot: its answer (a side switch?) shows in its records some ticks later
                    local ev = { fire = globals.tickcount(), phit = h and h.phit or 0.5, q = {}, at = {} }
                    p.events[#p.events + 1] = ev
                    while #p.events > 16 do table.remove(p.events, 1) end
                    shot.ev = ev
                end
                if h then
                    shot.value, shot.c, shot.ctx, shot.stance, shot.at, shot.zs, shot.mode = h.value, h.c, h.ctx, h.stance, h.at, h.zs, h.mode
                    shot.n, shot.pi_base, shot.lcls, shot.fcls = h.n, h.pi_base, h.lcls, h.fcls
                    shot.teleported = h.lc
                    shot.reason = shot.defensive and "defensive" or (h.ctx:sub(1, 1) == "j" and "jitter" or "desync")
                end
                shots[shot_id(e)] = shot
                if resolver.stats_hook then pcall(resolver.stats_hook, "fire", shot, e, p) end
            end

            local function learn(s, hit)
                local b = belief_of(s.key, s.ctx)
                local p = players[s.idx]
                local pi = 0.5
                if p and p.key == s.key then
                    -- the side the target was on when the record was made, and what this result says about it
                    local best = best_delay(rates_of(p.key))
                    pi = (1 + s.zs[best]) / 2
                    -- for the sizes: what is known about the side of the record NOW (with the results that came in after it was
                    -- decided). With the side guessed before a switch was seen, the misses after the switch used to eat the
                    -- size (48 -> 4-24 deg)
                    local zn = p.z[s.ctx] and p.z[s.ctx][best]
                    if zn then
                        -- carried back to the record through the switches expected since (a target that switches after a
                        -- hit is on the other side now than on the record): z now = z then x keep
                        local R = rates_of(p.key)[best]
                        local keep = (1 - 2 * per_tick(R)) ^ math.max((p.z_t or s.at) - s.at, 0)
                        for i = 1, #p.events do
                            local ev = p.events[i]
                            if ev.at[best] and ev.at[best] > s.at then keep = keep * (1 - 2 * ev.q[best]) end
                        end
                        pi = (1 + clamp(zn * keep, -1, 1)) / 2
                    end
                    local lp, lm = side_likelihoods(b, s.value, hit, reliability(s.key))
                    side_measure(p, s.ctx, s.at, s.zs, lp, lm)
                    local seen_side = (lp >= 3 * lm and 1) or (lm >= 3 * lp and -1) or nil
                    if seen_side and s.n and s.pi_base then pat_learn(s.key, s.n, seen_side, s.pi_base) end
                    if seen_side and s.lcls and s.pi_base then feat_learn(s.key, "lay", s.lcls, seen_side, s.pi_base) end
                    if seen_side and s.fcls and s.pi_base then feat_learn(s.key, "fs", s.fcls, seen_side, s.pi_base) end
                    -- the reliability: the misses since the last hit in this situation, judged by this hit's side
                    local sign = (s.value or 0) > 0 and 1 or ((s.value or 0) < 0 and -1 or 0)
                    local pend = p.pend_miss
                    if not pend then pend = {}; p.pend_miss = pend end
                    if hit then
                        local r = rel_of(s.key)
                        local noise = 0
                        local list = pend[s.ctx]
                        if list then
                            for _, m in ipairs(list) do
                                if sign ~= 0 and m.sign == sign and s.at - m.at <= 64 and s.at >= m.at then noise = noise + 1 end
                            end
                        end
                        rel_count(r, 1, noise, 1)
                        rel_count(grel, 1, noise, 0.3)
                        pend[s.ctx] = nil
                    elseif sign ~= 0 then
                        local list = pend[s.ctx] or {}
                        list[#list + 1] = { sign = sign, at = s.at }
                        while #list > 4 do table.remove(list, 1) end
                        pend[s.ctx] = list
                    end
                end
                -- a record that broke lag compensation was shot extrapolated: a resolver miss on it may also be the position
                -- (gamesense calls most of those "prediction error", they never get here), so it counts half
                local weight = (not hit and s.teleported) and 0.5 or 1
                if math.abs(s.c or 0) < ZERO_MIN then zero_result(s.key, s.ctx, s.value, hit) end
                update(b, s.c, s.value, hit, pi, weight)
                if not global[s.ctx] then global[s.ctx] = new_belief() end
                update(global[s.ctx], s.c, s.value, hit, pi, 0.3)
            end

            resolver.on_hit = function(e)
                if type(e) ~= "table" then return end
                local id = shot_id(e)
                local s = shots[id]
                shots[id] = nil
                local p = players[e.target]
                if resolver.stats_hook then pcall(resolver.stats_hook, "hit", s, e, p) end
                if p then p.consecutive_misses = 0 end
                if s and s.ev and p and s.key == p.key then side_result(p, s.ev, "hit") end
                if not s or s.value == nil or not s.key then return end
                -- only a head hit says where the head was
                if e.hitgroup ~= 1 then return end
                learn(s, true)
                memory_of(s.key).hit_value[s.stance or "stand"] = s.value
                resolver.last_log = string.format("%s: hit head with %d (%s)", name_of(e.target), s.value, s.ctx)
            end

            resolver.on_miss = function(e)
                if type(e) ~= "table" then return end
                local id = shot_id(e)
                local s = shots[id]
                shots[id] = nil
                local p = players[e.target]
                if resolver.stats_hook then pcall(resolver.stats_hook, "miss", s, e, p) end
                -- the target saw the shot, whatever the reason of the miss
                if s and s.ev and p and s.key == p.key then side_result(p, s.ev, "miss") end
                -- spread, prediction error, death ... are not about the angle
                if e.reason ~= "?" and e.reason ~= "resolver" then return end
                -- nor a miss on a shifted model: the server tested it against an older record (lag comp)
                if s and s.defensive then return end
                if p then p.consecutive_misses = p.consecutive_misses + 1 end
                if not s or s.value == nil or not s.key then return end
                learn(s, false)
                resolver.last_log = string.format("%s: missed %d (%s)", name_of(e.target), s.value, s.ctx)
            end

            -- ── rounds / reset ─────────────────────────────────────────────────────
            resolver.new_round = function()
                release_all()
                players, shots = {}, {}
                publish()
            end

            resolver.reset_player = function(idx)
                unforce(idx)
                players[idx] = nil
            end

            resolver.reset_all = function()
                release_all()
                players, mem, shots, global, grates = {}, {}, {}, {}, new_rates()
                gfeat, eye_hist = {}, {}
                cal.tick, cal.native = {}, {}
                grel = { hit = 17, noise = 3 }
                publish()
            end

            do
                local last_err = -10
                client.set_event_callback("net_update_end", function()
                    local ok, err = pcall(resolver.net_update)
                    if not ok and globals.realtime() - last_err > 5 then
                        last_err = globals.realtime()
                        client.error_log("[specter resolver] " .. tostring(err))
                    end
                end)
                client.set_event_callback("shutdown", function() pcall(release_all) end)
            end
            -- [resolver:end]
        end
        end -- TIER.HAS_RESOLVER else

        -- The noise the presets mix into their jitter (micro jitter, delays, limits, sway). Deterministic noise per tick,
        -- not a security feature: what an enemy cannot learn is the body side (antiaimbot.body_side, a coin flip per packet).
        -- It was part of "Enhanced AA" (removed Oct 2026: its yaw formulas "Figure-8" / "Quantum" / "Chaos Theory" ... did not
        -- lower the red team's hit rate (0.47-0.50 against 0.48 without, Smooth Sine 0.57 in the air), the rest doubled the
        -- anti brute-force / defensive triggers / edge yaw, and the default config had it on)
        aa_noise = {} do
            local chaos_seed = 0.5
            -- logistic map (r ~ 4): chaotic, reseeded from the clock when it sticks to an edge
            aa_noise.chaos_rng = function()
                chaos_seed = 3.9999 * chaos_seed * (1 - chaos_seed)
                if chaos_seed < 0.001 or chaos_seed > 0.999 then
                    chaos_seed = (globals_curtime() % 1) * 0.8 + 0.1
                end
                return chaos_seed
            end

            local function perlin_noise(x)
                local i = math_floor(x)
                local f = x - i
                local u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0)
                local a = math.sin(i * 12.9898 + 78.233) * 43758.5453
                local b = math.sin((i + 1) * 12.9898 + 78.233) * 43758.5453
                a = a - math_floor(a)
                b = b - math_floor(b)
                return a * (1.0 - u) + b * u
            end

            aa_noise.fractal_noise = function(x, octaves, persistence)
                local total, amplitude, max_val, frequency = 0, 1.0, 0, 1.0
                for _ = 1, octaves do
                    total = total + perlin_noise(x * frequency) * amplitude
                    max_val = max_val + amplitude
                    amplitude = amplitude * persistence
                    frequency = frequency * 2.0
                end
                return total / max_val
            end

            local primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97}
            local prime_index = 1
            aa_noise.get_prime_offset = function()
                prime_index = (prime_index % #primes) + 1
                return primes[prime_index]
            end
        end
    end

    ---
    --- Constant section .data
    ---
    local c_constant do
        c_constant = {} do
            c_constant.STATE_LIST = { 'Standing', 'Slow-motion', 'Moving', 'Crouching', 'Crouch moving', 'Air', 'Air & Crouch' }
            c_constant.DEFENSIVE_STATES = { 'On peek', 'Legit AA', 'Edge direction', 'Safe head', 'Triggered' }

            c_constant.fonts = {} do
                c_constant.fonts.lucida = surface.create_font('Lucida Console', 10, 400, 128)
            end

            c_constant.antiaim_presets = {} do
                local LEGIT = {
                    pitch = "Off", yaw_base = "Local view", yaw_type = "Left & Right",
                    left_offset = 180, right_offset = 180,
                    yaw_modifier = "Off", modifier_offset = 0,
                    body_yaw_type = "Jitter", body_yaw_value = -1
                }

                -- left / right yaw, switched after a random d1 .. d2 packets
                local function delay_state(l, r, d1, d2)
                    return {
                        pitch = "Minimal", yaw_base = "At targets", yaw_type = "Left & Right",
                        left_offset = l, right_offset = r, yaw_delay = d1, yaw_delay_second = d2,
                        yaw_modifier = "Off", modifier_offset = 0,
                        body_yaw_type = "Jitter", body_yaw_value = -1
                    }
                end

                -- the packet-stepped jitters + the body side as a coin flip per sent packet
                local function jit_state(off, mod, width, rnd)
                    return {
                        pitch = "Minimal", yaw_base = "At targets", yaw_type = "180", yaw_offset = off,
                        yaw_modifier = mod, modifier_offset = width, modifier_randomize = rnd,
                        body_yaw_type = "Sync", body_yaw_value = 1
                    }
                end

                -- Delay: the yaw sits left or right and switches after a random 1-5 packets (an asymmetric delayed
                -- jitter), 3-way in the air
                c_constant.antiaim_presets["Specter Delay"] = {
                    ["Legit AA"]      = LEGIT,
                    ["Fake lag"]      = delay_state(-24, 36, 1, 3),
                    ["Standing"]      = delay_state(-22, 34, 2, 4),
                    ["Slow-motion"]   = delay_state(-18, 28, 2, 4),
                    ["Moving"]        = delay_state(-26, 38, 1, 3),
                    ["Crouching"]     = delay_state(-20, 32, 2, 5),
                    ["Crouch moving"] = delay_state(-24, 34, 1, 4),
                    ["Air"]           = jit_state(5, "3-Way", 48, 6),
                    ["Air & Crouch"]  = jit_state(4, "3-Way", 44, 6),
                }

                -- 3-Way: left / center / right per sent packet, 5-way (new random order every cycle) in the air
                c_constant.antiaim_presets["Specter 3-Way"] = {
                    ["Legit AA"]      = LEGIT,
                    ["Fake lag"]      = jit_state(3, "3-Way", 54, 4),
                    ["Standing"]      = jit_state(4, "3-Way", 58, 4),
                    ["Slow-motion"]   = jit_state(2, "3-Way", 46, 4),
                    ["Moving"]        = jit_state(4, "3-Way", 56, 5),
                    ["Crouching"]     = jit_state(3, "3-Way", 50, 4),
                    ["Crouch moving"] = jit_state(4, "3-Way", 52, 5),
                    ["Air"]           = jit_state(5, "5-Way", 48, 6),
                    ["Air & Crouch"]  = jit_state(4, "5-Way", 44, 6),
                }

                -- Distort: a smooth wandering yaw with rare snaps to the far side (no rhythm to time), 5-way in the air.
                -- The lowest best attacker in tests/aa_redteam.py
                c_constant.antiaim_presets["Specter Distort"] = {
                    ["Legit AA"]      = LEGIT,
                    ["Fake lag"]      = jit_state(2, "Distortion", 58, 0),
                    ["Standing"]      = jit_state(3, "Distortion", 64, 0),
                    ["Slow-motion"]   = jit_state(2, "Distortion", 50, 0),
                    ["Moving"]        = jit_state(4, "Distortion", 60, 0),
                    ["Crouching"]     = jit_state(3, "Distortion", 58, 0),
                    ["Crouch moving"] = jit_state(4, "Distortion", 54, 0),
                    ["Air"]           = jit_state(5, "5-Way", 48, 6),
                    ["Air & Crouch"]  = jit_state(4, "5-Way", 44, 6),
                }
            end

            c_constant.defensive_presets = {} do
                c_constant.defensive_presets["Auto"] = {
                    ["Safe head"] = {
                        ["pitch"] = "Up Switch",
                        ["pitch_custom"] = -15,
                        ["yaw"] = "Scissors",
                        ["yaw_left"] = -135,
                        ["yaw_right"] = 135,
                        ["yaw_delay"] = 2,
                        ["yaw_left_start"] = -90,
                        ["yaw_left_target"] = -170,
                        ["yaw_right_start"] = 90,
                        ["yaw_right_target"] = 170,
                        ["yaw_randomize"] = 15
                    },
                    ["Triggered"] = {
                        ["pitch"] = "Up Switch",
                        ["pitch_custom"] = 10,
                        ["yaw"] = "Spinbot",
                        ["yaw_from"] = -180,
                        ["yaw_to"] = 180,
                        ["yaw_speed"] = 35,
                        ["yaw_randomize"] = 25
                    },
                    ["Edge direction"] = {
                        ["enable_on"] = {"Freestanding", "Manual yaw"},
                        ["pitch"] = "Up Switch",
                        ["pitch_custom"] = -10,
                        ["yaw"] = "Scissors",
                        ["yaw_left"] = -60,
                        ["yaw_right"] = 60,
                        ["yaw_delay"] = 2,
                        ["yaw_from"] = -180,
                        ["yaw_to"] = 180,
                        ["yaw_speed"] = 30,
                        ["yaw_left_start"] = -45,
                        ["yaw_left_target"] = -135,
                        ["yaw_right_start"] = 45,
                        ["yaw_right_target"] = 135,
                        ["yaw_randomize"] = 20
                    },

                    ["Standing"] = {
                        ["pitch"] = "Flick up", ["pitch_custom"] = -60,
                        ["yaw"] = "Distortion", ["yaw_left"] = -120, ["yaw_right"] = 120,
                        ["yaw_delay"] = 2, ["yaw_speed"] = 10, ["yaw_randomize"] = 12,
                        ["yaw_from"] = -180, ["yaw_to"] = 180,
                        ["yaw_left_start"] = -60, ["yaw_left_target"] = -150, ["yaw_right_start"] = 60, ["yaw_right_target"] = 150
                    },
                    ["Slow-motion"] = {
                        ["pitch"] = "Half up", ["pitch_custom"] = -60,
                        ["yaw"] = "Sway", ["yaw_left"] = -100, ["yaw_right"] = 100,
                        ["yaw_delay"] = 2, ["yaw_speed"] = 14, ["yaw_randomize"] = 10,
                        ["yaw_from"] = -180, ["yaw_to"] = 180,
                        ["yaw_left_start"] = -60, ["yaw_left_target"] = -150, ["yaw_right_start"] = 60, ["yaw_right_target"] = 150
                    },
                    ["Moving"] = {
                        ["pitch"] = "Up Switch", ["pitch_custom"] = -60,
                        ["yaw"] = "Flick", ["yaw_left"] = -110, ["yaw_right"] = 110,
                        ["yaw_delay"] = 3, ["yaw_speed"] = 20, ["yaw_randomize"] = 15,
                        ["yaw_from"] = -180, ["yaw_to"] = 180,
                        ["yaw_left_start"] = -60, ["yaw_left_target"] = -150, ["yaw_right_start"] = 60, ["yaw_right_target"] = 150
                    },
                    ["Crouching"] = {
                        ["pitch"] = "Flick up", ["pitch_custom"] = -60,
                        ["yaw"] = "Random side", ["yaw_left"] = -120, ["yaw_right"] = 120,
                        ["yaw_delay"] = 2, ["yaw_speed"] = 20, ["yaw_randomize"] = 15,
                        ["yaw_from"] = -180, ["yaw_to"] = 180,
                        ["yaw_left_start"] = -60, ["yaw_left_target"] = -150, ["yaw_right_start"] = 60, ["yaw_right_target"] = 150
                    },
                    ["Crouch moving"] = {
                        ["pitch"] = "Up Switch", ["pitch_custom"] = -60,
                        ["yaw"] = "Flick", ["yaw_left"] = -100, ["yaw_right"] = 100,
                        ["yaw_delay"] = 2, ["yaw_speed"] = 20, ["yaw_randomize"] = 12,
                        ["yaw_from"] = -180, ["yaw_to"] = 180,
                        ["yaw_left_start"] = -60, ["yaw_left_target"] = -150, ["yaw_right_start"] = 60, ["yaw_right_target"] = 150
                    },
                    ["Air"] = {
                        ["pitch"] = "Sway", ["pitch_custom"] = -60,
                        ["yaw"] = "Distortion", ["yaw_left"] = -150, ["yaw_right"] = 150,
                        ["yaw_delay"] = 1, ["yaw_speed"] = 20, ["yaw_randomize"] = 20,
                        ["yaw_from"] = -180, ["yaw_to"] = 180,
                        ["yaw_left_start"] = -60, ["yaw_left_target"] = -150, ["yaw_right_start"] = 60, ["yaw_right_target"] = 150
                    },
                    ["Air & Crouch"] = {
                        ["pitch"] = "Flick up", ["pitch_custom"] = -60,
                        ["yaw"] = "Sway", ["yaw_left"] = -130, ["yaw_right"] = 130,
                        ["yaw_delay"] = 2, ["yaw_speed"] = 22, ["yaw_randomize"] = 15,
                        ["yaw_from"] = -180, ["yaw_to"] = 180,
                        ["yaw_left_start"] = -60, ["yaw_left_target"] = -150, ["yaw_right_start"] = 60, ["yaw_right_target"] = 150
                    },
                    ["On peek"] = {
                        ["pitch"] = "Flick up", ["pitch_custom"] = -60,
                        ["yaw"] = "Random side", ["yaw_left"] = -100, ["yaw_right"] = 100,
                        ["yaw_delay"] = 1, ["yaw_speed"] = 20, ["yaw_randomize"] = 20,
                        ["yaw_from"] = -180, ["yaw_to"] = 180,
                        ["yaw_left_start"] = -60, ["yaw_left_target"] = -150, ["yaw_right_start"] = 60, ["yaw_right_target"] = 150
                    }
                }
            end
        end
    end

    ---
    --- Color
    ---
    local color do
        local create_color, create_color_object, Color do
            Color = {} do
                function Color:clone()
                    return create_color_object(
                        self.r, self.g, self.b, self.a
                    )
                end

                function Color:to_hex()
                    return ('%02X%02X%02X%02X'):format(self.r, self.g, self.b, self.a)
                end

                function Color:as_hex(hex_value)
                    local r, g, b, a = hex_value:match('(%x%x)(%x%x)(%x%x)(%x%x)')

                    return create_color_object(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), tonumber(a, 16))
                end

                function Color:lerp(color_target, weight)
                    return create_color_object(
                        c_math.lerp(self.r, color_target.r, weight),
                        c_math.lerp(self.g, color_target.g, weight),
                        c_math.lerp(self.b, color_target.b, weight),
                        c_math.lerp(self.a, color_target.a, weight)
                    )
                end

                function Color:alpha_modulate(alpha, modulate)
                    return create_color_object(
                        self.r,
                        self.g,
                        self.b,
                        modulate and self.a*alpha or alpha
                    )
                end

                function Color:unpack()
                    return self.r, self.g, self.b, self.a
                end
            end

            function create_color_object(self, ...)
                local args = {...}

                if type(self) == 'number' then
                    table_insert(args, 1, self)
                end

                if type(args[1]) == 'table' then
                    if args[1][1] then
                        args = args[1]
                    else
                        args = {args[1].r, args[1].g, args[1].b, args[1].a}
                    end
                end

                if type(args[1]) == 'string' then
                    return setmetatable({
                        r = 255, g = 255, b = 255, a = 255
                    }, {
                        __index = Color
                    }):as_hex(args[1])
                end

                return setmetatable({
                    r = args[1] or 255,
                    g = args[2] or 255,
                    b = args[3] or 255,
                    a = args[4] or 255
                }, {
                    __index = Color
                })
            end

            local stock_colors = {} do
                stock_colors.raw_green = create_color_object(0, 255, 0);
                stock_colors.raw_red = create_color_object(255, 0, 0);

                stock_colors.red = create_color_object(255, 0, 50);
                stock_colors.white = create_color_object();
                stock_colors.gray = create_color_object(200, 200, 200);
                stock_colors.blue = create_color_object(95, 156, 204);
                stock_colors.pink = create_color_object(209, 101, 145);
                stock_colors.yellow = create_color_object(233, 213, 2);
                stock_colors.purplish = create_color_object(193, 144, 252);

                stock_colors.onshot = create_color_object(100, 148, 237, 255);
                stock_colors.freestanding = create_color_object(132, 195, 16, 255);
                stock_colors.edge = create_color_object(209, 159, 230, 255);
                stock_colors.fixik = create_color_object('00FFCBFF');

                stock_colors.string_to_color_array = (function (str)
                    local arr =  {}
                    local match, mend = str:find('\a')

                    if not match then
                        arr[#arr+1] = str
                    else
                        while match do
                            local prmatch = match
                            local prend = mend

                            match, mend = str:find('\a', match+1)

                            if match == nil then
                                arr[#arr+1] = str:sub(prend, #str)

                                break
                            else
                                arr[#arr+1] = str:sub(prmatch, match-1)
                            end
                        end
                    end

                    local cnt = 0
                    local out = {}

                    for i=1, #arr do
                        for hex_col, s in arr[i]:gmatch('\a(%x%x%x%x%x%x%x%x)(.+)') do
                            out[#out+1] = {
                                color = create_color(hex_col),
                                text = s
                            };

                            cnt = cnt + 1
                        end
                    end

                    if cnt == 0 then
                        out[#out+1] = {
                            color = create_color('FFFFFFFF'),
                            text = str
                        }
                    end

                    return out
                end)

                stock_colors.animated_text = (function (text, speed, color_start, color_end, alpha)
                    local first = color_start and create_color(color_start.r, color_start.g, color_start.b, alpha) or create_color(255, 200, 255, alpha)
                    local second = color_end and create_color(color_end.r, color_end.g, color_end.b, alpha) or create_color(100, 100, 100, alpha)

                    local res = ""

                    for idx = 1, #text + 1 do
                        local letter = text:sub(idx, idx)

                        local alpha1 = (idx - 1) / (#text - 1)
                        local m_speed = globals.realtime() * ((50 / 25) or 1.0)
                        local m_factor = m_speed % math.pi

                        local c_speed = speed or 1
                        local m_sin = math.sin(m_factor * c_speed + (alpha1 or 0))
                        local m_abs = math_abs(m_sin)
                        local clr = first:lerp(second, m_abs)

                        res = ("%s\a%s%s"):format(res, clr:to_hex(), letter)
                    end

                    return res
                end)
            end

            create_color = setmetatable(stock_colors, {
                __call = create_color_object
            })
        end

        color = create_color
    end

    ---
    --- UI library
    ---
    local override = {} do
        local e_hotkey_mode = {
            [0] = "Always on",
            [1] = "On hotkey",
            [2] = "Toggle",
            [3] = "Off hotkey"
        }

        local data = { }
        local written = { }

        local function get_value(ref)
            if type(ref) == "table" then
                ref = ref[1]
            end
            if ref == nil then return {} end

            local ok, val1, val2, val3 = pcall(ui_get, ref)
            if not ok then return {} end
            local value = { val1, val2, val3 }

            local ok2, typeof = pcall(ui.type, ref)
            if ok2 and typeof == "hotkey" then
                return { e_hotkey_mode[value[2]], value[3] }
            end

            return value
        end

        function override.get(ref, ...)
            if type(ref) == "table" then ref = ref[1] end
            local value = data[ref]

            if value == nil then
                return
            end

            return unpack(value)
        end

        function override.set(ref, ...)
            if type(ref) == "table" then ref = ref[1] end
            if ref == nil then
                return
            end

            local args = {...}
            if #args == 0 then
                return
            end

            for i=1, #args do
                if args[i] == nil then
                    return
                end
            end

            if data[ref] == nil then
                data[ref] = get_value(ref)
            end

            -- skip rewriting the exact same value within 0.25s (nothing else writes these refs)
            local now = globals.realtime()
            local prev = written[ref]
            if prev and prev.n == #args and now - prev.t < 0.25 then
                local same = true
                for i = 1, #args do
                    if prev[i] ~= args[i] then same = false break end
                end
                if same then return end
            end

            pcall(ui.set, ref, unpack(args))
            args.n, args.t = #args, now
            written[ref] = args
        end

        function override.unset(ref)
            if type(ref) == "table" then ref = ref[1] end
            if ref == nil then return end
            written[ref] = nil
            if data[ref] == nil then
                return
            end

            pcall(ui.set, ref, unpack(data[ref]))
            data[ref] = nil
        end
    end

    local menu = {} do
        local items = { }
        local records = { }

        local callbacks = { }

        local function get_value(ref)
            local value = { pcall(ui.get, ref) }
            if not value[1] then return end

            return unpack(value, 2)
        end

        local function get_keys(value)
            if type(value[1]) == "table" then
                return c_table.keys(value[1])
            end

            return { }
        end

        local function update_items()
            for i = 1, #callbacks do
                callbacks[i]()
            end

            for i = 1, #items do
                local item = items[i]

                ui_set_visible(item.ref, item.is_visible)
                item.is_visible = false
            end
        end

        local c_item = { } do
            function c_item:new()
                return setmetatable({ }, self)
            end

            function c_item:init()
                local function callback(ref)
                    if self.is_label then return end
                    self:update_value(ref)
                    self:invoke_callback(ref)
                    if self.saveable and self.is_recorded then menu.dirty = true end

                    update_items()
                end

                ui.set_callback(self.ref, callback)
            end

            function c_item:get()
                -- hotkeys / textboxes change without a menu callback: always read them live
                if self.is_live then return ui_get(self.ref) end
                return unpack(self.value)
            end

            function c_item:set(...)
                local ref = self.ref

                ui_set(ref, ...)
                self:update_value(ref)
            end

            function c_item:rawget()
                return ui_get(self.ref)
            end

            function c_item:reset()
                pcall(ui.set, self.ref, unpack(self.default))
            end

            function c_item:record(tab, name)
                if records[tab] == nil then
                    records[tab] = { }
                end

                self.is_recorded = true
                records[tab][name] = self

                return self
            end

            function c_item:save()
                if not self.is_recorded then
                    error("unable to save unrecorded item")
                    return
                end

                self.is_saved = true
                return self
            end

            function c_item:display()
                self.is_visible = true
            end

            function c_item:config_ignore()
                self.saveable = false
                return self
            end

            function c_item:set_callback(callback, run)
                if run then
                    callback(self.ref)
                end

                self.callbacks[#self.callbacks + 1] = callback
            end

            function c_item:update_value(ref)
                local value = { get_value(ref) }
                self.keys = get_keys(value)

                self.value = value
            end

            function c_item:invoke_callback(...)
                for i = 1, #self.callbacks do
                    self.callbacks[i](...)
                end
            end

            function c_item:get_ref()
                return self.ref
            end

            c_item.__index = c_item
        end

        -- where the menu lives: the LUA tab (default) or the AA tab (second icon from the top, the spot
        -- Amnesia uses). Read once at load; a change is applied the next time the script is loaded.
        menu.location = "LUA"
        do
            local ok, where = pcall(database.read, "specter_menu_location")
            if ok and (where == "AA" or where == "LUA") then menu.location = where end
        end
        -- items are written against the AA tab's three boxes:
        --   "Anti-aimbot angles" = page content, "Fake lag" = navigation, "Other" = the page's side panel
        -- placed with the page you configure on the left and the navigation on the right (where Fake lag is)
        local PLACE = {
            LUA = { tab = "LUA", ["Anti-aimbot angles"] = "A", ["Fake lag"] = "B", ["Other"] = "B" },
            AA = { tab = "AA", ["Anti-aimbot angles"] = "Anti-aimbot angles", ["Fake lag"] = "Fake lag", ["Other"] = "Other" },
        }

        -- the gamesense tab / container an item really goes to
        function menu.container(tab, group)
            local place = tab == "AA" and PLACE[menu.location]
            if place and place[group] then
                return place.tab, place[group]
            end
            return tab, group
        end

        function menu.new_item(fn, tab, group, name, ...)
            tab, group = menu.container(tab, group)
            local ref = fn(tab, group, name, ...)

            local value = { get_value(ref) }
            local typeof = ui.type(ref)

            local item = c_item:new()

            item.ref = ref
            item.name = name
            item.tab, item.group = tab, group

            item.value = value
            item.default = value

            item.keys = get_keys(value)
            item.callbacks = { }

            item.is_saved = false
            item.is_visible = false
            item.is_recorded = false

            item.saveable = true
            item.is_label = typeof == "label"
            item.is_live = typeof == "hotkey" or typeof == "textbox"

            if typeof == "button" then
                item.callbacks[#item.callbacks + 1] = (...)
            end

            item:init()
            items[#items + 1] = item

            return item
        end

        function menu.get_records()
            return records
        end

        function menu.set_callback(callback)
            callbacks[#callbacks + 1] = callback
        end

        function menu.update()
            update_items()
        end
    end

    local config_system do
        config_system = { }

        local e_hotkey_mode = {
            [0] = "Always on",
            [1] = "On hotkey",
            [2] = "Toggle",
            [3] = "Off hotkey"
        }

        local function resolve_item_export(item)
            if not item.saveable then
                return
            end

            if ui.type(item.ref) == "label" then
                return
            end

            if ui.type(item.ref) == "hotkey" then
                local _, mode, key = item:rawget()

                return {e_hotkey_mode[mode], key}
            end

            if ui.type(item.ref) == "textbox" then
                return { tostring(item:rawget() or "") }
            end

            return item.value
        end

        local function resolve_item_import(item, data)
            if ui.type(item.ref) == "label" then
                return true
            end

            if not item.saveable then
                return true
            end

            if data == nil then
                return false
            end

            -- wrong value type from an old config (e.g. a list saved for a checkbox): treat as off
            if ui.type(item.ref) == "checkbox" and type(data[1]) ~= "boolean" then
                data = { false }
            end

            for i = 1, #data do
                if type(data[i]) == "string" then
                    data[i] = data[i]:gsub("^Zenith  ", "Specter ")
                end
            end

            if ui.type(item.ref) == "hotkey" then
                if pcall(item.set, item, unpack(data)) then return true end
                return (pcall(item.set, item, data[1]))
            end

            return (pcall(item.set, item, unpack(data)))
        end

        function config_system.export_to_str(...)
            local tabs = {...}
            local config_result = {}

            local records = menu:get_records()

            if #tabs ~= 0 then
                records = {}

                for i=1, #tabs do
                    records[tabs[i]] = menu:get_records()[tabs[i]]
                end
            end

            for tab, list in pairs(records) do
                config_result[tab] = {}

                for item_id, element in pairs(list) do
                    config_result[tab][item_id] = resolve_item_export(element)
                end
            end

            return base64.encode(json.stringify(config_result)) .. '_Specter'
        end

        function config_system.import_from_str(str, ...)
            local tabs = {...}
            local bloom_str = str:find("_", 1, true)

            if bloom_str then
                str = str:sub(1, bloom_str-1)
            end

            local status, config = pcall(base64.decode, str)

            if not status then
                return false, "Failed to decode config"
            end

            status, config = pcall(json.parse, config)

            if not status then
                return false, "Failed to parse config"
            end

            local records = menu:get_records()

            if #tabs ~= 0 then
                records = {}

                for i=1, #tabs do
                    records[tabs[i]] = menu:get_records()[tabs[i]]
                end
            end

            if type(config) ~= "table" then
                return false, "Config is empty"
            end

            local loaded, failed, failed_names = 0, 0, {}
            for tab, list in pairs(records) do
                if config[tab] then
                    for item_id, element in pairs(list) do
                        if config[tab][item_id] then
                            if resolve_item_import(element, config[tab][item_id]) then
                                loaded = loaded + 1
                            else
                                failed = failed + 1
                                if #failed_names < 5 then failed_names[#failed_names + 1] = tab .. "." .. tostring(item_id) end
                            end
                        end
                    end
                end
            end

            if failed > 0 then
                c_logger.log('Config: %d settings loaded, %d skipped (e.g. %s)', loaded, failed, table_concat(failed_names, ", "))
            end

            if config_system.after_import then pcall(config_system.after_import) end
            if config_system.migrate then pcall(config_system.migrate) end

            return true, nil, loaded
        end

        function config_system:retrieve_local()
            local db_data = database.read('specter_config') or database.read('zenith_config')

            if db_data ~= nil and db_data[1] ~= nil then
                local ok = self.import_from_str(db_data[1])
                self.last_saved = db_data[1]
                return ok and true or false
            end

            return false
        end

        function config_system:save_local(quiet)
            local ok, config_output = pcall(self.export_to_str)
            if not ok then
                c_logger.log_error('Config save failed [%s]', tostring(config_output))
                return false
            end

            if config_output ~= self.last_saved then
                database.write('specter_config', {
                    config_output
                })
                self.last_saved = config_output
                if not quiet then c_logger.log('Local config saved.') end
            elseif not quiet then
                c_logger.log('Local config already up to date.')
            end

            return true
        end
    end

    ---
    --- Reference
    ---
    do
        reference = {} do
            reference.ragebot = {} do
                reference.ragebot.enabled = {ui_reference('RAGE', 'Aimbot', 'Enabled')}

                reference.ragebot.doubletap = {} do
                    reference.ragebot.doubletap.enable = {ui_reference('RAGE', 'Aimbot', 'Double tap')}
                    reference.ragebot.doubletap.fakelag = ui_reference('RAGE', 'Aimbot', 'Double tap fake lag limit')
                end

                reference.ragebot.force_bodyaim = ui_reference('RAGE', 'Aimbot', 'Force body aim')
                reference.ragebot.force_safepoint = ui_reference('RAGE', 'Aimbot', 'Force safe point')

                reference.ragebot.minimum_damage_override = {ui_reference('RAGE', 'Aimbot', 'Minimum damage override')}

                reference.ragebot.quick_peek_assist = {ui_reference('RAGE', 'Other', 'Quick peek assist')}
                reference.ragebot.fakeduck = ui_reference('RAGE', 'Other', 'Duck peek assist')
                reference.ragebot.backtrack = ui_reference('RAGE', 'Other', 'Accuracy boost')
                reference.ragebot.multipoint = {ui_reference('RAGE', 'Aimbot', 'Multi-point')}
                reference.ragebot.multipoint_scale = ui_reference('RAGE', 'Aimbot', 'Multi-point scale')
            end

            reference.antiaim = {} do
                reference.antiaim.master = ui_reference('AA', 'Anti-aimbot angles', 'Enabled')

                reference.antiaim.roll = ui_reference('AA', 'Anti-aimbot angles', 'Roll')
                reference.antiaim.freestanding = {ui_reference('AA', 'Anti-aimbot angles', 'Freestanding')}

                reference.antiaim.pitch = c_table.unpack_keywise({'type', 'value'}, ui_reference('AA', 'Anti-aimbot angles', 'Pitch'))

                reference.antiaim.yaw = {} do
                    reference.antiaim.yaw.base = ui_reference('AA', 'Anti-aimbot angles', 'Yaw base')
                    reference.antiaim.yaw.yaw = c_table.unpack_keywise({'type', 'value'}, ui_reference('AA', 'Anti-aimbot angles', 'Yaw'))
                    reference.antiaim.yaw.jitter = c_table.unpack_keywise({'type', 'value'}, ui_reference('AA', 'Anti-aimbot angles', 'Yaw jitter'))
                    reference.antiaim.yaw.edge = ui_reference('AA', 'Anti-aimbot angles', 'Edge yaw')
                end

                reference.antiaim.body = {} do
                    reference.antiaim.body.yaw = c_table.unpack_keywise({'type', 'value'}, ui_reference('AA', 'Anti-aimbot angles', 'Body yaw'))
                    reference.antiaim.body.freestanding = ui_reference('AA', 'Anti-aimbot angles', 'Freestanding body yaw')
                end
            end

            reference.fakelag = {} do
                reference.fakelag.enable = {ui_reference('AA', 'Fake lag', 'Enabled')}
                reference.fakelag.amount = ui_reference('AA', 'Fake lag', 'Amount')
                reference.fakelag.variance = ui_reference('AA', 'Fake lag', 'Variance')
                reference.fakelag.limit = ui_reference('AA', 'Fake lag', 'Limit')
            end

            reference.misc = {} do
                reference.misc.draw_output = ui_reference('MISC', 'Miscellaneous', 'Draw console output')
                reference.misc.freestanding = ui_reference('AA', 'Anti-aimbot angles', 'Freestanding')

                reference.misc.slowmotion = {ui_reference('AA', 'Other', 'Slow motion')}
                reference.misc.onshot_antiaim = {ui_reference('AA', 'Other', 'On shot anti-aim')}
                reference.misc.leg_movement = ui_reference('AA', 'Other', 'Leg movement')

                reference.misc.grenade_toss = ui_reference('MISC', 'Miscellaneous', 'Super toss')
                reference.misc.grenade_release = {ui_reference('MISC', 'Miscellaneous', 'Automatic grenade release')}

                reference.misc.air_strafe = ui_reference('MISC', 'Movement', 'Air strafe')
            end
        end
    end

    ---
    --- Menu
    ---

    ---
    --- Menu look (Amnesia style): left box = the open page, right box = navigation + the page's side panel.
    --- The accent follows gamesense's own menu color (MISC > Settings > Menu color), so labels always match
    --- the checkboxes and sliders.
    ---
    local mui = {
        CONTENT = "Anti-aimbot angles", NAV = "Fake lag", SIDE = "Other",
        A = "\a95B806FF", W = "\aF0F0F5FF", K = "\a8C8C96FF", D = "\a5F5F6BFF",
        themed = {}, names = {}, overview = {}, loaded_at = globals.realtime(),
    }
    do
        local ok, ref = pcall(ui_reference, "MISC", "Settings", "Menu color")
        mui.color_ref = ok and ref or nil

        function mui.accent()
            if not mui.color_ref then return mui.A end
            local ok2, r, g, b = pcall(ui_get, mui.color_ref)
            if not ok2 or type(r) ~= "number" then return mui.A end
            return string_format("\a%02X%02X%02XFF", r, g, b)
        end
        mui.A = mui.accent()

        -- two labels in one box never share a name: repeats get invisible trailing spaces
        function mui.unique(group, text)
            local key = select(2, menu.container("AA", group)) .. "\0" .. text
            local n = mui.names[key]
            mui.names[key] = (n or 0) + 1
            return n and (text .. string.rep(" ", n)) or text
        end

        -- label whose text comes from build(accent); rebuilt when the accent changes or on refresh()
        function mui.label(group, build)
            local item = menu.new_item(ui.new_label, "AA", group, mui.unique(group, build(mui.A))):config_ignore()
            item.build = build
            mui.themed[#mui.themed + 1] = item
            return item
        end

        function mui.refresh(item)
            if not item or not item.build then return end
            local ok2, text = pcall(item.build, mui.A)
            if ok2 and type(text) == "string" and item.shown_text ~= text then
                item.shown_text = text
                pcall(ui_set, item.ref, text)
            end
        end

        function mui.retheme()
            local A = mui.accent()
            if A == mui.A then return end
            mui.A = A
            for i = 1, #mui.themed do mui.refresh(mui.themed[i]) end
        end

        -- "   ⊕   Ragebot"
        function mui.header(group, sym, title)
            return mui.label(group, function(A) return string_format("   %s%s   %s%s", A, sym, mui.W, title) end)
        end

        function mui.spacer(group)
            return menu.new_item(ui.new_label, "AA", group, mui.unique(group, " ")):config_ignore()
        end

        function mui.hint(group, text)
            return menu.new_item(ui.new_label, "AA", group, mui.unique(group, mui.D .. "      " .. text)):config_ignore()
        end

        -- "     ☺  User   admin"   (dim icon and key, accent value)
        function mui.row(group, sym, key, value_fn)
            return mui.label(group, function(A)
                local ok2, value = pcall(value_fn)
                return string_format("     %s%s  %s%s   %s%s", mui.D, sym, mui.K, key, A, ok2 and tostring(value) or "-")
            end)
        end

        function mui.greeting()
            local ok2, h = pcall(client.system_time)
            h = ok2 and tonumber(h) or 12
            if h >= 5 and h < 12 then return "good morning" end
            if h >= 12 and h < 18 then return "good afternoon" end
            if h >= 18 and h < 23 then return "good evening" end
            return "good night"
        end

        function mui.clock(seconds)
            seconds = math_floor(math_max(0, seconds or 0))
            return string_format("%d:%02d", math_floor(seconds / 3600), math_floor(seconds / 60) % 60)
        end
    end

    -- lifetime counters for the Home page (stored locally with the other specter data)
    local telemetry = { loads = 0, seconds = 0, kills = 0, evaded = 0 }
    do
        local ok, saved = pcall(database.read, "specter_telemetry")
        if ok and type(saved) == "table" then
            telemetry.loads = tonumber(saved.loads) or 0
            telemetry.seconds = tonumber(saved.seconds) or 0
            telemetry.kills = tonumber(saved.kills) or 0
            telemetry.evaded = tonumber(saved.evaded) or 0
        end
        telemetry.loads = telemetry.loads + 1
        telemetry.start = globals.realtime()

        function telemetry.play_time()
            return telemetry.seconds + math_max(0, globals.realtime() - telemetry.start)
        end

        function telemetry.save()
            telemetry.seconds = telemetry.play_time()
            telemetry.start = globals.realtime()
            pcall(database.write, "specter_telemetry", {
                loads = telemetry.loads, seconds = telemetry.seconds, kills = telemetry.kills, evaded = telemetry.evaded,
            })
        end
        telemetry.save()

        client.set_event_callback("player_death", function(e)
            local me = entity_get_local_player()
            local victim, attacker = client.userid_to_entindex(e.userid), client.userid_to_entindex(e.attacker)
            if me and attacker == me and victim and victim ~= me and entity.is_enemy(victim) then
                telemetry.kills = telemetry.kills + 1
            end
        end)
        client.set_event_callback("round_end", function() telemetry.save() end)
        client.set_event_callback("shutdown", function() telemetry.save() end)
    end

    config.uix = {}

    config.navigation = {} do
        local NAV = config.navigation
        local C, N, S = mui.CONTENT, mui.NAV, mui.SIDE

        -- the page tree (Amnesia style); a group heading opens the first page below it
        NAV.tree = (function()
            local t = {
                { text = "☺   Info" },
                { text = "        •  Profile", page = "Home" },
                { text = "⚔   Combat" },
            }
            if TIER.HAS_RAGEBOT_EXTRA then
                t[#t+1] = { text = "        •  Ragebot", page = "Ragebot", sub = "General" }
            end
            if TIER.HAS_RESOLVER then
                t[#t+1] = { text = "                •  Resolver", page = "Ragebot", sub = "Resolver" }
            end
            if TIER.HAS_TUNING then
                t[#t+1] = { text = "                •  Tuning", page = "Ragebot", sub = "Tuning" }
            end
            t[#t+1] = { text = "        •  Anti Aimbot", page = "Anti Aimbot", sub = "General" }
            if TIER.HAS_BUILDER then
                t[#t+1] = { text = "                •  Builder", page = "Anti Aimbot", sub = "Builder" }
            end
            if TIER.HAS_DEFENSIVE then
                t[#t+1] = { text = "                •  Defensive", page = "Anti Aimbot", sub = "Defensive" }
            end
            t[#t+1] = { text = "☀   World" }
            t[#t+1] = { text = "        •  Visualization", page = "Visuals", sub = "Screen" }
            t[#t+1] = { text = "                •  Widgets", page = "Visuals", sub = "Widgets" }
            t[#t+1] = { text = "⚙   System" }
            t[#t+1] = { text = "        •  Miscellaneous", page = "Misc" }
            t[#t+1] = { text = "        •  Configs", page = "Loadouts" }
            return t
        end)()

        -- right: brand, who / what / where, then the navigation tree
        NAV.brand = mui.label(N, function(A) return string_format("  %s⚡ %sspecter%s.lua", mui.K, mui.W, A) end)
        NAV.gap1 = mui.spacer(N)
        NAV.info = {
            mui.row(N, "☺", "User:", function() return user.name .. "  \a6E6E78FF•  " .. mui.A .. user.role end),
            mui.row(N, "⚒", "Build:", function() return user.version end),
            mui.row(N, "↻", "Updated:", function() return user.updated end),
            mui.row(N, "◷", "Session:", function() return mui.clock(globals.realtime() - mui.loaded_at) end),
            mui.row(N, "◎", "Server:", function()
                if entity_get_local_player() then
                    return "\a8CE6A0FF●  \aC8C8D2FF" .. tostring(globals.mapname() or "")
                end
                return "\a6E6E78FF○  not connected"
            end),
        }
        NAV.gap2 = mui.spacer(N)
        NAV.nav_hdr = mui.header(N, "⊞", "Navigation")
        local rows = {}
        for i, r in ipairs(NAV.tree) do rows[i] = r.text end
        NAV.list = menu.new_item(ui.new_listbox, "AA", N, "\nspecter_nav", rows):config_ignore()
        NAV.gap_end = mui.spacer(N)
        NAV.current = 2

        local function key_of(r) return r.page .. "/" .. (r.sub or "") end

        function NAV.page()
            local r = NAV.tree[NAV.current]
            return r and r.page or "Home"
        end

        function NAV.subpage()
            local r = NAV.tree[NAV.current]
            return r and r.sub or nil
        end

        local function first_page_from(i)
            for j = i, #NAV.tree do
                if NAV.tree[j].page then return j end
            end
            return NAV.current
        end

        NAV.list:set_callback(function()
            local i = (tonumber(NAV.list:get()) or 0) + 1
            if not (NAV.tree[i] and NAV.tree[i].page) then
                i = first_page_from(i)
                if not NAV.redirecting then
                    NAV.redirecting = true
                    pcall(NAV.list.set, NAV.list, i - 1)
                    NAV.redirecting = false
                end
            end
            NAV.current = i
            pcall(database.write, "specter_menu_page", { row = key_of(NAV.tree[i]) })
        end)

        -- reopen on the page that was open last time
        do
            local ok, saved = pcall(database.read, "specter_menu_page")
            local want = ok and type(saved) == "table" and saved.row or nil
            for i, r in ipairs(NAV.tree) do
                if r.page and key_of(r) == want then NAV.current = i end
            end
            pcall(NAV.list.set, NAV.list, NAV.current - 1)
        end

        -- left: every page's header (only the open page's header is shown)
        local H = {}
        NAV.hdr = H
        H.greeting = mui.label(C, function(A)
            return string_format("   %s%s   %s%s, %s%s", A, user.sky(), mui.W, mui.greeting(), A, user.name)
        end)
        H.gap_home = mui.spacer(C)
        H.telemetry = mui.header(C, "▼", "Statistics")
        H.telemetry_rows = {
            mui.row(C, "↻", "Total time:", function() return mui.clock(telemetry.play_time()) end),
            mui.row(C, "☠", "Kills:", function() return telemetry.kills end),
            mui.row(C, "⇄", "Shots evaded:", function() return telemetry.evaded end),
            mui.row(C, "↺", "Times loaded:", function() return telemetry.loads end),
        }
        H.gap_home1 = mui.spacer(C)
        H.overview = mui.header(C, "◈", "Overview")
        H.overview_rows = {}
        for i = 1, 6 do
            H.overview_rows[i] = mui.label(C, function() return mui.overview[i] or (mui.D .. "     ...") end)
        end
        H.gap_home2 = mui.spacer(C)
        H.stats = mui.header(C, "▤", "Accuracy")
        H.rage = mui.header(C, "⊕", "Ragebot")
        H.resolver = mui.header(C, "◎", "Resolver")
        H.tuning = mui.header(C, "✈", "Tuning")
        H.aa = mui.header(C, "☾", "Anti Aim")
        H.builder = mui.header(C, "⚒", "Builder")
        H.defensive = mui.header(C, "◆", "Defensive")
        H.visuals = mui.header(C, "◐", "Visuals")
        H.widgets = mui.header(C, "☰", "Widgets")
        H.misc = mui.header(C, "☰", "Modules")
        H.loadouts = mui.header(C, "✎", "Loadouts")
        H.gap = mui.spacer(C)

        -- master switch for specter's anti-aim (top of the Anti Aimbot pages)
        NAV.aa_enable = menu.new_item(ui.new_checkbox, "AA", C, "Enable\nspecter_aa_master")
            :record("antiaimbot", "master"):save()
        pcall(NAV.aa_enable.set, NAV.aa_enable, true)
        NAV.aa_enable.default = { true }

        -- the open page's side panel (under the tree in the LUA tab, bottom right box in the AA tab)
        local P = {}
        NAV.side = P
        P.top = mui.spacer(S)
        P.other = mui.header(S, "⚑", "Other")
        P.jumpscout = mui.header(S, "➚", "Jumpscout")
        P.tools = mui.header(S, "✦", "Resolver Tools")
        P.peek = mui.header(S, "⇆", "Peek Assist")
        P.fakelag = mui.header(S, "≋", "Fake Lag")
        P.advanced = mui.header(S, "⚙", "Advanced")
        P.triggers = mui.header(S, "✱", "Triggers")
        P.tweaks = mui.header(S, "⚙", "Tweaks")
        P.logs = mui.header(S, "✉", "Logs")
        P.create = mui.header(S, "✚", "Create Loadout")
        P.gap = mui.spacer(S)

        -- while the menu lives in the LUA tab, leave a pointer in the (now empty) AA tab
        if menu.location == "LUA" then
            pcall(ui.new_label, "AA", "Anti-aimbot angles", mui.A .. "☾  specter  " .. mui.K .. "·  menu is in the LUA tab")
        end
    end

    config.ragebot = {} do
        config.ragebot.hdr_accuracy = mui.header(mui.CONTENT, "◇", "Accuracy")
        config.ragebot.backtrack_optimization = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Backtrack Optimization")
            :record("ragebot", "backtrack_optimization"):save()
        config.ragebot.backtrack_level = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Accuracy boost\nbacktrack", {
            "High", "Maximum"
        }):record("ragebot", "backtrack_level"):save()



        config.ragebot.dormant = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Dormant Aimbot")
            :record("ragebot", "dormant_aimbot"):save()
        config.ragebot.dormant_key = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "\ndormant_aimbot_key", true)
            :record("ragebot", "dormant_aimbot_key"):save()
        config.ragebot.dormant_damage = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Min damage\ndormant", 1, 100, 15, true, " hp")
            :record("ragebot", "dormant_damage"):save()
        -- where to shoot: the heights are taken from the enemy's real hitboxes while it was last visible (crouch / stand)
        config.ragebot.dormant_hitboxes = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Hitboxes\ndormant", { "Head", "Chest", "Stomach" })
            :record("ragebot", "dormant_hitboxes"):save()
        pcall(function() config.ragebot.dormant_hitboxes:set({ "Chest", "Stomach" }) end)
        -- our gun's spread at that distance against the size of the hitbox: no shot before it is accurate enough
        config.ragebot.dormant_hc = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Hit chance\ndormant", 0, 100, 55, true, "%")
            :record("ragebot", "dormant_hc"):save()

        config.ragebot.extended_bt = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Extended Backtrack")
            :record("ragebot", "extended_bt"):save()
        config.ragebot.extended_bt_mode = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Mode\nextended_bt", {
            "Only with target", "Always"
        }):record("ragebot", "extended_bt_mode"):save()
        config.ragebot.extended_bt_amount = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Amount\nextended_bt", 50, 200, 200, true, "ms")
            :record("ragebot", "extended_bt_amount"):save()
        -- Adaptive record selection: the fake ping decides which records the server accepts (around now - our total
        -- latency, +-200 ms), so it picks old or new ones. A target that stands, or whose newest record is a shift: the full
        -- amount (the older, valid records); a target that runs / peeks: less (the newest record, where it came out)
        config.ragebot.adaptive_records = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "•  Adaptive record selection\nextended_bt")
            :record("ragebot", "adaptive_records"):save()
        -- Ping reducer: no fake ping when it buys nothing, the real ping stays low
        config.ragebot.ping_reducer = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Ping reducer\nextended_bt", {
            "Knife / grenade", "Freeze time", "No target for 3s"
        }):record("ragebot", "ping_reducer"):save()

        do
            local refs, slider, saved, active, looked, last_amount = {}, nil, nil, false, false, nil
            local extended_seen = 0

            local function lookup()
                looked = true
                local r = { pcall(ui_reference, 'MISC', 'Miscellaneous', 'Ping spike') }
                if not r[1] then return end
                for i = 2, #r do
                    local ok, v = pcall(ui_get, r[i])
                    if ok and type(v) == "number" then
                        slider = r[i]
                    elseif ok then
                        refs[#refs + 1] = r[i]
                    end
                end
            end

            local function restore()
                if not active then return end
                for ref, v in pairs(saved or {}) do
                    if type(v[2]) == "string" then
                        pcall(ui_set, ref, v[2])
                    else
                        pcall(ui_set, ref, v[1])
                    end
                end
                saved, active, last_amount = nil, false, nil
            end

            local function apply(amount)
                if not active then
                    saved = {}
                    for _, ref in ipairs(refs) do saved[ref] = { ui_get(ref) } end
                    if slider then saved[slider] = { ui_get(slider) } end
                    for _, ref in ipairs(refs) do
                        if not pcall(ui_set, ref, "Always on") then pcall(ui_set, ref, true) end
                    end
                    active = true
                end
                if slider and amount ~= last_amount then
                    pcall(ui_set, slider, amount)
                    last_amount = amount
                end
            end

            client.set_event_callback("paint_ui", function()
                if not looked then lookup() end
                if #refs == 0 then return end
                local want = config.ragebot.extended_bt:get() and entity_get_local_player() ~= nil
                if want and config.ragebot.extended_bt_mode:get() ~= "Always" then
                    want = client.current_threat() ~= nil
                end
                -- the threat breaks lag comp: nothing to backtrack, the fake ping would only add to the extrapolation
                if want and c_table.contains(config.ragebot.lc_handling:get() or {}, "No ping spike") then
                    local t = client.current_threat()
                    local d = t and resolver.database and resolver.database[t]
                    if d and d.lc_state == "breaking" then want = false end
                end
                local me = entity_get_local_player()
                local red = config.ragebot.ping_reducer:get() or {}
                if want and me and #red > 0 then
                    if c_table.contains(red, "Knife / grenade") then
                        local wpn = entity.get_player_weapon(me)
                        local info = wpn and csgo_weapons(wpn)
                        if info and (info.type == "knife" or info.type == "grenade") then want = false end
                    end
                    if want and c_table.contains(red, "Freeze time") then
                        local rules = entity.get_game_rules()
                        if rules and entity_get_prop(rules, "m_bFreezePeriod") == 1 then want = false end
                    end
                    if want and c_table.contains(red, "No target for 3s") then
                        local t = client.current_threat()
                        local now = globals.realtime()
                        if t and not entity.is_dormant(t) then extended_seen = now end
                        if now - (extended_seen or 0) > 3 then want = false end
                    end
                end
                if want then
                    local amount = config.ragebot.extended_bt_amount:get()
                    if config.ragebot.adaptive_records:get() then
                        local t = client.current_threat()
                        local d = t and resolver.database and resolver.database[t]
                        local speed = d and d.speed
                        if t and not speed then
                            local vx, vy = entity_get_prop(t, "m_vecVelocity")
                            speed = math.sqrt((vx or 0) ^ 2 + (vy or 0) ^ 2)
                        end
                        if speed and not (d and d.lc_rec) then
                            -- 40 u/s or slower: all of it; 150 u/s or faster: 40 %, at least 50 ms
                            local f = c_math.clamp((speed - 40) / 110, 0, 1)
                            amount = math_floor(math_max(50, amount * (1 - 0.6 * f)) / 10 + 0.5) * 10
                        end
                    end
                    apply(amount)
                else
                    restore()
                end
            end)

            client.set_event_callback("shutdown", function() pcall(restore) end)
        end

        config.ragebot.multipoint = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Improved Multi-point")
            :record("ragebot", "multipoint"):save()
        config.ragebot.multipoint_hitboxes = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Hitboxes\nmultipoint", {"Head", "Chest", "Stomach", "Arms", "Legs", "Feet"})
            :record("ragebot", "multipoint_hitboxes"):save()
        config.ragebot.multipoint_scale = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Scale\nmultipoint", 24, 100, 60, true, "%")
            :record("ragebot", "multipoint_scale"):save()
        config.ragebot.multipoint_auto = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "•  Auto\nmultipoint")
            :record("ragebot", "multipoint_auto"):save()

        -- Predict enemies: less interpolation = the enemies (and their records) are drawn / lag compensated closer to
        -- where they really are; a peeker shows up a few ms earlier. Default: one tick of interp; Aggressive: none, 128
        -- updates; Ultimate: interpolation off too. The old values come back when it is switched off / unloaded
        config.ragebot.predict = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Predict enemies")
            :record("ragebot", "predict"):save()
        config.ragebot.predict_mode = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Mode\npredict", {
            "Default", "Aggressive", "Ultimate"
        }):record("ragebot", "predict_mode"):save()
        -- only at some pings (our real ping, without the fake ping): less interp helps most on a high ping
        config.ragebot.predict_when = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Active\npredict", {
            "Always", "Ping 55+", "Ping under 40"
        }):record("ragebot", "predict_when"):save()
        do
            local MODES = {
                Default    = { cl_interp_ratio = 1, cl_interp = 0.015625, cl_updaterate = 64, cl_cmdrate = 64 },
                Aggressive = { cl_interp_ratio = 1, cl_interp = 0, cl_updaterate = 128, cl_cmdrate = 128 },
                Ultimate   = { cl_interp_ratio = 1, cl_interp = 0, cl_updaterate = 128, cl_cmdrate = 128, cl_interpolate = 0 },
            }
            local saved, next_t = {}, 0
            local function cv(name) local ok, c = pcall(function() return cvar[name] end) return ok and c or nil end
            local function getv(c, name) return name == "cl_interp" and c:get_float() or c:get_int() end
            local function setv(c, name, v)
                if name == "cl_interp" then pcall(c.set_raw_float, c, v) else pcall(c.set_raw_int, c, v) end
            end
            local function restore()
                for name, old in pairs(saved) do
                    local c = cv(name)
                    if c then setv(c, name, old) end
                end
                saved = {}
            end
            client.set_event_callback("paint_ui", function()
                local now = globals.realtime()
                if now < next_t and now > next_t - 2 then return end
                next_t = now + 0.5
                local on = config.ragebot.predict:get()
                local when = config.ragebot.predict_when and config.ragebot.predict_when:get() or "Always"
                if on and when ~= "Always" then
                    local ping = real_ping()
                    -- 3 ms of hysteresis, or a ping that sits on the line switches the cvars every half second
                    local was = next(saved) ~= nil
                    if when == "Ping 55+" then on = ping >= (was and 52 or 55) else on = ping <= (was and 43 or 40) end
                end
                if not on then
                    if next(saved) then restore() end
                    return
                end
                local want = MODES[config.ragebot.predict_mode:get()] or MODES.Default
                for name, old in pairs(saved) do
                    if want[name] == nil then
                        local c = cv(name)
                        if c then setv(c, name, old) end
                        saved[name] = nil
                    end
                end
                for name, v in pairs(want) do
                    local c = cv(name)
                    if c then
                        if saved[name] == nil then saved[name] = getv(c, name) end
                        if math.abs(getv(c, name) - v) > 1e-6 then setv(c, name, v) end
                    end
                end
            end)
            client.set_event_callback("shutdown", function() pcall(restore) end)
        end

        config.ragebot.hdr_safety = mui.header(mui.CONTENT, "◎", "Body aim & safety")
        -- enemies that break lag compensation (teleport > 64 units between updates, tickbase shift): no backtrack is possible,
        -- the aimbot shoots the newest record extrapolated. Body aim / safe point are the big, safe hitboxes for that; the
        -- ping spike only makes the extrapolation longer
        config.ragebot.lc_handling = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "Vs. lag comp breakers", {
            "Body aim", "Safe point", "No ping spike"
        }):record("ragebot", "lc_handling"):save()
        pcall(function() config.ragebot.lc_handling:set({ "Body aim", "No ping spike" }) end)

        -- Aim tools: per weapon group, body aim / safe point from the enemy's health (or when a body shot kills) and from
        -- the resolver's misses on it. Over the rules above for that weapon; "Force" = force body aim instead of prefer
        config.ragebot.aimtools = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Aim tools")
            :record("ragebot", "aimtools"):save()
        config.ragebot.aimtools_groups = { "Scout", "AWP", "Auto", "Deagle", "Revolver", "Pistols", "Other" }
        config.ragebot.aimtools_group = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Weapon\naimtools", config.ragebot.aimtools_groups)
            :config_ignore()
        config.ragebot.aimtools_w = {}
        do
            local DEF = { Scout = { 101, 2, 0, 0 }, AWP = { 101, 0, 0, 0 }, Auto = { 101, 2, 0, 3 }, Deagle = { 101, 2, 0, 0 },
                Revolver = { 101, 1, 0, 0 }, Pistols = { 0, 0, 0, 0 }, Other = { 0, 0, 0, 0 } }
            local HP = { [0] = "Off", [101] = "Lethal" }
            local MISS = { [0] = "Off" }
            for _, g in ipairs(config.ragebot.aimtools_groups) do
                local k, d = "at_" .. g:lower(), DEF[g]
                config.ragebot.aimtools_w[g] = {
                    baim_hp = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Body aim min health\n" .. k, 0, 101, d[1], true, "", 1, HP)
                        :record("ragebot", k .. "_baim_hp"):save(),
                    baim_miss = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Body aim after missed shots\n" .. k, 0, 5, d[2], true, "x", 1, MISS)
                        :record("ragebot", k .. "_baim_miss"):save(),
                    baim_force = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "•  Force body aim\n" .. k)
                        :record("ragebot", k .. "_baim_force"):save(),
                    sp_hp = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Safe points min health\n" .. k, 0, 101, d[3], true, "", 1, HP)
                        :record("ragebot", k .. "_sp_hp"):save(),
                    sp_miss = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Safe points after missed shots\n" .. k, 0, 5, d[4], true, "x", 1, MISS)
                        :record("ragebot", k .. "_sp_miss"):save(),
                }
            end
        end

        -- Aim tools: who the aimbot goes for first (player list "High priority"), and holding the shot on a target whose
        -- newest record is not a real one (a tickbase shift or a teleport) until a valid record comes, at most the slider
        config.ragebot.hdr_targeting = mui.header(mui.CONTENT, "⌖", "Targeting")
        config.ragebot.priority = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "Target priority", {
            "Bomb carrier", "Lowest health"
        }):record("ragebot", "priority"):save()
        config.ragebot.delay_invalid = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Delay shot at invalid records")
            :record("ragebot", "delay_invalid"):save()
        config.ragebot.delay_invalid_max = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Max wait\ndelay_invalid", 20, 400, 150, true, "ms")
            :record("ragebot", "delay_invalid_max"):save()

        do
            local prio = {}        -- [entindex] = true: "High priority" written by us
            local held = {}        -- [entindex] = { since = realtime, done = bool }: "Add to whitelist" while its record is invalid

            local function set_prio(idx, on)
                if (prio[idx] or false) == on then return end
                pcall(plist.set, idx, "High priority", on)
                prio[idx] = on or nil
            end
            local function set_hold(idx, on)
                local h = held[idx]
                if on and not (h and h.on) then
                    pcall(plist.set, idx, "Add to whitelist", true)
                    held[idx] = { since = globals.realtime(), on = true }
                elseif not on and h and h.on then
                    pcall(plist.set, idx, "Add to whitelist", false)
                    h.on = false
                end
            end
            local function release_all()
                for idx in pairs(prio) do pcall(plist.set, idx, "High priority", false) end
                for idx, h in pairs(held) do if h.on then pcall(plist.set, idx, "Add to whitelist", false) end end
                prio, held = {}, {}
            end

            client.set_event_callback("net_update_end", function()
                local me = entity_get_local_player()
                local want = config.ragebot.priority:get() or {}
                local delay = config.ragebot.delay_invalid:get()
                if not me or (#want == 0 and not delay) then
                    if next(prio) or next(held) then release_all() end
                    return
                end
                local enemies = entity.get_players(true)
                -- target priority: one enemy at a time
                local pick
                if c_table.contains(want, "Bomb carrier") then
                    for _, c4 in ipairs(entity.get_all("CC4")) do
                        local owner = entity_get_prop(c4, "m_hOwnerEntity")
                        if owner and owner > 0 and entity.is_enemy(owner) and entity.is_alive(owner) then pick = owner end
                    end
                end
                if not pick and c_table.contains(want, "Lowest health") then
                    local low = 100
                    for _, idx in ipairs(enemies) do
                        local hp = entity_get_prop(idx, "m_iHealth") or 100
                        if hp < low and not entity.is_dormant(idx) then pick, low = idx, hp end
                    end
                end
                local seen = {}
                for _, idx in ipairs(enemies) do
                    seen[idx] = true
                    set_prio(idx, idx == pick)
                    -- delay shot: the newest record is a tickbase shift / teleport (the resolver marks it), the aimbot
                    -- waits (whitelist) until a normal record arrives, never longer than the slider
                    local d = resolver.database and resolver.database[idx]
                    local invalid = delay and d and d.lc_rec == true
                    local h = held[idx]
                    if invalid then
                        local max = (config.ragebot.delay_invalid_max:get() or 150) / 1000
                        if h and h.on and globals.realtime() - h.since > max then
                            set_hold(idx, false); h.spent = true
                        elseif not (h and h.spent) then
                            set_hold(idx, true)
                        end
                    else
                        set_hold(idx, false)
                        if h then h.spent = nil end
                    end
                end
                for idx in pairs(prio) do if not seen[idx] then set_prio(idx, false) end end
                for idx, h in pairs(held) do if not seen[idx] and h.on then set_hold(idx, false) end end
            end)
            client.set_event_callback("round_start", release_all)
            client.set_event_callback("shutdown", function() pcall(release_all) end)
        end

        config.ragebot.hdr_exploits = mui.header(mui.CONTENT, "↯", "Exploits")
        config.ragebot.dt_guard = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Double Tap Guard")
            :record("ragebot", "dt_guard"):save()
        config.ragebot.dt_guard_on = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Disable on\ndt_guard", {
            "Grenades", "Revolver", "Fake duck", "After misses"
        }):record("ragebot", "dt_guard_on"):save()
        config.ragebot.dt_guard_misses = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Misses\ndt_guard", 2, 5, 3)
            :record("ragebot", "dt_guard_misses"):save()
        pcall(function() config.ragebot.dt_guard_on:set({ "Grenades", "Revolver", "Fake duck", "After misses" }) end)
        -- Auto hide shots: with double tap on, these states use hide shots (on shot anti-aim) instead (a standing / crouching
        -- shot does not need the second bullet, hide shots keeps the head safer); not with the weapons picked
        config.ragebot.auto_os = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Auto hide shots")
            :record("ragebot", "auto_os"):save()
        config.ragebot.auto_os_states = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  States\nauto_os", {
            "Standing", "Crouching", "Crouch moving", "Slow-motion", "Moving", "Air"
        }):record("ragebot", "auto_os_states"):save()
        pcall(function() config.ragebot.auto_os_states:set({ "Standing", "Crouching" }) end)
        config.ragebot.auto_os_avoid = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Not with\nauto_os", {
            "Desert Eagle", "Pistols", "Auto snipers", "SSG 08", "AWP"
        }):record("ragebot", "auto_os_avoid"):save()
        pcall(function() config.ragebot.auto_os_avoid:set({ "Desert Eagle" }) end)
        -- Unsafe charge: right after a double tap burst, double tap goes off for a few ticks and back on, so gamesense
        -- charges again at once instead of waiting for a safe moment (an enemy may see the recharge ticks)
        config.ragebot.unsafe_charge = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Unsafe charge")
            :record("ragebot", "unsafe_charge"):save()
        config.ragebot.unsafe_charge_ticks = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Off ticks\nunsafe_charge", 1, 6, 2, true, "t")
            :record("ragebot", "unsafe_charge_ticks"):save()

        do
            local misses, blocked_until, forced, os_forced = {}, 0, false, false

            client.set_event_callback("aim_miss", function(e)
                if e.reason == "death" or e.reason == "unregistered shot" then return end
                local now = globals.realtime()
                misses[#misses + 1] = now
                while #misses > 0 and now - misses[1] > 5 do table.remove(misses, 1) end
                if config.ragebot.dt_guard:get() and #misses >= config.ragebot.dt_guard_misses:get() then
                    blocked_until, misses = now + 3, {}
                end
            end)
            client.set_event_callback("aim_hit", function() misses = {} end)
            local last_fire = -100
            client.set_event_callback("aim_fire", function() last_fire = globals.tickcount() end)

            client.set_event_callback("setup_command", function()
                local want_off = false
                if config.ragebot.dt_guard:get() then
                    local on = config.ragebot.dt_guard_on:get() or {}
                    local me = entity_get_local_player()
                    local wpn = me and entity.get_player_weapon(me)
                    local id = wpn and entity_get_prop(wpn, "m_iItemDefinitionIndex")
                    if id and c_table.contains(on, "Grenades") and id >= 43 and id <= 48 then want_off = true end
                    if id == 64 and c_table.contains(on, "Revolver") then want_off = true end
                    if c_table.contains(on, "Fake duck") and ui_get(reference.ragebot.fakeduck) then want_off = true end
                    if c_table.contains(on, "After misses") and globals.realtime() < blocked_until then want_off = true end
                end
                -- unsafe charge: 6 ticks after the last shot (the second bullet of the burst is out), double tap off for the
                -- slider's ticks
                if not want_off and config.ragebot.unsafe_charge:get() then
                    local since = globals.tickcount() - last_fire
                    if since >= 6 and since < 6 + config.ragebot.unsafe_charge_ticks:get() then want_off = true end
                end
                -- auto hide shots: the user's double tap (as set, not as we overrode it) is on and the state is picked
                local want_os = false
                if not want_off and config.ragebot.auto_os:get() then
                    local dt_box = override.get(reference.ragebot.doubletap.enable[1])
                    if dt_box == nil then dt_box = ui_get(reference.ragebot.doubletap.enable[1]) end
                    local ok_k, key_on = pcall(ui_get, reference.ragebot.doubletap.enable[2])
                    local me = entity_get_local_player()
                    if dt_box and ok_k and key_on and me and entity.is_alive(me)
                        and c_table.contains(config.ragebot.auto_os_states:get() or {}, player.state or "") then
                        local wpn = entity.get_player_weapon(me)
                        local id = wpn and entity_get_prop(wpn, "m_iItemDefinitionIndex") or 0
                        local avoid = config.ragebot.auto_os_avoid:get() or {}
                        local pistol = id == 2 or id == 3 or id == 4 or id == 30 or id == 32 or id == 36 or id == 61 or id == 63 or id == 64
                        local blocked = (id == 1 and c_table.contains(avoid, "Desert Eagle")) or (pistol and c_table.contains(avoid, "Pistols"))
                            or ((id == 11 or id == 38) and c_table.contains(avoid, "Auto snipers"))
                            or (id == 40 and c_table.contains(avoid, "SSG 08")) or (id == 9 and c_table.contains(avoid, "AWP"))
                        want_os = not blocked
                    end
                end
                if want_off or want_os then
                    override.set(reference.ragebot.doubletap.enable[1], false)
                    forced = true
                elseif forced then
                    override.unset(reference.ragebot.doubletap.enable[1])
                    forced = false
                end
                if want_os then
                    override.set(reference.misc.onshot_antiaim[1], true)
                    override.set(reference.misc.onshot_antiaim[2], "Always on", 0x0)
                    os_forced = true
                elseif os_forced then
                    override.unset(reference.misc.onshot_antiaim[1])
                    override.unset(reference.misc.onshot_antiaim[2])
                    os_forced = false
                end
            end)
        end


        do
            local written = {}      -- [entindex] = { baim = "On" / "Off" / nil, sp = "On" / nil }

            local function put(idx, field, key, value)
                local w = written[idx]
                if not w then w = {}; written[idx] = w end
                if w[key] == value then return end
                local ok = pcall(plist.set, idx, field, value or "-")
                -- a gamesense without "Force" in the player list: prefer body aim then
                if not ok and value == "Force" then pcall(plist.set, idx, field, "On") end
                w[key] = value
            end

            local function release(idx)
                local w = written[idx]
                if not w then return end
                if w.baim then pcall(plist.set, idx, "Override prefer body aim", "-") end
                if w.sp then pcall(plist.set, idx, "Override safe point", "-") end
                written[idx] = nil
            end

            local function release_all()
                for idx in pairs(written) do release(idx) end
            end

            client.set_event_callback("net_update_end", function()
                local lch = config.ragebot.lc_handling:get() or {}
                local use_safety = config.ragebot.safety:get()
                local aimtools = config.ragebot.aimtools:get()
                if (not use_safety and #lch == 0 and not aimtools) or not entity_get_local_player() then
                    if next(written) then release_all() end
                    return
                end
                local on = use_safety and (config.ragebot.safety_on:get() or {}) or {}
                local misses_needed = config.ragebot.safety_misses:get()
                local low_hp = config.ragebot.safety_hp:get()
                local smart = use_safety and config.ragebot.smart_baim:get()
                local me = entity_get_local_player()
                -- what one body shot of the weapon in hand does (chest, armor, range), and whether double tap gives two
                local body_dmg, shots = nil, 1
                -- the weapon group for the aim tools
                local at
                if aimtools and entity.is_alive(me) then
                    local w = entity.get_player_weapon(me)
                    local id = w and entity_get_prop(w, "m_iItemDefinitionIndex") or 0
                    local g = (id == 40 and "Scout") or (id == 9 and "AWP") or ((id == 11 or id == 38) and "Auto") or (id == 1 and "Deagle")
                        or (id == 64 and "Revolver") or ((id == 2 or id == 3 or id == 4 or id == 30 or id == 32 or id == 36 or id == 61 or id == 63) and "Pistols")
                        or "Other"
                    local t = config.ragebot.aimtools_w[g]
                    if t then
                        at = { baim_hp = t.baim_hp:get(), baim_miss = t.baim_miss:get(), force = t.baim_force:get(),
                               sp_hp = t.sp_hp:get(), sp_miss = t.sp_miss:get() }
                    end
                end
                if (smart or (at and (at.baim_hp == 101 or at.sp_hp == 101))) and entity.is_alive(me) then
                    local wpn = entity.get_player_weapon(me)
                    local info = wpn and csgo_weapons(wpn)
                    local kind = info and info.type
                    if info and info.damage and kind ~= "knife" and kind ~= "grenade" and kind ~= "taser" and kind ~= "c4"
                        and kind ~= "shotgun" and not info.is_melee_weapon then
                        body_dmg = info
                        local dt_ok, dt_on = pcall(ui_get, reference.ragebot.doubletap.enable[1])
                        local key_ok, key_on = pcall(ui_get, reference.ragebot.doubletap.enable[2])
                        if dt_ok and dt_on and key_ok and key_on and (info.cycletime or 1) < 0.5 then shots = 2 end
                    end
                end
                local ex, ey, ez = client.eye_position()
                local function lethal(idx, hp)
                    local info = body_dmg
                    if not info or not ex then return false end
                    local ox, oy, oz = entity_get_prop(idx, "m_vecOrigin")
                    if not ox then return false end
                    local dist = math.sqrt((ox - ex) ^ 2 + (oy - ey) ^ 2 + ((oz + 40) - ez) ^ 2)
                    if info.range and dist > info.range then return false end
                    local dmg = info.damage * (info.range_modifier or 1) ^ (dist / 500)
                    if (entity_get_prop(idx, "m_ArmorValue") or 0) > 0 then dmg = dmg * (info.armor_ratio or 1) * 0.5 end
                    return dmg * shots >= hp
                end
                local seen = {}
                for _, idx in ipairs(entity.get_players(true)) do
                    seen[idx] = true
                    local d = resolver.database and resolver.database[idx]
                    local missed = d and (d.consecutive_misses or 0) >= misses_needed
                    local unsure = d and d.phit ~= nil and d.phit < 0.45
                    local sure = d and d.phit ~= nil and d.phit >= 0.8 and (d.consecutive_misses or 0) == 0
                    local hp = entity_get_prop(idx, "m_iHealth") or 100
                    -- only a teleport breaks lag comp; a tickbase shift (defensive, "shifting") leaves the other records
                    local breaking = d and d.lc_state == "breaking"
                    -- height: 64+ units above / below the enemy (stairs, boxes): the head is small and moves a lot from there
                    local height = false
                    if c_table.contains(on, "Body aim: height advantage") or c_table.contains(on, "Body aim: enemy higher") then
                        local _, _, ez_ = entity_get_prop(idx, "m_vecOrigin")
                        local _, _, mz_ = entity_get_prop(me, "m_vecOrigin")
                        if ez_ and mz_ then
                            height = (mz_ - ez_ > 64 and c_table.contains(on, "Body aim: height advantage"))
                                or (ez_ - mz_ > 64 and c_table.contains(on, "Body aim: enemy higher"))
                        end
                    end
                    local baim, head_sp
                    if smart then
                        local safe_head = d and d.phit ~= nil and d.phit * 100 >= config.ragebot.smart_conf:get()
                            and (d.consecutive_misses or 0) == 0
                        if (breaking and c_table.contains(lch, "Body aim"))
                            or (missed and c_table.contains(on, "Body aim after misses")) or height then
                            baim = "On"
                        elseif safe_head then
                            baim = "Off"
                        elseif lethal(idx, hp) or (unsure and c_table.contains(on, "Body aim when unsure")) then
                            baim = "On"
                        else
                            baim, head_sp = "Off", true
                        end
                    elseif (breaking and c_table.contains(lch, "Body aim")) or height
                        or (missed and c_table.contains(on, "Body aim after misses"))
                        or (unsure and c_table.contains(on, "Body aim when unsure"))
                        or (hp <= low_hp and c_table.contains(on, "Body aim on low HP")) then
                        baim = "On"
                    elseif sure and c_table.contains(on, "Head when sure") then
                        baim = "Off"
                    end
                    local sp_on = ((missed and c_table.contains(on, "Safe point after misses"))
                        or (breaking and c_table.contains(lch, "Safe point")) or head_sp) and true or false
                    -- aim tools of the weapon in hand: over the rules above
                    if at then
                        local m = d and d.consecutive_misses or 0
                        local function hp_rule(v) return (v == 101 and lethal(idx, hp)) or (v > 0 and v < 101 and hp <= v) end
                        if hp_rule(at.baim_hp) or (at.baim_miss > 0 and m >= at.baim_miss) then
                            baim = at.force and "Force" or "On"
                        end
                        if hp_rule(at.sp_hp) or (at.sp_miss > 0 and m >= at.sp_miss) then sp_on = true end
                    end
                    if not use_safety and not at and not breaking then baim, sp_on = nil, false end
                    put(idx, "Override prefer body aim", "baim", baim)
                    put(idx, "Override safe point", "sp", sp_on and "On" or nil)
                end
                for idx in pairs(written) do
                    if not seen[idx] then release(idx) end
                end
            end)
            client.set_event_callback("round_start", release_all)
            client.set_event_callback("shutdown", function() pcall(release_all) end)
        end

        -- Tuning page: adaptive air chance, ground / noscope scaling, weapon profiles, peek assist.
        -- Applied by the rage override block at the end of the file (it reads these through SPECTER_SHARED).
        do
            local C, S = mui.CONTENT, mui.SIDE
            local R = {}
            config.tuning = R
            R.air = menu.new_item(ui.new_checkbox, "AA", C, "Adaptive Air Chance"):record("ragebot", "air_enable"):save()
            R.air_key = menu.new_item(ui.new_hotkey, "AA", C, "\nair_hc_key", true):record("ragebot", "air_hc_key"):save()
            pcall(R.air_key.set, R.air_key, "Always on")
            R.air_hc = menu.new_item(ui.new_slider, "AA", C, "•  Hit chance\nair", 0, 100, 40, true, "%"):record("ragebot", "air_hc"):save()
            R.air_scale = menu.new_item(ui.new_slider, "AA", C, "•  Speed scaling\nair", 0, 100, 30, true, "%"):record("ragebot", "air_vel_scale"):save()
            R.air_weapon = menu.new_item(ui.new_combobox, "AA", C, "•  Weapon\nair", { "All", "Scout", "Deagle", "AWP" }):record("ragebot", "air_weapon"):save()
            R.air_dmg = menu.new_item(ui.new_slider, "AA", C, "•  Min damage\nair", 0, 126, 25, true):record("ragebot", "air_dmg"):save()
            R.air_dmg_key = menu.new_item(ui.new_hotkey, "AA", C, "•  Damage key\nair"):record("ragebot", "air_dmg_key"):save()
            R.ground = menu.new_item(ui.new_checkbox, "AA", C, "Ground HC Scaling"):record("ragebot", "ground_hc"):save()
            R.ground_min = menu.new_item(ui.new_slider, "AA", C, "•  Minimum\nground_hc", 0, 100, 50, true, "%"):record("ragebot", "ground_hc_min"):save()
            R.noscope = menu.new_item(ui.new_checkbox, "AA", C, "Noscope Hit Chance"):record("ragebot", "noscope"):save()
            R.noscope_hc = menu.new_item(ui.new_slider, "AA", C, "•  Hit chance\nnoscope", 0, 100, 45, true, "%"):record("ragebot", "noscope_hc"):save()

            R.profiles_gap = mui.spacer(C)
            R.profiles_hdr = mui.header(C, "⚖", "Weapon Profiles")
            R.profiles = menu.new_item(ui.new_checkbox, "AA", C, "Enable\nwp"):record("ragebot", "wp_enable"):save()
            R.groups = { "Auto", "AWP", "Scout", "Deagle", "Revolver", "Pistols", "Other" }
            R.group = menu.new_item(ui.new_combobox, "AA", C, "•  Weapon\nwp", R.groups):config_ignore()
            R.wp = {}
            local defaults = { Auto = { 60, 25 }, AWP = { 80, 90 }, Scout = { 70, 80 }, Deagle = { 60, 40 },
                Revolver = { 70, 60 }, Pistols = { 50, 20 }, Other = { 55, 25 } }
            for _, g in ipairs(R.groups) do
                local key = "wp_" .. g:lower()
                R.wp[g] = {
                    on = menu.new_item(ui.new_checkbox, "AA", C, "•  Override\n" .. key):record("ragebot", key .. "_on"):save(),
                    hc = menu.new_item(ui.new_slider, "AA", C, "•  Hit chance\n" .. key, 0, 100, defaults[g][1], true, "%"):record("ragebot", key .. "_hc"):save(),
                    dmg = menu.new_item(ui.new_slider, "AA", C, "•  Min damage\n" .. key, 0, 126, defaults[g][2], true):record("ragebot", key .. "_dmg"):save(),
                }
            end

            R.peek = menu.new_item(ui.new_checkbox, "AA", S, "Smart Peek Assist"):record("ragebot", "peek"):save()
            R.peek_hc = menu.new_item(ui.new_slider, "AA", S, "•  Hit chance bonus\npeek", 0, 30, 12, true, "%"):record("ragebot", "peek_hc"):save()
            R.peek_dmg = menu.new_item(ui.new_slider, "AA", S, "•  Damage bonus\npeek", 0, 30, 5, true):record("ragebot", "peek_dmg"):save()
            R.peek_scope = menu.new_item(ui.new_checkbox, "AA", S, "•  Auto-scope\npeek"):record("ragebot", "peek_scope"):save()
            R.peek_baim = menu.new_item(ui.new_checkbox, "AA", S, "•  Prefer body aim\npeek"):record("ragebot", "peek_baim"):save()
            -- movement for the aimbot: stop when landing / in the air, the knife on the way back of quick peek, peek bot
            R.hdr_move = mui.header(S, "➜", "Movement")
            R.land_stop = menu.new_item(ui.new_checkbox, "AA", S, "On-land quick stop"):record("ragebot", "land_stop"):save()
            R.air_stop = menu.new_item(ui.new_checkbox, "AA", S, "In-air quick stop"):record("ragebot", "air_stop"):save()
            R.air_stop_duck = menu.new_item(ui.new_checkbox, "AA", S, "•  Duck while air stop\nair_stop"):record("ragebot", "air_stop_duck"):save()
            R.peek_knife = menu.new_item(ui.new_checkbox, "AA", S, "Swap to knife with auto peek"):record("ragebot", "peek_knife"):save()
            -- quick peek per weapon: stop as soon as the threat is in sight / slow motion while peeking
            R.qp_weapon = menu.new_item(ui.new_combobox, "AA", S, "Quick peek options\nqp_weapon", { "Scout", "AWP", "Auto", "Pistols", "Deagle", "Other" })
                :config_ignore()
            for _, g in ipairs({ "Scout", "AWP", "Auto", "Pistols", "Deagle", "Other" }) do
                R["qp_" .. g:lower()] = menu.new_item(ui.new_multiselect, "AA", S, "•  " .. g .. "\nqp_" .. g:lower(), { "Early autostop", "Slow motion", "Move between shots" })
                    :record("ragebot", "qp_" .. g:lower()):save()
            end
            -- force shot: while the key is held, the aimbot shoots at this hit chance
            R.force_shot = menu.new_item(ui.new_hotkey, "AA", S, "Force shot"):record("ragebot", "force_shot"):save()
            R.force_shot_hc = menu.new_item(ui.new_slider, "AA", S, "•  Hit chance\nforce_shot", 0, 100, 15, true, "%")
                :record("ragebot", "force_shot_hc"):save()
            -- fake duck: the movement speed while duck peeking (0 = gamesense's own)
            R.fd_speed = menu.new_item(ui.new_slider, "AA", S, "Fake duck speed limit", 0, 150, 0, true, "u", 1, { [0] = "Off" })
                :record("ragebot", "fd_speed"):save()
            R.hdr_bot = mui.header(S, "⇆", "Peek bot")
            R.peek_bot = menu.new_item(ui.new_checkbox, "AA", S, "Peek bot"):record("ragebot", "peek_bot"):save()
            R.peek_bot_key = menu.new_item(ui.new_hotkey, "AA", S, "\npeek_bot_key", true):record("ragebot", "peek_bot_key"):save()
            R.peek_bot_dist = menu.new_item(ui.new_slider, "AA", S, "•  Distance\npeek_bot", 20, 90, 50, true, "u"):record("ragebot", "peek_bot_dist"):save()
            R.peek_bot_hitboxes = menu.new_item(ui.new_multiselect, "AA", S, "•  Hitboxes\npeek_bot", { "Head", "Chest", "Stomach" })
                :record("ragebot", "peek_bot_hitboxes"):save()
            pcall(function() R.peek_bot_hitboxes:set({ "Head", "Chest", "Stomach" }) end)
            R.peek_bot_weapons = menu.new_item(ui.new_multiselect, "AA", S, "•  Weapons\npeek_bot", { "Snipers", "Auto snipers", "Pistols", "Rifles", "Other" })
                :record("ragebot", "peek_bot_weapons"):save()
            pcall(function() R.peek_bot_weapons:set({ "Snipers", "Auto snipers", "Pistols", "Rifles", "Other" }) end)
            R.peek_bot_show = menu.new_item(ui.new_checkbox, "AA", S, "•  Show simulation\npeek_bot"):record("ragebot", "peek_bot_show"):save()
            R.peek_bot_target = menu.new_item(ui.new_combobox, "AA", S, "•  Target mode\npeek_bot", { "Current threat", "All enemies" })
                :record("ragebot", "peek_bot_target"):save()
            R.peek_bot_limit = menu.new_item(ui.new_slider, "AA", S, "•  Process limit\npeek_bot", 1, 10, 3, true, "ms")
                :record("ragebot", "peek_bot_limit"):save()

            -- fun: PP-Bizon in the air (with the air exploit): the aimbot sprays the whole mag while flying
            R.hdr_fun = mui.header(S, "☄", "Fun")
            R.bizon = menu.new_item(ui.new_checkbox, "AA", S, "Bizon air spray"):record("ragebot", "bizon"):save()
            R.bizon_key = menu.new_item(ui.new_hotkey, "AA", S, "\nbizon_key", true):record("ragebot", "bizon_key"):save()
            pcall(R.bizon_key.set, R.bizon_key, "Always on")
            R.bizon_exploit = menu.new_item(ui.new_checkbox, "AA", S, "•  Only with air exploit\nbizon"):record("ragebot", "bizon_exploit"):save()
            pcall(R.bizon_exploit.set, R.bizon_exploit, true)
            R.bizon_hc = menu.new_item(ui.new_slider, "AA", S, "•  Hit chance\nbizon", 0, 100, 5, true, "%"):record("ragebot", "bizon_hc"):save()
            R.bizon_dmg = menu.new_item(ui.new_slider, "AA", S, "•  Min damage\nbizon", 0, 100, 5, true):record("ragebot", "bizon_dmg"):save()
            R.bizon_jump = menu.new_item(ui.new_checkbox, "AA", S, "•  Auto jump\nbizon"):record("ragebot", "bizon_jump"):save()

            -- plain references for the override block at the end of the file
            SPECTER_SHARED = SPECTER_SHARED or {}
            local refs = { wp = {} }
            for k, v in pairs(R) do
                if type(v) == "table" and v.ref then refs[k] = v.ref end
            end
            for g, t in pairs(R.wp) do refs.wp[g] = { on = t.on.ref, hc = t.hc.ref, dmg = t.dmg.ref } end
            SPECTER_SHARED.rage_ui = refs
        end
    end

    config.stats = {} do
        config.stats.scope = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "View\nstats", { "Session", "Lifetime" })
            :record("stats", "scope"):save()
        config.stats.lines = {}
        for i = 1, 16 do
            config.stats.lines[i] = menu.new_item(ui.new_label, "AA", "Anti-aimbot angles", "\nstats_line_" .. i):config_ignore()
        end
        config.stats.reset = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Reset statistics", function () end)
            :config_ignore()
    end

    do
        local function new_bucket()
            return {
                shots = 0, hits = 0, misses = 0, heads = 0, kills = 0, dmg = 0,
                why = { resolver = 0, spread = 0, prediction = 0, lagcomp = 0, death = 0, other = 0 },
                methods = {}, players = {},
            }
        end

        -- the part of the resolver that forced the record a shot went at ("jitter native" = the jitter part chose native)
        local function method_of(reason)
            if reason == "desync" or reason == "jitter" or reason == "defensive" then return reason end
            return "native"
        end

        -- player names go into the gamesense database (written to disk when the script unloads): printable ASCII only,
        -- 20 characters. Raw names (accents, cyrillic, colour codes, a multi byte character cut at 32 bytes) were stored
        -- before; the dev build froze CS:GO on unload with a database full of them (owners, Oct 2026)
        local function db_name(name)
            local n = tostring(name or "?"):gsub("\a%x%x%x%x%x%x%x%x", ""):gsub("[^\32-\126]", ""):sub(1, 20)
            return n ~= "" and n or "?"
        end

        local session, lifetime = new_bucket(), new_bucket()
        do
            local ok, saved = pcall(database.read, "specter_stats")
            if ok and type(saved) == "table" and type(saved.why) == "table" then
                for k, v in pairs(new_bucket()) do
                    if saved[k] == nil then saved[k] = v end
                end
                lifetime = saved
                -- the names stored before: cleaned and written back at once, not only at unload
                local players, changed = {}, false
                for key, p in pairs(type(lifetime.players) == "table" and lifetime.players or {}) do
                    local k = db_name(key)
                    if type(p) == "table" then
                        local name = db_name(p.name)
                        changed = changed or k ~= key or name ~= p.name
                        players[k] = { name = name, h = tonumber(p.h) or 0, n = tonumber(p.n) or 0 }
                    else
                        changed = true
                    end
                end
                lifetime.players = players
                if changed then pcall(database.write, "specter_stats", lifetime) end
            end
        end

        local dirty = false
        local function save()
            if not dirty then return end
            local order = {}
            for key, p in pairs(lifetime.players) do order[#order + 1] = { key = key, n = tonumber(p.n) or 0 } end
            if #order > 200 then
                table_sort(order, function(a, b) return a.n > b.n end)
                for i = 201, #order do lifetime.players[order[i].key] = nil end
            end
            pcall(database.write, "specter_stats", lifetime)
            dirty = false
        end

        local function each(fn)
            fn(session)
            fn(lifetime)
            dirty = true
        end

        resolver.stats_hook = function(kind, shot, event, data)
            local method = method_of(shot and shot.reason)
            local key = db_name(data and data.key or tostring(event.target))
            local name = db_name(entity_get_player_name(event.target))

            if kind == "fire" then
                each(function(b) b.shots = b.shots + 1 end)
                return
            end

            each(function(b)
                local m = b.methods[method]
                if not m then m = { h = 0, n = 0 }; b.methods[method] = m end
                local p = b.players[key]
                if not p then p = { name = name, h = 0, n = 0 }; b.players[key] = p end
                p.name = name

                if kind == "hit" then
                    b.hits = b.hits + 1
                    b.dmg = b.dmg + (tonumber(event.damage) or 0)
                    if event.hitgroup == 1 then b.heads = b.heads + 1 end
                    local hp = tonumber(entity_get_prop(event.target, "m_iHealth")) or 1
                    if hp <= 0 or not entity.is_alive(event.target) then b.kills = b.kills + 1 end
                    m.h, m.n = m.h + 1, m.n + 1
                    p.h, p.n = p.h + 1, p.n + 1
                else
                    b.misses = b.misses + 1
                    local why = tostring(event.reason or "?")
                    local bucket = "other"
                    if why == "?" or why == "resolver" then
                        -- at a record that broke lag comp / at a shifted model (defensive): not the angle
                        bucket = (shot and (shot.teleported or shot.defensive)) and "lagcomp" or "resolver"
                    elseif why == "spread" or why == "prediction error" or why == "death" then
                        bucket = why == "prediction error" and "prediction" or why
                    end
                    b.why[bucket] = (b.why[bucket] or 0) + 1
                    if bucket == "resolver" then
                        m.n = m.n + 1
                        p.n = p.n + 1
                    end
                end
            end)
        end

        local function pct(a, b)
            if (b or 0) <= 0 then return 0 end
            return math_floor(a / b * 100 + 0.5)
        end

        local T, D = "\aE6E6E6FF", "\a8C8C96FF"

        local function method_text(b, name)
            local m = b.methods[name]
            if not m or m.n == 0 then return string_format("%s%s %s-", D, name, T) end
            return string_format("%s%s %s%d/%d %s(%d%%)", D, name, T, m.h, m.n, D, pct(m.h, m.n))
        end

        local function build(b)
            local A = mui.A
            local lines = {}
            local hitrate = pct(b.hits, b.hits + b.misses)
            local rc = hitrate >= 75 and "\a8CE6A0FF" or (hitrate >= 55 and "\aFFD278FF" or "\aFF7878FF")
            lines[#lines + 1] = string_format("%sShots %s%d   %sHits %s%d   %sMisses %s%d", D, T, b.shots, D, T, b.hits, D, T, b.misses)
            lines[#lines + 1] = string_format("%sHit rate %s%d%%   %sHeadshots %s%d%%", D, rc, hitrate, D, T, pct(b.heads, b.hits))
            lines[#lines + 1] = string_format("%sKills %s%d   %sDamage %s%d", D, T, b.kills, D, T, b.dmg)
            lines[#lines + 1] = A .. "Miss reasons"
            lines[#lines + 1] = string_format("%sresolver %s%d   %sspread %s%d   %sprediction %s%d", D, T, b.why.resolver or 0, D, T, b.why.spread or 0, D, T, b.why.prediction or 0)
            lines[#lines + 1] = string_format("%slagcomp %s%d   %sdeath %s%d   %sother %s%d", D, T, b.why.lagcomp or 0, D, T, b.why.death or 0, D, T, b.why.other or 0)
            lines[#lines + 1] = A .. "Resolver methods  " .. D .. "(hits / resolver shots)"
            lines[#lines + 1] = method_text(b, "desync") .. "   " .. method_text(b, "jitter")
            lines[#lines + 1] = method_text(b, "native")
            lines[#lines + 1] = "\n"

            local best, worst
            for _, p in pairs(b.players) do
                if p.n >= 3 then
                    local r = p.h / p.n
                    if not best or r > best.r then best = { p = p, r = r } end
                    if not worst or r < worst.r then worst = { p = p, r = r } end
                end
            end
            lines[#lines + 1] = A .. "Targets  " .. D .. "(3+ shots)"
            lines[#lines + 1] = best and string_format("%sbest %s%s %s%d%% (%d/%d)", D, T, best.p.name:sub(1, 18), "\a8CE6A0FF", math_floor(best.r * 100 + 0.5), best.p.h, best.p.n) or (D .. "best -")
            lines[#lines + 1] = worst and string_format("%sworst %s%s %s%d%% (%d/%d)", D, T, worst.p.name:sub(1, 18), "\aFF7878FF", math_floor(worst.r * 100 + 0.5), worst.p.h, worst.p.n) or (D .. "worst -")
            for i = 1, #lines do
                if lines[i] ~= "\n" then lines[i] = "     " .. lines[i] end
            end
            return lines
        end

        local next_refresh = 0
        client.set_event_callback("paint_ui", function()
            if not ui_is_menu_open() then return end
            if config.navigation.page() ~= "Home" then return end
            local now = globals.realtime()
            if now < next_refresh then return end
            next_refresh = now + 0.25
            local lines = build(config.stats.scope:get() == "Lifetime" and lifetime or session)
            for i = 1, #config.stats.lines do
                pcall(function() config.stats.lines[i]:set(lines[i] or "\n") end)
            end
        end)

        config.stats.reset:set_callback(function()
            if config.stats.scope:get() == "Lifetime" then
                lifetime = new_bucket()
                dirty = true
                save()
            else
                session = new_bucket()
            end
            next_refresh = 0
            c_logger.log("Statistics reset.")
        end)

        client.set_event_callback("round_end", function() pcall(save) end)
        client.set_event_callback("shutdown", function() pcall(save) end)
    end

    ---
    --- FFI
    ---
    do
        ffi_helpers = {} do
            -- every memory read goes through these: when a vtable / signature is not found (a game or gamesense update) the
            -- helper gives nil and its users fall back to the gamesense api, the script never stops on it
            local function ffi_note(what)
                client.color_log(255, 160, 90, "[specter] ffi: " .. what .. " not found, using the gamesense api for it\0")
                client.color_log(255, 255, 255, " ")
            end
            local function find_sig(module, sig)
                local ok, addr = pcall(client.find_signature, module, sig)
                if ok and addr ~= nil and addr ~= ffi.NULL then return addr end
                return nil
            end
            do
                local ok, fn = pcall(vtable_bind, 'client.dll', 'VClientEntityList003', 3, 'void*(__thiscall*)(void***, int)')
                if not ok then fn = nil; ffi_note("entity list") end
                ffi_helpers.get_client_entity = function(ent)
                    if not fn or not ent then return nil end
                    local ok2, ptr = pcall(fn, ent)
                    if not ok2 or ptr == nil or ptr == ffi.NULL then return nil end
                    return ptr
                end
            end

            ffi_helpers.animstate = {} do
                if not pcall(ffi.typeof, 'bt_animstate_t') then
                    ffi.cdef[[
                        typedef struct {
                            char __0x108[0x108];
                            bool on_ground;
                            bool hit_in_ground_animation;
                        } bt_animstate_t, *pbt_animstate_t
                    ]]
                end

                ffi_helpers.animstate.offset = 0x9960

                ffi_helpers.animstate.get = function (self, ent)
                    local client_entity = ffi_helpers.get_client_entity(ent)

                    if client_entity == nil or client_entity == ffi.NULL then     -- a NULL cdata pointer is truthy
                        return
                    end

                    return ffi.cast('pbt_animstate_t*', ffi.cast('uintptr_t', client_entity) + self.offset)[0]
                end
            end

            ffi_helpers.animlayers = {} do
                if not pcall(ffi.typeof, 'bt_animlayer_t') then
                    ffi.cdef[[
                        typedef struct {
                            float   anim_time;
                            float   fade_out_time;
                            int     nil;
                            int     activty;
                            int     priority;
                            int     order;
                            int     sequence;
                            float   prev_cycle;
                            float   weight;
                            float   weight_delta_rate;
                            float   playback_rate;
                            float   cycle;
                            int     owner;
                            int     bits;
                        } bt_animlayer_t, *pbt_animlayer_t
                    ]]
                end

                do
                    local addr = find_sig('client.dll', '\x8B\x89\xCC\xCC\xCC\xCC\x8D\x0C\xD1')
                    local ok, off = false, nil
                    if addr then ok, off = pcall(function() return ffi.cast('int*', ffi.cast('uintptr_t', addr) + 2)[0] end) end
                    -- the layers sit a few KB into the entity; anything else is a wrong signature
                    if ok and type(off) == "number" and off > 0x1000 and off < 0x10000 then
                        ffi_helpers.animlayers.offset = off
                    else
                        ffi_note("animation layers")
                    end
                end

                ffi_helpers.animlayers.get = function (self, ent)
                    if not self.offset then return nil end
                    local client_entity = ffi_helpers.get_client_entity(ent)

                    if client_entity == nil or client_entity == ffi.NULL then     -- a NULL cdata pointer is truthy
                        return
                    end

                    return ffi.cast('pbt_animlayer_t*', ffi.cast('uintptr_t', client_entity) + self.offset)[0]
                end
            end

            -- for the resolver: layer 6 (movement) playback rate of an enemy, read only. Layer values outside what the game
            -- can have (a wrong offset after an update) count against it; 30 bad reads in a row switch the reader off for good
            do
                local bad, dead = 0, false
                local function valid(x, lo, hi) return type(x) == "number" and x == x and x >= lo and x <= hi end
                resolver.read_layer6 = function(idx)
                    if dead then return nil end
                    local ok, layers = pcall(ffi_helpers.animlayers.get, ffi_helpers.animlayers, idx)
                    if not ok or layers == nil then return nil end
                    local ok2, rate, weight, cycle = pcall(function()
                        local l = layers[6]
                        return tonumber(l.playback_rate), tonumber(l.weight), tonumber(l.cycle)
                    end)
                    if ok2 and valid(rate, 0, 5) and valid(weight, 0, 1) and valid(cycle, 0, 1) then
                        bad = 0
                        if weight < 0.05 then return nil end
                        return rate
                    end
                    bad = bad + 1
                    if bad >= 30 then
                        dead = true
                        resolver.read_layer6 = nil
                        client.color_log(255, 120, 120, "[specter] resolver: animation layers look wrong, layer reading is off\0")
                        client.color_log(255, 255, 255, " ")
                    end
                    return nil
                end
            end

            ffi_helpers.activity = {} do
                if not pcall(ffi.typeof, 'bt_get_sequence') then
                    ffi.cdef[[
                        typedef int(__fastcall* bt_get_sequence)(void* entity, void* studio_hdr, int sequence);
                    ]]
                end

                ffi_helpers.activity.offset = 0x2950
                do
                    local addr = find_sig('client.dll', '\x55\x8B\xEC\x53\x8B\x5D\x08\x56\x8B\xF1\x83')
                    local ok, fn = false, nil
                    if addr then ok, fn = pcall(ffi.cast, 'bt_get_sequence', addr) end
                    if ok and fn then ffi_helpers.activity.location = fn else ffi_note("sequence activity") end
                end

                ffi_helpers.activity.get = function (self, sequence, ent)
                    if not self.location or sequence == nil then return nil end
                    local client_entity = ffi_helpers.get_client_entity(ent)

                    if client_entity == nil or client_entity == ffi.NULL then     -- a NULL cdata pointer is truthy
                        return
                    end

                    local studio_hdr = ffi.cast('void**', ffi.cast('uintptr_t', client_entity) + self.offset)[0]

                    if not studio_hdr then
                        return;
                    end

                    local ok, act = pcall(self.location, client_entity, studio_hdr, sequence)
                    return ok and act or nil
                end
            end

            ffi_helpers.user_input = {} do
                if not pcall(ffi.typeof, 'bt_cusercmd_t') then
                    ffi.cdef[[
                        typedef struct {
                            struct bt_cusercmd_t (*cusercmd)();
                            int     command_number;
                            int     tick_count;
                            float   view[3];
                            float   aim[3];
                            float   move[3];
                            int     buttons;
                        } bt_cusercmd_t;
                    ]]
                end

                if not pcall(ffi.typeof, 'bt_get_usercmd') then
                    ffi.cdef[[
                        typedef bt_cusercmd_t*(__thiscall* bt_get_usercmd)(void* input, int, int command_number);
                    ]]
                end

                do
                    local addr = find_sig('client.dll', '\xB9\xCC\xCC\xCC\xCC\x8B\x40\x38\xFF\xD0\x84\xC0\x0F\x85')
                    local ok = addr and pcall(function()
                        ffi_helpers.user_input.vtbl = ffi.cast('void***', ffi.cast('void**', ffi.cast('uintptr_t', addr) + 1)[0])
                        ffi_helpers.user_input.location = ffi.cast('bt_get_usercmd', ffi_helpers.user_input.vtbl[0][8])
                    end)
                    if not ok then
                        ffi_helpers.user_input.vtbl, ffi_helpers.user_input.location = nil, nil
                        ffi_note("usercmd")
                    end
                end

                ffi_helpers.user_input.get_command = function (self, command_number)
                    if not self.location then return nil end
                    local ok, command = pcall(self.location, self.vtbl, 0, command_number)
                    if not ok or command == nil or command == ffi.NULL then return nil end
                    -- the slot of a real usercmd carries its own number: anything else is the wrong memory (a moved
                    -- signature / vtable): its angles are garbage and writing its buttons would corrupt the game
                    local okn, number = pcall(function() return command.command_number end)
                    if not okn or number ~= command_number then return nil end
                    return command
                end
            end
        end
    end

    ---
    --- Player class
    ---
    do
        local create_player, BaseLocal do
            BaseLocal = {} do
                --- Reset player
                function BaseLocal:reset(full)
                    if full then
                        self.entindex = -1
                        self.alive = false
                    end

                    self.onground = true
                    self.velocity = vector()
                    self.speed = 0.0
                    self.duckamount = 0.0
                    self.stamina = 80.0
                    self.velocity_modifier = 1.0
                    self.fakeyaw = 0.0
                    self.server_fakeyaw = 0.0
                    self.smooth_fakeamount = 0.0
                    self.fakeamount_gram = {}
                    self.state = 'Standing'
                    self.defensive_active = false
                    self.defensive_predict = false
                    self.use_needed = false
                    self.landing = false
                    self.peeking = false
                    self.freestanding_side = 'none'
                    self._shifting_enough = false
                end

                function BaseLocal:is_onground()
                    local animstate = ffi_helpers.animstate:get(self.entindex)

                    if not animstate then
                        -- no memory read: m_fFlags, not on the tick it landed
                        local flags = entity_get_prop(self.entindex, 'm_fFlags') or 1
                        local on_ground = bit.band(flags, 1) == 1
                        local tick = globals_tickcount()
                        if on_ground and self._was_air then self._land_tick = tick end
                        self._was_air = not on_ground
                        return on_ground and self._land_tick ~= tick
                    end

                    local ptr_addr = ffi.cast('uintptr_t', ffi.cast('void*', animstate))
                    local landed_on_ground_this_frame = ffi.cast('bool*', ptr_addr + 0x120)[0]

                    return animstate.on_ground and not landed_on_ground_this_frame
                end

                function BaseLocal:get_velocity_modifier()
                    local velocity_modifier = entity_get_prop(self.entindex, 'm_flVelocityModifier')

                    if self.stamina > 0.01 and self.onground then
                        local flSpeedScale = c_math.clamp(1.0 - self.stamina * 0.01, 0.0, 1.0)

                        flSpeedScale = flSpeedScale * flSpeedScale

                        velocity_modifier = velocity_modifier * flSpeedScale
                    end

                    return velocity_modifier
                end

                --- Get player state
                function BaseLocal:get_state()
                    if not self.onground then
                        if self.duckamount > 0.5 then
                            return 'Air & Crouch'
                        else
                            return 'Air'
                        end
                    end

                    if self.duckamount > 0.5 or ui_get(reference.ragebot.fakeduck) then
                        if self.speed > 4 then
                            return 'Crouch moving'
                        else
                            return 'Crouching'
                        end
                    end

                    local slowmotion_state = c_table.is_hotkey_active(reference.misc.slowmotion)

                    if slowmotion_state then
                        return 'Slow-motion'
                    end

                    if self.speed > 4 then
                        return 'Moving'
                    end

                    return 'Standing'
                end

                local tickbase_max = 0

                function BaseLocal:get_defensive()
                    local tickbase = entity_get_prop(self.entindex, 'm_nTickBase')

                    if c_math.abs(tickbase - tickbase_max) > 64 then
                        tickbase_max = 0
                    end

                    local defensive_ticks_left = 0;

                    if tickbase > tickbase_max then
                        tickbase_max = tickbase
                    elseif tickbase_max > tickbase then
                        defensive_ticks_left = c_math.min(14, c_math.max(0, tickbase_max-tickbase-1))
                    end

                    return defensive_ticks_left > 2
                end

                BaseLocal.is_use_needed = (function (self, wpn)
                    if wpn then
                        local wpn_classname = entity.get_classname(wpn)

                        if wpn_classname == 'CC4' then
                            return true
                        end
                    end

                    local my_origin = vector(entity.get_origin(self.entindex))
                    local team_num = entity_get_prop(self.entindex, 'm_iTeamNum')
                    local planted_ents = entity.get_all('CPlantedC4')

                    for i=1, #planted_ents do
                        local c4 = planted_ents[i]
                        local m_hDefuser = entity_get_prop(c4, 'm_hDefuser')
                        local c4_origin = vector(entity.get_origin(c4))

                        if m_hDefuser == self.entindex or team_num == 3 and c4_origin:dist(my_origin) < 87.5 then
                            return true
                        end
                    end

                    local hostage_ents = entity.get_all('CHostage')

                    for i=1, #hostage_ents do
                        local hostage = hostage_ents[i]
                        local hostage_origin = vector(entity.get_origin(hostage))

                        if hostage_origin:dist(my_origin) < 50 and team_num == 3 then
                            return true
                        end
                    end

                    local head_origin = vector(client.eye_position())
                    local angles = vector():init_from_angles(client.camera_angles())
                    local end_point = head_origin + angles * 128

                    local fraction, ent = client_trace_line(self.entindex, head_origin.x, head_origin.y, head_origin.z, end_point.x, end_point.y, end_point.z)

                    if ent ~= -1 and fraction ~= 1.0 then
                        local cname = entity.get_classname(ent)

                        if cname ~= nil and cname ~= 'CWorld' and cname ~= 'CCSPlayer' and cname ~= 'CFuncBrush' then
                            return true
                        end
                    end

                    return false
                end)

                function BaseLocal:threat_yaw()
                    local aa_threat = client.current_threat()

                    if not aa_threat then
                        return
                    end

                    local my_origin = vector(entity.get_origin(self.entindex))
                    local _, threat_yaw = my_origin:to(vector(entity.get_origin(aa_threat))):angles()

                    return threat_yaw
                end

                BaseLocal.get_side = (function (self, target)
                    local local_pos, enemy_pos = vector(entity.hitbox_position(self.entindex, 0)), vector(entity.hitbox_position(target, 0))

                    local _, yaw = (local_pos-enemy_pos):angles()
                    local l_dir, r_dir = vector():init_from_angles(0, yaw+90), vector():init_from_angles(0, yaw-90)
                    local l_pos, r_pos = local_pos + l_dir * 110, local_pos + r_dir * 110

                    local fraction = client_trace_line(target, enemy_pos.x, enemy_pos.y, enemy_pos.z, l_pos.x, l_pos.y, l_pos.z)
                    local fraction_s = client_trace_line(target, enemy_pos.x, enemy_pos.y, enemy_pos.z, r_pos.x, r_pos.y, r_pos.z)

                    if fraction > fraction_s then
                        return 'left'
                    elseif fraction_s > fraction then
                        return 'right'
                    elseif fraction == fraction_s then
                        return 'none'
                    end

                    return 'none'
                end)

                function BaseLocal:get_weapon_type(wpn)
                    if not wpn then
                        return false
                    end

                    local wpn_info = csgo_weapons(wpn)

                    if not wpn_info then
                        return false
                    end

                    return wpn_info.type
                end

                do
                    local defensive_tick = 0
                    local native_GetClientEntity do
                        local ok, fn = pcall(vtable_bind, 'client.dll', 'VClientEntityList003', 3, 'void*(__thiscall*)(void*, int)')
                        native_GetClientEntity = ok and fn or nil
                    end
                    -- without the memory read: the networked tick base falls behind the highest one seen while a shift lasts
                    local max_tickbase = 0
                    local function defensive_from_tickbase(lp)
                        local tickbase = entity_get_prop(lp, "m_nTickBase")
                        if not tickbase then return false end
                        if tickbase > max_tickbase or max_tickbase - tickbase > 64 then max_tickbase = tickbase end
                        return max_tickbase - tickbase > 2
                    end

                    function BaseLocal:handle_defensive()
                        local lp = entity_get_local_player()

                        if lp and entity.is_alive(lp) then
                            local Entity
                            if native_GetClientEntity then
                                local ok, ptr = pcall(native_GetClientEntity, lp)
                                Entity = ok and ptr or nil
                            end
                            if Entity == nil or Entity == ffi.NULL then return defensive_from_tickbase(lp) end     -- a NULL cdata pointer is truthy
                            local m_flOldSimulationTime = ffi.cast("float*", ffi.cast("uintptr_t", Entity) + 0x26C)[0]
                            local m_flSimulationTime = entity_get_prop(lp, "m_flSimulationTime") or 0

                            local delta = m_flOldSimulationTime - m_flSimulationTime

                            if delta > 0 then
                                defensive_tick = globals_tickcount() + toticks(delta - client.real_latency())
                            end
                        end

                        return globals_tickcount() <= defensive_tick - 2
                    end
                end

                -- Peek detection: which enemy could hit our stomach a few ticks ahead (autowall). Autowall + bone setup for EVERY
                -- enemy on EVERY tick was the most expensive thing the script did on a full server. Now the current threat and
                -- the last target are traced every tick, the others in turns (PEEK_BUDGET per tick); a result is kept PEEK_TTL ticks.
                local PEEK_BUDGET, PEEK_TTL = 2, 8
                local peek_cache, peek_turn = {}, 0

                BaseLocal.set_peeking_state = (function (self, me)
                    local target, cross_target, last_dmg, best_yaw = nil, nil, 0, 362
                    local is_peeking = false
                    local tick = globals_tickcount()

                    local enemy_list = entity.get_players(true)
                    local camera_angles = vector(client.camera_angles())
                    local stomach_origin = vector(entity.hitbox_position(me, 2))
                    local stomach_future = c_math.extrapolate(me, stomach_origin, 16)

                    local n = #enemy_list
                    local fresh = {}
                    local threat = client.current_threat()
                    if threat then fresh[threat] = true end
                    if self._peek_target then fresh[self._peek_target] = true end
                    for _ = 1, math_min(PEEK_BUDGET, n) do
                        peek_turn = peek_turn % n + 1
                        fresh[enemy_list[peek_turn]] = true
                    end

                    for idx=1, n do
                        local ent = enemy_list[idx]
                        local c = peek_cache[ent]

                        if fresh[ent] or not c or tick - c.tick > PEEK_TTL or tick < c.tick then
                            c = c or {}
                            c.tick, c.head, c.dmg = tick, nil, 0
                            if entity.get_player_weapon(ent) then
                                local hx, hy, hz = entity.hitbox_position(ent, 2)
                                if hx then
                                    c.head = vector(hx, hy, hz)
                                    local entindex, damage = client.trace_bullet(ent, hx, hy, hz, stomach_future.x, stomach_future.y, stomach_future.z)
                                    c.dmg = (entindex == -1 or not damage) and 0 or damage
                                end
                            end
                            peek_cache[ent] = c
                        end

                        if c.head then
                            if c.dmg > 0 then
                                is_peeking = true
                            end

                            if c.dmg > last_dmg then
                                target = ent
                                last_dmg = c.dmg
                            end

                            local _, yaw = (stomach_origin-c.head):angles()
                            local base_diff = c_math.abs(camera_angles.y-yaw)

                            if base_diff < best_yaw then
                                cross_target = ent
                                best_yaw = base_diff
                            end
                        end
                    end

                    -- players that left / died: their cached results go
                    if tick % 64 == 0 then
                        for ent, c in pairs(peek_cache) do
                            if tick - c.tick > 64 or tick < c.tick then peek_cache[ent] = nil end
                        end
                    end

                    if not target then
                        target = cross_target
                    end

                    self._peek_target = target
                    self.peeking = is_peeking
                    self.fs_side = target and self:get_side(target) or 'none'
                end)

                function BaseLocal:get_double_tap()
                    return self._shifting_enough
                end

                function BaseLocal:run_command(cmd)
                    local me = entity_get_local_player()

                    if me then
                        local m_nTickBase = entity_get_prop(me, 'm_nTickBase')
                        local client_latency = client.latency()
                        local shift = math_floor(m_nTickBase - globals_tickcount() - 3 - toticks(client_latency) * .5 + .5 * (client_latency * 10))

                        local wanted = -14 + (ui_get(reference.ragebot.doubletap.fakelag) - 1) + 3

                        self._shifting_enough = shift <= wanted
                    end
                end

                function BaseLocal:predict_command(cmd, me, wpn)
                    if not self.valid then
                        return self:reset(true)
                    end

                    self.entindex = me
                    self.alive = entity.is_alive(self.entindex)

                    if self.alive then
                        local animstate = ffi_helpers.animstate:get(me) or {}

                        self.onground = self:is_onground()
                        self.defensive_predict = self:handle_defensive()
                        self.velocity = vector(entity_get_prop(me, 'm_vecVelocity'))
                        self.speed = self.velocity:length()
                        self.duckamount = entity_get_prop(me, 'm_flDuckAmount')
                        self.stamina = entity_get_prop(me, 'm_flStamina')
                        self.velocity_modifier = self:get_velocity_modifier()
                        self.state = self:get_state()
                        self.landing = animstate.hit_in_ground_animation
                        local tick = globals_tickcount()
                        if self._peek_tick ~= tick then
                            self._peek_tick = tick
                            self:set_peeking_state(me)
                        end
                    else
                        self:reset()
                    end
                end

                function BaseLocal:setup_command(cmd, me, wpn)
                    if not self.valid then
                        return self:reset(true)
                    end

                    self.entindex = me
                    self.alive = entity.is_alive(self.entindex)

                    if cmd.chokedcommands == 0 then
                        self.packets = self.packets + 1

                        c_grams.update_gram(self.fakeamount_gram, c_math.abs(self.fakeyaw), 8)

                        self.smooth_fakeamount = c_grams.average(self.fakeamount_gram)
                        self.server_fakeyaw = entity_get_prop(me, 'm_flPoseParameter', 11) * 120 - 60
                        self.weapon_type = self:get_weapon_type(wpn)
                        self.use_needed = self:is_use_needed(wpn)
                    end
                end

                function BaseLocal:finish_command(cmd, me, wpn)
                    local command = ffi_helpers.user_input:get_command(cmd.command_number)

                    if not command and me then
                        -- no usercmd read: the networked body yaw pose parameter
                        local pose = entity_get_prop(me, 'm_flPoseParameter', 11)
                        if type(pose) == "number" then self.fakeyaw = pose * 120 - 60 end
                    end

                    if command then
                        if cmd.chokedcommands == 0 and self._last_yaw then
                            local cheat_dsy = c_math.normalize_yaw(self._last_yaw - command.view[1])

                            self.fakeyaw = -(cheat_dsy > 0 and cheat_dsy - 60 or cheat_dsy + 60)
                        elseif cmd.chokedcommands ~= 0 then
                            self._last_yaw = command.view[1]
                        end
                    end
                end

                function BaseLocal:net_update_end()
                    if not self.valid then
                        return self:reset(true)
                    end

                    if self.alive then
                        self.defensive_active = self:get_defensive()
                    end
                end

                function BaseLocal:paint_ui()
                    local me = entity_get_local_player()

                    self.valid = me ~= nil

                    if me then
                        self.entindex = me
                        self.alive = entity.is_alive(me)
                    end
                end
            end

            --- Create player object
            create_player = function ()
                return setmetatable({
                    valid = false,
                    entindex = -1,
                    packets = 0,
                    onground = true,
                    velocity = vector(),
                    speed = 0.0,
                    duckamount = 0.0,
                    stamina = 80.0,
                    velocity_modifier = 1.0,
                    fakeyaw = 0.0,
                    server_fakeyaw = 0.0,
                    smooth_fakeamount = 0.0,
                    fakeamount_gram = {},
                    state = 'Standing',
                    defensive_active = false,
                    defensive_predict = false,
                    use_needed = false,
                    weapon_type = nil,
                    landing = false,
                    peeking = false,
                    freestanding_side = 'none',
                    air_exploit = false,
                    _shifting_enough = false
                }, {
                    __index = BaseLocal
                })
            end
        end

        player = create_player()
    end

    ---
    --- Fake lag
    ---
    local fakelag do

        fakelag = {} do
            fakelag.choking = false
            fakelag.last_choke = 0
            fakelag.choke_count = 0
            fakelag.tick = 0
            fakelag.reset = false
            fakelag.target = 1
            fakelag.phase = false
            fakelag.was_air = false
            fakelag.land_tick = -100

            local function has(list, name)
                return type(list) == "table" and c_table.contains(list, name)
            end

            -- the fewest choked ticks that move us more than 64 units between two sent packets (the server drops our old
            -- records then: lag compensation is broken). Horizontal + vertical (gravity in the air); nil when not possible
            fakelag.lc_ticks = function (self, me, on_ground)
                local vx, vy, vz = entity_get_prop(me, "m_vecVelocity")
                vx, vy, vz = vx or 0, vy or 0, vz or 0
                local g = cvar.sv_gravity:get_float()
                local ti = globals_tickinterval()
                for n = 1, 15 do
                    local t = (n + 1) * ti
                    local dz = on_ground and 0 or (vz * t - 0.5 * g * t * t)
                    if (vx * t) ^ 2 + (vy * t) ^ 2 + dz * dz > 66 * 66 then return n end
                end
                return nil
            end

            -- what the server got from us: our origin at every new simulation time. More than 64 units from the last one =
            -- our lag compensation is broken (the enemy can only shoot the newest record, extrapolated)
            fakelag.lc = { broken = false, dist = 0, since = -100 }
            client.set_event_callback("net_update_end", function()
                local me = entity_get_local_player()
                if not me or not entity.is_alive(me) then fakelag.lc.last = nil; return end
                local sim = entity_get_prop(me, "m_flSimulationTime")
                local x, y, z = entity_get_prop(me, "m_vecOrigin")
                if not (sim and x) then return end
                local L = fakelag.lc
                if L.last and sim > L.last[4] then
                    local dx, dy, dz = x - L.last[1], y - L.last[2], z - L.last[3]
                    L.dist = math_sqrt(dx * dx + dy * dy + dz * dz)
                    L.broken = L.dist > 64
                    if L.broken then L.since = globals_tickcount() end
                end
                if not L.last or sim ~= L.last[4] then L.last = { x, y, z, sim } end
                player.lc_broken = L.broken
            end)

            fakelag.pick_limit = function (self, me, cmd)
                local base = config.fakelag.ticks:get()
                local mode = config.fakelag.type:get()
                local flags = entity_get_prop(me, "m_fFlags") or 0
                local on_ground = bit.band(flags, 1) == 1
                local vx, vy = entity_get_prop(me, "m_vecVelocity")
                local speed = math_sqrt((vx or 0) * (vx or 0) + (vy or 0) * (vy or 0))
                local tick = globals_tickcount()

                if on_ground and self.was_air then self.land_tick = tick end
                self.was_air = not on_ground

                local limit = base
                if mode == "Cycle" then
                    limit = base - self.tick % 5
                elseif mode == "Randomize" then
                    limit = base - c_math.random(0, 5)
                elseif mode == "Fluctuate" then
                    limit = self.phase and base or math_max(1, math_floor(base / 2))
                elseif mode == "Adaptive" then
                    if not on_ground then
                        limit = 15
                    elseif speed < 5 then
                        limit = math_max(2, math_floor(base / 3))
                    elseif speed < 100 then
                        limit = math_max(3, math_floor(base * 0.7))
                    else
                        limit = base
                    end
                end

                local variance = config.fakelag.variance:get()
                if variance > 0 and mode ~= "Static" then
                    limit = limit - c_math.random(0, math_floor(limit * variance / 100))
                end

                local triggers = config.fakelag.triggers:get()
                if (has(triggers, "Peek") and player.peeking)
                    or (has(triggers, "Air") and not on_ground)
                    or (has(triggers, "Landing") and tick - self.land_tick < 8)
                    or (has(triggers, "Damage received") and (player.velocity_modifier or 1) < 1)
                    or (has(triggers, "Weapon switch") and cmd.weaponselect ~= 0) then
                    limit = 15
                end

                if config.fakelag.smart_lc:get() and speed > 1 then
                    local where = config.fakelag.lc_on and config.fakelag.lc_on:get() or { "In air" }
                    if (not on_ground and has(where, "In air")) or (on_ground and has(where, "On ground"))
                        or (player.peeking and has(where, "On peek")) then
                        local needed = self:lc_ticks(me, on_ground)
                        if needed then limit = math_max(limit, needed) end
                    end
                end

                return c_math.clamp(limit, 1, 15)
            end

            fakelag.setup_command = function (self, cmd, me, wpn)
                if config.fakelag.enable:get() then
                    local fakeduck_active = ui_get(reference.ragebot.fakeduck)
                    local onshot_active = c_table.is_hotkey_active(reference.misc.onshot_antiaim)
                    local doubletap_active = c_table.is_hotkey_active(reference.ragebot.doubletap.enable)

                    override.set(reference.fakelag.enable[1], true)
                    override.set(reference.fakelag.amount, player.weapon_type == 'grenade' and 'Dynamic' or 'Maximum')
                    override.set(reference.fakelag.limit, 15)
                    override.set(reference.fakelag.variance, 0)

                    if cmd.chokedcommands == 0 then
                        self.target = self:pick_limit(me, cmd)
                    end

                    local exploits_active = doubletap_active or onshot_active

                    if not exploits_active and player.weapon_type ~= 'grenade' and not fakeduck_active then
                        if cmd.chokedcommands < self.target then
                            cmd.allow_send_packet = false
                        else
                            self.tick = self.tick + 1
                            self.phase = not self.phase
                            cmd.no_choke = true
                        end
                    end

                    self.reset = false
                elseif not self.reset then
                    override.unset(reference.fakelag.enable[1])
                    override.unset(reference.fakelag.amount)
                    override.unset(reference.fakelag.limit)
                    override.unset(reference.fakelag.variance)

                    self.reset = true
                end

                if cmd.chokedcommands == 0 then
                    self.last_choke = self.choke_count
                    self.choke_count = 0;
                else
                    self.choke_count = self.choke_count + 1;
                end

                self.choking = self.last_choke >= 2;
            end
        end
    end

    ---
    --- Anti-aim
    ---
    local antiaimbot do
        antiaimbot = {}

        config.antiaimbot = {} do

            config.antiaimbot.hdr_mods = mui.header(mui.SIDE, "✦", "Modifications")
            config.antiaimbot.options = menu.new_item(ui.new_multiselect, "AA", "Other", "Modifications", {
                "On use antiaim",
                "Fast ladder"
            }):record("antiaimbot", "options"):save()
            config.antiaimbot.preset = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "Preset\naa",
                TIER.HAS_BUILDER and { "Specter Delay", "Specter 3-Way", "Specter Distort", "Constructor" }
                or { "Specter Delay", "Specter 3-Way", "Specter Distort" }
            ):record("antiaimbot", "preset"):save()
            config.uix.builder_hint = mui.hint(mui.CONTENT, "presets are fixed  ·  pick Constructor to edit states")

            config.resolver = {} do
            if TIER.HAS_RESOLVER then
                config.resolver.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Enable Resolver")
                    :record("resolver", "enabled"):save()
                pcall(function() config.resolver.enabled:set(true) end)
                -- what the resolver does with the current threat (the dynamic resolver's info lines)
                local function info()
                    local t = client.current_threat()
                    return t and resolver.database[t], t
                end
                config.resolver.info = {
                    mui.row(mui.CONTENT, "◎", "Target", function()
                        local d, t = info()
                        return d and (entity.get_player_name(t) or "-") or "-"
                    end),
                    mui.row(mui.CONTENT, "≡", "Method", function()
                        local d = info()
                        return d and d.method and (d.method .. "  ·  " .. (d.model_name or "-")) or "-"
                    end),
                    mui.row(mui.CONTENT, "∠", "Desync", function()
                        local d = info()
                        if not (d and d.value) then return "-" end
                        return string_format("%d°  %s", math.abs(d.value), d.value > 0 and "R" or (d.value < 0 and "L" or "-"))
                    end),
                    mui.row(mui.CONTENT, "⇄", "Lag comp", function()
                        local d = info()
                        local them = d and d.lc_state and (d.lc_state == "ok" and "ok" or (d.lc_state .. string_format(" %du", math.floor(d.lc_dist or 0)))) or "-"
                        local choke = d and d.choke and ("  ·  choke " .. d.choke) or ""
                        return them .. choke .. "  ·  ours " .. (player and player.lc_broken and "broken" or "ok")
                    end),
                    mui.row(mui.CONTENT, "✓", "Confidence", function()
                        local d = info()
                        return d and d.phit and (math.floor(d.phit * 100 + 0.5) .. "%") or "-"
                    end),
                }
                config.resolver.log = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Show angle in hitlog\nresolver")
                    :record("resolver", "log"):save()
                -- the resolver's numbers for the ping (0 .. 150 ms, steps of 5)
                config.resolver.ping_scale = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Ping scale\nresolver")
                    :record("resolver", "ping_scale"):save()
                pcall(function() config.resolver.ping_scale:set(true) end)
                config.resolver.ping_mode = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Ping\nresolver_ping", { "Auto", "Manual" })
                    :record("resolver", "ping_mode"):save()
                config.resolver.ping_manual = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Ping value\nresolver_ping", 0, 150, 50, true, "ms")
                    :record("resolver", "ping_manual"):save()
                config.resolver.ping_row = mui.row(mui.CONTENT, "◷", "Ping profile", function()
                    local st = resolver.ping_state
                    if not (st and st.bucket) then return "default" end
                    return string_format("%d ms", st.bucket)
                end)
                config.uix.res_hint = mui.hint(mui.CONTENT, "computes the body yaw like the server, learns the rest from every shot")
                client.set_event_callback("paint_ui", function()
                    if not ui_is_menu_open() then return end
                    for _, row in ipairs(config.resolver.info) do mui.refresh(row) end
                    if config.resolver.ping_row then mui.refresh(config.resolver.ping_row) end
                end)
                config.resolver.reset = menu.new_item(ui.new_button, "AA", "Other", "Reset memory\nresolver", function()
                    resolver.reset_all()
                    c_logger.log("Resolver memory cleared.")
                end)
            end
            end

            -- Resolver safety (owners, Oct 2026: on the Resolver page): per enemy, from what the resolver knows about it.
            -- Body aim / safe point after the resolver missed it, when the resolver is unsure of the angle of the newest
            -- record, or when the enemy is low; head when the resolver is sure. Written to the player list (only on
            -- change), given back when it does not apply any more. Created after the resolver's items: gamesense shows
            -- them in that order
            config.ragebot.safety = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Resolver Safety")
                :record("ragebot", "safety"):save()
            config.ragebot.safety_on = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Options\nsafety", {
                "Body aim after misses", "Safe point after misses", "Body aim when unsure", "Body aim on low HP", "Head when sure",
                "Body aim: height advantage", "Body aim: enemy higher"
            }):record("ragebot", "safety_on"):save()
            pcall(function() config.ragebot.safety_on:set({ "Body aim after misses", "Safe point after misses", "Body aim on low HP", "Head when sure" }) end)
            config.ragebot.safety_misses = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Misses\nsafety", 1, 5, 2)
                :record("ragebot", "safety_misses"):save()
            config.ragebot.safety_hp = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Low HP\nsafety", 1, 100, 50, true, " hp")
                :record("ragebot", "safety_hp"):save()
            -- Smart body aim: the head when it is safe (the resolver is sure of the angle and has not missed since), even when a
            -- body shot would kill. Not safe: the body when a body shot kills (this weapon's damage at this distance, the armor,
            -- two shots with double tap), else the head on safe points only (points inside the head whatever the resolver
            -- guessed). Body after the resolver missed, or when the enemy really breaks lag comp (teleport); a tickbase shift
            -- (defensive) does not: the normal records stay backtrackable
            config.ragebot.smart_baim = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "•  Smart body aim\nsafety")
                :record("ragebot", "smart_baim"):save()
            pcall(function() config.ragebot.smart_baim:set(true) end)
            -- the resolver's confidence from which the head counts as safe (then head even when a body shot would kill)
            config.ragebot.smart_conf = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Safe head from\nsafety", 40, 95, 70, true, "%")
                :record("ragebot", "smart_conf"):save()

            config.antiaimbot.defensive_aa = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Defensive AA")
                :record("antiaimbot", "defensive_aa")
                :save()

            config.antiaimbot.force_target_yaw = menu.new_item(ui.new_checkbox, "AA", "Other", "Force target yaw\ndefensive")
                :record("antiaimbot", "force_target_yaw")
                :save()

            config.antiaimbot.defensive_target = menu.new_item(ui.new_multiselect, "AA", "Other", "Active with\ndefensive", {
                "Double tap",
                "On shot anti-aim"
            }):record("antiaimbot", "defensive_target"):save()

            config.antiaimbot.defensive_conditions = menu.new_item(ui.new_multiselect, "AA", "Other", "Force on states\ndefensive", c_constant.STATE_LIST)
                :record("antiaimbot", "defensive_conditions")
                :save()

            config.antiaimbot.defensive_triggers = menu.new_item(ui.new_multiselect, "AA", "Other", "Triggers\ndefensive", {
                "Flashed",
                "Damage received",
                "Reloading",
                "Weapon switch",
                "After shot",
                "Enemy visible",
                "On peek",
                "Landing",
                "Low HP",
                "Threat scoped"
            }):record("antiaimbot", "defensive_triggers"):save()

            config.antiaimbot.defensive_preset = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Preset\ndefensive", {
                "Auto",
                "Constructor"
            }):record("antiaimbot", "defensive_preset"):save()

            config.antiaimbot.defensive_conditions_auto = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Conditions\ndefensive_auto", c_table.combine_arrays(c_constant.DEFENSIVE_STATES, c_constant.STATE_LIST))
                :record("antiaimbot", "defensive_conditions_auto")
                :save()

            -- desync inverter: while active the body yaw side picked by the preset / builder is flipped
            config.antiaimbot.hdr_angles = mui.header(mui.CONTENT, "↻", "Angles")
            config.antiaimbot.inverter = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "Inverter")
                :record("antiaimbot", "inverter"):save()

            config.antiaimbot.hdr_cond = mui.header(mui.CONTENT, "◇", "Conditional AA")
            config.antiaimbot.safe_head = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Safe Head")
                :record("antiaimbot", "safe_head")
                :save()

            config.antiaimbot.safe_head_conditions = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Conditions\nsafe_head", {
                "Air knife",
                "Air zeus",
                "Air & Crouch",
                "Crouch moving",
                "Crouching",
                "Slow-motion",
                "Standing"
            }):record("antiaimbot", "safe_head_conditions"):save()

            config.antiaimbot.warmup_aa = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Warmup AA")
                :record("antiaimbot", "warmup_aa")
                :save()

            config.antiaimbot.warmup_aa_conditions = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Conditions\nwarmup_aa", {
                "Warmup",
                "Round end"
            }):record("antiaimbot", "warmup_aa_conditions"):save()

            config.antiaimbot.hdr_anim = mui.header(mui.CONTENT, "☍", "Animation")
            config.antiaimbot.animation_breaker = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Animation Breaker")
                :record("antiaimbot", "animation_breaker")
                :save()

            config.antiaimbot.animation_breaker_leg = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Leg movement\nanim", {
                "Off",
                "Frozen",
                "Walking",
                "Sliding",
                "Jitter"
            }):record("antiaimbot", "animation_breaker_leg"):save()

            config.antiaimbot.animation_breaker_air = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  In air\nanim", {
                "Off",
                "Frozen",
                "Walking"
            }):record("antiaimbot", "animation_breaker_air"):save()

            config.antiaimbot.animation_breaker_other = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Other\nanim", {
                "Slide on slow-motion",
                "Slide on crouching",
                "Quick peek legs",
                "Pitch zero on land"
            }):record("antiaimbot", "animation_breaker_other"):save()

            config.antiaimbot.air_exploit = menu.new_item(ui.new_checkbox, "AA", "Other", "Air Exploit")
                :record("antiaimbot", "air_exploit")
                :save()

            config.antiaimbot.air_exploit_hotkey = menu.new_item(ui.new_hotkey, "AA", "Other", "\nair_exploit_hotkey", true)
                :record("antiaimbot", "air_exploit_hotkey")
                :save()

            config.antiaimbot.ideal_tick = menu.new_item(ui.new_checkbox, "AA", "Other", "Ideal Tick")
                :record("antiaimbot", "ideal_tick")
                :save()

            config.antiaimbot.ideal_tick_hotkey = menu.new_item(ui.new_hotkey, "AA", "Other", "\nideal_tick_hotkey", true)
                :record("antiaimbot", "ideal_tick_hotkey")
                :save()

            config.antiaimbot.hdr_ab = mui.header(mui.CONTENT, "⇄", "Anti-bruteforce")
            config.antiaimbot.anti_brute = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Anti Bruteforce")
                :record("antiaimbot", "anti_brute"):save()

            config.antiaimbot.anti_brute_triggers = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Trigger on\nanti_brute", { "Hit", "Near miss" })
                :record("antiaimbot", "anti_brute_triggers"):save()
            pcall(function() config.antiaimbot.anti_brute_triggers:set({ "Hit", "Near miss" }) end)
            -- under the crosshair while anti brute is active: the stage and the time left
            config.antiaimbot.anti_brute_indicator = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "•  Crosshair indicator\nanti_brute")
                :record("antiaimbot", "anti_brute_indicator"):save()
            pcall(function() config.antiaimbot.anti_brute_indicator:set(true) end)

            config.antiaimbot.backtrack_optimization = menu.new_item(ui.new_checkbox, "AA", "Other", "Backtrack optimization\nlegacy")
                :record("antiaimbot", "backtrack_optimization")
                :save()

            config.antiaimbot.hdr_manual = mui.header(mui.CONTENT, "➤", "Manual & freestanding")
            config.antiaimbot.manual_yaw = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Manual Yaw")
                :record("antiaimbot", "manual_yaw")
                :save()

            config.manuals = {
                menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "•  Left\nmanual")
                    :record("manuals", "left")
                    :save(),
                menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "•  Right\nmanual")
                    :record("manuals", "right")
                    :save(),
                menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "•  Back\nmanual")
                    :record("manuals", "backward")
                    :save(),
                menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "•  Forward\nmanual")
                    :record("manuals", "forward")
                    :save(),
                menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "•  Reset\nmanual")
                    :record("manuals", "reset")
                    :save()
            }

            config.antiaimbot.edge_yaw = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "•  Edge yaw\nmanual")
                :record("manuals", "edge")
                :save()

            config.antiaimbot.freestanding = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "•  Freestanding\nmanual")
                :record("manuals", "freestanding")
                :save()

            -- "Body freestanding": the yaw keeps its jitter, the body (head) goes to the side the wall covers. "Jitter
            -- disabled" does that too and also stops the jitter
            config.antiaimbot.manual_options = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Manual options", {
                "Jitter disabled",
                "Body freestanding",
            }):record("antiaimbot", "manual_options"):save()

            config.antiaimbot.fs_options = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Freestand options", {
                "Jitter disabled",
                "Body freestanding",
            }):record("antiaimbot", "fs_options"):save()

            config.antiaimbot.freestanding_disabler_states = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Freestand ignore", c_constant.STATE_LIST)
                :record("antiaimbot", "freestanding_disabler_states")
                :save()

        end

        do
            local create_antiaim, AntiAim do
                AntiAim = {} do
                    function AntiAim:reset()
                        override.unset(reference.antiaim.pitch.type)
                        override.unset(reference.antiaim.pitch.value)

                        override.unset(reference.antiaim.yaw.base)
                        override.unset(reference.antiaim.yaw.edge)

                        override.unset(reference.antiaim.freestanding[1])
                        override.unset(reference.antiaim.freestanding[2])

                        override.unset(reference.antiaim.yaw.yaw.type)
                        override.unset(reference.antiaim.yaw.yaw.value)

                        override.unset(reference.antiaim.yaw.jitter.type)
                        override.unset(reference.antiaim.yaw.jitter.value)

                        override.unset(reference.antiaim.body.yaw.type)
                        override.unset(reference.antiaim.body.yaw.value)

                        override.unset(reference.antiaim.body.freestanding)
                    end

                    function AntiAim:tick()
                        self.pitch = nil
                        self.pitch_custom = nil
                        self.yaw_base = nil
                        self.edge_yaw = nil
                        self.freestand = nil
                        self.yaw_type = nil
                        self.yaw_offset = nil
                        self.yaw_modifier = nil
                        self.modifier_offset = nil
                        self.left_limit = nil
                        self.right_limit = nil
                        self.body_yaw_type = nil
                        self.body_yaw_value = nil
                        self.inverter = nil
                        self.body_yaw_freestanding = nil
                    end

                    function AntiAim:run()
                        local pitch = self.pitch or 'Minimal';
                        local pitch_value = self.pitch_custom or 89

                        override.set(reference.antiaim.pitch.type, pitch)
                        override.set(reference.antiaim.pitch.value, pitch_value)

                        local yaw_base = self.yaw_base or 'At targets'

                        override.set(reference.antiaim.yaw.base, yaw_base)

                        local edge_yaw = self.edge_yaw or false

                        override.set(reference.antiaim.yaw.edge, edge_yaw)

                        local freestanding = self.freestand or false

                        override.set(reference.antiaim.freestanding[1], freestanding)

                        if freestanding then
                            override.set(reference.antiaim.freestanding[2], 'Always on', 0x0)
                        else
                            override.set(reference.antiaim.freestanding[2], 'On hotkey', 0x0)
                        end

                        local yaw_type = self.yaw_type or '180'
                        local yaw_offset = self.yaw_offset or 0

                        override.set(reference.antiaim.yaw.yaw.type, yaw_type)
                        override.set(reference.antiaim.yaw.yaw.value, yaw_offset)

                        local yaw_modifier = self.yaw_modifier or 'Off'
                        local modifier_offset = self.modifier_offset or 0
                        local valid_modifiers = { Off = true, Offset = true, Center = true, Random = true, Skitter = true }
                        if not valid_modifiers[yaw_modifier] then yaw_modifier = "Center" end

                        override.set(reference.antiaim.yaw.jitter.type, yaw_modifier)
                        override.set(reference.antiaim.yaw.jitter.value, modifier_offset)

                        local left_limit, right_limit = self.left_limit or 58, self.right_limit or 58

                        local body_yaw_type = self.body_yaw_type or 'Static'
                        local body_yaw_value = self.inverter and -left_limit or right_limit

                        if self.body_yaw_type then
                            body_yaw_type = self.body_yaw_type
                            body_yaw_value = self.body_yaw_value or 0
                        end

                        -- the slider is -180 .. 180: its sign is the side. +-1 only works if gamesense reads nothing but the sign;
                        -- if it reads the size too (desync amount, or how far the choked ticks turn away) +-1 is almost no desync.
                        -- 120: full desync under every reading (180 would be the same angle for both sides as an offset)
                        local body_sign = (body_yaw_value or 0) > 0 and 1 or ((body_yaw_value or 0) < 0 and -1 or 0)
                        override.set(reference.antiaim.body.yaw.type, body_yaw_type)
                        override.set(reference.antiaim.body.yaw.value, body_sign * 120)

                        local body_yaw_freestanding = self.body_yaw_freestanding or false

                        override.set(reference.antiaim.body.freestanding, body_yaw_freestanding)
                    end
                end

                function create_antiaim(initial)
                    return setmetatable(initial or {

                    }, {
                        __index = AntiAim
                    })
                end
            end

            antiaimbot.constructor = {}
            antiaimbot.defensive_constructor = {}

            antiaimbot.features = {} do
                antiaimbot.features.running = false

                antiaimbot.features.state = {
                    legit_antiaim = false,
                    safe_head = false,
                    warmup_antiaim = false,
                    manual_antiaim = false,
                    freestanding = false
                }

                antiaimbot.features.fast_ladder = {} do
                    local time_on_ladder = 0
                    local move_time = 0

                    function antiaimbot.features.fast_ladder:run(enabled, cmd, me, wpn)
                        if not enabled then
                            time_on_ladder = 0
                            move_time = 0

                            return
                        end

                        local throw_time = entity_get_prop(wpn, 'm_fThrowTime')

                        local ascending, descending = cmd.forwardmove > 0, cmd.forwardmove < 0
                        local moving_none = cmd.sidemove == 0

                        if ascending or descending or not moving_none then
                            move_time = move_time + 1
                        else
                            move_time = 0
                        end

                        if time_on_ladder < 1 then
                            time_on_ladder = time_on_ladder + 1
                        end

                        if move_time < 4 or time_on_ladder < 1 then
                            return
                        end

                        if cmd.in_jump == 1 then
                            return
                        end

                        if not wpn or (not throw_time or throw_time == 0) then

                            if cmd.forwardmove > 0 then
                                if cmd.pitch < 45 then
                                    cmd.pitch = 89
                                    cmd.in_moveright = 1
                                    cmd.in_moveleft = 0
                                    cmd.in_forward = 0
                                    cmd.in_back = 1

                                    if cmd.sidemove == 0 then
                                        cmd.yaw = cmd.yaw + 90
                                    end

                                    if cmd.sidemove < 0 then
                                        cmd.yaw = cmd.yaw + 150
                                    end

                                    if cmd.sidemove > 0 then
                                        cmd.yaw = cmd.yaw + 30
                                    end
                                end
                            elseif cmd.forwardmove < 0 then
                                cmd.pitch = 89
                                cmd.in_moveleft = 1
                                cmd.in_moveright = 0
                                cmd.in_forward = 1
                                cmd.in_back = 0

                                if cmd.sidemove == 0 then
                                    cmd.yaw = cmd.yaw + 90
                                end

                                if cmd.sidemove > 0 then
                                    cmd.yaw = cmd.yaw + 150
                                end

                                if cmd.sidemove < 0 then
                                    cmd.yaw = cmd.yaw + 30
                                end
                            end

                            return true
                        end
                    end
                end

                antiaimbot.features.legit_antiaim = {} do
                    local use_time = 0

                    function antiaimbot.features.legit_antiaim.run(instance, cmd, me, wpn)
                        antiaimbot.features.state.legit_antiaim = false

                        if antiaimbot.features.state.running then
                            return 'Priority surpassed'
                        end

                        if not c_table.contains(config.antiaimbot.options:get(), 'On use antiaim') then
                            return 'Not enabled'
                        end

                        if player.weapon_type == 'grenade' then
                            return 'Grenade in hands'
                        end

                        if cmd.in_use == 0 then
                            use_time = 0

                            return 'Not in use'
                        end

                        use_time = use_time + 1

                        if not player.use_needed and use_time > 2 then
                            local preset do
                                local preset_name = config.antiaimbot.preset:get()

                                if preset_name == 'Constructor' then
                                    preset = antiaimbot.constructor
                                else
                                    preset = c_constant.antiaim_presets[preset_name]
                                end
                            end

                            if preset then
                                cmd.in_use = 0

                                antiaimbot.main.run_preset(instance, preset['Legit AA'])

                                antiaimbot.features.state.legit_antiaim = true
                                antiaimbot.features.running = true

                                return 'Legit antiaim is active'
                            end

                            return 'No preset'
                        end

                        return 'Use is needed'
                    end
                end

                antiaimbot.features.manual_antiaim = {} do
                    function antiaimbot.features.manual_antiaim.run(instance, cmd, me, wpn)
                        antiaimbot.features.state.manual_antiaim = false
                        antiaimbot.features.state.freestanding = false

                        if antiaimbot.features.running then
                            return 'Priority surpassed'
                        end

                        if not config.antiaimbot.manual_yaw:get() then
                            antiaimbot.manual_antiaim.state = -1

                            return 'Not enabled'
                        end

                        local state = antiaimbot.manual_antiaim.state
                        local m_options = config.antiaimbot.manual_options:get()
                        local fs_options = config.antiaimbot.fs_options:get()
                        local ignore_freestanding = c_table.contains(config.antiaimbot.freestanding_disabler_states:get(), player.state)

                        if state ~= -1 then
                            instance.yaw_base = 'Local view'

                            instance.yaw_type = '180'
                            instance.yaw_offset = antiaimbot.manual_antiaim.convert[antiaimbot.manual_antiaim.state]

                            antiaimbot.features.state.manual_antiaim = true
                        else
                            instance.edge_yaw, instance.freestand = config.antiaimbot.edge_yaw:rawget(), config.antiaimbot.freestanding:rawget() and not ignore_freestanding

                            antiaimbot.features.state.freestanding = instance.freestand
                        end

                        local manual = state ~= -1
                        local fs_detected = instance.freestand and c_table.contains(fs_options, 'Jitter disabled')
                        local jitter_off = manual and c_table.contains(m_options, 'Jitter disabled') or fs_detected
                        local body_fs = jitter_off or (manual and c_table.contains(m_options, 'Body freestanding'))
                            or (instance.freestand and c_table.contains(fs_options, 'Body freestanding'))

                        if jitter_off then
                            instance.yaw_modifier = 'Off'
                            instance.modifier_offset = 0

                            if fs_detected then
                                instance.yaw_type = '180'
                                instance.yaw_offset = 0
                            end
                        end

                        -- the body side by the wall instead of the coin flip: the head stays behind cover
                        if body_fs and player.fs_side ~= 'none' then
                            instance.body_yaw_type = 'Static'
                            instance.body_yaw_value = player.fs_side == 'left' and 1 or -1
                        end

                        if not (antiaimbot.features.state.manual_antiaim or antiaimbot.features.state.freestanding) then
                            return 'Inactive'
                        end

                        antiaimbot.features.running = true

                        return 'Manual antiaim is active'
                    end
                end

                antiaimbot.features.warmup_antiaim = {} do
                    function antiaimbot.features.warmup_antiaim.run(instance, cmd, me, wpn)
                        antiaimbot.features.state.warmup_antiaim = false

                        if antiaimbot.features.running then
                            return 'Priority surpassed'
                        end

                        if not config.antiaimbot.warmup_aa:get() then
                            return 'Not enabled'
                        end

                        local game_rules = entity.get_game_rules()

                        if not game_rules then
                            return 'CGameRules is invalid'
                        end

                        local warmup_period do
                            local is_active = c_table.contains(config.antiaimbot.warmup_aa_conditions:get(), 'Warmup')
                            local is_warmup = entity_get_prop(game_rules, 'm_bWarmupPeriod') == 1

                            warmup_period = is_active and is_warmup
                        end

                        -- the round end check: only after the round is decided (restart time in the future) the 64 player slots
                        -- are scanned; it used to scan them on every tick of the round
                        if not warmup_period and globals_curtime() < (entity_get_prop(game_rules, 'm_flRestartRoundTime') or 0) then
                            local player_resource = entity.get_player_resource()

                            if player_resource then
                                local are_all_enemies_dead = true

                                for i=1, globals.maxplayers() do
                                    if entity_get_prop(player_resource, 'm_bConnected', i) == 1 then
                                        if entity.is_enemy(i) and entity.is_alive(i) then
                                            are_all_enemies_dead = false

                                            break
                                        end
                                    end
                                end

                                warmup_period = are_all_enemies_dead and globals_curtime() < (entity_get_prop(game_rules, 'm_flRestartRoundTime') or 0)
                            end
                        end

                        if warmup_period then
                            instance.pitch = 'Off'

                            instance.yaw_base = 'At targets'

                            instance.yaw_type = '180'
                            instance.yaw_offset = c_animations:spin('warmup_spin', -180, 180, 1, 32).value

                            instance.yaw_modifier = 'Off'

                            antiaimbot.features.state.warmup_antiaim = true
                            antiaimbot.features.running = true

                            return 'Warmup AA is active'
                        end

                        return 'Conditions was not met'
                    end
                end

                antiaimbot.features.safe_head = {} do
                    local resolve_classname = {
                        ['CKnife'] = 'Air knife',
                        ['CWeaponTaser'] = 'Air zeus'
                    }

                    antiaimbot.features.safe_head.trace_thread = (function (me, threat)
                        if threat then
                            local my_origin = vector(entity.get_origin(me))
                            local my_head = vector(entity.hitbox_position(me, 0))

                            if entity.is_alive(threat) then
                                local ent_origin = vector(entity.get_origin(threat))

                                do
                                    local target = c_math.extrapolate(threat, vector(entity.hitbox_position(threat, 0)), 5)
                                    local entindex, damage = client.trace_bullet(threat, target.x, target.y, target.z, my_head.x, my_head.y, my_head.z + 6)

                                    if -1 == entindex then
                                        damage = 0
                                    end

                                    return my_origin.z - ent_origin.z > 5 and damage > 0
                                end
                            end
                        end

                        return false
                    end)

                    function antiaimbot.features.safe_head.run(instance, cmd, me, wpn)
                        antiaimbot.features.state.safe_head = false

                        if antiaimbot.features.running then
                            return 'Priority surpassed'
                        end

                        if not config.antiaimbot.safe_head:get() then
                            return 'Not enabled'
                        end

                        local is_enabled = c_table.contains(config.antiaimbot.safe_head_conditions:get(), player.state)
                        local is_safe_head = false
                        local threat = client.current_threat()

                        do
                            if player.state:match('Air') and threat then
                                if wpn then
                                    local weapon_classname = entity.get_classname(wpn)

                                    if c_table.contains(config.antiaimbot.safe_head_conditions:get(), resolve_classname[weapon_classname]) then
                                        is_safe_head = true
                                    end
                                end
                            end
                        end

                        if not is_safe_head then
                            is_safe_head = antiaimbot.features.safe_head.trace_thread(me, threat)
                        end

                        if is_enabled and is_safe_head then
                            instance.pitch = 'Minimal'

                            instance.yaw_type = '180'
                            instance.yaw_base = 'At targets'
                            instance.yaw_offset = 0
                            instance.yaw_modifier = 'Off'

                            antiaimbot.features.state.safe_head = true
                            antiaimbot.features.running = true

                            return 'Safe head is running'
                        end

                        if not is_enabled then
                            return 'Not active'
                        end

                        return 'Conditions was not met'
                    end
                end

                antiaimbot.features.avoid_backstab = {} do
                    function antiaimbot.features.avoid_backstab.run(instance, cmd, me, wpn)
                        local my_origin = vector(entity.get_origin(me))

                        local player_list = entity.get_players(true)
                        local player_cnt = #player_list

                        local closest_dist, closest_yaw = math.huge, nil

                        for i=1, player_cnt do
                            local ent = player_list[i]
                            local weapon = entity.is_alive(ent) and not entity.is_dormant(ent) and entity.get_player_weapon(ent) or nil
                            local weapon_info = weapon and csgo_weapons(weapon)
                            -- only enemies with a knife, and only near ones get their bones set up (hitbox_position)
                            local ox, oy = nil, nil
                            if weapon_info and weapon_info.is_melee_weapon then ox, oy = entity.get_origin(ent) end
                            local near = ox ~= nil and (ox - my_origin.x) ^ 2 + (oy - my_origin.y) ^ 2 < 400 * 400
                            local hx, hy, hz
                            if near then hx, hy, hz = entity.hitbox_position(ent, 2) end
                            local player_origin = vector(hx or 0, hy or 0, hz or 0)
                            local distance = my_origin:dist(player_origin)
                            local same_floor = hz ~= nil and math_abs(hz - my_origin.z - 40) < 90

                            if hx and same_floor and distance < 350 and weapon then
                                if weapon_info.is_melee_weapon then
                                    if distance < closest_dist then
                                        local _, yaw_to_target = (player_origin - my_origin):angles()

                                        closest_yaw = yaw_to_target
                                        closest_dist = distance
                                    end
                                end
                            end
                        end

                        if closest_yaw then
                            instance.yaw_type = 'Static'
                            instance.yaw_offset = c_math.normalize_yaw(closest_yaw)

                            return true, 'Avoid backstab is active'
                        end

                        return false, 'No target'
                    end
                end
            end

            antiaimbot.defensive = {} do
                local presets = c_constant.defensive_presets['Auto']

                function antiaimbot.defensive.is_exploit_ready_and_active(wpn)
                    local fakeduck_active = ui_get(reference.ragebot.fakeduck)
                    local onshot_active = c_table.is_hotkey_active(reference.misc.onshot_antiaim)
                    local doubletap_active = c_table.is_hotkey_active(reference.ragebot.doubletap.enable)

                    if fakeduck_active or not (onshot_active or doubletap_active) or doubletap_active and not player:get_double_tap() then
                        return false
                    end

                    if wpn then
                        local wpn_info = csgo_weapons(wpn)

                        if wpn_info then
                            if wpn_info.is_revolver then
                                return false
                            end
                        end
                    end

                    return true
                end

                -- can the current threat see our head right now? (one trace per tick)
                local vis = { tick = -1, value = false, since = -10 }
                function antiaimbot.defensive.threat_visible(me)
                    local tick = globals_tickcount()
                    if vis.tick == tick then return vis.value, vis.since end
                    vis.tick = tick
                    local seen = false
                    local threat = client.current_threat()
                    if me and threat and entity.is_alive(threat) and not entity.is_dormant(threat) then
                        local ex, ey, ez = entity_get_prop(threat, 'm_vecOrigin')
                        local hx, hy, hz = entity.hitbox_position(me, 0)
                        if ex and hx then
                            ez = ez + (entity_get_prop(threat, 'm_vecViewOffset[2]') or 64)
                            local frac, hit = client.trace_line(threat, ex, ey, ez, hx, hy, hz)
                            seen = hit == me or (tonumber(frac) or 0) > 0.97
                        end
                    end
                    if seen and not vis.value then vis.since = globals.realtime() end
                    vis.value = seen
                    return seen, vis.since
                end

                function antiaimbot.defensive.force(cmd, me, wpn)
                    if not config.antiaimbot.defensive_aa:get() then
                        return false
                    end

                    if cmd.in_attack == 1 then antiaimbot.defensive.last_shot = globals.realtime() end

                    if not antiaimbot.defensive.is_exploit_ready_and_active(wpn) then
                        return false
                    end

                    local conditions_met = true do
                        local doubletap_active = c_table.is_hotkey_active(reference.ragebot.doubletap.enable)
                        local hideshots_active = c_table.is_hotkey_active(reference.misc.onshot_antiaim) and not doubletap_active
                        local defensive_target = config.antiaimbot.defensive_target:get()

                        if doubletap_active and not c_table.contains(defensive_target, "Double tap") then
                            conditions_met = false
                        elseif hideshots_active and not c_table.contains(defensive_target, "On shot anti-aim") then
                            conditions_met = false
                        end
                    end

                    if not conditions_met then
                        return false
                    end

                    local defensive_check = c_table.contains(config.antiaimbot.defensive_conditions:get(), player.state)

                    local defensive_triggers = config.antiaimbot.defensive_triggers:get()
                    local defensive_triggered

                    local animlayers = ffi_helpers.animlayers:get(me)

                    local is_reloading, is_flashed, is_under_attack
                    if animlayers then
                        local weapon_activity_number = ffi_helpers.activity:get(animlayers[1]['sequence'], me)
                        local flash_activity_number = ffi_helpers.activity:get(animlayers[9]['sequence'], me)
                        is_reloading = animlayers[1]['weight'] ~= 0.0 and weapon_activity_number == 967
                        is_flashed = animlayers[9]['weight'] > 0.1 and flash_activity_number == 960
                        is_under_attack = animlayers[10]['weight'] > 0.1
                    end
                    -- no layer read (or no activity function): the same from gamesense props
                    local curtime = globals_curtime()
                    if is_reloading == nil or (animlayers and not ffi_helpers.activity.location) then
                        is_reloading = (entity_get_prop(me, 'm_flNextAttack') or 0) > curtime + 0.1
                        is_flashed = (entity_get_prop(me, 'm_flFlashDuration') or 0) > 0.1
                    end
                    if is_under_attack == nil then is_under_attack = (entity_get_prop(me, 'm_flVelocityModifier') or 1) < 0.95 end
                    local is_swapping_weapons = cmd.weaponselect > 0

                    if c_table.contains(defensive_triggers, 'Flashed') and is_flashed
                    or c_table.contains(defensive_triggers, 'Damage received') and is_under_attack
                    or c_table.contains(defensive_triggers, 'Reloading') and is_reloading
                    or c_table.contains(defensive_triggers, 'Weapon switch') and is_swapping_weapons then
                        defensive_triggered = true
                    end

                    local now = globals.realtime()
                    local visible, visible_since = false, -10
                    if c_table.contains(defensive_triggers, 'Enemy visible') then visible, visible_since = antiaimbot.defensive.threat_visible(me) end

                    -- peeking the threat, the ticks after landing, low on health, a threat that is scoped in (it is about to shoot)
                    if c_table.contains(defensive_triggers, 'On peek') and player.peeking
                    or c_table.contains(defensive_triggers, 'Landing') and player.landing
                    or c_table.contains(defensive_triggers, 'Low HP') and (entity_get_prop(me, 'm_iHealth') or 100) <= 40 then
                        defensive_triggered = true
                    end
                    if c_table.contains(defensive_triggers, 'Threat scoped') then
                        local threat = client.current_threat()
                        local scoped = threat and entity_get_prop(threat, 'm_bIsScoped')
                        if scoped == 1 or scoped == true then defensive_triggered = true end
                    end

                    -- right after our own shot (the shot tick is when we are easiest to hit back)
                    if c_table.contains(defensive_triggers, 'After shot') and now - (antiaimbot.defensive.last_shot or -10) < 0.25 then
                        defensive_triggered = true
                    end
                    -- the moment the threat first sees us (peek), for a short burst
                    if c_table.contains(defensive_triggers, 'Enemy visible') and visible and now - visible_since < 0.3 then
                        defensive_triggered = true
                    end

                    if defensive_check or defensive_triggered then
                        cmd.force_defensive = 1

                        return true, defensive_triggered
                    end

                    return false
                end

                function antiaimbot.defensive.get_preset(wpn, forcing, triggered)
                    local is_auto = config.antiaimbot.defensive_preset:get() == 'Auto'
                    local preset_data = is_auto and presets or antiaimbot.defensive_constructor

                    if not preset_data then
                        return false
                    end

                    local state_selected = antiaimbot.features.state.legit_antiaim and 'Legit AA' or player.state
                    local is_active = preset_data[state_selected] ~= nil

                    if player.peeking then
                        if (not is_active or preset_data[state_selected].global_set) and preset_data["On peek"] then
                            state_selected = 'On peek'
                            is_active = true

                            forcing = true
                        end
                    end

                    if not forcing then
                        return false
                    end

                    local custom_states = {
                        ['freestanding'] = {'Edge direction', 'Freestanding'},
                        ['manual_antiaim'] = {'Edge direction', 'Manual yaw'},
                        ['safe_head'] = {'Safe head'},
                        [ triggered ] = {'Triggered'}
                    }

                    for feature, data in next, custom_states, nil do
                        if feature == true or antiaimbot.features.state[feature] then
                            local state = data[1]
                            local preset_active = preset_data[state]

                            if preset_active and data[2] then
                                preset_active = preset_active and c_table.contains(preset_active.enable_on, data[2])
                            end

                            state_selected = state
                            is_active = preset_active ~= nil
                        end
                    end

                    if is_auto then
                        is_active = c_table.contains(config.antiaimbot.defensive_conditions_auto:get(), state_selected)
                    end

                    local this

                    if state_selected == 'Safe head' or state_selected == 'Edge direction' or state_selected == 'Triggered' then
                        this = presets[state_selected]
                    else
                        this = preset_data[state_selected]
                    end

                    if not this then
                        return false
                    end

                    return is_active, this, state_selected
                end

                local flicker = false
                local last_flick_at = 0

                local three_way = {
                    90,
                    180,
                    -90,
                    180,
                    90
                }

                local scissor_way = 0
                local last_scissor = 0

                function antiaimbot.defensive.get_scissor_offset(way, state)
                    local target_way = way % 6

                    local left do
                        local from = c_math.min(state.yaw_left_start, state.yaw_left_target)
                        local to = c_math.max(state.yaw_left_start, state.yaw_left_target)
                        local step = (to - from) / 12

                        left = from + step / 2 * target_way
                    end

                    local right do
                        local from = c_math.min(state.yaw_right_start, state.yaw_right_target)
                        local to = c_math.max(state.yaw_right_start, state.yaw_right_target)
                        local step = (to - from) / 12

                        right = from + step / 2 * target_way
                    end

                    return way % 2 == 0 and left or right
                end

                function antiaimbot.defensive:run(instance, cmd, me, wpn, forcing, triggered)
                    if antiaimbot.features.state.warmup_antiaim then
                        return false, 'Overrided by superior features'
                    end

                    if not antiaimbot.defensive.is_exploit_ready_and_active(wpn) then
                        return false, 'Exploit is invalid'
                    end

                    local effective_forcing = forcing or (cmd.force_defensive == 1)

                    local is_active, this, state = self.get_preset(wpn, effective_forcing or false, triggered or false)

                    if not is_active or not this then
                        return false, 'Preset is invalid'
                    end

                    local game_rules = entity.get_game_rules()

                    if game_rules and entity_get_prop(game_rules, 'm_bFreezePeriod') == 1 or cmd.in_use == 1 then
                        return false, 'Player state is invalid'
                    end

                    local pitch_mode = this.pitch
                    local yaw_mode = this.yaw

                    local pitch = ({
                        ['Up'] = -88,
                        ['Zero'] = 0,
                        ['Up Switch'] = c_math.random(-45, -65),
                        ['Down Switch'] = c_math.random(45, 65),
                        ['Random'] = c_math.random(-89, 89),
                        ['Snap'] = (globals_tickcount() % 2 == 0) and -89 or 89,
                        ['Custom'] = this.pitch_custom
                    })[pitch_mode]

                    local yaw = ({
                        ['Forward'] = c_math.normalize_yaw(180 + c_math.random(-30, 30)),
                        ['3-Way'] = c_math.normalize_yaw(three_way[player.packets % 5 + 1] + c_math.randomf(-15, 15)),
                        ['5-Way'] = c_math.normalize_yaw(({ 90, 135, 180, 225, 270 })[player.packets % 5 + 1] + c_math.randomf(-15, 15)),
                        ['Random'] = c_math.random(-180, 180)
                    })[yaw_mode]

                    -- extra pitch modes
                    local dtick = globals_tickcount()
                    if pitch_mode == 'Sway' then
                        pitch = math.sin(dtick * 0.35) * 89
                    elseif pitch_mode == 'Flick up' then
                        pitch = (dtick % 4 == 0) and c_math.random(-10, 10) or -89
                    elseif pitch_mode == 'Half up' then
                        pitch = -45 + c_math.random(-8, 8)
                    elseif pitch_mode == 'Cycling' then
                        -- one step per defensive packet
                        local seqs = {
                            ['Up / Down'] = { -89, 89 },
                            ['Up / Zero / Down'] = { -89, 0, 89 },
                            ['Down / Zero / Up / Zero'] = { 89, 0, -89, 0 },
                        }
                        local seq = seqs[this.pitch_cycle or 'Up / Down']
                        if seq then
                            pitch = seq[(player.packets or 0) % #seq + 1]
                        else
                            -- random order: never the same twice in a row
                            local last = antiaimbot.defensive.cycle_last
                            local pick
                            repeat pick = ({ -89, -45, 0, 45, 89 })[client.random_int(1, 5)] until pick ~= last
                            if (player.packets or 0) ~= antiaimbot.defensive.cycle_packet then
                                antiaimbot.defensive.cycle_packet, antiaimbot.defensive.cycle_last = player.packets or 0, pick
                            end
                            pitch = antiaimbot.defensive.cycle_last or pick
                        end
                    end
                    -- freestand: the defensive yaw puts the head toward the covered side (as freestanding sees it)
                    if yaw_mode == 'Freestand' then
                        local fs = player.fs_side
                        local rnd = this.yaw_randomize or 0
                        yaw = (fs == 'left' and -90) or (fs == 'right' and 90) or 180
                        if rnd > 0 then yaw = yaw + client.random_int(-rnd, rnd) end
                        yaw = c_math.normalize_yaw(yaw)
                    end

                    -- extra yaw modes (0 = backwards, 180 = at them, +-90 = sideways)
                    if yaw_mode == 'Flick' or yaw_mode == 'Sway' or yaw_mode == 'Distortion' or yaw_mode == 'Random side' then
                        local l = (this.yaw_left and this.yaw_left ~= 0) and this.yaw_left or -90
                        local r = (this.yaw_right and this.yaw_right ~= 0) and this.yaw_right or 90
                        local rnd = this.yaw_randomize or 0
                        local packets = player.packets or 0

                        if yaw_mode == 'Flick' then
                            -- sit backwards, flick to one side for a single packet, alternate sides
                            local delay = math_max(2, this.yaw_delay or 4)
                            local k = packets % (delay * 2)
                            yaw = (k == 0) and l or ((k == delay) and r or 0)
                        elseif yaw_mode == 'Sway' then
                            local t = dtick * (this.yaw_speed or 8) * 0.02
                            yaw = l + (r - l) * (0.5 + 0.5 * math.sin(t))
                        elseif yaw_mode == 'Distortion' then
                            local n = c_math.clamp((aa_noise.fractal_noise(dtick * (this.yaw_speed or 8) * 0.01, 3, 0.55) - 0.5) * 2.1 + 0.5, 0, 1)
                            yaw = l + (r - l) * n
                            if client.random_int(1, 10) == 1 then yaw = (n > 0.5) and l or r end
                        else
                            local side = client.random_int(0, 1) == 1
                            yaw = (side and l or r) * (0.8 + 0.4 * client.random_int(0, 100) / 100)
                        end

                        if rnd > 0 then yaw = yaw + client.random_int(-rnd, rnd) end
                        yaw = c_math.normalize_yaw(yaw)
                    end

                    if yaw_mode == 'Snap' then
                        local left = (this.yaw_left and this.yaw_left ~= 0) and this.yaw_left or -90
                        local right = (this.yaw_right and this.yaw_right ~= 0) and this.yaw_right or 90
                        local seq = { left, 180, right, 180 }
                        local randomize = this.yaw_randomize or 0
                        yaw = c_math.normalize_yaw(seq[globals_tickcount() % #seq + 1] + (randomize > 0 and client.random_int(-randomize, randomize) or 0))
                    end

                    if yaw_mode == 'Sideways' then
                        local sideways_y = c_animations:flick('sideways_y', -90, 90, 2)

                        yaw = c_math.normalize_yaw(sideways_y.value + client.random_int(-15, 15))
                    end

                    if yaw_mode == 'Spinbot' then
                        local randomize = this.yaw_randomize or 0
                        local spinbot_y = c_animations:spin(string_format('spinbot_y_%s', state), this.yaw_from, this.yaw_to, 1, this.yaw_speed)

                        yaw = c_math.normalize_yaw(spinbot_y.value + client.random_int(-randomize, randomize))
                    end

                    if yaw_mode == 'Delayed' then
                        local yaw_delay = this.yaw_delay or 1
                        local randomize = this.yaw_randomize or 0

                        if player.packets - last_flick_at >= yaw_delay then
                            flicker = not flicker

                            last_flick_at = player.packets
                        end

                        yaw = flicker and this.yaw_left or this.yaw_right

                        if randomize ~= 0 then
                            yaw = yaw + (yaw > 0 and 1 or -1) * client.random_int(0, randomize)
                        end
                    end

                    if yaw_mode == 'Scissors' then
                        local yaw_delay = this.yaw_delay or 1
                        local randomize = this.yaw_randomize or 0

                        if player.packets - last_scissor > yaw_delay then
                            scissor_way = scissor_way + 1
                            last_scissor = player.packets
                        end

                        yaw = self.get_scissor_offset(scissor_way, this) + client.random_int(0, randomize)
                    end

                    local _, view_angle_yaw = client.camera_angles()

                    view_angle_yaw = player:threat_yaw(me) or view_angle_yaw
                    view_angle_yaw = view_angle_yaw - 180

                    if globals.absoluteframetime() < globals_tickinterval() and not client.key_state(0x1) then
                        -- keep the preset's jitter while defensive is being forced; flattening it to a static
                        -- 180 made every normal (lag compensated) tick an easy target
                        if forcing and config.antiaimbot.force_target_yaw:get() and state ~= 'On peek' and not antiaimbot.features.state.manual_antiaim then
                            instance.yaw_base = 'At targets'
                        end

                        -- only send defensive angles when the shift is confirmed; a wrong prediction would put
                        -- the flick on a real tick
                        if player.defensive_predict and player.defensive_active then
                            if pitch_mode ~= 'Default' then
                                cmd.pitch = c_math.clamp(pitch, -89, 89)
                            end

                            if yaw_mode ~= 'Default' then
                                cmd.yaw = c_math.normalize_yaw(view_angle_yaw-yaw)
                            end

                            return true
                        else
                            return false, 'Defensive is inactive'
                        end
                    end

                    return false, 'Overrided by left mouse'
                end
            end

            antiaimbot.main = {} do
                local presets = c_constant.antiaim_presets
                local instance = create_antiaim()

                local antiaim_state = {
                    switch = false,
                    swap = false,
                    delay = 0,
                    last_switch = 0,
                    last_packets = 0,
                    step = 1
                }

                -- packet-stepped jitters that gamesense doesn't have natively.
                -- They step once per SENT packet so fake lag never swallows a switch.
                local CUSTOM_JITTER = { ["3-Way"] = true, ["5-Way"] = true, ["Delayed center"] = true, ["Distortion"] = true, ["Random hold"] = true }
                local cj = { last = -1, step = 0, order = { 1, 2, 3, 4, 5 }, hold = 0, dir = 1, side = 1, snap = nil, snap_dir = 1 }

                -- The side of the body yaw is its own random process. It used to follow the yaw offset (opposite of it, or
                -- in lockstep with a native jitter), so a resolver that learned "side = opposite of the visible yaw" hit
                -- every single shot (simulated: 0.93 hit rate against it). Then it was held 1-4 packets: the next packet was
                -- on the same side 72% of the time, which a resolver that remembers the last side it saw learns
                -- (tests/aa_redteam.py: 0.50-0.59). Now every SENT packet gets a fresh coin flip: nothing to learn, a resolver
                -- that has to pick a side is right half of the time at best. Steps once per sent packet so fake lag never
                -- swallows a switch.
                local DECORRELATE_BODY = true
                local body_side do
                    local bs = { side = 1, last = -1 }
                    body_side = function()
                        local p = player.packets or 0
                        if p ~= bs.last then
                            bs.last = p
                            bs.side = client.random_int(0, 1) == 1 and 1 or -1
                        end
                        return bs.side
                    end
                end
                antiaimbot.body_side = function() return body_side() end

                local function cj_shuffle(t)
                    for i = #t, 2, -1 do
                        local j = client.random_int(1, i)
                        t[i], t[j] = t[j], t[i]
                    end
                end

                local function custom_jitter(mode, raw)
                    local v = math_abs(raw)
                    local flip = raw < 0 and -1 or 1
                    local p = player.packets or 0
                    local advanced = p ~= cj.last
                    if advanced then
                        cj.last, cj.step = p, cj.step + 1
                    end

                    local add = 0
                    if mode == "3-Way" then
                        add = ({ -v, 0, v })[cj.step % 3 + 1]
                    elseif mode == "5-Way" then
                        -- same five angles, new random order every cycle
                        if advanced and cj.step % 5 == 0 then cj_shuffle(cj.order) end
                        add = ({ -v, -v / 2, 0, v / 2, v })[cj.order[cj.step % 5 + 1]]
                    elseif mode == "Delayed center" then
                        if advanced then
                            cj.hold = cj.hold - 1
                            if cj.hold <= 0 then
                                cj.dir, cj.hold = -cj.dir, client.random_int(2, 5)
                            end
                        end
                        add = cj.dir * v / 2
                    elseif mode == "Distortion" then
                        -- smooth wandering angle with no fixed period, plus rare 2-packet snaps to the far side
                        local n = c_math.clamp((aa_noise.fractal_noise(p * 0.27, 3, 0.55) - 0.5) * 4.2, -1, 1)
                        add = n * v
                        if advanced and not (cj.snap and p <= cj.snap) and client.random_int(1, 14) == 1 then
                            cj.snap, cj.snap_dir = p + 2, add > 0 and -1 or 1
                        end
                        if cj.snap and p <= cj.snap then add = cj.snap_dir * v end
                    elseif mode == "Random hold" then
                        -- full-width side switch, but each side is held a random 1-4 packets at 70-100% width:
                        -- no fixed rhythm for timing-based brute force to lock on to
                        if advanced then
                            cj.rh_left = (cj.rh_left or 0) - 1
                            if cj.rh_left <= 0 then
                                cj.rh_side = -(cj.rh_side or 1)
                                cj.rh_left = client.random_int(1, 4)
                                cj.rh_amp = 0.7 + client.random_int(0, 30) / 100
                            end
                        end
                        add = (cj.rh_side or 1) * v * (cj.rh_amp or 1)
                    end

                    -- desync goes to the side opposite of the yaw offset
                    if add > 0.5 then cj.side = -flip elseif add < -0.5 then cj.side = flip end
                    return add, cj.side
                end

                function antiaimbot.main.run_preset(instance, data)
                    local yaw_side = player.fakeyaw > 0 and 'left' or 'right'

                    instance.pitch = data.pitch
                    instance.pitch_custom = data.pitch_custom

                    instance.yaw_base = data.yaw_base

                    local yaw_type = data.yaw_type or '180'
                    local yaw = data.yaw_offset or 0

                    local can_force_body_yaw = true
                    local inverter = false
                    local yaw_modifier = data.yaw_modifier or 'Off'
                    local modifier_offset = data.modifier_offset or 0

                    if yaw_type ~= '180' then
                        if yaw_type == 'Left & Right' then
                            local left_offset = type(data.left_offset) == 'table' and client.random_int(data.left_offset[1], data.left_offset[2]) or data.left_offset
                            local right_offset = type(data.right_offset) == 'table' and client.random_int(data.right_offset[1], data.right_offset[2]) or data.right_offset

                            local micro_jitter = (aa_noise.chaos_rng() - 0.5) * 8
                            left_offset = left_offset + micro_jitter
                            right_offset = right_offset - micro_jitter

                            if data.yaw_delay ~= nil then
                                local logic = data.yaw_logic or "Random"
                                -- logical: an anti brute-force trigger (a hit on us, a bullet past the head) switches at once
                                local ab = antiaimbot.anti_brute
                                local kicked = logic == "Logical" and ab and (ab.last_trigger or 0) > (antiaim_state.logic_seen or 0)
                                if kicked then antiaim_state.logic_seen = ab.last_trigger end
                                if kicked or player.packets - antiaim_state.last_packets >= antiaim_state.delay then
                                    if logic == "Random" then
                                        local base_delay = client.random_int(c_math.min(data.yaw_delay, data.yaw_delay_second), c_math.max(data.yaw_delay, data.yaw_delay_second))
                                        local prime_mod = aa_noise.get_prime_offset() % 5
                                        antiaim_state.delay = base_delay + prime_mod

                                        if aa_noise.chaos_rng() > 0.15 then
                                            antiaim_state.switch = not antiaim_state.switch
                                        end
                                    elseif logic == "Sequence" and data.yaw_sequence then
                                        -- the next step of the sequence
                                        local seq = data.yaw_sequence
                                        antiaim_state.seq_i = ((antiaim_state.seq_i or 0) % #seq) + 1
                                        antiaim_state.delay = math_max(1, seq[antiaim_state.seq_i] or data.yaw_delay)
                                        antiaim_state.switch = not antiaim_state.switch
                                    else
                                        antiaim_state.delay = data.yaw_delay
                                        antiaim_state.switch = not antiaim_state.switch
                                    end

                                    antiaim_state.last_packets = player.packets
                                end

                                inverter = antiaim_state.switch
                                yaw_side = inverter and 'left' or 'right'
                                can_force_body_yaw = false
                            end

                            yaw_type = '180'
                            yaw = yaw_side == 'left' and left_offset or right_offset
                        end

                        if yaw_type == 'Flick' then
                            yaw_type = '180'
                            yaw = c_animations:flick(string_format('Flick%s', player.state), data.left_offset, data.right_offset, data.yaw_delay).value
                        end

                        if yaw_type == 'Sway' then
                            yaw_type = '180'
                            yaw = c_animations:sway(string_format('Sway%s', player.state), data.left_offset, data.right_offset, data.yaw_delay, data.yaw_speed).value
                        end

                        if yaw_type == 'Spin between' then
                            yaw_type = '180'
                            yaw = c_animations:spin(string_format('Spin%s', player.state), data.left_offset, data.right_offset, data.yaw_delay, data.yaw_speed).value
                        end
                    end

                    instance.yaw_type = yaw_type
                    instance.yaw_offset = c_math.normalize_yaw(yaw)

                    local yaw_modifier_randomize = data.modifier_randomize

                    if yaw_modifier_randomize then
                        local base_random
                        if yaw_modifier_randomize > 0 then
                            base_random = client.random_int(modifier_offset-yaw_modifier_randomize, modifier_offset+yaw_modifier_randomize)
                        else
                            base_random = client.random_int(modifier_offset+yaw_modifier_randomize, modifier_offset-yaw_modifier_randomize)
                        end

                        local chaos_offset = (aa_noise.chaos_rng() - 0.5) * c_math.abs(yaw_modifier_randomize) * 0.5

                        local tick = globals_tickcount()
                        local tick_variance = (tick % aa_noise.get_prime_offset()) * (yaw_modifier_randomize > 0 and 1 or -1)

                        modifier_offset = base_random + chaos_offset + tick_variance
                    end

                    local sync_side = nil
                    if CUSTOM_JITTER[yaw_modifier] then
                        local add, side = custom_jitter(yaw_modifier, modifier_offset)
                        instance.yaw_offset = c_math.normalize_yaw((instance.yaw_offset or 0) + add)
                        sync_side = side
                        yaw_modifier, modifier_offset = 'Off', 0
                    end

                    instance.yaw_modifier = yaw_modifier
                    instance.modifier_offset = c_math.normalize_yaw(modifier_offset)

                    local left_limit = data.left_limit or 58
                    local right_limit = data.right_limit or 58

                    local tick = globals_tickcount()
                    local limit_variance = (tick % 7) * (aa_noise.chaos_rng() > 0.5 and 1 or -1)
                    left_limit = c_math.clamp(left_limit + limit_variance, 30, 60)
                    right_limit = c_math.clamp(right_limit + limit_variance, 30, 60)

                    instance.left_limit = left_limit
                    instance.right_limit = right_limit
                    instance.inverter = inverter

                    if can_force_body_yaw then
                        local body_yaw_type = data.body_yaw_type
                        local body_yaw_value = data.body_yaw_value

                        if body_yaw_type == 'Freestand' then
                            -- gamesense's freestanding body yaw picks the side hidden from the enemy
                            body_yaw_type, body_yaw_value = 'Static', 1
                        end

                        if body_yaw_type == 'Sync' then
                            if sync_side then
                                body_yaw_type, body_yaw_value = 'Static', sync_side
                            else
                                body_yaw_type, body_yaw_value = 'Jitter', 1
                            end
                        end

                        -- the slider is a whole number: a fraction (0.95, -0.8) can round down to 0, which is no desync at all
                        instance.body_yaw_type = body_yaw_type
                        instance.body_yaw_value = body_yaw_value
                    end

                    -- the side is decided here, independent of the yaw offset (see body_side). Left alone: the legit AA and the
                    -- freestanding body yaw (the game picks that side from the geometry)
                    if DECORRELATE_BODY and data.yaw_base ~= 'Local view'
                        and not (data.body_yaw_freestanding or data.body_yaw_type == 'Freestand' or data.body_yaw_type == 'Static') then
                        instance.body_yaw_type, instance.body_yaw_value = 'Static', body_side()
                    end

                    instance.body_yaw_freestanding = data.body_yaw_freestanding or data.body_yaw_type == 'Freestand'
                end

                --- Anti brute-force: an enemy bullet that hits us or passes within 40 units of the head means its resolver
                -- is on our angle. For a short window (about half a second) the yaw moves a few degrees away from the side
                -- the bullet came past, and the jitter switch restarts. Every next trigger by the same enemy within 7 s
                -- takes the next pattern, after that it starts over. The body side stays the coin flip per packet
                antiaimbot.anti_brute = {} do
                    local ab = antiaimbot.anti_brute
                    local PATTERNS = {
                        { offset = 7,  duration = 0.58, restart = true },
                        { offset = 11, duration = 0.72, restart = false },
                        { offset = 14, duration = 0.86, restart = true },
                        { offset = 9,  duration = 0.64, restart = true },
                        { offset = 13, duration = 0.78, restart = false },
                        { offset = 6,  duration = 0.54, restart = true },
                    }

                    ab.pending, ab.hurt_tick, ab.team_hurt_tick, ab.enemies = {}, {}, {}, {}
                    ab.active, ab.active_until, ab.stage, ab.last_trigger, ab.side = false, 0, 0, 0, 1

                    local function wants(kind)
                        local list = config.antiaimbot.anti_brute_triggers:get()
                        if type(list) ~= "table" or #list == 0 then return true end
                        return c_table.contains(list, kind)
                    end

                    -- side: +1 / -1 = the side of the head the bullet passed (0: unknown, a hit)
                    function ab:trigger(reason, attacker, side)
                        local master = config.navigation.aa_enable
                        if master and not master:get() then return end
                        local now = globals.realtime()
                        local enemy = self.enemies[attacker] or { stage = 0, last = -10, side = 0 }
                        if now - enemy.last < 0.08 then return end
                        enemy.stage = (now - enemy.last > 7) and 1 or (enemy.stage % #PATTERNS + 1)
                        -- away from the side the bullet passed, else alternating; never the same side twice in a row
                        side = side ~= 0 and -side or (enemy.stage % 2 == 0 and -1 or 1)
                        if side == enemy.side then side = -side end
                        enemy.last, enemy.side = now, side
                        self.enemies[attacker] = enemy

                        local pattern = PATTERNS[enemy.stage]
                        self.pattern, self.side, self.stage = pattern, side, enemy.stage
                        self.active, self.active_until, self.last_trigger = true, now + pattern.duration, now
                        self.restart_pending = pattern.restart
                        if c_logger.event then
                            local name = tostring(entity_get_player_name(attacker) or "?"):gsub("\a%x%x%x%x%x%x%x%x", ""):gsub("%c", "")
                            c_logger.event("ANTI-BRUTE", 180, 160, 255, {
                                { { "stage " .. self.stage, "k" } }, { { reason, "w" } }, { { "by ", "g" }, { name, "w" } },
                            })
                        else
                            c_logger.log("Anti-brute: stage %d (%s, %s)", self.stage, reason, entity_get_player_name(attacker) or "?")
                        end
                    end

                    function ab:on_hurt(attacker, damage, hitgroup)
                        self.hurt_tick[attacker] = globals_tickcount()
                        if not config.antiaimbot.anti_brute:get() or not wants("Hit") then return end
                        if not hitgroup or hitgroup == 0 or not entity.is_enemy(attacker) then return end
                        self:trigger(string_format("hit, %d dmg", damage), attacker, 0)
                    end

                    -- a teammate the attacker hit: that bullet was not for us
                    function ab:on_team_hurt(attacker)
                        self.team_hurt_tick[attacker] = globals_tickcount()
                    end

                    -- distance of a point to the bullet path (eye -> impact), nil when it is behind the shooter
                    local function path_dist(ex, ey, ez, dx, dy, dz, len2, x, y, z)
                        local t = ((x - ex) * dx + (y - ey) * dy + (z - ez) * dz) / len2
                        if t < 0 then return nil end
                        if t > 1 then t = 1 end
                        local px, py, pz = ex + dx * t - x, ey + dy * t - y, ez + dz * t - z
                        return math_sqrt(px * px + py * py + pz * pz)
                    end

                    -- enemy bullet path passing within 40 units of our head (decided two ticks later,
                    -- once player_hurt had the chance to say it was a hit). Not when it passed nearer to a teammate:
                    -- standing next to each other (T spawn), the shot at the teammate was an "evaded" shot at us
                    function ab:on_impact(attacker, x, y, z)
                        local me = entity_get_local_player()
                        if not me or attacker == me or not x or not entity.is_alive(me) or not entity.is_enemy(attacker) then return end
                        local hx, hy, hz = entity.hitbox_position(me, 0)
                        local ex, ey, ez = entity_get_prop(attacker, "m_vecOrigin")
                        if not hx or not ex then return end
                        ez = ez + (entity_get_prop(attacker, "m_vecViewOffset[2]") or 64)
                        local dx, dy, dz = x - ex, y - ey, z - ez
                        local len2 = dx * dx + dy * dy + dz * dz
                        if len2 < 1 then return end
                        local dist = path_dist(ex, ey, ez, dx, dy, dz, len2, hx, hy, hz)
                        if not dist or dist > 40 then return end
                        for _, mate in ipairs(entity.get_players(false)) do
                            if mate ~= me and mate ~= attacker and not entity.is_enemy(mate) and entity.is_alive(mate) then
                                local mx, my, mz = entity.hitbox_position(mate, 0)
                                local ox, oy, oz = entity_get_prop(mate, "m_vecOrigin")
                                local dh = mx and path_dist(ex, ey, ez, dx, dy, dz, len2, mx, my, mz)
                                local db = ox and path_dist(ex, ey, ez, dx, dy, dz, len2, ox, oy, oz + 40)
                                if (dh and dh < dist) or (db and db < dist) then return end
                            end
                        end
                        -- which side of the head the bullet went past (seen from above)
                        local cross = dx * (hy - ey) - dy * (hx - ex)
                        local side = cross > 0.001 and 1 or (cross < -0.001 and -1 or 0)
                        local tick = globals_tickcount()
                        local p = self.pending[attacker]
                        if not p or p.tick ~= tick then
                            self.pending[attacker] = { tick = tick, dist = dist, side = side }
                        elseif dist < p.dist then
                            p.dist, p.side = dist, side
                        end
                    end

                    function ab:tick()
                        local tick = globals_tickcount()
                        for attacker, p in pairs(self.pending) do
                            if tick - p.tick >= 2 or tick < p.tick then
                                self.pending[attacker] = nil
                                local hurt, mate = self.hurt_tick[attacker], self.team_hurt_tick[attacker]
                                if not (hurt and math_abs(hurt - p.tick) <= 2) and not (mate and math_abs(mate - p.tick) <= 2) then
                                    telemetry.evaded = telemetry.evaded + 1
                                    -- the hit log shows it ("evaded")
                                    if antiaimbot.on_evaded then pcall(antiaimbot.on_evaded, attacker, p.dist) end
                                    if config.antiaimbot.anti_brute:get() and wants("Near miss") then
                                        self:trigger(string_format("near miss, %d u", math_floor(p.dist + 0.5)), attacker, p.side)
                                    end
                                end
                            end
                        end
                        if self.active and globals.realtime() > self.active_until then
                            self.active = false
                        end
                    end

                    client.set_event_callback("paint", function()
                        if not ab.active or not config.antiaimbot.anti_brute:get() then return end
                        if not config.antiaimbot.anti_brute_indicator:get() then return end
                        local me = entity_get_local_player()
                        if not me or not entity.is_alive(me) then return end
                        local now = globals.realtime()
                        local frac = math.min(1, math_max(0, ab.active_until - now) / ab.pattern.duration)
                        local sw, sh = client.screen_size()
                        local x, y = math_floor(sw / 2), math_floor(sh / 2) + 46
                        local r, g, b = 180, 160, 255
                        if config.visuals and config.visuals.panels_color then r, g, b = config.visuals.panels_color:get() end
                        renderer.text(x, y, r, g, b, 255, "c-", 0, string_format("ANTI-BRUTE  %d", ab.stage))
                        local w = 44
                        renderer.rectangle(x - w / 2, y + 7, w, 2, 0, 0, 0, 140)
                        renderer.rectangle(x - w / 2, y + 7, math_floor(w * frac + 0.5), 2, r, g, b, 230)
                    end)

                    function ab:apply(instance)
                        if not self.active or not config.antiaimbot.anti_brute:get() then return false end
                        -- the jitter switch restarts once per trigger: the side the enemy timed is not the one that comes
                        if self.restart_pending then
                            self.restart_pending = false
                            antiaim_state.switch = not antiaim_state.switch
                            antiaim_state.last_packets = player.packets
                        end
                        instance.yaw_offset = c_math.normalize_yaw((instance.yaw_offset or 0) + self.pattern.offset * self.side)
                        return true
                    end

                    function ab:reset()
                        self.active, self.active_until, self.stage = false, 0, 0
                        self.pending, self.restart_pending = {}, false
                    end
                end

                antiaimbot.main.debug = {}

                function antiaimbot.main:run(cmd, me, wpn)
                    antiaimbot.anti_brute:tick()

                    -- "Enable" off: gamesense's own anti-aim takes over, the rage helpers keep running
                    local master = config.navigation.aa_enable
                    if master and not master:get() then
                        if SPECTER_SHARED then SPECTER_SHARED.air_exploit = false end
                        antiaimbot.main.release()
                        antiaimbot.ideal_tick.run(nil)      -- keeps its rage part working / releases it when off
                        antiaimbot.backtrack.run()
                        antiaimbot.main.multipoint(wpn)
                        return
                    end
                    antiaimbot.main.master_off = false
                    -- gamesense's own anti-aim switch has to be on for any of this to show; it used to be turned on only by the
                    -- menu code while the menu was open (with it off in the gamesense config the anti-aim did nothing until
                    -- the menu was opened). override.set does not rewrite an unchanged value
                    override.set(reference.antiaim.master, true)

                    instance:tick()

                    antiaimbot.main.debug.player_exploit = player.air_exploit

                    if antiaimbot.air_exploit.run(
                        config.antiaimbot.air_exploit:get() and config.antiaimbot.air_exploit_hotkey:rawget(), cmd
                    ) then
                        return instance:run()
                    end

                    local player_state = player.state

                    local is_fakelagging = not (c_table.is_hotkey_active(reference.ragebot.doubletap.enable) or c_table.is_hotkey_active(reference.misc.onshot_antiaim))

                    if is_fakelagging or cmd.chokedcommands == 0 then
                        c_animations:tick(globals_tickcount())
                    end

                    local selected_preset = config.antiaimbot.preset:get() do
                        if selected_preset == 'Constructor' then
                            local preset_data = antiaimbot.constructor[player_state]
                            local fakelag_preset = antiaimbot.constructor['Fake lag']

                            if is_fakelagging and fakelag_preset then
                                preset_data = fakelag_preset
                            end

                            if preset_data then
                                self.run_preset(instance, preset_data)
                            end
                        else
                            local preset = presets[selected_preset]
                            if preset then
                                local preset_data = preset[player_state]
                                local fakelag_preset = preset['Fake lag']

                                if is_fakelagging and fakelag_preset then
                                    preset_data = fakelag_preset
                                end

                                if preset_data then
                                    self.run_preset(instance, preset_data)
                                end
                            end
                        end
                    end

                    antiaimbot.main.debug.preset = selected_preset

                    local move_type = entity_get_prop(me, 'm_MoveType')
                    local selected_options = config.antiaimbot.options:get()

                    local anti_brute_active = antiaimbot.anti_brute:apply(instance)
                    antiaimbot.main.debug.anti_brute = anti_brute_active

                    local is_forcing, triggered_defensive = antiaimbot.defensive.force(cmd, me, wpn)

                    antiaimbot.main.debug.state = {
                        fakelag = is_fakelagging,
                        choking = fakelag.choking,
                        state = player_state
                    }

                    antiaimbot.main.debug.defensive = {
                        forcing = is_forcing,
                        triggered = triggered_defensive
                    }

                    if not antiaimbot.features.fast_ladder:run(
                        c_table.contains(selected_options, 'Fast ladder') and move_type == 9, cmd, me, wpn
                    ) and move_type ~= 9 then
                        antiaimbot.features.running = false

                        antiaimbot.main.debug.legit_antiaim = antiaimbot.features.legit_antiaim.run(instance, cmd, me, wpn)
                        antiaimbot.main.debug.manual_antiaim = antiaimbot.features.manual_antiaim.run(instance, cmd, me, wpn)
                        antiaimbot.main.debug.warmup_antiaim = antiaimbot.features.warmup_antiaim.run(instance, cmd, me, wpn)
                        antiaimbot.main.debug.safe_head = antiaimbot.features.safe_head.run(instance, cmd, me, wpn)

                        local avoid_backstab = antiaimbot.features.avoid_backstab.run(instance, cmd, me, wpn)

                        antiaimbot.main.debug.avoid_backstab = avoid_backstab

                        if config.antiaimbot.defensive_aa:get() and not avoid_backstab then
                            antiaimbot.main.debug.defensive = {antiaimbot.defensive:run(instance, cmd, me, wpn, is_forcing, triggered_defensive or false)}
                        end
                    end

                    antiaimbot.ideal_tick.run(instance)
                    antiaimbot.backtrack.run()

                    -- desync inverter (hotkey): flip whatever side was picked this tick, anti-brute included
                    local inverter_key = config.antiaimbot.inverter
                    if inverter_key and inverter_key:rawget() then
                        instance.inverter = not instance.inverter
                        if instance.body_yaw_value then instance.body_yaw_value = -instance.body_yaw_value end
                    end

                    instance:run()

                    antiaimbot.main.multipoint(wpn)
                end

                -- hand every anti-aim override back to gamesense (once per switch-off)
                function antiaimbot.main.release()
                    if antiaimbot.main.master_off then return end
                    antiaimbot.main.master_off = true
                    pcall(instance.reset, instance)
                    pcall(override.unset, reference.antiaim.master)      -- gamesense's own switch back as it was
                    pcall(antiaimbot.air_exploit.run, false)
                    antiaimbot.anti_brute:reset()
                end

                -- the switch also works outside a match (no setup_command running)
                config.navigation.aa_enable:set_callback(function()
                    if not config.navigation.aa_enable:get() then antiaimbot.main.release() end
                end)

                -- improved multi-point (also runs while specter's anti-aim is switched off)
                function antiaimbot.main.multipoint(wpn)
                    if config.ragebot.multipoint:get() and not (wpn and entity.get_classname(wpn) == "CWeaponTaser") then
                        local scale = config.ragebot.multipoint_scale:get()
                        local auto_mp = config.ragebot.multipoint_auto and config.ragebot.multipoint_auto:get()
                        local picked = config.ragebot.multipoint_hitboxes:get() or {}
                        local set = {}
                        for _, name in ipairs(picked) do set[name] = true end
                        if next(set) == nil then set["Head"] = true end

                        -- Auto only pulls the points towards the middle of the hitboxes (more accurate) when the target moves fast, is
                        -- in the air or was missed twice. It used to ADD chest + stomach multipoints then too: in HvH everybody is
                        -- moving almost all the time, so the aimbot found body points that passed the hit chance before the head
                        -- and shot the body
                        if auto_mp then
                            local threat = client.current_threat()
                            local res_data = threat and resolver.database[threat]
                            if res_data then
                                local t_misses = res_data.consecutive_misses or 0
                                if t_misses >= 2 or res_data.stance == "air" or (res_data.speed or 0) > 100 then
                                    scale = math_max(30, scale - 20)
                                end
                            end
                        end

                        local order, list = { "Head", "Chest", "Stomach", "Arms", "Legs", "Feet" }, {}
                        for _, name in ipairs(order) do
                            if set[name] then list[#list + 1] = name end
                        end
                        local key = table_concat(list, ",") .. "|" .. scale .. "|" .. tostring(wpn and entity_get_prop(wpn, "m_iItemDefinitionIndex") or 0)
                        if key ~= antiaimbot.main.mp_last then
                            if antiaimbot.main.mp_saved == nil then
                                local ok1, hb = pcall(ui_get, reference.ragebot.multipoint[1])
                                local ok2, sc = pcall(ui_get, reference.ragebot.multipoint_scale)
                                antiaimbot.main.mp_saved = { ok1 and hb or nil, ok2 and sc or nil }
                            end
                            antiaimbot.main.mp_last = key
                            pcall(ui_set, reference.ragebot.multipoint[1], list)
                            pcall(ui_set, reference.ragebot.multipoint_scale, scale)
                        end
                    elseif antiaimbot.main.mp_saved ~= nil then
                        local saved = antiaimbot.main.mp_saved
                        if saved[1] ~= nil then pcall(ui_set, reference.ragebot.multipoint[1], saved[1]) end
                        if saved[2] ~= nil then pcall(ui_set, reference.ragebot.multipoint_scale, saved[2]) end
                        antiaimbot.main.mp_saved, antiaimbot.main.mp_last = nil, nil
                    end
                end

                function antiaimbot.main.get_instance()
                    return instance
                end
            end

            antiaimbot.animation_breaker = {} do
                antiaimbot.animation_breaker.anim_reset = false

                function antiaimbot.animation_breaker.run(me)
                    local leg_move = config.antiaimbot.animation_breaker_leg:get()
                    local animlayers = ffi_helpers.animlayers:get(me)

                    if leg_move ~= 'Off' and player.onground and (player.state == 'Moving' or player.state == 'Crouch moving') then
                        if leg_move == 'Frozen' then
                            entity.set_prop(me, 'm_flPoseParameter', 1, 0)
                            override.set(reference.misc.leg_movement, "Always slide")
                        elseif leg_move == 'Jitter' and player.state == 'Moving' then
                            entity.set_prop(me, 'm_flPoseParameter', client.random_float(0, 1), 0)
                            if animlayers then animlayers[12]['weight'] = client.random_float(0, 1) end
                            override.set(reference.misc.leg_movement, "Always slide")
                        elseif leg_move == 'Walking' then
                            entity.set_prop(me, 'm_flPoseParameter', 0.5, 7)
                            override.set(reference.misc.leg_movement, "Never slide")
                        elseif leg_move == 'Sliding' and player.state == 'Moving' then
                            entity.set_prop(me, 'm_flPoseParameter', 0, 9)
                            entity.set_prop(me, 'm_flPoseParameter', 0, 10)
                            override.set(reference.misc.leg_movement, "Never slide")
                        else
                            override.unset(reference.misc.leg_movement)
                        end
                    else
                        override.unset(reference.misc.leg_movement)
                    end

                    local air_legs = config.antiaimbot.animation_breaker_air:get()
                    local move_type = entity_get_prop(me, 'm_MoveType')

                    if air_legs ~= 'Off' and not player.onground and not (move_type == 9 or move_type == 8) then
                        if air_legs == 'Frozen' then
                            entity.set_prop(me, 'm_flPoseParameter', 1, 6)
                        elseif air_legs == 'Walking' then
                            local cycle do
                                cycle = globals.realtime() * 0.7 % 2

                                if cycle > 1 then
                                    cycle = 1 - (cycle - 1)
                                end
                            end

                            if animlayers then
                                animlayers[6]['weight'] = 1
                                animlayers[6]['cycle'] = cycle
                            end
                        end
                    end

                    local breaker_options = config.antiaimbot.animation_breaker_other:get()

                    if c_table.contains(breaker_options, 'Slide on slow-motion') and c_table.is_hotkey_active(reference.misc.slowmotion) then
                        entity.set_prop(me, 'm_flPoseParameter', 0, 9)
                    end

                    if c_table.contains(breaker_options, 'Slide on crouching') and (player.state == 'Crouching' or player.state == 'Crouch moving') then
                        entity.set_prop(me, 'm_flPoseParameter', 0, 8)
                    end

                    if c_table.contains(breaker_options, 'Pitch zero on land') and player.landing and player.onground then
                        entity.set_prop(me, 'm_flPoseParameter', 0.5, 12)
                    end
                end

                function antiaimbot.animation_breaker.post(cmd, me)
                    if c_table.contains(config.antiaimbot.animation_breaker_other:get(), 'Quick peek legs') and c_table.is_hotkey_active(reference.ragebot.quick_peek_assist) then
                        local move_type = entity_get_prop(me, 'm_MoveType')

                        if move_type == 2 then
                            local command = ffi_helpers.user_input:get_command(cmd.command_number)

                            if command then
                                command.buttons = bit.band(command.buttons, bit.bnot(8))
                                command.buttons = bit.band(command.buttons, bit.bnot(16))
                                command.buttons = bit.band(command.buttons, bit.bnot(512))
                                command.buttons = bit.band(command.buttons, bit.bnot(1024))
                            else
                                -- no usercmd read: the same buttons through the setup_command fields
                                cmd.in_forward, cmd.in_back, cmd.in_moveleft, cmd.in_moveright = 0, 0, 0, 0
                            end
                        end
                    end
                end
            end

            antiaimbot.air_exploit = {} do
                local exploit_counter = 1

                function antiaimbot.air_exploit.run(enabled, cmd)
                    player.air_exploit = enabled
                    SPECTER_SHARED = SPECTER_SHARED or {}
                    SPECTER_SHARED.air_exploit = enabled and true or false

                    if not enabled then
                        if not antiaimbot.air_exploit.lag_reset then
                            override.unset(reference.ragebot.fakeduck)
                            antiaimbot.air_exploit.lag_reset = true
                        end

                        return
                    end

                    if player.onground or not c_table.is_hotkey_active(reference.ragebot.doubletap.enable) then
                        override.unset(reference.ragebot.fakeduck)

                        return
                    end

                    if globals_tickcount() % 2 == 1 then
                        exploit_counter = exploit_counter + 1
                    end

                    if exploit_counter > 2 then
                        override.set(reference.ragebot.fakeduck, "Always on")

                        exploit_counter = 1
                    else
                        override.set(reference.ragebot.fakeduck, "On hotkey", 0x0)
                    end

                    antiaimbot.air_exploit.lag_reset = false

                    return true
                end
            end

            antiaimbot.ideal_tick = {} do
                local ideal_tick_reset

                function antiaimbot.ideal_tick.run(instance)
                    if config.antiaimbot.ideal_tick:get() and config.antiaimbot.ideal_tick_hotkey:get() then
                        if reference.ragebot.quick_peek_assist then
                            override.set(reference.ragebot.quick_peek_assist[1], true)
                            override.set(reference.ragebot.quick_peek_assist[2], "Always on", 0x0)
                        end

                        if reference.ragebot.enabled then
                            override.set(reference.ragebot.enabled[1], true)
                            override.set(reference.ragebot.enabled[2], "Always on", 0x0)
                        end

                        if reference.ragebot.doubletap then
                            override.set(reference.ragebot.doubletap.enable[1], true)
                            override.set(reference.ragebot.doubletap.enable[2], "Always on", 0x0)
                            override.set(reference.ragebot.doubletap.fakelag, 1)
                        end

                        if instance and not antiaimbot.features.state.manual_antiaim then
                            instance.freestand = true
                        end
                        antiaimbot.features.state.freestanding = true
                        ideal_tick_reset = true
                    else
                        if ideal_tick_reset then
                            if reference.ragebot.quick_peek_assist then
                                override.unset(reference.ragebot.quick_peek_assist[1])
                                override.unset(reference.ragebot.quick_peek_assist[2])
                            end
                            if reference.ragebot.enabled then
                                override.unset(reference.ragebot.enabled[1])
                                override.unset(reference.ragebot.enabled[2])
                            end
                            if reference.ragebot.doubletap then
                                override.unset(reference.ragebot.doubletap.enable[1])
                                override.unset(reference.ragebot.doubletap.enable[2])
                                override.unset(reference.ragebot.doubletap.fakelag)
                            end

                            antiaimbot.features.state.freestanding = false
                            ideal_tick_reset = false
                        end
                    end
                end
            end

            antiaimbot.backtrack = {} do
                local best_level = nil

                function antiaimbot.backtrack.level()
                    local wanted = config.ragebot.backtrack_level and config.ragebot.backtrack_level:get() or "High"
                    if wanted ~= "Maximum" then return "High" end
                    if best_level then return best_level end
                    best_level = "High"
                    local ref = reference.ragebot.backtrack
                    local ok, current = pcall(ui_get, ref)
                    if pcall(ui_set, ref, "Maximum") then
                        local ok2, now = pcall(ui_get, ref)
                        if ok2 and now == "Maximum" then best_level = "Maximum" end
                    end
                    if ok then pcall(ui_set, ref, current) end
                    return best_level
                end

                local forced = false

                function antiaimbot.backtrack.run()
                    local enabled = config.ragebot.backtrack_optimization:get()
                    if enabled then
                        pcall(override.set, reference.ragebot.backtrack, antiaimbot.backtrack.level())
                        forced = true
                    elseif forced then
                        override.unset(reference.ragebot.backtrack)
                        forced = false
                    end
                end
            end

            antiaimbot.manual_antiaim = {} do
                local list = {}

                antiaimbot.manual_antiaim.state = -1
                antiaimbot.manual_antiaim.MANUAL_LEFT = 1
                antiaimbot.manual_antiaim.MANUAL_RIGHT = 2
                antiaimbot.manual_antiaim.MANUAL_BACK = 3
                antiaimbot.manual_antiaim.MANUAL_FORWARD = 4

                antiaimbot.manual_antiaim.convert = {
                    [antiaimbot.manual_antiaim.MANUAL_LEFT] = -90,
                    [antiaimbot.manual_antiaim.MANUAL_RIGHT] = 90,
                    [antiaimbot.manual_antiaim.MANUAL_BACK] = 0,
                    [antiaimbot.manual_antiaim.MANUAL_FORWARD] = 180
                }

                for i=1, #config.manuals do
                    list[#list+1] = {
                        prev = false,
                        ref = config.manuals[i],

                        change = function (self, new_value)
                            if new_value then
                                antiaimbot.manual_antiaim.state = (antiaimbot.manual_antiaim.state == i or i == 5) and -1 or i
                            end
                        end,

                        update = function (self)
                            local new_value, mode = self.ref:rawget()

                            if new_value ~= self.prev then
                                self:change(mode == 2 and true or new_value)

                                self.prev = new_value
                            end
                        end
                    }
                end

                function antiaimbot.manual_antiaim.update()
                    for i=1, #list do
                        list[i]:update();
                    end
                end
            end

            function antiaimbot:predict_command(cmd, me, wpn)
                self.manual_antiaim.update()

                if not me then
                    return
                end

                if config.antiaimbot.animation_breaker:get() then
                    self.animation_breaker.run(me)

                    self.animation_breaker.anim_reset = false
                elseif not self.anim_reset then
                    override.unset(reference.misc.leg_movement)
                    self.animation_breaker.anim_reset = true
                end
            end

            function antiaimbot:setup_command(cmd, me, wpn)
                -- quick peek legs without the usercmd read: the buttons off here, in setup_command (finish_command is too late)
                if me and not ffi_helpers.user_input.location and config.antiaimbot.animation_breaker:get() then
                    self.animation_breaker.post(cmd, me)
                end

                if me == nil then
                    return
                end

                self.main:run(cmd, me, wpn)
            end

            function antiaimbot:finish_command(cmd, me, wpn)
                if not me then
                    return
                end

                if config.antiaimbot.animation_breaker:get() then
                    self.animation_breaker.post(cmd, me);
                end
            end
        end
    end

    ---
    --- Builder
    ---
    local antiaimbot_builder do
        config.builder = {} do
            config.builder.antiaim_state = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "State\naa_builder", c_table.combine_arrays({"Global", "Fake lag"}, c_constant.STATE_LIST))
                :config_ignore()

            config.builder.defensive_state = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  State\ndefensive_builder", c_table.combine_arrays({"Global"}, c_constant.DEFENSIVE_STATES, c_constant.STATE_LIST))
                :config_ignore()
        end

        antiaimbot_builder = {} do
            antiaimbot_builder.settings = {} do
                local global_state_list = c_table.combine_arrays({'Global', 'Fake lag'}, c_constant.STATE_LIST)

                for i=1, #global_state_list do
                    local state = global_state_list[i]

                    antiaimbot_builder.settings[state] = {}

                    local this = antiaimbot_builder.settings[state]

                    if state ~= "Global" then
                        this.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", table_concat { "Override Global", "\n", "AA", state })
                            :record("builder", table_concat { "AA", "::", state, "::Enabled" })
                            :save()
                    end

                    this.gap_yaw = mui.spacer(mui.CONTENT)
                    this.hdr_yaw = mui.header(mui.CONTENT, "↻", "Angles")
                    this.pitch = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", table_concat { "Pitch", "\n", "AA", state }, {
                        "Off",
                        "Default",
                        "Up",
                        "Down",
                        "Minimal",
                        "Random",
                        "Custom", "Constructor"
                    }):record("builder", table_concat { "AA", "::", state, "::Pitch" }):save()

                    this.pitch_amount = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "\n", "Pitch custom", "AA", state }, -89, 89, 0, true, "°", 1)
                        :record("builder", table_concat { "AA", "::", state, "::PitchCustom" })
                        :save()

                    this.yaw_base = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", table_concat { "Yaw base", "\n", "AA", state }, {
                        "Local view",
                        "At targets"
                    }):record("builder", table_concat { "AA", "::", state, "::YawBase" }):save()

                    this.yaw_type = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", table_concat { "Yaw", "\n", "AA", state }, {
                        "Off",
                        "180",
                        "Spin",
                        "Static",
                        "180 Z",
                        "Crosshair",
                        "Left & Right",
                        "Flick",
                        "Sway",
                        "Spin between"
                    }):record("builder", table_concat { "AA", "::", state, "::YawType" }):save()

                    this.yaw_amount = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "\n", "Yaw custom", "AA", state }, -180, 180, 0, true, "°", 1)
                        :record("builder", table_concat { "AA", "::", state, "::YawCustom" })
                        :save()

                    this.yaw_left = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Left", "\n", "AA", state }, -180, 180, 0, true, "°", 1)
                        :record("builder", table_concat { "AA", "::", state, "::YawLeft" })
                        :save()

                    this.yaw_right = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Right", "\n", "AA", state }, -180, 180, 0, true, "°", 1)
                        :record("builder", table_concat { "AA", "::", state, "::YawRight" })
                        :save()

                    this.yaw_delayed_switch = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", table_concat { "•  Delayed switch", "\n", "AA", state })
                        :record("builder", table_concat { "AA", "::", state, "::YawDelayedSwitch" })
                        :save()

                    this.yaw_switch_delay = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Switch delay", "\n", "AA", state }, 1, 12, 6, true, "t", 1, {[0] = "Off"})
                        :record("builder", table_concat { "AA", "::", state, "::YawSwitchDelay" })
                        :save()

                    this.yaw_switch_delay_second = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Switch delay 2", "\n", "AA", state }, 1, 12, 6, true, "t", 1, {[0] = "Off"})
                        :record("builder", table_concat { "AA", "::", state, "::YawSwitchDelaySecond" })
                        :save()

                    -- Yaw logic of the delayed switch: Random (a delay between the two sliders, sometimes held), Interval
                    -- (always the first delay), Logical (the interval, and at once when an enemy shot near us / hit us)
                    this.yaw_logic = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", table_concat { "•  Yaw logic", "\n", "AA", state }, {
                        "Random", "Interval", "Logical", "Sequence"
                    }):record("builder", table_concat { "AA", "::", state, "::YawLogic" }):save()

                    -- Sequence: the switch delays one after the other (delay, delay 2, step 3, step 4), then again
                    this.yaw_seq_len = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Sequence steps", "\n", "AA", state }, 2, 4, 3, true, "")
                        :record("builder", table_concat { "AA", "::", state, "::YawSeqLen" }):save()
                    this.yaw_seq3 = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Step 3", "\n", "AA", state }, 1, 12, 3, true, "t")
                        :record("builder", table_concat { "AA", "::", state, "::YawSeq3" }):save()
                    this.yaw_seq4 = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Step 4", "\n", "AA", state }, 1, 12, 8, true, "t")
                        :record("builder", table_concat { "AA", "::", state, "::YawSeq4" }):save()

                    this.yaw_delay = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Delay", "\n", "AA", state }, 1, 64, 5, true, "t", 1, {[0] = "Off"})
                        :record("builder", table_concat { "AA", "::", state, "::YawDelay" })
                        :save()

                    this.yaw_speed = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Speed", "\n", "AA", state }, 1, 64, 5, true, "t", 1, {[0] = "Off"})
                        :record("builder", table_concat { "AA", "::", state, "::YawSpeed" })
                        :save()

                    this.gap_mod = mui.spacer(mui.CONTENT)
                    this.hdr_mod = mui.header(mui.CONTENT, "≈", "Modifier")
                    this.yaw_jitter = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", table_concat { "Modifier", "\n", "AA", state }, {
                        "Off",
                        "Offset",
                        "Center",
                        "Random",
                        "Skitter",
                        "3-Way",
                        "5-Way",
                        "Delayed center",
                        "Distortion",
                        "Random hold"
                    }):record("builder", table_concat { "AA", "::", state, "::YawJitter" }):save()

                    this.jitter_value = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "\n", "Jitter value", "AA", state }, -180, 180, 0, true, "°", 1)
                        :record("builder", table_concat { "AA", "::", state, "::JitterValue" })
                        :save()

                    this.jitter_randomize = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Randomize", "\n", "AA", state }, -180, 180, 0, true, "°", 1, {[0] = "Off"})
                        :record("builder", table_concat { "AA", "::", state, "::JitterRandomize" })
                        :save()

                    this.gap_body = mui.spacer(mui.CONTENT)
                    this.hdr_body = mui.header(mui.CONTENT, "⇄", "Body Yaw")
                    this.body_yaw = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", table_concat { "Body Yaw", "\n", "AA", state }, {
                        "Off",
                        "Opposite",
                        "Jitter",
                        "Static",
                        "Sync",
                        "Freestand"
                    }):record("builder", table_concat { "AA", "::", state, "::BodyYaw" }):save()

                    this.body_value = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "\n", "Body value", "AA", state }, -180, 180, 0, true, "°", 1)
                        :record("builder", table_concat { "AA", "::", state, "::BodyValue" })
                        :save()
                end

                local function onStateChange()
                    antiaimbot.constructor = {}

                    local state_list = c_table.combine_arrays({'Fake lag'}, c_constant.STATE_LIST)

                    for i=1, #state_list do
                        local state = state_list[i]

                        antiaimbot.constructor[state] = {}

                        local this = antiaimbot.constructor[state]
                        local is_enabled = antiaimbot_builder.settings[state].enabled:get()

                        if not is_enabled and state == 'Fake lag' then
                            antiaimbot.constructor[state] = nil

                            goto continue
                        end

                        local menu_state = is_enabled and antiaimbot_builder.settings[state] or antiaimbot_builder.settings['Global']

                        this.pitch = menu_state.pitch:get()
                        this.pitch_custom = menu_state.pitch_amount:get()

                        this.yaw_base = menu_state.yaw_base:get()

                        local yaw_type = menu_state.yaw_type:get()

                        this.yaw_type = yaw_type

                        if yaw_type == 'Left & Right' then
                            local yaw_delay = menu_state.yaw_switch_delay:get()

                            this.yaw_delay = menu_state.yaw_delayed_switch:get() and yaw_delay or nil
                            this.yaw_delay_second = menu_state.yaw_switch_delay_second:get()
                            this.yaw_logic = menu_state.yaw_logic and menu_state.yaw_logic:get() or "Random"
                            if this.yaw_logic == "Sequence" and menu_state.yaw_seq_len then
                                local seq = { yaw_delay, this.yaw_delay_second, menu_state.yaw_seq3:get(), menu_state.yaw_seq4:get() }
                                local n = menu_state.yaw_seq_len:get()
                                for i = #seq, n + 1, -1 do seq[i] = nil end
                                this.yaw_sequence = seq
                            else
                                this.yaw_sequence = nil
                            end
                            this.left_offset = menu_state.yaw_left:get()
                            this.right_offset = menu_state.yaw_right:get()
                        elseif yaw_type == 'Flick' or yaw_type == 'Sway' or yaw_type == 'Spin between' then
                            this.left_offset = menu_state.yaw_left:get()
                            this.right_offset = menu_state.yaw_right:get()
                            this.yaw_delay = menu_state.yaw_delay:get()
                            this.yaw_speed = menu_state.yaw_speed:get()
                        else
                            this.yaw_offset = menu_state.yaw_amount:get()
                        end

                        local jitter_type = menu_state.yaw_jitter:get()

                        this.yaw_modifier = jitter_type

                        this.modifier_offset = menu_state.jitter_value:get()
                        this.modifier_randomize = menu_state.jitter_randomize:get()

                        this.body_yaw_type = menu_state.body_yaw:get()
                        this.body_yaw_value = menu_state.body_value:get()

                        ::continue::
                    end

                    antiaimbot.constructor['Legit AA'] = {
                        pitch = 'Off',
                        yaw_base = 'Local view',
                        yaw_type = 'Left & Right',
                        left_offset = 165,
                        right_offset = -165,

                        yaw_delay = 1,
                        yaw_delay_second = 6
                    }
                end

                local builder_keys = menu.get_records()["builder"]

                for key, element in pairs(builder_keys) do
                    element:set_callback(onStateChange)
                end

                antiaimbot_builder.refresh = onStateChange
                onStateChange()
            end

            antiaimbot_builder.defensive_settings = {} do
                local defensive_state_list = c_table.combine_arrays({'Global'}, c_constant.DEFENSIVE_STATES, c_constant.STATE_LIST)

                for i=1, #defensive_state_list do
                    local state = defensive_state_list[i]

                    antiaimbot_builder.defensive_settings[state] = {}

                    local this = antiaimbot_builder.defensive_settings[state]

                    this.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", table_concat { (state == "Global" or state == "Safe head" or state == "Edge direction" or state == "Triggered") and "Enable" or "Override Global", "\n", "DEF", state })
                        :record("defensive", table_concat { "DEF", "::", state, "::Enabled" })
                        :save()

                    if state == "Edge direction" then
                        this.enable_on = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", table_concat { "•  Target", "\n", "DEF", state }, {"Freestanding", "Manual yaw"})
                            :record("defensive", table_concat { "DEF", "::", state, "::Target" })
                            :save()
                    end

                    if state == "Safe head" or state == "Edge direction" or state == "Triggered" then
                        goto ignore
                    end

                    this.pitch = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", table_concat { "Pitch", "\n", "DEF", state }, {
                        "Default",
                        "Up",
                        "Zero",
                        "Up Switch",
                        "Down Switch",
                        "Snap",
                        "Random",
                        "Sway",
                        "Flick up",
                        "Half up",
                        "Cycling",
                        "Custom", "Constructor"
                    }):record("defensive", table_concat { "DEF", "::", state, "::Pitch" }):save()

                    this.pitch_cycle = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", table_concat { "•  Cycling type", "\n", "DEF", state }, {
                        "Up / Down", "Up / Zero / Down", "Down / Zero / Up / Zero", "Random order"
                    }):record("defensive", table_concat { "DEF", "::", state, "::PitchCycle" }):save()

                    this.pitch_custom = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "\n", "Pitch custom", "DEF", state }, -89, 89, 89, true, "°", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::PitchCustom" })
                        :save()

                    this.yaw = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", table_concat { "Yaw", "\n", "DEF", state }, {
                        "Default",
                        "Forward",
                        "Sideways",
                        "Delayed",
                        "Scissors",
                        "Spinbot",
                        "3-Way",
                        "5-Way",
                        "Snap",
                        "Random",
                        "Flick",
                        "Sway",
                        "Distortion",
                        "Random side",
                        "Freestand"
                    }):record("defensive", table_concat { "DEF", "::", state, "::Yaw" }):save()

                    this.yaw_from = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  From", "\n", "DEF", state }, -180, 180, 0, true, "°", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawFrom" })
                        :save()
                    this.yaw_to = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  To", "\n", "DEF", state }, -180, 180, 0, true, "°", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawTo" })
                        :save()
                    this.yaw_speed = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Speed", "\n", "DEF", state }, 1, 64, 1, true, "t", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawSpeed" })
                        :save()

                    this.yaw_left = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Left", "\n", "DEF", state }, -180, 180, 0, true, "°", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawLeft" })
                        :save()
                    this.yaw_right = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Right", "\n", "DEF", state }, -180, 180, 0, true, "°", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawRight" })
                        :save()

                    this.yaw_left_start = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Left start", "\n", "DEF", state }, -180, 180, 0, true, "°", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawLeftStart" })
                        :save()
                    this.yaw_left_target = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Left target", "\n", "DEF", state }, -180, 180, 0, true, "°", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawLeftTarget" })
                        :save()

                    this.yaw_right_start = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Right start", "\n", "DEF", state }, -180, 180, 0, true, "°", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawRightStart" })
                        :save()
                    this.yaw_right_target = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Right target", "\n", "DEF", state }, -180, 180, 0, true, "°", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawRightTarget" })
                        :save()

                    this.yaw_delay = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Delay", "\n", "DEF", state }, 1, 8, 6, true, "t", 1)
                        :record("defensive", table_concat { "DEF", "::", state, "::YawDelay" })
                        :save()
                    this.yaw_randomize = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", table_concat { "•  Randomize", "\n", "DEF", state }, 0, 180, 0, true, "°", 1, { [0] = "Off" })
                        :record("defensive", table_concat { "DEF", "::", state, "::YawRandomize" })
                        :save()

                    ::ignore::
                end

                local function onStateChange()
                    antiaimbot.defensive_constructor = {}

                    for i=1, #defensive_state_list do
                        local state = defensive_state_list[i]

                        antiaimbot.defensive_constructor[state] = {}

                        local this = antiaimbot.defensive_constructor[state]
                        local is_enabled = antiaimbot_builder.defensive_settings[state].enabled:get()
                        local is_global = false

                        if not is_enabled then
                            local global_state = antiaimbot_builder.defensive_settings['Global']

                            if not global_state.enabled:get() then
                                antiaimbot.defensive_constructor[state] = nil

                                goto continue
                            else
                                is_global = true
                            end
                        end

                        local menu_state = antiaimbot_builder.defensive_settings[state]

                        if is_global then
                            menu_state = antiaimbot_builder.defensive_settings['Global']
                        end

                        if is_global then
                            this.enable_on = {'Freestanding', 'Manual yaw'}
                            this.global_set = true
                        else
                            if state == 'Edge direction' then
                                this.enable_on = menu_state.enable_on:get()
                            end
                        end

                        if state == 'Safe head' or state == 'Edge direction' or state == 'Triggered' then
                            goto continue
                        end

                        this.pitch = menu_state.pitch:get()
                        this.pitch_custom = menu_state.pitch_custom:get()
                        this.pitch_cycle = menu_state.pitch_cycle and menu_state.pitch_cycle:get() or "Up / Down"

                        this.yaw = menu_state.yaw:get()

                        this.yaw_left = menu_state.yaw_left:get()
                        this.yaw_right = menu_state.yaw_right:get()
                        this.yaw_delay = menu_state.yaw_delay:get()

                        this.yaw_from = menu_state.yaw_from:get()
                        this.yaw_to = menu_state.yaw_to:get()
                        this.yaw_speed = menu_state.yaw_speed:get()

                        this.yaw_left_start = menu_state.yaw_left_start:get()
                        this.yaw_left_target = menu_state.yaw_left_target:get()

                        this.yaw_right_start = menu_state.yaw_right_start:get()
                        this.yaw_right_target = menu_state.yaw_right_target:get()

                        this.yaw_randomize = menu_state.yaw_randomize:get()

                        ::continue::
                    end
                end

                local builder_keys = menu.get_records()["defensive"]

                for key, element in pairs(builder_keys) do
                    element:set_callback(onStateChange)
                end

                antiaimbot_builder.refresh_defensive = onStateChange
                config_system.after_import = function()
                    pcall(antiaimbot_builder.refresh)
                    pcall(antiaimbot_builder.refresh_defensive)
                end
                onStateChange()
            end

            antiaimbot_builder.default_aa = {
                ["Global"]        = { l = -20, r = 36, d1 = 2, d2 = 4, jit = "Off",    jv = 0,  rnd = 0 },
                ["Fake lag"]      = { l = -24, r = 40, d1 = 1, d2 = 2, jit = "Off",    jv = 0,  rnd = 0 },
                ["Standing"]      = { l = -22, r = 38, d1 = 2, d2 = 5, jit = "Off",    jv = 0,  rnd = 0 },
                ["Slow-motion"]   = { l = -18, r = 34, d1 = 2, d2 = 4, jit = "Off",    jv = 0,  rnd = 0 },
                ["Moving"]        = { l = -26, r = 40, d1 = 1, d2 = 3, jit = "Off",    jv = 0,  rnd = 0 },
                ["Crouching"]     = { l = -20, r = 35, d1 = 3, d2 = 6, jit = "Off",    jv = 0,  rnd = 0 },
                ["Crouch moving"] = { l = -24, r = 38, d1 = 2, d2 = 4, jit = "Off",    jv = 0,  rnd = 0 },
                ["Air"]           = { l = -30, r = 45, d1 = 1, d2 = 2, jit = "Center", jv = 10, rnd = 8 },
                ["Air & Crouch"]  = { l = -28, r = 42, d1 = 1, d2 = 3, jit = "Center", jv = 8,  rnd = 6 },
            }

            antiaimbot_builder.default_def_extra = {
                ["Global"]         = false,
                ["Legit AA"]       = false,
                ["Safe head"]      = true,
                ["Triggered"]      = true,
                ["Edge direction"] = true,
            }

            function antiaimbot_builder.load_defaults()
                for state, v in pairs(antiaimbot_builder.default_aa) do
                    local s = antiaimbot_builder.settings[state]
                    if s then
                        pcall(function()
                            if s.enabled then s.enabled:set(true) end
                            s.pitch:set("Minimal")
                            s.pitch_amount:set(0)
                            s.yaw_base:set("At targets")
                            s.yaw_type:set("Left & Right")
                            s.yaw_amount:set(0)
                            s.yaw_left:set(v.l)
                            s.yaw_right:set(v.r)
                            s.yaw_delayed_switch:set(true)
                            s.yaw_switch_delay:set(v.d1)
                            s.yaw_switch_delay_second:set(v.d2)
                            s.yaw_jitter:set(v.jit)
                            s.jitter_value:set(v.jv)
                            s.jitter_randomize:set(v.rnd)
                            s.body_yaw:set("Jitter")
                            s.body_value:set(-1)
                        end)
                    end
                end

                local auto = c_constant.defensive_presets["Auto"]
                for state, s in pairs(antiaimbot_builder.defensive_settings) do
                    pcall(function()
                        local p = auto[state] or (c_table.contains(c_constant.STATE_LIST, state) and auto["Standing"]) or nil
                        local extra = antiaimbot_builder.default_def_extra[state]
                        if extra ~= nil then
                            s.enabled:set(extra)
                        else
                            s.enabled:set(p ~= nil)
                        end
                        if s.enable_on and p and p.enable_on then s.enable_on:set(p.enable_on) end
                        if p and s.pitch then
                            s.pitch:set(p.pitch or "Default")
                            s.pitch_custom:set(p.pitch_custom or 0)
                            s.yaw:set(p.yaw or "Default")
                            s.yaw_left:set(p.yaw_left or 0)
                            s.yaw_right:set(p.yaw_right or 0)
                            s.yaw_delay:set(c_math.clamp(p.yaw_delay or 2, 1, 8))
                            s.yaw_from:set(p.yaw_from or -180)
                            s.yaw_to:set(p.yaw_to or 180)
                            s.yaw_speed:set(c_math.clamp(p.yaw_speed or 30, 1, 64))
                            s.yaw_left_start:set(p.yaw_left_start or 0)
                            s.yaw_left_target:set(p.yaw_left_target or 0)
                            s.yaw_right_start:set(p.yaw_right_start or 0)
                            s.yaw_right_target:set(p.yaw_right_target or 0)
                            s.yaw_randomize:set(p.yaw_randomize or 0)
                        end
                    end)
                end

                local function put(item, value)
                    if item then pcall(item.set, item, value) end
                end
                local aa, fl = config.antiaimbot, config.fakelag or {}

                put(aa.options, { "On use antiaim", "Fast ladder" })
                put(aa.defensive_aa, true)
                put(aa.force_target_yaw, true)
                put(aa.defensive_target, { "Double tap", "On shot anti-aim" })
                put(aa.defensive_conditions, { "Crouching", "Crouch moving", "Air", "Air & Crouch" })
                put(aa.defensive_triggers, { "Flashed", "Damage received", "Reloading", "Weapon switch" })
                put(aa.safe_head, true)
                put(aa.safe_head_conditions, { "Air knife", "Air zeus", "Air & Crouch", "Crouch moving", "Crouching" })
                put(aa.anti_brute, true)
                put(aa.manual_yaw, true)
                put(aa.manual_options, { "Jitter disabled" })
                put(aa.fs_options, { "Jitter disabled" })
                put(aa.freestanding_disabler_states, { "Air", "Air & Crouch" })

                put(fl.enable, true)
                put(fl.type, "Randomize")
                put(fl.ticks, 14)

                pcall(function() config.antiaimbot.preset:set("Constructor") end)
                pcall(function() config.antiaimbot.defensive_preset:set("Constructor") end)
                pcall(antiaimbot_builder.refresh)
                pcall(antiaimbot_builder.refresh_defensive)
            end
        end
    end

    do
        config.fakelag = {} do

            config.fakelag.hdr = mui.header(mui.SIDE, "≋", "Fake lag")
            config.fakelag.enable = menu.new_item(ui.new_checkbox, "AA", "Other", "Custom Fake Lag")
                :record("fakelag", "enable")
                :save()

            config.fakelag.type = menu.new_item(ui.new_combobox, "AA", "Other", "•  Mode\nfakelag", {
                "Static",
                "Cycle",
                "Randomize",
                "Fluctuate",
                "Adaptive"
            }):record("fakelag", "type"):save()

            config.fakelag.ticks = menu.new_item(ui.new_slider, "AA", "Other", "•  Limit\nfakelag", 1, 15, 14, true, "t", 1)
                :record("fakelag", "ticks")
                :save()

            config.fakelag.variance = menu.new_item(ui.new_slider, "AA", "Other", "•  Variance\nfakelag", 0, 100, 30, true, "%", 1)
                :record("fakelag", "variance")
                :save()

            config.fakelag.triggers = menu.new_item(ui.new_multiselect, "AA", "Other", "•  Max choke on\nfakelag", {
                "Peek",
                "Air",
                "Landing",
                "Damage received",
                "Weapon switch"
            }):record("fakelag", "triggers"):save()

            config.fakelag.smart_lc = menu.new_item(ui.new_checkbox, "AA", "Other", "•  Break lag comp\nfakelag")
                :record("fakelag", "smart_lc")
                :save()
            config.fakelag.lc_on = menu.new_item(ui.new_multiselect, "AA", "Other", "•  Break when\nfakelag", { "In air", "On ground", "On peek" })
                :record("fakelag", "lc_on"):save()
            pcall(function() config.fakelag.lc_on:set({ "In air", "On peek" }) end)

            pcall(function() config.fakelag.triggers:set({ "Peek", "Air", "Damage received" }) end)
            pcall(function() config.fakelag.smart_lc:set(true) end)
        end
    end

    ---
    --- Visuals
    ---
    local visuals do
        config.visuals = {} do
            config.visuals.indicators = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Crosshair Indicators")
                :record("visuals", "indicators"):save()

            config.visuals.indicator_color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "\nindicator_color", 100, 150, 255, 255)
                :record("visuals", "indicator_color")
                :save()
            -- custom gradient: the crosshair indicators sweep between the first and this second color
            config.visuals.indicator_gradient = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "•  Gradient color\nindicators")
                :record("visuals", "indicator_gradient"):save()
            config.visuals.indicator_color2 = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "\nindicator_color2", 255, 120, 200, 255)
                :record("visuals", "indicator_color2"):save()
            config.visuals.indicator_gradient_speed = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Gradient speed\nindicators", 1, 20, 6)
                :record("visuals", "indicator_gradient_speed"):save()

            config.visuals.indicator_style = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Style\nindicators", {
                "Specter",
                "Nova",
                "Modern",
                "Legacy",
                "Renewed"
            }):record("visuals", "indicator_style"):save()

            config.visuals.nova_elements = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Elements\nnova", {
                "Halo", "Brand", "State", "Binds", "Defensive"
            }):record("visuals", "nova_elements"):save()
            pcall(function() config.visuals.nova_elements:set({ "Halo", "Brand", "State", "Binds", "Defensive" }) end)

            config.visuals.indicator_renewed_color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "•  Renewed color\nindicators", 255, 255, 255, 255)
                :record("visuals", "indicator_renewed_color")
                :save()

            config.visuals.indicator_vertical_offset = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Vertical offset\nindicators", 20, 100, 10, true, "px")
                :record("visuals", "indicator_vertical_offset")
                :save()

            config.visuals.indicator_options = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Settings\nindicators", {
                "Velocity modifier",
                "Adjust while scoped",
                "Alter alpha while scoped",
                "Alter alpha on grenade"
            }):record("visuals", "indicator_options"):save()


            config.visuals.custom_scope = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Custom Scope Overlay")
                :record("visuals", "custom_scope"):save()
            config.visuals.custom_scope_color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "\ncustom_scope_color", 255, 255, 255, 255)
                :record("visuals", "custom_scope_color"):save()
            config.visuals.custom_scope_length = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Length\nscope", 10, 400, 120, true, "px")
                :record("visuals", "custom_scope_length"):save()
            config.visuals.custom_scope_gap = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Gap\nscope", 0, 150, 10, true, "px")
                :record("visuals", "custom_scope_gap"):save()
            config.visuals.custom_scope_thickness = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Thickness\nscope", 1, 5, 1, true, "px")
                :record("visuals", "custom_scope_thickness"):save()
            config.visuals.custom_scope_speed = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Animation speed\nscope", 1, 30, 12)
                :record("visuals", "custom_scope_speed"):save()
            config.visuals.custom_scope_options = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Settings\nscope", {
                "Gradient",
                "Invert gradient",
                "Animate",
                "Hide top line",
                "Center dot"
            }):record("visuals", "custom_scope_options"):save()
            pcall(function() config.visuals.custom_scope_options:set({"Gradient", "Animate"}) end)

            do
                local ok_ref, remove_scope_ref = pcall(ui_reference, "VISUALS", "Effects", "Remove scope overlay")
                if not ok_ref then remove_scope_ref = nil end

                local scope = { progress = 0, saved = nil, active = false }

                local function scoped_state(me)
                    if not me or not entity.is_alive(me) then return false end
                    local wpn = entity.get_player_weapon(me)
                    if not wpn then return false end
                    local zoom = entity_get_prop(wpn, "m_zoomLevel")
                    if zoom == nil or zoom <= 0 then return false end
                    if entity_get_prop(me, "m_bIsScoped") ~= 1 then return false end
                    if entity_get_prop(me, "m_bResumeZoom") == 1 then return false end
                    return true
                end

                local function take_over()
                    if scope.active or not remove_scope_ref then return end
                    local ok, current = pcall(ui_get, remove_scope_ref)
                    scope.saved = ok and current or false
                    scope.active = true
                end

                local function release()
                    if not scope.active then return end
                    scope.active = false
                    if remove_scope_ref then pcall(ui_set, remove_scope_ref, scope.saved and true or false) end
                end

                client.set_event_callback("paint_ui", function()
                    if not config.visuals.custom_scope:get() then
                        release()
                        scope.progress = 0
                        return
                    end
                    take_over()
                    if remove_scope_ref then pcall(ui_set, remove_scope_ref, true) end
                end)

                local function draw_scope()
                    if not config.visuals.custom_scope:get() then return end
                    if remove_scope_ref then pcall(ui_set, remove_scope_ref, false) end

                    local opts = config.visuals.custom_scope_options:get() or {}
                    local animate = c_table.contains(opts, "Animate")
                    local target = scoped_state(entity_get_local_player()) and 1 or 0
                    if animate then
                        local speed = config.visuals.custom_scope_speed:get() or 12
                        local step = globals_frametime() * speed
                        scope.progress = c_math.clamp(scope.progress + (target == 1 and step or -step), 0, 1)
                    else
                        scope.progress = target
                    end
                    if scope.progress <= 0 then return end

                    local p = scope.progress
                    local eased = 1 - (1 - p) * (1 - p)
                    local r, g, b, a = config.visuals.custom_scope_color:get()
                    a = math_floor((a or 255) * eased)
                    local sw, sh = client.screen_size()
                    local scale = sh / 1080
                    local cx, cy = math_floor(sw / 2), math_floor(sh / 2)
                    local len = math_floor((config.visuals.custom_scope_length:get() or 120) * scale * (animate and eased or 1))
                    local gap = math_floor((config.visuals.custom_scope_gap:get() or 10) * scale)
                    local t = config.visuals.custom_scope_thickness:get() or 1
                    local half = math_floor(t / 2)
                    if len < 1 then return end

                    local near, far = a, a
                    if c_table.contains(opts, "Gradient") then
                        far = 0
                        if c_table.contains(opts, "Invert gradient") then near, far = 0, a end
                    end

                    renderer.gradient(cx + gap, cy - half, len, t, r, g, b, near, r, g, b, far, true)
                    renderer.gradient(cx - gap - len, cy - half, len, t, r, g, b, far, r, g, b, near, true)
                    renderer.gradient(cx - half, cy + gap, t, len, r, g, b, near, r, g, b, far, false)
                    if not c_table.contains(opts, "Hide top line") then
                        renderer.gradient(cx - half, cy - gap - len, t, len, r, g, b, far, r, g, b, near, false)
                    end
                    if c_table.contains(opts, "Center dot") then
                        renderer.rectangle(cx - half, cy - half, t, t, r, g, b, a)
                    end
                end

                local scope_errors = {}
                client.set_event_callback("paint", function()
                    local ok, err = pcall(draw_scope)
                    if not ok then
                        err = tostring(err)
                        if not scope_errors[err] then
                            scope_errors[err] = true
                            client.error_log("[specter] custom scope: " .. err)
                        end
                    end
                end)

                client.set_event_callback("shutdown", function() pcall(release) end)
            end
            config.visuals.watermark = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Watermark")
                :record("visuals", "watermark"):save()
            config.visuals.watermark_color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "\nwatermark_color", 180, 160, 255, 255)
                :record("visuals", "watermark_color"):save()
            config.visuals.watermark_fields = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Fields\nwatermark", {
                "Username", "FPS", "Ping", "Tickrate", "Time"
            }):record("visuals", "watermark_fields"):save()
            config.visuals.watermark_position = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Position\nwatermark", {
                "Top right", "Top left", "Bottom center", "Custom (drag)"
            }):record("visuals", "watermark_position"):save()
            config.visuals.watermark_style = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Style\nwatermark", {
                "Minimal", "Split", "Glass", "Neon"
            }):record("visuals", "watermark_style"):save()
            config.visuals.watermark_effects = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Effects\nwatermark", {
                "Glow", "Animated line", "Shadow", "Icons"
            }):record("visuals", "watermark_effects"):save()
            config.visuals.watermark_x = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nwatermark_x", 0, 1000, 850, false)
                :record("visuals", "watermark_x"):save()
            config.visuals.watermark_y = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nwatermark_y", 0, 1000, 12, false)
                :record("visuals", "watermark_y"):save()
            pcall(function() config.visuals.watermark:set(true) end)
            pcall(function() config.visuals.watermark_fields:set({"Username", "FPS", "Ping", "Time"}) end)
            pcall(function() config.visuals.watermark_effects:set({"Glow", "Animated line", "Shadow"}) end)

            config.visuals.hdr_hitlog = mui.header(mui.CONTENT, "✉", "Hitlog")
            config.visuals.hitlog = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Screen Hitlog")
                :record("visuals", "hitlog_screen"):save()
            config.visuals.hitlog_style = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Style\nhitlog", {
                "Cards", "Minimal", "Compact", "Glass", "Neon", "Stacked", "Crosshair", "Killfeed"
            }):record("visuals", "hitlog_style"):save()
            config.visuals.hitlog_show = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Show\nhitlog", {
                "Hits", "Headshots", "Kills", "Misses", "Utility", "Evaded"
            }):record("visuals", "hitlog_show"):save()
            config.visuals.hitlog_duration = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Duration\nhitlog", 2, 10, 5, true, "s")
                :record("visuals", "hitlog_duration"):save()
            config.visuals.hitlog_max = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Max entries\nhitlog", 3, 10, 6, true)
                :record("visuals", "hitlog_max"):save()

            config.visuals.hitlog_color_keys = {
                { "hit",   "Body hit",  140, 230, 160 },
                { "head",  "Headshot",  120, 200, 255 },
                { "kill",  "Kill",      255, 205, 110 },
                { "miss",  "Miss",      255, 115, 115 },
                { "burn",  "Burn",      255, 140,  60 },
                { "nade",  "Grenade",   170, 220,  90 },
                { "knife", "Knife",     215, 215, 225 },
                { "evade", "Evaded",    175, 150, 255 },
            }
            config.visuals.hitlog_colors, config.visuals.hitlog_color_labels = {}, {}
            for _, c in ipairs(config.visuals.hitlog_color_keys) do
                config.visuals.hitlog_color_labels[c[1]] = menu.new_item(ui.new_label, "AA", "Anti-aimbot angles", "•  " .. c[2] .. " color")
                    :config_ignore()
                config.visuals.hitlog_colors[c[1]] = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "\nhitlog_color_" .. c[1], c[3], c[4], c[5], 255)
                    :record("visuals", "hitlog_color_" .. c[1]):save()
            end

            config.visuals.hitlog_x = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nhitlog_x", 0, 1000, 500, false)
                :record("visuals", "hitlog_x"):save()
            config.visuals.hitlog_y = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nhitlog_y", 0, 1000, 600, false)
                :record("visuals", "hitlog_y"):save()
            config.visuals.hitlog_reset = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Reset position\nhitlog", function () end)
                :config_ignore()
            config.visuals.hitlog_reset:set_callback(function()
                config.visuals.hitlog_x:set(500)
                config.visuals.hitlog_y:set(600)
            end)

            pcall(function() config.visuals.hitlog:set(true) end)
            pcall(function() config.visuals.hitlog_show:set({ "Hits", "Headshots", "Kills", "Misses", "Utility", "Evaded" }) end)

            ---
            --- Keybinds & spectators panels
            ---
            config.visuals.hdr_lists = mui.header(mui.CONTENT, "☰", "Lists")
            config.visuals.keybinds = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Keybinds List")
                :record("visuals", "keybinds"):save()
            config.visuals.spectators = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Spectators List")
                :record("visuals", "spectators"):save()
            config.visuals.panels_color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "\npanels_color", 180, 160, 255, 255)
                :record("visuals", "panels_color"):save()
            config.visuals.panels_style = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Style\nlists", {
                "Specter", "Glass", "Minimal"
            }):record("visuals", "panels_style"):save()
            config.visuals.panels_options = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Settings\nlists", {
                "Show mode", "Show values", "Hide always-on", "Show while dead", "Lua binds", "Glow"
            }):record("visuals", "panels_options"):save()
            config.visuals.keybinds_style = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Keybinds style\nlists", {
                "Pills icons", "Pills classic", "Pills gradient", "Like spectators"
            }):record("visuals", "keybinds_style"):save()
            config.visuals.keybinds_box = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Keybinds box\nlists", {
                "Faint", "Transparent", "None"
            }):record("visuals", "keybinds_box"):save()
            config.visuals.keybinds_x = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nkeybinds_x", 0, 1000, 12, false)
                :record("visuals", "keybinds_x"):save()
            config.visuals.keybinds_y = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nkeybinds_y", 0, 1000, 420, false)
                :record("visuals", "keybinds_y"):save()
            config.visuals.spectators_x = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nspectators_x", 0, 1000, 12, false)
                :record("visuals", "spectators_x"):save()
            config.visuals.spectators_y = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nspectators_y", 0, 1000, 620, false)
                :record("visuals", "spectators_y"):save()
            config.visuals.panels_reset = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Reset position\nlists", function () end)
                :config_ignore()
            config.visuals.panels_reset:set_callback(function()
                config.visuals.keybinds_x:set(12); config.visuals.keybinds_y:set(420)
                config.visuals.spectators_x:set(12); config.visuals.spectators_y:set(620)
            end)
            pcall(function() config.visuals.keybinds:set(true) end)
            pcall(function() config.visuals.panels_options:set({ "Show mode", "Show values", "Lua binds", "Glow" }) end)

            do
                local HOTKEY_MODE = { [0] = "always", [1] = "hold", [2] = "toggle", [3] = "off-key" }

                -- gamesense binds: display name, tab, container, menu name, value suffix
                local GS_BINDS = {
                    { "Double tap",     "RAGE", "Aimbot",             "Double tap" },
                    { "Hide shots",     "AA",   "Other",              "On shot anti-aim" },
                    { "Fake duck",      "RAGE", "Other",              "Duck peek assist" },
                    { "Quick peek",     "RAGE", "Other",              "Quick peek assist" },
                    { "Body aim",       "RAGE", "Aimbot",             "Force body aim" },
                    { "Safe point",     "RAGE", "Aimbot",             "Force safe point" },
                    { "Min. damage",    "RAGE", "Aimbot",             "Minimum damage override", " hp" },
                    { "Ping spike",     "MISC", "Miscellaneous",      "Ping spike", " ms" },
                    { "Slow walk",      "AA",   "Other",              "Slow motion" },
                    { "Freestanding",   "AA",   "Anti-aimbot angles", "Freestanding" },
                    { "Edge yaw",       "AA",   "Anti-aimbot angles", "Edge yaw" },
                    { "Fake peek",      "AA",   "Other",              "Fake peek" },
                    { "Blockbot",       "MISC", "Movement",           "Blockbot" },
                }

                local binds, resolved = {}, false

                local function resolve()
                    resolved = true
                    for _, def in ipairs(GS_BINDS) do
                        local res = { pcall(ui_reference, def[2], def[3], def[4]) }
                        if res[1] then
                            local b = { name = def[1], suffix = def[5] }
                            for i = 2, #res do
                                local ok, t = pcall(ui.type, res[i])
                                if ok then
                                    if t == "hotkey" and not b.hk then b.hk = res[i]
                                    elseif t == "checkbox" and not b.cb then b.cb = res[i]
                                    elseif t == "slider" and not b.sl then b.sl = res[i] end
                                end
                            end
                            if b.hk then binds[#binds + 1] = b end
                        end
                    end
                end

                local function hk_state(ref)
                    local ok, active, mode = pcall(ui_get, ref)
                    if not ok then return false, nil end
                    return active == true, HOTKEY_MODE[mode or 1]
                end

                local function lua_hk(item)
                    if not item then return false, nil end
                    local ok, active, mode = pcall(item.rawget, item)
                    if not ok then return false, nil end
                    return active == true, HOTKEY_MODE[mode or 1]
                end

                -- builds the list of active binds this frame: { name, mode, value }
                local function collect(opts)
                    if not resolved then resolve() end
                    local out = {}
                    local hide_always = c_table.contains(opts, "Hide always-on")
                    for _, b in ipairs(binds) do
                        local enabled = true
                        if b.cb then
                            local ok, v = pcall(ui_get, b.cb)
                            enabled = ok and v == true
                        end
                        if enabled then
                            local active, mode = hk_state(b.hk)
                            if active and not (hide_always and mode == "always") then
                                local value
                                if b.sl and b.suffix then
                                    local ok, v = pcall(ui_get, b.sl)
                                    if ok and v then value = tostring(v) .. b.suffix end
                                end
                                out[#out + 1] = { b.name, mode, value }
                            end
                        end
                    end

                    if c_table.contains(opts, "Lua binds") then
                        local ma = antiaimbot and antiaimbot.manual_antiaim
                        if ma and ma.state and ma.state > 0 and ma.state < 5 and config.antiaimbot.manual_yaw:get() then
                            local dir = ({ "left", "right", "back", "forward" })[ma.state]
                            out[#out + 1] = { "Manual AA", "toggle", dir }
                        end
                        local fs, fm = lua_hk(config.antiaimbot.freestanding)
                        if fs then out[#out + 1] = { "Freestand (lua)", fm } end
                        local ey, em = lua_hk(config.antiaimbot.edge_yaw)
                        if ey then out[#out + 1] = { "Edge yaw (lua)", em } end
                        if config.ragebot.dormant and config.ragebot.dormant:get() then
                            local da, dm = lua_hk(config.ragebot.dormant_key)
                            if da then out[#out + 1] = { "Dormant aim", dm, tostring(config.ragebot.dormant_damage:get()) .. " hp" } end
                        end
                    end
                    return out
                end

                local function spectators_of(me)
                    local out = {}
                    if not me then return out end
                    local target = me
                    if not entity.is_alive(me) then
                        local t = entity_get_prop(me, "m_hObserverTarget")
                        if t and t > 0 then target = t end
                    end
                    for i = 1, globals.maxplayers() do
                        if i ~= me and entity.get_classname(i) == "CCSPlayer" and not entity.is_alive(i) then
                            local t = entity_get_prop(i, "m_hObserverTarget")
                            local mode = entity_get_prop(i, "m_iObserverMode") or 0
                            if t == target and (mode == 4 or mode == 5) then
                                local name = entity_get_player_name(i) or "?"
                                if #name > 18 then name = name:sub(1, 17) .. "\226\128\166" end
                                out[#out + 1] = { name, mode == 4 and "1st" or "3rd", nil, enemy = entity.is_enemy(i) }
                            end
                        end
                    end
                    return out
                end

                local function lerp(a, b, t) return a + (b - a) * math_min(1, t) end

                -- persistent animation state per panel
                local function new_panel()
                    return { anim = 0, w = 0, h = 0, rows = {}, drag = {}, x = nil, y = nil }
                end
                local panels = { keybinds = new_panel(), spectators = new_panel() }

                local function header_icon(kind, cx, cy, r, g, b, a)
                    if kind == "keybinds" then
                        visuals.rounded(cx - 6, cy - 4, 12, 9, 2, r, g, b, a)
                        for k = 0, 2 do
                            renderer.rectangle(cx - 4 + k * 3, cy - 2, 2, 2, 15, 15, 20, a)
                        end
                        renderer.rectangle(cx - 3, cy + 2, 6, 1, 15, 15, 20, a)
                    else
                        -- eye
                        renderer.circle_outline(cx, cy, r, g, b, a, 5, 200, 0.39, 1)
                        renderer.circle_outline(cx, cy, r, g, b, a, 5, 20, 0.39, 1)
                        renderer.circle(cx, cy, r, g, b, a, 2, 0, 1)
                    end
                end

                -- draws one list panel; items = { {text, tag, value}, ... }
                local function draw_panel(key, title, items, xi, yi, style, opts, r, g, b, now, ft)
                    local p = panels[key]
                    local menu_open = ui_is_menu_open()
                    local want = (#items > 0 or menu_open) and 1 or 0
                    p.anim = lerp(p.anim, want, ft * 8)
                    if p.anim < 0.01 then p.anim = 0; p.rows = {}; return end
                    local a = p.anim
                    local show_mode = c_table.contains(opts, "Show mode")
                    local show_val = c_table.contains(opts, "Show values")
                    local glow = c_table.contains(opts, "Glow")

                    -- row bookkeeping for fade in/out
                    local seen = {}
                    for _, it in ipairs(items) do
                        local row = p.rows[it[1]]
                        if not row then
                            p.seq = (p.seq or 0) + 1
                            row = { a = 0, order = p.seq }
                            p.rows[it[1]] = row
                        end
                        row.item, row.live = it, true
                        seen[it[1]] = true
                    end
                    local list = {}
                    for name, row in pairs(p.rows) do
                        if not seen[name] then row.live = false end
                        row.a = lerp(row.a, row.live and 1 or 0, ft * (row.live and 12 or 9))
                        if not row.live and row.a < 0.02 then
                            p.rows[name] = nil
                        else
                            list[#list + 1] = row
                        end
                    end
                    table.sort(list, function(x, y) return x.order < y.order end)

                    local _, th = renderer.measure_text("", "A")
                    local RH = th + 5
                    local HEAD = style == "Minimal" and (th + 6) or (th + 12)
                    local PAD = 10

                    -- width
                    local tw = renderer.measure_text("b", title)
                    local need = PAD + 18 + tw + PAD
                    for _, row in ipairs(list) do
                        local it = row.item
                        local w = PAD + renderer.measure_text("", it[1]) + 24
                        row.value = (show_val and it[3]) and it[3] or nil
                        row.mode = (show_mode and it[2]) and string.upper(it[2]) or nil
                        row.vw = row.value and renderer.measure_text("", row.value) or 0
                        row.mw = row.mode and (renderer.measure_text("-", row.mode) + 8) or 0
                        w = w + row.vw + row.mw + ((row.value and row.mode) and 6 or 0)
                        need = math_max(need, w + PAD)
                    end
                    need = math_max(need, 150)
                    p.w = p.w == 0 and need or lerp(p.w, need, ft * 12)
                    local body = 0
                    for _, row in ipairs(list) do body = body + RH * row.a end
                    local total = HEAD + (body > 0 and (body + 6) or 0)
                    p.h = p.h == 0 and total or lerp(p.h, total, ft * 14)
                    local w, h = math_floor(p.w + 0.5), math_floor(p.h + 0.5)

                    local sw, sh = client.screen_size()
                    local tx, ty = xi:get() / 1000 * sw, yi:get() / 1000 * sh
                    if menu_open and visuals.drag_update then
                        local nx, ny = visuals.drag_update(p.drag, tx, ty, w, HEAD)
                        if nx then
                            tx, ty = c_math.clamp(nx, 0, sw - w), c_math.clamp(ny, 0, sh - HEAD)
                            xi:set(math_floor(tx / sw * 1000 + 0.5))
                            yi:set(math_floor(ty / sh * 1000 + 0.5))
                            p.x, p.y = tx, ty
                        end
                    end
                    p.x = p.x and lerp(p.x, tx, ft * 16) or tx
                    p.y = p.y and lerp(p.y, ty, ft * 16) or ty
                    local x, y = math_floor(p.x + 0.5), math_floor(p.y + 0.5)
                    local rounded = visuals.rounded
                    local pulse = 0.75 + 0.25 * math.sin(now * 2.2)

                    -- background
                    if style == "Specter" then
                        for i = 1, 2 do rounded(x - i * 2, y - i * 2 + 2, w + i * 4, h + i * 4, 6 + i * 2, 0, 0, 0, (3 - i) * 14 * a) end
                        if glow then
                            for i = 1, 3 do rounded(x - i * 2, y - i * 2, w + i * 4, h + i * 4, 6 + i * 2, r, g, b, (4 - i) * 3 * pulse * a) end
                        end
                        rounded(x - 1, y - 1, w + 2, h + 2, 7, 255, 255, 255, 14 * a)
                        rounded(x, y, w, h, 6, 12, 12, 16, 238 * a)
                        local half = math_floor((w - 16) / 2)
                        renderer.gradient(x + 8, y + HEAD - 1, half, 1, r, g, b, 0, r, g, b, 230 * a, true)
                        renderer.gradient(x + 8 + half, y + HEAD - 1, w - 16 - half, 1, r, g, b, 230 * a, r, g, b, 0, true)
                    elseif style == "Glass" then
                        if glow then
                            for i = 1, 4 do rounded(x - i, y - i, w + i * 2, h + i * 2, 5 + i, r, g, b, (5 - i) * 2 * pulse * a) end
                        end
                        rounded(x, y, w, h, 5, 18, 18, 26, 150 * a)
                        rounded(x, y, w, HEAD, 5, r, g, b, 38 * a)
                        renderer.gradient(x + 5, y, w - 10, 1, 255, 255, 255, 40 * a, 255, 255, 255, 5 * a, true)
                        renderer.rectangle(x, y + 5, 2, HEAD - 10, r, g, b, 255 * a)
                    else
                        renderer.gradient(x, y + HEAD - 2, w, 2, r, g, b, 255 * a, r, g, b, 0, true)
                    end

                    -- header
                    local cy = y + math_floor(HEAD / 2)
                    header_icon(key, x + PAD + 5, cy - (style == "Minimal" and 1 or 0), r, g, b, 255 * a)
                    local hy = y + math_floor((HEAD - th) / 2) - (style == "Minimal" and 1 or 0)
                    if style == "Minimal" then
                        renderer.text(x + PAD + 19, hy + 1, 0, 0, 0, 170 * a, "b", 0, title)
                    end
                    renderer.text(x + PAD + 18, hy, 240, 240, 245, 255 * a, "b", 0, title)
                    local count = tostring(#items)
                    local cw = renderer.measure_text("", count)
                    if #items > 0 and style ~= "Minimal" then
                        rounded(x + w - PAD - cw - 8, cy - 7, cw + 8, 14, 7, r, g, b, 60 * a)
                        renderer.text(x + w - PAD - cw - 4, cy - math_floor(th / 2), r, g, b, 255 * a, "", 0, count)
                    end

                    -- rows
                    local ry = y + HEAD + 3
                    for _, row in ipairs(list) do
                        local it, ra = row.item, row.a * a
                        local slide = math_floor((1 - row.a) * 10)
                        local shadow = style == "Minimal"
                        local nr, ng, nb = 225, 225, 232
                        if key == "spectators" and it.enemy then nr, ng, nb = 255, 150, 150 end
                        -- status dot
                        renderer.circle(x + PAD + 3 + slide, ry + math_floor(RH / 2), r, g, b, 255 * ra, 2.5, 0, 1)
                        if shadow then renderer.text(x + PAD + 13 + slide, ry + 2, 0, 0, 0, 170 * ra, "", 0, it[1]) end
                        renderer.text(x + PAD + 12 + slide, ry + 1, nr, ng, nb, 255 * ra, "", 0, it[1])
                        local rx = x + w - PAD
                        if row.mode then
                            rx = rx - row.mw
                            if shadow then
                                renderer.text(rx + 5, ry + 4, 0, 0, 0, 170 * ra, "-", 0, row.mode)
                                renderer.text(rx + 4, ry + 3, 150, 150, 162, 255 * ra, "-", 0, row.mode)
                            else
                                rounded(rx, ry + 1, row.mw, RH - 2, 3, r, g, b, 45 * ra)
                                renderer.text(rx + 4, ry + 3, r, g, b, 255 * ra, "-", 0, row.mode)
                            end
                        end
                        if row.value then
                            rx = rx - row.vw - (row.mode and 6 or 0)
                            if shadow then renderer.text(rx + 1, ry + 2, 0, 0, 0, 170 * ra, "", 0, row.value) end
                            renderer.text(rx, ry + 1, 200, 200, 210, 255 * ra, "", 0, row.value)
                        end
                        ry = ry + RH * row.a
                    end

                    if menu_open then
                        local da = p.drag.drag and 220 or 90
                        if #items == 0 then
                            renderer.text(x + math_floor(w / 2), y + HEAD + 8, 130, 130, 140, 200 * a, "c", 0,
                                key == "keybinds" and "no active binds" or "nobody is watching")
                        end
                        renderer.text(x + math_floor(w / 2), y + h + (#items == 0 and 22 or 8), r, g, b, da, "c", 0, "drag to move")
                    end
                end

                -- ── keybinds: pill styles (one rounded pill per bind, a header pill, an optional box around them) ──
                local PILL_BG, PILL_W, PILL_D = { 18, 18, 22 }, { 235, 235, 245 }, { 135, 135, 146 }
                local GRAD2 = { 110, 170, 255 }

                local function rounded_outline(x, y, w, h, rad, r, g, b, a)
                    if a <= 0 or w <= 2 or h <= 2 then return end
                    rad = math_max(0, math_min(rad, math_floor(h / 2), math_floor(w / 2)))
                    renderer.rectangle(x + rad, y, w - rad * 2, 1, r, g, b, a)
                    renderer.rectangle(x + rad, y + h - 1, w - rad * 2, 1, r, g, b, a)
                    renderer.rectangle(x, y + rad, 1, h - rad * 2, r, g, b, a)
                    renderer.rectangle(x + w - 1, y + rad, 1, h - rad * 2, r, g, b, a)
                    if rad > 0 then
                        renderer.circle_outline(x + rad, y + rad, r, g, b, a, rad, 180, 0.25, 1)
                        renderer.circle_outline(x + w - rad, y + rad, r, g, b, a, rad, 90, 0.25, 1)
                        renderer.circle_outline(x + rad, y + h - rad, r, g, b, a, rad, 270, 0.25, 1)
                        renderer.circle_outline(x + w - rad, y + h - rad, r, g, b, a, rad, 0, 0.25, 1)
                    end
                end

                -- a rounded rectangle filled with a horizontal gradient: left corners color 1, right corners color 2
                local function grad_rounded(x, y, w, h, rad, r1, g1, b1, a1, r2, g2, b2, a2)
                    if w <= 0 or h <= 0 then return end
                    rad = math_max(1, math_min(rad, math_floor(h / 2), math_floor(w / 2)))
                    visuals.rounded(x, y, rad * 2, h, rad, r1, g1, b1, a1)
                    visuals.rounded(x + w - rad * 2, y, rad * 2, h, rad, r2, g2, b2, a2)
                    renderer.gradient(x + rad, y, w - rad * 2, h, r1, g1, b1, a1, r2, g2, b2, a2, true)
                end

                local function text_shadow(x, y, r, g, b, a, flags, s)
                    renderer.text(x + 1, y + 1, 0, 0, 0, a * 0.55, flags, 0, s)
                    renderer.text(x, y, r, g, b, a, flags, 0, s)
                end

                local function keyboard_icon(cx, cy, r, g, b, a)
                    rounded_outline(cx - 8, cy - 5, 16, 10, 2, r, g, b, a)
                    rounded_outline(cx - 7, cy - 4, 14, 8, 1, r, g, b, a * 0.6)
                    for k = 0, 3 do renderer.rectangle(cx - 6 + k * 3, cy - 2, 2, 2, r, g, b, a) end
                    renderer.rectangle(cx - 4, cy + 1, 8, 2, r, g, b, a)
                end

                local function gear_icon(cx, cy, r, g, b, a)
                    renderer.circle_outline(cx, cy, r, g, b, a, 5, 0, 1, 2)
                    for k = 0, 7 do
                        local ang = k * math.pi / 4
                        local c, s = math.cos(ang), math.sin(ang)
                        renderer.line(cx + c * 5, cy + s * 5, cx + c * 8, cy + s * 8, r, g, b, a)
                        renderer.line(cx + c * 5 + s * 0.8, cy + s * 5 - c * 0.8, cx + c * 8 + s * 0.8, cy + s * 8 - c * 0.8, r, g, b, a)
                    end
                    renderer.circle(cx, cy, r, g, b, a, 1.5, 0, 1)
                end

                local function poly(pts, cx, cy, r, g, b, a)
                    for i = 1, #pts - 1 do
                        renderer.line(cx + pts[i][1], cy + pts[i][2], cx + pts[i + 1][1], cy + pts[i + 1][2], r, g, b, a)
                    end
                end

                -- a small glyph per bind (style "Pills icons"), drawn with lines / circles / triangles
                local function bind_icon(name, cx, cy, r, g, b, a)
                    if name == "Double tap" then                                  -- bolt
                        renderer.triangle(cx + 2, cy - 7, cx - 4, cy + 1, cx + 1, cy + 1, r, g, b, a)
                        renderer.triangle(cx - 1, cy + 7, cx + 4, cy - 1, cx - 1, cy - 1, r, g, b, a)
                    elseif name == "Hide shots" or name == "Fake peek" then        -- eye (slashed for hide shots)
                        renderer.circle_outline(cx, cy + 5, r, g, b, a, 8, 140, 0.28, 1)
                        renderer.circle_outline(cx, cy - 5, r, g, b, a, 8, 320, 0.28, 1)
                        renderer.circle(cx, cy, r, g, b, a, 1.8, 0, 1)
                        if name == "Hide shots" then renderer.line(cx - 5, cy + 5, cx + 5, cy - 5, r, g, b, a) end
                    elseif name == "Min. damage" or name == "Dormant aim" then     -- crosshair
                        renderer.circle_outline(cx, cy, r, g, b, a, 5, 0, 1, 1)
                        renderer.rectangle(cx - 8, cy, 3, 1, r, g, b, a)
                        renderer.rectangle(cx + 6, cy, 3, 1, r, g, b, a)
                        renderer.rectangle(cx, cy - 8, 1, 3, r, g, b, a)
                        renderer.rectangle(cx, cy + 6, 1, 3, r, g, b, a)
                        if name == "Min. damage" then renderer.circle(cx, cy, r, g, b, a, 1.5, 0, 1) end
                    elseif name == "Freestanding" or name == "Freestand (lua)" then -- shield
                        poly({ { -5, -6 }, { 5, -6 }, { 5, 1 }, { 0, 7 }, { -5, 1 }, { -5, -6 } }, cx, cy, r, g, b, a)
                        renderer.rectangle(cx, cy - 4, 1, 8, r, g, b, a * 0.6)
                    elseif name == "Quick peek" then                               -- arrow back
                        renderer.rectangle(cx - 6, cy, 12, 1, r, g, b, a)
                        poly({ { -2, -4 }, { -6, 0 }, { -2, 4 } }, cx, cy, r, g, b, a)
                    elseif name == "Fake duck" then                                -- arrow down to a line
                        renderer.rectangle(cx, cy - 6, 1, 9, r, g, b, a)
                        poly({ { -4, -1 }, { 0, 3 }, { 4, -1 } }, cx, cy, r, g, b, a)
                        renderer.rectangle(cx - 5, cy + 6, 11, 1, r, g, b, a)
                    elseif name == "Body aim" then                                 -- torso
                        renderer.circle(cx, cy - 4, r, g, b, a, 2.5, 0, 1)
                        visuals.rounded(cx - 4, cy - 1, 9, 7, 3, r, g, b, a)
                    elseif name == "Safe point" then                               -- ring + dot
                        renderer.circle_outline(cx, cy, r, g, b, a, 6, 0, 1, 1)
                        renderer.circle(cx, cy, r, g, b, a, 3, 0, 1)
                    elseif name == "Ping spike" then                               -- signal bars
                        for k = 0, 3 do renderer.rectangle(cx - 6 + k * 3, cy + 5 - (k + 1) * 3, 2, (k + 1) * 3, r, g, b, a) end
                    elseif name == "Slow walk" then                                -- double chevron
                        poly({ { -5, -4 }, { -1, 0 }, { -5, 4 } }, cx, cy, r, g, b, a)
                        poly({ { 0, -4 }, { 4, 0 }, { 0, 4 } }, cx, cy, r, g, b, a * 0.6)
                    elseif name == "Edge yaw" or name == "Edge yaw (lua)" then     -- corner
                        poly({ { -5, -6 }, { -5, 5 }, { 6, 5 } }, cx, cy, r, g, b, a)
                        renderer.circle(cx + 1, cy - 1, r, g, b, a, 2, 0, 1)
                    elseif name == "Blockbot" then                                 -- box
                        rounded_outline(cx - 5, cy - 5, 11, 11, 2, r, g, b, a)
                        renderer.rectangle(cx - 2, cy - 2, 5, 5, r, g, b, a)
                    elseif name == "Manual AA" then                                -- arrow
                        renderer.triangle(cx + 6, cy, cx - 4, cy - 5, cx - 4, cy + 5, r, g, b, a)
                    else
                        renderer.circle(cx, cy, r, g, b, a, 2.5, 0, 1)
                    end
                end

                local function switch_draw(x, y, filled, r, g, b, a)
                    if filled then
                        visuals.rounded(x, y, 18, 10, 5, r, g, b, 230 * a / 255)
                        renderer.circle(x + 13, y + 5, 255, 255, 255, a, 3.2, 0, 1)
                    else
                        rounded_outline(x, y, 18, 10, 5, r, g, b, 230 * a / 255)
                        renderer.circle(x + 13, y + 5, r, g, b, 230 * a / 255, 3, 0, 1)
                    end
                end

                local pills = { anim = 0, w = 0, h = 0, rows = {}, drag = {}, ctx = { a = 0 } }
                local CTX_ITEMS = { "Reset position", "Center horizontally", "Center vertically" }

                local function pill_ctx(cx_, cy_, cw, ch, menu_open, mx, my, r, g, b, accent, ft, act)
                    local c = pills.ctx
                    c.a = lerp(c.a, (c.open and menu_open) and 1 or 0, ft * 14)
                    if c.a < 0.02 then c.a = 0; return end
                    local a = c.a
                    local rounded = visuals.rounded
                    rounded(cx_, cy_, cw, ch, 8, PILL_BG[1], PILL_BG[2], PILL_BG[3], 215 * a)
                    rounded_outline(cx_, cy_, cw, ch, 8, 255, 255, 255, 22 * a)
                    rounded(cx_ + 1, cy_ + 1, 27, ch - 2, 7, 255, 255, 255, 10 * a)
                    renderer.rectangle(cx_ + 28, cy_ + 6, 1, ch - 12, 255, 255, 255, 18 * a)
                    local ir, ig, ib = PILL_D[1], PILL_D[2], PILL_D[3]
                    if accent then ir, ig, ib = r, g, b end
                    gear_icon(cx_ + 14, cy_ + math_floor(ch / 2), ir, ig, ib, 255 * a)
                    text_shadow(cx_ + 124, cy_ + 17, PILL_W[1], PILL_W[2], PILL_W[3], 255 * a, "cb", "Keybinds")
                    c.hover = nil
                    for i, label in ipairs(CTX_ITEMS) do
                        local iy = cy_ + 44 + (i - 1) * 22
                        local hot = mx and mx >= cx_ + 34 and mx <= cx_ + cw - 6 and my >= iy - 10 and my <= iy + 10
                        if hot then c.hover = i end
                        local dr, dg, db = PILL_D[1], PILL_D[2], PILL_D[3]
                        if hot then
                            if accent then dr, dg, db = r, g, b else dr, dg, db = 255, 255, 255 end
                            rounded(cx_ + 36, iy - 9, cw - 44, 18, 5, 255, 255, 255, 8 * a)
                        end
                        renderer.circle(cx_ + 44, iy, dr, dg, db, 255 * a, 2, 0, 1)
                        local tr, tg, tb = PILL_D[1], PILL_D[2], PILL_D[3]
                        if hot then tr, tg, tb = PILL_W[1], PILL_W[2], PILL_W[3] end
                        local _, th = renderer.measure_text(hot and "b" or "", label)
                        text_shadow(cx_ + 54, iy - math_floor(th / 2), tr, tg, tb, 255 * a, hot and "b" or "", label)
                    end
                end

                -- draws the keybinds as pills; variant = "Pills icons" (D) / "Pills classic" (A) / "Pills gradient" (C)
                local function draw_pills(items, xi, yi, variant, box, opts, r, g, b, now, ft)
                    local p = pills
                    local menu_open = ui_is_menu_open()
                    if not menu_open then p.ctx.open = false end
                    local want = (#items > 0 or menu_open) and 1 or 0
                    p.anim = lerp(p.anim, want, ft * 8)
                    if p.anim < 0.01 and p.ctx.a <= 0 then p.anim = 0; p.rows = {}; return end
                    local a = p.anim
                    local show_mode = c_table.contains(opts, "Show mode")
                    local show_val = c_table.contains(opts, "Show values")
                    local icons, classic, grad = variant == "Pills icons", variant == "Pills classic", variant == "Pills gradient"

                    -- rows fade / slide in and out (same bookkeeping as the old panel)
                    local seen = {}
                    for _, it in ipairs(items) do
                        local row = p.rows[it[1]]
                        if not row then
                            p.seq = (p.seq or 0) + 1
                            row = { a = 0, order = p.seq }
                            p.rows[it[1]] = row
                        end
                        row.item, row.live = it, true
                        seen[it[1]] = true
                    end
                    local list = {}
                    for name, row in pairs(p.rows) do
                        if not seen[name] then row.live = false end
                        row.a = lerp(row.a, row.live and 1 or 0, ft * (row.live and 12 or 9))
                        if not row.live and row.a < 0.02 then
                            p.rows[name] = nil
                        else
                            list[#list + 1] = row
                        end
                    end
                    table.sort(list, function(x, y) return x.order < y.order end)

                    local HEAD, RH, GAP = 28, 26, 5
                    local name_x = icons and 28 or 22
                    local need = 200
                    for _, row in ipairs(list) do
                        local it = row.item
                        row.value = (show_val and it[3]) and tostring(it[3]) or nil
                        row.mode = nil
                        if not row.value and show_mode and it[2] and it[2] ~= "toggle" and it[2] ~= "always" then row.mode = it[2] end
                        local right
                        if row.value then
                            row.vw = renderer.measure_text("b", row.value)
                            right = grad and (row.vw + 12) or row.vw
                        elseif row.mode then
                            row.vw = renderer.measure_text("", row.mode)
                            right = row.vw
                        else
                            right = 18
                        end
                        need = math_max(need, name_x + renderer.measure_text("b", it[1]) + 18 + right + 12)
                    end
                    p.w = p.w == 0 and need or lerp(p.w, need, ft * 12)
                    local body = 0
                    for _, row in ipairs(list) do body = body + (RH + GAP) * row.a end
                    local total = HEAD + body
                    if #items == 0 and menu_open then total = HEAD + 26 end
                    p.h = p.h == 0 and total or lerp(p.h, total, ft * 14)
                    local w, h = math_floor(p.w + 0.5), math_floor(p.h + 0.5)

                    local sw, sh = client.screen_size()
                    local tx, ty = xi:get() / 1000 * sw, yi:get() / 1000 * sh
                    local mx, my
                    if menu_open then
                        mx, my = ui.mouse_position()
                        if visuals.drag_update and not p.ctx.open then
                            local nx, ny = visuals.drag_update(p.drag, tx, ty, w, HEAD)
                            if nx then
                                tx, ty = c_math.clamp(nx, 0, sw - w), c_math.clamp(ny, 0, sh - HEAD)
                                xi:set(math_floor(tx / sw * 1000 + 0.5))
                                yi:set(math_floor(ty / sh * 1000 + 0.5))
                                p.x, p.y = tx, ty
                            end
                        end
                    end
                    p.x = p.x and lerp(p.x, tx, ft * 16) or tx
                    p.y = p.y and lerp(p.y, ty, ft * 16) or ty
                    local x, y = math_floor(p.x + 0.5), math_floor(p.y + 0.5)
                    local rounded = visuals.rounded
                    local A = 255 * a

                    -- the box around the whole list
                    if box == "Faint" then
                        rounded(x - 8, y - 8, w + 16, h + 16, 11, 255, 255, 255, 14 * a)
                        rounded_outline(x - 8, y - 8, w + 16, h + 16, 11, 255, 255, 255, 30 * a)
                    elseif box == "Transparent" then
                        rounded(x - 8, y - 8, w + 16, h + 16, 11, 0, 0, 0, 45 * a)
                        rounded_outline(x - 8, y - 8, w + 16, h + 16, 11, 255, 255, 255, 22 * a)
                    end

                    -- header pill
                    local g2r, g2g, g2b = GRAD2[1], GRAD2[2], GRAD2[3]
                    if grad then
                        grad_rounded(x, y, w, HEAD, 7, r, g, b, A, g2r, g2g, g2b, 200 * a)
                        rounded(x + 1, y + 1, w - 2, HEAD - 2, 6, 16, 14, 26, 235 * a)
                        renderer.gradient(x + 4, y + 1, w - 8, HEAD - 2, r, g, b, 70 * a, g2r, g2g, g2b, 20 * a, true)
                    else
                        rounded(x, y, w, HEAD, 7, PILL_BG[1], PILL_BG[2], PILL_BG[3], 200 * a)
                        rounded_outline(x, y, w, HEAD, 7, 255, 255, 255, 22 * a)
                    end
                    if classic then
                        rounded(x + 3, y + 3, 30, 22, 5, 255, 255, 255, 14 * a)
                        keyboard_icon(x + 18, y + 14, 200, 200, 210, A)
                    else
                        rounded(x + 3, y + 3, 30, 22, 5, r, g, b, 55 * a)
                        keyboard_icon(x + 18, y + 14, r, g, b, A)
                    end
                    text_shadow(x + math_floor(w / 2) + 14, y + math_floor(HEAD / 2), PILL_W[1], PILL_W[2], PILL_W[3], A, "cb", "Hotkeys")

                    -- one pill per bind
                    local ry = y + HEAD + GAP
                    for _, row in ipairs(list) do
                        local it, ra = row.item, row.a * a
                        local RA = 255 * ra
                        local px = x + math_floor((1 - row.a) * 26)
                        local cyr = ry + math_floor(RH / 2)
                        if grad then
                            grad_rounded(px, ry, w, RH, 7, r, g, b, RA, g2r, g2g, g2b, 120 * ra)
                            rounded(px + 1, ry + 1, w - 2, RH - 2, 6, PILL_BG[1], PILL_BG[2], PILL_BG[3], RA)
                            renderer.gradient(px + 4, ry + 1, w - 8, RH - 2, r, g, b, 40 * ra, g2r, g2g, g2b, 0, true)
                        else
                            rounded(px, ry, w, RH, 7, PILL_BG[1], PILL_BG[2], PILL_BG[3], 195 * ra)
                            rounded_outline(px, ry, w, RH, 7, 255, 255, 255, 20 * ra)
                        end
                        if icons then
                            bind_icon(it[1], px + 15, cyr, r, g, b, RA)
                        elseif classic then
                            renderer.circle(px + 12, cyr, 255, 255, 255, RA, 2.2, 0, 1)
                        else
                            renderer.circle(px + 12, cyr, r, g, b, RA, 2.2, 0, 1)
                        end
                        local _, nth = renderer.measure_text("b", it[1])
                        text_shadow(px + name_x, cyr - math_floor(nth / 2), PILL_W[1], PILL_W[2], PILL_W[3], RA, "b", it[1])
                        local rx = px + w - 12
                        if row.value then
                            local _, vth = renderer.measure_text("b", row.value)
                            if grad then
                                rounded(rx - row.vw - 10, cyr - 7, row.vw + 12, 14, 7, r, g, b, 60 * ra)
                                renderer.text(rx - row.vw - 4, cyr - math_floor(vth / 2), 230, 220, 255, RA, "b", 0, row.value)
                            elseif classic then
                                text_shadow(rx - row.vw, cyr - math_floor(vth / 2), 190, 190, 200, RA, "b", row.value)
                            else
                                text_shadow(rx - row.vw, cyr - math_floor(vth / 2), r, g, b, RA, "b", row.value)
                            end
                        elseif row.mode then
                            local _, mth = renderer.measure_text("", row.mode)
                            text_shadow(rx - row.vw, cyr - math_floor(mth / 2), PILL_D[1], PILL_D[2], PILL_D[3], RA, "", row.mode)
                        else
                            if classic then
                                switch_draw(px + w - 28, cyr - 5, false, 255, 255, 255, RA)
                            else
                                switch_draw(px + w - 28, cyr - 5, true, r, g, b, RA)
                            end
                        end
                        ry = ry + (RH + GAP) * row.a
                    end

                    -- menu open: hints, right click opens the options next to the list
                    local cw, ch = 220, 106
                    local cx_ = x + w + 12
                    if cx_ + cw > sw then cx_ = x - 12 - cw end
                    local cy_ = c_math.clamp(y, 0, sh - ch)
                    if menu_open then
                        if #items == 0 then
                            renderer.text(x + math_floor(w / 2), y + HEAD + 14, 130, 130, 140, 200 * a, "c", 0, "no active binds")
                        end
                        local da = p.drag.drag and 220 or 90
                        renderer.text(x + math_floor(w / 2), y + h + 18, r, g, b, da * a, "c", 0,
                            "drag to move  \194\183  right click: options")
                        local rdown, ldown = client.key_state(0x02), client.key_state(0x01)
                        local rpress, lpress = rdown and not p.r_was, ldown and not p.l_was
                        p.r_was, p.l_was = rdown, ldown
                        local over_list = mx and mx >= x - 8 and mx <= x + w + 8 and my >= y - 8 and my <= y + h + 8
                        local over_ctx = p.ctx.open and mx and mx >= cx_ and mx <= cx_ + cw and my >= cy_ and my <= cy_ + ch
                        if rpress and over_list and not visuals.over_menu(mx, my) then
                            p.ctx.open = not p.ctx.open
                        elseif lpress and p.ctx.open then
                            if over_ctx and p.ctx.hover then
                                local pick = CTX_ITEMS[p.ctx.hover]
                                if pick == "Reset position" then
                                    xi:set(12); yi:set(420)
                                elseif pick == "Center horizontally" then
                                    xi:set(math_floor((sw - w) / 2 / sw * 1000 + 0.5))
                                else
                                    yi:set(math_floor((sh - h) / 2 / sh * 1000 + 0.5))
                                end
                                p.ctx.open = false
                            elseif not over_ctx then
                                p.ctx.open = false
                            end
                        end
                    end
                    pill_ctx(cx_, cy_, cw, ch, menu_open, mx, my, r, g, b, not classic, ft, a)
                end

                client.set_event_callback("paint_ui", function()
                    local ok, err = pcall(function()
                        local kb, sp = config.visuals.keybinds:get(), config.visuals.spectators:get()
                        if not kb and not sp then return end
                        local me = entity_get_local_player()
                        local opts = config.visuals.panels_options:get() or {}
                        local alive = me and entity.is_alive(me)
                        local show = ui_is_menu_open() or alive or c_table.contains(opts, "Show while dead")
                        local r, g, b = config.visuals.panels_color:get()
                        local style = config.visuals.panels_style:get()
                        local now, ft = globals.realtime(), globals_frametime()
                        if now >= (panels.next_scan or 0) or now < (panels.next_scan or 0) - 1 then
                            panels.next_scan = now + 1 / 15
                            panels.kb_items = (kb and show and me) and collect(opts) or {}
                            panels.sp_items = (sp and show and me) and spectators_of(me) or {}
                        end
                        if kb then
                            local kstyle = config.visuals.keybinds_style:get()
                            if kstyle == "Like spectators" then
                                draw_panel("keybinds", "keybinds", panels.kb_items or {},
                                    config.visuals.keybinds_x, config.visuals.keybinds_y, style, opts, r, g, b, now, ft)
                            else
                                draw_pills(panels.kb_items or {}, config.visuals.keybinds_x, config.visuals.keybinds_y,
                                    kstyle, config.visuals.keybinds_box:get(), opts, r, g, b, now, ft)
                            end
                        end
                        if sp then
                            draw_panel("spectators", "spectators", panels.sp_items or {},
                                config.visuals.spectators_x, config.visuals.spectators_y, style, opts, r, g, b, now, ft)
                        end
                    end)
                    if not ok then client.error_log("[specter] lists: " .. tostring(err)) end
                end)
            end


            do
                local wm = { fps = 0, anim = 0, w = 0, x = nil, y = nil, drag = {}, day = nil }
                local BG = { 12, 12, 16 }

                local function rounded(x, y, w, h, rad, r, g, b, a)
                    if a <= 0 or w <= 0 or h <= 0 then return end
                    rad = math_max(0, math_min(rad, math_floor(h / 2), math_floor(w / 2)))
                    if a < 32 and rad > 0 then
                        renderer.rectangle(x + rad, y, w - rad * 2, h, r, g, b, a)
                        renderer.rectangle(x, y + rad, rad, h - rad * 2, r, g, b, a)
                        renderer.rectangle(x + w - rad, y + rad, rad, h - rad * 2, r, g, b, a)
                        return
                    end
                    renderer.rectangle(x + rad, y, w - rad * 2, h, r, g, b, a)
                    if rad > 0 then
                        renderer.rectangle(x, y + rad, rad, h - rad * 2, r, g, b, a)
                        renderer.rectangle(x + w - rad, y + rad, rad, h - rad * 2, r, g, b, a)
                        renderer.circle(x + rad, y + rad, r, g, b, a, rad, 180, 0.25)
                        renderer.circle(x + w - rad, y + rad, r, g, b, a, rad, 90, 0.25)
                        renderer.circle(x + rad, y + h - rad, r, g, b, a, rad, 270, 0.25)
                        renderer.circle(x + w - rad, y + h - rad, r, g, b, a, rad, 0, 0.25)
                    end
                end

                local function lerp(a, b, t)
                    return a + (b - a) * math_min(1, t)
                end

                local function panel(x, y, w, h, a, effects, r, g, b, pulse, style)
                    local rad = math_floor(h / 2)
                    if style == "Glass" then
                        rad = 5
                        if c_table.contains(effects, "Shadow") then
                            for i = 1, 3 do rounded(x - i, y - i + 2, w + i * 2, h + i * 2, rad + i, 0, 0, 0, (4 - i) * 8 * a) end
                        end
                        if c_table.contains(effects, "Glow") then
                            for i = 1, 4 do rounded(x - i, y - i, w + i * 2, h + i * 2, rad + i, r, g, b, (5 - i) * 2 * pulse * a) end
                        end
                        rounded(x, y, w, h, rad, 18, 18, 26, 150 * a)
                        renderer.gradient(x, y, math_floor(w * 0.45), h, r, g, b, 45 * a, r, g, b, 0, true)
                        renderer.gradient(x + rad, y, w - rad * 2, 1, 255, 255, 255, 45 * a, 255, 255, 255, 6 * a, true)
                        renderer.rectangle(x, y + 5, 2, h - 10, r, g, b, 255 * a)
                        return
                    elseif style == "Neon" then
                        for i = 1, 3 do
                            rounded(x - i * 2, y - i * 2, w + i * 4, h + i * 4, rad + i * 2, r, g, b, (4 - i) * 6 * pulse * a)
                        end
                        rounded(x - 1, y - 1, w + 2, h + 2, rad + 1, r, g, b, 210 * a)
                        rounded(x, y, w, h, rad, 8, 8, 12, 245 * a)
                        return
                    end
                    if c_table.contains(effects, "Shadow") then
                        for i = 1, 2 do
                            rounded(x - i * 2, y - i * 2 + 2, w + i * 4, h + i * 4, rad + i * 2, 0, 0, 0, (3 - i) * 14 * a)
                        end
                    end
                    if c_table.contains(effects, "Glow") then
                        for i = 1, 3 do
                            rounded(x - i * 2, y - i * 2, w + i * 4, h + i * 4, rad + i * 2, r, g, b, (4 - i) * 2.6 * pulse * a)
                        end
                    end
                    rounded(x - 1, y - 1, w + 2, h + 2, rad + 1, 255, 255, 255, 14 * a)
                    rounded(x, y, w, h, rad, BG[1], BG[2], BG[3], 238 * a)
                    renderer.gradient(x + rad, y + 1, w - rad * 2, 1, 255, 255, 255, 12 * a, 255, 255, 255, 12 * a, true)
                end

                local function underline(x, y, w, r, g, b, a, now, animated)
                    local half = math_floor(w / 2)
                    if half <= 0 then return end
                    local k = animated and (0.55 + 0.45 * math.sin(now * 1.8)) or 1
                    renderer.gradient(x, y, half, 1, r, g, b, 0, r, g, b, 230 * k * a, true)
                    renderer.gradient(x + half, y, w - half, 1, r, g, b, 230 * k * a, r, g, b, 0, true)
                    renderer.gradient(x + math_floor(w * 0.2), y - 1, math_floor(w * 0.3), 1, r, g, b, 0, r, g, b, 60 * k * a, true)
                    renderer.gradient(x + math_floor(w * 0.5), y - 1, math_floor(w * 0.3), 1, r, g, b, 60 * k * a, r, g, b, 0, true)
                end

                local function sky(cx, cy, r, g, b, a, now, day)
                    local night = 1 - day
                    if night > 0.02 then
                        renderer.circle(cx, cy, r, g, b, a, 4.5 * night, 0, 1)
                        renderer.circle(cx + 2.2 * night, cy - 1.6 * night, BG[1], BG[2], BG[3], a, 3.8 * night, 0, 1)
                    end
                    if day > 0.02 then
                        renderer.circle(cx, cy, 255, 222, 140, a, 3.2 * day, 0, 1)
                        local spin = now * 0.5
                        for k = 0, 7 do
                            local ang = spin + k * math.pi / 4
                            local ca, sa = math.cos(ang), math.sin(ang)
                            renderer.line(cx + ca * 4.8 * day, cy + sa * 4.8 * day, cx + ca * 6.6 * day, cy + sa * 6.6 * day, 255, 222, 140, a)
                        end
                    end
                end

                local function icon(kind, cx, cy, a)
                    local c = 150
                    if kind == "user" then
                        renderer.circle(cx, cy - 2.5, c, c, c + 10, a, 2.6, 0, 1)
                        rounded(cx - 4, cy + 1, 8, 4, 2, c, c, c + 10, a)
                    elseif kind == "fps" then
                        renderer.rectangle(cx - 4, cy + 1, 2, 3, c, c, c + 10, a)
                        renderer.rectangle(cx - 1, cy - 1, 2, 5, c, c, c + 10, a)
                        renderer.rectangle(cx + 2, cy - 3, 2, 7, c, c, c + 10, a)
                    elseif kind == "ping" then
                        renderer.circle_outline(cx, cy, c, c, c + 10, a, 4.5, 0, 1, 1)
                        renderer.circle(cx, cy, c, c, c + 10, a, 1.5, 0, 1)
                    elseif kind == "tick" then
                        renderer.rectangle(cx - 4, cy, 8, 1, c, c, c + 10, a)
                        renderer.rectangle(cx, cy - 4, 1, 8, c, c, c + 10, a)
                    elseif kind == "time" then
                        renderer.circle_outline(cx, cy, c, c, c + 10, a, 4.5, 0, 1, 1)
                        renderer.rectangle(cx, cy - 3, 1, 3, c, c, c + 10, a)
                        renderer.rectangle(cx, cy, 2, 1, c, c, c + 10, a)
                    end
                end

                local function brand_text(x, y, text, r, g, b, a, now)
                    local cx = x
                    for i = 1, #text do
                        local ch = text:sub(i, i)
                        local t = 0.5 + 0.5 * math.sin(now * 1.6 - i * 0.55)
                        local cr = math_floor(245 + (r - 245) * t)
                        local cg = math_floor(245 + (g - 245) * t)
                        local cb = math_floor(250 + (b - 250) * t)
                        renderer.text(cx, y, cr, cg, cb, a, "b", 0, ch)
                        cx = cx + renderer.measure_text("b", ch)
                    end
                end

                client.set_event_callback("paint_ui", function()
                    local ft = globals_frametime()
                    local target = config.visuals.watermark:get() and 1 or 0
                    wm.anim = lerp(wm.anim, target, ft * 7)
                    if wm.anim < 0.01 then wm.anim = 0 return end

                    if ft > 0 then
                        wm.fps = wm.fps == 0 and 1 / ft or lerp(wm.fps, 1 / ft, ft * 2)
                    end

                    local r, g, b = config.visuals.watermark_color:get()
                    local fields = config.visuals.watermark_fields:get() or {}
                    local effects = config.visuals.watermark_effects:get() or {}
                    local style = config.visuals.watermark_style:get()
                    local icons = c_table.contains(effects, "Icons")
                    local now = globals.realtime()
                    local pulse = 0.7 + 0.3 * math.sin(now * 2)
                    wm.day = lerp(wm.day or (user.is_day() and 1 or 0), user.is_day() and 1 or 0, ft * 3)

                    local W = { 230, 230, 236 }
                    local segs = {}
                    if c_table.contains(fields, "Username") then
                        segs[#segs + 1] = { "user", user.name, "", W[1], W[2], W[3] }
                    end
                    if c_table.contains(fields, "FPS") then
                        local fps = math_floor(wm.fps + 0.5)
                        local cr, cg, cb = W[1], W[2], W[3]
                        if fps < 60 then cr, cg, cb = 255, 118, 118 elseif fps < 120 then cr, cg, cb = 255, 210, 125 end
                        segs[#segs + 1] = { "fps", tostring(fps), " fps", cr, cg, cb }
                    end
                    if c_table.contains(fields, "Ping") then
                        local ping = math_floor((client.latency() or 0) * 1000 + 0.5)
                        local cr, cg, cb = W[1], W[2], W[3]
                        if ping > 110 then cr, cg, cb = 255, 118, 118 elseif ping > 60 then cr, cg, cb = 255, 210, 125 end
                        segs[#segs + 1] = { "ping", tostring(ping), " ms", cr, cg, cb }
                    end
                    if c_table.contains(fields, "Tickrate") then
                        segs[#segs + 1] = { "tick", tostring(math_floor(1 / globals_tickinterval() + 0.5)), " tick", W[1], W[2], W[3] }
                    end
                    if c_table.contains(fields, "Time") then
                        local hours, minutes = client.system_time()
                        segs[#segs + 1] = { "time", string_format("%02d:%02d", hours, minutes), "", W[1], W[2], W[3] }
                    end

                    local brand = "specter"
                    local bw, th = renderer.measure_text("b", brand)
                    local H = th + 12
                    local PADX, GAP = 12, 11
                    local brand_w = PADX + 14 + 6 + bw + PADX

                    local info_w = 0
                    for _, sg in ipairs(segs) do
                        sg.vw = renderer.measure_text("", sg[2])
                        sg.uw = sg[3] ~= "" and renderer.measure_text("-", sg[3]) or 0
                        sg.w = (icons and 14 or 0) + sg.vw + sg.uw
                        info_w = info_w + sg.w
                    end
                    if #segs > 0 then info_w = info_w + GAP * 2 * (#segs - 1) + PADX * 2 end

                    local split = style == "Split" and #segs > 0
                    local width = split and (brand_w + 6 + info_w) or (brand_w + (#segs > 0 and (info_w - PADX) or 0))
                    wm.w = wm.w == 0 and width or lerp(wm.w, width, ft * 12)
                    local w = math_floor(wm.w + 0.5)

                    local sw, sh = client.screen_size()
                    local position = config.visuals.watermark_position:get()
                    local tx_, ty_ = sw - w - 16, 16
                    if position == "Top left" then
                        tx_ = 16
                    elseif position == "Bottom center" then
                        tx_, ty_ = (sw - w) / 2, sh - H - 16
                    elseif position == "Custom (drag)" then
                        tx_ = config.visuals.watermark_x:get() / 1000 * sw
                        ty_ = config.visuals.watermark_y:get() / 1000 * sh
                        if ui_is_menu_open() and visuals and visuals.drag_update then
                            local nx, ny = visuals.drag_update(wm.drag, tx_, ty_, w, H)
                            if nx then
                                tx_ = c_math.clamp(nx, 0, sw - w)
                                ty_ = c_math.clamp(ny, 0, sh - H)
                                config.visuals.watermark_x:set(math_floor(tx_ / sw * 1000 + 0.5))
                                config.visuals.watermark_y:set(math_floor(ty_ / sh * 1000 + 0.5))
                                wm.x, wm.y = tx_, ty_
                            end
                        end
                    end
                    wm.x = wm.x and lerp(wm.x, tx_, ft * 14) or tx_
                    wm.y = wm.y and lerp(wm.y, ty_, ft * 14) or ty_
                    local x, y = math_floor(wm.x + 0.5), math_floor(wm.y + 0.5)
                    local a = wm.anim
                    local animated = c_table.contains(effects, "Animated line")
                    local cy = y + math_floor(H / 2)
                    local ty = y + math_floor((H - th) / 2)

                    if split then
                        local iw = math_max(0, w - brand_w - 6)
                        panel(x, y, brand_w, H, a, effects, r, g, b, pulse, style)
                        underline(x + 8, y + H - 1, brand_w - 16, r, g, b, a, now, animated)
                        if iw > 0 then
                            panel(x + brand_w + 6, y, iw, H, a, effects, r, g, b, pulse, style)
                        end
                    else
                        panel(x, y, w, H, a, effects, r, g, b, pulse, style)
                        if style ~= "Neon" then
                            underline(x + 10, y + H - 1, w - 20, r, g, b, a, now, animated)
                        end
                    end

                    sky(x + PADX + 6, cy, r, g, b, 255 * a, now, wm.day)
                    brand_text(x + PADX + 14 + 6, ty, brand, r, g, b, 255 * a, now)

                    local tx = split and (x + brand_w + 6 + PADX) or (x + brand_w)
                    local limit = x + w - 6
                    for i, sg in ipairs(segs) do
                        if tx + sg.w > limit then break end
                        local sep
                        if split then
                            if i > 1 then sep = tx - GAP end
                        else
                            sep = i == 1 and (tx - PADX + 1) or (tx - GAP)
                        end
                        if sep then
                            renderer.gradient(sep, y + 6, 1, math_floor((H - 12) / 2), 255, 255, 255, 0, 255, 255, 255, 30 * a, false)
                            renderer.gradient(sep, y + 6 + math_floor((H - 12) / 2), 1, math_floor((H - 12) / 2), 255, 255, 255, 30 * a, 255, 255, 255, 0, false)
                        end
                        local vx = tx
                        if icons then
                            icon(sg[1], vx + 4, cy, 255 * a)
                            vx = vx + 14
                        end
                        renderer.text(vx, ty, sg[4], sg[5], sg[6], 255 * a, "", 0, sg[2])
                        if sg.uw > 0 then
                            renderer.text(vx + sg.vw + 1, ty + 2, 125, 125, 138, 255 * a, "-", 0, sg[3])
                        end
                        tx = tx + sg.w + GAP * 2
                    end

                    if position == "Custom (drag)" and ui_is_menu_open() then
                        local da = wm.drag.drag and 220 or 100
                        for k = 0, w + 8, 8 do
                            renderer.rectangle(x - 4 + k, y - 4, math_min(4, w + 8 - k), 1, r, g, b, da)
                            renderer.rectangle(x - 4 + k, y + H + 3, math_min(4, w + 8 - k), 1, r, g, b, da)
                        end
                        renderer.text(x + math_floor(w / 2), y + H + 12, r, g, b, da, "c", 0, "drag to move")
                    end
                end)
            end
            config.visuals.damage_marker = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Damage Marker")
                :record("visuals", "damage_marker")
                :save()

            config.visuals.damage_marker_color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "\ndamage_marker", 100, 150, 255, 255)
                :record("visuals", "damage_marker_color")
                :save()

            config.visuals.r8_indicator = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "R8 Indicator")
                :record("visuals", "r8_indicator")
                :save()

            config.visuals.r8_indicator_color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "\nr8_indicator", 100, 150, 255, 255)
                :record("visuals", "r8_indicator_color")
                :save()

            config.visuals.manual_arrows = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Manual Arrows")
                :record("visuals", "manual_arrows")
                :save()

            config.visuals.manual_arrows_color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "\nmanual_arrows", 77, 77, 77, 255)
                :record("visuals", "manual_arrows_color")
                :save()

            config.visuals.manual_arrows_accent = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "•  Accent\narrows", 100, 150, 255, 255)
                :record("visuals", "manual_arrows_accent")
                :save()

            config.visuals.manual_arrows_style = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Style\narrows", {
                "Triangles",
                "Symbols #1",
                "Symbols #2",
                "Symbols #3"
            }):record("visuals", "manual_arrows_style"):save()

            config.visuals.manual_arrows_options = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Settings\narrows", {
                "Hide while scoped"
            }):record("visuals", "manual_arrows_options"):save()

            config.visuals.manual_arrows_size = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Size\narrows", 5, 100, 10, true, "px")
                :record("visuals", "manual_arrows_size")
                :save()
                config.visuals.manual_arrows_offset = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Offset\narrows", 0, 100, 15, true, "px")
                    :record("visuals", "manual_arrows_offset")
                    :save()

                config.visuals.scan_antiaim = menu.new_item(ui.new_checkbox, "AA", "Other", "AA Scan Overlay")
                    :record("visuals", "scan_antiaim")
                    :save()
                config.visuals.scan_antiaim_color = menu.new_item(ui.new_color_picker, "AA", "Other", "\nscan_antiaim_color", 100, 150, 255, 255)
                    :record("visuals", "scan_antiaim_color")
                    :save()
        end

        visuals = {} do
            local screen_size = vector(client.screen_size())
            local screen_center = screen_size * 0.5

            local state_name = player.state

            local smooth_charge = c_tweening:new(0)
            local smooth_scope = c_tweening:new(0)
            local smooth_state = c_tweening:new(1.0)

            local indicator_global = c_tweening:new(0)
            local indicator_grenade = c_tweening:new(1.0)

            visuals.modern = {} do
                local list = {
                    {
                        name = 'VELOCITY: %d%%',
                        format = function ()
                            return player.velocity_modifier * 100
                        end,
                        active = function ()
                            return c_table.contains(config.visuals.indicator_options:get(), 'Velocity modifier') and player.velocity_modifier ~= 1.0
                        end,
                        color = function ()
                            return color.yellow:lerp(color.gray, player.velocity_modifier)
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = 'SAFE HEAD',
                        active = function ()
                            return antiaimbot.features.state.safe_head
                        end,
                        color = color.fixik,
                        animation = c_tweening:new(0)
                    },
                    {
                        -- our records are not lag compensated (teleport > 64 units between sent packets)
                        name = 'LC',
                        active = function ()
                            return player.lc_broken == true
                        end,
                        color = color.fixik,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = 'DOUBLETAP',
                        active = function ()
                            return c_table.is_hotkey_active(reference.ragebot.doubletap.enable)
                        end,
                        color = function ()
                            return color.red:lerp(color.white, smooth_charge())
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = 'ONSHOT',
                        active = function ()
                            return c_table.is_hotkey_active(reference.misc.onshot_antiaim)
                        end,
                        color = color.onshot,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = 'DUCK',
                        active = function ()
                            return ui_get(reference.ragebot.fakeduck) and not player.air_exploit
                        end,
                        color = function (accent, me)
                            return color.white:lerp(color.gray, 1 - player.duckamount)
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = 'DAMAGE: %d',
                        format = function ()
                            return ui_get(reference.ragebot.minimum_damage_override[3])
                        end,
                        active = function ()
                            return c_table.is_hotkey_active(reference.ragebot.minimum_damage_override)
                        end,
                        color = color.white,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = 'FREESTAND',
                        active = function ()
                            return c_table.is_hotkey_active(reference.antiaim.freestanding)
                        end,
                        color = color.freestanding,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = 'EDGE',
                        active = function ()
                            return ui_get(reference.antiaim.yaw.edge)
                        end,
                        color = color.edge,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = 'BAIM',
                        active = function ()
                            return ui_get(reference.ragebot.force_bodyaim)
                        end,
                        color = color.raw_red,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = 'SP',
                        active = function ()
                            return ui_get(reference.ragebot.force_safepoint)
                        end,
                        color = color.raw_green,
                        animation = c_tweening:new(0)
                    }
                }

                visuals.modern.draw = (function (global_alpha, grenade_alpha)
                    local ctx_alpha = global_alpha * grenade_alpha

                    local indicator_offset = config.visuals.indicator_vertical_offset:get()
                    local indicator_position = screen_center + vector(0, indicator_offset)

                    local indicator_accent = color(visuals.indicator_rgb())

                    local indicator_label = 'specter'

                    renderer.text(indicator_position.x , indicator_position.y, 255, 255, 255, 255*ctx_alpha, '-', 0, indicator_label)

                    indicator_position = indicator_position + vector(0, 11)

                    local indicator_body_yaw = c_math.clamp(player.smooth_fakeamount*0.0172, 0.0, 1.0)

                    renderer.rectangle(indicator_position.x + 1, indicator_position.y, 46, 5, 0, 0, 0, 255*ctx_alpha)
                    renderer.gradient(indicator_position.x + 2, indicator_position.y + 1, math_floor(indicator_body_yaw*43), 3,
                        indicator_accent.r, indicator_accent.g, indicator_accent.b, 255*ctx_alpha,
                        indicator_accent.r, indicator_accent.g, indicator_accent.b, 15*ctx_alpha,
                    true)

                    indicator_position = indicator_position + vector(0, 5)

                    for i=1, #list do
                        local indicator = list[i]
                        local indicator_animation = indicator.animation(0.15, ({indicator.active()})[1] or false)

                        if indicator_animation > 0.01 then
                            local indicator_text = indicator.name:format(indicator.format and indicator.format() or '')
                            local indicator_color do
                                if type(indicator.color) == 'table' then
                                    indicator_color = indicator.color
                                elseif type(indicator.color) == 'function' then
                                    indicator_color = indicator.color()
                                else
                                    indicator_accent = indicator_accent:clone()
                                end
                            end

                            renderer.text(indicator_position.x, indicator_position.y, indicator_color.r, indicator_color.g, indicator_color.b, indicator_color.a*indicator_animation*ctx_alpha, '-', 0, indicator_text)

                            indicator_position = indicator_position + vector(0, 9) * indicator_animation
                        end
                    end
                end)
            end

            visuals.legacy = {} do
                local list = {
                    {
                        name = "velocity %d%%",
                        format = function()
                            return player.velocity_modifier * 100
                        end,
                        active = function()
                            return c_table.contains(config.visuals.indicator_options:get(), "Velocity modifier") and player.velocity_modifier ~= 1.0
                        end,
                        color = color.pink,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "safe head",
                        active = function()
                            return antiaimbot.features.state.safe_head
                        end,
                        color = color.fixik,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "lc broken",
                        active = function()
                            return player.lc_broken == true
                        end,
                        color = color.fixik,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "shifting (dt)",
                        active = function()
                            return c_table.is_hotkey_active(reference.ragebot.doubletap.enable)
                        end,
                        color = function()
                            return color.red:lerp(color.white, smooth_charge())
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "onshot",
                        active = function()
                            return c_table.is_hotkey_active(reference.misc.onshot_antiaim)
                        end,
                        color = color.purplish,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "ducking",
                        active = function()
                            return ui_get(reference.ragebot.fakeduck) and not player.air_exploit
                        end,
                        color = function(accent, me)
                            return color.white:lerp(color.gray, 1 - player.duckamount)
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "damage (%d)",
                        format = function()
                            return ui_get(reference.ragebot.minimum_damage_override[3])
                        end,
                        active = function()
                            return c_table.is_hotkey_active(reference.ragebot.minimum_damage_override)
                        end,
                        color = color.white,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "onlybaim",
                        active = function()
                            return ui_get(reference.ragebot.force_bodyaim)
                        end,
                        color = color.pink,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "freestanding",
                        active = function()
                            return c_table.is_hotkey_active(reference.antiaim.freestanding)
                        end,
                        color = color("9DB0FBCA"),
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "edging",
                        active = function()
                            return ui_get(reference.antiaim.yaw.edge)
                        end,
                        color = color.pink,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "safety",
                        active = function()
                            return ui_get(reference.ragebot.force_safepoint)
                        end,
                        color = color.blue,
                        animation = c_tweening:new(0)
                    }
                }

                visuals.legacy.draw = (function (global_alpha, grenade_alpha)
                    local ctx_alpha = global_alpha * grenade_alpha

                    local indicator_offset = config.visuals.indicator_vertical_offset:get()
                    local indicator_position = screen_center + vector(0, indicator_offset)

                    local scope_animation = smooth_scope()

                    local indicator_accent = color(visuals.indicator_rgb())

                    local left_color, right_color do
                        if player.fakeyaw > 0 then
                            left_color = color.white
                            right_color = indicator_accent
                        else
                            left_color = indicator_accent
                            right_color = color.white
                        end
                    end

                    local indicator_label_t = {
                        {'specter', left_color:alpha_modulate(ctx_alpha, true)},
                        {'.', color.white:alpha_modulate(ctx_alpha, true)},
                        {'top', right_color:alpha_modulate(ctx_alpha, true)}
                    }
                    local indicator_label = ''

                    for i=1, 3 do
                        indicator_label = string_format('%s\a%s%s', indicator_label, indicator_label_t[i][2]:to_hex(), indicator_label_t[i][1])
                    end

                    local indicator_label_size = vector(renderer.measure_text('b', 'specter'))
                    local scope_offset = indicator_label_size.x * 0.5 * scope_animation + scope_animation * 4

                    renderer.text(indicator_position.x + scope_offset - indicator_label_size.x * 0.5 + 1, indicator_position.y - indicator_label_size.y * 0.5, 255, 255, 255, 255, 'b', 0, indicator_label)

                    indicator_position = indicator_position + vector(0, indicator_label_size.y)

                    local indicator_body_yaw = c_math.clamp(player.smooth_fakeamount*0.0172, 0.0, 1.0)
                    local indicator_dsy = string_format('%d%%', indicator_body_yaw*100)
                    local indicator_dsy_size = vector(renderer.measure_text('-', indicator_dsy))

                    local scope_offset_dsy = indicator_dsy_size.x * 0.5 * scope_animation + scope_animation * 3

                    renderer.text(indicator_position.x + scope_offset_dsy - indicator_dsy_size.x*0.5, indicator_position.y - indicator_dsy_size.y*0.5, indicator_accent.r, indicator_accent.g, indicator_accent.b, 255*ctx_alpha, '-', 0, indicator_dsy)

                    indicator_position = indicator_position + vector(0, indicator_dsy_size.y + 1)

                    for i=1, #list do
                        local indicator = list[i]
                        local indicator_animation = indicator.animation(0.15, ({indicator.active()})[1] or false)

                        if indicator_animation > 0.01 then
                            local indicator_text = indicator.name:format(indicator.format and indicator.format() or '')
                            local indicator_color do
                                if type(indicator.color) == 'table' then
                                    indicator_color = indicator.color
                                elseif type(indicator.color) == 'function' then
                                    indicator_color = indicator.color(indicator_accent)
                                else
                                    indicator_accent = indicator_accent:clone()
                                end
                            end

                            local text_size = vector(renderer.measure_text('', indicator_text))
                            local _scope_offset = text_size.x*scope_animation*0.5 + scope_animation * 3

                            renderer.text(indicator_position.x + _scope_offset - text_size.x*0.5 + 1, indicator_position.y - text_size.y*0.5, indicator_color.r, indicator_color.g, indicator_color.b, indicator_color.a * indicator_animation*ctx_alpha, '', 0, indicator_text)

                            indicator_position = indicator_position + vector(0, text_size.y) * indicator_animation
                        end
                    end
                end)
            end

            visuals.renewed = {} do
                visuals.renewed.states = {
                    ['Air'] = 'AIR',
                    ['Air & Crouch'] = 'AIR+',
                    ['Crouching'] = 'CROUCHING',
                    ['Crouch moving'] = 'CROUCHING'
                }
                local list = {
                    {
                        name = "%s",
                        format = function()
                            return state_name:upper()
                        end,
                        active = function()
                            return true
                        end,
                        color = function(accent, accent_second)
                            return accent:lerp(accent_second, smooth_state())
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "%d%%",
                        format = function()
                            return player.velocity_modifier * 100
                        end,
                        active = function()
                            return c_table.contains(config.visuals.indicator_options:get(), "Velocity modifier") and player.velocity_modifier ~= 1.0
                        end,
                        color = function(accent)
                            return color.red:lerp(accent, player.velocity_modifier)
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "DMG",
                        active = function()
                            return c_table.is_hotkey_active(reference.ragebot.minimum_damage_override)
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "DT",
                        active = function()
                            return c_table.is_hotkey_active(reference.ragebot.doubletap.enable)
                        end,
                        color = function(accent)
                            return color.red:lerp(accent, smooth_charge())
                        end,
                        render_addition = function(pos, accent, ctx)
                            renderer.circle_outline(
                                pos.x + 1,
                                pos.y,
                                accent.r,
                                accent.g,
                                accent.b,
                                255 * ctx,
                                3,
                                180,
                                smooth_charge(),
                                1
                            )
                        end,
                        offset_x = function(scope)
                            return smooth_charge() * -4 * scope + scope * 1
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "FREESTAND",
                        active = function()
                            return c_table.is_hotkey_active(reference.antiaim.freestanding)
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "OSAA",
                        active = function()
                            return c_table.is_hotkey_active(reference.misc.onshot_antiaim)
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "EDGE",
                        active = function()
                            return ui_get(reference.antiaim.yaw.edge)
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "BAIM",
                        active = function()
                            return ui_get(reference.ragebot.force_bodyaim)
                        end,
                        animation = c_tweening:new(0)
                    },
                    {
                        name = "SP",
                        active = function()
                            return ui_get(reference.ragebot.force_safepoint)
                        end,
                        animation = c_tweening:new(0)
                    }
                }

                visuals.renewed.draw = (function (global_alpha, grenade_alpha)
                    local ctx_alpha = global_alpha * grenade_alpha

                    local indicator_offset = config.visuals.indicator_vertical_offset:get()
                    local indicator_position = screen_center + vector(0, indicator_offset)

                    local scope_animation = smooth_scope()
                    local rev_scope_animation = 1 - scope_animation

                    local indicator_accent = color(visuals.indicator_rgb())
                    local indicator_renewed = color(config.visuals.indicator_renewed_color:get())

                    local indicator_label = color.animated_text('specter', 1, indicator_renewed, indicator_accent, ctx_alpha*255)
                    local indicator_label_size = vector(renderer.measure_text('b', 'specter'))

                    local scope_offset = indicator_label_size.x * 0.5 * scope_animation + scope_animation * 3

                    renderer.text(indicator_position.x + scope_offset - indicator_label_size.x * 0.5, indicator_position.y - indicator_label_size.y * 0.5, 255, 255, 255, ctx_alpha*255, 'b', 0, indicator_label)

                    indicator_position = indicator_position + vector(0, indicator_label_size.y - 1)

                    for i=1, #list do
                        local indicator = list[i]
                        local indicator_animation = indicator.animation(0.15, ({indicator.active()})[1] or false)

                        if indicator_animation > 0.01 then
                            local indicator_text = indicator.name:format(indicator.format and indicator.format() or '')
                            local indicator_color do
                                if type(indicator.color) == 'table' then
                                    indicator_color = indicator.color
                                elseif type(indicator.color) == 'function' then
                                    indicator_color = indicator.color(indicator_accent, indicator_renewed)
                                else
                                    indicator_color = indicator_accent:clone()
                                end
                            end

                            local text_size = vector(renderer.measure_text('-', indicator_text))
                            local _x_offset = indicator.offset_x or 0

                            if type(_x_offset) == 'function' then
                                _x_offset = _x_offset(rev_scope_animation)
                            end

                            local _scope_offset = text_size.x*scope_animation*0.5 + scope_animation * 3

                            renderer.text(indicator_position.x + _scope_offset - text_size.x * 0.5 - 1 + _x_offset, indicator_position.y - text_size.y * 0.5, indicator_color.r, indicator_color.g, indicator_color.b, 255 * indicator_animation*ctx_alpha, '-', 0, indicator_text)

                            if indicator.render_addition then
                                indicator.render_addition(vector(indicator_position.x + text_size.x + _scope_offset + _x_offset, indicator_position.y), indicator_accent, indicator_animation*ctx_alpha)
                            end

                            indicator_position = indicator_position + vector(0, text_size.y) * indicator_animation
                        end
                    end
                end)
            end

            visuals.specter_style = {} do
                local st = { a = 0, dim = 1, scope = 0, amount = 0, charge = 0, side = 0, state = "", prev = "", fade = 1, binds = {} }
                local BIND_LIST = {
                    { key = "dt",   name = "DT" },
                    { key = "hs",   name = "HIDE" },
                    { key = "dmg",  name = "DMG" },
                    { key = "fs",   name = "FS" },
                    { key = "baim", name = "BAIM" },
                    { key = "sp",   name = "SAFE" },
                    { key = "fd",   name = "DUCK" },
                    { key = "edge", name = "EDGE" },
                }
                local PREVIEW_STATES = { "STANDING", "MOVING", "AIR", "CROUCHING", "ANTI-BRUTE 1" }

                local function ease(ft, k)
                    return 1 - math.exp(-ft * k)
                end

                local function live_state()
                    local name = visuals.renewed.states[player.state] or player.state or "stand"
                    if antiaimbot.features.state.safe_head then name = "safe head" end
                    if antiaimbot.anti_brute and antiaimbot.anti_brute.active then
                        name = "anti-brute " .. tostring(antiaimbot.anti_brute.stage)
                    end
                    return string.upper(tostring(name))
                end

                local function live_binds()
                    local dmg_on = c_table.is_hotkey_active(reference.ragebot.minimum_damage_override)
                    local dmg_value = nil
                    if dmg_on then
                        local ok, v = pcall(ui_get, reference.ragebot.minimum_damage_override[3])
                        dmg_value = ok and v or nil
                    end
                    return {
                        dt = c_table.is_hotkey_active(reference.ragebot.doubletap.enable),
                        hs = c_table.is_hotkey_active(reference.misc.onshot_antiaim),
                        dmg = dmg_on,
                        fs = c_table.is_hotkey_active(reference.antiaim.freestanding),
                        baim = ui_get(reference.ragebot.force_bodyaim),
                        sp = ui_get(reference.ragebot.force_safepoint),
                        fd = ui_get(reference.ragebot.fakeduck),
                        edge = ui_get(reference.antiaim.yaw.edge),
                    }, dmg_value
                end

                visuals.specter_style.live_state, visuals.specter_style.live_binds = live_state, live_binds

                function visuals.specter_style.draw(alpha, preview)
                    local ft = globals_frametime()
                    local now = globals.realtime()
                    local sw, sh = client.screen_size()
                    local cx, cy = math_floor(sw / 2), math_floor(sh / 2)
                    local opts = config.visuals.indicator_options:get() or {}
                    local r, g, b = visuals.indicator_rgb()

                    local state_text, binds, dmg_value, amount, charge, side, scoped
                    if preview then
                        state_text = PREVIEW_STATES[math_floor(now / 2) % #PREVIEW_STATES + 1]
                        local phase = math_floor(now / 2.5) % 4
                        binds = { dt = true, hs = phase == 1 or phase == 2, dmg = phase >= 2, fs = phase ~= 3, baim = phase == 3 }
                        dmg_value = 42
                        amount = 0.55 + 0.4 * math.sin(now * 1.3)
                        charge = math_min(1, (now % 4) / 2.5)
                        side = math.sin(now * 0.8) > 0
                        scoped = math_floor(now / 5) % 2 == 1
                    else
                        state_text = live_state()
                        binds, dmg_value = live_binds()
                        amount = c_math.clamp((player.smooth_fakeamount or 0) * 0.0172, 0, 1)
                        charge = player:get_double_tap() and 1 or 0
                        side = (player.fakeyaw or 0) > 0
                        scoped = entity_get_prop(player.entindex, "m_bIsScoped") == 1
                    end

                    st.a = st.a + (alpha - st.a) * ease(ft, 12)
                    local grenade = not preview and c_table.contains(opts, "Alter alpha on grenade") and player.weapon_type == "grenade"
                    local dim = (grenade or (scoped and c_table.contains(opts, "Alter alpha while scoped"))) and 0.5 or 1
                    st.dim = st.dim + (dim - st.dim) * ease(ft, 10)
                    local a = st.a * st.dim
                    if a < 0.01 then return end

                    local want_scope = (scoped and c_table.contains(opts, "Adjust while scoped")) and 1 or 0
                    st.scope = st.scope + (want_scope - st.scope) * ease(ft, 12)
                    st.amount = st.amount + (amount - st.amount) * ease(ft, 8)
                    st.charge = st.charge + (charge - st.charge) * ease(ft, 10)
                    st.side = st.side + ((side and 1 or 0) - st.side) * ease(ft, 10)

                    if state_text ~= st.state then
                        st.prev, st.state, st.fade = st.state, state_text, 0
                    end
                    st.fade = st.fade + (1 - st.fade) * ease(ft, 10)

                    local function col_x(w)
                        return math_floor(cx - w / 2 + (w / 2 + 8) * st.scope + 0.5)
                    end

                    local y = cy + (config.visuals.indicator_vertical_offset:get() or 20)

                    local brand = "specter"
                    local bw, bh = renderer.measure_text("b", brand)
                    local px = col_x(bw)
                    for i = 1, #brand do
                        local ch = brand:sub(i, i)
                        local t = 0.5 + 0.5 * math.sin(now * 2 - i * 0.6)
                        renderer.text(px + 1, y + 1, 0, 0, 0, 120 * a, "b", 0, ch)
                        renderer.text(px, y, math_floor(245 + (r - 245) * t), math_floor(245 + (g - 245) * t), math_floor(250 + (b - 250) * t), 255 * a, "b", 0, ch)
                        px = px + renderer.measure_text("b", ch)
                    end
                    y = y + bh + 2

                    local BW = 42
                    local bx = col_x(BW)
                    visuals.rounded(bx, y, BW, 5, 2, 0, 0, 0, 160 * a)
                    local fill = math_floor((BW - 2) * st.amount + 0.5)
                    if fill > 0 then
                        local fx = bx + 1 + math_floor((BW - 2 - fill) * st.side + 0.5)
                        local left_a = (st.side < 0.5) and 255 or 70
                        local right_a = (st.side < 0.5) and 70 or 255
                        renderer.gradient(fx, y + 1, fill, 3, r, g, b, left_a * a, r, g, b, right_a * a, true)
                    end
                    y = y + 9

                    if st.fade < 0.99 and st.prev ~= "" then
                        local pw = renderer.measure_text("-", st.prev)
                        renderer.text(col_x(pw), y - math_floor(st.fade * 4), 235, 235, 242, 255 * a * (1 - st.fade), "-", 0, st.prev)
                    end
                    local sw1 = renderer.measure_text("-", st.state)
                    renderer.text(col_x(sw1), y + math_floor((1 - st.fade) * 4), 235, 235, 242, 255 * a * st.fade, "-", 0, st.state)
                    y = y + 10

                    for _, bind in ipairs(BIND_LIST) do
                        local on = binds[bind.key] and true or false
                        local s = st.binds[bind.key] or 0
                        s = s + ((on and 1 or 0) - s) * ease(ft, 14)
                        if s < 0.005 then s = 0 end
                        st.binds[bind.key] = s
                        if s > 0.01 then
                            local text = bind.name
                            if bind.key == "dmg" and dmg_value then text = "DMG " .. tostring(dmg_value) end
                            local tw = renderer.measure_text("-", text)
                            local tx = col_x(tw) + math_floor((1 - s) * 8)
                            local cr, cg, cb = r, g, b
                            if bind.key == "dt" then
                                cr = math_floor(255 + (r - 255) * st.charge)
                                cg = math_floor(95 + (g - 95) * st.charge)
                                cb = math_floor(95 + (b - 95) * st.charge)
                            end
                            renderer.text(tx, y, cr, cg, cb, 255 * a * s, "-", 0, text)
                            if bind.key == "dt" then
                                renderer.circle_outline(tx + tw + 5, y + 5, cr, cg, cb, 255 * a * s, 3, 270, st.charge, 1)
                            end
                            y = y + 9 * s
                        end
                    end
                end
            end

            visuals.nova = {} do
                local st = { a = 0, dim = 1, scope = 0, amount = 0, charge = 0, side = 0, def = 0, dt = 0,
                             vel = 1, state = "", prev = "", fade = 1, chips = {}, row_w = 0 }
                local CHIPS = {
                    { "dt", "DT" }, { "hs", "OS" }, { "dmg", "DMG" }, { "fs", "FS" },
                    { "baim", "BODY" }, { "sp", "SAFE" }, { "fd", "DUCK" }, { "edge", "EDGE" },
                }
                local PREVIEW_STATES = { "STANDING", "MOVING", "AIR", "CROUCHING", "ANTI-BRUTE 2" }
                local R = 26           -- halo radius around the crosshair
                local SPAN = 56        -- degrees each side arc covers

                local function ease(ft, k) return 1 - math.exp(-ft * k) end

                local function arc(cx, cy, rad, start, pct, r, g, b, a, th)
                    if pct <= 0.002 or a < 1 then return end
                    renderer.circle_outline(cx, cy, r, g, b, a, rad, start, pct, th)
                end

                -- glowing arc: soft wide pass + crisp core
                local function glow_arc(cx, cy, rad, start, pct, r, g, b, a, th)
                    arc(cx, cy, rad, start, pct, r, g, b, a * 0.22, th + 3)
                    arc(cx, cy, rad, start, pct, r, g, b, a, th)
                end

                local function has(list, v) return c_table.contains(list, v) end

                function visuals.nova.draw(alpha, preview)
                    local ft = globals_frametime()
                    local now = globals.realtime()
                    local sw, sh = client.screen_size()
                    local cx, cy = math_floor(sw / 2), math_floor(sh / 2)
                    local opts = config.visuals.indicator_options:get() or {}
                    local el = config.visuals.nova_elements:get() or {}
                    local r, g, b = visuals.indicator_rgb()
                    preview = preview and true or false

                    local state_text, binds, dmg_value, amount, charge, side, scoped, defensive, vel
                    if preview then
                        state_text = PREVIEW_STATES[math_floor(now / 2) % #PREVIEW_STATES + 1]
                        local phase = math_floor(now / 2.5) % 4
                        binds = { dt = true, hs = phase == 1, dmg = phase >= 2, fs = phase ~= 3, baim = phase == 3, sp = phase == 2 }
                        dmg_value = 42
                        amount = 0.6 + 0.35 * math.sin(now * 1.3)
                        charge = math_min(1, (now % 4) / 2.2)
                        side = math.sin(now * 0.8) > 0
                        scoped = false
                        defensive = (now % 3) < 0.6
                        vel = 0.55 + 0.45 * math.abs(math.sin(now * 0.5))
                    else
                        local ss = visuals.specter_style
                        state_text = ss.live_state()
                        binds, dmg_value = ss.live_binds()
                        amount = c_math.clamp((player.smooth_fakeamount or 0) * 0.0172, 0, 1)
                        charge = player:get_double_tap() and 1 or 0
                        side = (player.fakeyaw or 0) > 0
                        scoped = entity_get_prop(player.entindex, "m_bIsScoped") == 1
                        defensive = player.defensive_active == true
                        vel = player.velocity_modifier or 1
                    end

                    st.a = st.a + (alpha - st.a) * ease(ft, 12)
                    local grenade = not preview and has(opts, "Alter alpha on grenade") and player.weapon_type == "grenade"
                    local dim = (grenade or (scoped and has(opts, "Alter alpha while scoped"))) and 0.45 or 1
                    st.dim = st.dim + (dim - st.dim) * ease(ft, 10)
                    local a = st.a * st.dim
                    if a < 0.01 then return end

                    st.scope = st.scope + (((scoped and has(opts, "Adjust while scoped")) and 1 or 0) - st.scope) * ease(ft, 12)
                    st.amount = st.amount + (amount - st.amount) * ease(ft, 8)
                    st.charge = st.charge + (charge - st.charge) * ease(ft, 10)
                    st.side = st.side + ((side and 1 or 0) - st.side) * ease(ft, 10)
                    st.def = st.def + ((defensive and 1 or 0) - st.def) * ease(ft, defensive and 20 or 6)
                    st.dt = st.dt + ((binds.dt and 1 or 0) - st.dt) * ease(ft, 12)
                    st.vel = st.vel + (vel - st.vel) * ease(ft, 8)
                    if state_text ~= st.state then st.prev, st.state, st.fade = st.state, state_text, 0 end
                    st.fade = st.fade + (1 - st.fade) * ease(ft, 10)

                    local pulse = 0.7 + 0.3 * math.sin(now * 4)

                    ---
                    --- halo around the crosshair
                    ---
                    if has(el, "Halo") then
                        local ha = a * (1 - st.scope * 0.6)
                        local left_i, right_i = 1 - st.side, st.side
                        -- tracks
                        arc(cx, cy, R, 180 + SPAN / 2, SPAN / 360, 0, 0, 0, 90 * ha, 3)
                        arc(cx, cy, R, SPAN / 2, SPAN / 360, 0, 0, 0, 90 * ha, 3)
                        -- desync fill grows from the bottom of each arc
                        local fill = SPAN * st.amount / 360
                        glow_arc(cx, cy, R, 180 + SPAN / 2, fill, r, g, b, (70 + 185 * left_i) * ha, 2)
                        glow_arc(cx, cy, R, -SPAN / 2 + SPAN * st.amount, fill, r, g, b, (70 + 185 * right_i) * ha, 2)
                        -- end caps on the active side
                        local cap = math.rad(180 + SPAN / 2 - SPAN * st.amount)
                        if left_i > 0.05 then
                            renderer.circle(cx + math.cos(cap) * R, cy - math.sin(cap) * R, 255, 255, 255, 230 * ha * left_i, 1.6, 0, 1)
                        end
                        local cap2 = math.rad(SPAN * st.amount - SPAN / 2)
                        if right_i > 0.05 then
                            renderer.circle(cx + math.cos(cap2) * R, cy - math.sin(cap2) * R, 255, 255, 255, 230 * ha * right_i, 1.6, 0, 1)
                        end

                        -- DT charge along the bottom
                        if st.dt > 0.01 then
                            local cr = math_floor(255 + (r - 255) * st.charge)
                            local cg = math_floor(90 + (g - 90) * st.charge)
                            local cb = math_floor(90 + (b - 90) * st.charge)
                            arc(cx, cy, R + 5, 270 + 30, 60 / 360, 0, 0, 0, 80 * ha * st.dt, 2)
                            glow_arc(cx, cy, R + 5, 270 + 30, 60 / 360 * st.charge, cr, cg, cb, 255 * ha * st.dt, 2)
                        end

                        -- defensive flash across the top
                        if st.def > 0.01 then
                            glow_arc(cx, cy, R + 5, 90 + 30, 60 / 360, r, g, b, 255 * ha * st.def * pulse, 2)
                        end

                        -- velocity modifier: thin inner ring shrinks while slowed
                        -- velocity modifier: red arc opening from the top, as wide as the slowdown
                        if has(opts, "Velocity modifier") and st.vel < 0.98 then
                            local miss = c_math.clamp(1 - st.vel, 0, 1)
                            local span = 150 * miss
                            glow_arc(cx, cy, R - 6, 90 + span / 2, span / 360, 255, 95, 95, 210 * ha, 1)
                        end
                    end

                    ---
                    --- text block under the crosshair
                    ---
                    local y = cy + math_max(config.visuals.indicator_vertical_offset:get() or 20, R + 14)
                    local function col_x(w) return math_floor(cx - w / 2 + (w / 2 + 12) * st.scope + 0.5) end

                    if has(el, "Brand") then
                        local brand = "specter"
                        local bw, bh = renderer.measure_text("b", brand)
                        local pw, ph = bw + 26, bh + 6
                        local px = col_x(pw)
                        visuals.rounded(px - 2, y - 1, pw + 4, ph + 4, 10, 0, 0, 0, 30 * a)
                        visuals.rounded(px, y, pw, ph, 8, 10, 10, 14, 200 * a)
                        visuals.rounded(px, y, pw, ph, 8, r, g, b, 26 * a)
                        -- side dots
                        renderer.circle(px + 7, y + ph / 2, r, g, b, (60 + 195 * (1 - st.side)) * a, 2.2, 0, 1)
                        renderer.circle(px + pw - 7, y + ph / 2, r, g, b, (60 + 195 * st.side) * a, 2.2, 0, 1)
                        local tx = px + 13
                        for i = 1, #brand do
                            local ch = brand:sub(i, i)
                            local t = 0.5 + 0.5 * math.sin(now * 2.4 - i * 0.7)
                            renderer.text(tx, y + 3, math_floor(245 + (r - 245) * t), math_floor(245 + (g - 245) * t), math_floor(250 + (b - 250) * t), 255 * a, "b", 0, ch)
                            tx = tx + renderer.measure_text("b", ch)
                        end
                        local half = math_floor((pw - 16) / 2)
                        renderer.gradient(px + 8, y + ph - 1, half, 1, r, g, b, 0, r, g, b, 200 * a, true)
                        renderer.gradient(px + 8 + half, y + ph - 1, pw - 16 - half, 1, r, g, b, 200 * a, r, g, b, 0, true)
                        y = y + ph + 4
                    end

                    if has(el, "State") then
                        if st.fade < 0.99 and st.prev ~= "" then
                            local pw = renderer.measure_text("-", st.prev)
                            renderer.text(col_x(pw), y - math_floor(st.fade * 5), 230, 230, 238, 255 * a * (1 - st.fade), "-", 0, st.prev)
                        end
                        local sw1 = renderer.measure_text("-", st.state)
                        local sx = col_x(sw1)
                        local sy = y + math_floor((1 - st.fade) * 5)
                        renderer.text(sx + 1, sy + 1, 0, 0, 0, 150 * a * st.fade, "-", 0, st.state)
                        renderer.text(sx, sy, 232, 232, 240, 255 * a * st.fade, "-", 0, st.state)
                        y = y + 12
                    end

                    if has(el, "Binds") then
                        -- animate every chip, then lay out the visible ones centered on one row
                        local row, total = {}, 0
                        for _, c in ipairs(CHIPS) do
                            local key = c[1]
                            local s = st.chips[key] or 0
                            s = s + (((binds[key]) and 1 or 0) - s) * ease(ft, 14)
                            if s < 0.004 then s = 0 end
                            st.chips[key] = s
                            if s > 0 then
                                local text = c[2]
                                if key == "dmg" and dmg_value then text = "DMG " .. tostring(dmg_value) end
                                local tw = renderer.measure_text("-", text)
                                local w = tw + 10 + (key == "dt" and 9 or 0)
                                row[#row + 1] = { key = key, text = text, tw = tw, w = w, s = s }
                                total = total + (w + 3) * s
                            end
                        end
                        st.row_w = st.row_w + (total - st.row_w) * ease(ft, 14)
                        local rx = col_x(st.row_w)
                        for _, c in ipairs(row) do
                            local ca = a * c.s
                            local cyo = y + math_floor((1 - c.s) * 4)
                            local cr, cg, cb = r, g, b
                            if c.key == "dt" then
                                cr = math_floor(255 + (r - 255) * st.charge)
                                cg = math_floor(90 + (g - 90) * st.charge)
                                cb = math_floor(90 + (b - 90) * st.charge)
                            end
                            visuals.rounded(rx, cyo, c.w, 12, 4, 10, 10, 14, 190 * ca)
                            visuals.rounded(rx, cyo, c.w, 12, 4, cr, cg, cb, 38 * ca)
                            renderer.rectangle(rx + 3, cyo + 11, c.w - 6, 1, cr, cg, cb, 200 * ca)
                            renderer.text(rx + 5, cyo + 2, cr, cg, cb, 255 * ca, "-", 0, c.text)
                            if c.key == "dt" then
                                renderer.circle_outline(rx + c.w - 7, cyo + 6, cr, cg, cb, 255 * ca, 3, 90, st.charge, 1)
                            end
                            rx = rx + (c.w + 3) * c.s
                        end
                        if #row > 0 then y = y + 15 end
                    end

                    if has(el, "Defensive") and st.def > 0.01 then
                        local t = "DEFENSIVE"
                        local tw = renderer.measure_text("-", t)
                        local dx = col_x(tw)
                        renderer.text(dx, y, r, g, b, 255 * a * st.def * pulse, "-", 0, t)
                    end
                end
            end

            local previous_state = player.state

            visuals.draw_indicators = (function (self)
                if not player.alive then
                    return
                end

                local me = player.entindex
                local indicator_options = config.visuals.indicator_options:get()
                local is_scoped = entity_get_prop(me, 'm_bIsScoped') == 1

                smooth_scope(0.1, c_table.contains(indicator_options, 'Adjust while scoped') and is_scoped)

                local exploits_charged = player:get_double_tap()

                smooth_charge(0.1, exploits_charged or false)

                local player_state = self.renewed.states[player.state] or player.state

                if antiaimbot.features.state.safe_head then
                    player_state = 'SAFE'
                end

                if antiaimbot.anti_brute and antiaimbot.anti_brute.active then
                    player_state = 'AB:' .. antiaimbot.anti_brute.stage
                end

                if previous_state ~= player_state then
                    smooth_state(0.15, 1)

                    if smooth_state() == 1.0 then
                        state_name = player_state

                        previous_state = player_state
                    end
                else
                    smooth_state(0.15, 0)
                end

                local indicator_state = indicator_global(0.15, config.visuals.indicators:get())
                local grenade_b = c_table.contains(indicator_options, 'Alter alpha on grenade') and player.weapon_type == 'grenade' or c_table.contains(indicator_options, 'Alter alpha while scoped') and is_scoped
                local grenade_state = indicator_grenade(0.15, grenade_b and 0.5 or 1.0)

                if config.visuals.indicator_style:get() == 'Specter' then
                    self.specter_style.draw(config.visuals.indicators:get() and 1 or 0, false)
                    return
                end
                if config.visuals.indicator_style:get() == 'Nova' then
                    self.nova.draw(config.visuals.indicators:get() and 1 or 0, false)
                    return
                end

                if indicator_state > 0.01 then
                    local indicator_type = config.visuals.indicator_style:get();

                    if indicator_type == 'Modern' then
                        self.modern.draw(indicator_state, grenade_state);
                    elseif indicator_type == 'Legacy' then
                        self.legacy.draw(indicator_state, grenade_state);
                    elseif indicator_type == 'Renewed' then
                        self.renewed.draw(indicator_state, grenade_state);
                    end
                end
            end)

            visuals.markers = {} do
                local marker_points = { 0, 5, 2, 13, 14, 7, 8 }
                local list = {}

                function visuals.markers.receive(event)
                    local userid, attacker = client.userid_to_entindex(event.userid), client.userid_to_entindex(event.attacker)

                    if not userid or not attacker or userid == attacker or attacker ~= player.entindex then
                        return
                    end

                    local hitbox = marker_points[event.hitgroup] or 3
                    local found_existing = false

                    for i=1, #list do
                        local marker = list[i]

                        if marker[1] == userid and marker[3]-globals.realtime() > 1 then
                            marker[5] = marker[5] + (event.dmg_health or 0)

                            found_existing = true
                        end
                    end

                    if not found_existing then
                        list[#list+1] = {
                            userid;
                            {c_tweening:new(0.01), c_tweening:new(0)},
                            globals.realtime() + 2,
                            {config.visuals.damage_marker_color:get()},
                            event.dmg_health or 0,
                            {entity.hitbox_position(userid, hitbox)}
                        }
                    end
                end

                visuals.markers.draw = (function ()
                    local realtime = globals.realtime();

                    for i, marker in ipairs(list) do
                        local time_diff = marker[3] - realtime;
                        local anim = marker[2][1](0.2, time_diff > 0 or marker[2][2]() ~= marker[5]);

                        if anim < 0.01 then
                            table_remove(list, i);
                        else
                            local anim_dmg = marker[2][2](1.5, marker[5]);
                            local screen_x, screen_y = renderer.world_to_screen(marker[6][1], marker[6][2], marker[6][3] + 60 - (time_diff * 40));

                            if screen_x then
                                renderer.text(screen_x, screen_y, marker[4][1], marker[4][2], marker[4][3], marker[4][4]*anim, 'bc', 0, math_floor(anim_dmg));
                            end
                        end
                    end
                end)
            end

            visuals.draw_markers = (function (self)
                if config.visuals.damage_marker:get() then
                    self.markers.draw()
                end
            end)

            visuals.r8_indicator = {} do
                local r8_main = c_tweening:new(0)
                local r8_process = c_tweening:new(0)

                visuals.r8_indicator.draw = (function ()
                    if not player.alive then
                        return
                    end

                    local wpn = entity.get_player_weapon(player.entindex)

                    if not wpn then
                        return
                    end

                    local wpn_info = csgo_weapons(wpn)

                    local main_alpha = r8_main(0.15, (config.visuals.r8_indicator:get() and wpn_info and wpn_info.is_revolver) == true)

                    if main_alpha < 0.01 then
                        return
                    end

                    local time = globals_curtime()

                    local m_flFireReady = entity_get_prop(wpn, 'm_flPostponeFireReadyTime')

                    if m_flFireReady > 0 and m_flFireReady < globals_curtime() then
                        if m_flFireReady + globals_tickinterval() * 14 > globals_curtime() then
                            time = m_flFireReady + globals_tickinterval() * 14
                        end
                    end

                    local r8_pct = (time - globals_curtime()) * 4.571428571

                    local circle_anim = r8_process(0.15, r8_pct) * main_alpha
                    local circle_color = color(config.visuals.r8_indicator_color:get())

                    if entity_get_prop(player.entindex, 'm_flNextAttack') - globals_curtime() >= 0 or entity_get_prop(wpn, 'm_flNextPrimaryAttack') - globals_curtime() >= 0 then
                        r8_process(0.001, 1)
                        circle_anim = 1
                    end

                    renderer.circle_outline(screen_center.x + 25, screen_center.y, 0, 0, 0, 120*main_alpha, 8.2, 0, 1, 5)
                    renderer.circle_outline(screen_center.x + 25, screen_center.y, circle_color.r, circle_color.g, circle_color.b, 255*main_alpha, 7.2, 0, (1 - circle_anim)*main_alpha, 3)
                end)
            end

            visuals.draw_r8_indicator = (function (self)
                if config.visuals.r8_indicator:get() then
                    self.r8_indicator.draw()
                end
            end)

            visuals.manual_arrows = {} do
                local arrows = {
                    main = c_tweening:new(0),
                    left = c_tweening:new(0),
                    right = c_tweening:new(0)
                }

                local arrow_svg3 = (function ()
                    return renderer.load_svg('<svg width="44" height="51" viewBox="0 0 44 51" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4.80057 0.42733L42.2181 23.2222C43.9803 24.2955 43.9775 26.8231 42.2135 27.893L4.81149 50.5757C2.3411 52.0739 -0.515033 49.3119 0.956021 46.8473L12.8323 26.9498C13.344 26.0926 13.345 25.0295 12.8351 24.1714L0.937543 4.14816C-0.528614 1.68041 2.33319 -1.07609 4.80057 0.42733Z" fill="white"/><path d="M4.80057 0.42733L42.2181 23.2222C43.9803 24.2955 43.9775 26.8231 42.2135 27.893L4.81149 50.5757C2.3411 52.0739 -0.515033 49.3119 0.956021 46.8473L12.8323 26.9498C13.344 26.0926 13.345 25.0295 12.8351 24.1714L0.937543 4.14816C-0.528614 1.68041 2.33319 -1.07609 4.80057 0.42733Z" fill="white"/></svg>', 8, 11);
                end)()

                visuals.manual_arrows.draw = (function ()
                    if not player.alive then
                        return
                    end

                    local arrow_options = config.visuals.manual_arrows_options:get()
                    local scope_check = true

                    if c_table.contains(arrow_options, 'Hide while scoped') then
                        scope_check = smooth_scope() < 1
                    end

                    local main = arrows.main(0.15, antiaimbot.manual_antiaim.state ~= -1 and config.visuals.manual_arrows:get() and scope_check)

                    if main > 0.01 then
                        local manual_color_bg = color(config.visuals.manual_arrows_color:get())
                        local manual_color = color(config.visuals.manual_arrows_accent:get())

                        local manual_size = config.visuals.manual_arrows_size:get()
                        local manual_offset = config.visuals.manual_arrows_offset:get()

                        local manual_style = config.visuals.manual_arrows_style:get()

                        local left_modifier = arrows.left(0.15, antiaimbot.manual_antiaim.state == antiaimbot.manual_antiaim.MANUAL_LEFT or antiaimbot.manual_antiaim.state == antiaimbot.manual_antiaim.MANUAL_BACK)
                        local base_position_left = vector(screen_center.x - manual_offset, screen_center.y + 1)

                        local arrow_weight = 8
                        local arrow_height = 11

                        if manual_style == 'Triangles' then
                            renderer.triangle(
                                base_position_left.x - manual_size, base_position_left.y,
                                base_position_left.x, base_position_left.y - manual_size * 0.5,
                                base_position_left.x, base_position_left.y + manual_size * 0.5,
                                manual_color_bg.r, manual_color_bg.g, manual_color_bg.b, manual_color_bg.a * main
                            )

                            renderer.triangle(
                                base_position_left.x - manual_size, base_position_left.y,
                                base_position_left.x, base_position_left.y - manual_size * 0.5,
                                base_position_left.x, base_position_left.y + manual_size * 0.5,
                                manual_color.r, manual_color.g, manual_color.b, 255 * left_modifier * main
                            )
                        elseif manual_style == 'Symbols #1' then
                            renderer.text(base_position_left.x+1, base_position_left.y-4, manual_color_bg.r, manual_color_bg.g, manual_color_bg.b, manual_color_bg.a * main, 'cb+', 0, '‹')
                            renderer.text(base_position_left.x+1, base_position_left.y-4, manual_color.r, manual_color.g, manual_color.b, 255 * left_modifier * main, 'cb+', 0, '‹')
                        elseif manual_style == 'Symbols #2' then
                            renderer.text(base_position_left.x, base_position_left.y-2, manual_color_bg.r, manual_color_bg.g, manual_color_bg.b, manual_color_bg.a * main, 'cb', 0, '⯇')
                            renderer.text(base_position_left.x, base_position_left.y-2, manual_color.r, manual_color.g, manual_color.b, 255 * left_modifier * main, 'cb', 0, '⯇')
                        elseif manual_style == 'Symbols #3' then
                            renderer.texture(arrow_svg3, base_position_left.x+1+arrow_weight/2, base_position_left.y-arrow_height/2+1, -arrow_weight, arrow_height, manual_color_bg.r, manual_color_bg.g, manual_color_bg.b, manual_color_bg.a * main, 'f')
                            renderer.texture(arrow_svg3, base_position_left.x+arrow_weight/2, base_position_left.y-arrow_height/2, -arrow_weight, arrow_height, manual_color.r, manual_color.g, manual_color.b, 255 * left_modifier * main, 'f')
                        end

                        local right_modifier = arrows.right(0.15, antiaimbot.manual_antiaim.state == antiaimbot.manual_antiaim.MANUAL_RIGHT or antiaimbot.manual_antiaim.state == antiaimbot.manual_antiaim.MANUAL_BACK)
                        local base_position_right = vector(screen_center.x + manual_offset, screen_center.y + 1)

                        if manual_style == 'Triangles' then
                            renderer.triangle(
                                base_position_right.x + manual_size, base_position_right.y,
                                base_position_right.x, base_position_right.y - manual_size * 0.5,
                                base_position_right.x, base_position_right.y + manual_size * 0.5,
                                manual_color_bg.r, manual_color_bg.g, manual_color_bg.b, manual_color_bg.a * main
                            )

                            renderer.triangle(
                                base_position_right.x + manual_size, base_position_right.y,
                                base_position_right.x, base_position_right.y - manual_size * 0.5,
                                base_position_right.x, base_position_right.y + manual_size * 0.5,
                                manual_color.r, manual_color.g, manual_color.b, 255 * right_modifier * main
                            )
                        elseif manual_style == 'Symbols #1' then
                            renderer.text(base_position_right.x, base_position_right.y-4, manual_color_bg.r, manual_color_bg.g, manual_color_bg.b, manual_color_bg.a * main, 'cb+', 0, '›')
                            renderer.text(base_position_right.x, base_position_right.y-4, manual_color.r, manual_color.g, manual_color.b, 255 * right_modifier * main, 'cb+', 0, '›')
                        elseif manual_style == 'Symbols #2' then
                            renderer.text(base_position_right.x, base_position_right.y-2, manual_color_bg.r, manual_color_bg.g, manual_color_bg.b, manual_color_bg.a * main, 'cb', 0, '⯈')
                            renderer.text(base_position_right.x, base_position_right.y-2, manual_color.r, manual_color.g, manual_color.b, 255 * right_modifier * main, 'cb', 0, '⯈')
                        elseif manual_style == 'Symbols #3' then
                            renderer.texture(arrow_svg3, base_position_right.x-arrow_weight/2+2, base_position_right.y-arrow_height/2+1, arrow_weight, arrow_height, manual_color_bg.r, manual_color_bg.g, manual_color_bg.b, manual_color_bg.a * main, 'f')
                            renderer.texture(arrow_svg3, base_position_right.x-arrow_weight/2+1, base_position_right.y-arrow_height/2, arrow_weight, arrow_height, manual_color.r, manual_color.g, manual_color.b, 255 * right_modifier * main, 'f')
                        end

                    end
                end)
            end

            visuals.draw_manual_arrows = (function (self)
                self.manual_arrows.draw()
            end)

            visuals.draw_forced_watermark = (function ()
                screen_size = vector(client.screen_size())
                screen_center = screen_size * 0.5

                if user.debug then
                    local str = inspect(antiaimbot.main.debug):gsub('\t', ('\x20'):rep(4))

                    renderer.text(50, screen_size.y / 4 + 100, 255, 255, 255, 255, '', 0, str)
                end

                if config.visuals.indicators:get() then
                    return
                end

                renderer.text(screen_center.x, screen_size.y - 20, 255, 255, 255, 255, 'c', 0, 'specter.lua')
            end)

            function visuals:player_hurt(event)
                if not player.alive then
                    return
                end

                self.markers.receive(event)
            end

            function visuals:paint()
                self:draw_indicators()
                self:draw_r8_indicator()
                self:draw_manual_arrows()
                self:draw_markers()

                if config.visuals.scan_antiaim:get() then
                    local threat = client.current_threat()
                    if threat and entity.is_alive(threat) and aa_stealer and aa_stealer:is_scanning(threat) then
                        local screen_size = vector(client.screen_size())
                        local x, y = screen_size.x / 2, screen_size.y / 2 + 150
                        local r, g, b, a = config.visuals.scan_antiaim_color:get()
                        local rows, ready = aa_stealer:progress(threat)

                        renderer.text(x, y - 20, r, g, b, a, 'c', 0, "SCANNING: " .. string.upper(entity_get_player_name(threat) or "?"))
                        for i, row in ipairs(rows) do
                            local oy = (i - 1) * 12
                            renderer.text(x - 70, y + oy, 255, 255, 255, a, '', 0, string.upper(row.label))
                            renderer.rectangle(x - 10, y + oy + 2, 100, 6, 20, 20, 20, math_floor(a * 0.5))
                            renderer.rectangle(x - 10, y + oy + 2, row.percent, 6, r, g, b, a)
                            renderer.text(x + 95, y + oy, 255, 255, 255, a, '', 0, row.percent .. "%")
                        end
                        renderer.text(x, y + #rows * 12 + 6, 255, 255, 255, a, 'c', 0,
                            ready > 0 and string_format("READY: %d/%d STANCES", ready, #rows) or "WAITING...")
                    end

                end

            end

            -- the crosshair indicator color: the picker, or the sweep between the two pickers ("Gradient color")
            function visuals.indicator_rgb()
                local r, g, b, a = config.visuals.indicator_color:get()
                if not (config.visuals.indicator_gradient and config.visuals.indicator_gradient:get()) then return r, g, b, a end
                local r2, g2, b2, a2 = config.visuals.indicator_color2:get()
                local t = 0.5 + 0.5 * math.sin(globals.realtime() * (config.visuals.indicator_gradient_speed:get() or 6) * 0.4)
                return math_floor(r + (r2 - r) * t), math_floor(g + (g2 - g) * t), math_floor(b + (b2 - b) * t), math_floor(a + (a2 - a) * t)
            end

            function visuals.rounded(x, y, w, h, rad, r, g, b, a)
                if a <= 0 or w <= 0 or h <= 0 then return end
                rad = math_max(0, math_min(rad, math_floor(h / 2), math_floor(w / 2)))
                if a < 32 and rad > 0 then
                    renderer.rectangle(x + rad, y, w - rad * 2, h, r, g, b, a)
                    renderer.rectangle(x, y + rad, rad, h - rad * 2, r, g, b, a)
                    renderer.rectangle(x + w - rad, y + rad, rad, h - rad * 2, r, g, b, a)
                    return
                end
                renderer.rectangle(x + rad, y, w - rad * 2, h, r, g, b, a)
                if rad > 0 then
                    renderer.rectangle(x, y + rad, rad, h - rad * 2, r, g, b, a)
                    renderer.rectangle(x + w - rad, y + rad, rad, h - rad * 2, r, g, b, a)
                    renderer.circle(x + rad, y + rad, r, g, b, a, rad, 180, 0.25)
                    renderer.circle(x + w - rad, y + rad, r, g, b, a, rad, 90, 0.25)
                    renderer.circle(x + rad, y + h - rad, r, g, b, a, rad, 270, 0.25)
                    renderer.circle(x + w - rad, y + h - rad, r, g, b, a, rad, 0, 0.25)
                end
            end

            function visuals.over_menu(mx, my)
                if not ui_is_menu_open() then return false end
                local ok, px, py = pcall(ui.menu_position)
                local ok2, pw, ph = pcall(ui.menu_size)
                if not ok or not ok2 or not px or not pw then return false end
                return mx >= px and mx <= px + pw and my >= py and my <= py + ph
            end

            function visuals.drag_update(st, bx, by, bw, bh)
                local mx, my = ui.mouse_position()
                local down = client.key_state(0x01)
                local pressed = down and not st.was_down
                st.was_down = down
                if not down then
                    st.drag = false
                    return nil
                end
                if pressed and not st.drag and mx >= bx and mx <= bx + bw and my >= by and my <= by + bh and not visuals.over_menu(mx, my) then
                    st.drag, st.ox, st.oy = true, mx - bx, my - by
                end
                if st.drag then return mx - st.ox, my - st.oy end
                return nil
            end

            visuals.hitlog_kinds = {
                hit   = { "HIT",      "Hits" },
                head  = { "HEADSHOT", "Headshots" },
                kill  = { "KILL",     "Kills" },
                miss  = { "MISS",     "Misses" },
                burn  = { "BURN",     "Utility" },
                nade  = { "NADE",     "Utility" },
                knife = { "KNIFE",    "Utility" },
                evade = { "EVADED",   "Evaded" },
            }

            function visuals.hitlog_color(kind)
                local item = config.visuals.hitlog_colors and config.visuals.hitlog_colors[kind]
                if item then
                    local r, g, b = item:get()
                    if r then return r, g, b end
                end
                return config.visuals.watermark_color:get()
            end

            function visuals.draw_icon(icon, cx, cy, r, g, b, a)
                local br, bg, bb = 15, 15, 20
                if icon == "head" then
                    renderer.circle_outline(cx, cy, r, g, b, a, 5, 0, 1, 1)
                    renderer.circle(cx, cy, r, g, b, a, 1.5, 0, 1)
                    renderer.rectangle(cx - 8, cy, 3, 1, r, g, b, a)
                    renderer.rectangle(cx + 6, cy, 3, 1, r, g, b, a)
                    renderer.rectangle(cx, cy - 8, 1, 3, r, g, b, a)
                    renderer.rectangle(cx, cy + 6, 1, 3, r, g, b, a)
                elseif icon == "kill" then
                    renderer.circle(cx, cy - 1, r, g, b, a, 5, 0, 1)
                    renderer.rectangle(cx - 3, cy + 2, 7, 4, r, g, b, a)
                    renderer.rectangle(cx - 3, cy - 2, 2, 2, br, bg, bb, a)
                    renderer.rectangle(cx + 2, cy - 2, 2, 2, br, bg, bb, a)
                    renderer.rectangle(cx - 1, cy + 4, 1, 2, br, bg, bb, a)
                    renderer.rectangle(cx + 1, cy + 4, 1, 2, br, bg, bb, a)
                elseif icon == "hit" then
                    renderer.circle(cx, cy - 4, r, g, b, a, 2.5, 0, 1)
                    visuals.rounded(cx - 4, cy - 1, 9, 7, 3, r, g, b, a)
                elseif icon == "miss" then
                    for o = 0, 1 do
                        renderer.line(cx - 4 + o, cy - 4, cx + 4 + o, cy + 4, r, g, b, a)
                        renderer.line(cx + 4 + o, cy - 4, cx - 4 + o, cy + 4, r, g, b, a)
                    end
                elseif icon == "burn" then
                    renderer.triangle(cx, cy - 7, cx - 5, cy + 2, cx + 5, cy + 2, r, g, b, a)
                    renderer.circle(cx, cy + 2, r, g, b, a, 5, 0, 1)
                    renderer.triangle(cx, cy - 1, cx - 2.5, cy + 3, cx + 2.5, cy + 3, 255, 235, 160, a)
                    renderer.circle(cx, cy + 3, 255, 235, 160, a, 2.5, 0, 1)
                elseif icon == "nade" then
                    renderer.circle(cx, cy + 2, r, g, b, a, 5, 0, 1)
                    renderer.rectangle(cx - 2, cy - 6, 4, 3, r, g, b, a)
                    renderer.circle_outline(cx + 4, cy - 5, r, g, b, a, 2, 0, 1, 1)
                elseif icon == "evade" then
                    -- a bullet line passing an outlined head
                    renderer.circle_outline(cx + 2, cy, r, g, b, a, 4, 0, 1, 1)
                    renderer.line(cx - 8, cy - 6, cx + 8, cy - 6, r, g, b, a)
                    renderer.line(cx + 5, cy - 8, cx + 8, cy - 6, r, g, b, a)
                    renderer.line(cx + 5, cy - 4, cx + 8, cy - 6, r, g, b, a)
                elseif icon == "knife" then
                    renderer.triangle(cx - 5, cy + 1, cx + 7, cy - 6, cx + 7, cy + 1, r, g, b, a)
                    renderer.rectangle(cx - 8, cy + 1, 8, 3, r, g, b, a)
                end
            end

            function visuals.hitlog_preview()
                if visuals.hl_preview then return visuals.hl_preview end
                local W, D = { 240, 240, 245 }, { 135, 135, 146 }
                local function seg(t, c, f) return { t, c[1], c[2], c[3], f or "" } end
                local function sep() return { "  \194\183  ", 85, 85, 96, "" } end
                local function mk(kind, label, icon, name, detail, meta, short)
                    local segs = { seg(name, W, "b"), sep() }
                    for _, d in ipairs(detail) do segs[#segs + 1] = d end
                    return { kind = kind, label = label, icon = icon, segs = segs, meta = meta, short = short,
                        time = 0, alpha = 1, slide = 1, preview = true }
                end
                local function col(kind, t, f)
                    local r, g, b = visuals.hitlog_color(kind)
                    return { t, r, g, b, f or "" }
                end
                visuals.hl_preview = {
                    mk("knife", "KNIFE", "knife", "enemy", { col("knife", "65", "b"), seg(" dmg", D) }, nil, "-65"),
                    mk("nade", "NADE", "nade", "enemy", { col("nade", "42", "b"), seg(" dmg", D) }, nil, "-42"),
                    mk("burn", "BURN", "burn", "enemy", { col("burn", "8", "b"), seg(" dmg", D) }, nil, "-8"),
                    mk("evade", "EVADED", "evade", "enemy", { seg("missed you by", D), seg(" 11", W, "b"), seg(" u", D) }, "head", "evaded"),
                    mk("miss", "MISS", "miss", "enemy", { seg("head", D), sep(), col("miss", "resolver") }, "hc 78%   jitter 58\194\176", "resolver"),
                    mk("hit", "HIT", "hit", "enemy", { seg("stomach", D), sep(), col("hit", "54", "b"), seg(" dmg", D), sep(), seg("46 hp", W) }, "hc 92%   db 1", "-54"),
                    mk("head", "HEADSHOT", "head", "enemy", { seg("head", D), sep(), col("head", "92", "b"), seg(" dmg", D), sep(), seg("8 hp", W) }, "hc 88%   freestand 57\194\176", "-92"),
                    mk("kill", "HS KILL", "kill", "enemy", { seg("head", D), sep(), col("kill", "297", "b"), seg(" dmg", D) }, "hc 100%   bt 4t   jitter -29\194\176", "dead"),
                }
                return visuals.hl_preview
            end

            visuals.hl_drag = {}
            visuals.hl_box = { w = 260, h = 90 }

            function visuals:draw_hitlog()
                if not config.visuals.hitlog:get() then return end
                local menu_open = ui_is_menu_open()
                local list, preview = hitlog_data, false
                if #list == 0 then
                    if not menu_open then return end
                    list, preview = visuals.hitlog_preview(), true
                else
                    visuals.hl_preview = nil
                end

                local rounded = visuals.rounded
                local sw, sh = client.screen_size()
                local now, ft = globals.realtime(), globals_frametime()
                local LIFE = config.visuals.hitlog_duration:get()
                hitlog_data.max = config.visuals.hitlog_max:get()
                local style = config.visuals.hitlog_style:get()
                local show = config.visuals.hitlog_show:get() or {}
                local H = ({ Compact = 20, Stacked = 40, Crosshair = 13, Killfeed = 22 })[style] or 26
                local GAP = ({ Minimal = 3, Crosshair = 1, Killfeed = 3 })[style] or 5
                local crosshair = style == "Crosshair"
                local pulse = 0.75 + 0.25 * math.sin(now * 2.4)

                local ax = config.visuals.hitlog_x:get() / 1000 * sw
                local ay = config.visuals.hitlog_y:get() / 1000 * sh
                if crosshair then
                    ax, ay = sw / 2, sh / 2 + 42
                elseif menu_open then
                    local bw, bh = visuals.hl_box.w + 16, math_max(visuals.hl_box.h, H) + 12
                    local nx, ny = visuals.drag_update(visuals.hl_drag, ax - bw / 2, ay - 6, bw, bh)
                    if nx then
                        ax = c_math.clamp(nx + bw / 2, 20, sw - 20)
                        ay = c_math.clamp(ny + 6, 10, sh - 40)
                        config.visuals.hitlog_x:set(math_floor(ax / sw * 1000 + 0.5))
                        config.visuals.hitlog_y:set(math_floor(ay / sh * 1000 + 0.5))
                    end
                end
                ax, ay = math_floor(ax), math_floor(ay)

                local offset, max_w = 0, 0
                for i = #list, 1, -1 do
                    local e = list[i]
                    local info = visuals.hitlog_kinds[e.kind] or { "INFO", "Hits" }
                    local visible = #show == 0 or c_table.contains(show, info[2])
                    local age = preview and (((now * 0.2) + i * 0.137) % 1) * LIFE or (now - e.time)
                    local alive = age < LIFE

                    if not preview then
                        e.alpha = e.alpha + ((alive and 1 or 0) - e.alpha) * math_min(1, ft * (alive and 12 or 7))
                        e.slide = e.slide + (1 - e.slide) * math_min(1, ft * 10)
                    end

                    if not preview and not alive and e.alpha < 0.02 then
                        table_remove(list, i)
                    elseif visible then
                        local label = e.label or info[1]
                        local r, g, b = visuals.hitlog_color(e.kind)
                        local a = e.alpha

                        if e.cache_style ~= style then
                            e.cache_style = style
                            e.lw, e.lh = renderer.measure_text("b", label)
                            e.th = 0
                            e.sw = 0
                            for _, s in ipairs(e.segs or {}) do
                                local w_, h_ = renderer.measure_text(s[5], s[1])
                                s.w = w_
                                e.th = math_max(e.th, h_)
                                e.sw = e.sw + w_
                            end
                            e.mw = e.meta and renderer.measure_text("", e.meta) or 0
                            local name = e.segs and e.segs[1] and e.segs[1][1] or ""
                            e.name_w = renderer.measure_text("b", name)
                            e.short_w = renderer.measure_text("b", e.short or "")
                            local segs_ = e.segs or {}
                            e.rest_w = e.sw - ((segs_[1] and segs_[1].w or 0) + (segs_[2] and segs_[2].w or 0))
                            e.lw_small = renderer.measure_text("-", string.upper(label))
                            if style == "Compact" then
                                e.w = 8 + 16 + 6 + e.name_w + 8 + e.short_w + 10
                            elseif style == "Glass" then
                                e.w = 2 + 10 + 16 + 8 + e.lw + 10 + e.sw + (e.meta and (15 + e.mw) or 0) + 12
                            elseif style == "Neon" then
                                e.w = 12 + 16 + 8 + e.lw + 12 + e.sw + (e.meta and (15 + e.mw) or 0) + 12
                            elseif style == "Stacked" then
                                e.big_w = renderer.measure_text("b", e.short or "")
                                e.l1_w = e.lw_small + 8 + e.name_w
                                e.l2_w = e.rest_w + (e.meta and (12 + e.mw) or 0)
                                e.w = 46 + math_max(e.l1_w, e.l2_w) + 18 + e.big_w + 14
                            elseif style == "Crosshair" then
                                e.w = e.lw_small + 6 + e.name_w + 6 + e.short_w
                            elseif style == "Killfeed" then
                                e.w = 8 + 16 + 6 + e.name_w + 8 + e.lw_small + 8 + e.short_w + 8
                            elseif style == "Minimal" then
                                e.w = 20 + e.lw + 10 + e.sw + (e.meta and (14 + e.mw) or 0)
                            else
                                e.w = 8 + 20 + 8 + e.lw + 12 + e.sw + (e.meta and (15 + e.mw) or 0) + 10
                            end
                        end

                        e.oy = e.oy and (e.oy + (offset - e.oy) * math_min(1, ft * 14)) or offset
                        local w = e.w
                        max_w = math_max(max_w, w)
                        local x = ax - math_floor(w / 2) + math_floor((1 - e.slide) * 36)
                        local y = ay + math_floor(e.oy + 0.5)
                        local cy = y + math_floor(H / 2)
                        local ty = y + math_floor((H - 1 - (e.th > 0 and e.th or e.lh)) / 2)
                        local life = c_math.clamp(1 - age / LIFE, 0, 1)

                        if style == "Cards" then
                            for k = 1, 3 do
                                rounded(x - k, y - k + 2, w + k * 2, H + k * 2, 7 + k, 0, 0, 0, (4 - k) * 12 * a)
                            end
                            rounded(x - 1, y - 1, w + 2, H + 2, 8, r, g, b, 22 * a)
                            rounded(x, y, w, H, 7, 15, 15, 20, 242 * a)
                            renderer.gradient(x + 7, y + 1, w - 14, 1, 255, 255, 255, 14 * a, 255, 255, 255, 0, true)
                            renderer.circle(x + 18, cy, r, g, b, 34 * a, 10, 0, 1)
                            visuals.draw_icon(e.icon or e.kind, x + 18, cy, r, g, b, 255 * a)
                            local cx = x + 36
                            renderer.text(cx, y + math_floor((H - 1 - e.lh) / 2), r, g, b, 255 * a, "b", 0, label)
                            cx = cx + e.lw + 12
                            for _, sg in ipairs(e.segs or {}) do
                                renderer.text(cx, ty, sg[2], sg[3], sg[4], 255 * a, sg[5], 0, sg[1])
                                cx = cx + sg.w
                            end
                            if e.meta then
                                cx = cx + 7
                                renderer.rectangle(cx, y + 7, 1, H - 14, 255, 255, 255, 26 * a)
                                cx = cx + 8
                                renderer.text(cx, ty, 128, 128, 140, 255 * a, "", 0, e.meta)
                            end
                            local bw = math_floor((w - 14) * life)
                            if bw > 0 then
                                renderer.gradient(x + 7, y + H - 2, bw, 2, r, g, b, 220 * a, r, g, b, 50 * a, true)
                            end
                        elseif style == "Glass" then
                            rounded(x, y, w, H, 5, 18, 18, 26, 150 * a)
                            renderer.gradient(x, y, math_min(w, 90), H, r, g, b, 60 * a, r, g, b, 0, true)
                            renderer.gradient(x + 5, y, w - 10, 1, 255, 255, 255, 45 * a, 255, 255, 255, 6 * a, true)
                            renderer.rectangle(x, y + 4, 2, H - 8, r, g, b, 255 * a)
                            visuals.draw_icon(e.icon or e.kind, x + 20, cy, r, g, b, 255 * a)
                            local cx = x + 36
                            renderer.text(cx, y + math_floor((H - 1 - e.lh) / 2), r, g, b, 255 * a, "b", 0, label)
                            cx = cx + e.lw + 10
                            for _, sg in ipairs(e.segs or {}) do
                                renderer.text(cx, ty, sg[2], sg[3], sg[4], 255 * a, sg[5], 0, sg[1])
                                cx = cx + sg.w
                            end
                            if e.meta then
                                renderer.text(cx + 15, ty, 160, 160, 172, 230 * a, "", 0, e.meta)
                            end
                            renderer.rectangle(x + 5, y + H - 1, math_floor((w - 10) * life), 1, 255, 255, 255, 70 * a)
                        elseif style == "Neon" then
                            local rad = math_floor(H / 2)
                            for k = 1, 3 do
                                rounded(x - k * 2, y - k * 2, w + k * 4, H + k * 4, rad + k * 2, r, g, b, (4 - k) * 7 * pulse * a)
                            end
                            rounded(x - 1, y - 1, w + 2, H + 2, rad + 1, r, g, b, 200 * a)
                            rounded(x, y, w, H, rad, 8, 8, 12, 245 * a)
                            visuals.draw_icon(e.icon or e.kind, x + 20, cy, r, g, b, 255 * a)
                            local cx = x + 36
                            renderer.text(cx, y + math_floor((H - 1 - e.lh) / 2), r, g, b, 255 * a, "b", 0, label)
                            cx = cx + e.lw + 12
                            for _, sg in ipairs(e.segs or {}) do
                                renderer.text(cx, ty, sg[2], sg[3], sg[4], 255 * a, sg[5], 0, sg[1])
                                cx = cx + sg.w
                            end
                            if e.meta then
                                renderer.text(cx + 15, ty, 150, 150, 165, 230 * a, "", 0, e.meta)
                            end
                            local bw = math_floor((w - rad * 2) * life)
                            if bw > 0 then
                                renderer.gradient(x + rad, y + H - 1, bw, 1, r, g, b, 255 * a, 255, 255, 255, 200 * a, true)
                            end
                        elseif style == "Stacked" then
                            -- soft shadow
                            for k = 1, 2 do
                                rounded(x - k * 2, y - k * 2 + 3, w + k * 4, H + k * 4, 8 + k * 2, 0, 0, 0, (3 - k) * 16 * a)
                            end
                            rounded(x, y, w, H, 8, 13, 13, 18, 244 * a)
                            -- accent wash from the right, where the damage number sits
                            renderer.gradient(x + w - 110, y + 1, 102, H - 2, r, g, b, 0, r, g, b, 26 * a, true)
                            renderer.gradient(x + 8, y, w - 16, 1, 255, 255, 255, 18 * a, 255, 255, 255, 0, true)
                            -- icon tile
                            rounded(x + 6, y + 6, 28, 28, 7, r, g, b, 40 * a)
                            rounded(x + 6, y + 6, 28, 2, 1, r, g, b, 150 * a)
                            visuals.draw_icon(e.icon or e.kind, x + 20, y + 20, r, g, b, 255 * a)
                            -- line 1: TYPE  name
                            local name = e.segs and e.segs[1] and e.segs[1][1] or ""
                            local up = string.upper(label)
                            renderer.text(x + 46, y + 8, r, g, b, 255 * a, "-", 0, up)
                            renderer.text(x + 46 + e.lw_small + 8, y + 5, 242, 242, 247, 255 * a, "b", 0, name)
                            -- line 2: details + meta
                            local cx, l2 = x + 46, y + 21
                            for i2, sg in ipairs(e.segs or {}) do
                                if i2 > 2 then
                                    renderer.text(cx, l2, sg[2], sg[3], sg[4], 235 * a, sg[5], 0, sg[1])
                                    cx = cx + sg.w
                                end
                            end
                            if e.meta then
                                renderer.text(cx + 12, l2, 118, 118, 132, 255 * a, "", 0, e.meta)
                            end
                            -- big damage / result on the right
                            local bx = x + w - 14 - e.big_w
                            renderer.rectangle(bx - 10, y + 9, 1, H - 18, 255, 255, 255, 22 * a)
                            renderer.text(bx + 1, y + math_floor((H - e.lh) / 2) + 1, 0, 0, 0, 150 * a, "b", 0, e.short or "")
                            renderer.text(bx, y + math_floor((H - e.lh) / 2), r, g, b, 255 * a, "b", 0, e.short or "")
                            -- lifetime bar
                            local lw_ = math_floor((w - 16) * life)
                            if lw_ > 0 then
                                renderer.gradient(x + 8, y + H - 2, lw_, 2, r, g, b, 230 * a, r, g, b, 60 * a, true)
                            end
                        elseif style == "Crosshair" then
                            local name = e.segs and e.segs[1] and e.segs[1][1] or ""
                            local cx = x
                            local up = string.upper(label)
                            renderer.text(cx + 1, y + 1, 0, 0, 0, 200 * a, "-", 0, up)
                            renderer.text(cx, y, r, g, b, 255 * a, "-", 0, up)
                            cx = cx + e.lw_small + 6
                            renderer.text(cx + 1, y, 0, 0, 0, 200 * a, "", 0, name)
                            renderer.text(cx, y - 1, 235, 235, 240, 255 * a, "", 0, name)
                            cx = cx + e.name_w + 6
                            renderer.text(cx + 1, y, 0, 0, 0, 200 * a, "b", 0, e.short or "")
                            renderer.text(cx, y - 1, r, g, b, 255 * a, "b", 0, e.short or "")
                        elseif style == "Killfeed" then
                            local red = e.kind == "kill"
                            renderer.rectangle(x, y, w, H, 0, 0, 0, (red and 170 or 140) * a)
                            local br, bg_, bb = r, g, b
                            if red then br, bg_, bb = 230, 40, 40 end
                            renderer.rectangle(x, y, w, 1, br, bg_, bb, 255 * a)
                            renderer.rectangle(x, y + H - 1, w, 1, br, bg_, bb, 255 * a)
                            renderer.rectangle(x, y, 1, H, br, bg_, bb, 255 * a)
                            renderer.rectangle(x + w - 1, y, 1, H, br, bg_, bb, 255 * a)
                            visuals.draw_icon(e.icon or e.kind, x + 16, cy, r, g, b, 255 * a)
                            local name = e.segs and e.segs[1] and e.segs[1][1] or ""
                            local cx = x + 30
                            local nty = y + math_floor((H - 1 - e.lh) / 2)
                            renderer.text(cx, nty, 235, 235, 240, 255 * a, "b", 0, name)
                            cx = cx + e.name_w + 8
                            renderer.text(cx, y + math_floor((H - 8) / 2), r, g, b, 255 * a, "-", 0, string.upper(label))
                            cx = cx + e.lw_small + 8
                            renderer.text(cx, nty, r, g, b, 255 * a, "b", 0, e.short or "")
                        elseif style == "Minimal" then
                            visuals.draw_icon(e.icon or e.kind, x + 8, cy, r, g, b, 255 * a)
                            local cx = x + 20
                            renderer.text(cx + 1, y + math_floor((H - 1 - e.lh) / 2) + 1, 0, 0, 0, 160 * a, "b", 0, label)
                            renderer.text(cx, y + math_floor((H - 1 - e.lh) / 2), r, g, b, 255 * a, "b", 0, label)
                            cx = cx + e.lw + 10
                            for _, sg in ipairs(e.segs or {}) do
                                renderer.text(cx + 1, ty + 1, 0, 0, 0, 160 * a, sg[5], 0, sg[1])
                                renderer.text(cx, ty, sg[2], sg[3], sg[4], 255 * a, sg[5], 0, sg[1])
                                cx = cx + sg.w
                            end
                            if e.meta then
                                cx = cx + 14
                                renderer.text(cx, ty, 150, 150, 160, 220 * a, "", 0, e.meta)
                            end
                            renderer.gradient(x + 20, y + H - 3, math_floor((w - 20) * life), 1, r, g, b, 200 * a, r, g, b, 0, true)
                        else
                            rounded(x, y, w, H, math_floor(H / 2), 15, 15, 20, 235 * a)
                            rounded(x, y, w, H, math_floor(H / 2), r, g, b, 18 * a)
                            visuals.draw_icon(e.icon or e.kind, x + 16, cy, r, g, b, 255 * a)
                            local name = e.segs and e.segs[1] and e.segs[1][1] or ""
                            local nty = y + math_floor((H - 1 - e.lh) / 2)
                            renderer.text(x + 30, nty, 235, 235, 240, 255 * a, "b", 0, name)
                            renderer.text(x + 30 + e.name_w + 8, nty, r, g, b, 255 * a, "b", 0, e.short or label)
                        end

                        offset = offset + (H + GAP) * a
                    end
                end

                visuals.hl_box.w = math_max(120, max_w)
                visuals.hl_box.h = math_max(H, offset)

                if menu_open and not crosshair then
                    local ar, ag, ab = config.visuals.watermark_color:get()
                    local bw, bh = visuals.hl_box.w + 16, visuals.hl_box.h + 12
                    local bx, by = ax - math_floor(bw / 2), ay - 6
                    local da = visuals.hl_drag.drag and 200 or 90
                    for k = 0, bw, 8 do
                        renderer.rectangle(bx + k, by, math_min(4, bw - k), 1, ar, ag, ab, da)
                        renderer.rectangle(bx + k, by + bh, math_min(4, bw - k), 1, ar, ag, ab, da)
                    end
                    for k = 0, bh, 8 do
                        renderer.rectangle(bx, by + k, 1, math_min(4, bh - k), ar, ag, ab, da)
                        renderer.rectangle(bx + bw, by + k, 1, math_min(4, bh - k), ar, ag, ab, da)
                    end
                    renderer.text(ax, by - 12, ar, ag, ab, da + 40, "c", 0, preview and "hitlog preview - drag to move" or "drag to move")
                end
            end
            function visuals:paint_ui()
                self:draw_forced_watermark()
                self:draw_hitlog()
                if ui_is_menu_open() and config.visuals.indicators:get() and not player.alive then
                    local style = config.visuals.indicator_style:get()
                    if style == 'Specter' then
                        self.specter_style.draw(1, true)
                    else
                        local mod = self[string.lower(style or '')]
                        if mod and mod.draw then pcall(mod.draw, 1, 1) end
                    end
                end
            end
        end
    end

    ---
    --- Miscellaneous
    ---
    local miscellaneous do
        config.miscellaneous = {} do
            -- camera & effects: zoom animation, second zoom fov, viewmodel, bullet tracers
            local CM = {}
            config.camera = CM
            CM.hdr = mui.header(mui.SIDE, "◎", "Camera & effects")
            CM.anim_zoom = menu.new_item(ui.new_checkbox, "AA", "Other", "Animated zoom"):record("camera", "anim_zoom"):save()
            CM.anim_zoom_amount = menu.new_item(ui.new_slider, "AA", "Other", "•  Zoom in by\nanim_zoom", 0, 40, 15, true, "\194\176")
                :record("camera", "anim_zoom_amount"):save()
            CM.anim_zoom_speed = menu.new_item(ui.new_slider, "AA", "Other", "•  Speed\nanim_zoom", 1, 10, 5, true, "")
                :record("camera", "anim_zoom_speed"):save()
            CM.second_zoom = menu.new_item(ui.new_checkbox, "AA", "Other", "Second zoom FOV"):record("camera", "second_zoom"):save()
            CM.second_zoom_fov = menu.new_item(ui.new_slider, "AA", "Other", "•  FOV\nsecond_zoom", 1, 90, 30, true, "\194\176")
                :record("camera", "second_zoom_fov"):save()
            CM.viewmodel = menu.new_item(ui.new_checkbox, "AA", "Other", "Viewmodel"):record("camera", "viewmodel"):save()
            CM.vm_fov = menu.new_item(ui.new_slider, "AA", "Other", "•  FOV\nviewmodel", 54, 120, 68, true, "\194\176")
                :record("camera", "vm_fov"):save()
            CM.vm_x = menu.new_item(ui.new_slider, "AA", "Other", "•  X\nviewmodel", -100, 100, 25, true, "", 0.1)
                :record("camera", "vm_x"):save()
            CM.vm_y = menu.new_item(ui.new_slider, "AA", "Other", "•  Y\nviewmodel", -100, 100, 0, true, "", 0.1)
                :record("camera", "vm_y"):save()
            CM.vm_z = menu.new_item(ui.new_slider, "AA", "Other", "•  Z\nviewmodel", -100, 100, -15, true, "", 0.1)
                :record("camera", "vm_z"):save()
            CM.vm_knife_left = menu.new_item(ui.new_checkbox, "AA", "Other", "•  Knife in the other hand\nviewmodel")
                :record("camera", "vm_knife_left"):save()
            CM.tracers = menu.new_item(ui.new_checkbox, "AA", "Other", "Bullet tracers"):record("camera", "tracers"):save()
            CM.tracers_color = menu.new_item(ui.new_color_picker, "AA", "Other", "\ntracers_color", 149, 184, 6, 255)
                :record("camera", "tracers_color"):save()
            CM.tracers_style = menu.new_item(ui.new_combobox, "AA", "Other", "•  Style\ntracers", { "Line", "Beam", "Glow" })
                :record("camera", "tracers_style"):save()
            CM.tracers_time = menu.new_item(ui.new_slider, "AA", "Other", "•  Duration\ntracers", 1, 10, 3, true, "s")
                :record("camera", "tracers_time"):save()

            do
                local function gref(...) local ok, r = pcall(ui.reference, ...) return ok and r or nil end
                local ref_fov = gref("MISC", "Miscellaneous", "Override FOV")
                local ref_zoom = gref("MISC", "Miscellaneous", "Override zoom FOV")

                -- gamesense settings we change: the user's value is kept and given back
                local held = {}
                local function hold(r) if r and held[r] == nil then local ok, v = pcall(ui.get, r) if ok then held[r] = v end end end
                local function give(r) if r and held[r] ~= nil then pcall(ui.set, r, held[r]); held[r] = nil end end
                local function put(r, v) local ok, cur = pcall(ui.get, r) if ok and cur ~= v then pcall(ui.set, r, v) end end

                -- cvars of the viewmodel: the values before we touched them come back when it is switched off
                local cv_saved = {}
                local function cv(name) local ok, c = pcall(function() return cvar[name] end) return ok and c or nil end
                local function cv_set(name, v, is_int)
                    local c = cv(name)
                    if not c then return end
                    if cv_saved[name] == nil then
                        cv_saved[name] = { is_int and c:get_int() or c:get_float(), is_int }
                    end
                    local cur = is_int and c:get_int() or c:get_float()
                    if math.abs((cur or 0) - v) > 1e-3 then
                        if is_int then pcall(c.set_raw_int, c, v) else pcall(c.set_raw_float, c, v) end
                    end
                end
                local function cv_restore()
                    for name, sv in pairs(cv_saved) do
                        local c = cv(name)
                        if c then if sv[2] then pcall(c.set_raw_int, c, sv[1]) else pcall(c.set_raw_float, c, sv[1]) end end
                    end
                    cv_saved = {}
                end

                local zoom_cur
                local vm_next = 0
                local tracers = {}

                client.set_event_callback("paint", function()
                    local me = entity.get_local_player()
                    local alive = me and entity.is_alive(me)

                    -- animated zoom: the fov glides to (fov - amount) while scoped and back after
                    if CM.anim_zoom:get() and ref_fov and alive then
                        hold(ref_fov)
                        local base = tonumber(held[ref_fov]) or 90
                        local scoped = entity.get_prop(me, "m_bIsScoped") == 1
                        local target = scoped and (base - CM.anim_zoom_amount:get()) or base
                        zoom_cur = zoom_cur or base
                        local k = 1 - math.exp(-globals.frametime() * CM.anim_zoom_speed:get() * 4)
                        zoom_cur = zoom_cur + (target - zoom_cur) * k
                        if not scoped and math.abs(zoom_cur - base) < 0.3 then
                            give(ref_fov); zoom_cur = nil
                        else
                            put(ref_fov, math.floor(zoom_cur + 0.5))
                        end
                    else
                        give(ref_fov); zoom_cur = nil
                    end

                    -- second zoom: on the second zoom level of a sniper, the zoom fov of the slider
                    local wpn = alive and entity.get_player_weapon(me)
                    local zl = wpn and entity.get_prop(wpn, "m_zoomLevel") or 0
                    if CM.second_zoom:get() and ref_zoom and alive and zl >= 2 then
                        hold(ref_zoom)
                        put(ref_zoom, CM.second_zoom_fov:get())
                    else
                        give(ref_zoom)
                    end

                    -- viewmodel (cvars, 4x a second is plenty)
                    local now = globals.realtime()
                    if now >= vm_next or now < vm_next - 1 then
                        vm_next = now + 0.25
                        if CM.viewmodel:get() then
                            cv_set("viewmodel_fov", CM.vm_fov:get())
                            cv_set("viewmodel_offset_x", CM.vm_x:get() / 10)
                            cv_set("viewmodel_offset_y", CM.vm_y:get() / 10)
                            cv_set("viewmodel_offset_z", CM.vm_z:get() / 10)
                            local right = cv_saved.cl_righthand and cv_saved.cl_righthand[1] or (cv("cl_righthand") and cv("cl_righthand"):get_int() or 1)
                            local cls = wpn and entity.get_classname(wpn) or ""
                            local knife = cls:find("Knife", 1, true) ~= nil
                            cv_set("cl_righthand", (CM.vm_knife_left:get() and knife) and (1 - right) or right, true)
                        elseif next(cv_saved) then
                            cv_restore()
                        end
                    end

                    -- bullet tracers
                    if CM.tracers:get() and #tracers > 0 then
                        local r, g, b, a = CM.tracers_color:get()
                        local life = CM.tracers_time:get()
                        local style = CM.tracers_style:get()
                        for i = #tracers, 1, -1 do
                            local t = tracers[i]
                            local age = now - t.at
                            if age > life or age < 0 then
                                table.remove(tracers, i)
                            else
                                local x1, y1 = renderer.world_to_screen(t.sx, t.sy, t.sz)
                                local x2, y2 = renderer.world_to_screen(t.ex, t.ey, t.ez)
                                if x1 and x2 then
                                    local fade = (1 - age / life) * (a / 255)
                                    if style == "Glow" then
                                        for w = 3, 1, -1 do
                                            renderer.line(x1 + w, y1, x2 + w, y2, r, g, b, 40 * fade)
                                            renderer.line(x1 - w, y1, x2 - w, y2, r, g, b, 40 * fade)
                                        end
                                    elseif style == "Beam" then
                                        renderer.line(x1, y1 + 1, x2, y2 + 1, r, g, b, 120 * fade)
                                        renderer.line(x1, y1 - 1, x2, y2 - 1, r, g, b, 120 * fade)
                                    end
                                    renderer.line(x1, y1, x2, y2, r, g, b, 255 * fade)
                                end
                            end
                        end
                    end
                end)

                -- one tracer per shot: the last impact of the tick (the farthest the bullet got)
                client.set_event_callback("bullet_impact", function(e)
                    if not CM.tracers:get() then return end
                    local me = entity.get_local_player()
                    if not me or client.userid_to_entindex(e.userid) ~= me then return end
                    local sx, sy, sz = client.eye_position()
                    if not sx then return end
                    local tick = globals.tickcount()
                    local last = tracers[#tracers]
                    if last and last.tick == tick then
                        last.ex, last.ey, last.ez = e.x, e.y, e.z
                    else
                        tracers[#tracers + 1] = { tick = tick, at = globals.realtime(), sx = sx, sy = sy, sz = sz, ex = e.x, ey = e.y, ez = e.z }
                        while #tracers > 32 do table.remove(tracers, 1) end
                    end
                end)

                client.set_event_callback("shutdown", function()
                    give(ref_fov); give(ref_zoom)
                    cv_restore()
                end)
            end

            config.miscellaneous.hdr_social = mui.header(mui.CONTENT, "☺", "Social & tweaks")
            config.miscellaneous.clantag = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Clan Tag")
                :record("miscellaneous", "clantag")
                :save()

            config.miscellaneous.clantag_style = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Style\nclantag", {"Scrolling", "Glitch"})
                :record("miscellaneous", "clantag_style")
                :save()

            config.miscellaneous.cheat_tweaks = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Cheat Tweaks")
                :record("miscellaneous", "cheat_tweaks")
                :save()

            config.miscellaneous.cheat_tweaks_list = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  List\ncheat_tweaks", {
                "Uncharge helper",
                "Super toss on grenade release",
                "Allow crouch on fakeduck"
            }):record("miscellaneous", "cheat_tweaks_list"):save()

            config.miscellaneous.automatic_tp = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Auto Teleport")
                :record("miscellaneous", "automatic_tp")
                :save()

            config.miscellaneous.automatic_tp_weapons = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Weapons\nautomatic_tp", {
                "Auto",
                "Scout",
                "AWP",
                "Pistols",
                "Taser",
                "Knife"
            }):record("miscellaneous", "automatic_tp_weapons"):save()

            -- off: no teleport while our crosshair is on the threat (the double tap is kept for the shot)
            config.miscellaneous.automatic_tp_cross = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "•  Allow on crosshair\nautomatic_tp")
                :record("miscellaneous", "automatic_tp_cross"):save()
            config.miscellaneous.automatic_tp_delay = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Delay\nautomatic_tp", 1, 6, 2, true, "t", 1)
                :record("miscellaneous", "automatic_tp_delay")
                :save()

            config.miscellaneous.trashtalk = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Trash Talk")
                :record("miscellaneous", "trashtalk")
                :save()

            config.miscellaneous.killsay = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Kill Say")
                :record("miscellaneous", "killsay")
                :save()

            config.miscellaneous.sponsor_killsay = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Sponsor Kill Say")
                :record("miscellaneous", "sponsor_killsay")
                :save()

            config.miscellaneous.custom_output = menu.new_item(ui.new_checkbox, "AA", "Other", "Custom Output")
                :record("miscellaneous", "custom_output")
                :save()

            config.miscellaneous.event_logger = menu.new_item(ui.new_checkbox, "AA", "Other", "Event Logger")
                :record("miscellaneous", "event_logger")
                :save()

            config.miscellaneous.console_colors = menu.new_item(ui.new_checkbox, "AA", "Other", "•  Colored\nevent_logger")
                :record("miscellaneous", "console_colors"):save()
            pcall(function() config.miscellaneous.console_colors:set(true) end)


            config.miscellaneous.hdr_utility = mui.header(mui.CONTENT, "⚙", "Utility")
            config.miscellaneous.console_filter = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Console Filter")
                :record("miscellaneous", "console_filter")
                :save()

            config.miscellaneous.aspect_mode = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "Aspect Ratio", {
                "Off", "4:3", "5:4", "16:10", "16:9", "21:9", "Custom"
            }):record("miscellaneous", "aspect_mode"):save()
            config.miscellaneous.aspect_ratio = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Custom\naspect", 50, 250, 133, true, "", 0.01)
                :record("miscellaneous", "aspect_custom"):save()
            config.miscellaneous.thirdperson_dist = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "Thirdperson Distance", 0, 250, 150, true, "px")
                :record("miscellaneous", "thirdperson_dist"):save()

            do
                local ratios = { ["4:3"] = 4 / 3, ["5:4"] = 5 / 4, ["16:10"] = 16 / 10, ["16:9"] = 16 / 9, ["21:9"] = 21 / 9 }
                local applied_ratio, applied_dist
                client.set_event_callback("paint_ui", function()
                    local mode = config.miscellaneous.aspect_mode:get()
                    local ratio = 0
                    if mode == "Custom" then
                        ratio = (config.miscellaneous.aspect_ratio:get() or 133) / 100
                    elseif ratios[mode] then
                        ratio = ratios[mode]
                    end
                    if ratio ~= applied_ratio then
                        client.set_cvar("r_aspectratio", ratio)
                        applied_ratio = ratio
                    end

                    local dist = config.miscellaneous.thirdperson_dist:get()
                    if dist and dist ~= applied_dist then
                        client.set_cvar("cam_idealdist", dist)
                        applied_dist = dist
                    end
                end)
            end

            config.miscellaneous.autobuy = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Buy Bot")
                :record("miscellaneous", "autobuy"):save()
            config.miscellaneous.autobuy_primary = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Primary\nbuybot", {"Off", "Autosniper", "AWP", "Scout", "AK-47", "M4A4", "M4A1-S", "Galil AR", "FAMAS", "SG 553", "AUG"})
                :record("miscellaneous", "autobuy_primary"):save()
            config.miscellaneous.autobuy_secondary = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "•  Secondary\nbuybot", {"Off", "Heavy Pistol", "Dual Berettas", "P250", "Five-SeveN", "Tec-9", "CZ75-Auto"})
                :record("miscellaneous", "autobuy_secondary"):save()
            config.miscellaneous.autobuy_utility = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Utility\nbuybot", {"Kevlar", "Kevlar + Helmet", "Defuse Kit", "Grenade", "Smoke", "Flashbang", "Molotov", "Incendiary", "Decoy", "Zeus"})
                :record("miscellaneous", "autobuy_utility"):save()

            config.miscellaneous.anti_zeus = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Anti-Zeus / Knife")
                :record("miscellaneous", "anti_zeus"):save()
            -- FPS booster: engine settings that cost frames and give nothing in HvH (restored when switched off / unloaded)
            config.miscellaneous.fps_boost = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "FPS Booster")
                :record("miscellaneous", "fps_boost"):save()
            config.miscellaneous.fps_boost_list = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "•  Optimizations\nfps_boost", {
                "Disable dynamic lighting", "Disable shadows", "Disable ragdolls", "Multi-core rendering", "Disable bloom",
                "Disable particles", "Reduce breakables", "Fix chams color"
            }):record("miscellaneous", "fps_boost_list"):save()
            pcall(function() config.miscellaneous.fps_boost_list:set({ "Disable dynamic lighting", "Disable shadows", "Disable ragdolls",
                "Multi-core rendering", "Disable bloom", "Reduce breakables" }) end)
            do
                local CVARS = {
                    ["Disable dynamic lighting"] = { { "r_dynamic", 0 } },
                    ["Disable shadows"] = { { "cl_csm_enabled", 0 }, { "r_shadows", 0 } },
                    ["Disable ragdolls"] = { { "cl_disable_ragdolls", 1 } },
                    ["Multi-core rendering"] = { { "mat_queue_mode", 2 } },
                    ["Disable bloom"] = { { "mat_disable_bloom", 1 } },
                    ["Disable particles"] = { { "r_drawparticles", 0 } },
                    ["Reduce breakables"] = { { "func_break_max_pieces", 0 } },
                    -- auto exposure changes how bright the chams look from spot to spot; locked, they keep their color
                    ["Fix chams color"] = { { "mat_autoexposure_min", 1, true }, { "mat_autoexposure_max", 1, true } },
                }
                local saved, next_check, is_float = {}, 0, {}
                local function cv(name) local ok, c = pcall(function() return cvar[name] end) return ok and c or nil end
                local function apply()
                    local want = {}
                    if config.miscellaneous.fps_boost:get() then
                        for _, opt in ipairs(config.miscellaneous.fps_boost_list:get() or {}) do
                            for _, pair in ipairs(CVARS[opt] or {}) do want[pair[1]] = pair[2]; is_float[pair[1]] = pair[3] or nil end
                        end
                    end
                    for name, value in pairs(want) do
                        local c = cv(name)
                        if c then
                            local fl = is_float[name]
                            local cur = fl and c:get_float() or c:get_int()
                            if saved[name] == nil then saved[name] = { cur, fl } end
                            if cur ~= value then
                                if fl then pcall(c.set_raw_float, c, value) else pcall(c.set_raw_int, c, value) end
                            end
                        end
                    end
                    for name, old in pairs(saved) do
                        if want[name] == nil then
                            local c = cv(name)
                            if c then
                                if old[2] then pcall(c.set_raw_float, c, old[1]) else pcall(c.set_raw_int, c, old[1]) end
                            end
                            saved[name] = nil
                        end
                    end
                end
                client.set_event_callback("paint_ui", function()
                    local now = globals.realtime()
                    if now < next_check and now > next_check - 2 then return end
                    next_check = now + 0.5
                    pcall(apply)
                end)
                client.set_event_callback("shutdown", function()
                    for name, old in pairs(saved) do
                        local c = cv(name)
                        if c then
                            if old[2] then pcall(c.set_raw_float, c, old[1]) else pcall(c.set_raw_int, c, old[1]) end
                        end
                    end
                end)
            end
            config.miscellaneous.anti_zeus_distance = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "•  Distance\nanti_zeus", 200, 900, 500, true, " units", 1)
                :record("miscellaneous", "anti_zeus_distance"):save()

            config.miscellaneous.jumpscout = menu.new_item(ui.new_checkbox, "AA", "Other", "Advanced Jumpscout")
                :record("miscellaneous", "jumpscout"):save()
            config.miscellaneous.jumpscout_autostop = menu.new_item(ui.new_checkbox, "AA", "Other", "•  Auto-stop\njumpscout")
                :record("miscellaneous", "jumpscout_autostop"):save()
            config.miscellaneous.jumpscout_autostop_key = menu.new_item(ui.new_hotkey, "AA", "Other", "•  Auto-stop key\njumpscout")
                :record("miscellaneous", "jumpscout_autostop_key"):save()
        end

        miscellaneous = {} do
            miscellaneous.clantag = {} do
                function miscellaneous.clantag.reset()
                    for i=1, 64 do
                        client.set_clan_tag('')
                    end
                end

                function miscellaneous.clantag.build_tag(text, style)
                    local temp = {}
                    local len = #text

                    if style == "Scrolling" then
                        for i = 1, 15 do temp[#temp+1] = text end

                        for i = 1, len do
                            temp[#temp+1] = text:sub(i, len)
                        end

                        temp[#temp+1] = ""

                        for i = len, 1, -1 do
                            temp[#temp+1] = text:sub(1, i)
                        end
                    else
                        local glitch_chars = {"1", "3", "4", "5", "7", "0", "Z", "E", "N", "I", "T", "H", ".", "T", "O", "P"}

                        for i = 1, 15 do temp[#temp+1] = text end

                        for i = 1, len do
                            local glitched = ""
                            for j = 1, len do
                                if j <= i then
                                    glitched = glitched .. glitch_chars[client.random_int(1, #glitch_chars)]
                                else
                                    glitched = glitched .. text:sub(j, j)
                                end
                            end
                            temp[#temp+1] = glitched
                        end

                        for i = 1, 5 do
                            local glitched = ""
                            for j = 1, len do
                                glitched = glitched .. glitch_chars[client.random_int(1, #glitch_chars)]
                            end
                            temp[#temp+1] = glitched
                        end

                        for i = len, 1, -1 do
                            local glitched = ""
                            for j = 1, len do
                                if j >= i then
                                    glitched = glitched .. text:sub(j, j)
                                else
                                    glitched = glitched .. glitch_chars[client.random_int(1, #glitch_chars)]
                                end
                            end
                            temp[#temp+1] = glitched
                        end
                    end

                    return temp
                end

                local text = 'specter'
                local cache = ''
                local last_style = nil
                local chars = {}
                local restored = false

                function miscellaneous.clantag:run()
                    if not config.miscellaneous.clantag:get() then
                        if not restored then
                            client.set_clan_tag('')

                            restored = true
                        end

                        return
                    end

                    restored = false

                    local current_style = config.miscellaneous.clantag_style:get()
                    if current_style ~= last_style then
                        chars = miscellaneous.clantag.build_tag(text, current_style)
                        last_style = current_style
                    end

                    local latency_out = client.latency()
                    local lock, game_rules = false, entity.get_game_rules()

                    if game_rules ~= nil then
                        local game_phase = entity_get_prop(game_rules, 'm_gamePhase')

                        lock = game_phase == 4 or game_phase == 5
                    end

                    local latency = c_math.round(latency_out / globals_tickinterval())
                    local predicted = globals_tickcount() + latency

                    local idx = c_math.round(predicted * 0.0625) % #chars + 1

                    local target_text = lock and string_format('%s\t', text) or chars[idx]

                    if target_text == cache then
                        return
                    end

                    client.set_clan_tag(target_text)

                    cache = target_text
                end
            end

            miscellaneous.tweaks = {} do
                miscellaneous.tweaks.dt_reset = false

                local single_fire = {40, 9, 64, 27, 29, 35}

                function miscellaneous.tweaks.uncharge_helper(me, wpn)
                    local tickbase_diff = entity_get_prop(me, 'm_nTickBase') - globals_tickcount()
                    local doubletap_active = c_table.is_hotkey_active(reference.ragebot.doubletap.enable) and not ui_get(reference.ragebot.fakeduck)

                    local wpn_info = csgo_weapons(wpn)

                    if not wpn_info then
                        return
                    end

                    local last_shot_time = entity_get_prop(wpn, 'm_fLastShotTime')

                    if not last_shot_time then
                        return
                    end

                    if not doubletap_active then
                        return
                    end

                    local single_fire_weapon = c_table.contains(single_fire, wpn_info.idx)
                    local value = single_fire_weapon and 1.50 or 0.50
                    local in_attack = globals_curtime() - last_shot_time <= value

                    if wpn_info.is_revolver then
                        local threat = client.current_threat()

                        if threat and not player:get_double_tap() and not player.onground and bit.band((entity.get_esp_data(threat) or {}).flags or 0, 2048) == 2048 then
                            override.set(reference.ragebot.enabled[2], 'On hotkey', 0x0)
                        else
                            override.set(reference.ragebot.enabled[2], 'Always on')
                        end
                    else
                        if tickbase_diff > 0 and not player:get_double_tap() then
                            if in_attack then
                                override.set(reference.ragebot.enabled[2], 'Always on')
                            else
                                override.set(reference.ragebot.enabled[2], 'On hotkey', 0x0)
                            end

                        else
                            override.set(reference.ragebot.enabled[2], 'Always on')
                        end
                    end

                    return true
                end

                miscellaneous.tweaks.st_reset = false

                function miscellaneous.tweaks.super_toss()
                    local grenade_release_held = c_table.is_hotkey_active(reference.misc.grenade_release)

                    if grenade_release_held then
                        override.set(reference.misc.grenade_toss, true)

                        miscellaneous.tweaks.st_reset = true
                    else
                        override.unset(reference.misc.grenade_toss)
                    end
                end

                miscellaneous.tweaks.fd_reset = false

                function miscellaneous.tweaks.fakeduck_helper(cmd)
                    local state = false

                    if cmd.in_duck == 1 then
                        if player.duckamount > 0.8 then
                            state = true
                        end
                    end

                    local active, mode = ui_get(reference.ragebot.fakeduck)

                    if active and state then
                        local mode_new = 'Off hotkey'

                        if mode == 2 or mode == 3 then
                            mode_new = 'On hotkey'
                        end

                        override.set(reference.ragebot.fakeduck, mode_new)
                        miscellaneous.tweaks.fd_reset = false
                    elseif not state then
                        if not miscellaneous.tweaks.fd_reset then
                            override.unset(reference.ragebot.fakeduck)
                            miscellaneous.tweaks.fd_reset = true
                        end
                    end
                end
            end

            miscellaneous.automatic_tp = {} do
                local weapon_index = {
                    ['Auto Snipers'] = { 38, 11 },
                    ['Pistols'] = { 4, 63, 36, 3, 1, 64, 2, 30, 61, 32 },
                    ['Scout'] = { 40 },
                    ['AWP'] = { 9 },
                    ['Taser'] = { 31 }
                }

                local delay = 0
                local time = 0
                local last_full = 0

                miscellaneous.automatic_tp.reset = false

                miscellaneous.automatic_tp.trace_thread = (function (me, threat)
                    local player_resource = entity.get_player_resource()

                    if not player_resource then
                        return false
                    end

                    local ping = entity_get_prop(player_resource, 'm_iPing', threat)
                    local ticks_to_extrapolate = math_max(5, toticks( ( ping * (ping <= 10 and 2 or 1.75) ) * 0.001 ))

                    local hitbox_position = vector(entity.hitbox_position(threat, 5))
                    local local_hitbox_position = vector(entity.hitbox_position(me, 4))

                    local entindex, damage = client.trace_bullet(threat, hitbox_position.x, hitbox_position.y, hitbox_position.z, c_math.extrapolate(me, local_hitbox_position, ticks_to_extrapolate):unpack())

                    return (damage and damage > 0 or false) and (entindex and entity.get_classname(entindex) ~= 'CWorld' or false)
                end)

                function miscellaneous.automatic_tp.run(me, wpn)
                    if player.onground or player.speed < 100 or not player:get_double_tap() then
                        return globals.realtime()-last_full < 0.4
                    end

                    local threat = client.current_threat()

                    if not threat or entity.is_dormant(threat) then
                        return
                    end

                    if not wpn then
                        return
                    end

                    local wpn_info = csgo_weapons(wpn)

                    if not wpn_info then
                        return
                    end

                    local active_weapon_id = wpn_info.idx

                    local should_run, found_knife = false, false

                    for _, weapon in ipairs(config.miscellaneous.automatic_tp_weapons:get()) do
                        local curr = weapon_index[weapon]

                        if curr then
                            for __, id in ipairs(curr) do
                                if id == active_weapon_id then
                                    should_run = true
                                    break
                                end
                            end
                        else
                            if weapon == 'Knife' then
                                found_knife = true
                            end
                        end
                    end

                    if not should_run and found_knife then
                        should_run = wpn_info.is_melee_weapon
                    end

                    if not should_run then
                        return
                    end

                    if not config.miscellaneous.automatic_tp_cross:get() then
                        local ex, ey, ez = client.eye_position()
                        local tx, ty, tz = entity_get_prop(threat, "m_vecOrigin")
                        local cp, cy = client.camera_angles()
                        if ex and tx and cp then
                            local dx, dy, dz = tx - ex, ty - ey, (tz + 56) - ez
                            local yaw = math.deg(math.atan2(dy, dx))
                            local pitch = -math.deg(math.atan2(dz, math.sqrt(dx * dx + dy * dy)))
                            if math_abs(c_math.normalize_yaw(yaw - cy)) < 5 and math_abs(pitch - cp) < 6 then return end
                        end
                    end

                    local should_teleport = miscellaneous.automatic_tp.trace_thread(me, threat)

                    if should_teleport and time < globals.realtime() then
                        if delay == config.miscellaneous.automatic_tp_delay:get() then
                            time = globals.realtime() + 0.5

                            override.set(reference.ragebot.doubletap.enable[2], 'On hotkey', 0x0)
                            miscellaneous.automatic_tp.reset = true

                            delay = 0
                        end

                        delay = delay + 1
                    elseif globals.realtime() - time > 0.5 and miscellaneous.automatic_tp.reset then
                        override.unset(reference.ragebot.doubletap.enable[2])

                        miscellaneous.automatic_tp.reset = false
                    end

                    last_full = globals.realtime()

                    return true
                end
            end

            miscellaneous.trashtalk = {} do
                local counter = 0
                local said = {}   -- per kill say list: how many of its lines went out

                local killsay_messages = {
                    '{name} got absolutely destroyed / sit down',
                    'gg {name} / maybe next time',
                    '{name} just got specter\'d / was that your best?',
                    'nice try {name} / but not good enough',
                    '{name} deleted / too easy',
                    'bye bye {name} / back to lobby',
                    '{name} thought he was good / LMFAO',
                    'where you going {name}? / oh wait you\'re dead',
                    '{name} = free kill / thanks for the frag',
                    'imagine dying that fast {name}',
                    '{name} just got sent to the shadow realm',
                    'sorry {name} / actually no i\'m not',
                    '{name} ragdolled beautifully / 10/10',
                    'nt {name} / jk that was terrible',
                    '{name} down / who\'s next?',
                    'get rekt {name} / specter on top',
                    '{name} caught a headshot / and a reality check',
                    'that was embarrassing {name} / just saying',
                    '1 tap on {name} / too clean',
                    '{name} uninstall maybe? / just a suggestion'
                }

                local DISCORD = 'discord.gg/dxM89UUnVN'
                local sponsor_messages = {
                    '{name} got tapped by Specter / sit down',
                    'imagine dying to Specter {name}',
                    'skill issue {name} / Specter said goodnight',
                    '1 {name} / sponsored by Specter - ' .. DISCORD,
                    '{name} is a free kill for Specter / thanks for the frag',
                    'L {name} / Specter on top',
                    'ratio + L + no Specter {name}',
                    '{name} spectating again / Specter keeps playing',
                    'was that a hvh or a Specter tutorial {name}?',
                    '{name} uninstall / or get Specter at ' .. DISCORD,
                    '{name} you just paid the Specter tax',
                    'owned by Specter / next',
                    'iq check failed {name} / Specter passed it',
                    'dont rage quit {name} / Specter is not done with you',
                    '{name} vs Specter / not even close'
                }

                local list = {
                    ['head'] = {
                        'headshot machine / cant miss',
                        '1 / sleep dog',
                        '1 / ahahahahahahahah',
                        'BAM / right in the head',
                        'L / sit down',
                        'u think im lucky?? / just Specter',
                        'too easy / next please',
                        'clean headshot / you felt that one'
                    },
                    ['body'] = {
                        'u mad? / i just broke lagcomp',
                        'FEEL THE SPECTER',
                        '? / what you do dog?',
                        'you read like a book / too easy for me',
                        'body shot and you still died / tragic'
                    },
                    ['taser'] = {
                        'zapped / get a better gaming chair',
                        'taser kill / how embarrassing',
                        'bzzzzt / you\'re done',
                        'yt bot'
                    },
                    ['inferno'] = {
                        'burned alive / unlucky',
                        'throw a smoke next time?',
                        'roasted',
                        'fire in the hole / and you were in it'
                    },
                    ['hegrenade'] = {
                        'boomed / catch that',
                        'nade kill lmfao',
                        'exploded like your chances of winning'
                    },
                    ['death'] = {
                        'lucky shot / wont happen again',
                        'only luck in this game',
                        'nice one / enjoy it while it lasts',
                        'ok that was weird / lag?',
                        'how / actually nvm'
                    },
                    ['revenge'] = {
                        '1. / thats what you get'
                    }
                }
                local active = false

                local attacker_index = -1

                function miscellaneous.trashtalk.run(type, victim_name)
                    if not config.miscellaneous.trashtalk:get() then
                        return
                    end

                    local game_rules = entity.get_game_rules()
                    local is_warmup = entity_get_prop(game_rules, 'm_bWarmupPeriod') == 1

                    if is_warmup then
                        return
                    end

                    local phrase_list = list[type]

                    if not phrase_list or active then
                        return
                    end

                    local delay = 0
                    local phrase = phrase_list[counter % #phrase_list + 1]

                    if victim_name then
                        phrase = phrase:gsub('{name}', victim_name)
                    end

                    local active_pool = c_string.split(phrase, ' / ')

                    active = true

                    for i=1, #active_pool do
                        local phrase_piece = active_pool[i]
                        local size = phrase_piece:len()
                        local new_delay = delay + size * 0.07

                        client.delay_call(new_delay, function ()
                            client.exec(string_format('say "%s";', phrase_piece))

                            if i == #active_pool then
                                active = false
                            end
                        end)

                        delay = new_delay
                    end

                    counter = counter + 1
                end

                -- the line goes to the console as  say "...";  so a name with a quote or a semicolon would end it and
                -- run the rest as a command (an enemy can pick that name); % would be a gsub capture
                function miscellaneous.trashtalk.run_killsay(messages, victim_name)
                    if active then return end

                    local game_rules = entity.get_game_rules()
                    local is_warmup = entity_get_prop(game_rules, 'm_bWarmupPeriod') == 1
                    if is_warmup then return end

                    local n = said[messages] or 0
                    said[messages] = n + 1

                    local name = (victim_name or ''):gsub('[%c";%%]', '')
                    if name == '' then name = 'noob' end
                    local phrase = messages[n % #messages + 1]:gsub('{name}', function () return name end)

                    local active_pool = c_string.split(phrase, ' / ')
                    active = true
                    local delay = 0

                    for i=1, #active_pool do
                        local phrase_piece = active_pool[i]
                        local size = phrase_piece:len()
                        local new_delay = delay + size * 0.07

                        client.delay_call(new_delay, function ()
                            client.exec(string_format('say "%s";', phrase_piece))
                            if i == #active_pool then
                                active = false
                            end
                        end)

                        delay = new_delay
                    end
                end

                function miscellaneous.trashtalk:on_kill(event)
                    local M = config.miscellaneous
                    local sponsor = M.sponsor_killsay:get()
                    local killsay = sponsor or M.killsay:get()
                    if not M.trashtalk:get() and not killsay then
                        return
                    end

                    local victim_ent = client.userid_to_entindex(event.userid)
                    local victim_name = victim_ent and entity.get_player_name(victim_ent) or nil

                    if killsay and victim_name then
                        self.run_killsay(sponsor and sponsor_messages or killsay_messages, victim_name)
                        return
                    end

                    if config.miscellaneous.trashtalk:get() then
                        if list[event.weapon] then
                            self.run(event.weapon, victim_name)
                        else
                            self.run(event.headshot and 'head' or 'body', victim_name)
                        end
                    end
                end

                function miscellaneous.trashtalk:on_death(event)
                    self.run('death')
                end

                function miscellaneous.trashtalk:on_player_death(event)
                    if event.userid == attacker_index then
                        self.run('revenge')
                        attacker_index = -1
                    end
                end
            end

            miscellaneous.custom_output = {} do
                local list = {}

                miscellaneous.custom_output.paint_ui = (function (ctx)
                    if #list == 0 then
                        return
                    end

                    local hs = select(2, surface.get_text_size(c_constant.fonts.lucida , 'A'))
                    local x, y, size = 8, 5, hs

                    for i=1, #list do
                        local notify = list[i]

                        if notify then
                            notify.m_time = notify.m_time - globals_frametime()

                            if notify.m_time <= 0.0 then
                                table_remove(list, i)
                            end
                        end
                    end

                    if #list == 0 then
                        return
                    end

                    while #list > 8 do
                        table_remove(list, 1)
                    end

                    for i=1, #list do
                        local notify = list[i]
                        local left = notify.m_time
                        local ncolor = notify.m_color

                        if left < 0.5 then
                            local fl = c_math.clamp(left, 0.0, 0.5)

                            ncolor.a = fl * 255.0

                            if i == 1 and fl < 0.2 then
                                y = y - size * (1.0 - fl * 5)
                            end
                        else
                            ncolor.a = 255
                        end

                        local txt = notify.m_text
                        local slist = color.string_to_color_array(string_format('\a%s%s', ncolor:to_hex(), txt))

                        local w_o = 0

                        for j=1, #slist do
                            local obj = slist[j]

                            obj.text = obj.text:gsub('\1', '')

                            local this_w = surface.get_text_size(c_constant.fonts.lucida, obj.text)

                            surface.draw_text(x + w_o, y, obj.color.r, obj.color.g, obj.color.b, ncolor.a, c_constant.fonts.lucida, obj.text)

                            w_o = w_o + this_w
                        end

                        y = y + size
                    end
                end)

                local skip_line

                function miscellaneous.custom_output.output(output)
                    local text_to_draw = output.text

                    local clr = color(output.r, output.g, output.b, output.a)

                    if text_to_draw:find('\0') then
                        text_to_draw = text_to_draw:sub(1, #text_to_draw-1)
                    end

                    if skip_line then
                        if list[#list] then
                            list[#list].m_text = string_format('%s%s', list[#list].m_text, string_format('\a%s%s', clr:to_hex(), text_to_draw))
                        else
                            list[#list+1] = {
                                m_text = text_to_draw,
                                m_color = clr,
                                m_time = 8.0
                            }
                        end

                        skip_line = false
                    else
                        for str in text_to_draw:gmatch('([^\n]+)') do
                            list[#list+1] = {
                                m_text = str,
                                m_color = clr,
                                m_time = 8.0
                            }
                        end
                    end

                    local has_ignore_newline = output.text:find('\0')

                    if has_ignore_newline ~= nil then
                        skip_line = true
                    end
                end
            end

            miscellaneous.event_logger = {} do
                local cache = {}
                local hitgroups = {
                    'body',
                    'head',
                    'chest',
                    'stomach',
                    'left arm',
                    'right arm',
                    'left leg',
                    'right leg',
                    'neck',
                    '?',
                    'gear'
                }

                local function seg(text, r, g, b, flags)
                    return { tostring(text), r, g, b, flags or "" }
                end

                local function dot()
                    return seg("  \194\183  ", 85, 85, 96)
                end

                -- player names can carry colour codes / control characters (they broke the line); short and clean
                local function clean_name(idx)
                    local n = tostring(entity_get_player_name(idx) or '?'):gsub('\a%x%x%x%x%x%x%x%x', ''):gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
                    if n == '' then n = '?' end
                    if #n > 20 then n = n:sub(1, 19) .. '.' end
                    return n
                end

                local function bt_text(cached)
                    return string_format('bt %dt', math_max(0, tonumber(cached.bt) or 0))
                end

                -- the resolver's part of the shot (only with "Show angle in hitlog" on): the angle its record got and what
                -- kind of record it was (desync / jitter); "(def)" = fired at a shifted model (defensive), the server tested
                -- it against that record
                local function res_text(shot)
                    local item = config.resolver and config.resolver.log
                    if not (item and item:get()) or not (shot and shot.value ~= nil) then return nil end
                    local kind = (shot.ctx or ''):sub(1, 1) == 'j' and 'jitter' or 'desync'
                    return string_format('res %d\194\176 %s%s', shot.value, kind, shot.defensive and ' (def)' or '')
                end

                local function shot_meta(event, cached)
                    return cached.res and (bt_text(cached) .. '   ' .. cached.res) or bt_text(cached)
                end

                -- the resolver ran first (miscellaneous:aim_fire): the log shows its backtrack and angle of the shot, and
                -- a "?" miss it does not count (lag comp, not the angle) is not called a resolver miss
                function miscellaneous.event_logger.aim_fire(event)
                    local shot = resolver.shots[event.id]
                    local this = {
                        tick = event.tick,
                        timestamp = client.timestamp(),
                        wanted_damage = event.damage,
                        wanted_hit_chance = event.hit_chance,
                        wanted_hitgroup = event.hitgroup,
                        bt = shot and shot.bt or resolver.shot_backtrack(event),
                        res = res_text(shot),
                        lagcomp = shot and (shot.defensive and 'defensive' or (shot.teleported and 'lag comp')) or nil,
                    }

                    cache[event.id] = this
                end

                local function console(parts)
                    local colored = config.miscellaneous.console_colors == nil or config.miscellaneous.console_colors:get()
                    if not colored then
                        local plain = {}
                        for i = 2, #parts do plain[#plain + 1] = parts[i][1] end
                        client.color_log(180, 160, 255, 'specter  \0')
                        client.color_log(255, 255, 255, table_concat(plain))
                        return
                    end
                    for i = 1, #parts do
                        local p = parts[i]
                        client.color_log(p[2], p[3], p[4], p[1] .. (i < #parts and "\0" or ""))
                    end
                end

                local function screen_on()
                    return config.visuals.hitlog and config.visuals.hitlog:get()
                end

                local GREY, WHITE, DIM = { 140, 140, 150 }, { 235, 235, 240 }, { 80, 80, 92 }
                local SEP = '  \194\183  '

                -- one console line:  specter  HIT    name  ·  aimed head  ›  chest  ·  87 dmg  ·  bt 4t
                local function line(label, kr, kg, kb, name, aimed, landed_label, landed, lr, lg, lb, dmg, cached)
                    local ar, ag, ab = config.visuals.watermark_color:get()
                    local parts = {
                        { 'specter  ', ar, ag, ab },
                        { label .. string.rep(' ', math_max(2, 12 - #label)), kr, kg, kb },
                        { name, WHITE[1], WHITE[2], WHITE[3] },
                        { SEP, DIM[1], DIM[2], DIM[3] },
                        { 'aimed ', GREY[1], GREY[2], GREY[3] },
                        { aimed, WHITE[1], WHITE[2], WHITE[3] },
                        { '  \226\128\186  ', DIM[1], DIM[2], DIM[3] },
                        { landed_label, GREY[1], GREY[2], GREY[3] },
                        { landed, lr, lg, lb },
                    }
                    if dmg then
                        parts[#parts + 1] = { SEP, DIM[1], DIM[2], DIM[3] }
                        parts[#parts + 1] = { tostring(dmg), kr, kg, kb }
                        parts[#parts + 1] = { ' dmg', GREY[1], GREY[2], GREY[3] }
                    end
                    parts[#parts + 1] = { SEP, DIM[1], DIM[2], DIM[3] }
                    parts[#parts + 1] = { bt_text(cached), WHITE[1], WHITE[2], WHITE[3] }
                    if cached.res then
                        parts[#parts + 1] = { SEP, DIM[1], DIM[2], DIM[3] }
                        parts[#parts + 1] = { cached.res, GREY[1], GREY[2], GREY[3] }
                    end
                    console(parts)
                end

                -- the same style for the other lines (nade / knife / burn, anti-brute, dormant shots):
                -- groups = { { {text, "w" | "g" | "k"}, ... }, ... }, a dot between the groups
                function c_logger.event(label, kr, kg, kb, groups)
                    local ar, ag, ab = config.visuals.watermark_color:get()
                    local parts = {
                        { 'specter  ', ar, ag, ab },
                        { label .. string.rep(' ', math_max(2, 12 - #label)), kr, kg, kb },
                    }
                    for gi, group in ipairs(groups) do
                        if gi > 1 then parts[#parts + 1] = { SEP, DIM[1], DIM[2], DIM[3] } end
                        for _, it in ipairs(group) do
                            local c = it[2] == 'k' and { kr, kg, kb } or (it[2] == 'g' and GREY or WHITE)
                            parts[#parts + 1] = { tostring(it[1]), c[1], c[2], c[3] }
                        end
                    end
                    console(parts)
                end

                function miscellaneous.event_logger.aim_hit(event)
                    local cached = cache[event.id]
                    cache[event.id] = nil

                    if not cached then
                        return
                    end

                    local name = clean_name(event.target)
                    local hitgroup = hitgroups[(tonumber(event.hitgroup) or 0) + 1] or '?'
                    local aimed = hitgroups[(tonumber(cached.wanted_hitgroup) or 0) + 1] or '?'
                    local damage = tonumber(event.damage) or 0
                    local health = math_max(0, tonumber(entity_get_prop(event.target, 'm_iHealth')) or 0)
                    local dead = health <= 0 or not entity.is_alive(event.target)
                    local head = event.hitgroup == 1

                    local kind = dead and 'kill' or (head and 'head' or 'hit')
                    local label = dead and (head and 'HS KILL' or 'KILL') or (head and 'HEADSHOT' or 'HIT')
                    local kr, kg, kb = visuals.hitlog_color(kind)

                    if config.miscellaneous.event_logger:get() then
                        line(label, kr, kg, kb, name, aimed, 'hit ', hitgroup, kr, kg, kb, damage, cached)
                    end

                    if screen_on() then
                        local segs = {
                            seg(name, WHITE[1], WHITE[2], WHITE[3], 'b'), dot(),
                            seg(aimed, GREY[1], GREY[2], GREY[3]),
                            seg(' \226\128\186 ', DIM[1], DIM[2], DIM[3]),
                            seg(hitgroup, kr, kg, kb, 'b'), dot(),
                            seg(damage, kr, kg, kb, 'b'),
                            seg(' dmg', GREY[1], GREY[2], GREY[3]),
                        }
                        add_hitlog({ kind = kind, label = label, icon = kind, segs = segs, meta = shot_meta(event, cached),
                            short = dead and 'dead' or ('-' .. damage) })
                    end
                end

                function miscellaneous.event_logger.aim_miss(event)
                    local cached = cache[event.id]
                    cache[event.id] = nil

                    if not cached then
                        return
                    end

                    local name = clean_name(event.target)
                    local aimed = hitgroups[(tonumber(cached.wanted_hitgroup) or tonumber(event.hitgroup) or 0) + 1] or '?'
                    local reason = tostring(event.reason or '?')
                    local shown_reason = (reason == '?' or reason == 'resolver') and (cached.lagcomp or 'resolver') or reason
                    local kr, kg, kb = visuals.hitlog_color('miss')

                    if config.miscellaneous.event_logger:get() then
                        line('MISS', kr, kg, kb, name, aimed, 'missed: ', shown_reason, kr, kg, kb, nil, cached)
                    end

                    if screen_on() then
                        add_hitlog({ kind = 'miss', label = 'MISS', icon = 'miss', meta = shot_meta(event, cached), short = shown_reason, segs = {
                            seg(name, WHITE[1], WHITE[2], WHITE[3], 'b'), dot(),
                            seg(aimed, GREY[1], GREY[2], GREY[3]), dot(),
                            seg(shown_reason, kr, kg, kb, 'b'),
                        } })
                    end
                end

                -- an enemy shot passed close to our head without hurting us (decided in the anti brute force module)
                antiaimbot.on_evaded = function(attacker, dist)
                    local name = entity_get_player_name(attacker) or '?'
                    local units = math_floor((dist or 0) + 0.5)
                    local kr, kg, kb = visuals.hitlog_color('evade')
                    if config.miscellaneous.event_logger:get() then
                        c_logger.event('EVADED', kr, kg, kb, {
                            { { clean_name(attacker), 'w' } },
                            { { 'missed you by ', 'g' }, { units, 'k' }, { ' u', 'g' } },
                        })
                    end
                    if screen_on() then
                        add_hitlog({ kind = 'evade', label = 'EVADED', icon = 'evade', short = 'evaded', segs = {
                            seg(name, WHITE[1], WHITE[2], WHITE[3], 'b'), dot(),
                            seg('missed you by ', GREY[1], GREY[2], GREY[3]),
                            seg(tostring(units), kr, kg, kb, 'b'),
                            seg(' u', GREY[1], GREY[2], GREY[3]),
                        } })
                    end
                end

                local hurt_weapons = {
                    ['knife'] = { 'knife', 'KNIFE', 'knifed' },
                    ['knife_t'] = { 'knife', 'KNIFE', 'knifed' },
                    ['bayonet'] = { 'knife', 'KNIFE', 'knifed' },
                    ['hegrenade'] = { 'nade', 'NADE', 'naded' },
                    ['inferno'] = { 'burn', 'BURN', 'burned' },
                    ['molotov'] = { 'burn', 'BURN', 'burned' },
                    ['incgrenade'] = { 'burn', 'BURN', 'burned' },
                }

                function miscellaneous.event_logger.player_hurt(event)
                    local attacker = client.userid_to_entindex(event.attacker)

                    if not attacker or attacker ~= entity_get_local_player() then
                        return
                    end

                    local target = client.userid_to_entindex(event.userid)

                    if not target then
                        return
                    end

                    local weapon = tostring(event.weapon or '')
                    local info = hurt_weapons[weapon]
                    if not info and weapon:find('knife', 1, true) then info = hurt_weapons['knife'] end

                    if not info then
                        return
                    end

                    local kind, label, verb = info[1], info[2], info[3]
                    local name = entity_get_player_name(target) or '?'
                    local damage = tonumber(event.dmg_health) or 0
                    local left = tonumber(event.health) or 0
                    local dead = left <= 0
                    if dead then label = label .. ' KILL' end
                    local kr, kg, kb = visuals.hitlog_color(kind)

                    if config.miscellaneous.event_logger:get() then
                        c_logger.event(dead and label or string.upper(verb), kr, kg, kb, {
                            { { clean_name(target), 'w' } },
                            { { damage, 'k' }, { ' dmg', 'g' } },
                        })
                    end

                    if screen_on() then
                        local segs = {
                            seg(name, WHITE[1], WHITE[2], WHITE[3], 'b'), dot(),
                            seg(damage, kr, kg, kb, 'b'),
                            seg(' dmg', GREY[1], GREY[2], GREY[3]),
                        }
                        if not dead then
                            segs[#segs + 1] = dot()
                            segs[#segs + 1] = seg(left .. ' hp', WHITE[1], WHITE[2], WHITE[3])
                        end
                        add_hitlog({ kind = kind, label = label, icon = kind, segs = segs, short = dead and 'dead' or ('-' .. damage) })
                    end
                end
            end
            function miscellaneous:setup_command(cmd, me, wpn)


                local cheat_tweaks = config.miscellaneous.cheat_tweaks:get()
                local tweak_list = config.miscellaneous.cheat_tweaks_list:get()

                if cheat_tweaks and c_table.contains(tweak_list, 'Uncharge helper') or player.air_exploit then
                    self.tweaks.dt_reset = true

                    if not self.tweaks.uncharge_helper(me, wpn) then
                        override.set(reference.ragebot.enabled[2], "Always on")
                    end
                elseif self.tweaks.dt_reset then
                    override.unset(reference.ragebot.enabled[2])
                    self.tweaks.dt_reset = false
                end

                if cheat_tweaks and c_table.contains(tweak_list, 'Allow crouch on fakeduck') then
                    self.tweaks.fakeduck_helper(cmd)
                else
                    if self.tweaks.fd_reset then
                        override.unset(reference.ragebot.fakeduck)
                        self.tweaks.fd_reset = false
                    end
                end

                if not player.air_exploit and not cheat_tweaks then
                    if self.tweaks.fd_reset then
                        override.unset(reference.ragebot.fakeduck)
                        self.tweaks.fd_reset = false
                    end
                end


                if config.miscellaneous.automatic_tp:get() then
                    if not self.automatic_tp.run(me, wpn) and self.automatic_tp.reset then
                        override.unset(reference.ragebot.doubletap.enable[2])
                        self.automatic_tp.reset = false
                    end
                elseif self.automatic_tp.reset then
                    override.unset(reference.ragebot.doubletap.enable[2])
                    self.automatic_tp.reset = false
                end

                if config.miscellaneous.anti_zeus:get() then
                    self.anti_melee(me, wpn)
                else
                    self.anti_melee_state.switched = false
                end
                if config.ragebot.dormant:get() then self.dormant_track(me) end
                if config.ragebot.dormant:get() and config.ragebot.dormant_key:get() and wpn then
                    self.dormant_aim(cmd, me, wpn)
                else
                    self.dormant_state.target = nil
                end

                if config.miscellaneous.jumpscout:get() and config.miscellaneous.jumpscout_autostop:get()
                    and config.miscellaneous.jumpscout_autostop_key:get() and wpn then
                    self.jumpscout_stop(cmd, me, wpn)
                end
            end

            miscellaneous.dormant_state = { target = nil, still_ticks = 0, last_shot = 0, info = {} }

            -- per enemy: the hitbox heights over the origin from the last time it was visible (crouched / standing), and
            -- while it is dormant the speed of its sound updates (where the next one will be)
            local DORMANT_BOXES = { Head = 0, Chest = 5, Stomach = 3 }
            local DORMANT_STAND = { Head = 64, Chest = 52, Stomach = 40 }
            local DORMANT_CROUCH = { Head = 46, Chest = 37, Stomach = 29 }
            function miscellaneous.dormant_track(me)
                local st = miscellaneous.dormant_state
                local tick = globals_tickcount()
                if tick % 2 == 1 then return end
                local now = globals.realtime()
                for enemy = 1, globals.maxplayers() do
                    if entity.get_classname(enemy) == "CCSPlayer" and entity.is_enemy(enemy) then
                        local d = st.info[enemy]
                        if not d then d = { anchor_tick = -1000 }; st.info[enemy] = d end
                        local ox, oy, oz = entity.get_origin(enemy)
                        if ox then
                            if not entity.is_dormant(enemy) then
                                -- visible: the real heights, every 16 ticks (a bone setup per hitbox)
                                if entity.is_alive(enemy) and (tick - d.anchor_tick >= 16 or tick < d.anchor_tick) then
                                    d.anchor_tick = tick
                                    local a = {}
                                    for name, hb in pairs(DORMANT_BOXES) do
                                        local _, _, hz = entity.hitbox_position(enemy, hb)
                                        if hz and hz - oz > 10 and hz - oz < 80 then a[name] = hz - oz end
                                    end
                                    d.anchor, d.anchor_t = a, now
                                end
                                d.vx, d.vy, d.last = nil, nil, nil
                            elseif not d.last or ox ~= d.last[1] or oy ~= d.last[2] then
                                -- dormant: a new sound position; its speed from the last one (a step every 0.1-0.6 s)
                                if d.last then
                                    local dt = now - d.last[4]
                                    if dt > 0.05 and dt < 0.7 then
                                        local vx, vy = (ox - d.last[1]) / dt, (oy - d.last[2]) / dt
                                        local sp = math_sqrt(vx * vx + vy * vy)
                                        if sp > 260 then vx, vy = vx * 260 / sp, vy * 260 / sp end
                                        d.vx = d.vx and d.vx * 0.5 + vx * 0.5 or vx
                                        d.vy = d.vy and d.vy * 0.5 + vy * 0.5 or vy
                                    else
                                        d.vx, d.vy = nil, nil
                                    end
                                end
                                d.last = { ox, oy, oz, now }
                            end
                        end
                    end
                end
            end

            -- the point to shoot at a dormant enemy: the last sound position moved on by its speed (up to 0.2 s, never into
            -- a wall), at the height of the hitbox
            local function dormant_point(me, enemy, d, box)
                local ox, oy, oz = entity.get_origin(enemy)
                if not ox then return nil end
                if d and d.vx and d.last then
                    local t = math.min(0.2, globals.realtime() - d.last[4] + (client.latency() or 0))
                    local px, py = ox + d.vx * t, oy + d.vy * t
                    local frac = client_trace_line(enemy, ox, oy, oz + 36, px, py, oz + 36)
                    frac = math.max(0, (tonumber(frac) or 1) - 0.05)
                    ox, oy = ox + (px - ox) * frac, oy + (py - oy) * frac
                end
                local h
                if d and d.anchor and d.anchor[box] and globals.realtime() - (d.anchor_t or 0) < 8 then
                    h = d.anchor[box]
                else
                    local duck = entity_get_prop(enemy, "m_flDuckAmount") or 0
                    h = DORMANT_STAND[box] + (DORMANT_CROUCH[box] - DORMANT_STAND[box]) * math.min(1, math.max(0, duck))
                end
                return ox, oy, oz + h
            end

            -- hit chance: the spread cone at that distance against the radius of the hitbox
            local DORMANT_RADIUS = { Head = 4.5, Chest = 7, Stomach = 6.5 }
            local function dormant_hc(me, wpn, info, dist, box)
                local pen = tonumber(entity_get_prop(wpn, "m_fAccuracyPenalty")) or 0
                local scoped = entity_get_prop(me, "m_bIsScoped") == 1
                local ducked = (entity_get_prop(me, "m_flDuckAmount") or 0) > 0.9
                local base
                if ducked then base = scoped and info.inaccuracy_crouch_alt or info.inaccuracy_crouch
                else base = scoped and info.inaccuracy_stand_alt or info.inaccuracy_stand end
                local spread = (scoped and info.spread_alt or info.spread) or 0
                local cone = math.max(1e-4, ((tonumber(base) or 0) + (tonumber(spread) or 0)) / 1000 + pen)
                local r = dist * math.tan(cone)
                return math.min(1, (DORMANT_RADIUS[box] / math.max(r, 1e-3)) ^ 2)
            end

            function miscellaneous.dormant_aim(cmd, me, wpn)
                local st = miscellaneous.dormant_state
                st.target = nil

                local info = csgo_weapons(wpn)
                if not info or info.is_melee_weapon or info.type == "grenade" or info.type == "c4" or info.type == "taser" then return end

                local curtime = globals_curtime()
                if (entity_get_prop(wpn, "m_flNextPrimaryAttack") or 0) > curtime or (entity_get_prop(me, "m_flNextAttack") or 0) > curtime then return end
                if (entity_get_prop(wpn, "m_iClip1") or 0) <= 0 then return end
                if globals.realtime() - st.last_shot < 0.25 then return end

                local flags = entity_get_prop(me, "m_fFlags") or 0
                if bit.band(flags, 1) == 0 then return end

                local visible_threat = client.current_threat()
                if visible_threat and entity.is_alive(visible_threat) and not entity.is_dormant(visible_threat) then
                    local hx, hy, hz = entity.hitbox_position(visible_threat, 5)
                    local ex, ey, ez = client.eye_position()
                    if hx and ex then
                        local fraction, hit = client_trace_line(me, ex, ey, ez, hx, hy, hz)
                        if hit == visible_threat or (fraction or 0) > 0.97 then return end
                    end
                end

                local ex, ey, ez = client.eye_position()
                if not ex then return end
                local min_dmg = config.ragebot.dormant_damage:get()
                local boxes = config.ragebot.dormant_hitboxes and config.ragebot.dormant_hitboxes:get() or {}
                if type(boxes) ~= "table" or #boxes == 0 then boxes = { "Chest", "Stomach" } end
                local best, best_score = nil, -1

                local tick = globals_tickcount()
                if st.scan_tick and tick - st.scan_tick < 4 and tick >= st.scan_tick then
                    best = st.scan_best
                    if best and not entity.is_dormant(best[4]) then best = nil end
                    goto scanned
                end

                for enemy = 1, globals.maxplayers() do
                    if entity.get_classname(enemy) == "CCSPlayer" and entity.is_enemy(enemy) and entity.is_dormant(enemy) then
                        local ok, _, _, _, _, alpha = pcall(entity.get_bounding_box, enemy)
                        local esp = entity.get_esp_data(enemy) or {}
                        local alive = (esp.health == nil) or (esp.health > 0)
                        local hp = tonumber(esp.health) or 100
                        if ok and (alpha or 0) > 0.1 and alive then
                            local d = st.info[enemy]
                            for _, box in ipairs(boxes) do
                                local px, py, pz
                                if DORMANT_STAND[box] then px, py, pz = dormant_point(me, enemy, d, box) end
                                if px then
                                    local ok2, _, dmg = pcall(client.trace_bullet, me, ex, ey, ez, px, py, pz, true)
                                    dmg = ok2 and tonumber(dmg) or 0
                                    -- a kill first, then the damage; a fresh position (alpha) counts a little
                                    local need = math.min(min_dmg, hp)
                                    if dmg >= need then
                                        local score = (dmg >= hp and 1000 or 0) + dmg + (alpha or 0) * 10
                                        if score > best_score then best, best_score = { px, py, pz, enemy, box, dmg }, score end
                                    end
                                end
                            end
                        end
                    end
                end
                st.scan_tick, st.scan_best = tick, best

                ::scanned::
                if not best then
                    st.still_ticks = 0
                    return
                end
                local best_dmg = best[6] or 0
                st.target = best[4]

                cmd.forwardmove, cmd.sidemove = 0, 0
                local vx, vy = entity_get_prop(me, "m_vecVelocity")
                local speed = math_sqrt((vx or 0) ^ 2 + (vy or 0) ^ 2)
                if speed > 20 then
                    local _, view_yaw = client.camera_angles()
                    local diff = math.rad(math.deg(math.atan2(vy, vx)) - (view_yaw or cmd.yaw))
                    cmd.forwardmove = -math.cos(diff) * 450
                    cmd.sidemove = math.sin(diff) * 450
                    st.still_ticks = 0
                    return
                end
                st.still_ticks = st.still_ticks + 1

                if info.type == "sniperrifle" and entity_get_prop(me, "m_bIsScoped") ~= 1 then
                    cmd.in_attack2 = 1
                    return
                end
                if st.still_ticks < 2 then return end

                local dx, dy, dz = best[1] - ex, best[2] - ey, best[3] - ez
                -- wait (stopped, aiming) until the gun is accurate enough for that hitbox at that distance
                local want_hc = (config.ragebot.dormant_hc and config.ragebot.dormant_hc:get() or 0) / 100
                if want_hc > 0 and dormant_hc(me, wpn, info, math_sqrt(dx * dx + dy * dy + dz * dz), best[5] or "Chest") < want_hc then
                    if st.still_ticks < 64 then return end
                end
                local pitch = -math.deg(math.atan2(dz, math_sqrt(dx * dx + dy * dy)))
                local yaw = math.deg(math.atan2(dy, dx))
                local punch_p, punch_y = entity_get_prop(me, "m_aimPunchAngle")
                cmd.pitch = pitch - (punch_p or 0) * 2
                cmd.yaw = yaw - (punch_y or 0) * 2
                cmd.in_attack = 1
                st.last_shot = globals.realtime()
                if c_logger.event then
                    local name = tostring(entity_get_player_name(best[4]) or "?"):gsub("\a%x%x%x%x%x%x%x%x", ""):gsub("%c", "")
                    c_logger.event("DORMANT", 120, 200, 255, {
                        { { name, "w" } }, { { "~" .. math_floor(best_dmg), "k" }, { " dmg through wall", "g" } },
                    })
                else
                    c_logger.log("dormant shot at %s (%d dmg through wall)", entity_get_player_name(best[4]) or "?", best_dmg)
                end
            end

            miscellaneous.anti_melee_state = { switched = false, last_exec = 0, clear_since = 0, return_slot = nil }

            function miscellaneous.anti_melee(me, wpn)
                local stt = miscellaneous.anti_melee_state
                local now = globals.realtime()
                local limit = config.miscellaneous.anti_zeus_distance:get()
                local mx, my, mz = entity.get_origin(me)
                local ex, ey, ez = client.eye_position()
                if not mx or not ex or not wpn then return end

                local threat = false
                for _, ent in ipairs(entity.get_players(true)) do
                    if entity.is_alive(ent) and not entity.is_dormant(ent) then
                        local ew = entity.get_player_weapon(ent)
                        local cls = ew and entity.get_classname(ew)
                        local info = ew and csgo_weapons(ew)
                        local is_zeus = cls == "CWeaponTaser"
                        local is_knife = not is_zeus and info ~= nil and info.is_melee_weapon
                        if is_zeus or is_knife then
                            local ox, oy, oz = entity.get_origin(ent)
                            local dx, dy, dz = ox - mx, oy - my, oz - mz
                            local flat = math_sqrt(dx * dx + dy * dy)
                            local reach = is_zeus and limit or math_min(limit, 300)
                            if math_abs(dz) < 90 and flat < reach then
                                local vx, vy = entity_get_prop(ent, "m_vecVelocity")
                                local closing = flat > 1 and (-(dx * (vx or 0) + dy * (vy or 0)) / flat) or 0
                                local close = flat < (is_zeus and 200 or 130)
                                if close or closing > 60 then
                                    local hx, hy, hz = entity.hitbox_position(ent, 5)
                                    if hx then
                                        local fraction, hit = client_trace_line(me, ex, ey, ez, hx, hy, hz)
                                        if hit == ent or (fraction or 0) > 0.97 then
                                            threat = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                local myinfo = csgo_weapons(wpn)
                local mytype = myinfo and myinfo.type or ""
                local my_cls = entity.get_classname(wpn)
                local weak_close = mytype == "sniperrifle" or mytype == "grenade" or mytype == "c4"
                    or (myinfo and myinfo.is_melee_weapon and my_cls ~= "CWeaponTaser")

                if threat then
                    stt.clear_since = 0
                    if weak_close and now - stt.last_exec > 0.6 then
                        client.exec("slot2")
                        stt.last_exec, stt.switched = now, true
                        stt.return_slot = mytype == "sniperrifle" and "slot1" or nil
                    end
                elseif stt.switched then
                    if stt.clear_since == 0 then stt.clear_since = now end
                    if now - stt.clear_since > 1.5 then
                        if stt.return_slot and mytype == "pistol" then client.exec(stt.return_slot) end
                        stt.switched, stt.return_slot, stt.clear_since = false, nil, 0
                    end
                end
            end

            function miscellaneous.jumpscout_visible_enemy(me)
                local ex, ey, ez = client.eye_position()
                if not ex then return nil end
                for _, enemy in ipairs(entity.get_players(true)) do
                    if entity.is_alive(enemy) and not entity.is_dormant(enemy) then
                        for _, hitbox in ipairs({ 0, 5, 2 }) do
                            local hx, hy, hz = entity.hitbox_position(enemy, hitbox)
                            if hx then
                                local fraction, hit = client_trace_line(me, ex, ey, ez, hx, hy, hz)
                                if hit == enemy or (fraction or 0) > 0.97 then
                                    return enemy
                                end
                            end
                        end
                    end
                end
                return nil
            end

            function miscellaneous.jumpscout_stop(cmd, me, wpn)
                local id = entity_get_prop(wpn, "m_iItemDefinitionIndex")
                if id ~= 40 then return end

                local flags = entity_get_prop(me, "m_fFlags") or 0
                if bit.band(flags, 1) == 1 then return end

                local curtime = globals_curtime()
                local ready = (entity_get_prop(wpn, "m_flNextPrimaryAttack") or 0) <= curtime
                    and (entity_get_prop(me, "m_flNextAttack") or 0) <= curtime
                if not ready then return end

                if not miscellaneous.jumpscout_visible_enemy(me) then return end

                local vx, vy = entity_get_prop(me, "m_vecVelocity")
                vx, vy = vx or 0, vy or 0
                local speed = math_sqrt(vx * vx + vy * vy)
                if speed < 10 then
                    cmd.forwardmove, cmd.sidemove = 0, 0
                    return
                end

                local _, view_yaw = client.camera_angles()
                local diff = math.rad(math.deg(math.atan2(vy, vx)) - (view_yaw or cmd.yaw))
                local power = math_min(450, speed * 4)
                cmd.forwardmove = -math.cos(diff) * power
                cmd.sidemove = math.sin(diff) * power
            end

            function miscellaneous:aim_fire(event)
                -- the resolver first: the hitlog keeps the angle it gave the shot
                resolver.on_fire(event)
                self.event_logger.aim_fire(event)
            end

            function miscellaneous:aim_hit(event)
                self.event_logger.aim_hit(event)
                resolver.on_hit(event)
            end

            function miscellaneous:aim_miss(event)
                self.event_logger.aim_miss(event)
                resolver.on_miss(event)
            end

            function miscellaneous:player_death(event)
                local attacker = client.userid_to_entindex(event.attacker)
                local userid = client.userid_to_entindex(event.userid)

                if not attacker or not userid then
                    return
                end

                resolver.reset_player(userid)
                plist.set(userid, "Force body yaw", false)
                plist.set(userid, "Force body yaw value", 0)

                if attacker == player.entindex then
                    if userid ~= player.entindex then
                        self.trashtalk:on_kill(event)
                    end
                elseif userid == player.entindex then
                    self.trashtalk:on_death(event)
                else
                    self.trashtalk:on_player_death(event)
                end
            end

            function miscellaneous:player_hurt(event)
                self.event_logger.player_hurt(event)
            end

            function miscellaneous:net_update_end()
                self.clantag:run()
            end

            function miscellaneous:paint_ui()
                local tweaks = config.miscellaneous.cheat_tweaks:get()
                local tweak_list = config.miscellaneous.cheat_tweaks_list:get()

                if tweaks and c_table.contains(tweak_list, 'Super toss on grenade release') then
                    self.tweaks.super_toss()
                elseif miscellaneous.tweaks.st_reset then
                    override.unset(reference.misc.grenade_toss)
                    miscellaneous.tweaks.st_reset = false
                end

                do
                    if not player.valid then
                        if tweaks and c_table.contains(tweak_list, 'Uncharge helper') then
                            self.tweaks.dt_reset = true
                            override.set(reference.ragebot.enabled[2], "Always on")
                        elseif self.tweaks.dt_reset then
                            override.unset(reference.ragebot.enabled[2])
                            self.tweaks.dt_reset = false
                        end
                    end
                end

                self.custom_output.paint_ui()
            end

            function miscellaneous.output_raw(output)
                miscellaneous.custom_output.output(output)
            end

            config.miscellaneous.custom_output:set_callback(function (element)
                local enabled = ui_get(element)

                if enabled and not miscellaneous._output_set then
                    client.set_event_callback('output', miscellaneous.output_raw)

                    miscellaneous._output_set = true
                elseif not enabled and miscellaneous._output_set then
                    client.unset_event_callback('output', miscellaneous.output_raw)

                    miscellaneous._output_set = false
                end

                if enabled then
                    override.set(reference.misc.draw_output, false)
                else
                    override.unset(reference.misc.draw_output)
                end
            end, true)

            config.miscellaneous.console_filter:set_callback(function (element)
                local enabled = ui_get(element)

                if enabled then
                    client.exec('clear;con_filter_enable 1;con_filter_text "specter";')
                else
                    client.exec('con_filter_enable 0;con_filter_text "";')
                end
            end, true)
        end
    end

    ---
    --- Settings
    ---
    local settings do
        config.presets = {} do
            config.presets.list = menu.new_item(ui.new_listbox, "AA", "Anti-aimbot angles", "\nloadouts_list", {})
                :config_ignore()
            config.presets.selected = mui.row(mui.CONTENT, "✎", "Selected", function()
                local name = config.presets.name and c_string.trim(tostring(config.presets.name:rawget() or "")) or ""
                local pick = config.presets.cloud_pick
                if pick and pick.name == name then return "☁ " .. name .. "  by " .. pick.author end
                return (name == "" or name:find("^No loadouts yet")) and "-" or name
            end)
            config.presets.name = menu.new_item(ui.new_textbox, "AA", "Other", "\nloadout_name")
                :config_ignore()
            config.presets.create = menu.new_item(ui.new_button, "AA", "Other", "Create\nloadout", function () end)
                :config_ignore()

            config.presets.load = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Load\nloadout", function () end)
                :config_ignore()
            config.presets.save = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Save\nloadout", function () end)
                :config_ignore()
            config.presets.remove = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Delete\nloadout", function () end)
                :config_ignore()
            config.presets.import = menu.new_item(ui.new_button, "AA", "Other", "Import\nloadout", function () end)
                :config_ignore()
            config.presets.export = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Export\nloadout", function () end)
                :config_ignore()
            -- cloud: the loadouts everyone shared are in the same list, "☁ name  by user"
            config.presets.share = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "☁ Share to cloud", function () end)
                :config_ignore()
            config.presets.refresh = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "☁ Refresh cloud", function () end)
                :config_ignore()
            config.presets.cloud_msg = "press Refresh cloud to see the shared loadouts"
            config.presets.cloud_status = mui.label(mui.CONTENT, function() return mui.D .. "      " .. config.presets.cloud_msg end)
        end

        config.settings = {} do
            config.settings.gap = mui.spacer(mui.CONTENT)
            config.settings.label = mui.header(mui.CONTENT, "⇅", "Full Config")
            config.settings.import = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Import from clipboard", function () end)
                :config_ignore()
            config.settings.export = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Export to clipboard", function () end)
                :config_ignore()
            config.settings.builtin = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Reset to defaults", function () end)
                :config_ignore()
            config.settings.default_aa = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Load default anti-aim", function () end)
                :config_ignore()
            config.settings.save = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Save now", function () end)
                :config_ignore()
            config.settings.autosave = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Auto-save")
                :record("global", "autosave"):save()
            pcall(function() config.settings.autosave:set(true) end)

            -- LUA tab or AA tab; stored outside the configs, applied on the next load
            config.settings.general_gap = mui.spacer(mui.CONTENT)
            config.settings.general = mui.header(mui.CONTENT, "⚙", "General")
            config.settings.location = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "Menu location", { "LUA tab", "AA tab (top)" })
                :config_ignore()
            pcall(config.settings.location.set, config.settings.location, menu.location == "AA" and "AA tab (top)" or "LUA tab")
            config.settings.location_hint = mui.hint(mui.CONTENT, "moves after reloading the script")
            config.settings.location:set_callback(function()
                local want = config.settings.location:get() == "AA tab (top)" and "AA" or "LUA"
                pcall(database.write, "specter_menu_location", want)
                if want ~= menu.location then
                    c_logger.log("Menu location set to the %s tab - reload the script to move it.", want)
                end
            end)
        end

        -- old configs could have backtrack optimization on in two places; keep one switch (Ragebot)
        config_system.migrate = function()
            if config.antiaimbot.backtrack_optimization:get() then
                pcall(config.ragebot.backtrack_optimization.set, config.ragebot.backtrack_optimization, true)
                pcall(config.antiaimbot.backtrack_optimization.set, config.antiaimbot.backtrack_optimization, false)
            end
        end

        settings = {} do
            function settings.import()
                local success, err = config_system.import_from_str(clipboard.get())

                if not success then
                    return c_logger.log_error('Failed to load config due to [%s]', err)
                end

                pcall(antiaimbot_builder.refresh)
                pcall(antiaimbot_builder.refresh_defensive)

                config_system:save_local(true)
                c_logger.log('Config loaded.')
            end

            function settings.save()
                config_system:save_local()
            end

            function settings.export()
                local config_text = config_system.export_to_str()

                clipboard.set(config_text)
                c_logger.log('Config exported.')
            end

            -- the recommended setup: what the simulations and the red team found best (Distort had the lowest hit rate of the
            -- best attacker), everything that only helps switched on. Applied by "Reset to defaults" and on the first start
            function settings.recommended()
                local function set(item, v) if item and item.set then pcall(item.set, item, v) end end
                local A, R, T, F, RS = config.antiaimbot, config.ragebot, config.tuning or {}, config.fakelag or {}, config.resolver or {}
                local NAV = config.navigation or {}

                -- resolver
                set(RS.enabled, true)
                set(RS.ping_scale, true)
                set(RS.ping_mode, "Auto")

                -- anti-aim
                set(NAV.aa_enable, true)
                set(A.preset, "Specter Distort")
                set(A.options, { "On use antiaim", "Fast ladder" })
                set(A.anti_brute, true)
                set(A.anti_brute_triggers, { "Hit", "Near miss" })
                set(A.anti_brute_indicator, true)
                set(A.safe_head, true)
                set(A.safe_head_conditions, { "Air knife", "Air zeus", "Air & Crouch", "Crouching" })
                set(A.warmup_aa, true)
                set(A.manual_yaw, true)
                set(A.manual_options, { "Jitter disabled" })
                set(A.fs_options, { "Jitter disabled" })
                set(A.freestanding_disabler_states, { "Air", "Air & Crouch" })
                set(A.animation_breaker, true)
                set(A.animation_breaker_leg, "Walking")
                set(A.animation_breaker_air, "Walking")
                set(A.animation_breaker_other, { "Quick peek legs", "Pitch zero on land" })

                -- defensive
                set(A.defensive_aa, true)
                set(A.force_target_yaw, true)
                set(A.defensive_target, { "Double tap", "On shot anti-aim" })
                set(A.defensive_conditions, { "Crouch moving", "Air", "Air & Crouch" })
                set(A.defensive_triggers, { "Flashed", "Damage received", "Reloading", "Weapon switch", "After shot", "On peek", "Landing", "Threat scoped" })
                set(A.defensive_preset, "Auto")
                set(A.defensive_conditions_auto, { "On peek", "Safe head", "Triggered", "Crouch moving", "Air", "Air & Crouch" })

                -- fake lag
                set(F.enable, true)
                set(F.type, "Adaptive")
                set(F.ticks, 14)
                set(F.variance, 30)
                set(F.triggers, { "Peek", "Air", "Damage received" })
                set(F.smart_lc, true)
                set(F.lc_on, { "In air", "On peek" })

                -- ragebot
                set(R.backtrack_optimization, true)
                set(R.backtrack_level, "Maximum")
                set(R.extended_bt, true)
                set(R.extended_bt_mode, "Only with target")
                set(R.extended_bt_amount, 200)
                set(R.adaptive_records, true)
                set(R.ping_reducer, { "Knife / grenade", "Freeze time" })
                set(R.multipoint, true)
                set(R.multipoint_auto, true)
                set(R.multipoint_hitboxes, { "Head", "Chest", "Stomach" })
                set(R.multipoint_scale, 60)
                set(R.safety, true)
                set(R.safety_on, { "Body aim after misses", "Safe point after misses", "Body aim on low HP", "Head when sure" })
                set(R.safety_misses, 2)
                set(R.safety_hp, 50)
                set(R.smart_baim, true)
                set(R.smart_conf, 70)
                set(R.lc_handling, { "Body aim", "No ping spike" })
                set(R.priority, { "Bomb carrier" })
                set(R.delay_invalid, true)
                set(R.delay_invalid_max, 150)
                set(R.dt_guard, true)
                set(R.dt_guard_on, { "Grenades", "Revolver", "Fake duck", "After misses" })
                set(R.dt_guard_misses, 3)

                -- tuning
                set(T.air, true)
                set(T.air_hc, 40)
                set(T.air_scale, 30)
                set(T.air_weapon, "All")
                set(T.ground, true)
                set(T.ground_min, 50)
                set(T.noscope, true)
                set(T.noscope_hc, 45)
                set(T.profiles, true)
                for g, w in pairs(T.wp or {}) do set(w.on, g == "AWP" or g == "Scout" or g == "Auto" or g == "Deagle") end
                set(T.peek, true)
                set(T.peek_hc, 12)
                set(T.peek_dmg, 5)
                set(T.peek_scope, true)
                set(T.peek_baim, false)
            end

            function settings.builtin()
                local success, err = config_system.import_from_str("eyJidWlsZGVyIjp7IkFBOjpTdGFuZGluZzo6Sml0dGVyVmFsdWUiOlswXSwiQUE6OlN0YW5kaW5nOjpZYXdCYXNlIjpbIkxvY2FsIHZpZXciXSwiQUE6OkFpciAmIENyb3VjaDo6WWF3U3dpdGNoRGVsYXlTZWNvbmQiOls2XSwiQUE6OkFpciAmIENyb3VjaDo6UGl0Y2hDdXN0b20iOlswXSwiQUE6Ok1vdmluZzo6UGl0Y2giOlsiT2ZmIl0sIkFBOjpGYWtlIGxhZzo6WWF3QmFzZSI6WyJMb2NhbCB2aWV3Il0sIkFBOjpDcm91Y2hpbmc6OkppdHRlclJhbmRvbWl6ZSI6WzBdLCJBQTo6U2xvdy1tb3Rpb246Ollhd0RlbGF5ZWRTd2l0Y2giOltmYWxzZV0sIkFBOjpBaXI6Ollhd0Jhc2UiOlsiTG9jYWwgdmlldyJdLCJBQTo6RmFrZSBsYWc6OkJvZHlWYWx1ZSI6WzBdLCJBQTo6U3RhbmRpbmc6OkVuYWJsZWQiOltmYWxzZV0sIkFBOjpGYWtlIGxhZzo6WWF3Sml0dGVyIjpbIk9mZiJdLCJBQTo6QWlyOjpZYXdTcGVlZCI6WzVdLCJBQTo6U3RhbmRpbmc6Ollhd1JpZ2h0IjpbMF0sIkFBOjpHbG9iYWw6Ollhd0N1c3RvbSI6WzBdLCJBQTo6U3RhbmRpbmc6OlBpdGNoIjpbIk9mZiJdLCJBQTo6U3RhbmRpbmc6Ollhd0RlbGF5ZWRTd2l0Y2giOltmYWxzZV0sIkFBOjpHbG9iYWw6Ollhd1N3aXRjaERlbGF5U2Vjb25kIjpbNl0sIkFBOjpDcm91Y2hpbmc6Ollhd0xlZnQiOlswXSwiQUE6OkNyb3VjaGluZzo6WWF3VHlwZSI6WyJPZmYiXSwiQUE6OkNyb3VjaCBtb3Zpbmc6OkppdHRlclZhbHVlIjpbMF0sIkFBOjpGYWtlIGxhZzo6Sml0dGVyVmFsdWUiOlswXSwiQUE6Ok1vdmluZzo6Qm9keVlhdyI6WyJPZmYiXSwiQUE6OkNyb3VjaCBtb3Zpbmc6Ollhd1NwZWVkIjpbNV0sIkFBOjpBaXI6Ollhd0RlbGF5ZWRTd2l0Y2giOltmYWxzZV0sIkFBOjpDcm91Y2ggbW92aW5nOjpCb2R5WWF3IjpbIk9mZiJdLCJBQTo6R2xvYmFsOjpZYXdKaXR0ZXIiOlsiT2ZmIl0sIkFBOjpBaXI6Ollhd0RlbGF5IjpbNV0sIkFBOjpDcm91Y2hpbmc6OkVuYWJsZWQiOltmYWxzZV0sIkFBOjpNb3Zpbmc6Ollhd0N1c3RvbSI6WzBdLCJBQTo6RmFrZSBsYWc6OlBpdGNoIjpbIk9mZiJdLCJBQTo6U3RhbmRpbmc6OkJvZHlZYXciOlsiT2ZmIl0sIkFBOjpGYWtlIGxhZzo6WWF3TGVmdCI6WzBdLCJBQTo6U2xvdy1tb3Rpb246Ollhd0N1c3RvbSI6WzBdLCJBQTo6RmFrZSBsYWc6Ollhd1JpZ2h0IjpbMF0sIkFBOjpBaXIgJiBDcm91Y2g6Ollhd1R5cGUiOlsiT2ZmIl0sIkFBOjpBaXI6OlBpdGNoQ3VzdG9tIjpbMF0sIkFBOjpDcm91Y2ggbW92aW5nOjpZYXdMZWZ0IjpbMF0sIkFBOjpDcm91Y2ggbW92aW5nOjpZYXdTd2l0Y2hEZWxheVNlY29uZCI6WzZdLCJBQTo6TW92aW5nOjpZYXdSaWdodCI6WzBdLCJBQTo6TW92aW5nOjpKaXR0ZXJWYWx1ZSI6WzBdLCJBQTo6QWlyOjpCb2R5WWF3IjpbIk9mZiJdLCJBQTo6U2xvdy1tb3Rpb246Ollhd0xlZnQiOlswXSwiQUE6OlNsb3ctbW90aW9uOjpZYXdEZWxheSI6WzVdLCJBQTo6QWlyOjpZYXdUeXBlIjpbIk9mZiJdLCJBQTo6U3RhbmRpbmc6Ollhd0ppdHRlciI6WyJPZmYiXSwiQUE6OlN0YW5kaW5nOjpZYXdEZWxheSI6WzVdLCJBQTo6QWlyOjpKaXR0ZXJWYWx1ZSI6WzBdLCJBQTo6QWlyICYgQ3JvdWNoOjpZYXdTcGVlZCI6WzVdLCJBQTo6QWlyOjpFbmFibGVkIjpbZmFsc2VdLCJBQTo6RmFrZSBsYWc6OkVuYWJsZWQiOltmYWxzZV0sIkFBOjpTdGFuZGluZzo6WWF3U3dpdGNoRGVsYXkiOls2XSwiQUE6OkZha2UgbGFnOjpCb2R5WWF3IjpbIk9mZiJdLCJBQTo6Q3JvdWNoaW5nOjpQaXRjaCI6WyJPZmYiXSwiQUE6OkNyb3VjaGluZzo6WWF3U3dpdGNoRGVsYXkiOls2XSwiQUE6OkFpciAmIENyb3VjaDo6Sml0dGVyUmFuZG9taXplIjpbMF0sIkFBOjpNb3Zpbmc6Ollhd1N3aXRjaERlbGF5IjpbNl0sIkFBOjpHbG9iYWw6Ollhd1N3aXRjaERlbGF5IjpbNl0sIkFBOjpDcm91Y2ggbW92aW5nOjpKaXR0ZXJSYW5kb21pemUiOlswXSwiQUE6OkNyb3VjaGluZzo6WWF3RGVsYXkiOls1XSwiQUE6OkNyb3VjaGluZzo6UGl0Y2hDdXN0b20iOlswXSwiQUE6OkNyb3VjaCBtb3Zpbmc6OlBpdGNoIjpbIk9mZiJdLCJBQTo6U2xvdy1tb3Rpb246Ollhd1NwZWVkIjpbNV0sIkFBOjpBaXIgJiBDcm91Y2g6Ollhd0N1c3RvbSI6WzBdLCJBQTo6U3RhbmRpbmc6Ollhd0xlZnQiOlswXSwiQUE6OlN0YW5kaW5nOjpCb2R5VmFsdWUiOlswXSwiQUE6Okdsb2JhbDo6Qm9keVZhbHVlIjpbMF0sIkFBOjpDcm91Y2hpbmc6Ollhd0Jhc2UiOlsiTG9jYWwgdmlldyJdLCJBQTo6U2xvdy1tb3Rpb246Ollhd0Jhc2UiOlsiTG9jYWwgdmlldyJdLCJBQTo6RmFrZSBsYWc6Ollhd0RlbGF5ZWRTd2l0Y2giOltmYWxzZV0sIkFBOjpTbG93LW1vdGlvbjo6Sml0dGVyVmFsdWUiOlswXSwiQUE6OkZha2UgbGFnOjpQaXRjaEN1c3RvbSI6WzBdLCJBQTo6Q3JvdWNoIG1vdmluZzo6WWF3UmlnaHQiOlswXSwiQUE6OkZha2UgbGFnOjpZYXdTd2l0Y2hEZWxheSI6WzZdLCJBQTo6RmFrZSBsYWc6Ollhd1R5cGUiOlsiT2ZmIl0sIkFBOjpDcm91Y2ggbW92aW5nOjpZYXdDdXN0b20iOlswXSwiQUE6OkFpciAmIENyb3VjaDo6Qm9keVZhbHVlIjpbMF0sIkFBOjpHbG9iYWw6OlBpdGNoIjpbIk9mZiJdLCJBQTo6QWlyICYgQ3JvdWNoOjpZYXdTd2l0Y2hEZWxheSI6WzZdLCJBQTo6R2xvYmFsOjpCb2R5WWF3IjpbIk9mZiJdLCJBQTo6TW92aW5nOjpZYXdEZWxheSI6WzVdLCJBQTo6Q3JvdWNoaW5nOjpCb2R5VmFsdWUiOlswXSwiQUE6OkNyb3VjaCBtb3Zpbmc6Ollhd0Jhc2UiOlsiTG9jYWwgdmlldyJdLCJBQTo6Q3JvdWNoIG1vdmluZzo6WWF3VHlwZSI6WyJPZmYiXSwiQUE6OlNsb3ctbW90aW9uOjpQaXRjaEN1c3RvbSI6WzBdLCJBQTo6U2xvdy1tb3Rpb246Ollhd1N3aXRjaERlbGF5U2Vjb25kIjpbNl0sIkFBOjpDcm91Y2ggbW92aW5nOjpZYXdEZWxheSI6WzVdLCJBQTo6Q3JvdWNoIG1vdmluZzo6WWF3U3dpdGNoRGVsYXkiOls2XSwiQUE6OkFpcjo6Sml0dGVyUmFuZG9taXplIjpbMF0sIkFBOjpBaXI6Ollhd1N3aXRjaERlbGF5U2Vjb25kIjpbNl0sIkFBOjpNb3Zpbmc6Ollhd0Jhc2UiOlsiTG9jYWwgdmlldyJdLCJBQTo6R2xvYmFsOjpQaXRjaEN1c3RvbSI6WzBdLCJBQTo6RmFrZSBsYWc6OkppdHRlclJhbmRvbWl6ZSI6WzBdLCJBQTo6Q3JvdWNoIG1vdmluZzo6Qm9keVZhbHVlIjpbMF0sIkFBOjpTbG93LW1vdGlvbjo6UGl0Y2giOlsiT2ZmIl0sIkFBOjpDcm91Y2hpbmc6Ollhd0N1c3RvbSI6WzBdLCJBQTo6U2xvdy1tb3Rpb246OkppdHRlclJhbmRvbWl6ZSI6WzBdLCJBQTo6R2xvYmFsOjpZYXdSaWdodCI6WzBdLCJBQTo6Q3JvdWNoaW5nOjpZYXdTcGVlZCI6WzVdLCJBQTo6TW92aW5nOjpFbmFibGVkIjpbZmFsc2VdLCJBQTo6U3RhbmRpbmc6Ollhd1NwZWVkIjpbNV0sIkFBOjpDcm91Y2hpbmc6OkppdHRlclZhbHVlIjpbMF0sIkFBOjpDcm91Y2ggbW92aW5nOjpZYXdKaXR0ZXIiOlsiT2ZmIl0sIkFBOjpBaXI6Ollhd0xlZnQiOlswXSwiQUE6OkFpciAmIENyb3VjaDo6WWF3RGVsYXkiOls1XSwiQUE6Okdsb2JhbDo6WWF3TGVmdCI6WzBdLCJBQTo6U3RhbmRpbmc6OkppdHRlclJhbmRvbWl6ZSI6WzBdLCJBQTo6U2xvdy1tb3Rpb246Ollhd0ppdHRlciI6WyJPZmYiXSwiQUE6Ok1vdmluZzo6WWF3U3BlZWQiOls1XSwiQUE6Okdsb2JhbDo6WWF3VHlwZSI6WyJPZmYiXSwiQUE6OkFpciAmIENyb3VjaDo6WWF3Sml0dGVyIjpbIk9mZiJdLCJBQTo6TW92aW5nOjpQaXRjaEN1c3RvbSI6WzBdLCJBQTo6U2xvdy1tb3Rpb246OkVuYWJsZWQiOltmYWxzZV0sIkFBOjpDcm91Y2hpbmc6Ollhd1N3aXRjaERlbGF5U2Vjb25kIjpbNl0sIkFBOjpGYWtlIGxhZzo6WWF3RGVsYXkiOls1XSwiQUE6Ok1vdmluZzo6WWF3TGVmdCI6WzBdLCJBQTo6Q3JvdWNoIG1vdmluZzo6RW5hYmxlZCI6W2ZhbHNlXSwiQUE6OkFpcjo6WWF3UmlnaHQiOlswXSwiQUE6OlNsb3ctbW90aW9uOjpCb2R5WWF3IjpbIk9mZiJdLCJBQTo6QWlyOjpQaXRjaCI6WyJPZmYiXSwiQUE6Ok1vdmluZzo6WWF3VHlwZSI6WyJPZmYiXSwiQUE6OlNsb3ctbW90aW9uOjpCb2R5VmFsdWUiOlswXSwiQUE6Ok1vdmluZzo6Qm9keVZhbHVlIjpbMF0sIkFBOjpTdGFuZGluZzo6WWF3U3dpdGNoRGVsYXlTZWNvbmQiOls2XSwiQUE6Ok1vdmluZzo6WWF3RGVsYXllZFN3aXRjaCI6W2ZhbHNlXSwiQUE6OkZha2UgbGFnOjpZYXdDdXN0b20iOlswXSwiQUE6Okdsb2JhbDo6WWF3RGVsYXllZFN3aXRjaCI6W2ZhbHNlXSwiQUE6OkZha2UgbGFnOjpZYXdTd2l0Y2hEZWxheVNlY29uZCI6WzZdLCJBQTo6QWlyICYgQ3JvdWNoOjpZYXdCYXNlIjpbIkxvY2FsIHZpZXciXSwiQUE6Ok1vdmluZzo6WWF3U3dpdGNoRGVsYXlTZWNvbmQiOls2XSwiQUE6OlN0YW5kaW5nOjpZYXdDdXN0b20iOlswXSwiQUE6OlN0YW5kaW5nOjpZYXdUeXBlIjpbIk9mZiJdLCJBQTo6U2xvdy1tb3Rpb246Ollhd1JpZ2h0IjpbMF0sIkFBOjpDcm91Y2hpbmc6Ollhd1JpZ2h0IjpbMF0sIkFBOjpHbG9iYWw6OkppdHRlclZhbHVlIjpbMF0sIkFBOjpTdGFuZGluZzo6UGl0Y2hDdXN0b20iOlswXSwiQUE6Ok1vdmluZzo6WWF3Sml0dGVyIjpbIk9mZiJdLCJBQTo6R2xvYmFsOjpZYXdCYXNlIjpbIkxvY2FsIHZpZXciXSwiQUE6OkNyb3VjaGluZzo6WWF3RGVsYXllZFN3aXRjaCI6W2ZhbHNlXSwiQUE6OlNsb3ctbW90aW9uOjpZYXdUeXBlIjpbIk9mZiJdLCJBQTo6QWlyICYgQ3JvdWNoOjpFbmFibGVkIjpbZmFsc2VdLCJBQTo6Q3JvdWNoIG1vdmluZzo6WWF3RGVsYXllZFN3aXRjaCI6W2ZhbHNlXSwiQUE6Okdsb2JhbDo6WWF3U3BlZWQiOls1XSwiQUE6OkFpciAmIENyb3VjaDo6WWF3RGVsYXllZFN3aXRjaCI6W2ZhbHNlXSwiQUE6OkFpciAmIENyb3VjaDo6Qm9keVlhdyI6WyJPZmYiXSwiQUE6Okdsb2JhbDo6WWF3RGVsYXkiOls1XSwiQUE6OkFpciAmIENyb3VjaDo6Sml0dGVyVmFsdWUiOlswXSwiQUE6Ok1vdmluZzo6Sml0dGVyUmFuZG9taXplIjpbMF0sIkFBOjpDcm91Y2ggbW92aW5nOjpQaXRjaEN1c3RvbSI6WzBdLCJBQTo6QWlyICYgQ3JvdWNoOjpQaXRjaCI6WyJPZmYiXSwiQUE6OkFpcjo6WWF3Sml0dGVyIjpbIk9mZiJdLCJBQTo6Q3JvdWNoaW5nOjpCb2R5WWF3IjpbIk9mZiJdLCJBQTo6QWlyOjpZYXdTd2l0Y2hEZWxheSI6WzZdLCJBQTo6QWlyICYgQ3JvdWNoOjpZYXdMZWZ0IjpbMF0sIkFBOjpBaXI6Ollhd0N1c3RvbSI6WzBdLCJBQTo6Q3JvdWNoaW5nOjpZYXdKaXR0ZXIiOlsiT2ZmIl0sIkFBOjpBaXI6OkJvZHlWYWx1ZSI6WzBdLCJBQTo6RmFrZSBsYWc6Ollhd1NwZWVkIjpbNV0sIkFBOjpHbG9iYWw6OkppdHRlclJhbmRvbWl6ZSI6WzBdLCJBQTo6U2xvdy1tb3Rpb246Ollhd1N3aXRjaERlbGF5IjpbNl0sIkFBOjpBaXIgJiBDcm91Y2g6Ollhd1JpZ2h0IjpbMF19LCJ2aXN1YWxzIjp7ImluZGljYXRvcl92ZXJ0aWNhbF9vZmZzZXQiOlsyMF0sIm1hbnVhbF9hcnJvd3NfYWNjZW50IjpbMjU1LDAsMCwyNTVdLCJkYW1hZ2VfbWFya2VyIjpbdHJ1ZV0sImluZGljYXRvcnMiOlt0cnVlXSwicjhfaW5kaWNhdG9yX2NvbG9yIjpbMjU1LDAsMCwyNTVdLCJpbmRpY2F0b3Jfb3B0aW9ucyI6W1siVmVsb2NpdHkgbW9kaWZpZXIiLCJBZGp1c3Qgd2hpbGUgc2NvcGVkIiwiQWx0ZXIgYWxwaGEgd2hpbGUgc2NvcGVkIiwiQWx0ZXIgYWxwaGEgb24gZ3JlbmFkZSJdXSwiaW5kaWNhdG9yX2NvbG9yIjpbMjU1LDI1NSwyNTUsMjU1XSwicjhfaW5kaWNhdG9yIjpbZmFsc2VdLCJtYW51YWxfYXJyb3dzX29wdGlvbnMiOlt7fV0sIm1hbnVhbF9hcnJvd3Nfc2l6ZSI6WzEwXSwiaW5kaWNhdG9yX3N0eWxlIjpbIlJlbmV3ZWQiXSwibWFudWFsX2Fycm93c19vZmZzZXQiOlszNV0sIm1hbnVhbF9hcnJvd3NfY29sb3IiOls3Nyw3Nyw3NywyNTVdLCJtYW51YWxfYXJyb3dzIjpbZmFsc2VdLCJtYW51YWxfYXJyb3dzX3N0eWxlIjpbIlRyaWFuZ2xlcyJdLCJkYW1hZ2VfbWFya2VyX2NvbG9yIjpbMjU1LDAsMCwyNTVdLCJpbmRpY2F0b3JfcmVuZXdlZF9jb2xvciI6WzEzNywxMzcsMTM3LDI1NV19LCJhbnRpYWltYm90Ijp7ImRlZmVuc2l2ZV9jb25kaXRpb25zX2F1dG8iOltbIk9uIHBlZWsiLCJMZWdpdCBBQSIsIkVkZ2UgZGlyZWN0aW9uIiwiU2FmZSBoZWFkIiwiVHJpZ2dlcmVkIiwiU3RhbmRpbmciLCJTbG93LW1vdGlvbiIsIk1vdmluZyIsIkNyb3VjaGluZyIsIkNyb3VjaCBtb3ZpbmciLCJBaXIiLCJBaXIgJiBDcm91Y2giXV0sImlkZWFsX3RpY2siOltmYWxzZV0sIm1hbnVhbF95YXciOlt0cnVlXSwiYW5pbWF0aW9uX2JyZWFrZXJfYWlyIjpbIldhbGtpbmciXSwic2FmZV9oZWFkX2NvbmRpdGlvbnMiOltbIkFpciBrbmlmZSIsIkFpciB6ZXVzIiwiQWlyICYgQ3JvdWNoIiwiQ3JvdWNoIG1vdmluZyIsIkNyb3VjaGluZyIsIlNsb3ctbW90aW9uIiwiU3RhbmRpbmciXV0sInNhZmVfaGVhZCI6W3RydWVdLCJvcHRpb25zIjpbWyJPbiB1c2UgYW50aWFpbSIsIkZhc3QgbGFkZGVyIiwiRG9ybWFudCBwcmVzZXQiXV0sIndhcm11cF9hYV9jb25kaXRpb25zIjpbWyJXYXJtdXAiLCJSb3VuZCBlbmQiXV0sImFuaW1hdGlvbl9icmVha2VyX2xlZyI6WyJXYWxraW5nIl0sIm1hbnVhbF9vcHRpb25zIjpbWyJKaXR0ZXIgZGlzYWJsZWQiXV0sImZyZWVzdGFuZGluZ19kaXNhYmxlcl9zdGF0ZXMiOltbIkFpciIsIkFpciAmIENyb3VjaCJdXSwid2FybXVwX2FhIjpbdHJ1ZV0sImFuaW1hdGlvbl9icmVha2VyX290aGVyIjpbWyJRdWljayBwZWVrIGxlZ3MiLCJQaXRjaCB6ZXJvIG9uIGxhbmQiXV0sImFuaW1hdGlvbl9icmVha2VyIjpbdHJ1ZV0sImRlZmVuc2l2ZV9hYSI6W3RydWVdLCJhaXJfZXhwbG9pdCI6W2ZhbHNlXSwiZGVmZW5zaXZlX2NvbmRpdGlvbnMiOltbIkNyb3VjaGluZyIsIkNyb3VjaCBtb3ZpbmciLCJBaXIiLCJBaXIgJiBDcm91Y2giXV0sImlkZWFsX3RpY2tfaG90a2V5IjpbIk9uIGhvdGtleSJdLCJwcmVzZXQiOlsiU3BlY3RlciBHb2Rtb2RlIl0sImRlZmVuc2l2ZV90YXJnZXQiOltbIkRvdWJsZSB0YXAiXV0sImFpcl9leHBsb2l0X2hvdGtleSI6WyJPbiBob3RrZXkiXSwiZnNfb3B0aW9ucyI6W1siSml0dGVyIGRpc2FibGVkIl1dLCJkZWZlbnNpdmVfcHJlc2V0IjpbIkF1dG8iXSwiZGVmZW5zaXZlX3RyaWdnZXJzIjpbWyJGbGFzaGVkIiwiRGFtYWdlIHJlY2VpdmVkIiwiUmVsb2FkaW5nIiwiV2VhcG9uIHN3aXRjaCJdXSwiZm9yY2VfdGFyZ2V0X3lhdyI6W3RydWVdfSwibWlzY2VsbGFuZW91cyI6eyJjaGVhdF90d2Vha3NfbGlzdCI6W1siVW5jaGFyZ2UgaGVscGVyIiwiU3VwZXIgdG9zcyBvbiBncmVuYWRlIHJlbGVhc2UiLCJBbGxvdyBjcm91Y2ggb24gZmFrZWR1Y2siXV0sImF1dG9tYXRpY190cCI6W3t9XSwiY2xhbnRhZyI6W2ZhbHNlXSwidHJhc2h0YWxrIjpbZmFsc2VdLCJjb25zb2xlX2ZpbHRlciI6W3RydWVdLCJhdXRvbWF0aWNfdHBfZGVsYXkiOlsyXSwiY3VzdG9tX291dHB1dCI6W3RydWVdLCJldmVudF9sb2dnZXIiOlt0cnVlXSwiY2hlYXRfdHdlYWtzIjpbdHJ1ZV19LCJkZWZlbnNpdmUiOnsiREVGOjpBaXI6OlBpdGNoIjpbIkRlZmF1bHQiXSwiREVGOjpPbiBwZWVrOjpQaXRjaCI6WyJEZWZhdWx0Il0sIkRFRjo6T24gcGVlazo6WWF3UmFuZG9taXplIjpbMF0sIkRFRjo6Q3JvdWNoIG1vdmluZzo6WWF3TGVmdFN0YXJ0IjpbMF0sIkRFRjo6U2xvdy1tb3Rpb246OlBpdGNoIjpbIkRlZmF1bHQiXSwiREVGOjpHbG9iYWw6Ollhd1NwZWVkIjpbMV0sIkRFRjo6R2xvYmFsOjpZYXdSYW5kb21pemUiOlswXSwiREVGOjpNb3Zpbmc6OlBpdGNoIjpbIkRlZmF1bHQiXSwiREVGOjpMZWdpdCBBQTo6UGl0Y2hDdXN0b20iOls4OV0sIkRFRjo6U3RhbmRpbmc6Ollhd1JhbmRvbWl6ZSI6WzBdLCJERUY6OkNyb3VjaGluZzo6WWF3RGVsYXkiOls2XSwiREVGOjpTbG93LW1vdGlvbjo6WWF3U3BlZWQiOlsxXSwiREVGOjpHbG9iYWw6OlBpdGNoIjpbIkRlZmF1bHQiXSwiREVGOjpFZGdlIGRpcmVjdGlvbjo6RW5hYmxlZCI6W2ZhbHNlXSwiREVGOjpNb3Zpbmc6Ollhd0xlZnQiOlswXSwiREVGOjpNb3Zpbmc6Ollhd1RvIjpbMF0sIkRFRjo6QWlyICYgQ3JvdWNoOjpZYXdMZWZ0VGFyZ2V0IjpbMF0sIkRFRjo6TGVnaXQgQUE6OlBpdGNoIjpbIkRlZmF1bHQiXSwiREVGOjpDcm91Y2hpbmc6OlBpdGNoIjpbIkRlZmF1bHQiXSwiREVGOjpDcm91Y2hpbmc6Ollhd1RvIjpbMF0sIkRFRjo6U2xvdy1tb3Rpb246Ollhd1JpZ2h0VGFyZ2V0IjpbMF0sIkRFRjo6Q3JvdWNoaW5nOjpZYXciOlsiRGVmYXVsdCJdLCJERUY6OlNsb3ctbW90aW9uOjpFbmFibGVkIjpbZmFsc2VdLCJERUY6Ok1vdmluZzo6WWF3TGVmdFN0YXJ0IjpbMF0sIkRFRjo6T24gcGVlazo6UGl0Y2hDdXN0b20iOls4OV0sIkRFRjo6QWlyOjpQaXRjaEN1c3RvbSI6Wzg5XSwiREVGOjpHbG9iYWw6Ollhd1JpZ2h0VGFyZ2V0IjpbMF0sIkRFRjo6U3RhbmRpbmc6OlBpdGNoIjpbIkRlZmF1bHQiXSwiREVGOjpTbG93LW1vdGlvbjo6WWF3TGVmdFRhcmdldCI6WzBdLCJERUY6OkFpcjo6WWF3UmFuZG9taXplIjpbMF0sIkRFRjo6R2xvYmFsOjpZYXdSaWdodFN0YXJ0IjpbMF0sIkRFRjo6U3RhbmRpbmc6Ollhd0Zyb20iOlswXSwiREVGOjpNb3Zpbmc6Ollhd1JpZ2h0U3RhcnQiOlswXSwiREVGOjpNb3Zpbmc6Ollhd0xlZnRUYXJnZXQiOlswXSwiREVGOjpBaXIgJiBDcm91Y2g6Ollhd1JpZ2h0VGFyZ2V0IjpbMF0sIkRFRjo6R2xvYmFsOjpZYXdMZWZ0VGFyZ2V0IjpbMF0sIkRFRjo6QWlyICYgQ3JvdWNoOjpFbmFibGVkIjpbZmFsc2VdLCJERUY6Okdsb2JhbDo6WWF3TGVmdCI6WzBdLCJERUY6OkNyb3VjaCBtb3Zpbmc6OlBpdGNoQ3VzdG9tIjpbODldLCJERUY6OkFpciAmIENyb3VjaDo6WWF3UmFuZG9taXplIjpbMF0sIkRFRjo6R2xvYmFsOjpZYXdSaWdodCI6WzBdLCJERUY6Ok1vdmluZzo6WWF3RnJvbSI6WzBdLCJERUY6OkNyb3VjaCBtb3Zpbmc6Ollhd1NwZWVkIjpbMV0sIkRFRjo6Q3JvdWNoaW5nOjpZYXdSaWdodFN0YXJ0IjpbMF0sIkRFRjo6U2xvdy1tb3Rpb246Ollhd0Zyb20iOlswXSwiREVGOjpTYWZlIGhlYWQ6OkVuYWJsZWQiOltmYWxzZV0sIkRFRjo6VHJpZ2dlcmVkOjpFbmFibGVkIjpbZmFsc2VdLCJERUY6OkxlZ2l0IEFBOjpZYXdSYW5kb21pemUiOlswXSwiREVGOjpHbG9iYWw6OlBpdGNoQ3VzdG9tIjpbODldLCJERUY6OkFpciAmIENyb3VjaDo6UGl0Y2hDdXN0b20iOls4OV0sIkRFRjo6TGVnaXQgQUE6Ollhd1NwZWVkIjpbMV0sIkRFRjo6TW92aW5nOjpZYXdSaWdodCI6WzBdLCJERUY6OkFpciAmIENyb3VjaDo6WWF3RnJvbSI6WzBdLCJERUY6Ok1vdmluZzo6UGl0Y2hDdXN0b20iOls4OV0sIkRFRjo6QWlyOjpZYXdMZWZ0U3RhcnQiOlswXSwiREVGOjpDcm91Y2ggbW92aW5nOjpZYXdSaWdodCI6WzBdLCJERUY6Ok1vdmluZzo6WWF3RGVsYXkiOls2XSwiREVGOjpBaXIgJiBDcm91Y2g6OllhdyI6WyJEZWZhdWx0Il0sIkRFRjo6TGVnaXQgQUE6Ollhd0xlZnQiOlswXSwiREVGOjpHbG9iYWw6OllhdyI6WyJEZWZhdWx0Il0sIkRFRjo6U3RhbmRpbmc6Ollhd0xlZnQiOlswXSwiREVGOjpBaXI6Ollhd1JpZ2h0U3RhcnQiOlswXSwiREVGOjpDcm91Y2hpbmc6Ollhd0xlZnQiOlswXSwiREVGOjpBaXI6OkVuYWJsZWQiOltmYWxzZV0sIkRFRjo6QWlyOjpZYXdSaWdodFRhcmdldCI6WzBdLCJERUY6OkNyb3VjaGluZzo6WWF3UmFuZG9taXplIjpbMF0sIkRFRjo6U3RhbmRpbmc6Ollhd1JpZ2h0IjpbMF0sIkRFRjo6T24gcGVlazo6WWF3UmlnaHQiOlswXSwiREVGOjpMZWdpdCBBQTo6RW5hYmxlZCI6W2ZhbHNlXSwiREVGOjpTbG93LW1vdGlvbjo6WWF3TGVmdFN0YXJ0IjpbMF0sIkRFRjo6QWlyICYgQ3JvdWNoOjpZYXdUbyI6WzBdLCJERUY6Ok9uIHBlZWs6Ollhd0xlZnRUYXJnZXQiOlswXSwiREVGOjpTbG93LW1vdGlvbjo6WWF3UmFuZG9taXplIjpbMF0sIkRFRjo6T24gcGVlazo6WWF3U3BlZWQiOlsxXSwiREVGOjpTdGFuZGluZzo6RW5hYmxlZCI6W2ZhbHNlXSwiREVGOjpTdGFuZGluZzo6WWF3IjpbIkRlZmF1bHQiXSwiREVGOjpBaXI6OllhdyI6WyJEZWZhdWx0Il0sIkRFRjo6QWlyICYgQ3JvdWNoOjpZYXdEZWxheSI6WzZdLCJERUY6OkxlZ2l0IEFBOjpZYXdGcm9tIjpbMF0sIkRFRjo6Q3JvdWNoIG1vdmluZzo6WWF3RGVsYXkiOls2XSwiREVGOjpBaXI6Ollhd0Zyb20iOlswXSwiREVGOjpTbG93LW1vdGlvbjo6UGl0Y2hDdXN0b20iOls4OV0sIkRFRjo6U2xvdy1tb3Rpb246Ollhd1JpZ2h0U3RhcnQiOlswXSwiREVGOjpDcm91Y2hpbmc6OkVuYWJsZWQiOltmYWxzZV0sIkRFRjo6T24gcGVlazo6WWF3IjpbIkRlZmF1bHQiXSwiREVGOjpTdGFuZGluZzo6WWF3UmlnaHRTdGFydCI6WzBdLCJERUY6Ok9uIHBlZWs6OkVuYWJsZWQiOltmYWxzZV0sIkRFRjo6TGVnaXQgQUE6Ollhd0RlbGF5IjpbNl0sIkRFRjo6QWlyOjpZYXdUbyI6WzBdLCJERUY6OlN0YW5kaW5nOjpZYXdMZWZ0U3RhcnQiOlswXSwiREVGOjpDcm91Y2ggbW92aW5nOjpZYXdSaWdodFRhcmdldCI6WzBdLCJERUY6Okdsb2JhbDo6WWF3RGVsYXkiOls2XSwiREVGOjpDcm91Y2ggbW92aW5nOjpZYXciOlsiRGVmYXVsdCJdLCJERUY6Ok1vdmluZzo6RW5hYmxlZCI6W2ZhbHNlXSwiREVGOjpDcm91Y2hpbmc6Ollhd1JpZ2h0VGFyZ2V0IjpbMF0sIkRFRjo6Q3JvdWNoaW5nOjpZYXdTcGVlZCI6WzFdLCJERUY6OkFpcjo6WWF3U3BlZWQiOlsxXSwiREVGOjpFZGdlIGRpcmVjdGlvbjo6VGFyZ2V0Ijpbe31dLCJERUY6Ok1vdmluZzo6WWF3UmFuZG9taXplIjpbMF0sIkRFRjo6U3RhbmRpbmc6OlBpdGNoQ3VzdG9tIjpbODldLCJERUY6Ok1vdmluZzo6WWF3U3BlZWQiOlsxXSwiREVGOjpTdGFuZGluZzo6WWF3TGVmdFRhcmdldCI6WzBdLCJERUY6Ok1vdmluZzo6WWF3UmlnaHRUYXJnZXQiOlswXSwiREVGOjpPbiBwZWVrOjpZYXdMZWZ0U3RhcnQiOlswXSwiREVGOjpDcm91Y2hpbmc6Ollhd1JpZ2h0IjpbMF0sIkRFRjo6Q3JvdWNoaW5nOjpQaXRjaEN1c3RvbSI6Wzg5XSwiREVGOjpBaXIgJiBDcm91Y2g6Ollhd1JpZ2h0U3RhcnQiOlswXSwiREVGOjpDcm91Y2ggbW92aW5nOjpQaXRjaCI6WyJEZWZhdWx0Il0sIkRFRjo6TGVnaXQgQUE6Ollhd1RvIjpbMF0sIkRFRjo6TGVnaXQgQUE6Ollhd1JpZ2h0VGFyZ2V0IjpbMF0sIkRFRjo6U3RhbmRpbmc6Ollhd1JpZ2h0VGFyZ2V0IjpbMF0sIkRFRjo6R2xvYmFsOjpZYXdGcm9tIjpbMF0sIkRFRjo6R2xvYmFsOjpZYXdMZWZ0U3RhcnQiOlswXSwiREVGOjpTbG93LW1vdGlvbjo6WWF3RGVsYXkiOls2XSwiREVGOjpDcm91Y2ggbW92aW5nOjpZYXdSYW5kb21pemUiOlswXSwiREVGOjpMZWdpdCBBQTo6WWF3TGVmdFRhcmdldCI6WzBdLCJERUY6OkFpciAmIENyb3VjaDo6WWF3TGVmdCI6WzBdLCJERUY6Ok9uIHBlZWs6Ollhd0Zyb20iOlswXSwiREVGOjpMZWdpdCBBQTo6WWF3TGVmdFN0YXJ0IjpbMF0sIkRFRjo6T24gcGVlazo6WWF3VG8iOlswXSwiREVGOjpDcm91Y2hpbmc6Ollhd0xlZnRUYXJnZXQiOlswXSwiREVGOjpDcm91Y2ggbW92aW5nOjpZYXdUbyI6WzBdLCJERUY6OlNsb3ctbW90aW9uOjpZYXciOlsiRGVmYXVsdCJdLCJERUY6OkNyb3VjaCBtb3Zpbmc6Ollhd0Zyb20iOlswXSwiREVGOjpTbG93LW1vdGlvbjo6WWF3VG8iOlswXSwiREVGOjpPbiBwZWVrOjpZYXdEZWxheSI6WzZdLCJERUY6Ok1vdmluZzo6WWF3IjpbIkRlZmF1bHQiXSwiREVGOjpTbG93LW1vdGlvbjo6WWF3TGVmdCI6WzBdLCJERUY6Okdsb2JhbDo6WWF3VG8iOlswXSwiREVGOjpDcm91Y2ggbW92aW5nOjpZYXdSaWdodFN0YXJ0IjpbMF0sIkRFRjo6Q3JvdWNoaW5nOjpZYXdGcm9tIjpbMF0sIkRFRjo6QWlyICYgQ3JvdWNoOjpZYXdTcGVlZCI6WzFdLCJERUY6OlNsb3ctbW90aW9uOjpZYXdSaWdodCI6WzBdLCJERUY6OkNyb3VjaCBtb3Zpbmc6Ollhd0xlZnRUYXJnZXQiOlswXSwiREVGOjpPbiBwZWVrOjpZYXdMZWZ0IjpbMF0sIkRFRjo6TGVnaXQgQUE6Ollhd1JpZ2h0U3RhcnQiOlswXSwiREVGOjpPbiBwZWVrOjpZYXdSaWdodFN0YXJ0IjpbMF0sIkRFRjo6Q3JvdWNoaW5nOjpZYXdMZWZ0U3RhcnQiOlswXSwiREVGOjpBaXIgJiBDcm91Y2g6Ollhd0xlZnRTdGFydCI6WzBdLCJERUY6Okdsb2JhbDo6RW5hYmxlZCI6W2ZhbHNlXSwiREVGOjpBaXI6Ollhd0RlbGF5IjpbNl0sIkRFRjo6Q3JvdWNoIG1vdmluZzo6WWF3TGVmdCI6WzBdLCJERUY6OkFpciAmIENyb3VjaDo6WWF3UmlnaHQiOlswXSwiREVGOjpMZWdpdCBBQTo6WWF3IjpbIkRlZmF1bHQiXSwiREVGOjpBaXI6Ollhd0xlZnRUYXJnZXQiOlswXSwiREVGOjpTdGFuZGluZzo6WWF3VG8iOlswXSwiREVGOjpBaXI6Ollhd1JpZ2h0IjpbMF0sIkRFRjo6QWlyOjpZYXdMZWZ0IjpbMF0sIkRFRjo6Q3JvdWNoIG1vdmluZzo6RW5hYmxlZCI6W2ZhbHNlXSwiREVGOjpPbiBwZWVrOjpZYXdSaWdodFRhcmdldCI6WzBdLCJERUY6OlN0YW5kaW5nOjpZYXdTcGVlZCI6WzFdLCJERUY6OlN0YW5kaW5nOjpZYXdEZWxheSI6WzZdLCJERUY6OkxlZ2l0IEFBOjpZYXdSaWdodCI6WzBdLCJERUY6OkFpciAmIENyb3VjaDo6UGl0Y2giOlsiRGVmYXVsdCJdfSwibWFudWFscyI6eyJyaWdodCI6WyJPbiBob3RrZXkiXSwibGVmdCI6WyJPbiBob3RrZXkiXSwiYmFja3dhcmQiOlsiT24gaG90a2V5Il0sImVkZ2UiOlsiT24gaG90a2V5Il0sImZvcndhcmQiOlsiT24gaG90a2V5Il0sInJlc2V0IjpbIk9uIGhvdGtleSJdLCJmcmVlc3RhbmRpbmciOlsiT24gaG90a2V5Il19LCJmYWtlbGFnIjp7ImVuYWJsZSI6W3RydWVdLCJ0aWNrcyI6WzE0XSwidHlwZSI6WyJSYW5kb21pemUiXX19_Specter");

                if not success then
                    return c_logger.log_error('Failed to load builtin config due to [%s]', err)
                end

                antiaimbot_builder.load_defaults()
                settings.recommended()
                config_system:save_local(true)
                c_logger.log('Builtin config loaded.')
            end

            config.settings.import:set_callback(settings.import)
            config.settings.export:set_callback(settings.export)
            config.settings.builtin:set_callback(settings.builtin)
            config.settings.default_aa:set_callback(function()
                antiaimbot_builder.load_defaults()
                config_system:save_local(true)
                c_logger.log('Default anti-aim loaded.')
            end)
            config.settings.save:set_callback(settings.save)

            do
                local menu_was_open, next_save = false, 0
                client.set_event_callback("paint_ui", function()
                    if not config_system.loaded_once then return end

                    local open = ui_is_menu_open()
                    local now = globals.realtime()
                    local auto = config.settings.autosave:get()
                    if auto and menu.dirty and ((menu_was_open and not open) or now >= next_save) then
                        next_save = now + 30
                        menu.dirty = false
                        pcall(config_system.save_local, config_system, true)
                    end
                    menu_was_open = open
                end)
            end
        end
    end

    ---
    --- Antiaim presets
    ---
    local antiaim_presets do

        antiaim_presets = {} do
            local database_name = 'specter_presets'
            local list = {}

            -- the loadouts everyone shared through the license server; they come after the own ones in the list
            local SERVER = _auth_data and _auth_data.server_url or ""
            local KEY    = _auth_data and _auth_data.key or ""
            local HWID   = _auth_data and _auth_data.hwid or ""
            local cloud, rows, cloud_busy = {}, {}, false

            local function cloud_status(msg)
                config.presets.cloud_msg = msg
                mui.refresh(config.presets.cloud_status)
            end

            local function url_encode(v)
                return (tostring(v):gsub("([^%w%-_.~])", function(c) return string_format("%%%02X", string.byte(c)) end))
            end

            -- names come from other users: printable, short
            local function clean(v, n)
                return (tostring(v or ""):gsub("[%c]", ""):sub(1, n))
            end

            local function cloud_ready()
                if not http then cloud_status("subscribe to gamesense/http for the cloud"); return false end
                if SERVER == "" then cloud_status("no server set"); return false end
                if cloud_busy then return false end
                return true
            end

            local function cloud_answer(ok, resp)
                if not ok then return nil end
                local body = type(resp) == "table" and resp.body or resp
                local good, data = pcall(json.parse, body)
                return good and type(data) == "table" and data or nil
            end

            local create_preset, Preset do
                Preset = {} do
                    function Preset:load()
                        local success, err = config_system.import_from_str(self.data)

                        if not success then
                            c_logger.log_error('Failed to load cfg [%s]', err)

                            return false
                        end

                        config_system:save_local(true)
                        return true
                    end

                    function Preset:import()
                        local data = clipboard.get()
                        local success, err = config_system.import_from_str(data, "builder", "defensive")

                        if not success then
                            c_logger.log_error('Failed to import cfg [%s]', err)

                            return false
                        end

                        self.data = data

                        return true
                    end

                    function Preset:export()
                        clipboard.set(self.data)
                    end

                    function Preset:save()
                        local result = config_system.export_to_str()
                        self.data = result
                    end

                    function Preset:to_database()
                        return {
                            name = self.name,
                            data = self.data
                        }
                    end

                    function create_preset(preset)
                        return setmetatable({
                            name = preset.name,
                            data = preset.data
                        }, {
                            __index = Preset
                        })
                    end
                end
            end

            function antiaim_presets.update_list()
                local list_names = {}
                rows = {}

                for i = 1, #list do
                    rows[#rows + 1] = { preset = list[i] }
                    list_names[#rows] = list[i].name
                end
                for i = 1, #cloud do
                    rows[#rows + 1] = { cloud = cloud[i] }
                    list_names[#rows] = "☁ " .. cloud[i].name .. "  by " .. cloud[i].author
                end

                if #list_names == 0 then
                    list_names[1] = 'No loadouts yet - type a name and press Create'
                end

                ui.update(config.presets.list:get_ref(), list_names)
            end

            function antiaim_presets.lookup(name)
                local search = c_string.trim(name)
                local list_len = #list

                for i=1, list_len do
                    local preset = list[i]

                    if preset.name == search then
                        return preset, i - 1
                    end
                end
            end

            function antiaim_presets.create(name)
                local target = c_string.trim(name)

                local success, result = pcall(function (...)
                    return config_system.export_to_str()
                end)

                if not success then
                    c_logger.log_error('Preset failed to create [%s]', result)

                    return
                end

                list[#list+1] = create_preset({
                    name = target,
                    data = result
                })

                antiaim_presets.update_list()
                antiaim_presets.flush()
            end

            function antiaim_presets.list_name_changed()
                if #rows == 0 then
                    return
                end

                local selected_id = config.presets.list:rawget() or 0
                local row = rows[selected_id + 1] or rows[#rows]
                local selected = row.preset or row.cloud

                config.presets.cloud_pick = row.cloud
                config.presets.name:set(selected.name)
            end

            -- the cloud loadout that is selected (and whose name is still in the name box)
            local function picked_cloud()
                local pick = config.presets.cloud_pick
                if pick and pick.name == c_string.trim(tostring(config.presets.name:rawget() or "")) then return pick end
            end

            -- the shared data is the export string in base64 (older uploads: the export string itself)
            local function cloud_data(cfg)
                local ok, decoded = pcall(base64.decode, cfg.data)
                if ok and type(decoded) == "string" and decoded:find("_Specter$") then return decoded end
                return cfg.data
            end

            function antiaim_presets.cloud_refresh()
                if not cloud_ready() then return end
                cloud_busy = true
                cloud_status("loading the cloud...")
                http.get(SERVER .. "/configs", function(ok, resp)
                    cloud_busy = false
                    local data = cloud_answer(ok, resp)
                    if not data then cloud_status("cloud unreachable"); return end
                    cloud = {}
                    for i = #data, 1, -1 do -- newest first
                        local c = data[i]
                        if type(c) == "table" and type(c.data) == "string" and c.name then
                            cloud[#cloud + 1] = { name = clean(c.name, 32), author = clean(c.author or "?", 20), data = c.data }
                        end
                    end
                    antiaim_presets.update_list()
                    antiaim_presets.list_name_changed()
                    cloud_status(#cloud .. " shared loadout(s) in the cloud")
                end)
            end

            -- uploads the loadout named in the box (or the current config under that name)
            function antiaim_presets.cloud_share()
                local name = c_string.trim(tostring(config.presets.name:rawget() or ""))
                if name == "" or name:find("^No loadouts yet") then cloud_status("type a name first"); return end
                if #name > 32 then cloud_status("name too long (max 32)"); return end
                if picked_cloud() then cloud_status("that one is already in the cloud"); return end
                if KEY == "" then cloud_status("log in with your key to share"); return end
                if not cloud_ready() then return end

                local preset = antiaim_presets.lookup(name)
                local data = preset and preset.data or config_system.export_to_str()
                local encoded = base64.encode(data)

                -- a whole config does not fit into one URL: it goes up in small parts, one request each
                local CHUNK, parts = 3000, {}
                for i = 1, #encoded, CHUNK do parts[#parts + 1] = encoded:sub(i, i + CHUNK - 1) end
                if #parts > 150 then cloud_status("loadout too large"); return end

                local base = SERVER .. "/configs/upload_part?key=" .. url_encode(KEY) .. "&hwid=" .. url_encode(HWID)
                    .. "&name=" .. url_encode(name) .. "&total=" .. #parts
                cloud_busy = true
                local function send(i)
                    cloud_status(string_format("sharing %d/%d...", i, #parts))
                    http.get(base .. "&idx=" .. (i - 1) .. "&data=" .. url_encode(parts[i]), function(ok, resp)
                        local answer = cloud_answer(ok, resp)
                        if not (answer and answer.ok) then
                            cloud_busy = false
                            cloud_status("share failed: " .. tostring(answer and answer.reason or "server unreachable"))
                            return
                        end
                        if i < #parts then return send(i + 1) end
                        cloud_busy = false
                        c_logger.log('Loadout "%s" shared to the cloud.', name)
                        antiaim_presets.cloud_refresh()
                    end)
                end
                send(1)
            end

            function antiaim_presets.cloud_load(cfg)
                local ok, err = config_system.import_from_str(cloud_data(cfg))
                if not ok then
                    c_logger.log_error('Failed to load cloud loadout [%s]', err)
                    return
                end
                pcall(antiaimbot_builder.refresh)
                pcall(antiaimbot_builder.refresh_defensive)
                config_system:save_local(true)
                c_logger.log('Cloud loadout "%s" by %s loaded.', cfg.name, cfg.author)
            end

            -- the server deletes only the user's own uploads
            function antiaim_presets.cloud_delete(cfg)
                if KEY == "" then cloud_status("log in with your key to delete"); return end
                if not cloud_ready() then return end
                cloud_busy = true
                local url = SERVER .. "/configs/delete?key=" .. url_encode(KEY) .. "&hwid=" .. url_encode(HWID) .. "&name=" .. url_encode(cfg.name)
                http.get(url, function(ok, resp)
                    cloud_busy = false
                    local answer = cloud_answer(ok, resp)
                    if not (answer and answer.ok) then
                        local reason = answer and answer.reason
                        cloud_status(reason == "not_found" and "you can only delete your own loadouts"
                            or "delete failed: " .. tostring(reason or "server unreachable"))
                        return
                    end
                    c_logger.log('Cloud loadout "%s" deleted.', cfg.name)
                    antiaim_presets.cloud_refresh()
                end)
            end

            function antiaim_presets.delete(target)
                local list_len = #list

                for i=1, list_len do
                    local preset = list[i]

                    if preset.name == target.name then
                        c_logger.log('Removed preset [%s]', preset.name)

                        table_remove(list, i)

                        break
                    end
                end

                antiaim_presets.update_list()
                antiaim_presets.flush()
                antiaim_presets.list_name_changed()
            end

            function antiaim_presets.initialize()
                local database_list = database.read(database_name) or database.read('Zenith_presets')

                if database_list == nil then
                    database_list = {}
                end

                local list_len = #database_list

                for i=1, list_len do
                    local preset = database_list[i]

                    list[i] = create_preset(preset)
                end

                antiaim_presets.initialized = true
                antiaim_presets.update_list()
                antiaim_presets.list_name_changed()
            end

            function antiaim_presets.flush()
                -- unloading before the saved list was read would overwrite it with an empty one
                if not antiaim_presets.initialized then return end
                local database_list = {}

                local list_len = #list

                for i=1, list_len do
                    database_list[i] = list[i]:to_database()
                end

                c_logger.log('Presets db saved.')

                database.write(database_name, database_list)
            end

            antiaim_presets.methods = {} do
                function antiaim_presets.methods.load()
                    local pick = picked_cloud()
                    if pick then return antiaim_presets.cloud_load(pick) end
                    local name = config.presets.name:rawget()
                    local preset, id = antiaim_presets.lookup(name)

                    if preset == nil then
                        c_logger.log_error('No preset selected!');

                        return
                    end

                    if preset:load() then
                        c_logger.log('Config "%s" loaded', name)
                    end
                    config.presets.list:set(id)
                end

                function antiaim_presets.methods.save()
                    local name = c_string.trim(tostring(config.presets.name:rawget() or ""))
                    if name == "" or name:find("^No loadouts yet") then
                        c_logger.log_error('Type a config name first')
                        return
                    end
                    -- saving with a cloud loadout selected makes an own one with its name
                    config.presets.cloud_pick = nil
                    local preset, id = antiaim_presets.lookup(name)

                    if preset == nil then
                        antiaim_presets.create(name)
                        config.presets.list:set(#list-1)
                        c_logger.log('Config "%s" created', name)

                        return
                    end

                    preset:save()
                    config.presets.list:set(id)

                    antiaim_presets.flush()
                    c_logger.log('Config "%s" saved', name)
                end

                function antiaim_presets.methods.create()
                    local name = c_string.trim(tostring(config.presets.name:rawget() or ""))
                    if name == "" or name:find("^No loadouts yet") then
                        c_logger.log_error('Type a loadout name first')
                        return
                    end
                    if antiaim_presets.lookup(name) then
                        c_logger.log_error('A loadout named "%s" already exists - select it and press Save to overwrite', name)
                        return
                    end
                    antiaim_presets.methods.save()
                end

                function antiaim_presets.methods.export()
                    local pick = picked_cloud()
                    if pick then
                        clipboard.set(cloud_data(pick))
                        return c_logger.log('Cloud loadout "%s" exported.', pick.name)
                    end
                    local name = config.presets.name:rawget()
                    local preset, id = antiaim_presets.lookup(name)

                    if preset == nil then
                        c_logger.log_error('No preset selected!');

                        return
                    end

                    c_logger.log('Exporting preset "%s"', name)

                    preset:export()
                    config.presets.list:set(id)
                end

                function antiaim_presets.methods.import()
                    local name = c_string.trim(tostring(config.presets.name:rawget() or ""))
                    if name == "" or name:find("^No loadouts yet") then
                        c_logger.log_error('Type a config name first')
                        return
                    end

                    -- check the clipboard before touching anything
                    local data = clipboard.get()
                    local body = type(data) == "string" and data:match("^([^_]+)") or nil
                    local ok_dec, decoded = pcall(base64.decode, body or "")
                    local ok_json, parsed = false, nil
                    if ok_dec and decoded then ok_json, parsed = pcall(json.parse, decoded) end
                    if not (ok_json and type(parsed) == "table") then
                        c_logger.log_error('Clipboard does not contain a specter config')
                        return
                    end

                    local preset, id = antiaim_presets.lookup(name)
                    if preset == nil then
                        antiaim_presets.create(name)
                        preset, id = antiaim_presets.lookup(name)
                    end

                    if preset and preset:import() then
                        antiaim_presets.flush()
                        config.presets.list:set(id)
                        c_logger.log('Preset imported [%s].', name)
                    end
                end

                function antiaim_presets.methods.remove()
                    local pick = picked_cloud()
                    if pick then return antiaim_presets.cloud_delete(pick) end
                    local name = config.presets.name:rawget()
                    local preset = antiaim_presets.lookup(name)

                    if preset == nil then
                        return
                    else
                        antiaim_presets.delete(preset)
                    end
                end
            end

            config.presets.load:set_callback(antiaim_presets.methods.load)
            config.presets.create:set_callback(antiaim_presets.methods.create)
            config.presets.save:set_callback(antiaim_presets.methods.save)
            config.presets.export:set_callback(antiaim_presets.methods.export)
            config.presets.import:set_callback(antiaim_presets.methods.import)
            config.presets.remove:set_callback(antiaim_presets.methods.remove)
            config.presets.share:set_callback(antiaim_presets.cloud_share)
            config.presets.refresh:set_callback(antiaim_presets.cloud_refresh)

            config.presets.list:set_callback(function ()
                antiaim_presets.list_name_changed()
            end)

            antiaim_presets.initialize()
            if http and SERVER ~= "" then antiaim_presets.cloud_refresh() end
        end
    end

    ---
    --- Menu state
    ---
    config.global = {} do
        -- change how your name appears in the watermark, logs and this menu
        config.global.name_override = menu.new_item(ui.new_checkbox, "AA", "Other", "Username Manipulation")
            :record("global", "name_override"):save()
        config.global.display_name = menu.new_item(ui.new_textbox, "AA", "Other", "\ndisplay_name")
            :record("global", "display_name"):save()
        config.global.name_hint = mui.hint(mui.SIDE, "shown in the watermark, logs and menu")
        user.real_name = user.real_name or user.name
        function config.global.apply_name()
            local custom = ""
            if config.global.name_override:get() then
                custom = c_string.trim(tostring(config.global.display_name:get() or ""))
            end
            user.name = custom ~= "" and custom:sub(1, 24) or user.real_name
        end

        config.global.public_mode = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Public Mode")
            :record("global", "public_mode"):save()
        config.global.welcome_msg = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Show Welcome Message")
            :record("global", "welcome_msg"):save()

        if config.global.public_mode:get() == nil then
            config.global.public_mode:set(true)
            config.global.welcome_msg:set(true)
        end
    end

    local menu_state = {} do
        function menu_state.visibility(shutdown)
            -- gamesense's own controls come back when the script unloads or specter's anti-aim is off
            local master = config.navigation.aa_enable
            local should_show_aa = shutdown or (master ~= nil and not master:get())
            local should_show_fl = shutdown or (menu.location == "LUA" and not config.fakelag.enable:get())

            if should_show_aa then
                override.unset(reference.antiaim.master)
            else
                override.set(reference.antiaim.master, true)
            end

            ui_set_visible(reference.antiaim.master, should_show_aa)

            ui_set_visible(reference.antiaim.roll, should_show_aa)
            ui_set_visible(reference.antiaim.freestanding[1], should_show_aa)
            ui_set_visible(reference.antiaim.freestanding[2], should_show_aa)
            ui_set_visible(reference.antiaim.yaw.edge, should_show_aa)

            ui_set_visible(reference.antiaim.pitch.type, should_show_aa)
            ui_set_visible(reference.antiaim.pitch.value, should_show_aa and ui_get(reference.antiaim.pitch.type) == 'Custom')

            ui_set_visible(reference.antiaim.yaw.base, should_show_aa)

            ui_set_visible(reference.antiaim.yaw.yaw.type, should_show_aa)

            local should_show_yaw_value = ui_get(reference.antiaim.yaw.yaw.type) ~= 'Off'

            ui_set_visible(reference.antiaim.yaw.yaw.value, should_show_aa and should_show_yaw_value)

            ui_set_visible(reference.antiaim.yaw.jitter.type, should_show_aa)

            local should_show_yaw_jitter = ui_get(reference.antiaim.yaw.jitter.type) ~= 'Off'

            ui_set_visible(reference.antiaim.yaw.jitter.value, should_show_aa and should_show_yaw_jitter)

            ui_set_visible(reference.antiaim.body.yaw.type, should_show_aa)

            local body_yaw = ui_get(reference.antiaim.body.yaw.type)
            local should_show_body_yaw = body_yaw ~= 'Disabled' and body_yaw ~= 'Opposite'

            ui_set_visible(reference.antiaim.body.yaw.value, should_show_aa and should_show_body_yaw)

            ui_set_visible(reference.antiaim.body.freestanding, should_show_aa)

            ui_set_visible(reference.fakelag.amount, should_show_fl)
            ui_set_visible(reference.fakelag.enable[1], should_show_fl)
            ui_set_visible(reference.fakelag.enable[2], should_show_fl)
            ui_set_visible(reference.fakelag.limit, should_show_fl)
            ui_set_visible(reference.fakelag.variance, should_show_fl)

        end

        -- live menu text (session clock, Home overview + telemetry, selected loadout), 4x per second
        local next_live, fps = 0, nil
        function menu_state.live(now)
            if now < next_live and now > next_live - 2 then return end
            next_live = now + 0.25

            local ft = globals.absoluteframetime and globals.absoluteframetime() or globals_frametime()
            if ft and ft > 0 then fps = fps and (fps + (1 / ft - fps) * 0.35) or 1 / ft end

            mui.retheme()
            pcall(config.global.apply_name)
            local NAV = config.navigation
            mui.refresh(NAV.info[1])
            mui.refresh(NAV.info[4])
            mui.refresh(NAV.info[5])

            local page = NAV.page()
            if page == "Home" then
                local A, W, D, K = mui.A, mui.W, mui.D, mui.K
                local GREEN, AMBER, OFF = "\a8CE6A0FF", "\aFFCD6EFF", "\a6E6E78FF"
                local SEP = OFF .. "  ·  "
                local function row(sym, key, value) return string_format("     %s%s  %s%s   %s", D, sym, K, key, value) end
                local ov = mui.overview

                local state = player.alive and string.lower(player.state or "-") or "dead"
                if NAV.aa_enable:get() then
                    ov[1] = row("☾", "Anti-aim", A .. (config.antiaimbot.preset:get() or "-") .. SEP .. W .. state)
                else
                    ov[1] = row("☾", "Anti-aim", OFF .. "off  (gamesense settings)")
                end

                if config.resolver.enabled and config.resolver.enabled:get() then
                    local forced, seen, jitter = 0, 0, 0
                    for _ in pairs(resolver.forced or {}) do forced = forced + 1 end
                    for _, e in ipairs(entity.get_players(true)) do
                        if entity.is_alive(e) and not entity.is_dormant(e) then
                            seen = seen + 1
                            local d = resolver.database and resolver.database[e]
                            if d and d.mode == "j" then jitter = jitter + 1 end
                        end
                    end
                    ov[2] = row("◎", "Resolver", GREEN .. "on" .. SEP .. W .. forced .. " / " .. seen .. " forced" .. SEP .. W .. jitter .. " jitter")
                else
                    ov[2] = row("◎", "Resolver", OFF .. "off")
                end

                if config.antiaimbot.defensive_aa:get() then
                    local active = player.alive and player.defensive_active
                    ov[3] = row("◆", "Defensive", A .. (config.antiaimbot.defensive_preset:get() or "-") .. SEP
                        .. (active and (AMBER .. "active") or (W .. "idle")))
                else
                    ov[3] = row("◆", "Defensive", OFF .. "off")
                end

                local ab = antiaimbot.anti_brute
                if not config.antiaimbot.anti_brute:get() then
                    ov[4] = row("⇄", "Anti-brute", OFF .. "off")
                elseif ab.active then
                    ov[4] = row("⇄", "Anti-brute", AMBER .. "stage " .. ab.stage .. SEP .. W .. math_max(0, math_floor(ab.active_until - now + 0.5)) .. "s")
                else
                    ov[4] = row("⇄", "Anti-brute", W .. "armed")
                end

                if c_table.is_hotkey_active(reference.ragebot.doubletap.enable) then
                    local charged = player.alive and player:get_double_tap()
                    ov[5] = row("↯", "Double tap", charged and (GREEN .. "charged") or (AMBER .. "charging"))
                else
                    ov[5] = row("↯", "Double tap", OFF .. "off")
                end

                local ping = math_floor((client.latency() or 0) * 1000 + 0.5)
                ov[6] = row("≈", "Network", W .. math_floor((fps or 0) + 0.5) .. " fps" .. SEP .. W .. ping .. " ms")

                mui.refresh(NAV.hdr.greeting)
                for i = 1, #NAV.hdr.overview_rows do mui.refresh(NAV.hdr.overview_rows[i]) end
                for i = 1, #NAV.hdr.telemetry_rows do mui.refresh(NAV.hdr.telemetry_rows[i]) end
            elseif page == "Loadouts" then
                mui.refresh(config.presets.selected)
                mui.refresh(config.presets.cloud_status)
            end
        end
    end

    ---
    --- Callbacks
    ---
    local callbacks, events = {}, {} do
        function callbacks.start()
            c_logger.log('Welcome back, %s!', user.name)

            if config.global.welcome_msg:get() then
                client.color_log(180, 160, 255, "specter  \0"); client.color_log(255, 255, 255, "Welcome to specter.lua")
                client.color_log(180, 160, 255, "specter  \0"); client.color_log(255, 255, 255, "Public mode is active, builder presets loaded as default.")
            end

            client.delay_call(0.25, function ()
                config.builder.antiaim_state:set('Standing')
                antiaim_presets.initialize()
                local had_saved = config_system:retrieve_local()
                config_system.loaded_once = true
                pcall(config.global.apply_name)

                if not had_saved then
                    -- first start: the recommended setup
                    antiaimbot_builder.load_defaults()
                    pcall(settings.recommended)
                    pcall(config_system.save_local, config_system, true)
                end
            end)
        end

        -- what is visible: the open page on the left, navigation (+ the page's side panel) on the right.
        -- Everything not display()ed here is hidden by the menu wrapper.
        function callbacks.menu()
            local NAV = config.navigation
            local H, P = NAV.hdr, NAV.side
            local page = NAV.page()
            local sub = NAV.subpage()
            local AA, V, M, R = config.antiaimbot, config.visuals, config.miscellaneous, config.ragebot

            if page == "Home" then
                H.greeting:display()
                H.gap_home:display()
                H.telemetry:display()
                for i = 1, #H.telemetry_rows do H.telemetry_rows[i]:display() end
                H.gap_home1:display()
                H.overview:display()
                for i = 1, #H.overview_rows do H.overview_rows[i]:display() end
                H.gap_home2:display()
                H.stats:display()
                H.gap:display()
                config.stats.scope:display()
                for i = 1, #config.stats.lines do config.stats.lines[i]:display() end
                config.stats.reset:display()

                P.other:display()
                P.gap:display()
                config.global.name_override:display()
                if config.global.name_override:get() then config.global.display_name:display() end
                config.global.name_hint:display()

            elseif page == "Ragebot" then
                if sub == "Resolver" and TIER.HAS_RESOLVER then
                    local RS = config.resolver
                    H.resolver:display()
                    H.gap:display()
                    RS.enabled:display()
                    if RS.enabled:get() then
                        config.uix.res_hint:display()
                        for _, row in ipairs(RS.info) do row:display() end
                        if RS.ping_scale then
                            RS.ping_scale:display()
                            if RS.ping_scale:get() then
                                RS.ping_mode:display()
                                if RS.ping_mode:get() == "Manual" then RS.ping_manual:display() end
                                RS.ping_row:display()
                            end
                        end
                        RS.log:display()
                    end
                    -- Resolver safety (it lives on the Resolver page; the tiers without the resolver have it on Accuracy)
                    local R = config.ragebot
                    R.safety:display()
                    if R.safety:get() then
                        R.smart_baim:display()
                        if R.smart_baim:get() then R.smart_conf:display() end
                        R.safety_on:display()
                        R.safety_misses:display()
                        if not R.smart_baim:get() then R.safety_hp:display() end
                    end

                    P.tools:display()
                    P.gap:display()
                    RS.reset:display()
                    V.scan_antiaim:display()
                    V.scan_antiaim_color:display()

                elseif sub == "Tuning" and TIER.HAS_TUNING then
                    local T = config.tuning
                    H.tuning:display()
                    H.gap:display()
                    T.air:display()
                    T.air_key:display()
                    if T.air:get() then
                        T.air_hc:display()
                        T.air_scale:display()
                        T.air_weapon:display()
                        T.air_dmg:display()
                        T.air_dmg_key:display()
                    end
                    T.ground:display()
                    if T.ground:get() then T.ground_min:display() end
                    T.noscope:display()
                    if T.noscope:get() then T.noscope_hc:display() end

                    T.profiles_gap:display()
                    T.profiles_hdr:display()
                    T.profiles:display()
                    if T.profiles:get() then
                        T.group:display()
                        local w = T.wp[T.group:get()] or T.wp.Other
                        w.on:display()
                        if w.on:get() then
                            w.hc:display()
                            w.dmg:display()
                        end
                    end

                    P.peek:display()
                    P.gap:display()
                    T.peek:display()
                    if T.peek:get() then
                        T.peek_hc:display()
                        T.peek_dmg:display()
                        T.peek_scope:display()
                        T.peek_baim:display()
                    end
                    T.hdr_move:display()
                    T.land_stop:display()
                    T.air_stop:display()
                    if T.air_stop:get() then T.air_stop_duck:display() end
                    T.peek_knife:display()
                    T.qp_weapon:display()
                    local qg = T["qp_" .. T.qp_weapon:get():lower()]
                    if qg then qg:display() end
                    T.force_shot:display()
                    T.force_shot_hc:display()
                    T.fd_speed:display()
                    T.hdr_bot:display()
                    T.peek_bot:display()
                    T.peek_bot_key:display()
                    if T.peek_bot:get() then
                        T.peek_bot_dist:display()
                        T.peek_bot_hitboxes:display()
                        T.peek_bot_weapons:display()
                        T.peek_bot_show:display()
                        T.peek_bot_target:display()
                        T.peek_bot_limit:display()
                    end
                    T.hdr_fun:display()
                    T.bizon:display()
                    T.bizon_key:display()
                    if T.bizon:get() then
                        T.bizon_exploit:display()
                        T.bizon_hc:display()
                        T.bizon_dmg:display()
                        T.bizon_jump:display()
                    end

                elseif TIER.HAS_RAGEBOT_EXTRA then
                    H.rage:display()
                    H.gap:display()
                    R.hdr_accuracy:display()
                    R.backtrack_optimization:display()
                    if R.backtrack_optimization:get() then R.backtrack_level:display() end
                    R.dormant:display()
                    R.dormant_key:display()
                    if R.dormant:get() then
                        R.dormant_damage:display()
                        R.dormant_hitboxes:display()
                        R.dormant_hc:display()
                    end
                    R.extended_bt:display()
                    if R.extended_bt:get() then
                        R.extended_bt_mode:display()
                        R.extended_bt_amount:display()
                        R.adaptive_records:display()
                        R.ping_reducer:display()
                    end
                    R.multipoint:display()
                    if R.multipoint:get() then
                        R.multipoint_auto:display()
                        R.multipoint_hitboxes:display()
                        R.multipoint_scale:display()
                    end
                    R.predict:display()
                    if R.predict:get() then R.predict_mode:display(); R.predict_when:display() end
                    R.hdr_safety:display()
                    if not TIER.HAS_RESOLVER then
                        R.safety:display()
                        if R.safety:get() then
                            R.smart_baim:display()
                            if R.smart_baim:get() then R.smart_conf:display() end
                            R.safety_on:display()
                            R.safety_misses:display()
                            if not R.smart_baim:get() then R.safety_hp:display() end
                        end
                    end
                    R.lc_handling:display()
                    R.aimtools:display()
                    if R.aimtools:get() then
                        R.aimtools_group:display()
                        local wt = R.aimtools_w[R.aimtools_group:get()] or R.aimtools_w.Other
                        wt.baim_hp:display()
                        wt.baim_miss:display()
                        wt.baim_force:display()
                        wt.sp_hp:display()
                        wt.sp_miss:display()
                    end
                    R.hdr_targeting:display()
                    R.priority:display()
                    R.delay_invalid:display()
                    if R.delay_invalid:get() then R.delay_invalid_max:display() end
                    R.hdr_exploits:display()
                    R.dt_guard:display()
                    if R.dt_guard:get() then
                        R.dt_guard_on:display()
                        if c_table.contains(R.dt_guard_on:get() or {}, "After misses") then R.dt_guard_misses:display() end
                    end
                    R.auto_os:display()
                    if R.auto_os:get() then
                        R.auto_os_states:display()
                        R.auto_os_avoid:display()
                    end
                    R.unsafe_charge:display()
                    if R.unsafe_charge:get() then R.unsafe_charge_ticks:display() end
                    M.automatic_tp:display()
                    if M.automatic_tp:get() then
                        M.automatic_tp_weapons:display()
                        M.automatic_tp_delay:display()
                        M.automatic_tp_cross:display()
                    end

                    P.jumpscout:display()
                    P.gap:display()
                    M.jumpscout:display()
                    if M.jumpscout:get() then
                        M.jumpscout_autostop:display()
                        if M.jumpscout_autostop:get() then M.jumpscout_autostop_key:display() end
                    end
                end

            elseif page == "Anti Aimbot" then
                NAV.aa_enable:display()

                if sub == "Builder" and TIER.HAS_BUILDER then
                    H.builder:display()
                    H.gap:display()
                    AA.preset:display()

                    if AA.preset:get() == "Constructor" then
                        config.builder.antiaim_state:display()

                        local list = antiaimbot_builder.settings[config.builder.antiaim_state:get()]
                        local show = true
                        if list.enabled then
                            list.enabled:display()
                            show = list.enabled:get()
                        end

                        if show then
                            list.gap_yaw:display()
                            list.hdr_yaw:display()
                            list.pitch:display()
                            if list.pitch:get() == "Custom" or list.pitch:get() == "Constructor" then
                                list.pitch_amount:display()
                            end
                            list.yaw_base:display()
                            list.yaw_type:display()

                            local yaw_type = list.yaw_type:get()
                            local delayed_switch = false
                            if yaw_type == "Left & Right" or yaw_type == "Flick" or yaw_type == "Sway" or yaw_type == "Spin between" then
                                list.yaw_left:display()
                                list.yaw_right:display()
                                if yaw_type == "Left & Right" then
                                    list.yaw_delayed_switch:display()
                                    if list.yaw_delayed_switch:get() then
                                        delayed_switch = true
                                        list.yaw_switch_delay:display()
                                        if list.yaw_logic then list.yaw_logic:display() end
                                        local lg = list.yaw_logic and list.yaw_logic:get() or "Random"
                                        if lg == "Random" or lg == "Sequence" then list.yaw_switch_delay_second:display() end
                                        if lg == "Sequence" and list.yaw_seq_len then
                                            list.yaw_seq_len:display()
                                            if list.yaw_seq_len:get() >= 3 then list.yaw_seq3:display() end
                                            if list.yaw_seq_len:get() >= 4 then list.yaw_seq4:display() end
                                        end
                                    end
                                else
                                    list.yaw_delay:display()
                                    list.yaw_speed:display()
                                end
                            elseif yaw_type ~= "Off" then
                                list.yaw_amount:display()
                            end

                            list.gap_mod:display()
                            list.hdr_mod:display()
                            list.yaw_jitter:display()
                            if list.yaw_jitter:get() ~= "Off" then
                                list.jitter_value:display()
                                list.jitter_randomize:display()
                            end

                            if not delayed_switch then
                                list.gap_body:display()
                                list.hdr_body:display()
                                list.body_yaw:display()
                                local body = list.body_yaw:get()
                                if body ~= "Off" and body ~= "Sync" and body ~= "Freestand" then
                                    list.body_value:display()
                                end
                            end
                        end
                    else
                        config.uix.builder_hint:display()
                    end

                    P.advanced:display()
                    P.gap:display()
                    AA.air_exploit:display()
                    AA.air_exploit_hotkey:display()
                    AA.ideal_tick:display()
                    AA.ideal_tick_hotkey:display()

                elseif sub == "Defensive" and TIER.HAS_DEFENSIVE then
                    H.defensive:display()
                    H.gap:display()
                    AA.defensive_aa:display()

                    if AA.defensive_aa:get() then
                        AA.defensive_preset:display()
                        local preset = AA.defensive_preset:get()

                        if preset == "Auto" then
                            AA.defensive_conditions_auto:display()
                        elseif preset == "Constructor" then
                            config.builder.defensive_state:display()

                            local state = config.builder.defensive_state:get()
                            local list = antiaimbot_builder.defensive_settings[state]
                            list.enabled:display()
                            if list.enable_on then list.enable_on:display() end

                            if list.enabled:get() and list.pitch then
                                list.pitch:display()
                                if list.pitch:get() == "Custom" or list.pitch:get() == "Constructor" then
                                    list.pitch_custom:display()
                                end
                                if list.pitch:get() == "Cycling" and list.pitch_cycle then list.pitch_cycle:display() end

                                list.yaw:display()
                                local yaw = list.yaw:get()
                                if yaw == "Delayed" or yaw == "Snap" or yaw == "Flick" or yaw == "Sway" or yaw == "Distortion" or yaw == "Random side" then
                                    list.yaw_left:display()
                                    list.yaw_right:display()
                                end
                                if yaw == "Spinbot" then
                                    list.yaw_from:display()
                                    list.yaw_to:display()
                                    list.yaw_speed:display()
                                end
                                if yaw == "Scissors" then
                                    list.yaw_left_start:display()
                                    list.yaw_left_target:display()
                                    list.yaw_right_start:display()
                                    list.yaw_right_target:display()
                                end
                                if yaw == "Scissors" or yaw == "Delayed" or yaw == "Flick" then list.yaw_delay:display() end
                                if yaw == "Sway" or yaw == "Distortion" then list.yaw_speed:display() end
                                if yaw == "Scissors" or yaw == "Delayed" or yaw == "Spinbot" or yaw == "Snap"
                                    or yaw == "Flick" or yaw == "Sway" or yaw == "Distortion" or yaw == "Random side" then
                                    list.yaw_randomize:display()
                                end
                            end
                        end

                        P.triggers:display()
                        P.gap:display()
                        AA.defensive_target:display()
                        AA.defensive_conditions:display()
                        AA.defensive_triggers:display()
                        AA.force_target_yaw:display()
                    end

                else
                    H.aa:display()
                    H.gap:display()
                    AA.hdr_angles:display()
                    AA.inverter:display()
                    AA.hdr_cond:display()
                    AA.safe_head:display()
                    if AA.safe_head:get() then AA.safe_head_conditions:display() end
                    AA.warmup_aa:display()
                    if AA.warmup_aa:get() then AA.warmup_aa_conditions:display() end

                    AA.hdr_ab:display()
                    AA.anti_brute:display()
                    if AA.anti_brute:get() then
                        AA.anti_brute_triggers:display()
                        AA.anti_brute_indicator:display()
                    end

                    AA.hdr_manual:display()
                    AA.manual_yaw:display()
                    if AA.manual_yaw:get() then
                        for i = 1, #config.manuals do config.manuals[i]:display() end
                        AA.edge_yaw:display()
                        AA.freestanding:display()
                        AA.manual_options:display()
                        AA.fs_options:display()
                        AA.freestanding_disabler_states:display()
                    end

                    -- side: modifications, fake lag
                    AA.hdr_mods:display()
                    AA.options:display()
                    config.fakelag.hdr:display()
                    config.fakelag.enable:display()
                    if config.fakelag.enable:get() then
                        config.fakelag.type:display()
                        config.fakelag.ticks:display()
                        if config.fakelag.type:get() ~= "Static" then config.fakelag.variance:display() end
                        config.fakelag.triggers:display()
                        config.fakelag.smart_lc:display()
                        if config.fakelag.smart_lc:get() then config.fakelag.lc_on:display() end
                    end
                end

            elseif page == "Visuals" then
                if sub == "Widgets" then
                    H.widgets:display()
                    H.gap:display()
                    V.watermark:display()
                    V.watermark_color:display()
                    if V.watermark:get() then
                        V.watermark_fields:display()
                        V.watermark_position:display()
                        V.watermark_style:display()
                        V.watermark_effects:display()
                    end

                    V.hdr_hitlog:display()
                    V.hitlog:display()
                    if V.hitlog:get() then
                        V.hitlog_style:display()
                        V.hitlog_show:display()
                        V.hitlog_duration:display()
                        V.hitlog_max:display()
                        for _, c in ipairs(V.hitlog_color_keys) do
                            V.hitlog_color_labels[c[1]]:display()
                            V.hitlog_colors[c[1]]:display()
                        end
                        V.hitlog_reset:display()
                    end

                    V.hdr_lists:display()
                    V.keybinds:display()
                    V.spectators:display()
                    V.panels_color:display()
                    if V.keybinds:get() or V.spectators:get() then
                        V.panels_style:display()
                        if V.keybinds:get() then
                            V.keybinds_style:display()
                            if V.keybinds_style:get() ~= "Like spectators" then V.keybinds_box:display() end
                        end
                        V.panels_options:display()
                        V.panels_reset:display()
                    end
                else
                    H.visuals:display()
                    H.gap:display()
                    V.indicators:display()
                    V.indicator_color:display()
                    if V.indicators:get() then
                        V.indicator_gradient:display()
                        if V.indicator_gradient:get() then
                            V.indicator_color2:display()
                            V.indicator_gradient_speed:display()
                        end
                    end
                    if V.indicators:get() then
                        V.indicator_style:display()
                        local style = V.indicator_style:get()
                        if style == "Nova" then V.nova_elements:display() end
                        if style == "Renewed" then V.indicator_renewed_color:display() end
                        V.indicator_vertical_offset:display()
                        V.indicator_options:display()
                    end

                    V.custom_scope:display()
                    V.custom_scope_color:display()
                    if V.custom_scope:get() then
                        V.custom_scope_length:display()
                        V.custom_scope_gap:display()
                        V.custom_scope_thickness:display()
                        V.custom_scope_options:display()
                        if c_table.contains(V.custom_scope_options:get() or {}, "Animate") then
                            V.custom_scope_speed:display()
                        end
                    end

                    V.damage_marker:display()
                    V.damage_marker_color:display()
                    V.r8_indicator:display()
                    V.r8_indicator_color:display()
                    V.manual_arrows:display()
                    V.manual_arrows_color:display()
                    if V.manual_arrows:get() then
                        V.manual_arrows_accent:display()
                        V.manual_arrows_style:display()
                        V.manual_arrows_options:display()
                        if V.manual_arrows_style:get() == "Triangles" then V.manual_arrows_size:display() end
                        V.manual_arrows_offset:display()
                    end
                end

                P.tweaks:display()
                P.gap:display()

                local CM = config.camera
                CM.hdr:display()
                CM.anim_zoom:display()
                if CM.anim_zoom:get() then CM.anim_zoom_amount:display(); CM.anim_zoom_speed:display() end
                CM.second_zoom:display()
                if CM.second_zoom:get() then CM.second_zoom_fov:display() end
                CM.viewmodel:display()
                if CM.viewmodel:get() then
                    CM.vm_fov:display(); CM.vm_x:display(); CM.vm_y:display(); CM.vm_z:display(); CM.vm_knife_left:display()
                end
                CM.tracers:display()
                CM.tracers_color:display()
                if CM.tracers:get() then CM.tracers_style:display(); CM.tracers_time:display() end

            elseif page == "Misc" then
                H.misc:display()
                H.gap:display()
                AA.hdr_anim:display()
                AA.animation_breaker:display()
                if AA.animation_breaker:get() then
                    AA.animation_breaker_leg:display()
                    AA.animation_breaker_air:display()
                    AA.animation_breaker_other:display()
                end
                M.hdr_social:display()
                M.clantag:display()
                if M.clantag:get() then M.clantag_style:display() end
                M.cheat_tweaks:display()
                if M.cheat_tweaks:get() then M.cheat_tweaks_list:display() end
                M.trashtalk:display()
                M.killsay:display()
                M.sponsor_killsay:display()
                M.hdr_utility:display()
                M.console_filter:display()
                M.aspect_mode:display()
                if M.aspect_mode:get() == "Custom" then M.aspect_ratio:display() end
                M.thirdperson_dist:display()
                M.autobuy:display()
                if M.autobuy:get() then
                    M.autobuy_primary:display()
                    M.autobuy_secondary:display()
                    M.autobuy_utility:display()
                end
                M.anti_zeus:display()
                if M.anti_zeus:get() then M.anti_zeus_distance:display() end
                M.fps_boost:display()
                if M.fps_boost:get() then M.fps_boost_list:display() end

                P.logs:display()
                P.gap:display()
                M.custom_output:display()
                M.event_logger:display()
                if M.event_logger:get() then M.console_colors:display() end

            elseif page == "Loadouts" then
                local PR, ST, GL = config.presets, config.settings, config.global
                H.loadouts:display()
                H.gap:display()
                PR.list:display()
                PR.selected:display()
                PR.load:display()
                PR.save:display()
                PR.export:display()
                PR.remove:display()
                PR.share:display()
                PR.refresh:display()
                PR.cloud_status:display()

                ST.gap:display()
                ST.label:display()
                ST.import:display()
                ST.export:display()
                ST.builtin:display()
                ST.default_aa:display()
                ST.save:display()
                ST.autosave:display()
                ST.general_gap:display()
                ST.general:display()
                ST.location:display()
                ST.location_hint:display()
                GL.public_mode:display()
                GL.welcome_msg:display()

                P.create:display()
                P.gap:display()
                PR.name:display()
                PR.create:display()
                PR.import:display()
            end

            if menu.location == "AA" then P.top:display() end

            -- navigation (right)
            NAV.brand:display()
            -- the AA tab's Fake lag box is short: there the tree gets the room instead of the info rows
            if menu.location ~= "AA" then
                NAV.gap1:display()
                for i = 1, #NAV.info do NAV.info[i]:display() end
                NAV.gap2:display()
            end
            NAV.nav_hdr:display()
            NAV.list:display()
            NAV.gap_end:display()
        end

        function callbacks.paint(ctx)
            visuals:paint()
        end

        local next_menu_tick = 0
        function callbacks.paint_ui(ctx)
            if ui_is_menu_open() then
                local now = globals.realtime()
                if now >= next_menu_tick then
                    next_menu_tick = now + 0.05
                    menu_state.visibility()
                    menu_state.live(now)
                end
            end

            c_animations:frame()

            player:paint_ui()
            visuals:paint_ui()
            miscellaneous:paint_ui()
        end

        function callbacks.predict_command(cmd)
            local me = entity_get_local_player()
            local wpn = me and entity.get_player_weapon(me) or nil

            player:predict_command(cmd, me)
            antiaimbot:predict_command(cmd, me, wpn)
        end

        function callbacks.setup_command(cmd)
            local me = entity_get_local_player()
            local wpn = me and entity.get_player_weapon(me) or nil

            player:setup_command(cmd, me, wpn)
            fakelag:setup_command(cmd, me, wpn)
            antiaimbot:setup_command(cmd, me, wpn)
            miscellaneous:setup_command(cmd, me, wpn)
        end

        function callbacks.run_command(cmd)
            player:run_command(cmd)
        end

        function callbacks.finish_command(cmd)
            local me = entity_get_local_player()
            local wpn = me and entity.get_player_weapon(me) or nil

            antiaimbot:finish_command(cmd, me, wpn)
            player:finish_command(cmd, me, wpn)
        end

        function callbacks.net_update_end()
            player:net_update_end()
            miscellaneous:net_update_end()
            if aa_stealer then
                aa_stealer:on_net_update_end()
            end
        end

        function callbacks.console_input(text)
            if text == 'bt_debug' then
                user.debug = not user.debug

                return true
            end
        end

        function callbacks.shutdown()
            if config_system.loaded_once and config.settings.autosave:get() then
                pcall(config_system.save_local, config_system)
            end

            local steps = {
                function() miscellaneous.clantag.reset() end,
                function() antiaimbot.main.get_instance():reset() end,
                function() antiaim_presets.flush() end,
                function() client.exec('con_filter_enable 0;con_filter_text "";') end,
                function() override.unset(reference.ragebot.fakeduck) end,
                function() override.unset(reference.fakelag.enable) end,
                function() override.unset(reference.fakelag.amount) end,
                function() override.unset(reference.fakelag.limit) end,
                function() override.unset(reference.fakelag.variance) end,
                function() override.unset(reference.misc.draw_output) end,
                function() override.unset(reference.misc.air_strafe) end,
                function() client.set_cvar("r_aspectratio", 0) end,
                function() client.set_cvar("cam_idealdist", 150) end,
                function() menu_state.visibility(true) end,
            }
            for i = 1, #steps do pcall(steps[i]) end

            c_logger.log('Shutting down...')
        end

        ---
        --- Anti-aim stealer
        ---
        if TIER.HAS_AA_STEALER then
        aa_stealer = {
            scanning = {},
            samples = {},
            last_sim = {},
            MIN_SAMPLES = 16,
            MAX_SAMPLES = 40,
        }

        local STEAL_STATES = c_constant.STATE_LIST
        local STATE_SHORT = {
            ["Standing"] = "ST", ["Slow-motion"] = "SW", ["Moving"] = "MV", ["Crouching"] = "CR",
            ["Crouch moving"] = "CM", ["Air"] = "AR", ["Air & Crouch"] = "AC",
        }
        local NEXUS_STANCE = {
            ["Standing"] = "stand", ["Slow-motion"] = "move", ["Moving"] = "move", ["Crouching"] = "duck",
            ["Crouch moving"] = "duck", ["Air"] = "air", ["Air & Crouch"] = "air",
        }

        local function steal_round(v)
            return math_floor(v + 0.5)
        end

        local function steal_state(ent)
            local flags = entity_get_prop(ent, "m_fFlags") or 0
            local duck = (entity_get_prop(ent, "m_flDuckAmount") or 0) > 0.7
            if bit.band(flags, 1) == 0 then
                return duck and "Air & Crouch" or "Air"
            end
            local vx, vy = entity_get_prop(ent, "m_vecVelocity")
            local speed = vx and math_sqrt(vx * vx + vy * vy) or 0
            if duck then
                return speed > 5 and "Crouch moving" or "Crouching"
            end
            if speed <= 5 then
                return "Standing"
            end
            return speed < 100 and "Slow-motion" or "Moving"
        end

        local function new_bucket()
            local bucket = {}
            for _, state in ipairs(STEAL_STATES) do
                bucket[state] = { yaw = {}, pitch = {} }
            end
            return bucket
        end

        local function median(values)
            local sorted = {}
            for i = 1, #values do sorted[i] = values[i] end
            table_sort(sorted)
            return sorted[math_floor((#sorted + 1) / 2)] or 0
        end

        local function clusters_of(values)
            local sorted = {}
            for i = 1, #values do sorted[i] = values[i] end
            table_sort(sorted)

            local list = {}
            for _, v in ipairs(sorted) do
                local c = list[#list]
                if c and v - c.max <= 8 then
                    c.max, c.sum, c.n = v, c.sum + v, c.n + 1
                else
                    list[#list + 1] = { min = v, max = v, sum = v, n = 1 }
                end
            end

            local min_n = math_max(2, #values * 0.1)
            local out = {}
            for _, c in ipairs(list) do
                if c.n >= min_n then
                    c.center = c.sum / c.n
                    out[#out + 1] = c
                end
            end
            return out
        end

        local function nearest_cluster(clusters, v)
            local best, best_d = 1, math.huge
            for i, c in ipairs(clusters) do
                local d = math_abs(v - c.center)
                if d < best_d then best, best_d = i, d end
            end
            return best
        end

        local function pitch_mode(p)
            if p > 70 then return "Down" end
            if p < -70 then return "Up" end
            if math_abs(p) < 10 then return "Off" end
            return "Custom", steal_round(p)
        end

        function aa_stealer:is_scanning(ent)
            return self.scanning[ent] == true
        end

        function aa_stealer:reset(ent)
            self.samples[ent] = new_bucket()
            self.last_sim[ent] = nil
        end

        function aa_stealer:set_scanning(ent, on)
            self.scanning[ent] = on and true or nil
            if on and not self.samples[ent] then
                self:reset(ent)
            end
        end

        function aa_stealer:collect()
            local me = entity_get_local_player()
            if not me then return end
            local mx, my = entity_get_prop(me, "m_vecOrigin")
            if not mx then return end

            for ent in pairs(self.scanning) do
                if entity.is_alive(ent) and not entity.is_dormant(ent) then
                    local sim = entity_get_prop(ent, "m_flSimulationTime")
                    local st = sim and math_floor(sim / globals_tickinterval() + 0.5)

                    if st and st ~= self.last_sim[ent] then
                        local shifted = self.last_sim[ent] ~= nil and st < self.last_sim[ent]
                        self.last_sim[ent] = st

                        local pitch, eye_yaw = entity_get_prop(ent, "m_angEyeAngles")
                        local ox, oy = entity_get_prop(ent, "m_vecOrigin")
                        local wpn = entity.get_player_weapon(ent)
                        local last_shot = wpn and entity_get_prop(wpn, "m_fLastShotTime")
                        local shooting = last_shot ~= nil and globals_curtime() - last_shot < 0.2

                        if not shifted and not shooting and pitch and eye_yaw and ox then
                            local bucket = self.samples[ent][steal_state(ent)]
                            local flick = #bucket.pitch >= 6 and pitch < 45 and median(bucket.pitch) > 70

                            if not flick and #bucket.yaw < self.MAX_SAMPLES then
                                local to_me = math.deg(math.atan2(my - oy, mx - ox))
                                bucket.yaw[#bucket.yaw + 1] = c_math.normalize_yaw(eye_yaw - to_me - 180)
                                bucket.pitch[#bucket.pitch + 1] = pitch
                            end
                        end
                    end
                end
            end
        end

        function aa_stealer:analyze(bucket)
            local yaw = bucket.yaw
            if #yaw < self.MIN_SAMPLES then return nil end

            local clusters = clusters_of(yaw)
            if #clusters == 0 then return nil end

            local lo, hi = clusters[1].center, clusters[#clusters].center
            local res = {
                pitch = median(bucket.pitch),
                yaw_type = "180",
                offset = steal_round((lo + hi) / 2),
                jitter = "Off",
                jitter_value = 0,
                kind = "static",
            }
            if #clusters == 1 then return res end

            local span = steal_round(hi - lo)
            local runs, total, cur, len = 0, 0, nil, 0
            for i = 1, #yaw do
                local id = nearest_cluster(clusters, yaw[i])
                if id == cur then
                    len = len + 1
                else
                    if cur then runs, total = runs + 1, total + len end
                    cur, len = id, 1
                end
            end
            runs, total = runs + 1, total + len
            local avg_run = total / runs

            if #clusters == 2 then
                if avg_run >= 1.8 then
                    res.yaw_type, res.kind = "Left & Right", "left/right"
                    res.left, res.right = steal_round(lo), steal_round(hi)
                    res.delay = c_math.clamp(steal_round(avg_run), 1, 12)
                else
                    res.jitter, res.jitter_value, res.kind = "Center", span, "center"
                end
            elseif #clusters <= 5 then
                res.jitter, res.jitter_value, res.kind = "Skitter", steal_round(span / 2), #clusters .. "-way"
            else
                res.jitter, res.jitter_value, res.kind = "Random", span, "random"
            end
            return res
        end

        local function learned_body(ent, state)
            local data = resolver.database[ent]
            local m = data and resolver.memory[data.key]
            return m and m.hit_value[NEXUS_STANCE[state]]
        end

        function aa_stealer:import(ent)
            local bucket = self.samples[ent]
            if not bucket then return 0, {} end

            local done, report = 0, {}
            for _, state in ipairs(STEAL_STATES) do
                local res = self:analyze(bucket[state])
                local list = antiaimbot_builder.settings[state]

                if res and list then
                    local function set(item, ...)
                        if item then pcall(item.set, item, ...) end
                    end

                    set(list.enabled, true)

                    local pmode, pvalue = pitch_mode(res.pitch)
                    set(list.pitch, pmode)
                    if pvalue then set(list.pitch_amount, pvalue) end

                    set(list.yaw_base, "At targets")
                    set(list.yaw_type, res.yaw_type)
                    if res.yaw_type == "Left & Right" then
                        set(list.yaw_left, res.left)
                        set(list.yaw_right, res.right)
                        set(list.yaw_delayed_switch, res.delay > 1)
                        set(list.yaw_switch_delay, res.delay)
                        set(list.yaw_switch_delay_second, res.delay)
                    else
                        set(list.yaw_amount, res.offset)
                    end

                    set(list.yaw_jitter, res.jitter)
                    set(list.jitter_value, res.jitter_value)
                    set(list.jitter_randomize, 0)

                    local learned = learned_body(ent, state)
                    if res.jitter ~= "Off" then
                        set(list.body_yaw, "Jitter")
                        set(list.body_value, 0)
                    elseif learned and learned ~= 0 then
                        set(list.body_yaw, "Static")
                        set(list.body_value, learned)
                    else
                        set(list.body_yaw, "Opposite")
                    end

                    done = done + 1
                    if res.yaw_type == "Left & Right" then
                        report[#report + 1] = string_format("%s: left/right %d/%d, %dt", state, res.left, res.right, res.delay)
                    elseif res.jitter ~= "Off" then
                        report[#report + 1] = string_format("%s: %s %d (offset %d)", state, res.kind, res.jitter_value, res.offset)
                    else
                        report[#report + 1] = string_format("%s: static %d", state, res.offset)
                    end
                end
            end

            if done > 0 and antiaimbot_builder.refresh then
                pcall(antiaimbot_builder.refresh)
            end
            return done, report
        end

        function aa_stealer:progress(ent)
            local rows, ready = {}, 0
            local bucket = self.samples[ent]
            for _, state in ipairs(STEAL_STATES) do
                local n = bucket and #bucket[state].yaw or 0
                local pct = math_floor(math_min(n / self.MIN_SAMPLES, 1) * 100)
                if pct >= 100 then ready = ready + 1 end
                rows[#rows + 1] = { label = state, short = STATE_SHORT[state] or state, percent = pct }
            end
            return rows, ready
        end

        function aa_stealer:progress_text(ent)
            local rows = self:progress(ent)
            local parts = {}
            for _, row in ipairs(rows) do
                parts[#parts + 1] = string_format("%s %d%%", row.short, row.percent)
            end
            return table_concat(parts, "  ")
        end

        function aa_stealer:on_net_update_end()
            self:collect()
            if self._plist_ref and self._progress_label then
                local target = ui_get(self._plist_ref)
                if target and self.scanning[target] then
                    ui_set(self._progress_label, self:progress_text(target))
                end
            end
        end

        do
            local plist_ref = ui_reference("Players", "Players", "Player list")
            ui.new_label("Players", "Adjustments", "Anti-aim stealer")
            local progress_label = ui.new_label("Players", "Adjustments", "Select a player and enable scanning")
            local scan_toggle = ui.new_checkbox("Players", "Adjustments", "Scan anti-aim")

            ui.new_button("Players", "Adjustments", "Import to builder", function()
                local target = ui_get(plist_ref)
                if not target then return end
                if not aa_stealer:is_scanning(target) then
                    c_logger.log_error("Enable 'Scan anti-aim' for this player first.")
                    return
                end

                local done, report = aa_stealer:import(target)
                if done == 0 then
                    c_logger.log_error("Not enough samples yet (%d per stance needed).", aa_stealer.MIN_SAMPLES)
                    return
                end

                c_logger.log("Imported %d stance%s from %s", done, done == 1 and "" or "s", entity_get_player_name(target) or "?")
                for _, line in ipairs(report) do
                    c_logger.log("  %s", line)
                end
            end)

            ui.new_button("Players", "Adjustments", "Reset scan", function()
                local target = ui_get(plist_ref)
                if not target then return end
                aa_stealer:reset(target)
                ui_set(progress_label, aa_stealer:progress_text(target))
            end)

            ui.set_callback(scan_toggle, function()
                local target = ui_get(plist_ref)
                if target then
                    aa_stealer:set_scanning(target, ui_get(scan_toggle))
                end
            end)

            ui.set_callback(plist_ref, function()
                local target = ui_get(plist_ref)
                if not target then return end
                ui_set(scan_toggle, aa_stealer:is_scanning(target))
                if aa_stealer:is_scanning(target) then
                    ui_set(progress_label, aa_stealer:progress_text(target))
                else
                    ui_set(progress_label, "Select a player and enable scanning")
                end
            end)

            aa_stealer._plist_ref = plist_ref
            aa_stealer._progress_label = progress_label
        end
        end -- TIER.HAS_AA_STEALER

        --- Events
        function events.aim_fire(event)
            antiaimbot.defensive.last_shot = globals.realtime()
            miscellaneous:aim_fire(event)
        end

        function events.aim_hit(event)
            miscellaneous:aim_hit(event)
        end

        function events.aim_miss(event)
            miscellaneous:aim_miss(event)
        end

        function events.player_hurt(event)
            miscellaneous:player_hurt(event)
            visuals:player_hurt(event)

            local victim = client.userid_to_entindex(event.userid)
            local attacker = client.userid_to_entindex(event.attacker)
            if victim and attacker and victim == player.entindex and attacker ~= player.entindex then
                antiaimbot.anti_brute:on_hurt(attacker, event.dmg_health or 0, event.hitgroup or 0)
            elseif victim and attacker and victim ~= attacker and entity.is_enemy(attacker) and not entity.is_enemy(victim) then
                antiaimbot.anti_brute:on_team_hurt(attacker)
            end
        end

        function events.bullet_impact(event)
            local attacker = client.userid_to_entindex(event.userid)
            if attacker and attacker ~= player.entindex then
                antiaimbot.anti_brute:on_impact(attacker, event.x, event.y, event.z)
            end
        end

        function events.player_death(event)
            miscellaneous:player_death(event)
            local victim = client.userid_to_entindex(event.userid)
            if victim and victim == player.entindex then
                antiaimbot.anti_brute:reset()
            end
        end

        function events.round_start(event)
            antiaimbot.anti_brute:reset()
            if resolver.new_round then pcall(resolver.new_round) end

            if config.miscellaneous.autobuy:get() then
                local buy_map = {
                    ["AK-47"] = "ak47", ["M4A4"] = "m4a1", ["M4A1-S"] = "m4a1_silencer", ["Galil AR"] = "galilar", ["FAMAS"] = "famas", ["SG 553"] = "sg556", ["AUG"] = "aug",
                    ["AWP"] = "awp", ["Scout"] = "ssg08",
                    ["Heavy Pistol"] = "deagle", ["Dual Berettas"] = "elite", ["P250"] = "p250", ["Five-SeveN"] = "fiveseven", ["Tec-9"] = "tec9", ["CZ75-Auto"] = "cz75a",
                    ["Grenade"] = "hegrenade", ["Smoke"] = "smokegrenade", ["Flashbang"] = "flashbang", ["Molotov"] = "molotov", ["Incendiary"] = "incgrenade", ["Decoy"] = "decoy",
                    ["Kevlar"] = "vest", ["Kevlar + Helmet"] = "vesthelm", ["Defuse Kit"] = "defuser", ["Zeus"] = "taser"
                }

                local lp = entity_get_local_player()
                if not lp then return end
                local team = entity_get_prop(lp, "m_iTeamNum")
                local cmd = {}

                local primary = config.miscellaneous.autobuy_primary:get()
                if primary == "Autosniper" then
                    cmd[#cmd + 1] = "buy " .. (team == 3 and "scar20" or "g3sg1")
                elseif primary ~= "Off" then
                    cmd[#cmd + 1] = "buy " .. (buy_map[primary] or "")
                end

                local secondary = config.miscellaneous.autobuy_secondary:get()
                if secondary ~= "Off" then
                    cmd[#cmd + 1] = "buy " .. (buy_map[secondary] or "")
                end

                local utility = config.miscellaneous.autobuy_utility:get()
                for i = 1, #utility do
                    cmd[#cmd + 1] = "buy " .. (buy_map[utility[i]] or "")
                end

                if #cmd > 0 then
                    client.exec(table_concat(cmd, "; "))
                end
            end
        end
    end

    ---
    --- Start up
    ---
    do
        callbacks.start()

        menu.set_callback(callbacks.menu)
        menu.update()

        local function guard(name, fn)
            local last = -10
            -- no table per call (paint / setup_command run this every frame / tick)
            local function finish(ok, ...)
                if ok then return ... end
                local now = globals.realtime()
                if now - last > 5 then
                    last = now
                    client.error_log(string_format("[specter] %s: %s", name, tostring((...))))
                end
            end
            return function(...)
                return finish(pcall(fn, ...))
            end
        end

        client.set_event_callback('paint', guard('paint', callbacks.paint))
        client.set_event_callback('paint_ui', guard('paint_ui', callbacks.paint_ui))
        client.set_event_callback('predict_command', guard('predict_command', callbacks.predict_command))
        client.set_event_callback('setup_command', guard('setup_command', callbacks.setup_command))
        client.set_event_callback('run_command', guard('run_command', callbacks.run_command))
        client.set_event_callback('finish_command', guard('finish_command', callbacks.finish_command))

        client.set_event_callback('net_update_end', guard('net_update_end', callbacks.net_update_end))
        client.set_event_callback('console_input', guard('console_input', callbacks.console_input))
        client.set_event_callback('shutdown', guard('shutdown', callbacks.shutdown))

        --- Events
        client.set_event_callback('aim_fire', guard('aim_fire', events.aim_fire))
        client.set_event_callback('aim_hit', guard('aim_hit', events.aim_hit))
        client.set_event_callback('aim_miss', guard('aim_miss', events.aim_miss))

        client.set_event_callback('player_hurt', guard('player_hurt', events.player_hurt))
        client.set_event_callback('bullet_impact', guard('bullet_impact', events.bullet_impact))
        client.set_event_callback('player_death', guard('player_death', events.player_death))
        client.set_event_callback('round_start', guard('round_start', events.round_start))
    end

    --- Splash screen
    do
        local T0 = globals.realtime()
        local DUR, FADE = 4.8, 0.7
        local alive = true
        local st = { bar = 0, flash = 0, skip = nil }
        local AR, AG, AB = 180, 160, 255
        local STEPS = {
            { 0.00, "initializing" },
            { 0.16, "loading anti-aim builder" },
            { 0.36, "starting resolver" },
            { 0.56, "building interface" },
            { 0.76, "restoring config" },
            { 0.97, "ready" },
        }

        local function rnd(a, b) return a + (b - a) * math.random() end
        local particles = {}
        for i = 1, 28 do
            particles[i] = { x = rnd(-1, 1), y = rnd(0, 1), s = rnd(0.35, 1), p = rnd(0, 6.28) }
        end

        local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end
        local function out_cubic(t) t = clamp01(t); return 1 - (1 - t) ^ 3 end
        local function out_back(t)
            t = clamp01(t)
            local c1 = 1.70158
            return 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
        end

        local function rounded(x, y, w, h, rad, r, g, b, a)
            if a <= 0 or w <= 0 or h <= 0 then return end
            rad = math_max(0, math_min(rad, math_floor(h / 2), math_floor(w / 2)))
            renderer.rectangle(x + rad, y, w - rad * 2, h, r, g, b, a)
            if rad > 0 then
                renderer.rectangle(x, y + rad, rad, h - rad * 2, r, g, b, a)
                renderer.rectangle(x + w - rad, y + rad, rad, h - rad * 2, r, g, b, a)
                if a >= 32 then
                    renderer.circle(x + rad, y + rad, r, g, b, a, rad, 180, 0.25)
                    renderer.circle(x + w - rad, y + rad, r, g, b, a, rad, 90, 0.25)
                    renderer.circle(x + rad, y + h - rad, r, g, b, a, rad, 270, 0.25)
                    renderer.circle(x + w - rad, y + h - rad, r, g, b, a, rad, 0, 0.25)
                end
            end
        end

        local function shimmer(i, now, speed)
            local t = 0.5 + 0.5 * math.sin(now * (speed or 1.8) - i * 0.55)
            return math_floor(245 + (AR - 245) * t), math_floor(245 + (AG - 245) * t), math_floor(250 + (AB - 250) * t)
        end

        client.set_event_callback("paint_ui", function()
            if not alive then return end
            local now = globals.realtime()
            local ft = globals_frametime()
            local t = now - T0

            -- click / ESC skips straight to the fade out
            if not st.skip and t > 0.4 and (client.key_state(0x01) or client.key_state(0x1B)) then
                st.skip = t
            end
            local fade_start = st.skip and math_min(st.skip, DUR - FADE) or (DUR - FADE)
            if t > fade_start + FADE then alive = false return end
            local fade = 1 - clamp01((t - fade_start) / FADE)
            local out = out_cubic(1 - fade)             -- 0 -> 1 while leaving

            local sw, sh = client.screen_size()
            local cx, cy = math_floor(sw / 2), math_floor(sh / 2 - 30 - out * 14)
            local A = fade

            ---
            --- backdrop
            ---
            local bg = out_cubic(t / 0.45) * A
            renderer.rectangle(0, 0, sw, sh, 6, 6, 9, math_floor(165 * bg))
            renderer.gradient(0, 0, sw, math_floor(sh * 0.35), 0, 0, 0, math_floor(150 * bg), 0, 0, 0, 0, false)
            renderer.gradient(0, math_floor(sh * 0.65), sw, math_floor(sh * 0.35) + 1, 0, 0, 0, 0, 0, 0, 0, math_floor(150 * bg), false)
            -- soft accent bloom behind the logo
            for i = 1, 7 do
                renderer.circle(cx, cy, AR, AG, AB, math_floor(3 * bg), 30 + i * 24, 0, 1)
            end

            -- drifting particles
            for _, p in ipairs(particles) do
                local py = (p.y - t * 0.07 * p.s) % 1
                local px = cx + p.x * 260 + math.sin(now * 0.6 + p.p) * 10
                local yy = cy + 150 - py * 300
                local tw = 0.5 + 0.5 * math.sin(now * 2.2 + p.p)
                local edge = math.sin(py * math.pi)          -- fade at top / bottom of the column
                local pa = math_floor(110 * p.s * tw * edge * bg)
                if pa > 2 then
                    local sz = p.s > 0.75 and 2 or 1
                    renderer.rectangle(math_floor(px), math_floor(yy), sz, sz, AR, AG, AB, pa)
                end
            end

            ---
            --- ring logo
            ---
            local draw = out_cubic((t - 0.15) / 0.9)
            local R = 34 + out * 22
            local la = A * (1 - out * 0.6)
            if draw > 0 then
                renderer.circle_outline(cx, cy, 0, 0, 0, math_floor(90 * la), R, 0, 1, 2)
                renderer.circle_outline(cx, cy, AR, AG, AB, math_floor(60 * la), R, 90, draw, 6)
                renderer.circle_outline(cx, cy, AR, AG, AB, math_floor(255 * la), R, 90, draw, 2)
                -- head of the drawing stroke
                local ha = math.rad(90 - 360 * draw)
                renderer.circle(cx + math.cos(ha) * R, cy - math.sin(ha) * R, 255, 255, 255, math_floor(240 * la * (draw < 1 and 1 or 0.35)), 2.2, 0, 1)
            end
            if draw >= 0.999 then
                -- orbiting light once the ring is closed
                local oa = math.rad(90 - (now * 160) % 360)
                renderer.circle(cx + math.cos(oa) * R, cy - math.sin(oa) * R, AR, AG, AB, math_floor(90 * la), 5, 0, 1)
                renderer.circle(cx + math.cos(oa) * R, cy - math.sin(oa) * R, 255, 255, 255, math_floor(255 * la), 2, 0, 1)
            end
            -- inner counter-rotating segments
            local inner = out_cubic((t - 0.35) / 0.6) * la
            if inner > 0.01 then
                local spin = (now * 120) % 360
                for k = 0, 2 do
                    renderer.circle_outline(cx, cy, AR, AG, AB, math_floor(170 * inner), R - 9, spin + k * 120, 0.16, 2)
                    renderer.circle_outline(cx, cy, 255, 255, 255, math_floor(60 * inner), R - 15, -spin * 1.4 + k * 120 + 60, 0.10, 1)
                end
            end
            -- monogram
            local mono = out_back((t - 0.45) / 0.5) * la
            if mono > 0.01 then
                local mw, mh = renderer.measure_text("+", "S")
                local my_ = cy - math_floor(mh / 2) + math_floor((1 - clamp01(mono)) * 6)
                renderer.text(cx - math_floor(mw / 2) + 1, my_ + 1, 0, 0, 0, math_floor(150 * clamp01(mono)), "+", 0, "S")
                local sr, sg, sb = shimmer(1, now, 2.4)
                renderer.text(cx - math_floor(mw / 2), my_, sr, sg, sb, math_floor(255 * clamp01(mono)), "+", 0, "S")
            end

            ---
            --- name, letter by letter
            ---
            local name = "SPECTER"
            local spacing = 4
            local total = 0
            local widths = {}
            for i = 1, #name do
                widths[i] = renderer.measure_text("+", name:sub(i, i))
                total = total + widths[i] + (i < #name and spacing or 0)
            end
            local nx = cx - math_floor(total / 2)
            local ny = cy + R + 18
            for i = 1, #name do
                local e = out_back((t - 0.55 - i * 0.055) / 0.45)
                local ea = clamp01((t - 0.55 - i * 0.055) / 0.3) * A
                if ea > 0.01 then
                    local ch = name:sub(i, i)
                    local yo = math_floor((1 - e) * 10)
                    local cr, cg, cb = shimmer(i, now)
                    renderer.text(nx + 1, ny + yo + 1, 0, 0, 0, math_floor(140 * ea), "+", 0, ch)
                    renderer.text(nx, ny + yo, cr, cg, cb, math_floor(255 * ea), "+", 0, ch)
                end
                nx = nx + widths[i] + spacing
            end
            local _, nh = renderer.measure_text("+", "S")

            -- tagline
            local tag_a = clamp01((t - 1.0) / 0.4) * A
            if tag_a > 0.01 then
                local tag = string.upper(user.role or "beta") .. "   \194\183   GAMESENSE   \194\183   HVH"
                local tw = renderer.measure_text("-", tag)
                renderer.text(cx - math_floor(tw / 2), ny + nh + 4, 140, 140, 155, math_floor(255 * tag_a), "-", 0, tag)
            end

            ---
            --- progress bar
            ---
            local by = ny + nh + 24
            local BW, BH = 240, 4
            local bar_a = clamp01((t - 1.0) / 0.35) * A
            local target = out_cubic((t - 1.1) / 1.9)
            if st.skip then target = 1 end
            st.bar = st.bar + (target - st.bar) * math_min(1, ft * 9)
            if st.bar > 0.995 and target >= 1 then st.flash = st.flash + (1 - st.flash) * math_min(1, ft * 6) end
            if bar_a > 0.01 then
                local bx = cx - BW / 2
                rounded(bx - 1, by - 1, BW + 2, BH + 2, 3, 255, 255, 255, math_floor(16 * bar_a))
                rounded(bx, by, BW, BH, 2, 20, 20, 28, math_floor(230 * bar_a))
                local fw = math_floor(BW * st.bar)
                if fw > 0 then
                    renderer.gradient(bx, by, fw, BH, AR, AG, AB, math_floor(200 * bar_a), 255, 255, 255, math_floor(255 * bar_a), true)
                    -- glowing head
                    renderer.circle(bx + fw, by + BH / 2, AR, AG, AB, math_floor(80 * bar_a), 6, 0, 1)
                    renderer.circle(bx + fw, by + BH / 2, 255, 255, 255, math_floor(255 * bar_a), 2.5, 0, 1)
                end
                if st.flash > 0.01 then
                    rounded(bx - 3, by - 3, BW + 6, BH + 6, 5, AR, AG, AB, math_floor(40 * st.flash * (1 - out) * bar_a))
                end

                -- step label + percent
                local label = STEPS[1][2]
                for _, s in ipairs(STEPS) do
                    if st.bar >= s[1] then label = s[2] end
                end
                local pct = string_format("%d%%", math_floor(st.bar * 100 + 0.5))
                local dots = st.bar < 0.97 and string.rep(".", math_floor(now * 3) % 4) or ""
                renderer.text(bx, by + 10, 170, 170, 185, math_floor(255 * bar_a), "", 0, label .. dots)
                local pw = renderer.measure_text("b", pct)
                renderer.text(bx + BW - pw, by + 10, AR, AG, AB, math_floor(255 * bar_a), "b", 0, pct)
            end

            ---
            --- welcome line
            ---
            local wa = clamp01((st.bar - 0.97) / 0.03) * clamp01(st.flash * 1.5) * A
            if wa > 0.01 then
                local w1 = "welcome back, "
                local w2 = tostring(user.name or "user")
                local ww1 = renderer.measure_text("", w1)
                local ww2 = renderer.measure_text("b", w2)
                local wx = cx - math_floor((ww1 + ww2) / 2)
                local wy = by + 34 + math_floor((1 - wa) * 4)
                renderer.text(wx, wy, 200, 200, 212, math_floor(255 * wa), "", 0, w1)
                renderer.text(wx + ww1, wy, AR, AG, AB, math_floor(255 * wa), "b", 0, w2)
            end

            if t > 0.6 and not st.skip and st.bar < 0.97 then
                local hint = "click to skip"
                local hw = renderer.measure_text("-", string.upper(hint))
                renderer.text(cx - math_floor(hw / 2), sh - 40, 110, 110, 122, math_floor(160 * bg), "-", 0, string.upper(hint))
            end
        end)
    end
end)()

-- ── rage override: hit chance / damage per situation (air, ground, noscope, weapon profiles), smart peek assist ──
local ref_hc, ref_mindmg
pcall(function() ref_hc = ui.reference("RAGE", "Aimbot", "Minimum hit chance") end)
if not ref_hc then pcall(function() ref_hc = ui.reference("RAGE", "Aimbot", "Hitchance") end) end
pcall(function() ref_mindmg = ui.reference("RAGE", "Aimbot", "Minimum damage") end)

-- the controls live in the specter menu (Ragebot > Tuning); plain references come through SPECTER_SHARED
local RUI = (SPECTER_SHARED and SPECTER_SHARED.rage_ui) or {}
local RAGE_READY = RUI.air ~= nil and RUI.peek ~= nil
local air_enable_lua, air_hc_bind_lua, air_hc_lua = RUI.air, RUI.air_key, RUI.air_hc
local air_dmg_bind_lua, air_mindmg_lua, air_weapon, vel_scale = RUI.air_dmg_key, RUI.air_dmg, RUI.air_weapon, RUI.air_scale
local ground_hc_enable, ground_hc_min = RUI.ground, RUI.ground_min
local noscope_enable, noscope_hc = RUI.noscope, RUI.noscope_hc
local peek_enable, peek_hc_bonus, peek_mindmg_bonus = RUI.peek, RUI.peek_hc, RUI.peek_dmg
local peek_auto_scope, peek_prefer_body = RUI.peek_scope, RUI.peek_baim

-- weapon profiles: item definition index -> profile group
local WP_GROUP = {
    [11] = "Auto", [38] = "Auto", [9] = "AWP", [40] = "Scout", [1] = "Deagle", [64] = "Revolver",
    [2] = "Pistols", [3] = "Pistols", [4] = "Pistols", [30] = "Pistols", [32] = "Pistols", [36] = "Pistols",
    [61] = "Pistols", [63] = "Pistols",
}

local function weapon_profile(id)
    if not RUI.profiles or not ui.get(RUI.profiles) then return nil, nil end
    local p = RUI.wp and RUI.wp[WP_GROUP[id] or "Other"]
    if not p or not ui.get(p.on) then return nil, nil end
    return ui.get(p.hc), ui.get(p.dmg)
end

-- Bizon air spray (Tuning > Fun): PP-Bizon (64 rounds, 26) in the air, with the air exploit when that is asked: hit chance
-- and min damage down to the sliders and automatic fire on, so the aimbot empties the mag at whoever it sees while flying
local ref_autofire
pcall(function() ref_autofire = ui.reference("RAGE", "Aimbot", "Automatic fire") end)
local bizon_saved_fire = nil
local function bizon_active(lp, id, on_ground)
    if id ~= 26 or on_ground or not RUI.bizon or not ui.get(RUI.bizon) then return false end
    if RUI.bizon_key and not ui.get(RUI.bizon_key) then return false end
    if RUI.bizon_exploit and ui.get(RUI.bizon_exploit) and not (SPECTER_SHARED and SPECTER_SHARED.air_exploit) then return false end
    return true
end
local function bizon_fire(on)
    if not ref_autofire then return end
    if on then
        if bizon_saved_fire == nil then bizon_saved_fire = ui.get(ref_autofire) end
        if ui.get(ref_autofire) ~= true then pcall(ui.set, ref_autofire, true) end
    elseif bizon_saved_fire ~= nil then
        pcall(ui.set, ref_autofire, bizon_saved_fire)
        bizon_saved_fire = nil
    end
end

local rage_saved = {}
local current_weapon = nil

local function override_value(ref, slot, key, want, lo, hi, label, quiet)
    if not ref then return end
    local cur = ui.get(ref)
    local wrote_key = "wrote_" .. key
    if want ~= nil then
        want = math.max(lo, math.min(hi, math.floor(want + 0.5)))
        if slot[key] == nil then
            slot[key] = cur
        elseif slot[wrote_key] ~= nil and cur ~= slot[wrote_key] then
            slot[key] = cur
        end
        if cur ~= want then pcall(ui.set, ref, want) end
        slot[wrote_key] = want
    elseif slot[key] ~= nil then
        if slot[wrote_key] == nil or cur == slot[wrote_key] then
            pcall(ui.set, ref, slot[key])
        end
        slot[key], slot[wrote_key] = nil, nil
    end
end

local function apply_rage(hc, dmg, quiet)
    if current_weapon == nil then return end
    local slot = rage_saved[current_weapon]
    if not slot then
        slot = {}
        rage_saved[current_weapon] = slot
    end
    override_value(ref_hc, slot, "hc", hc, 0, 100, "hit chance", quiet)
    override_value(ref_mindmg, slot, "dmg", dmg, 0, 126, "min damage", quiet)
end

local function restore_rage()
    apply_rage(nil, nil)
    bizon_fire(false)
end

local function weapon_id(lp)
    local wpn = entity.get_player_weapon(lp)
    return wpn and entity.get_prop(wpn, "m_iItemDefinitionIndex") or nil
end

local function air_weapon_ok(id)
    local sel = ui.get(air_weapon)
    if sel == "Scout" then return id == 40 end
    if sel == "AWP" then return id == 9 end
    if sel == "Deagle" then return id == 1 end
    return true
end

local peek = { state = "idle", start = 0, stop = 0, origin = nil, fired = false, baim_target = nil, last_speed = 0 }

local function release_peek_baim()
    if peek.baim_target then
        pcall(plist.set, peek.baim_target, "Override prefer body aim", "-")
        peek.baim_target = nil
    end
end

local function update_peek(cmd, lp, speed, on_ground, curtime)
    if not ui.get(peek_enable) or not on_ground then
        peek.state = "idle"
        release_peek_baim()
        return nil
    end

    local ox, oy = entity.get_prop(lp, "m_vecOrigin")
    local dist = 0
    if peek.origin and ox then
        local dx, dy = ox - peek.origin[1], oy - peek.origin[2]
        dist = math.sqrt(dx * dx + dy * dy)
    end

    local bonus = nil
    if peek.state ~= "idle" and not client.current_threat() then
        peek.state = "idle"
        release_peek_baim()
        return nil
    end
    if peek.state == "idle" then
        if peek.last_speed < 20 and speed > 50 then
            peek.state, peek.start, peek.fired = "out", curtime, false
            peek.origin = { ox or 0, oy or 0 }
        end
    elseif peek.state == "out" then
        if (speed < 20 and peek.last_speed > 40) or (speed < 15 and dist > 40) then
            peek.state, peek.stop = "hold", curtime
        elseif dist > 30 and speed > 30 and client.current_threat() and not peek.fired then
            bonus = { hc = math.floor(ui.get(peek_hc_bonus) * 0.5), dmg = 0 }
        end
        if curtime - peek.start > 1.2 then peek.state = "idle" end
    elseif peek.state == "hold" then
        if curtime - peek.stop < 0.5 then
            bonus = { hc = ui.get(peek_hc_bonus), dmg = ui.get(peek_mindmg_bonus) }

            if ui.get(peek_auto_scope) and not peek.fired then
                local id = weapon_id(lp)
                if id == 9 or id == 11 or id == 38 or id == 40 then
                    local scoped = entity.get_prop(lp, "m_bIsScoped")
                    if not scoped or scoped == 0 then cmd.in_attack2 = 1 end
                end
            end

            if ui.get(peek_prefer_body) and not peek.baim_target then
                local threat = client.current_threat()
                if threat then
                    pcall(plist.set, threat, "Override prefer body aim", "On")
                    peek.baim_target = threat
                end
            end

            if cmd.in_attack == 1 then peek.fired = true end
        else
            release_peek_baim()
            peek.state = speed > 50 and "in" or "idle"
        end
        if speed > 70 then peek.state = "in" end
    elseif peek.state == "in" then
        release_peek_baim()
        if speed < 10 or dist < 20 then peek.state = "idle" end
    end

    peek.last_speed = speed
    return bonus
end

client.set_event_callback("setup_command", function(cmd)
    if not RAGE_READY then return end
    local ok, err = pcall(function()
        local lp = entity.get_local_player()
        if not lp or not entity.is_alive(lp) or not ref_hc then
            restore_rage()
            release_peek_baim()
            return
        end

        local id = weapon_id(lp)
        if cmd.weaponselect ~= 0 then
            restore_rage()
            return
        end
        if current_weapon ~= nil and current_weapon ~= id then
            restore_rage()
            release_peek_baim()
        end
        current_weapon = id

        local held = entity.get_player_weapon(lp)
        local cls = held and entity.get_classname(held) or ""
        if cls == "CWeaponTaser" or cls:find("Knife", 1, true) or cls:find("Grenade", 1, true) or cls == "CC4" then
            restore_rage()
            release_peek_baim()
            return
        end

        local flags = entity.get_prop(lp, "m_fFlags") or 0
        local on_ground = bit.band(flags, 1) == 1
        local vx, vy = entity.get_prop(lp, "m_vecVelocity")
        local speed = math.sqrt((vx or 0) ^ 2 + (vy or 0) ^ 2)
        local curtime = globals.curtime()

        local slot = rage_saved[id] or {}
        local prof_hc, prof_dmg = weapon_profile(id)
        local base_hc = prof_hc or (slot.hc ~= nil and slot.hc or ui.get(ref_hc))
        local base_dmg = ref_mindmg and (prof_dmg or (slot.dmg ~= nil and slot.dmg or ui.get(ref_mindmg))) or nil
        local want_hc, want_dmg = prof_hc, prof_dmg

        local bizon = bizon_active(lp, id, on_ground)
        if bizon then
            want_hc, want_dmg = ui.get(RUI.bizon_hc), ui.get(RUI.bizon_dmg)
        elseif not on_ground then
            if ui.get(air_enable_lua) and air_weapon_ok(id) then
                if ui.get(air_hc_bind_lua) then
                    local cut = math.min(15, speed / 250 * ui.get(vel_scale) / 100 * 15)
                    want_hc = math.max(20, ui.get(air_hc_lua) - cut)
                end
                if ui.get(air_dmg_bind_lua) then
                    want_dmg = ui.get(air_mindmg_lua)
                end
            end
        elseif ui.get(noscope_enable) and (id == 9 or id == 11 or id == 38 or id == 40)
            and (entity.get_prop(lp, "m_bIsScoped") or 0) == 0 then
            want_hc = ui.get(noscope_hc)
        elseif ui.get(ground_hc_enable) and speed > 5 then
            local scaled = math.min(100, math.max(ui.get(ground_hc_min), base_hc + speed * 0.05))
            if scaled > base_hc then want_hc = scaled end
        end

        local bonus = not bizon and update_peek(cmd, lp, speed, on_ground, curtime) or nil
        -- force shot: the key's hit chance, whatever else wanted
        if RUI.force_shot and ui.get(RUI.force_shot) and RUI.force_shot_hc then
            want_hc = ui.get(RUI.force_shot_hc)
            bonus = nil
        end
        bizon_fire(bizon)
        -- auto jump: hold the bizon key on the ground and it keeps bunny hopping into the air
        if RUI.bizon and ui.get(RUI.bizon) and id == 26 and on_ground and RUI.bizon_jump and ui.get(RUI.bizon_jump)
            and RUI.bizon_key and ui.get(RUI.bizon_key) and client.current_threat() then
            cmd.in_jump = 1
        end
        if bonus then
            if bonus.hc > 0 then want_hc = math.min(100, (want_hc or base_hc) + bonus.hc) end
            if bonus.dmg > 0 and base_dmg then want_dmg = (want_dmg or base_dmg) + bonus.dmg end
        end

        apply_rage(want_hc, want_dmg, want_hc == prof_hc and want_dmg == prof_dmg)
    end)
    if not ok then client.error_log("[specter] rage overrides: " .. tostring(err)) end
end)

client.set_event_callback("paint", function()
    if not RAGE_READY then return end
    local me = entity.get_local_player()
    if me and entity.is_alive(me) then
        local w = entity.get_player_weapon(me)
        local id = w and entity.get_prop(w, "m_iItemDefinitionIndex")
        if bizon_active(me, id, bit.band(entity.get_prop(me, "m_fFlags") or 1, 1) == 1) then
            renderer.indicator(255, 120, 200, 255, "BIZON SPRAY")
        end
    end
    if not ui.get(air_enable_lua) then return end
    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then return end
    if bit.band(entity.get_prop(lp, "m_fFlags") or 0, 1) == 1 then return end
    if ui.get(air_hc_bind_lua) then renderer.indicator(120, 200, 255, 255, "AIR HC") end
    if ui.get(air_dmg_bind_lua) then renderer.indicator(255, 180, 80, 255, "AIR DMG") end
end)

client.set_event_callback("player_death", function(e)
    if client.userid_to_entindex(e.userid) == entity.get_local_player() then
        restore_rage()
        release_peek_baim()
    end
end)

client.set_event_callback("round_prestart", function()
    restore_rage()
    release_peek_baim()
    peek.state = "idle"
end)

client.set_event_callback("shutdown", function()
    restore_rage()
    release_peek_baim()
    bizon_fire(false)
end)


-- ── movement helpers for the aimbot (Tuning): quick stops, knife on the way back of quick peek, peek bot ──────────
do
    local RU = (SPECTER_SHARED and SPECTER_SHARED.rage_ui) or {}
    local function on(ref) if not ref then return false end local ok, v = pcall(ui.get, ref) return ok and v == true end
    local qp = { pcall(ui.reference, "RAGE", "Other", "Quick peek assist") }
    local qp_box, qp_key = qp[1] and qp[2] or nil, qp[1] and qp[3] or nil
    local function qp_active()
        if not qp_box then return false end
        local ok, b = pcall(ui.get, qp_box)
        local ok2, k = pcall(ui.get, qp_key)
        return ok and b and ok2 and k
    end
    local function is_gun(lp)
        local w = entity.get_player_weapon(lp)
        local cls = w and entity.get_classname(w) or ""
        return w ~= nil and not (cls == "CWeaponTaser" or cls:find("Knife", 1, true) or cls:find("Grenade", 1, true)
            or cls == "CC4" or cls:find("Flashbang", 1, true) or cls:find("Decoy", 1, true) or cls:find("Molotov", 1, true)
            or cls:find("Incendiary", 1, true) or cls:find("Smoke", 1, true))
    end
    -- full counter-strafe against the current velocity (the dormant aimbot does the same)
    local function counter(cmd, lp, min_speed)
        local vx, vy = entity.get_prop(lp, "m_vecVelocity")
        vx, vy = vx or 0, vy or 0
        if math.sqrt(vx * vx + vy * vy) < (min_speed or 15) then return false end
        local _, view_yaw = client.camera_angles()
        local diff = math.rad(math.deg(math.atan2(vy, vx)) - (view_yaw or cmd.yaw))
        cmd.forwardmove = -math.cos(diff) * 450
        cmd.sidemove = math.sin(diff) * 450
        return true
    end
    local function threat_seen()
        local t = client.current_threat()
        return t ~= nil and not entity.is_dormant(t) and entity.is_alive(t), t
    end

    local st = { air = false, land = 0, knife = nil, bot = nil, bot_t = 0, qp_saved = nil, slow_saved = nil }

    local slow = { pcall(ui.reference, "AA", "Other", "Slow motion") }
    local slow_box, slow_key = slow[1] and slow[2] or nil, slow[1] and slow[3] or nil
    local fd = { pcall(ui.reference, "RAGE", "Other", "Duck peek assist") }
    local fd_key = fd[1] and fd[2] or nil

    local function slow_release()
        if st.slow_saved and slow_box then
            pcall(ui.set, slow_box, st.slow_saved[1])
            pcall(ui.set, slow_key, st.slow_saved[2])
        end
        st.slow_saved = nil
    end

    local function qp_group(lp)
        local w = entity.get_player_weapon(lp)
        local id = w and entity.get_prop(w, "m_iItemDefinitionIndex") or 0
        if id == 40 then return "scout" elseif id == 9 then return "awp" elseif id == 11 or id == 38 then return "auto"
        elseif id == 1 then return "deagle"
        elseif id == 2 or id == 3 or id == 4 or id == 30 or id == 32 or id == 36 or id == 61 or id == 63 or id == 64 then return "pistols" end
        return "other"
    end

    -- seconds before the gun is ready that the early stop starts (a counter-strafe from full speed takes ~0.1-0.2 s;
    -- the scoped snipers need the most accuracy)
    local QP_EARLY = { awp = 0.22, scout = 0.17, auto = 0.20, deagle = 0.15, pistols = 0.11, other = 0.14 }
    -- our bullet can hurt the threat (head or chest), one result per tick
    local hurt_cache = { tick = -1 }
    local function can_hurt(lp, threat)
        local tick = globals.tickcount()
        if hurt_cache.tick == tick and hurt_cache.t == threat then return hurt_cache.v end
        local v = false
        local ex, ey, ez = client.eye_position()
        if ex then
            for _, hb in ipairs({ 0, 5 }) do
                local hx, hy, hz = entity.hitbox_position(threat, hb)
                if hx then
                    local _, dmg = client.trace_bullet(lp, ex, ey, ez, hx, hy, hz, true)
                    if (tonumber(dmg) or 0) > 0 then v = true; break end
                end
            end
        end
        hurt_cache.tick, hurt_cache.t, hurt_cache.v = tick, threat, v
        return v
    end

    local function bot_release()
        if st.qp_saved and qp_box then
            pcall(ui.set, qp_box, st.qp_saved[1])
            pcall(ui.set, qp_key, st.qp_saved[2])
        end
        st.qp_saved, st.bot = nil, nil
    end

    client.set_event_callback("setup_command", function(cmd)
        local ok, err = pcall(function()
            local lp = entity.get_local_player()
            if not lp or not entity.is_alive(lp) then st.air, st.land = false, 0; bot_release(); slow_release(); return end
            local flags = entity.get_prop(lp, "m_fFlags") or 1
            local ground = bit.band(flags, 1) == 1
            local seen, threat = threat_seen()
            local gun = is_gun(lp)

            -- on-land quick stop: the first ticks on the ground after a jump, with a threat in sight
            if ground and st.air and on(RU.land_stop) and seen and gun and cmd.in_jump == 0 then st.land = 4 end
            if st.land > 0 then
                st.land = st.land - 1
                if not (ground and cmd.in_jump == 0 and counter(cmd, lp, 20)) then st.land = 0 end
            end
            -- in-air quick stop: no air strafing into the shot, the air drag only slows us down
            if not ground and on(RU.air_stop) and seen and gun then
                if counter(cmd, lp, 30) and on(RU.air_stop_duck) then cmd.in_duck = 1 end
            end
            st.air = not ground

            -- swap to knife with auto peek: after our shot on quick peek, the knife (faster) on the way back, then the gun
            if on(RU.peek_knife) then
                local active = qp_active()
                if active and gun and cmd.in_attack == 1 and not st.knife then
                    st.knife = globals.realtime()
                    client.exec("use weapon_knife")
                elseif st.knife then
                    local vx, vy = entity.get_prop(lp, "m_vecVelocity")
                    local speed = math.sqrt((vx or 0) ^ 2 + (vy or 0) ^ 2)
                    local back = globals.realtime() - st.knife > 0.25 and speed < 10
                    if not active or back or globals.realtime() - st.knife > 1.5 then
                        client.exec("lastinv")
                        st.knife = nil
                    end
                end
            end

            -- quick peek options of the weapon in hand
            local qp_list = (gun and ground and qp_active() and RU["qp_" .. qp_group(lp)]) and (ui.get(RU["qp_" .. qp_group(lp)]) or {}) or {}
            local want_slow, want_early, want_move = false, false, false
            for _, v in ipairs(qp_list) do
                if v == "Slow motion" then want_slow = true elseif v == "Early autostop" then want_early = true
                elseif v == "Move between shots" then want_move = true end
            end
            if want_slow and slow_box then
                if not st.slow_saved then
                    local ok_b, b = pcall(ui.get, slow_box)
                    local ok_k, _, mode = pcall(ui.get, slow_key)
                    local modes = { [0] = "Always on", [1] = "On hotkey", [2] = "Toggle", [3] = "Off hotkey" }
                    st.slow_saved = { ok_b and b or false, (ok_k and modes[mode]) or "On hotkey" }
                end
                pcall(ui.set, slow_box, true)
                pcall(ui.set, slow_key, "Always on")
            elseif st.slow_saved then
                slow_release()
            end
            -- early autostop: stop before the aimbot's own stop, when the gun is ready (or about to be: a per weapon
            -- window, the time a counter-strafe takes) and our bullet can hurt the threat. After a shot the stop is held
            -- ~0.1 s (the double tap's second bullet), unless "Move between shots"
            if want_early and not st.knife then
                local now = globals.realtime()
                if cmd.in_attack == 1 and not want_move then st.qp_hold = now + 0.1 end
                local holding = now < (st.qp_hold or 0)
                local stop = holding
                if not stop and seen then
                    local w = entity.get_player_weapon(lp)
                    local ready = math.max(w and entity.get_prop(w, "m_flNextPrimaryAttack") or 0, entity.get_prop(lp, "m_flNextAttack") or 0)
                    if ready - globals.curtime() <= (QP_EARLY[qp_group(lp)] or 0.14) then stop = can_hurt(lp, threat) end
                end
                if stop and not counter(cmd, lp, 15) then
                    -- slow enough: no new input, or the stop is undone by our own keys
                    cmd.forwardmove, cmd.sidemove = 0, 0
                end
            end

            -- fake duck speed limit
            local fd_lim = RU.fd_speed and ui.get(RU.fd_speed) or 0
            if fd_lim > 0 and fd_key and ground then
                local ok_fd, fd_on = pcall(ui.get, fd_key)
                if ok_fd and fd_on then
                    local mv = math.sqrt(cmd.forwardmove ^ 2 + cmd.sidemove ^ 2)
                    if mv > fd_lim then
                        cmd.forwardmove = cmd.forwardmove * fd_lim / mv
                        cmd.sidemove = cmd.sidemove * fd_lim / mv
                    end
                end
            end

            -- peek bot: while the key is held, look for a spot left / right (across the line to the threat) from where
            -- its head is in sight, walk there; gamesense's quick peek (switched on meanwhile) brings us back after the shot
            local bot_on = on(RU.peek_bot)
            local key_ok, key_on = false, false
            if RU.peek_bot_key then key_ok, key_on = pcall(ui.get, RU.peek_bot_key) end
            if bot_on and gun then
                local w = entity.get_player_weapon(lp)
                local id = w and entity.get_prop(w, "m_iItemDefinitionIndex") or 0
                local grp = (id == 9 or id == 40) and "Snipers" or ((id == 11 or id == 38) and "Auto snipers")
                    or ((id == 1 or id == 2 or id == 3 or id == 4 or id == 30 or id == 32 or id == 36 or id == 61 or id == 63 or id == 64) and "Pistols")
                    or ((id == 7 or id == 8 or id == 10 or id == 13 or id == 16 or id == 39 or id == 60) and "Rifles") or "Other"
                local list = RU.peek_bot_weapons and ui.get(RU.peek_bot_weapons) or {}
                local okw = false
                for _, g in ipairs(list) do if g == grp then okw = true end end
                if not okw then gun = false end
            end
            -- the enemies to peek: the current threat, or every enemy in sight range (nearest first)
            local targets = {}
            if bot_on and key_ok and key_on then
                if RU.peek_bot_target and ui.get(RU.peek_bot_target) == "All enemies" then
                    local mx, my = entity.get_prop(lp, "m_vecOrigin")
                    for _, e in ipairs(entity.get_players(true)) do
                        if entity.is_alive(e) and not entity.is_dormant(e) then
                            local ex_, ey_ = entity.get_prop(e, "m_vecOrigin")
                            if ex_ and mx then targets[#targets + 1] = { e, (ex_ - mx) ^ 2 + (ey_ - my) ^ 2 } end
                        end
                    end
                    table.sort(targets, function(p1, p2) return p1[2] < p2[2] end)
                    for i = 1, #targets do targets[i] = targets[i][1] end
                elseif threat then
                    targets[1] = threat
                end
            end
            if not (bot_on and key_ok and key_on and ground and gun and #targets > 0) then
                if st.bot ~= nil or st.qp_saved then bot_release() end
                return
            end
            if not st.qp_saved and qp_box then
                local ok_b, b = pcall(ui.get, qp_box)
                local ok_k, _, mode = pcall(ui.get, qp_key)
                local modes = { [0] = "Always on", [1] = "On hotkey", [2] = "Toggle", [3] = "Off hotkey" }
                st.qp_saved = { ok_b and b or false, (ok_k and modes[mode]) or "On hotkey" }
                pcall(ui.set, qp_box, true)
                pcall(ui.set, qp_key, "Always on")
            end
            local tick = globals.tickcount()
            if tick - st.bot_t >= 4 or tick < st.bot_t then
                st.bot_t = tick
                local mx, my, mz = entity.get_prop(lp, "m_vecOrigin")
                local dist = ui.get(RU.peek_bot_dist) or 50
                local hb = RU.peek_bot_hitboxes and ui.get(RU.peek_bot_hitboxes) or {}
                local heights = {}
                for _, h in ipairs(hb) do heights[#heights + 1] = (h == "Head" and 64) or (h == "Chest" and 50) or 38 end
                if #heights == 0 then heights = { 64 } end
                -- process limit: the traces stop when this much time went into them this tick (the spot found so far stays)
                local limit = (RU.peek_bot_limit and ui.get(RU.peek_bot_limit) or 3)
                local t0 = client.timestamp and client.timestamp() or nil
                local function over() return t0 and client.timestamp() - t0 > limit end
                local found, points = nil, {}
                for _, target in ipairs(targets) do
                    local tx, ty, tz = entity.get_prop(target, "m_vecOrigin")
                    if mx and tx and not found and not over() then
                        local a = math.atan2(ty - my, tx - mx)
                        for _, d in ipairs({ dist * 0.5, dist }) do
                            for _, side in ipairs({ 1, -1 }) do
                                local sx, sy = mx + math.cos(a + side * math.pi / 2) * d, my + math.sin(a + side * math.pi / 2) * d
                                local open = false
                                if not found and not over() then
                                    for _, hz in ipairs(heights) do
                                        if not open then
                                            local frac, hit = client.trace_line(lp, sx, sy, mz + 64, tx, ty, tz + hz)
                                            if (frac and frac > 0.97) or hit == target then open = true end
                                        end
                                    end
                                    if open then found = { sx, sy } end
                                end
                                points[#points + 1] = { sx, sy, mz, open }
                            end
                        end
                    end
                end
                st.bot, st.points, st.points_t = found, points, globals.realtime()
            end
            if st.bot then
                local mx, my = entity.get_prop(lp, "m_vecOrigin")
                local dx, dy = st.bot[1] - mx, st.bot[2] - my
                if dx * dx + dy * dy > 16 then
                    local _, view_yaw = client.camera_angles()
                    local diff = math.rad(math.deg(math.atan2(dy, dx)) - (view_yaw or cmd.yaw))
                    cmd.forwardmove = math.cos(diff) * 450
                    cmd.sidemove = -math.sin(diff) * 450
                end
            end
        end)
        if not ok then client.error_log("[specter] movement: " .. tostring(err)) end
    end)
    client.set_event_callback("shutdown", function() pcall(bot_release); pcall(slow_release) end)

    -- "Show simulation": the spots the peek bot tried (green = the head is in sight from there, red = covered)
    client.set_event_callback("paint", function()
        if not (on(RU.peek_bot) and on(RU.peek_bot_show)) or not st.points or globals.realtime() - (st.points_t or 0) > 0.5 then return end
        local lp = entity.get_local_player()
        if not lp then return end
        local mx, my, mz = entity.get_prop(lp, "m_vecOrigin")
        local x0, y0 = renderer.world_to_screen(mx or 0, my or 0, mz or 0)
        for _, p in ipairs(st.points) do
            local x, y = renderer.world_to_screen(p[1], p[2], p[3])
            if x and x0 then
                local r, g = p[4] and 120 or 255, p[4] and 255 or 90
                renderer.line(x0, y0, x, y, r, g, 120, 120)
                renderer.circle(x, y, r, g, 120, 230, 4, 0, 1)
            end
        end
        if st.bot then
            local x, y = renderer.world_to_screen(st.bot[1], st.bot[2], mz or 0)
            if x then renderer.circle_outline(x, y, 120, 255, 120, 255, 8, 0, 1, 2) end
        end
    end)
end
