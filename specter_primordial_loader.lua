-- ======================================================================
--  SPECTER for Primordial | Loader
--  Key + HWID checked by the license server, the script downloaded from it at every login
--  (nightly = everything, beta = no resolver, dev = the newest build). A key loads its own build and the ones below it:
--  a dev key dev / nightly / beta (a button each), a nightly key nightly / beta, a beta key beta. Put this file into primordial/scripts once.
-- ======================================================================

if (rawget(_G, "_specter_pm_loader_loaded")) then
    return
end
rawset(_G, "_specter_pm_loader_loaded", true)

local SERVER_URL = "https://specter-license-mh111-production.up.railway.app"
-- bump whenever this file changes: the server hands out the number of the newest loader (the bot reads it from the cloud
-- branch) and an older one tells its user to download the new one
local LOADER_VERSION = 3
local KEY_FILE = "specter/key.txt"             -- csgo/specter/key.txt
local BUILD_FILE = "specter/build.txt"         -- the build a multi build key loaded last (csgo/specter/build.txt)
local GROUP = "Specter loader"

-- the Primordial calls the two libraries below use
local client_log, global_vars_cur_time = client.log, global_vars.cur_time
local memory_find_pattern, memory_create_interface = memory.find_pattern, memory.create_interface

local libs = {}

