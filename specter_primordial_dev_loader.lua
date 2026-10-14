-- ======================================================================
--  SPECTER for Primordial | DEV LOADER
--
--  For the owners / devs only: no login, no key, no HWID, no server (the whole script, like the #staff build).
--  Put THIS file into primordial/scripts once (the copy the bot posts in #staff: it carries the dev token). Every time
--  it is loaded it downloads the newest specter_primordial.lua of main and runs it, so the script never has to be
--  copied into the folder again. The bot puts every new version of main on the license server; the repo is private,
--  so GitHub's raw files can not be read without a token.
--
--    1. the sources below are tried in order, the first one that answers with a script that compiles wins
--    2. the script that was downloaded is saved as csgo/specter/specter_primordial_dev_cache.lua
--    3. when GitHub can not be reached, the saved copy is used
--
--  The bot checks main every 5 minutes: a merge is there within ~5 minutes.
-- ======================================================================

if (_specter_pm_dev_loader_loaded) then
    return
end
_specter_pm_dev_loader_loaded = true

local DEV_TOKEN = "%%DEV_TOKEN%%"                                -- written in by the bot when it posts this file
local SOURCES = {
    "https://specter-license-mh111-production.up.railway.app/dev/script?token=" .. DEV_TOKEN,
}
local CACHE_FILE = "specter/specter_primordial_dev_cache.lua"    -- csgo/specter/...
local CHUNK_NAME = "=specter_primordial"

local function say(msg)
    client.log("[Specter dev] " .. tostring(msg))
end

local compile = loadstring or load

-- the file and http functions: Primordial's steam http and the game's file system (the libraries of the script);
-- SPECTER_DEV_TEST_IO replaces them in tests/primordial_regress.py
local io_ = SPECTER_DEV_TEST_IO
if (io_ == nil) then
    local client_log, global_vars_cur_time = client.log, global_vars.cur_time
    local memory_find_pattern, memory_create_interface = memory.find_pattern, memory.create_interface
    local libs = {}

libs.filesystem = (function()
    local a={}a.__index={}a.class=ffi.cast(ffi.typeof("void***"),memory_create_interface("filesystem_stdio.dll","VBaseFileSystem011"))a.v_table=a.class[0]a.full_class=ffi.cast("void***",memory_create_interface("filesystem_stdio.dll","VFileSystem017"))a.v_fltable=a.full_class[0]a.casts={read_file=ffi.cast("int (__thiscall*)(void*, void*, int, void*)",a.v_table[0]),write_file=ffi.cast("int (__thiscall*)(void*, void const*, int, void*)",a.v_table[1]),open_file=ffi.cast("void* (__thiscall*)(void*, const char*, const char*, const char*)",a.v_table[2]),close_file=ffi.cast("void (__thiscall*)(void*, void*)",a.v_table[3]),file_size=ffi.cast("unsigned int (__thiscall*)(void*, void*)",a.v_table[7]),file_exists=ffi.cast("bool (__thiscall*)(void*, const char*, const char*)",a.v_table[10]),delete_file=ffi.cast("void (__thiscall*)(void*, const char*, const char*)",a.v_fltable[20]),rename_file=ffi.cast("bool (__thiscall*)(void*, const char*, const char*, const char*)",a.v_fltable[21]),create_dir=ffi.cast("void (__thiscall*)(void*, const char*, const char*)",a.v_fltable[22]),is_dir=ffi.cast("bool (__thiscall*)(void*, const char*, const char*)",a.v_fltable[23])}local b=memory_create_interface("filesystem_stdio.dll","VFileSystem017")local c=ffi.cast(ffi.typeof("void***"),b)ffi.cdef([[ typedef void (__thiscall* AddSearchPath)(void*, const char*, const char*); typedef void (__thiscall* RemoveSearchPaths)(void*, const char*); typedef const char* (__thiscall* FindNext)(void*, int); typedef bool (__thiscall* FindIsDirectory)(void*, int); typedef void (__thiscall* FindClose)(void*, int); typedef const char* (__thiscall* FindFirstEx)(void*, const char*, const char*, int*); typedef long (__thiscall* GetFileTime)(void*, const char*, const char*); ]])local d=ffi.cast("AddSearchPath",c[0][11])local e=ffi.cast("RemoveSearchPaths",c[0][14])local f=ffi.cast("FindNext",c[0][33])local g=ffi.cast("FindIsDirectory",c[0][34])local h=ffi.cast("FindClose",c[0][35])local i=ffi.cast("FindFirstEx",c[0][36])a.modes={["r"]="r",["w"]="w",["a"]="a",["r+"]="r+",["w+"]="w+",["a+"]="a+",["rb"]="rb",["wb"]="wb",["ab"]="ab",["rb+"]="rb+",["wb+"]="wb+",["ab+"]="ab+"}a.open=function(j,k,l)if not a.modes[k]then error("File mode error!")end;local self=setmetatable({file=j,mode=k,path_id=l,handle=a.casts.open_file(a.class,j,k,l)},a)return self end;a.close=function(m)a.casts.close_file(a.class,m.handle)end;a.exists=function(j,l)return a.casts.file_exists(a.class,j,l)end;a.get_size=function(m)return a.casts.file_size(a.class,m.handle)end;a.write_binary=function(n,o)local m=a.open(n,"wb","MOD")a.casts.write_file(a.class,o,#o,m.handle)a.close(m)end;a.read_binary=function(n)local m=a.open(n,"rb","MOD")local p=a.get_size(m)local q=ffi.new("char[?]",p)a.casts.read_file(a.class,q,p,m.handle)a.close(m)return ffi.string(q,p)end;a.write=function(n,o)local m=a.open(n,"w","MOD")a.casts.write_file(a.class,o,#o,m.handle)a.close(m)end;a.append=function(n,o)local m=a.open(n,"a","MOD")a.casts.write_file(a.class,o,#o,m.handle)a.close(m)end;a.read=function(n)local m=a.open(n,"r","MOD")local p=a.get_size(m)local q=ffi.new("char[?]",p+1)a.casts.read_file(a.class,q,p,m.handle)a.close(m)return ffi.string(q)end;a.rename=function(r,s,l)return a.casts.rename_file(a.full_class,r,s,l)end;a.delete=function(j,l)a.casts.delete_file(a.full_class,j,l)end;a.create_directory=function(n,l)a.casts.create_dir(a.full_class,n,l)end;a.is_directory=function(n,l)return a.casts.is_dir(a.full_class,n,l)end;a.find_next=function(t)local j=a.casts.find_next(a.full_class,t)if j==0 then return nil end;return ffi.string(j)end;a.find_is_directory=function(t)return a.casts.find_is_dir(a.full_class,t)end;a.get_sec_files=function()local u=ffi.new("int[1]")e(c,"primordial")d(c,"././primordial/scripts","primordial")local v={}local j=i(c,"*","primordial",u)while j~=nil do local w=ffi.string(j)if g(c,u[0])==false and w:find("[.]lua")then table.insert(v,w)end;j=f(c,u[0])end;h(c,u[0])return v end;a.read_first_line=function(x)local y=x:match("^[^\r\n]+")return y end;a.get_files=function()local u=ffi.new("int[1]")e(c,"specter_configs")d(c,"./csgo/specter/","specter_configs")local v={}local j=i(c,"*","specter_configs",u)while j~=nil do local w=ffi.string(j)if g(c,u[0])==false and w:find("[.]cfg")then table.insert(v,w)end;j=f(c,u[0])end;h(c,u[0])return v end;return a
end)()

libs.httpcreator = (function()
    local a=ffi.cast("uint32_t**",ffi.cast("char**",ffi.cast("char*",memory_find_pattern("client.dll","B9 ? ? ? ? E8 ? ? ? ? 83 3D ? ? ? ? ? 0F 84"))+1)[0]+48)[0]or error("steam_http error")local b=ffi.cast("void***",a)or error("steam_http_ptr error")local c=b[0]or error("steam_http_ptr was null")local function d(e,f)return function(...)return e(f,...)end end;local g=d(ffi.cast(ffi.typeof("uint32_t(__thiscall*)(void*, uint32_t, const char*)"),c[0]),a)local h=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, uint64_t)"),c[5]),a)local i=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, uint32_t*)"),c[9]),a)local j=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, char*, uint32_t)"),c[10]),a)local k=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, uint32_t*)"),c[11]),a)local l=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, char*, uint32_t)"),c[12]),a)local m=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, const char*)"),c[3]),a)local n=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, const char*)"),c[4]),a)local o=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*)"),c[21]),a)local p=d(ffi.cast("bool(__thiscall*)(void*, uint32_t, const char*, const char*, uint32_t)",c[16]),a)local q=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t)"),c[14]),a)local r={}callbacks.add(e_callbacks.PAINT,function()for s,t in ipairs(r)do if global_vars_cur_time()-t.ls>t.task_interval then t:_process_tasks()t.ls=global_vars_cur_time()end end end)local u={}local v={__index=u}function u.new(w,x,y)return setmetatable({handle=w,url=x,callback=y,ticks=0},v)end;local z={}local A={__index=z}function z.new(B,C,D)return setmetatable({status=B,body=C,headers=D},A)end;function z:success()return self.status==200 end;local E={state={ok=200,no_response=204,timed_out=408,unknown=0}}local F={__index=E}function E.new(G)G=G or{}local t=setmetatable({requests={},task_interval=G.task_interval or 0.3,enable_debug=G.debug or false,timeout=G.timeout or 10,ls=global_vars_cur_time()},F)table.insert(r,t)return t end;local H={["get"]=1,["head"]=2,["post"]=3,["put"]=4,["delete"]=5,["options"]=6,["patch"]=7}function E:request(I,J,K,L)if type(K)=="function"and L==nil then L=K;K={}end;K=K or{}local M=H[tostring(I):lower()]local N=g(M,J)local O="application/text"if type(K.headers)=="table"then for P,Q in pairs(K.headers)do P=tostring(P)Q=tostring(Q)if P:lower()=="content-type"then O=Q end;m(N,P,Q)end end;if type(K.body)=="string"then local R=K.body:len()p(N,O,ffi.cast("unsigned char*",K.body),R)end;if type(K.params)=="table"then for S,T in pairs(K.params)do n(N,S,T)end end;if type(K.user_agent_info)=="string"then o(N,K.user_agent_info)end;if not h(N,0)then return end;local U=u.new(N,J,L)self:_debug("[HTTP] New %s request to: %s",I:upper(),J)table.insert(self.requests,U)end;function E:get(J,L)local N=g(1,J)if not h(N,0)then return end;local U=u.new(N,J,L)self:_debug("[HTTP] New GET request to: %s",J)table.insert(self.requests,U)end;function E:post(J,V,L)local N=g(3,J)for S,T in pairs(V)do n(N,S,T)end;if not h(N,0)then return end;local U=u.new(N,J,L)self:_debug("[HTTP] New POST request to: %s",J)table.insert(self.requests,U)end;function E:download_image(J,W,L)local N=g(1,J)if not h(N,0)then return end;local function X(z)if z:success()then libs.filesystem.write_binary(W,z.body)if L then L(true,"Image downloaded successfully")end else if L then L(false,"Failed to download image")end end end;local U=u.new(N,J,X)table.insert(self.requests,U)end;function E:_process_tasks()for S,T in ipairs(self.requests)do local Y=ffi.new("uint32_t[1]")self:_debug("[HTTP] Processing request #%s",S)if k(T.handle,Y)then local Z=Y[0]if Z>0 then local _=ffi.new("char[?]",Z)if l(T.handle,_,Z)then self:_debug("[HTTP] Request #%s finished. Invoking callback.",S)T.callback(z.new(E.state.ok,ffi.string(_,Z),setmetatable({},{__index=function(a0,a1)return E._get_header(T,a1)end})))table.remove(self.requests,S)q(T.handle)end else T.callback(z.new(E.state.no_response,nil,{}))table.remove(self.requests,S)q(T.handle)end end;local a2=T.ticks+1;if a2>=self.timeout then T.callback(z.new(E.state.timed_out,nil,{}))table.remove(self.requests,S)q(T.handle)else T.ticks=a2 end end end;function E:_debug(...)if self.enable_debug then client_log(string.format(...))end end;function E._get_header(U,a3)local Y=ffi.new("uint32_t[1]")if i(U.handle,a3,Y)then local Z=Y[0]local _=ffi.new("char[?]",Z)if j(U.handle,a3,_,Z)then return ffi.string(_,Z)end end;return nil end;function E._bind(a4,a5)return function(...)return a4[a5](a4,...)end end;return E
