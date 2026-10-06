-- ======================================================================
--  SPECTER | DEV LOADER
--
--  For the owners / devs only: no login, no key, no HWID, no server.
--  Put THIS file into the gamesense lua folder once. Every time it is loaded it downloads the newest
--  specter_dev.lua from GitHub and runs it, so the script never has to be copied into the folder again.
--
--    1. the sources below are tried in order, the first one that answers with a script that compiles wins
--       (main is first: after the pull request is merged it is the newest, before that it does not have the file)
--    2. the script that was downloaded is saved as specter_dev_cache.lua
--    3. when GitHub cannot be reached, the saved copy is used
--
--  GitHub's raw files are cached for a few minutes: a push is not always there the second it is made.
--  A new source (another branch) is one more line in SOURCES.
-- ======================================================================

local SOURCES = {
    "https://raw.githubusercontent.com/274cjw2j48idj2j384irfjwj/27fjej28tijxje28rujfjw38/main/specter_dev.lua",
    "https://raw.githubusercontent.com/274cjw2j48idj2j384irfjwj/27fjej28tijxje28rujfjw38/dev/specter_dev.lua",
}
local CACHE_FILE = "specter_dev_cache.lua"
local CHUNK_NAME = "@specter_dev"

local function say(msg)
    client.color_log(180, 160, 255, "specter dev  \0")
    client.color_log(255, 255, 255, msg)
end

local compile = rawget(_G, "loadstring") or rawget(_G, "load") or load

-- compiles and runs a script; returns false + the reason when it does not
local function run(body)
    local fn, cerr = compile(body, CHUNK_NAME)
    if not fn then return false, "does not compile: " .. tostring(cerr) end
    local ok, rerr = xpcall(fn, function(e) return tostring(e) end)
    if not ok then return false, "error while running: " .. tostring(rerr) end
    return true
end

-- something that is a lua script and not an error page
local function looks_like_script(body)
    if type(body) ~= "string" or #body < 2000 then return false end
    if body:sub(1, 1) == "<" or body:sub(1, 3) == "404" then return false end
    return compile(body, CHUNK_NAME) ~= nil
end

local function from_cache(why)
    local ok, body = pcall(readfile, CACHE_FILE)
    if ok and type(body) == "string" and #body > 0 then
        say(why .. " - using the saved copy")
        local done, err = run(body)
        if not done then say("saved copy failed: " .. err) end
    else
        say(why .. " - and there is no saved copy yet. Check the internet connection and the SOURCES list")
    end
end

local ok_http, http = pcall(require, "gamesense/http")
if not ok_http or type(http) ~= "table" then
    from_cache("the gamesense/http library is not installed")
    return
end

local function try(i)
    local url = SOURCES[i]
    if not url then
        from_cache("could not download the script")
        return
    end
    -- the time makes the url new for the caches on the way
    local stamp = (client.unix_time and client.unix_time()) or 0
    http.get(url .. "?t=" .. tostring(stamp), { network_timeout = 10, absolute_timeout = 30 }, function(success, response)
        local body = success and response and response.status == 200 and response.body or nil
        if not looks_like_script(body) then
            try(i + 1)
            return
        end
        pcall(writefile, CACHE_FILE, body)
        local branch = url:match("/idk/([^/]+)/") or "?"
        say(string.format("loaded specter_dev.lua from %s (%d KB)", branch, math.floor(#body / 1024)))
        local done, err = run(body)
        if not done then say("the downloaded script failed: " .. err) end
    end)
end

try(1)