-- files in the game folder (the key is remembered in csgo/specter/key.txt)
libs.filesystem = (function()
    local a={}a.__index={}a.class=ffi.cast(ffi.typeof("void***"),memory_create_interface("filesystem_stdio.dll","VBaseFileSystem011"))a.v_table=a.class[0]a.full_class=ffi.cast("void***",memory_create_interface("filesystem_stdio.dll","VFileSystem017"))a.v_fltable=a.full_class[0]a.casts={read_file=ffi.cast("int (__thiscall*)(void*, void*, int, void*)",a.v_table[0]),write_file=ffi.cast("int (__thiscall*)(void*, void const*, int, void*)",a.v_table[1]),open_file=ffi.cast("void* (__thiscall*)(void*, const char*, const char*, const char*)",a.v_table[2]),close_file=ffi.cast("void (__thiscall*)(void*, void*)",a.v_table[3]),file_size=ffi.cast("unsigned int (__thiscall*)(void*, void*)",a.v_table[7]),file_exists=ffi.cast("bool (__thiscall*)(void*, const char*, const char*)",a.v_table[10]),delete_file=ffi.cast("void (__thiscall*)(void*, const char*, const char*)",a.v_fltable[20]),rename_file=ffi.cast("bool (__thiscall*)(void*, const char*, const char*, const char*)",a.v_fltable[21]),create_dir=ffi.cast("void (__thiscall*)(void*, const char*, const char*)",a.v_fltable[22]),is_dir=ffi.cast("bool (__thiscall*)(void*, const char*, const char*)",a.v_fltable[23])}local b=memory_create_interface("filesystem_stdio.dll","VFileSystem017")local c=ffi.cast(ffi.typeof("void***"),b)ffi.cdef([[ typedef void (__thiscall* AddSearchPath)(void*, const char*, const char*); typedef void (__thiscall* RemoveSearchPaths)(void*, const char*); typedef const char* (__thiscall* FindNext)(void*, int); typedef bool (__thiscall* FindIsDirectory)(void*, int); typedef void (__thiscall* FindClose)(void*, int); typedef const char* (__thiscall* FindFirstEx)(void*, const char*, const char*, int*); typedef long (__thiscall* GetFileTime)(void*, const char*, const char*); ]])local d=ffi.cast("AddSearchPath",c[0][11])local e=ffi.cast("RemoveSearchPaths",c[0][14])local f=ffi.cast("FindNext",c[0][33])local g=ffi.cast("FindIsDirectory",c[0][34])local h=ffi.cast("FindClose",c[0][35])local i=ffi.cast("FindFirstEx",c[0][36])a.modes={["r"]="r",["w"]="w",["a"]="a",["r+"]="r+",["w+"]="w+",["a+"]="a+",["rb"]="rb",["wb"]="wb",["ab"]="ab",["rb+"]="rb+",["wb+"]="wb+",["ab+"]="ab+"}a.open=function(j,k,l)if not a.modes[k]then error("File mode error!")end;local self=setmetatable({file=j,mode=k,path_id=l,handle=a.casts.open_file(a.class,j,k,l)},a)return self end;a.close=function(m)a.casts.close_file(a.class,m.handle)end;a.exists=function(j,l)return a.casts.file_exists(a.class,j,l)end;a.get_size=function(m)return a.casts.file_size(a.class,m.handle)end;a.write_binary=function(n,o)local m=a.open(n,"wb","MOD")a.casts.write_file(a.class,o,#o,m.handle)a.close(m)end;a.read_binary=function(n)local m=a.open(n,"rb","MOD")local p=a.get_size(m)local q=ffi.new("char[?]",p)a.casts.read_file(a.class,q,p,m.handle)a.close(m)return ffi.string(q,p)end;a.write=function(n,o)local m=a.open(n,"w","MOD")a.casts.write_file(a.class,o,#o,m.handle)a.close(m)end;a.append=function(n,o)local m=a.open(n,"a","MOD")a.casts.write_file(a.class,o,#o,m.handle)a.close(m)end;a.read=function(n)local m=a.open(n,"r","MOD")local p=a.get_size(m)local q=ffi.new("char[?]",p+1)a.casts.read_file(a.class,q,p,m.handle)a.close(m)return ffi.string(q)end;a.rename=function(r,s,l)return a.casts.rename_file(a.full_class,r,s,l)end;a.delete=function(j,l)a.casts.delete_file(a.full_class,j,l)end;a.create_directory=function(n,l)a.casts.create_dir(a.full_class,n,l)end;a.is_directory=function(n,l)return a.casts.is_dir(a.full_class,n,l)end;a.find_next=function(t)local j=a.casts.find_next(a.full_class,t)if j==0 then return nil end;return ffi.string(j)end;a.find_is_directory=function(t)return a.casts.find_is_dir(a.full_class,t)end;a.get_sec_files=function()local u=ffi.new("int[1]")e(c,"primordial")d(c,"././primordial/scripts","primordial")local v={}local j=i(c,"*","primordial",u)while j~=nil do local w=ffi.string(j)if g(c,u[0])==false and w:find("[.]lua")then table.insert(v,w)end;j=f(c,u[0])end;h(c,u[0])return v end;a.read_first_line=function(x)local y=x:match("^[^\r\n]+")return y end;a.get_files=function()local u=ffi.new("int[1]")e(c,"specter_configs")d(c,"./csgo/specter/","specter_configs")local v={}local j=i(c,"*","specter_configs",u)while j~=nil do local w=ffi.string(j)if g(c,u[0])==false and w:find("[.]cfg")then table.insert(v,w)end;j=f(c,u[0])end;h(c,u[0])return v end;return a
end)()

-- steam http (the same library the script uses)
libs.httpcreator = (function()
    local a=ffi.cast("uint32_t**",ffi.cast("char**",ffi.cast("char*",memory_find_pattern("client.dll","B9 ? ? ? ? E8 ? ? ? ? 83 3D ? ? ? ? ? 0F 84"))+1)[0]+48)[0]or error("steam_http error")local b=ffi.cast("void***",a)or error("steam_http_ptr error")local c=b[0]or error("steam_http_ptr was null")local function d(e,f)return function(...)return e(f,...)end end;local g=d(ffi.cast(ffi.typeof("uint32_t(__thiscall*)(void*, uint32_t, const char*)"),c[0]),a)local h=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, uint64_t)"),c[5]),a)local i=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, uint32_t*)"),c[9]),a)local j=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, char*, uint32_t)"),c[10]),a)local k=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, uint32_t*)"),c[11]),a)local l=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, char*, uint32_t)"),c[12]),a)local m=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, const char*)"),c[3]),a)local n=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, const char*)"),c[4]),a)local o=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*)"),c[21]),a)local p=d(ffi.cast("bool(__thiscall*)(void*, uint32_t, const char*, const char*, uint32_t)",c[16]),a)local q=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t)"),c[14]),a)local r={}callbacks.add(e_callbacks.PAINT,function()for s,t in ipairs(r)do if global_vars_cur_time()-t.ls>t.task_interval then t:_process_tasks()t.ls=global_vars_cur_time()end end end)local u={}local v={__index=u}function u.new(w,x,y)return setmetatable({handle=w,url=x,callback=y,ticks=0},v)end;local z={}local A={__index=z}function z.new(B,C,D)return setmetatable({status=B,body=C,headers=D},A)end;function z:success()return self.status==200 end;local E={state={ok=200,no_response=204,timed_out=408,unknown=0}}local F={__index=E}function E.new(G)G=G or{}local t=setmetatable({requests={},task_interval=G.task_interval or 0.3,enable_debug=G.debug or false,timeout=G.timeout or 10,ls=global_vars_cur_time()},F)table.insert(r,t)return t end;local H={["get"]=1,["head"]=2,["post"]=3,["put"]=4,["delete"]=5,["options"]=6,["patch"]=7}function E:request(I,J,K,L)if type(K)=="function"and L==nil then L=K;K={}end;K=K or{}local M=H[tostring(I):lower()]local N=g(M,J)local O="application/text"if type(K.headers)=="table"then for P,Q in pairs(K.headers)do P=tostring(P)Q=tostring(Q)if P:lower()=="content-type"then O=Q end;m(N,P,Q)end end;if type(K.body)=="string"then local R=K.body:len()p(N,O,ffi.cast("unsigned char*",K.body),R)end;if type(K.params)=="table"then for S,T in pairs(K.params)do n(N,S,T)end end;if type(K.user_agent_info)=="string"then o(N,K.user_agent_info)end;if not h(N,0)then return end;local U=u.new(N,J,L)self:_debug("[HTTP] New %s request to: %s",I:upper(),J)table.insert(self.requests,U)end;function E:get(J,L)local N=g(1,J)if not h(N,0)then return end;local U=u.new(N,J,L)self:_debug("[HTTP] New GET request to: %s",J)table.insert(self.requests,U)end;function E:post(J,V,L)local N=g(3,J)for S,T in pairs(V)do n(N,S,T)end;if not h(N,0)then return end;local U=u.new(N,J,L)self:_debug("[HTTP] New POST request to: %s",J)table.insert(self.requests,U)end;function E:download_image(J,W,L)local N=g(1,J)if not h(N,0)then return end;local function X(z)if z:success()then libs.filesystem.write_binary(W,z.body)if L then L(true,"Image downloaded successfully")end else if L then L(false,"Failed to download image")end end end;local U=u.new(N,J,X)table.insert(self.requests,U)end;function E:_process_tasks()for S,T in ipairs(self.requests)do local Y=ffi.new("uint32_t[1]")self:_debug("[HTTP] Processing request #%s",S)if k(T.handle,Y)then local Z=Y[0]if Z>0 then local _=ffi.new("char[?]",Z)if l(T.handle,_,Z)then self:_debug("[HTTP] Request #%s finished. Invoking callback.",S)T.callback(z.new(E.state.ok,ffi.string(_,Z),setmetatable({},{__index=function(a0,a1)return E._get_header(T,a1)end})))table.remove(self.requests,S)q(T.handle)end else T.callback(z.new(E.state.no_response,nil,{}))table.remove(self.requests,S)q(T.handle)end end;local a2=T.ticks+1;if a2>=self.timeout then T.callback(z.new(E.state.timed_out,nil,{}))table.remove(self.requests,S)q(T.handle)else T.ticks=a2 end end end;function E:_debug(...)if self.enable_debug then client_log(string.format(...))end end;function E._get_header(U,a3)local Y=ffi.new("uint32_t[1]")if i(U.handle,a3,Y)then local Z=Y[0]local _=ffi.new("char[?]",Z)if j(U.handle,a3,_,Z)then return ffi.string(_,Z)end end;return nil end;function E._bind(a4,a5)return function(...)return a4[a5](a4,...)end end;return E