end)()

    local http = libs.httpcreator.new({ task_interval = 0.3, enable_debug = false, timeout = 20 })
    io_ = {
        get = function(url, cb)
            http:get(url, function(response) cb(response.body) end)
        end,
        read = function(name)
            if (not libs.filesystem.exists(name, "MOD")) then
                return nil
            end
            return libs.filesystem.read_binary(name)
        end,
        write = function(name, body)
            pcall(libs.filesystem.create_directory, "specter", "MOD")
            libs.filesystem.write_binary(name, body)
        end,
    }
end

-- compiles and runs the script; false + the reason when it does not
local function run(body)
    local fn, cerr = compile(body, CHUNK_NAME)
    if (not fn) then
        return false, "does not compile: " .. tostring(cerr)
    end
    local ok, rerr = xpcall(fn, function(e) return tostring(e) end)
    if (not ok) then
        return false, "error while running: " .. tostring(rerr)
    end
    return true
end

-- a lua script, not an error page
local function looks_like_script(body)
    if (type(body) ~= "string" or #body < 2000 or body:sub(1, 1) == "<" or body:sub(1, 3) == "not") then
        return false
    end
    return compile(body, CHUNK_NAME) ~= nil
end

local function from_cache(why)
    local ok, body = pcall(io_.read, CACHE_FILE)
    if (ok and type(body) == "string" and #body > 0) then
        say(why .. " - using the saved copy")
        local done, err = run(body)
        if (not done) then
            say("saved copy failed: " .. err)
        end
    else
        say(why .. " - and there is no saved copy yet. Check the internet connection")
    end
end

local function try(i)
    local url = SOURCES[i]
    if (url == nil) then
        from_cache("could not download the script")
        return
    end
    -- the time makes the url new for the caches on the way
    io_.get(url .. "&t=" .. tostring(client.get_unix_time and client.get_unix_time() or 0), function(body)
        if (not looks_like_script(body)) then
            try(i + 1)
            return
        end
        pcall(io_.write, CACHE_FILE, body)
        say(string.format("loaded the newest dev build (%d KB)", math.floor(#body / 1024)))
        local done, err = run(body)
        if (not done) then
            say("the downloaded script failed: " .. err)
        end
    end)
end

try(1)
