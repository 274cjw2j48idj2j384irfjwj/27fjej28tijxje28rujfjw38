-- Client API contract checks only. No game simulation or live HTTP requests.
-- Run: luajit tests/primordial_presence.lua
local file = assert(io.open(arg[1] or "specter_primordial.lua", "rb"))
local source = file:read("*a")
file:close()
local begin = assert(source:find("presence.hash = function", 1, true))
local finish = assert(source:find("run_clantag = function", begin, true))
local clock, enabled, map, local_index = 100, true, "de_dust2", 1
local entities, requests, icons, notes, downloads = {}, {}, {}, {}, {}
local list, saved_image, chats = {}, false, 0
local p = { server = "https://test.invalid", version = "specter", epoch = 0, sequence = 0,
    next = 0, shown = {}, announced = {}, failures = 0, icon = "moon", icon_next = 0,
    icon_ready = false }
local env = setmetatable({
    presence = p, esp = { sync_user = {} }, shared_data = {},
    globals = { real_time = function() return clock end },
    ui = {
        utils = { shared_esp = { get = function() return enabled end },
            synced_players = { get = function() return true end } },
        nav = { shared_esp = { ref = { set_items = function(_, rows) list = rows end } } },
    },
    notifications = { types = { warning = 1, success = 2, information = 3 },
        create = function(_, text) notes[#notes + 1] = text end },
    libs = {
        json = { parse = function(body)
            if type(body) ~= "table" then error("malformed") end
            return body
        end },
        filesystem = { exists = function() return saved_image end, create_directory = function() end },
        tools = {
            js = { update = function(idx, path, ready, sid)
                icons[idx] = { path = path, ready = ready, sid = sid }
            end, clear = function() icons = {} end },
            js2 = { GameStateAPI = { GetPlayerXuidStringFromEntIndex = function(idx)
                return entities[idx] and entities[idx].fallback
            end } },
            http = {
                get = function(_, url, callback)
                    requests[#requests + 1] = { url = url, callback = callback }
                end,
                download_image = function(_, url, path, callback)
                    downloads[#downloads + 1] = { callback = callback }
                end,
            },
        },
    },
    engine_get_level_name = function() return map end,
    entity_list_get_entity = function(idx) return entities[idx] end,
    entity_list_get_local_player = function() return entities[local_index] end,
    entity_list_get_player_from_userid = function(idx) return entities[idx] end,
    entity_list_get_players = function()
        local out = {}
        for i = 1, 64 do if entities[i] then out[#out + 1] = entities[i] end end
        return out
    end,
    check_conditions = function() return entities[local_index] ~= nil end,
    chat_print = function() chats = chats + 1 end,
}, { __index = _G })
setfenv(assert(loadstring(source:sub(begin, finish - 1), "presence")), env)()
local count = 0
local function check(ok, name)
    assert(ok, name)
    count = count + 1
    print("PASS " .. name)
end
local function player(idx, account, name)
    local e = { account = account, name = name or "same name" }
    function e:get_index() return idx end
    function e:get_name() return self.name end
    function e:get_steamids() return "[U:1:" .. self.account .. "]", p.account_steam64(self.account) end
    entities[idx] = e
    return e
end
local function reply(req, on)
    req.callback({ body = { ok = true, on = on or {} } })
end
local function restart()
    p.reset(false)
    requests, notes = {}, {}
end
local mine, other = player(1, 12345, "me"), player(2, 24691)
local own_sid, other_sid = p.account_steam64(12345), p.account_steam64(24691)
check(own_sid == "76561197960278073", "account IDs convert without Steam64 double rounding")
check(p.account_steam64(4294967295) == "76561202255233023", "maximum account ID retains exact decimal digits")
check(p.normalize_id("STEAM_0:1:12345") == other_sid
    and p.normalize_id("[U:1:24691]") == other_sid, "Steam2 and Steam3 share canonical Steam64")
check(p.normalize_id(require("ffi").new("uint64_t", 76561197960278073ULL)) == own_sid,
    "uint64 cdata retains exact identity")
check(p.normalize_id(76561197960278073) == nil and p.normalize_id("BOT") == nil
    and p.normalize_id("0") == nil and p.normalize_id("[U:1:4294967296]") == nil,
    "rounded Steam64 numbers, bots and invalid account IDs are rejected")
local original_ids = other.get_steamids
other.get_steamids = function() return "invalid", other_sid end
check(p.steamid(other) == other_sid, "exact second Steam-ID return is used")
other.get_steamids = function() error("not ready") end
other.fallback = other_sid
check(p.steamid(other) == other_sid, "Panorama exact identity is a fallback when native API fails")
other.get_steamids, other.fallback = original_ids, nil
p.update(true)
local first = requests[1]
check(first.url:find("&me=" .. p.hash(own_sid), 1, true) ~= nil
    and not first.url:find(own_sid, 1, true) and not first.url:find("same name", 1, true),
    "heartbeat and queries send hashes only, never raw IDs or names")
check(first.url:find(p.hash(other_sid), 1, true) ~= nil
    and first.url:find(p.hash("[U:1:24691]"), 1, true) ~= nil,
    "queries cover both canonical identities and legacy primary strings")
reply(first, { [p.hash(own_sid)] = "dev", [p.hash(other_sid)] = "nightly" })
check(icons[1] and icons[2] and #list == 2 and tostring(list[1]):find("(you)", 1, true) ~= nil
    and #env.esp.sync_user == 1 and env.esp.sync_user[1] == other_sid,
    "own badge and own sidebar row (first, marked you; owners: \"my name didn't appear\"); peers use canonical sync identity")
check(not icons[2].ready, "fallback badge is used while icon download is unavailable")
check(#requests == 2 and requests[2].url:find("&q=&me=" .. p.hash("[U:1:12345]"), 1, true),
    "legacy visibility is registered while migrating older clients")
env.on_chatsync({ userid = 2 })
env.on_chatsync({ userid = 1 })
check(chats == 1, "chat sync recognizes canonical peers but excludes local chat")
other.name = "renamed"
p.apply({ [p.hash(other_sid)] = "beta" }, {
    [p.hash(other_sid)] = { idx = 2, sid = other_sid, canonical = true },
})
check(list[1] == "renamed ~ beta", "name and version changes refresh an existing player row")
local note_count = #notes
p.apply({ [p.hash(other_sid)] = "beta" }, {
    [p.hash(other_sid)] = { idx = 2, sid = other_sid, canonical = true },
})
check(#notes == note_count, "stable identities do not repeat user-found announcements")
p.report = true
p.apply({}, {})
check(notes[#notes]:find("your badge is not confirmed yet", 1, true),
    "enabled but unconfirmed visibility is not reported as disabled")
p.apply({}, {})
check(#list == 0 and next(icons) == nil and #env.esp.sync_user == 0, "absent users clear list and badges")
restart()
p.update(true)
local old = requests[1]
player(2, 99999)
reply(old, { [p.hash(other_sid)] = "dev" })
check(p.shown[2] == nil, "late response cannot badge a reused entity slot")
entities[2] = other
restart()
p.update(true)
old = requests[1]
p.reset(false)
reply(old, { [p.hash(other_sid)] = "dev" })
check(next(p.shown) == nil and p.last_success == nil, "reset invalidates in-flight callbacks")
restart()
p.update(true)
old = requests[1]
map = "de_mirage"
reply(old, { [p.hash(other_sid)] = "dev" })
check(next(p.shown) == nil and p.next == 0, "map changes reject replies before next frame poll")
p.update(false)
check(#requests == 2, "map transition promptly starts a new request")
old = requests[2]
enabled = false
reply(old, { [p.hash(own_sid)] = "dev" })
check(next(p.shown) == nil, "visibility changes reject stale heartbeat responses")
p.update(false)
check(not requests[#requests].url:find("&me=", 1, true), "visibility off never registers a heartbeat")
enabled = true
restart()
p.update(true)
old = requests[1]
old.callback(nil)
check(p.failures == 1 and p.next == clock + 4 and not p.busy, "failed HTTP replies schedule bounded retry")
clock = clock + 4
p.update(false)
check(#requests == 2, "retry runs when its short backoff expires")
old = requests[2]
clock = clock + 26
p.update(false)
check(not p.busy and p.failures == 2, "missing callbacks time out instead of blocking presence forever")
reply(old, { [p.hash(other_sid)] = "dev" })
check(next(p.shown) == nil, "timed-out request cannot overwrite current state")
restart()
p.update(true)
reply(requests[1], { [p.hash(other_sid)] = "dev" })
clock = clock + 76
p.update(false)
check(next(p.shown) == nil, "last successful user state expires at server TTL")
restart()
p.icon_ready, p.icon_busy, p.icon_next, saved_image = false, nil, 0, false
p.install_icon()
downloads[#downloads].callback(false)
check(not p.icon_ready and not p.icon_busy, "failed icon download keeps fallback and permits retry")
clock = clock + 31
p.install_icon()
saved_image = true
downloads[#downloads].callback(true)
check(p.icon_ready, "retried icon download becomes ready only after saved file exists")
restart()
for i = 2, 64 do player(i, 10000 + i) end
p.update(true)
local query = requests[1].url:match("&q=([^&]*)")
local hashes = {}
for hash in query:gmatch("[^,]+") do hashes[#hashes + 1] = hash end
check(#hashes == 64 and hashes[64] == p.hash(p.account_steam64(10064)),
    "all 64 canonical players fit before any legacy aliases consume query capacity")
restart()
entities = { [1] = mine, [2] = other, [3] = player(3, 33333, "renamed") }
p.update(true)
reply(requests[1], { [p.hash(other_sid)] = "dev", [p.hash(p.account_steam64(33333))] = "dev" })
check(#list == 2 and #env.esp.sync_user == 2, "duplicate names preserve both distinct user identities")
entities[1] = nil
p.update(true)
check(#list == 0 and next(icons) == nil, "disconnect clears rendered user data")
check(p.connected == false and p.busy == nil, "disconnect invalidates pending HTTP requests")
local paint = assert(source:find('perf.add(e_callbacks.PAINT, "PAINT"', 1, true))
local presence_poll = assert(source:find('perf.span("presence", lets_sync)', paint, true))
local condition = assert(source:find("if (check_conditions()) then", paint, true))
check(presence_poll < condition, "PAINT polls presence outside match-only callback block")
print("ALL " .. count .. " PRESENCE CONTRACT CHECKS PASSED")