end)()

local http = libs.httpcreator.new({ task_interval = 0.3, enable_debug = false, timeout = 15 })

local function say(text)
    client_log("[Specter] " .. tostring(text))
end

-- this machine: the volume serial of C:\ and the computer name, hashed (the server locks the key to it)
local function get_hwid()
    local raw = "specter-pm"
    pcall(ffi.cdef, [[
        int GetVolumeInformationA(const char*, char*, unsigned long, unsigned long*, unsigned long*, unsigned long*, char*, unsigned long);
        int GetComputerNameA(char*, unsigned long*);
    ]])
    pcall(function()
        local serial = ffi.new("unsigned long[1]")
        if (ffi.C.GetVolumeInformationA("C:\\", nil, 0, serial, nil, nil, nil, 0) ~= 0) then
            raw = raw .. "|" .. tostring(tonumber(serial[0]))
        end
        local name, size = ffi.new("char[256]"), ffi.new("unsigned long[1]", 256)
        if (ffi.C.GetComputerNameA(name, size) ~= 0) then
            raw = raw .. "|" .. ffi.string(name)
        end
    end)
    local h1, h2 = 5381, 52711
    for i = 1, #raw do
        local c = raw:byte(i)
        h1 = (h1 * 33 + c) % 4294967296
        h2 = (h2 * 31 + c * 7) % 4294967296
    end
    return string.format("PM-%08X%08X", h1, h2)
