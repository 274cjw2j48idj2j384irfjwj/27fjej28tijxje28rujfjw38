-- Simulated world for the resolver tests (tests/resolver_regress.py): a mock of the gamesense API the resolver uses
-- (event registry, ui items, plist, entity props) and enemies that run on a hidden tick level. Every tick the enemy AA
-- decides an eye yaw and which ticks are sent (fakelag); a copy of the server's animstate feet logic turns that into the
-- true body yaw, and only the sent ticks reach the resolver as netvars. Shots are fired by an aimbot model with backtrack
-- and ping delayed results; a shot hits when the value applied to the record it went at is within `tol` of the truth.
-- A tickbase shifted update (defensive) gets no lag record on the server (it adds one only when the sim time moves
-- forward): a shot at the shifted model is tested against the newest normal record at or before its sim time.
--
--   H = load(this)();  stats = H.run(script_src, { scenario = "...", ticks = ..., ping = ..., ... })
local H = {}

local TI = 1 / 64                 -- opts.tickrate changes it for a run

-- ── server physics (an independent copy of the animstate feet logic) ────────
local function norm(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end
local function approach(target, value, step)
    local d = norm(target - value)
    if d > step then return norm(value + step) end
    if d < -step then return norm(value - step) end
    return norm(target)
end
-- once per server tick: standing, the feet turn towards the lower body yaw target; moving they follow the eye yaw;
-- the lower body yaw target is set to the eye yaw when the realign timer is up and the feet are > 35 away.
-- returns the body yaw (eye - feet) and whether the feet realigned this tick
local function srv_update(s, eye, moving, speed, t)
    local realigned = false
    if moving then
        local w2r = math.max(0, math.min(1, (speed - 70) / 65))
        s.feet = approach(eye, s.feet, TI * (30 + 20 * w2r))
        s.lby = eye
        s.timer = t + 0.22
    else
        s.feet = approach(s.lby, s.feet, TI * 100)
        if t > s.timer and math.abs(norm(s.feet - eye)) > 35 then
            s.timer = t + 1.1
            s.lby = eye
            realigned = true
        end
    end
    local d = norm(eye - s.feet)
    if d > 58 then s.feet = norm(eye - 58) elseif d < -58 then s.feet = norm(eye + 58) end
    return norm(eye - s.feet), realigned
end

-- ── AA drivers: what the enemy does on every tick ────────────────────────────
-- each returns { eye(k), sent(k), vel(k), shift(k), on_hit(k), on_miss(k) }
local function lcg(seed)
    local s = seed
    return function() s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 end
end

local function every(n) return function(k) return k % n == 0 end end

H.drivers = {
    -- classic desync through the choke: hidden ticks look 116 degrees away, the sent tick is the shown angle
    choke_static = function(o)
        local c, side = o.choke or 6, o.side or 1
        local d = { }
        function d.eye(k) if k % (c + 1) == c then return o.base or 0 end return (o.base or 0) + side * 116 end
        d.sent = function(k) return k % (c + 1) == c end
        d.on_flip = function() side = -side end
        d.get_side = function() return side end
        return d
    end,
    -- the same, the side flips at random moments (every 0.5 - 3 s)
    choke_random = function(o)
        local c, side, rnd = o.choke or 6, 1, lcg(o.seed or 7)
        local nxt = 100
        local d = {}
        function d.eye(k)
            if k >= nxt then side = -side; nxt = k + math.floor(30 + rnd() * 160) end
            if k % (c + 1) == c then return 0 end
            return side * 116
        end
        d.sent = function(k) return k % (c + 1) == c end
        return d
    end,
    -- the side flips every time a shot hits it (anti bruteforce)
    anti_brute = function(o)
        local c, side = o.choke or 6, 1
        local d = {}
        function d.eye(k) if k % (c + 1) == c then return 0 end return side * 116 end
        d.sent = function(k) return k % (c + 1) == c end
        d.on_hit = function() side = -side end
        return d
    end,
    -- the side flips on every shot that comes at it (bullet impact near the head), hit or miss
    anti_shot = function(o)
        local c, side = o.choke or 6, 1
        local d = {}
        function d.eye(k) if k % (c + 1) == c then return 0 end return side * 116 end
        d.sent = function(k) return k % (c + 1) == c end
        d.on_shot = function() side = -side end
        return d
    end,
    -- the side flips when a shot missed it (anti bruteforce on "the enemy is missing me")
    anti_miss = function(o)
        local c, side = o.choke or 6, 1
        local d = {}
        function d.eye(k) if k % (c + 1) == c then return 0 end return side * 116 end
        d.sent = function(k) return k % (c + 1) == c end
        d.on_miss = function() side = -side end
        return d
    end,
    -- the AA of the main script: a yaw jitter that steps once per SENT packet + a body yaw side.
    --   scheme "current": the side is a function of the yaw offset (opposite of it)
    --   scheme "new":     the side is its own random hold process (1-4 packets, flips 70%)
    aa_sim = function(o)
        local c, mode, scheme = o.choke or 6, o.mode or "delayed", o.scheme or "current"
        local rnd = lcg(o.seed or 5)
        local d = {}
        local pk, add, side, dir, hold, step = 0, 0, 1, 1, 0, 0
        local order = { 1, 2, 3, 4, 5 }
        local bside, bleft = 1, 0
        local w = o.width or 56
        local function packet()
            pk = pk + 1
            if mode == "delayed" then
                hold = hold - 1
                if hold <= 0 then dir = -dir; hold = 2 + math.floor(rnd() * 4) end
                add = dir * w / 2
            elseif mode == "5way" then
                step = step + 1
                if step % 5 == 0 then for i = 5, 2, -1 do local j = 1 + math.floor(rnd() * i); order[i], order[j] = order[j], order[i] end end
                add = ({ -w, -w / 2, 0, w / 2, w })[order[step % 5 + 1]]
            elseif mode == "center" then
                add = (pk % 2 == 0) and w / 2 or -w / 2
            end
            if scheme == "coin" then
                side = (rnd() < 0.5) and 1 or -1         -- a fresh coin flip per sent packet (our own anti-aim)
            elseif scheme == "current" then
                if mode == "center" then side = (pk % 2 == 0) and -1 or 1
                elseif add > 0.5 then side = -1 elseif add < -0.5 then side = 1 end
            else
                bleft = bleft - 1
                if bleft <= 0 then
                    if rnd() < 0.7 then bside = -bside end
                    bleft = 1 + math.floor(rnd() * 4)
                end
                side = bside
            end
        end
        function d.eye(k) if k % (c + 1) == c then packet() end return add end
        d.sent = function(k) return k % (c + 1) == c end
        d.truth = function(k) return side * 58 end
        return d
    end,
    -- no fakelag, the eye yaw alternates every tick
    jitter_tick = function(o)
        local amp, ctr = o.amp or 35, o.center or 0
        local d = {}
        function d.eye(k) return ctr + ((k % 2 == 0) and amp or -amp) end
        d.sent = function(k) return true end
        return d
    end,
    -- random side every tick
    jitter_random = function(o)
        local amp, ctr, rnd = o.amp or 35, o.center or 0, lcg(o.seed or 3)
        local d = {}
        function d.eye(k) return ctr + ((rnd() < 0.5) and amp or -amp) end
        d.sent = function(k) return true end
        return d
    end,
    -- three values: -amp / 0 / +amp in random order
    jitter_multi = function(o)
        local amp, rnd = o.amp or 35, lcg(o.seed or 5)
        local d = {}
        function d.eye(k) local r = rnd(); return (r < 0.33) and -amp or ((r < 0.66) and 0 or amp) end
        d.sent = function(k) return true end
        return d
    end,
    -- the centre of the jitter slowly turns
    jitter_drift = function(o)
        local amp, rate = o.amp or 35, o.rate or 0.25
        local d = {}
        function d.eye(k) return norm(k * rate + ((k % 2 == 0) and amp or -amp)) end
        d.sent = function(k) return true end
        return d
    end,
    -- sides held for a random number of ticks (1-4)
    jitter_rperiod = function(o)
        local amp, rnd = o.amp or 35, lcg(o.seed or 9)
        local side, left = 1, 0
        local d = {}
        function d.eye(k)
            if left <= 0 then side = -side; left = 1 + math.floor(rnd() * (o.maxrun or 4)) end
            left = left - 1
            return side * amp
        end
        d.sent = function(k) return true end
        return d
    end,
    -- alternates every `period` ticks
    jitter_delay = function(o)
        local amp, ctr, p = o.amp or 35, o.center or 0, o.period or 3
        local d = {}
        function d.eye(k) return ctr + ((math.floor(k / p) % 2 == 0) and amp or -amp) end
        d.sent = function(k) return true end
        return d
    end,
    -- jitter with fakelag: the sent tick alternates, hidden ticks sit on the other side
    jitter_choke = function(o)
        local c, amp = o.choke or 3, o.amp or 35
        local d = {}
        local n = 0
        function d.eye(k)
            if k % (c + 1) == c then n = n + 1; return (n % 2 == 0) and amp or -amp end
            return ((n + 1) % 2 == 0) and amp + 60 or -amp - 60
        end
        d.sent = function(k) return k % (c + 1) == c end
        return d
    end,
    -- jitter with micromovement: the eye yaw switches side every `hold` sent packets (o.rhold: a random 1..rhold), the lower
    -- body yaw target the server sends is the eye yaw of the sent tick (micromovement), so the netvars show no desync and
    -- with fakelag the feet model lands near 0 on many records. The true body yaw: body "static" (side * size), "opp" /
    -- "same" (against / with the yaw offset), "none" (no desync: the server's own feet, moving = they follow the eye yaw
    -- at 30 deg/s)
    micro_jitter = function(o)
        local c, amp, hold, body, size = o.choke or 6, o.amp or 30, o.hold or 1, o.body or "static", o.size or 58
        local rnd = lcg(o.seed or 11)
        local d = {}
        local ys, left, bs, cur, feet, nb = 1, 0, o.side or 1, amp, nil, 0
        local function packet()
            left = left - 1
            if left <= 0 then
                ys = -ys
                left = o.rhold and (1 + math.floor(rnd() * o.rhold)) or hold
            end
            cur = (o.center or 0) + ys * amp
            if body == "opp" then bs = -ys elseif body == "same" then bs = ys end
        end
        function d.eye(k)
            if k % (c + 1) == c then packet() end
            if body == "none" then
                feet = approach(cur, feet or cur, TI * 30)
                local dd = norm(cur - feet)
                if dd > 58 then feet = norm(cur - 58) elseif dd < -58 then feet = norm(cur + 58) end
                nb = norm(cur - feet)
            end
            return cur
        end
        d.sent = function(k) return k % (c + 1) == c end
        d.vel = function(k) return 1.1 end
        d.net_lby = function(k, eye) return eye end
        d.truth = function(k) if body == "none" then return nb end return bs * size end
        return d
    end,
    -- no anti-aim at all (a legit / matchmaking player): every tick is sent, so no desync is possible; the eye yaw wanders
    -- slowly and the true body yaw is the server's own feet logic (o.vel: running, else standing)
    legit = function(o)
        local amp, period = o.amp or 50, o.period or 200
        local d = {}
        function d.eye(k) return amp * math.sin(k / period * 2 * math.pi) end
        d.sent = function(k) return true end
        d.vel = function(k) return o.vel or 0 end
        return d
    end,
    -- eye yaw holds, then flicks away for one sent tick once per second
    lby_flick = function(o)
        local d = {}
        function d.eye(k) if k % 70 == 69 then return o.flick or 110 end return 0 end
        d.sent = function(k) return true end
        return d
    end,
    -- running: the feet follow the eye yaw slowly
    moving_jitter = function(o)
        local amp = o.amp or 35
        local d = {}
        function d.eye(k) return (k % 2 == 0) and amp or -amp end
        d.sent = function(k) return true end
        d.vel = function(k) return o.speed or 200 end
        return d
    end,
    slow_spin = function(o)
        local d = {}
        function d.eye(k) return norm(k * (o.rate or 1.5)) end
        d.sent = function(k) return true end
        return d
    end,
    -- small desync
    low_delta = function(o)
        local amp = o.amp or 12
        local d = {}
        function d.eye(k) return (k % 2 == 0) and amp or -amp end
        d.sent = function(k) return true end
        return d
    end,
    -- defensive: every 48 ticks a window of 6 sent ticks with a tickbase shift (sim time goes back `back` ticks) while the
    -- eye yaw flicks (`flick`, 110 = past the side, 90 = sideways, 0 = pitch only); the server animates the flicked angles
    -- but keeps no lag record of them. o.base: "static" (eye 0) or "jitter" (+-35 every tick)
    defensive = function(o)
        local flick, back, base = o.flick or 110, o.back or 10, o.base or "static"
        local d = {}
        local function window(k) local ph = k % 48; return ph >= 40 and ph < 46 end
        function d.eye(k)
            if window(k) then return flick end
            if base == "jitter" then return (k % 2 == 0) and 35 or -35 end
            return 0
        end
        d.sent = function(k) return true end
        d.shift = function(k) if window(k) then return { back = back } end return nil end
        return d
    end,
    -- standing choke desync with tickbase shifts every 48 ticks (the sim time goes back past the newest record: `back`
    -- has to be more than the choke)
    choke_defensive = function(o)
        local c = o.choke or 6
        local d = {}
        function d.eye(k) if k % (c + 1) == c then return 0 end return 116 end
        d.sent = function(k) return k % (c + 1) == c end
        d.shift = function(k)
            local ph = k % 48
            if ph >= 36 and ph < 42 and k % (c + 1) == c then return { back = o.back or (c + 4), theta = 0 } end
            return nil
        end
        return d
    end,
    -- a jitter AA with micromovement (the netvars show no desync, the feet model lands near 0) and an always-on defensive:
    -- every `every` ticks a burst of `len` sent packets with a tickbase shift (`back` ticks) and a pitch flick (the yaw
    -- stays). The body yaw is a real desync (body "static" / "opp" / "coin" per packet), the shifted packets too
    jitter_defensive = function(o)
        local c, amp, size, body, every, len = o.choke or 1, o.amp or 30, o.size or 58, o.body or "static", o.every or 16, o.len or 4
        local rnd = lcg(o.seed or 17)
        local d = {}
        local ys, bs, cur = 1, o.side or 1, 0
        local function burst(k) return k % every >= every - len * (c + 1) end
        function d.eye(k)
            if k % (c + 1) == c then
                ys = -ys
                cur = (o.center or 0) + ys * amp
                if body == "opp" then bs = -ys elseif body == "coin" then bs = rnd() < 0.5 and 1 or -1 end
            end
            return cur
        end
        d.sent = function(k) return k % (c + 1) == c end
        d.vel = function(k) return 1.1 end
        d.net_lby = function(k, eye) return eye end
        d.truth = function(k) return bs * size end
        d.shift = function(k) if burst(k) and d.sent(k) then return { back = o.back or 6, truth = true } end return nil end
        return d
    end,
}

-- ── world ─────────────────────────────────────────────────────────────────────
local function make_enemy(idx, spec, ping_ticks)
    local e = {
        idx = idx, name = spec.name or ("enemy" .. idx), driver = spec.driver,
        srv = { feet = 0, lby = 0, timer = 0 }, rec = {}, recent = {}, valid = {},
        net = { sim = 0, eye = 0, pitch = 89, vel = 0, flags = 1, duck = 0, lby = 0, pose = 0.5 },
        max_st = 0, native_p = spec.native_p or 0.25, truth_pol = spec.truth_pol or 1, move = spec.move,
        realign_until = 0, realign_since = 0,
    }
    return e
end

local function enemy_advance(e, k, opts)
    local d = e.driver
    local eye = d.eye(k)
    local vel = d.vel and d.vel(k) or 0
    local theta, realigned = srv_update(e.srv, eye, vel > 5, vel, k * TI)
    if realigned then e.realign_since, e.realign_until = k, k + 24 end
    if not d.sent(k) then return nil end

    local sh = d.shift and d.shift(k) or nil
    local st = sh and (k - sh.back) or k
    -- a shift that still leaves the sim time past the newest one moves it forward: the server takes it as a normal record
    local shifted = sh ~= nil and st <= e.max_st
    local raw = (sh and sh.theta) or theta
    if d.truth and (not sh or sh.truth) then raw = d.truth(k) end
    local pose = 0.5
    if opts.pose_real then pose = (raw + 60) / 120 end
    -- d.net_lby: the lower body yaw target the server sends when it is not the one of the feet logic (micromovement keeps
    -- it on the eye yaw of the sent tick, the netvars show no desync)
    local lby = e.srv.lby
    if d.net_lby then lby = d.net_lby(k, eye) end
    -- spec.move: the player walks left and right (100 units each way, 3 s), else it stands at y 0
    local oy = e.move and 100 * math.sin(k * TI * 2 * math.pi / 3) or 0
    e.net = { sim = st, eye = eye, pitch = sh and -89 or 89, vel = vel, flags = 1, duck = 0, lby = lby, pose = pose, oy = oy }
    if not shifted then e.max_st = st end
    local r = { k = k, st = st, T = raw * e.truth_pol, shifted = shifted, applied = nil, pitch_net = e.net.pitch, oy = oy }
    -- the server's lag record for a shifted update: the newest normal one at or before its sim time
    if shifted then
        for i = #e.valid, 1, -1 do
            if e.valid[i].st <= st then r.srv = e.valid[i]; break end
        end
    else
        e.valid[#e.valid + 1] = r
        while #e.valid > 300 do table.remove(e.valid, 1) end
    end
    e.rec[k] = r
    e.recent[#e.recent + 1] = r
    while #e.recent > 300 do table.remove(e.recent, 1) end
    return r
end

-- ── mock gamesense ────────────────────────────────────────────────────────────
function H.run(script_src, opts)
    opts = opts or {}
    local real_G = _G
    TI = 1 / (opts.tickrate or 64)
    local ticks = opts.ticks or 3000
    local ping_ms = opts.ping or 20
    local fake_ms = opts.fake_ping or 0          -- ping spike: the scoreboard and client.latency have it, the results not
    local ping_ticks = math.ceil(ping_ms / 1000 / TI)
    local tol = opts.tol or 12
    local apply_lag = opts.apply_lag or 0
    local shoot_every = opts.shoot_every or 11
    local rng = lcg(opts.seed or 424242)

    local ctl = { callbacks = {}, items = {}, logs = {}, errors = {}, plist = {}, db = opts.db or {}, tick = 0, ping = ping_ms }
    local specs = opts.enemies
    if not specs then
        local f = H.drivers[opts.scenario or "choke_static"]
        specs = { { driver = f(opts.driver_opts or {}), native_p = opts.native_p, truth_pol = opts.truth_pol } }
    end
    local enemies, by_idx = {}, {}
    for i, spec in ipairs(specs) do
        local e = make_enemy(i + 1, spec, ping_ticks)
        enemies[#enemies + 1] = e
        by_idx[e.idx] = e
    end
    ctl.enemies = enemies

    -- ui -----------------------------------------------------------------------
    local ui = {}
    local function new_item(kind, tab, box, name, extra)
        assert(tab == "RAGE" and box == "Other", "unexpected menu location " .. tostring(tab) .. "/" .. tostring(box))
        local it = { kind = kind, tab = tab, box = box, name = name, visible = true }
        for k, v in pairs(extra or {}) do it[k] = v end
        ctl.items[#ctl.items + 1] = it
        return it
    end
    local function list_of(a, ...) if type(a) == "table" then return a end return { a, ... } end
    ui.new_checkbox = function(tab, box, name) return new_item("checkbox", tab, box, name, { value = false }) end
    ui.new_multiselect = function(tab, box, name, ...) local l = list_of(...); return new_item("multiselect", tab, box, name, { list = l, value = {} }) end
    ui.new_combobox = function(tab, box, name, ...) local l = list_of(...); return new_item("combobox", tab, box, name, { list = l, value = l[1] }) end
    ui.new_slider = function(tab, box, name, min, max, init) return new_item("slider", tab, box, name, { min = min, max = max, value = init or min }) end
    ui.new_hotkey = function(tab, box, name) return new_item("hotkey", tab, box, name, { value = false }) end
    ui.new_button = function(tab, box, name, cb) return new_item("button", tab, box, name, { cb = cb }) end
    ui.new_label = function(tab, box, name) return new_item("label", tab, box, name, {}) end
    ui.get = function(it)
        if it.kind == "multiselect" then local c = {}; for i, v in ipairs(it.value) do c[i] = v end; return c end
        if it.kind == "hotkey" then return it.value, 1, 0 end
        return it.value
    end
    ui.set = function(it, v)
        if it.kind == "multiselect" then
            local ok = {}
            for _, o in ipairs(it.list) do ok[o] = true end
            for _, o in ipairs(v) do if not ok[o] then error("invalid option for " .. it.name .. ": " .. tostring(o)) end end
            local c = {}; for i, x in ipairs(v) do c[i] = x end; it.value = c
        else
            it.value = v
        end
        if it.cb and it.kind ~= "button" then it.cb(it) end
    end
    ui.set_visible = function(it, b) it.visible = b and true or false end
    ui.set_callback = function(it, fn) it.cb = fn end
    function ctl.item(name)
        for _, it in ipairs(ctl.items) do if it.name == name then return it end end
        error("no menu item named " .. name)
    end

    -- time ---------------------------------------------------------------------
    local globals = {
        tickcount = function() return ctl.tick end, tickinterval = function() return TI end,
        curtime = function() return ctl.tick * TI end, realtime = function() return ctl.tick * TI end,
        frametime = function() return TI end,
    }

    -- entity -------------------------------------------------------------------
    local entity = {}
    entity.get_local_player = function() return 1 end
    entity.is_alive = function(idx) return not (opts.dead_fn and opts.dead_fn(ctl.tick, idx)) end
    entity.is_dormant = function(idx) return opts.dormant_fn ~= nil and opts.dormant_fn(ctl.tick, idx) or false end
    -- like gamesense: dead and dormant players are not listed (opts.list_all lists them anyway)
    entity.get_players = function()
        local l = {}
        for _, e in ipairs(enemies) do
            if opts.list_all or (entity.is_alive(e.idx) and not entity.is_dormant(e.idx)) then l[#l + 1] = e.idx end
        end
        return l
    end
    entity.get_player_resource = function() return 99 end
    entity.hitbox_position = function(idx) local e = by_idx[idx]; return 500, e and e.net.oy or 0, 64 end
    entity.get_origin = function(idx) local e = by_idx[idx]; return 500, e and e.net.oy or 0, 0 end
    entity.get_player_name = function(idx) return by_idx[idx] and by_idx[idx].name or "me" end
    entity.get_steam64 = function(idx)
        if opts.steam_fn then return opts.steam_fn(ctl.tick, idx) end
        return "7656119800000000" .. idx
    end
    entity.get_prop = function(ent, name, i)
        if ent == 99 and name == "m_iPing" then return ctl.ping + fake_ms end
        if ent == 1 then if name == "m_vecOrigin" then return 0, 0, 0 end return 0 end
        local e = by_idx[ent]
        if not e then return 0 end
        local n = e.net
        if opts.garbage and opts.garbage(ctl.tick, ent, name) ~= nil then return opts.garbage(ctl.tick, ent, name) end
        if name == "m_flSimulationTime" then return n.sim * TI end
        if name == "m_angEyeAngles" then return n.pitch, n.eye end
        if name == "m_vecOrigin" then return 500, n.oy or 0, 0 end
        if name == "m_vecVelocity" then return n.vel, 0, 0 end
        if name == "m_fFlags" then return n.flags end
        if name == "m_flDuckAmount" then return n.duck end
        if name == "m_flLowerBodyYawTarget" then return n.lby end
        if name == "m_flPoseParameter" then
            if i == 11 then
                if opts.pose_echo then return (((ctl.plist[ent] or {})["Force body yaw value"] or 0) + 60) / 120 end
                return n.pose
            end
            return 0
        end
        return 0
    end

    -- client ---------------------------------------------------------------------
    local client = {
        latency = function() return (ctl.ping + fake_ms) / 2000 end,
        real_latency = function() return ctl.ping / 2000 end,
        eye_position = function() return 0, 0, 64 end,
        trace_line = function(me, x1, y1) if y1 < 0 then return 0.4 end return 1.0 end,
        current_threat = function() return ctl.threat or (enemies[1] and enemies[1].idx) end,
        set_event_callback = function(name, fn)
            ctl.callbacks[name] = ctl.callbacks[name] or {}
            table.insert(ctl.callbacks[name], fn)
        end,
        register_esp_flag = function(name, r, g, b, fn) ctl.esp = ctl.esp or {}; ctl.esp[name] = fn end,
        error_log = function(m) ctl.errors[#ctl.errors + 1] = tostring(m) end,
        color_log = function(r, g, b, m) ctl.logs[#ctl.logs + 1] = tostring(m) end,
        screen_size = function() return 1920, 1080 end,
        userid_to_entindex = function(uid) return uid end,
        timestamp = function() return ctl.tick * 16 end,
        system_time = function() return 12, 0, 0, 0 end,
    }

    local plist = {
        get = function(idx, field) return (ctl.plist[idx] or {})[field] end,
        set = function(idx, field, v) ctl.plist[idx] = ctl.plist[idx] or {}; ctl.plist[idx][field] = v end,
    }
    local database = {
        read = function(k) local v = ctl.db[k]; if v == nil then return nil end return v end,
        write = function(k, v) ctl.db[k] = v end,
    }
    local renderer = setmetatable({ measure_text = function() return 40 end }, { __index = function() return function() end end })

    -- sandbox: no os / io / debug (like gamesense), strict globals (no undefined reads, no writes) -----
    local env = {}
    for _, name in ipairs({ "assert", "error", "ipairs", "pairs", "next", "pcall", "xpcall", "select", "tonumber", "tostring",
                            "type", "unpack", "rawget", "rawset", "rawequal", "setmetatable", "getmetatable", "math", "string",
                            "table", "bit", "collectgarbage" }) do
        env[name] = real_G[name]
    end
    env.require = function(name)
        if name == "ffi" or name == "bit" then return real_G.require(name) end
        error("module '" .. name .. "' not found")
    end
    env.client, env.entity, env.globals, env.ui, env.plist, env.renderer, env.database = client, entity, globals, ui, plist, renderer, database
    env.set_cb = client.set_event_callback
    env._G = env
    setmetatable(env, {
        __index = function(t, k) error("undefined global read: " .. tostring(k), 2) end,
        __newindex = function(t, k) error("global write: " .. tostring(k), 2) end,
    })

    local chunk, err = loadstring(script_src, "@resolver")
    assert(chunk, err)
    setfenv(chunk, env)
    local S = chunk()
    S = S or {}
    ctl.S = S
    if opts.configure then opts.configure(ctl, S) end
    if not opts.disabled then ui.set(ctl.item(opts.enable_item or "Resolver"), true) end

    local function fire(name, ...)
        for _, fn in ipairs(ctl.callbacks[name] or {}) do fn(...) end
    end

    -- run --------------------------------------------------------------------------
    local stats = { shots = 0, hits = 0, late_shots = 0, late_hits = 0, errors = 0, per = {}, spread = 0, def_shots = 0,
                    late_valid_shots = 0, late_valid_hits = 0 }
    for _, e in ipairs(enemies) do stats.per[e.idx] = { shots = 0, hits = 0, late_shots = 0, late_hits = 0 } end
    local pending, shot_id = {}, 0
    -- the enemy AA reacting to a shot (anti-bruteforce drivers): right away, or opts.react_delay ticks later (in a real game
    -- the enemy hears about the shot through the server and its new angles come back with its own ping and choke)
    local function react(e, hook, k)
        if not e.driver[hook] then return end
        local delay = opts.react_delay or 0
        if delay <= 0 then e.driver[hook](k) else pending[#pending + 1] = { at = k + delay, kind = "react", target = e.idx, hook = hook } end
    end
    local warm = opts.warm or math.floor(ticks / 2)

    for k = 1, ticks do
        ctl.tick = k
        if opts.ping_fn then ctl.ping = opts.ping_fn(k) end
        if opts.on_tick then opts.on_tick(k, ctl, S) end

        -- net_update_start runs before the update is read: opts.apply_lag = 1 is a gamesense that builds a new record
        -- (and reads "Force body yaw value" for it) before net_update_end, so the record gets what is set before that
        local oks, errs = pcall(fire, "net_update_start")
        if not oks then stats.errors = stats.errors + 1; ctl.errors[#ctl.errors + 1] = "net_update_start: " .. tostring(errs) end
        local pre = {}
        for _, e in ipairs(enemies) do
            local pl = ctl.plist[e.idx] or {}
            pre[e.idx] = { pl["Force body yaw"] and pl["Force body yaw value"] or nil, pl["Force pitch"] and pl["Force pitch value"] or nil }
        end

        local arrived = {}
        for _, e in ipairs(enemies) do
            local r = enemy_advance(e, k, opts)
            if r then arrived[e.idx] = r end
        end

        local okn, errn = pcall(fire, "net_update_end")
        if not okn then stats.errors = stats.errors + 1; ctl.errors[#ctl.errors + 1] = "net_update_end: " .. tostring(errn) end
        if opts.panel and k % 40 == 0 then
            local okp, errp = pcall(fire, "paint")
            if not okp then stats.errors = stats.errors + 1; ctl.errors[#ctl.errors + 1] = "paint: " .. tostring(errp) end
        end

        -- what was applied to the records that arrived this tick (the value forced after this update, or, apply_lag 1,
        -- the one set before it); the pitch too ("Force pitch": the defensive pitch flick taken back)
        for _, e in ipairs(enemies) do
            local pl = ctl.plist[e.idx] or {}
            local v = pl["Force body yaw"] and pl["Force body yaw value"] or nil
            local fp = pl["Force pitch"] and pl["Force pitch value"] or nil
            local r = arrived[e.idx]
            if r and apply_lag == 0 then r.applied, r.pitch = v, fp
            elseif r then r.applied, r.pitch = pre[e.idx][1], pre[e.idx][2] end
            local cl = ctl.plist[e.idx] or {}
            if cl["Override prefer body aim"] == "On" then stats.ba_ticks = (stats.ba_ticks or 0) + 1 end
            if cl["Override safe point"] == "On" then stats.sp_ticks = (stats.sp_ticks or 0) + 1 end
        end

        -- results arrive after the ping
        local i = 1
        while i <= #pending do
            local p = pending[i]
            if p.at <= k then
                local e = by_idx[p.target]
                local okc, errc = true, nil
                if p.kind == "react" then
                    e.driver[p.hook](k)
                elseif p.kind == "impact" then
                    react(e, "on_shot", k)
                elseif p.kind == "hit" then
                    okc, errc = pcall(fire, "aim_hit", { id = (not opts.no_ids) and p.id or nil, target = p.target, damage = 100, hitgroup = 1 })
                    react(e, "on_hit", k)
                else
                    okc, errc = pcall(fire, "aim_miss", { id = (not opts.no_ids) and p.id or nil, target = p.target, reason = p.reason })
                    react(e, "on_miss", k)
                end
                if not okc then stats.errors = stats.errors + 1; ctl.errors[#ctl.errors + 1] = "result: " .. tostring(errc) end
                table.remove(pending, i)
            else
                i = i + 1
            end
        end

        -- the aimbot
        if k > 20 and k % shoot_every == 0 then
            local e = enemies[(math.floor(k / shoot_every) % #enemies) + 1]
            if #e.recent > 0 then
                -- the drawn model (the newest update: a shifted one during a defensive burst) or a backtracked normal record
                -- (a shifted record is no backtrack target: its sim time went back). Like gamesense, a shot at the drawn
                -- shifted model says 0 ticks back: the newest normal record is not drawn then, and not shot with 0
                local newest = e.recent[#e.recent]
                local r = newest
                -- opts.bt_min: a ping spike, the aimbot shoots the records around the fake latency only
                if opts.bt_min or rng() < 0.5 then
                    local pool = {}
                    local bt_max = opts.bt_max or (ping_ticks + 8)
                    for _, c in ipairs(e.recent) do
                        if not c.shifted and e.max_st - c.st <= bt_max and e.max_st - c.st >= (opts.bt_min or 0)
                                and not (newest.shifted and c.st == e.max_st) then pool[#pool + 1] = c end
                    end
                    if #pool > 0 then r = pool[math.floor(rng() * #pool) + 1] end
                end
                shot_id = shot_id + 1
                pending[#pending + 1] = { at = k + math.max(1, math.floor(ping_ticks / 2)), kind = "impact", target = e.idx }
                local bt = r.shifted and 0 or math.max(0, e.max_st - r.st)
                local ev = { id = shot_id, target = e.idx, backtrack = bt, tick = k, hitgroup = 1, hit_chance = 80 }
                -- opts.aim: the aim point on the record's head (+- 0.5 multipoint); opts.native_off: gamesense counts its
                -- backtrack from the record that many ticks back (a ping spike); opts.ev_tick = "record": the shot's tick
                -- is its record's tick + 1 (interpolation), else the tick it was fired at
                if opts.aim then ev.x, ev.y, ev.z = 500 + rng() - 0.5, (r.oy or 0) + rng() - 0.5, 64 end
                if opts.native_off then ev.backtrack = math.max(0, bt - opts.native_off) end
                if opts.ev_tick == "record" then ev.tick = r.st + 1 end
                if opts.no_ids then ev.id = nil end
                if opts.fire_extra then for kk, vv in pairs(opts.fire_extra(k, e, r) or {}) do ev[kk] = vv end end
                local okf, errf = pcall(fire, "aim_fire", ev)
                if not okf then stats.errors = stats.errors + 1; ctl.errors[#ctl.errors + 1] = "aim_fire: " .. tostring(errf) end
                stats.shots = stats.shots + 1
                local late = k > warm
                local per = stats.per[e.idx]
                per.shots = per.shots + 1
                if late then stats.late_shots = stats.late_shots + 1; per.late_shots = per.late_shots + 1 end
                local hit
                if r.shifted then stats.def_shots = stats.def_shots + 1 end
                if late and not r.shifted then stats.late_valid_shots = stats.late_valid_shots + 1 end
                if rng() < (opts.spread_p or 0.06) then
                    stats.spread = stats.spread + 1
                    pending[#pending + 1] = { at = k + ping_ticks, kind = "miss", id = shot_id, target = e.idx, reason = "spread" }
                else
                    if r.shifted then
                        -- tested against the server's lag record; the aimbot aimed at the shifted model, whose head the
                        -- flick moved (opts.def_head = "same": a defensive that keeps the angles, only the record breaks;
                        -- "pitch": the flick is the pitch only (-89), the head is right when the normal pitch was forced)
                        local s = r.srv
                        local head = opts.def_head == "same" or (opts.def_head == "pitch" and r.pitch ~= nil and math.abs(r.pitch - 89) <= 10)
                        hit = s ~= nil and r.applied ~= nil and head and math.abs(r.applied - s.T) <= tol
                    elseif r.applied == nil then hit = rng() < e.native_p else hit = math.abs(r.applied - r.T) <= tol end
                    if hit and rng() < (opts.noise_p or 0) then hit = false end
                    if opts.on_shot then opts.on_shot(k, e, r, hit, ctl, S) end
                    if hit then
                        stats.hits = stats.hits + 1; per.hits = per.hits + 1
                        if late then stats.late_hits = stats.late_hits + 1; per.late_hits = per.late_hits + 1 end
                        if late and not r.shifted then stats.late_valid_hits = stats.late_valid_hits + 1 end
                        pending[#pending + 1] = { at = k + ping_ticks, kind = "hit", id = shot_id, target = e.idx }
                    else
                        pending[#pending + 1] = { at = k + ping_ticks, kind = "miss", id = shot_id, target = e.idx, reason = "?" }
                    end
                end
            end
        end
    end

    stats.rate = stats.shots > 0 and stats.hits / stats.shots or 0
    stats.late_rate = stats.late_shots > 0 and stats.late_hits / stats.late_shots or 0
    stats.valid_rate = stats.late_valid_shots > 0 and stats.late_valid_hits / stats.late_valid_shots or 0
    for _, per in pairs(stats.per) do per.late_rate = per.late_shots > 0 and per.late_hits / per.late_shots or 0 end
    stats.ctl = ctl
    stats.S = S
    stats.fire = fire
    return stats
end

return H
