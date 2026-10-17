-- Standalone regression harness. No game process, network calls or FFI reads.
-- Run from the repository root: luajit tests/primordial_advanced.lua
local path = arg[1] or "specter_primordial.lua"
local handle = assert(io.open(path, "rb"))
local source = handle:read("*a")
handle:close()
assert(loadstring(source, "full-file-syntax"))
local clock, tick, choked = 10, 640, 0
local outgoing, incoming, autopeek = 0.02, 0.02, nil
local entities, trace_handler = {}, nil
local function control(value)
    return { get = function() return value end, set = function(_, v) value = v end }
end
local resolver = { data = {}, mem = {}, previous = {}, misses = {}, safe = {},
    shots = {}, epoch = 0, trust = { fs = 0, jitter = 0 }, stats = {} }
local builder = { speed = 0 }
local controls = { adaptive = control(true), enable = control(true),
    anti_brute = control(true), ab_mode = control(1) }
local env = setmetatable({
    resolver = resolver, builder = builder, reso = {},
    bit = require("bit"), ffi = require("ffi"),
    globals = {
        real_time = function() return clock end,
        tick_count = function() return tick end,
        frame_time = function() return 1 / 64 end,
    },
    global = { current_state_number = 2 },
    engine_get_choked_commands = function() return choked end,
    engine_get_latency = function(flow) return flow == 1 and outgoing or incoming end,
    e_latency_flows = { OUTGOING = 1, INCOMING = 2 },
    e_hitboxes = { HEAD = 0, CHEST = 2, PELVIS = 3 },
    e_hitscan_groups = { HEAD = 1, CHEST = 2, STOMACH = 3, ARMS = 4, LEGS = 5, FEET = 6 },
    ragebot_get_autopeek_pos = function() return autopeek end,
    entity_list_get_entity = function(idx) return entities[idx] end,
    entity_list_get_players = function()
        local result = {}
        for _, e in pairs(entities) do result[#result + 1] = e end
        return result
    end,
    entity_list_get_local_player = function()
        return { get_eye_position = function() return { x = 0, y = 0, z = 0 } end }
    end,
    trace_line = function() return { fraction = 1 } end,
    vec3_t = function(x, y, z) return { x = x, y = y, z = z } end,
    trace_bullet = function(...)
        if trace_handler then return trace_handler(...) end
        return { valid = true, damage = 30, hitgroup = 3 }
    end,
    time_to_ticks = function(v) return math.floor(v * 64 + 0.5) end,
    ui = {
        ragebot = { logic_reso = control(true), smart_baim = control(true),
            smart_baim_hp = control(40), smart_baim_lethal = control(true),
            latency_guard = control(true), latency_limit = control(80), fast_peek = control(true),
            backtrack = { prediction = control(true), enable_backtrack = control(true),
                extended_backtrack = control(false), ping_in_sight = control(true) },
            resolver = { enable_resolver = control(false) },
            reso_cfg = { yaw_calc = control(3) } },
        antiaim = { builder = controls },
    },
}, { __index = _G })
env.globals.interval_per_tick = function() return 1 / 64 end
env.math = {}
for k, v in pairs(math) do env.math[k] = v end
env.math.vec_length2d = function(v) return math.sqrt(v.x * v.x + v.y * v.y) end
local function section(first, last, appendix)
    local a = assert(source:find(first, 1, true), first)
    local b = assert(source:find(last, a, true), last)
    local chunk = assert(loadstring(source:sub(a, b - 1) .. (appendix or ""), first))
    setfenv(chunk, env)
    chunk()
end
section("resolver.network = function", "safe_defensive = function")
section("local backtrack = {", "local RES_NOCHOKE = 8", "\nexport_backtrack = backtrack")
env.backtrack = env.export_backtrack
section("resolver.HYP = {", "--- @info: resolver: side from freestanding")
section("local RES_NOCHOKE = 8", "local shotlog = {")
section("builder.lerp = function", "builder.apply_preset = function")
local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error("FAIL " .. name .. ": " .. tostring(err), 0) end
    passed = passed + 1
    print("PASS " .. name)
end
local function entity(idx)
    local e = { idx = idx, sim = 1, spawn = 100, hp = 100, flags = 1, velocity = { x = 0, y = 0, z = 0 } }
    function e:get_index() return self.idx end
    function e:get_hitbox_pos() return { x = 1, y = 2, z = 3 } end
    function e:get_prop(prop)
        if prop == "m_flSimulationTime" then return self.sim end
        if prop == "m_flSpawnTime" then return self.spawn end
        if prop == "m_iHealth" then return self.hp end
        if prop == "m_fFlags" then return self.flags end
        if prop == "m_vecVelocity" then return self.velocity end
    end
    function e:is_alive() return self.hp > 0 end
    function e:is_dormant() return false end
    function e:is_enemy() return true end
    function e:get_name() return "test-target" end
    return e
end
local target = entity(2)
entities[2] = target
local function prepare(candidate, id)
    local p = resolver.track(target, 0)
    resolver.previous[2] = { key = "stand", kind = nil, rel = 1,
        candidate = candidate, m_flDesync = 58 }
    resolver.capture({ id = id, player = target })
    return p
end
test("jitter differs from a steady spin", function()
    assert(resolver.jit_classify({ 60, -60, 60, -60 }, 20))
    assert(not resolver.jit_classify({ 60, 60, 60, 60 }, 20))
    assert(not resolver.jit_classify({ 1, -1, 1, -1 }, 20))
end)
test("initial simulation is a baseline, not a choked record", function()
    resolver.reset()
    target.sim = 900
    local p = resolver.track(target, 170)
    assert(p.sim == 900 and p.samples == 0 and #p.jd == 0)
    target.sim = 900 + 1 / 64
    assert(resolver.track(target, -170).jd[1] == 20)
end)
test("bounded jitter history and confidence", function()
    local p = { jd = {}, jy = {}, dir = 1 }
    for i = 1, 100 do
        resolver.jit_record(p, i % 2 == 0 and 60 or -60, i / 64, 20, i % 2 == 0 and 30 or -30)
    end
    assert(#p.jd == 12 and #p.jy == 12)
    assert(p.jitter and p.confidence >= 0.8 and p.confidence <= 1)
end)
test("small repeated jitter contributes usable confidence", function()
    local p = { jd = {}, jy = {}, dir = 1 }
    for i = 1, 30 do
        resolver.jit_record(p, i % 2 == 0 and 6 or -6, i / 64, 20, i % 2 == 0 and 3 or -3)
    end
    assert(p.jitter and p.confidence >= 0.65)
end)
test("simulation rewind invalidates target memory", function()
    local old = resolver.data[2]
    resolver.memory(2, "stand").misses = 7
    target.sim = 1
    local p = resolver.track(target, 0)
    assert(p ~= old and resolver.mem[2] == nil)
end)
test("respawn invalidates target generation", function()
    local old = resolver.data[2]
    target.spawn = target.spawn + 1
    assert(resolver.track(target, 0) ~= old)
end)
test("out-of-order shot IDs credit the captured candidate", function()
    resolver.reset()
    prepare(1, 101)
    prepare(2, 102)
    local mem = resolver.memory(2, "stand")
    resolver.on_result(target, true, false, { id = 102 })
    assert(mem.candidates[2].good > 1 and mem.candidates[1].good == 1)
    resolver.on_result(target, false, true, { id = 101 })
    assert(mem.candidates[1].bad > 1 and mem.candidates[2].bad == 1)
    assert(#resolver.shots == 0)
end)
test("duplicate result cannot train twice", function()
    local mem = resolver.memory(2, "stand")
    local before = mem.candidates[1].bad
    resolver.on_result(target, false, true, { id = 101 })
    assert(mem.candidates[1].bad == before)
end)
test("spread feedback leaves hypotheses unchanged", function()
    prepare(3, 103)
    local mem = resolver.memory(2, "stand")
    local before = mem.candidates[3].bad
    resolver.on_result(target, false, false, { id = 103 })
    assert(mem.candidates[3].bad == before)
end)
test("overlapping feedback without IDs is not guessed", function()
    resolver.reset()
    prepare(1, nil)
    prepare(2, nil)
    local mem = resolver.memory(2, "stand")
    resolver.on_result(target, true, false, {})
    assert(mem.candidates[1].good == 1 and mem.candidates[2].good == 1)
    assert(resolver.shots[1].ambiguous and resolver.shots[2].ambiguous)
end)
test("unique shot without an ID may be matched", function()
    resolver.reset()
    prepare(1, nil)
    resolver.on_result(target, true, false, {})
    assert(resolver.memory(2, "stand").candidates[1].good > 1)
end)
test("feedback from a previous target generation is ignored", function()
    resolver.reset()
    prepare(1, 200)
    target.spawn = target.spawn + 1
    resolver.track(target, 0)
    resolver.on_result(target, true, false, { id = 200 })
    assert(resolver.mem[2] == nil)
end)
test("expired shots and queue size are bounded", function()
    resolver.reset()
    for i = 1, 140 do prepare(1, i) end
    assert(#resolver.shots == 128)
    clock = clock + 5
    resolver.prune_shots(clock)
    assert(#resolver.shots == 0)
end)
test("resolver miss explores a different hypothesis", function()
    local mem = resolver.memory(2, "stand")
    local first = resolver.choose(mem, 0.8)
    mem.last_failed = first
    mem.candidates[first].bad = mem.candidates[first].bad + 1
    assert(resolver.choose(mem, 0.8) ~= first)
end)
test("half-offset hypotheses respect yaw calculation mode", function()
    local mem = resolver.memory(2, "mode-check")
    mem.candidates[3].good = 1000
    assert(resolver.choose(mem, 0.8, true) == 3)
    local choice = resolver.choose(mem, 0.8, false)
    assert(choice ~= 3 and choice ~= 4)
end)
test("invalid simulation times are rejected", function()
    local e = entity(10)
    e.sim = math.huge
    assert(resolver.track(e, 0) == nil)
    e.sim = 0 / 0
    assert(resolver.track(e, 0) == nil)
end)
test("zero-offset hypothesis can learn", function()
    resolver.reset()
    prepare(5, 500)
    resolver.previous[2].rel = 0
    resolver.on_result(target, true, false, { id = 500 })
    assert(resolver.memory(2, "stand").candidates[5].good > 1)
end)
test("packet decisions stay stable within a tick", function()
    builder.new_packet()
    assert(builder.fresh)
    local side = builder.side_flip
    builder.new_packet()
    assert(not builder.fresh and builder.side_flip == side)
    tick = tick + 1
    choked = 2
    builder.new_packet()
    assert(not builder.fresh)
    choked = 0
    builder.new_packet()
    assert(builder.fresh)
end)
test("state changes discard stale AA caches", function()
    builder.xw_st.value = 500
    builder.advanced_left = 99
    env.global.current_state_number = 3
    builder.new_packet()
    assert(builder.xw_st.value == nil and builder.advanced_left == nil and builder.fresh)
end)
test("tick rewind clears anti-brute timers", function()
    builder.ab_until, builder.ab_phase_until, builder.ab_trigger_tick = 2000, 3000, tick
    tick = 1
    builder.new_packet()
    assert(builder.ab_until == 0 and builder.ab_phase_until == 0 and builder.ab_trigger_tick == nil)
end)
test("negative UI randomization does not create an empty interval", function()
    for _ = 1, 100 do
        local value = builder.rnd(0, -30)
        assert(value >= -30 and value <= 0)
    end
end)
test("X-Way stays bounded and refreshes changed parameters", function()
    local st = {}
    for _ = 1, 100 do
        local value = builder.adv.xway(st, 5, 25, 10, 2, builder.rnd)
        assert(value >= -15 and value <= 35)
    end
    assert(builder.adv.xway(st, 5, 0, 77, 100, builder.rnd) == 77)
end)
test("delayed AA feedback credits the captured arm, not current arm", function()
    local st = {}
    local g = builder.adv.brain_group(st, 1)
    g.cur, g.until_t = 2, clock + 10
    builder.adv.brain_learn(st, 1, "hit", 1, clock, math.random, 1)
    assert(g.arms[1].b > 1 and g.arms[2].b == 1 and g.cur == 2)
end)
test("frame-scaled smoothing converges without overshoot", function()
    local value = builder.lerp(0, 89, 0.1)
    assert(value > 0 and value < 89)
    for _ = 1, 100 do value = builder.lerp(value, 89, 0.1) end
    assert(value == 89)
end)
test("angle normalization and finite desync bounds", function()
    assert(builder.adv.norm(181) == -179)
    assert(builder.adv.norm(-181) == 179)
    local st = { m_flFeetSpeedForwardsOrsideWays = 0 / 0,
        m_flStopToFullRunningFraction = math.huge, m_fDuckAmount = nil }
    local value = resolver.max_desync(st)
    assert(value == value and value >= 29 and value <= 58)
end)
local function context(e)
    local ctx = { player = e, groups = {}, safepoints = {}, forced_hc = nil, forced_accuracy = nil }
    function ctx:set_hitscan_group_state(group, enabled) self.groups[group] = enabled end
    function ctx:set_safepoint_state(value, group) self.safepoints[group] = value end
    function ctx:set_hitchance(value) self.forced_hc = value end
    function ctx:set_damage_accuracy(value) self.forced_accuracy = value end
    return ctx
end
test("low HP forces body aim even with resolver inactive", function()
    resolver.reset()
    resolver.active = false
    target.hp, target.flags = 39, 1
    local ctx = context(target)
    resolver.hitscan(ctx)
    assert(ctx.groups[1] == false and ctx.groups[2] == true and ctx.groups[3] == true)
    assert(ctx.groups[4] == false and ctx.groups[5] == false)
end)
test("new sliders initialize explicit defaults with unit steps", function()
    assert(source:find('slider("Body aim below HP", 0, 100, 1, 0, "hp")', 1, true))
    assert(source:find('slider("High ping threshold", 40, 250, 1, 0, "ms")', 1, true))
    env.ui.ragebot.smart_baim_hp.ref = env.ui.ragebot.smart_baim_hp
    env.ui.ragebot.latency_limit.ref = env.ui.ragebot.latency_limit
    env.ui.ragebot.smart_baim_hp:set(0)
    env.ui.ragebot.latency_limit:set(40)
    section("ui.ragebot.smart_baim_hp.ref:set(40)", "ui.antiaim.builder.ab_mode")
    assert(env.ui.ragebot.smart_baim_hp:get() == 40 and env.ui.ragebot.latency_limit:get() == 80)
end)
test("health threshold is strict and configurable", function()
    target.hp = 40
    local ctx = context(target)
    resolver.hitscan(ctx)
    assert(ctx.groups[1] == nil)
    env.ui.ragebot.smart_baim_hp:set(50)
    resolver.hitscan(ctx)
    assert(ctx.groups[1] == false)
    env.ui.ragebot.smart_baim_hp:set(40)
end)
test("zero threshold disables HP-forced body aim", function()
    env.ui.ragebot.smart_baim_hp:set(0)
    target.hp = 1
    local ctx = context(target)
    resolver.hitscan(ctx)
    assert(ctx.groups[1] == nil)
    env.ui.ragebot.smart_baim_hp:set(40)
end)
test("disabling smart body aim removes its overrides", function()
    env.ui.ragebot.smart_baim:set(false)
    target.hp = 10
    local ctx = context(target)
    resolver.hitscan(ctx)
    assert(ctx.groups[1] == nil)
    env.ui.ragebot.smart_baim:set(true)
end)
test("lethal body scan respects actual traced damage through walls", function()
    target.hp = 60
    resolver.misses[2] = 1
    local ctx = context(target)
    trace_handler = function() return { valid = true, damage = 20, hitgroup = 3 } end
    resolver.hitscan(ctx)
    assert(ctx.groups[1] == nil)
    tick = tick + 1 -- the body damage is traced once per tick and target
    trace_handler = function() return { valid = true, damage = 65, hitgroup = 3 } end
    resolver.hitscan(ctx)
    assert(ctx.groups[1] == false)
    trace_handler = nil
    resolver.misses[2] = nil
end)
test("head hits and invalid traces do not count as lethal body damage", function()
    tick = tick + 1
    trace_handler = function() return { valid = true, damage = 100, hitgroup = 1 } end
    assert(resolver.body_damage(target) == 0)
    tick = tick + 1
    trace_handler = function() return nil end
    assert(resolver.body_damage(target) == 0)
    trace_handler = nil
end)
test("final body enforcement defeats a later head re-enable", function()
    local ctx = context(target)
    ctx.groups[1] = true
    resolver.enforce_body(ctx)
    assert(ctx.groups[1] == false and ctx.groups[2] == true and ctx.groups[3] == true)
end)
test("fresh confident crouch jitter does not force safepoints in fast mode", function()
    target.flags, target.hp = 3, 100
    resolver.active, resolver.safe_all = true, false
    resolver.data[2] = { updated = clock, defensive_until = 0, jitter = true, confidence = 1 }
    local ctx = context(target)
    resolver.hitscan(ctx)
    assert(ctx.safepoints[1] == nil and ctx.safepoints[2] == nil)
end)
test("explicit strict safety remains respected", function()
    resolver.safe_all = true
    local ctx = context(target)
    resolver.hitscan(ctx)
    assert(ctx.safepoints[1] == true)
    resolver.safe_all = false
end)
test("stale jitter does not force safety", function()
    target.flags = 1
    resolver.data[2] = { updated = clock - 1, defensive_until = 0, jitter = true, confidence = 1 }
    local ctx = context(target)
    resolver.hitscan(ctx)
    assert(ctx.safepoints[1] == nil and ctx.safepoints[2] == nil)
end)
test("crouch transition clears earlier standing jitter evidence", function()
    resolver.reset()
    target.flags = 1
    local p = resolver.track(target, 0)
    p.jitter, p.confidence, p.jd, p.jy = true, 1, { 60, -60, 60 }, { 30, -30, 30 }
    target.flags, target.sim = 3, target.sim + 1 / 64
    p = resolver.track(target, 0)
    assert(not p.jitter and p.confidence == 0 and #p.jd == 1)
end)
test("simulation rewind has a defensive grace window", function()
    target.sim = target.sim - 1
    local p = resolver.track(target, 0)
    assert(not resolver.fresh(p) and p.defensive_until > clock)
end)
test("high ping uses millisecond threshold and outgoing-only budgets", function()
    outgoing, incoming = 0.08, 0.07
    local net = resolver.network()
    assert(net.high and math.abs(net.ping - 150) < 0.001)
    assert(env.backtrack.horizon(net, false) <= 0.06)
    assert(env.backtrack.horizon(net, true) <= 0.04)
    outgoing, incoming = 0.02, 0.02
end)
test("invalid latency inputs stay finite", function()
    outgoing, incoming = 0 / 0, math.huge
    local net = resolver.network()
    assert(net.ping == 0 and net.outgoing == 0 and net.incoming == 0)
    outgoing, incoming = 0.02, 0.02
end)
test("high ping fallback enables native resolver", function()
    local setting = control(false)
    env.menu_find = function() return setting end
    env.auto_cfg = { resolve_antiaim = false }
    resolver.native(false, true)
    assert(setting:get())
    resolver.native(true, false)
    assert(not setting:get())
    resolver.native(false, false)
    assert(not setting:get())
end)
test("high ping does not receive added fake latency", function()
    local ping = control(12)
    env.backtrack.ping = ping
    local player = { get_active_weapon = function() return { get_name = function() return "ssg08" end } end }
    outgoing, incoming = 0.07, 0.07
    env.backtrack.update(player)
    assert(ping:get() == 0)
    outgoing, incoming = 0.02, 0.02
    clock = clock + 1
    env.backtrack.update(player)
    assert(ping:get() == 60)
    env.ui.ragebot.backtrack.enable_backtrack:set(false)
    env.backtrack.update(player)
    assert(ping:get() == 12)
    env.ui.ragebot.backtrack.enable_backtrack:set(true)
end)
test("fake ping only runs while an enemy is in sight, 1 s after, and always when the option is off", function()
    local ping = control(0)
    env.backtrack.ping, env.backtrack.saved, env.backtrack.amount, env.backtrack.seen_until = ping, nil, nil, nil
    local player = { get_active_weapon = function() return { get_name = function() return "ssg08" end } end }
    outgoing, incoming = 0.02, 0.02
    local dormant = true
    target.is_dormant = function() return dormant end
    env.backtrack.update(player)
    assert(ping:get() == 0)                         -- nobody in sight: no fake ping
    dormant = false
    clock = clock + 1
    env.backtrack.update(player)
    assert(ping:get() == 60)                        -- seen: on (the 100 ms budget minus the real 40)
    dormant = true
    clock = clock + 0.5
    env.backtrack.update(player)
    assert(ping:get() == 60)                        -- lost half a second ago: still on
    clock = clock + 1
    env.backtrack.update(player)
    assert(ping:get() == 0)                         -- a second without a sight: off
    env.ui.ragebot.backtrack.ping_in_sight:set(false)
    env.backtrack.update(player)
    assert(ping:get() == 60)                        -- option off: the old behaviour, an alive enemy is enough
    env.ui.ragebot.backtrack.ping_in_sight:set(true)
    target.is_dormant = function() return false end
end)
test("expired prediction priorities are ignored", function()
    env.backtrack.peekers, env.backtrack.peek_until = { 2 }, clock - 1
    local n = 0
    local ctx = { prioritize_target = function() n = n + 1 end }
    env.backtrack.target_selection(ctx)
    assert(n == 0)
end)
test("blocked extrapolation does not manufacture a future peek", function()
    target.flags, target.velocity = 3, { x = 20, y = 0, z = 0 }
    env.trace_line = function() return { fraction = 0.5 } end
    trace_handler = function() return { valid = true, damage = 50, hitgroup = 1 } end
    env.backtrack.predict_tick, env.backtrack.records = -1, {}
    env.backtrack.predict(env.entity_list_get_local_player())
    assert(#env.backtrack.peekers == 0)
    env.trace_line = function() return { fraction = 1 } end
    trace_handler = nil
end)
test("crouch peek prediction supports slow movement and short lookahead", function()
    tick = tick + 2
    local positions = {}
    trace_handler = function(_, point)
        positions[#positions + 1] = point
        return { valid = true, damage = point.x > 1 and 50 or 0, hitgroup = 1 }
    end
    env.vec3_t = function(x, y, z) return { x = x, y = y, z = z } end
    env.backtrack.predict(env.entity_list_get_local_player())
    assert(#env.backtrack.peekers == 1 and env.backtrack.peekers[1] == 2)
    assert(positions[1].x <= 1.8)
    trace_handler = nil
end)
env.ui.ragebot.safe_defensive = control(true)
env.ui.ragebot.accuracy_boost = { enable_booster = control(true), booster_mode = control(2) }
env.defensive = { is_active = function() return true end }
section("safe_defensive = function", "local damage = {")
section("accuracy_boost = function", "antiafk = function")
test("fast crouch scan avoids script-imposed defensive head safepoint", function()
    target.flags = 3
    local ctx = context(target)
    env.safe_defensive(ctx)
    assert(ctx.safepoints[1] == nil)
end)
test("fast crouch scan avoids 90 percent damage-accuracy injection", function()
    local ctx = context(target)
    env.accuracy_boost(ctx)
    assert(ctx.forced_accuracy == nil)
end)
test("normal standing scan preserves the chosen accuracy booster", function()
    target.flags = 1
    local ctx = context(target)
    env.accuracy_boost(ctx)
    assert(ctx.forced_accuracy == 90)
end)
test("false autopeek position is not mistaken for an active peek", function()
    autopeek = false
    assert(not resolver.fast_target(target))
    autopeek = nil
end)
env.perf = { add = function(_, _, fn) env.miss_callback = fn end }
env.e_callbacks = { AIMBOT_MISS = 1 }
env.hit_groups = { [1] = "head" }
env.cl_logs = { add_log = function() end }
env.shotlog = { result = function() end }
env.ui.utils = { event_logs = control(false) }
env.indicator = { data = {}, shot_count = 0 }
section("do_aimmiss = function()", "do_antiaim = function()")
env.do_aimmiss()
test("miss statistics retain host reasons with logging off", function()
    env.miss_callback({ id = 9000, player = target, aim_hitgroup = 1,
        reason_string = "spread", backtrack_ticks = 30 })
    assert(env.indicator.data.spread == 1)
    assert(env.indicator.data.jitter == nil and env.indicator.data["prediction error"] == nil)
    assert(env.indicator.shot_count == 1)
end)
test("host jitter is not relabeled as prediction error", function()
    env.miss_callback({ id = 9001, player = target, aim_hitgroup = 1,
        reason_string = "jitter", backtrack_ticks = 18 })
    assert(env.indicator.data.jitter == 1 and env.indicator.data["prediction error"] == nil)
end)
test("missing reason safely becomes unknown", function()
    env.miss_callback({ id = 9002, player = target, aim_hitgroup = 1 })
    assert(env.indicator.data.unknown == 1)
end)
test("AA code does not depend on resolver-only numeric helpers", function()
    local tail = source:sub(assert(source:find("-- [pm-resolver:end]", 1, true)))
    assert(not tail:find("res_clamp(", 1, true))
end)
test("shot capture is optional when the resolver block is omitted", function()
    assert(source:find("if (resolver.capture ~= nil) then resolver.capture(shot) end", 1, true))
end)
print(string.format("ALL %d TESTS PASSED", passed))