end

local function read_key()
    local ok, exists = pcall(libs.filesystem.exists, KEY_FILE, "MOD")
    if (not ok or not exists) then
        return ""
    end
    local ok2, text = pcall(libs.filesystem.read, KEY_FILE)
    return ok2 and tostring(text):match("^%s*(.-)%s*$") or ""
end

local function save_key(key)
    pcall(libs.filesystem.create_directory, "specter", "MOD")
    pcall(libs.filesystem.write, KEY_FILE, key)
end

local function read_build()
    local ok, exists = pcall(libs.filesystem.exists, BUILD_FILE, "MOD")
    if (not ok or not exists) then
        return ""
    end
    local ok2, text = pcall(libs.filesystem.read, BUILD_FILE)
    return ok2 and tostring(text):match("^%s*(.-)%s*$") or ""
end

local function save_build(build)
    pcall(libs.filesystem.create_directory, "specter", "MOD")
    pcall(libs.filesystem.write, BUILD_FILE, build)
end

local function field(body, name)
    return body:match('"' .. name .. '"%s*:%s*"([^"]*)"')
end

local function encode(s)
    return (tostring(s):gsub("([^%w%-_.~])", function(c) return string.format("%%%02X", c:byte()) end))
end

local REASONS = {
    wrong_build = "This key can not load that build.", invalid_key = "Invalid key.", revoked = "This key was revoked.", expired = "This key has expired.",
    hwid_mismatch = "This key is locked to another PC (ask staff for a HWID reset).",
    missing_params = "Enter your key.", script_missing = "The script is not on the server yet, try again later.",
}

local ui = {}
ui.key = menu.add_text_input(GROUP, "Key")
ui.status = menu.add_text(GROUP, "Enter your key and press Login.")
local busy = false

-- the builds a key can load, best first; the name the buttons / messages use
local BUILD_ORDER = { "pm_dev", "pm_nightly", "pm_beta" }
local function build_name(build)
    return (tostring(build):gsub("^pm_", ""))
end

local function status(text)
    say(text)
    pcall(ui.status.set, ui.status, text)
end

local function run(body, key, hwid, plan, user)
    local fn, err = (loadstring or load)(body, "=specter")
    if (fn == nil) then
        status("The downloaded script does not compile: " .. tostring(err))
        return
    end
    rawset(_G, "loader", { username = (user ~= nil and user ~= "") and user or "user", id = "1", hwid = hwid })
    pcall(menu.set_group_visibility, GROUP, false)
    say("loaded Specter " .. plan:gsub("^pm_", "") .. ", have fun")
    local ok, run_err = pcall(fn)
    if (not ok) then
        pcall(menu.set_group_visibility, GROUP, true)
        status("The script stopped with an error: " .. tostring(run_err))
    end
end

local login

-- one button per build, shown only for the builds the key allows (more than one)
ui.builds = {}
for _, build in ipairs(BUILD_ORDER) do
    ui.builds[build] = menu.add_button(GROUP, "Load " .. build_name(build), function()
        login(build)
    end)
    pcall(ui.builds[build].set_visible, ui.builds[build], false)
end

local function show_builds(allowed)
    for _, build in ipairs(BUILD_ORDER) do
        local on = false
        for _, name in ipairs(allowed) do
            on = on or name == build
        end
        pcall(ui.builds[build].set_visible, ui.builds[build], on)
    end
end

-- the builds the server lists for the key ("builds":["pm_dev","pm_nightly","pm_beta"]); none listed = an older server: the key's own plan
local function parse_builds(body)
    local list, inner = {}, body:match('"builds"%s*:%s*%[(.-)%]')
    for name in (inner or ""):gmatch('"(pm_%a+)"') do
        list[#list + 1] = name
    end
    return list
end

login = function(chosen)
    if (busy) then
        return
    end
    local key = tostring(ui.key:get() or ""):match("^%s*(.-)%s*$")
    if (key == "") then
        status("Enter your key.")
        return
    end
    busy = true
    local hwid = get_hwid()
    status("Checking your key...")
    http:get(SERVER_URL .. "/verify?key=" .. encode(key) .. "&hwid=" .. encode(hwid), function(response)
        local body = response.body or ""
        if (not body:find('"valid"%s*:%s*true')) then
            busy = false
            status(REASONS[field(body, "reason") or ""] or (body == "" and "The server did not answer, try again." or "Login failed."))
            return
        end
        local latest = tonumber(body:match('"loader_pm"%s*:%s*(%d+)'))
        if (latest ~= nil and latest > LOADER_VERSION) then
            local text = "A new Specter loader is out (v" .. latest .. ", you have v" .. LOADER_VERSION
                .. "): download it from #primordial-loader and replace this file."
            say(text)
            pcall(menu.add_text, "Specter update", text)
        end
        local plan, ticket, nonce, user = field(body, "plan") or "", field(body, "ticket"), field(body, "nonce"), field(body, "user")
        if (not plan:find("^pm_")) then
            busy = false
            status("This key is for Specter on gamesense, not for Primordial.")
            return
        end
        save_key(key)
        local allowed = parse_builds(body)
        local build = plan
        if (#allowed > 1) then
            -- a key with several builds: the one picked with a button, else the one loaded last time, else wait for a button
            local pick = chosen or read_build()
            build = nil
            for _, name in ipairs(allowed) do
                if (name == pick) then build = name end
            end
            if (build == nil) then
                busy = false
                show_builds(allowed)
                status("Choose a build: " .. table.concat((function()
                    local names = {}
                    for _, name in ipairs(allowed) do names[#names + 1] = build_name(name) end
                    return names
                end)(), " / ") .. ".")
                return
            end
            show_builds(allowed)
            save_build(build)
        elseif (#allowed == 1) then
            build = allowed[1]
        end
        status("Downloading Specter " .. build_name(build) .. "...")
        http:get(SERVER_URL .. "/script?key=" .. encode(key) .. "&hwid=" .. encode(hwid) .. "&plan=" .. encode(plan)
            .. "&build=" .. encode(build) .. "&ticket=" .. encode(ticket or "") .. "&nonce=" .. encode(nonce or ""), function(script)
            busy = false
            local text = script.body or ""
            if (#text < 1000 or text:find('^%s*{')) then
                status(REASONS[field(text, "reason") or ""] or "Download failed, try again.")
                return
            end
            run(text, key, hwid, build, user)
        end)
    end)
end

ui.login = menu.add_button(GROUP, "Login", function() login() end)

local saved = read_key()
if (saved ~= "") then
    pcall(ui.key.set, ui.key, saved)
    login()
end
