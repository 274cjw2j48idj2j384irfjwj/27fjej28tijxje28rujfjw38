--[[

    -- * script name: script
    -- * script version: v5.5
    -- * script author: e0n3x

]]

-- Advanced engineering revision. Native resolver remains the default.
-- Hard-coded FFI offsets require the exact original game/client build.
local client_version = "5.5-advanced.3"

local config_version = "1.0"
local config_build = "beta"

local beta_event = true

--- @info: lua requirements and(or) helpers
--- @region: include(s)

local libs = {
    tools = { }
}

antiaim_is_fakeducking, antiaim_get_max_desync_range, antiaim_get_real_angle, antiaim_get_body_lean, antiaim_is_inverting_body_lean, antiaim_is_inverting_desync, antiaim_get_desync_side, antiaim_get_manual_override, antiaim_get_fake_angle = antiaim.is_fakeducking, antiaim.get_max_desync_range, antiaim.get_real_angle, antiaim.get_body_lean, antiaim.is_inverting_body_lean, antiaim.is_inverting_desync, antiaim.get_desync_side, antiaim.get_manual_override, antiaim.get_fake_angle
client_precache_model, client_get_hitgroup_name, client_get_unix_time, client_log_screen, client_log, client_get_hitbox_name, client_delay_call, client_random_float, client_get_fps, client_get_tickrate, client_set_clantag, client_can_fire, client_random_int, client_is_in_thirdperson, client_get_local_time, client_ticks_to_time, client_time_to_ticks = client.precache_model, client.get_hitgroup_name, client.get_unix_time, client.log_screen, client.log, client.get_hitbox_name, client.delay_call, client.random_float, client.get_fps, client.get_tickrate, client.set_clantag, client.can_fire, client.random_int, client.is_in_thirdperson, client.get_local_time, client.ticks_to_time, client.time_to_ticks
debug_overlay_add_line, debug_overlay_add_capsule, debug_overlay_add_box, debug_overlay_add_sphere = debug_overlay.add_line, debug_overlay.add_capsule, debug_overlay.add_box, debug_overlay.add_sphere
engine_set_view_angles, engine_get_latency, engine_get_last_outgoing_command, engine_is_in_game, engine_get_level_name, engine_get_bsp_entities, engine_get_bsp_entity, engine_get_player_index_from_user_id, engine_get_bomb_radius, engine_get_level_name_short, engine_play_sound, engine_execute_cmd, engine_get_choked_commands, engine_is_connected, engine_is_app_active, engine_get_view_angles, engine_get_local_player_index, engine_get_last_acknowledged_command = engine.set_view_angles, engine.get_latency, engine.get_last_outgoing_command, engine.is_in_game, engine.get_level_name, engine.get_bsp_entities, engine.get_bsp_entity, engine.get_player_index_from_user_id, engine.get_bomb_radius, engine.get_level_name_short, engine.play_sound, engine.execute_cmd, engine.get_choked_commands, engine.is_connected, engine.is_app_active, engine.get_view_angles, engine.get_local_player_index, engine.get_last_acknowledged_command
entity_list_get_player_from_userid, entity_list_get_local_player, entity_list_get_local_player_or_spectating, entity_list_get_entities_by_classid, entity_list_get_highest_entity_index, entity_list_get_entities_by_name, entity_list_get_players, entity_list_get_entity = entity_list.get_player_from_userid, entity_list.get_local_player, entity_list.get_local_player_or_spectating, entity_list.get_entities_by_classid, entity_list.get_highest_entity_index, entity_list.get_entities_by_name, entity_list.get_players, entity_list.get_entity
exploits_get_charge, exploits_force_uncharge, exploits_force_recharge, exploits_get_max_charge, exploits_block_recharge, exploits_allow_recharge = exploits.get_charge, exploits.force_uncharge, exploits.force_recharge, exploits.get_max_charge, exploits.block_recharge, exploits.allow_recharge
game_rules_get_prop, game_rules_set_prop = game_rules.get_prop, game_rules.set_prop
global_vars_frame_count, global_vars_cur_time, global_vars_simticks_this_frame, global_vars_real_time, global_vars_tick_count, global_vars_frame_time, global_vars_absolute_frame_time, global_vars_interval_per_tick, global_vars_max_clients, global_vars_interpolation_amount, global_vars_server_tick = global_vars.frame_count, global_vars.cur_time, global_vars.simticks_this_frame, global_vars.real_time, global_vars.tick_count, global_vars.frame_time, global_vars.absolute_frame_time, global_vars.interval_per_tick, global_vars.max_clients, global_vars.interpolation_amount, global_vars.server_tick
input_is_key_released, input_find_key_bound_to_binding, input_get_mouse_pos, input_is_mouse_in_bounds, input_is_key_toggled, input_block, input_is_key_pressed, input_get_key_name, input_is_key_held, input_get_time_held, input_get_scroll_delta = input.is_key_released, input.find_key_bound_to_binding, input.get_mouse_pos, input.is_mouse_in_bounds, input.is_key_toggled, input.block, input.is_key_pressed, input.get_key_name, input.is_key_held, input.get_time_held, input.get_scroll_delta
materials_for_each, materials_find, materials_create = materials.for_each, materials.find, materials.create
memory_create_interface, memory_find_text, memory_find_pattern, memory_get_vfunc = memory.create_interface, memory.find_text, memory.find_pattern, memory.get_vfunc
menu_get_size, menu_find, menu_list, menu_add_slider, menu_add_checkbox, menu_text_input, menu_text, menu_multi_keybind, menu_add_list, menu_multi_selection, menu_add_text, menu_set_group_visibility, menu_add_text_input, menu_add_separator, menu_separator, menu_is_open, menu_slider, menu_selection, menu_color_picker, menu_button, menu_keybind, menu_e_keybind_modes, menu_add_button, menu_get_pos, menu_checkbox, menu_add_multi_selection, menu_reload_scripts, menu_add_selection, menu_set_group_column, menu_get_alpha_modifier = menu.get_size, menu.find, menu.list, menu.add_slider, menu.add_checkbox, menu.text_input, menu.text, menu.multi_keybind, menu.add_list, menu.multi_selection, menu.add_text, menu.set_group_visibility, menu.add_text_input, menu.add_separator, menu.separator, menu.is_open, menu.slider, menu.selection, menu.color_picker, menu.button, menu.keybind, menu.e_keybind_modes, menu.add_button, menu.get_pos, menu.checkbox, menu.add_multi_selection, menu.reload_scripts, menu.add_selection, menu.set_group_column, menu.get_alpha_modifier
player_resource_get_prop, player_resource_set_prop = player_resource.get_prop, player_resource.set_prop
ragebot_get_active_cfg, ragebot_get_autopeek_pos = ragebot.get_active_cfg, ragebot.get_autopeek_pos
render_get_text_size, render_push_clip, render_load_image, render_rect_filled, render_line, render_pop_clip, render_rect_fade, render_circle_filled, render_weapon_icon, render_rect, render_texture, render_get_screen_size, render_load_image_buffer, render_create_font, render_weapon_icon_size, render_pop_alpha_modifier, render_circle, render_text, render_get_default_font, render_polygon, render_polyline, render_triangle, render_push_alpha_modifier, render_triangle_filled, render_progress_circle, render_world_to_screen = render.get_text_size, render.push_clip, render.load_image, render.rect_filled, render.line, render.pop_clip, render.rect_fade, render.circle_filled, render.weapon_icon, render.rect, render.texture, render.get_screen_size, render.load_image_buffer, render.create_font, render.weapon_icon_size, render.pop_alpha_modifier, render.circle, render.text, render.get_default_font, render.polygon, render.polyline, render.triangle, render.push_alpha_modifier, render.triangle_filled, render.progress_circle, render.world_to_screen

-- menu.find walks Primordial's whole menu by name, and the script asks for the same items every frame / tick (jumpshot,
-- the anti-aim refs, the keybinds ...). An item never changes, so each one is looked up once (owners, Oct 2026: 70 fps)
do
    local find, cache = menu_find, {}
    menu_find = function(...)
        local n, parts = select("#", ...), { ... }
        for i = 1, n do
            if (type(parts[i]) ~= "string") then
                return find(...)
            end
        end
        local key = table.concat(parts, "\1")
        local item = cache[key]
        if (item == nil) then
            item = find(...)
            cache[key] = item
        end
        return item
    end
end

-- FPS profiler (dev build, owners Oct 2026: "az FPS nagyon gatya van 70 fpsem"): Utils "Profile 10 s" times every
-- callback and the parts of PAINT with the performance counter, then prints the most expensive ones and sends them to
-- the shot logs (kind "perf"). Nothing is timed while it is off
local perf = { on = false, t = {}, n = {}, frames = 0 }
do
    local ok, ffi = pcall(require, "ffi")
    local buf, freq = nil, 0
    if (ok) then
        pcall(ffi.cdef, "int QueryPerformanceCounter(int64_t *c); int QueryPerformanceFrequency(int64_t *f);")
        pcall(function()
            buf = ffi.new("int64_t[1]")
            ffi.C.QueryPerformanceFrequency(buf)
            freq = tonumber(buf[0]) or 0
        end)
    end
    perf.now = function()
        if (freq <= 0) then
            return 0
        end
        ffi.C.QueryPerformanceCounter(buf)
        return tonumber(buf[0]) / freq * 1000
    end
    perf.usable = freq > 0
end

perf.span = function(name, fn, ...)
    if (not perf.on) then
        return fn(...)
    end
    local t0 = perf.now()
    fn(...)
    perf.t[name] = (perf.t[name] or 0) + perf.now() - t0
    perf.n[name] = (perf.n[name] or 0) + 1
end

perf.add = function(id, name, fn)
    return callbacks.add(id, function(...)
        if (not perf.on) then
            return fn(...)
        end
        local t0 = perf.now()
        fn(...)
        local key = "cb " .. name
        perf.t[key] = (perf.t[key] or 0) + perf.now() - t0
        perf.n[key] = (perf.n[key] or 0) + 1
    end)
end

-- Primordial's circle calls take the radius as an int: a fraction (the watermark's moon / sun, 4.5 * night ...) is
-- "not a numeric type" and stops the PAINT callback, so every radius is rounded here
do
    local circle_filled, circle = render_circle_filled, render_circle
    render_circle_filled = function(pos, radius, ...)
        return circle_filled(pos, math.max(0, math.floor((tonumber(radius) or 0) + 0.5)), ...)
    end
    render_circle = function(pos, radius, ...)
        return circle(pos, math.max(0, math.floor((tonumber(radius) or 0) + 0.5)), ...)
    end
end
trace_line, trace_bullet, trace_hull = trace.line, trace.bullet, trace.hull
ipairs, assert, pairs, next, tostring, tonumber, setmetatable, unpack, type, getmetatable, pcall, error = ipairs, assert, pairs, next, tostring, tonumber, setmetatable, unpack, type, getmetatable, pcall, error

libs.etr = (function()
    local b={}function b.round(c)return math.floor(c+.5)end;function b.clamp(d,e,f)if d<e then return e elseif d>f then return f else return d end end;function b.lerp(g,h,i)if type(h)=="number"and math.floor(h)~=h then goto j end::j::local k,l=b.clamp(globals.frame_time()*i,0,1),0.3;if k>=1-l then return h else return g+(h-g)*k end end;function b.glow(m,n,o,p,q)local r,s=m.x,m.y;local t,u=n.x,n.y;local v,w,x,y=p.r,p.g,p.b,p.a;for z=2,math.floor(q)do local A=z/2;local B=math.floor(y/q*(q-z))render_rect(vec2_t(r-A,s-A),vec2_t(t+A*2,u+A*2),color_t(v,w,x,B),o)end end;function b.color_anim(v,w,x,y)return color_t(math.floor(v+0.5),math.floor(w+0.5),math.floor(x+0.5),y==nil and 255 or(math.floor(y+0.5)or 255))end;c_render={}c_render.frame=function(C,D,E,F,o,G)if F==nil then F=1 end;if o==nil then o=5 end;if G==nil then G=1 end;if F==1 then render_rect(C,D-C,color_t(255,255,255,math.floor(150*G)),o)end end;c_render.drag_frame=function(C,D,E)if not menu_is_open()then return end;c_render.frame(C,D,E,1,2,1)end;local H={}H.data={}H.new=function(I,d,i)if H.data[I]==nil then H.data[I]=d end;H.data[I]=b.lerp(H.data[I],d,i)return H.data[I]end;H.fn_smooth_lerp=function(g,h,i)if math.abs(g-h)<1 or g==h then return h end;local d=b.lerp(g,h,i)return d end;local J={}J.data={}J.target=""b.new=function(I,K,n)local L={name=I,pos=K,d_pos=vec2_t(0,0),size=n,anim=0,drag=false}J.__index=J;table.insert(J.data,L)return setmetatable(L,J)end;function J:lerp(M,N,i)local O=self[M]local P=b.clamp(globals.frame_time()*i,0,0.5)self[M]=vec2_t((N.x-O.x)*P+O.x,(N.y-O.y)*P+O.y)end;function J:limit_pos(Q)if self.pos.x<=0 then self.pos.x=0 end;if self.pos.x+self.size.x>=Q.x-1 then self.pos.x=Q.x-self.size.x-1 end;if self.pos.y<=0 then self.pos.y=0 end;if self.pos.y+self.size.y>=Q.y-1 then self.pos.y=Q.y-self.size.y-1 end end;function J:is_in_area(R)return R.x>=self.pos.x-10 and R.x<=self.pos.x+self.size.x+10 and R.y>=self.pos.y-10 and R.y<=self.pos.y+self.size.y+10 end;function J:update()local S=render_get_screen_size()local R=input_get_mouse_pos()local T=input_is_key_held(e_keys.MOUSE_LEFT)local U=input_is_key_pressed(e_keys.MOUSE_RIGHT)local V=self:is_in_area(R)local W=self.drag;local X=J.target;local Y=X==""or X==self.name;local E=(X==self.name or V and menu_is_open())and color_t(255,255,255,255)or color_t(100,100,100,100)c_render.drag_frame(self.pos-vec2_t(10,10),self.pos+self.size+vec2_t(10,10),E)local Z=0;if V and menu_is_open()and Y then Z=H.new("Drag alpha"..self.name,255,4)render_text(render_get_default_font(),"Press M2 to center",self.pos+vec2_t(-5,self.size.y+10),color_t(255,255,255,255))else Z=H.new("Drag alpha"..self.name,0,4)end;if menu_is_open()and V and T and not W and Y then self.drag=true;self.d_pos=self.pos-R elseif menu_is_open()and V and U and not W and Y then self.pos.x=S.x/2-self.size.x/2 end;if not T then J.target=""self.drag=false end;if W and menu_is_open()then J.target=self.name;new=R+self.d_pos;self.pos=new;self:limit_pos(S)end end;local _=ffi.typeof("unsigned char[?]")local a0=ffi.typeof("unsigned int[?]")local a1=65535;local function a2(a3,b,a4)for a5=0,3 do b[a4+a5]=bit.band(bit.rshift(a3,(3-a5)*8),0xFF)end end;local a6={}a6.__index=a6;function a6:writeBytes(a7,a4,a8)a4=a4 or 1;a8=a8 or#a7;for a5=a4,a4+a8-1 do table.insert(self.output,string.char(a7[a5]))end end;function a6:write(a9)local aa=#a9;local ab=1;while aa>0 do if self.positionY>=self.height then error("Pixels already written")end;if self.deflateFilled==0 then local n=a1;if self.uncompRemain<n then n=self.uncompRemain end;local ac={bit.band(self.uncompRemain<=a1 and 1 or 0,0xFF),bit.band(bit.rshift(n,0),0xFF),bit.band(bit.rshift(n,8),0xFF),bit.band(bit.bxor(bit.rshift(n,0),0xFF),0xFF),bit.band(bit.bxor(bit.rshift(n,8),0xFF),0xFF)}self:writeBytes(ac)self:crc32(ac,1,#ac)end;assert(self.positionX<self.lineSize and self.deflateFilled<a1)if self.positionX==0 then local x={0}self:writeBytes(x)self:crc32(x,1,1)self:adler32(x,1,1)self.positionX=self.positionX+1;self.uncompRemain=self.uncompRemain-1;self.deflateFilled=self.deflateFilled+1 else local ad=a1-self.deflateFilled;if self.lineSize-self.positionX<ad then ad=self.lineSize-self.positionX end;if aa<ad then ad=aa end;assert(ad>0)self:writeBytes(a9,ab,ad)self:crc32(a9,ab,ad)self:adler32(a9,ab,ad)aa=aa-ad;ab=ab+ad;self.positionX=self.positionX+ad;self.uncompRemain=self.uncompRemain-ad;self.deflateFilled=self.deflateFilled+ad end;if self.deflateFilled>=a1 then self.deflateFilled=0 end;if self.positionX==self.lineSize then self.positionX=0;self.positionY=self.positionY+1;if self.positionY==self.height then local ae={0,0,0,0,0,0,0,0,0x00,0x00,0x00,0x00,0x49,0x45,0x4E,0x44,0xAE,0x42,0x60,0x82}a2(self.adler,ae,1)self:crc32(ae,1,4)a2(self.crc,ae,5)self:writeBytes(ae)self.done=true end end end end;function a6:crc32(a7,a4,a8)self.crc=bit.bnot(self.crc)for a5=a4,a4+a8-1 do local af=a7[a5]for ag=0,7 do local ah=bit.band(bit.bxor(self.crc,bit.rshift(af,ag)),1)self.crc=bit.bxor(bit.rshift(self.crc,1),bit.band(-ah,0xEDB88320))end end;self.crc=bit.bnot(self.crc)end;function a6:adler32(a7,a4,a8)local ai=bit.band(self.adler,0xFFFF)local aj=bit.rshift(self.adler,16)for a5=a4,a4+a8-1 do ai=(ai+a7[a5])%65521;aj=(aj+ai)%65521 end;self.adler=bit.bor(bit.lshift(aj,16),ai)end;local function ak(al,am,an)an=an or"rgb"local ao,ap;if an=="rgb"then ao,ap=3,2 elseif an=="rgba"then ao,ap=4,6 else error("Invalid color mode")end;local aq=setmetatable({width=al,height=am,done=false,output={}},a6)aq.lineSize=al*ao+1;aq.uncompRemain=aq.lineSize*am;local ar=math.ceil(aq.uncompRemain/a1)local as=ar*5+6;as=as+aq.uncompRemain;local ac={0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52,0,0,0,0,0,0,0,0,0x08,ap,0x00,0x00,0x00,0,0,0,0,0,0,0,0,0x49,0x44,0x41,0x54,0x08,0x1D}a2(al,ac,17)a2(am,ac,21)a2(as,ac,34)aq.crc=0;aq:crc32(ac,13,17)a2(aq.crc,ac,30)aq:writeBytes(ac)aq.crc=0;aq:crc32(ac,38,6)aq.adler=1;aq.positionX=0;aq.positionY=0;aq.deflateFilled=0;return aq end;ffi.cdef([[ typedef struct { void* steam_client; void* steam_user; void* steam_friends; void* steam_utils; void* steam_matchmaking; void* steam_user_stats; void* steam_apps; void* steam_matchmakingservers; void* steam_networking; void* steam_remotestorage; void* steam_screenshots; void* steam_http; void* steam_unidentifiedmessages; void* steam_controller; void* steam_ugc; void* steam_applist; void* steam_music; void* steam_musicremote; void* steam_htmlsurface; void* steam_inventory; void* steam_video; } S_steamApiCtx_t; ]])local at=ffi.cast("S_steamApiCtx_t**",ffi.cast("char*",memory_find_pattern("client.dll","FF 15 ?? ?? ?? ?? B9 ?? ?? ?? ?? E8 ?? ?? ?? ?? 6A"))+7)[0]or error("invalid interface",2)local au=ffi.cast("void***",at.steam_friends)local av=ffi.cast("void***",at.steam_utils)local aw=ffi.cast("int(__thiscall*)(void*, uint64_t)",au[0][34])local ax=ffi.cast("int(__thiscall*)(void*, uint64_t)",au[0][35])local ay=ffi.cast("int(__thiscall*)(void*, uint64_t)",au[0][36])local az=ffi.cast("bool(__thiscall*)(void*, int, uint32_t*, uint32_t*)",av[0][5])local aA=ffi.cast("bool(__thiscall*)(void*, int, unsigned char*, int)",av[0][6])local aB={}get_steam_avatar=function(aC,n)local aD=string.format("%s_%s",aC,n)local aE;local aF=""if aB[aD]==nil then local aG;if n==nil then aG=aw elseif n>64 then aG=ay elseif n>32 then aG=ax else aG=aw end;local aH=aG(au,tonumber(aC:sub(4,-1))+76500000000000000ULL)if aH>0 then local al=a0(1)local am=a0(1)if az(av,aH,al,am)then if al[0]>0 and am[0]>0 then local aI=al[0]*am[0]*4;local aJ=_(aI)if aA(av,aH,aJ,aI)then local aK=ak(al[0],am[0],"rgba")for r=0,al[0]-1 do for s=0,am[0]-1 do local aL=r*am[0]*4+s*4;aK:write{aJ[aL],aJ[aL+1],aJ[aL+2],aJ[aL+3]}end end;for a5=1,#aK.output do aF=aF..aK.output[a5]end;aB[aD]=render_load_image_buffer(aF)end end end elseif aH~=-1 then aB[aD]=nil end end;if aB[aD]then return aB[aD]end end;b.data={}b.default_image=render_load_image_buffer("\xFF\xD8\xFF\xE0\x00\x10\x4A\x46\x49\x46\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xFE\x00\x3B\x43\x52\x45\x41\x54\x4F\x52\x3A\x20\x67\x64\x2D\x6A\x70\x65\x67\x20\x76\x31\x2E\x30\x20\x28\x75\x73\x69\x6E\x67\x20\x49\x4A\x47\x20\x4A\x50\x45\x47\x20\x76\x36\x32\x29\x2C\x20\x71\x75\x61\x6C\x69\x74\x79\x20\x3D\x20\x38\x30\x0A\xFF\xDB\x00\x43\x00\x06\x04\x05\x06\x05\x04\x06\x06\x05\x06\x07\x07\x06\x08\x0A\x10\x0A\x0A\x09\x09\x0A\x14\x0E\x0F\x0C\x10\x17\x14\x18\x18\x17\x14\x16\x16\x1A\x1D\x25\x1F\x1A\x1B\x23\x1C\x16\x16\x20\x2C\x20\x23\x26\x27\x29\x2A\x29\x19\x1F\x2D\x30\x2D\x28\x30\x25\x28\x29\x28\xFF\xDB\x00\x43\x01\x07\x07\x07\x0A\x08\x0A\x13\x0A\x0A\x13\x28\x1A\x16\x1A\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\x28\xFF\xC0\x00\x11\x08\x00\x40\x00\x40\x03\x01\x22\x00\x02\x11\x01\x03\x11\x01\xFF\xC4\x00\x1F\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\xFF\xC4\x00\xB5\x10\x00\x02\x01\x03\x03\x02\x04\x03\x05\x05\x04\x04\x00\x00\x01\x7D\x01\x02\x03\x00\x04\x11\x05\x12\x21\x31\x41\x06\x13\x51\x61\x07\x22\x71\x14\x32\x81\x91\xA1\x08\x23\x42\xB1\xC1\x15\x52\xD1\xF0\x24\x33\x62\x72\x82\x09\x0A\x16\x17\x18\x19\x1A\x25\x26\x27\x28\x29\x2A\x34\x35\x36\x37\x38\x39\x3A\x43\x44\x45\x46\x47\x48\x49\x4A\x53\x54\x55\x56\x57\x58\x59\x5A\x63\x64\x65\x66\x67\x68\x69\x6A\x73\x74\x75\x76\x77\x78\x79\x7A\x83\x84\x85\x86\x87\x88\x89\x8A\x92\x93\x94\x95\x96\x97\x98\x99\x9A\xA2\xA3\xA4\xA5\xA6\xA7\xA8\xA9\xAA\xB2\xB3\xB4\xB5\xB6\xB7\xB8\xB9\xBA\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xD2\xD3\xD4\xD5\xD6\xD7\xD8\xD9\xDA\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xF1\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9\xFA\xFF\xC4\x00\x1F\x01\x00\x03\x01\x01\x01\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\xFF\xC4\x00\xB5\x11\x00\x02\x01\x02\x04\x04\x03\x04\x07\x05\x04\x04\x00\x01\x02\x77\x00\x01\x02\x03\x11\x04\x05\x21\x31\x06\x12\x41\x51\x07\x61\x71\x13\x22\x32\x81\x08\x14\x42\x91\xA1\xB1\xC1\x09\x23\x33\x52\xF0\x15\x62\x72\xD1\x0A\x16\x24\x34\xE1\x25\xF1\x17\x18\x19\x1A\x26\x27\x28\x29\x2A\x35\x36\x37\x38\x39\x3A\x43\x44\x45\x46\x47\x48\x49\x4A\x53\x54\x55\x56\x57\x58\x59\x5A\x63\x64\x65\x66\x67\x68\x69\x6A\x73\x74\x75\x76\x77\x78\x79\x7A\x82\x83\x84\x85\x86\x87\x88\x89\x8A\x92\x93\x94\x95\x96\x97\x98\x99\x9A\xA2\xA3\xA4\xA5\xA6\xA7\xA8\xA9\xAA\xB2\xB3\xB4\xB5\xB6\xB7\xB8\xB9\xBA\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xD2\xD3\xD4\xD5\xD6\xD7\xD8\xD9\xDA\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9\xFA\xFF\xDA\x00\x0C\x03\x01\x00\x02\x11\x03\x11\x00\x3F\x00\xF0\x89\xE6\x93\xCF\x93\xF7\x8F\xF7\x8F\xF1\x1F\x5A\x67\x9D\x27\xFC\xF4\x7F\xFB\xE8\xD1\x3F\xFA\xF9\x3F\xDE\x3F\xCE\x99\x40\x0F\xF3\xA4\xFF\x00\x9E\x8F\xFF\x00\x7D\x1A\x3C\xE9\x3F\xE7\xA3\xFF\x00\xDF\x46\x99\x5A\x3A\x2E\x87\xAA\xEB\x93\x34\x5A\x3E\x9D\x75\x7A\xEB\xF7\x84\x11\x17\xDB\xF5\x23\xA7\xE3\x40\x14\x7C\xE9\x3F\xE7\xA3\xFF\x00\xDF\x46\x8F\x3A\x4F\xF9\xE8\xFF\x00\xF7\xD1\xAD\x1D\x6F\xC3\xBA\xCE\x86\x57\xFB\x63\x4B\xBC\xB2\x0F\xC2\xB4\xD1\x15\x56\xFA\x1E\x86\xB2\xE8\x01\xFE\x74\x9F\xF3\xD1\xFF\x00\xEF\xA3\x4F\x82\x69\x3C\xF8\xFF\x00\x78\xFF\x00\x78\x7F\x11\xF5\xA8\x69\xF0\x7F\xAF\x8F\xFD\xE1\xFC\xE8\x00\x9F\xFD\x7C\x9F\xEF\x1F\xE7\x4C\xA7\xCF\xFE\xBE\x4F\xF7\x8F\xF3\xA6\x50\x05\xDD\x13\x4F\x7D\x5B\x59\xB0\xD3\xA2\x60\xB2\x5D\xCF\x1C\x0A\x4F\x62\xCC\x14\x1F\xD6\xBE\xA8\xF1\x77\x88\x74\x8F\x84\x5E\x12\xD3\xED\x34\xDD\x3C\x4A\xD2\x13\x1C\x10\x06\xD9\xBC\x80\x37\x48\xED\x8E\xBC\x8C\xFA\x93\x5F\x27\x5B\xCF\x2D\xB5\xC4\x73\xDB\xC8\xF1\x4D\x13\x07\x49\x11\x8A\xB2\xB0\x39\x04\x11\xD0\x83\x56\xF5\x4D\x67\x53\xD5\xFC\xBF\xED\x5D\x46\xF2\xF7\xCB\xCE\xCF\xB4\x4C\xD2\x6D\xCF\x5C\x64\x9C\x74\x14\x01\xF5\x17\xC3\xEF\x1C\xE9\x9F\x14\x74\xDD\x47\x4B\xD5\x74\xC4\x8A\x54\x4C\xCD\x6C\xED\xE6\x24\x88\x4E\x37\x29\xC0\x20\x83\xF9\x71\x83\x5F\x34\xF8\xDB\x44\x1E\x1C\xF1\x66\xA9\xA4\xAB\x17\x4B\x59\xCA\x23\x1E\xA5\x0F\x2B\x9F\x7C\x11\x5F\x42\x7C\x16\xF0\xA4\x5E\x06\xF0\x9D\xDF\x88\xBC\x40\xE2\xDA\xE6\xE6\x11\x2C\x9E\x67\x1E\x44\x23\x90\x0F\xFB\x47\xA9\x1F\x41\xD6\xBE\x7A\xF1\xAE\xB7\xFF\x00\x09\x1F\x8A\xF5\x4D\x58\x21\x44\xBA\x98\xBA\x29\xEA\x13\xA2\x83\xEF\x80\x28\x03\x16\x9F\x07\xFA\xF8\xFF\x00\xDE\x1F\xCE\x99\x4F\x83\xFD\x7C\x7F\xEF\x0F\xE7\x40\x04\xFF\x00\xEB\xE4\xFF\x00\x78\xFF\x00\x3A\x65\x3E\x7F\xF5\xF2\x7F\xBC\x7F\x9D\x32\x80\x0A\xED\xFE\x0B\x69\x96\xDA\xBF\xC4\xAD\x1E\xDA\xF6\x31\x24\x0A\xCF\x31\x46\x19\x0C\x51\x19\x86\x7D\xB2\x05\x71\x15\xD3\xFC\x36\xD3\x75\x4D\x5F\xC6\x16\x76\x5A\x0E\xA0\x74\xED\x42\x45\x90\xC7\x72\x19\x97\x68\x08\x49\xE5\x79\xE4\x02\x3F\x1A\x00\xF5\x1F\xDA\x6F\xC4\xF7\x62\xFE\xCF\xC3\x70\x31\x8E\xCF\xCA\x5B\xA9\xF1\xD6\x46\x2C\xC1\x41\xF6\x1B\x73\xF5\x3E\xD5\xE0\xF5\xD8\xFC\x56\xD1\xF5\xAD\x13\xC4\xE9\x6B\xE2\x3D\x50\xEA\x97\xA6\xDD\x1C\x4E\x5D\x9B\x08\x4B\x61\x72\xDC\xF5\x07\xF3\xAE\x3A\x80\x0A\x7C\x1F\xEB\xE3\xFF\x00\x78\x7F\x3A\x65\x3E\x0F\xF5\xF1\xFF\x00\xBC\x3F\x9D\x00\x13\xFF\x00\xAF\x93\xFD\xE3\xFC\xE9\x95\x34\xF0\xC9\xE7\xC9\xFB\xB7\xFB\xC7\xF8\x4F\xAD\x33\xC9\x93\xFE\x79\xBF\xFD\xF2\x68\x01\x95\x7B\x43\xD5\xEF\xF4\x2D\x4A\x2D\x43\x49\xB8\x6B\x6B\xC8\xC1\x09\x22\x80\x48\xC8\x20\xF5\x04\x74\x26\xAA\x79\x32\x7F\xCF\x37\xFF\x00\xBE\x4D\x1E\x4C\x9F\xF3\xCD\xFF\x00\xEF\x93\x40\x1A\x1E\x21\xD7\xB5\x3F\x11\x5F\x8B\xDD\x6A\xED\xAE\xEE\x82\x08\xC4\x8C\xA0\x1D\xA0\x92\x07\x00\x7A\x9A\xCC\xA7\xF9\x32\x7F\xCF\x37\xFF\x00\xBE\x4D\x1E\x4C\x9F\xF3\xCD\xFF\x00\xEF\x93\x40\x0C\xA7\xC1\xFE\xBE\x3F\xF7\x87\xF3\xA3\xC9\x93\xFE\x79\xBF\xFD\xF2\x69\xF0\x43\x27\x9F\x1F\xEE\xDF\xEF\x0F\xE1\x3E\xB4\x01\xFF\xD9")b.fn_create_item=function(I)b.data[I]={}b.data[I].url=nil;b.data[I].image=nil;b.data[I].loaded=false;b.data[I].loading=false end;b.get_avatar=function(I,aM)if b.data[I]and b.data[I].loaded then return b.data[I].image end;if b.data[I]==nil then b.fn_create_item(I)local aN,aO=entity_list_get_entity(aM):get_steamids()if#aO<5 then return end;if aO==nil or b.default_image==nil then return nil end;b.data[I].image=get_steam_avatar(aO,64)b.data[I].loaded=true end;return b.default_image end;local aP={}local aQ=function(aR)local buffer={}local aS=8*global_vars_frame_time()local aT=entity_list_get_entities_by_name("CCSPlayer")for aU,aV in pairs(aT)do if aV:get_index()~=aR:get_index()then if aV==nil then return end;if not aV:get_prop("m_iHealth")~=0 and not aV:is_dormant()then local aW=aV:get_prop("m_iObserverMode")local aX=aV:get_prop("m_hObserverTarget")if aX then if aW>=4 or aW<=5 then local aY=entity_list_get_entity(aX)if aY~=nil and aY:get_index()==aR:get_index()then if aP[aV:get_index()]==nil then aP[aV:get_index()]={alpha=0,offset=0,active=true}end;aP[aV:get_index()].active=true;aP[aV:get_index()].alpha=aP[aV:get_index()].alpha+aS;if aP[aV:get_index()].alpha>1 then aP[aV:get_index()].alpha=1 end;table.insert(buffer,1,{["alpha"]=aP[aV:get_index()].alpha,["id"]=aV:get_index(),["name"]=aV:get_name()})elseif aP[aV:get_index()]~=nil then aP[aV:get_index()].active=false;aP[aV:get_index()].alpha=aP[aV:get_index()].alpha-aS;if aP[aV:get_index()].alpha<=0 then aP[aV:get_index()]=nil end end end else aP[aV:get_index()]=nil end else aP[aV:get_index()]=nil end end end;return buffer end;callbacks.add(e_callbacks.EVENT,function()if buffer==nil then return end;for a4,d in pairs(buffer)do if aQ(d)==nil then print()end end end,"round_start")b.get_spectators=function()if not engine_is_connected()or entity_list_get_local_player()==nil then return end;local aZ=entity_list_get_local_player()if aZ:get_prop("m_iHealth")>0 then return aQ(aZ)else local a_=aZ:get_prop("m_hObserverTarget")if a_ then local b0=entity_list_get_entity(a_)if b0~=nil then if b0:is_player()and b0:is_alive()then return aQ(b0)end end end end end;return b
end)()

libs.json = (function()
    local a={_version="0.1.2"}local b;local c={["\\"]="\\",["\""]="\"",["\b"]="b",["\f"]="f",["\n"]="n",["\r"]="r",["\t"]="t"}local d={["/"]="/"}for e,f in pairs(c)do d[f]=e end;local function g(h)return"\\"..(c[h]or string.format("u%04x",h:byte()))end;local function i(j)return"null"end;local function k(j,l)local m={}l=l or{}if l[j]then error("circular reference")end;l[j]=true;if rawget(j,1)~=nil or next(j)==nil then local n=0;for e in pairs(j)do if type(e)~="number"then error("invalid table: mixed or invalid key types")end;n=n+1 end;if n~=#j then error("invalid table: sparse array")end;for o,f in ipairs(j)do table.insert(m,b(f,l))end;l[j]=nil;return"["..table.concat(m,",").."]"else for e,f in pairs(j)do if type(e)~="string"then error("invalid table: mixed or invalid key types")end;table.insert(m,b(e,l)..":"..b(f,l))end;l[j]=nil;return"{"..table.concat(m,",").."}"end end;local function p(j)return'"'..j:gsub('[%z\1-\31\\"]',g)..'"'end;local function q(j)if j~=j or j<=-math.huge or j>=math.huge then error("unexpected number value '"..tostring(j).."'")end;return string.format("%.14g",j)end;local r={["nil"]=i,["table"]=k,["string"]=p,["number"]=q,["boolean"]=tostring}b=function(j,l)local s=type(j)local t=r[s]if t then return t(j,l)end;error("unexpected type '"..s.."'")end;function a.encode(j)return b(j)end;local u;local function v(...)local m={}for o=1,select("#",...)do m[select(o,...)]=true end;return m end;local w=v(" ","\t","\r","\n")local x=v(" ","\t","\r","\n","]","}",",")local y=v("\\","/",'"',"b","f","n","r","t","u")local z=v("true","false","null")local A={["true"]=true,["false"]=false,["null"]=nil}local function B(C,D,E,F)for o=D,#C do if E[C:sub(o,o)]~=F then return o end end;return#C+1 end;local function G(C,D,H)local I=1;local J=1;for o=1,D-1 do J=J+1;if C:sub(o,o)=="\n"then I=I+1;J=1 end end;error(string.format("%s at line %d col %d",H,I,J))end;local function K(n)local t=math.floor;if n<=0x7f then return string.char(n)elseif n<=0x7ff then return string.char(t(n/64)+192,n%64+128)elseif n<=0xffff then return string.char(t(n/4096)+224,t(n%4096/64)+128,n%64+128)elseif n<=0x10ffff then return string.char(t(n/262144)+240,t(n%262144/4096)+128,t(n%4096/64)+128,n%64+128)end;error(string.format("invalid unicode codepoint '%x'",n))end;local function L(M)local N=tonumber(M:sub(1,4),16)local O=tonumber(M:sub(7,10),16)if O then return K((N-0xd800)*0x400+O-0xdc00+0x10000)else return K(N)end end;local function P(C,o)local m=""local Q=o+1;local e=Q;while Q<=#C do local R=C:byte(Q)if R<32 then G(C,Q,"control character in string")elseif R==92 then m=m..C:sub(e,Q-1)Q=Q+1;local h=C:sub(Q,Q)if h=="u"then local S=C:match("^[dD][89aAbB]%x%x\\u%x%x%x%x",Q+1)or C:match("^%x%x%x%x",Q+1)or G(C,Q-1,"invalid unicode escape in string")m=m..L(S)Q=Q+#S else if not y[h]then G(C,Q-1,"invalid escape char '"..h.."' in string")end;m=m..d[h]end;e=Q+1 elseif R==34 then m=m..C:sub(e,Q-1)return m,Q+1 end;Q=Q+1 end;G(C,o,"expected closing quote for string")end;local function T(C,o)local R=B(C,o,x)local M=C:sub(o,R-1)local n=tonumber(M)if not n then G(C,o,"invalid number '"..M.."'")end;return n,R end;local function U(C,o)local R=B(C,o,x)local V=C:sub(o,R-1)if not z[V]then G(C,o,"invalid literal '"..V.."'")end;return A[V],R end;local function W(C,o)local m={}local n=1;o=o+1;while 1 do local R;o=B(C,o,w,true)if C:sub(o,o)=="]"then o=o+1;break end;R,o=u(C,o)m[n]=R;n=n+1;o=B(C,o,w,true)local X=C:sub(o,o)o=o+1;if X=="]"then break end;if X~=","then G(C,o,"expected ']' or ','")end end;return m,o end;local function Y(C,o)local m={}o=o+1;while 1 do local Z,j;o=B(C,o,w,true)if C:sub(o,o)=="}"then o=o+1;break end;if C:sub(o,o)~='"'then G(C,o,"expected string for key")end;Z,o=u(C,o)o=B(C,o,w,true)if C:sub(o,o)~=":"then G(C,o,"expected ':' after key")end;o=B(C,o+1,w,true)j,o=u(C,o)m[Z]=j;o=B(C,o,w,true)local X=C:sub(o,o)o=o+1;if X=="}"then break end;if X~=","then G(C,o,"expected '}' or ','")end end;return m,o end;local _={['"']=P,["0"]=T,["1"]=T,["2"]=T,["3"]=T,["4"]=T,["5"]=T,["6"]=T,["7"]=T,["8"]=T,["9"]=T,["-"]=T,["t"]=U,["f"]=U,["n"]=U,["["]=W,["{"]=Y}u=function(C,D)local X=C:sub(D,D)local t=_[X]if t then return t(C,D)end;G(C,D,"unexpected character '"..X.."'")end;function a.parse(C)if type(C)~="string"then error("expected argument of type string, got "..type(C))end;local m,D=u(C,B(C,1,w,true))D=B(C,D,w,true)if D<=#C then G(C,D,"trailing garbage")end;return m end;return a
end)()

libs.base64 = (function()
    local a={}local b,c,d=bit.lshift,bit.rshift,bit.band;local e,f,g,h,i,j,tostring,error,pairs=string.char,string.byte,string.gsub,string.sub,string.format,table.concat,tostring,error,pairs;local k=function(l,m,n)return d(c(l,m),b(1,n)-1)end;local function o(p)local q,r={},{}for s=1,65 do local t=f(h(p,s,s))or 32;if r[t]~=nil then error("invalid alphabet: duplicate character "..tostring(t),3)end;q[s-1]=t;r[t]=s-1 end;return q,r end;local u,v={},{}u["base64"],v["base64"]=o("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")u["base64url"],v["base64url"]=o("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")local w={__index=function(x,y)if type(y)=="string"and y:len()==64 or y:len()==65 then u[y],v[y]=o(y)return x[y]end end}setmetatable(u,w)setmetatable(v,w)function a.encode(z,q)q=u[q or"base64"]or error("invalid alphabet specified",2)z=tostring(z)local A,B,C={},1,#z;local D=C%3;local E={}for s=1,C-D,3 do local F,G,H=f(z,s,s+2)local l=F*0x10000+G*0x100+H;local I=E[l]if not I then I=e(q[k(l,18,6)],q[k(l,12,6)],q[k(l,6,6)],q[k(l,0,6)])E[l]=I end;A[B]=I;B=B+1 end;if D==2 then local F,G=f(z,C-1,C)local l=F*0x10000+G*0x100;A[B]=e(q[k(l,18,6)],q[k(l,12,6)],q[k(l,6,6)],q[64])elseif D==1 then local l=f(z,C)*0x10000;A[B]=e(q[k(l,18,6)],q[k(l,12,6)],q[64],q[64])end;return j(A)end;function a.decode(J,r)r=v[r or"base64"]or error("invalid alphabet specified",2)local K="[^%w%+%/%=]"if r then local L,M;for N,O in pairs(r)do if O==62 then L=N elseif O==63 then M=N end end;K=i("[^%%w%%%s%%%s%%=]",e(L),e(M))end;J=g(tostring(J),K,'')local E={}local A,B={},1;local C=#J;local P=h(J,-2)=="=="and 2 or h(J,-1)=="="and 1 or 0;for s=1,P>0 and C-4 or C,4 do local F,G,H,Q=f(J,s,s+3)local R=F*0x1000000+G*0x10000+H*0x100+Q;local I=E[R]if not I then local l=r[F]*0x40000+r[G]*0x1000+r[H]*0x40+r[Q]I=e(k(l,16,8),k(l,8,8),k(l,0,8))E[R]=I end;A[B]=I;B=B+1 end;if P==1 then local F,G,H=f(J,C-3,C-1)local l=r[F]*0x40000+r[G]*0x1000+r[H]*0x40;A[B]=e(k(l,16,8),k(l,8,8))elseif P==2 then local F,G=f(J,C-3,C-2)local l=r[F]*0x40000+r[G]*0x1000;A[B]=e(k(l,16,8))end;return j(A)end;return a
end)()

libs.filesystem = (function()
    local a={}a.__index={}a.class=ffi.cast(ffi.typeof("void***"),memory_create_interface("filesystem_stdio.dll","VBaseFileSystem011"))a.v_table=a.class[0]a.full_class=ffi.cast("void***",memory_create_interface("filesystem_stdio.dll","VFileSystem017"))a.v_fltable=a.full_class[0]a.casts={read_file=ffi.cast("int (__thiscall*)(void*, void*, int, void*)",a.v_table[0]),write_file=ffi.cast("int (__thiscall*)(void*, void const*, int, void*)",a.v_table[1]),open_file=ffi.cast("void* (__thiscall*)(void*, const char*, const char*, const char*)",a.v_table[2]),close_file=ffi.cast("void (__thiscall*)(void*, void*)",a.v_table[3]),file_size=ffi.cast("unsigned int (__thiscall*)(void*, void*)",a.v_table[7]),file_exists=ffi.cast("bool (__thiscall*)(void*, const char*, const char*)",a.v_table[10]),delete_file=ffi.cast("void (__thiscall*)(void*, const char*, const char*)",a.v_fltable[20]),rename_file=ffi.cast("bool (__thiscall*)(void*, const char*, const char*, const char*)",a.v_fltable[21]),create_dir=ffi.cast("void (__thiscall*)(void*, const char*, const char*)",a.v_fltable[22]),is_dir=ffi.cast("bool (__thiscall*)(void*, const char*, const char*)",a.v_fltable[23])}local b=memory_create_interface("filesystem_stdio.dll","VFileSystem017")local c=ffi.cast(ffi.typeof("void***"),b)ffi.cdef([[ typedef void (__thiscall* AddSearchPath)(void*, const char*, const char*); typedef void (__thiscall* RemoveSearchPaths)(void*, const char*); typedef const char* (__thiscall* FindNext)(void*, int); typedef bool (__thiscall* FindIsDirectory)(void*, int); typedef void (__thiscall* FindClose)(void*, int); typedef const char* (__thiscall* FindFirstEx)(void*, const char*, const char*, int*); typedef long (__thiscall* GetFileTime)(void*, const char*, const char*); ]])local d=ffi.cast("AddSearchPath",c[0][11])local e=ffi.cast("RemoveSearchPaths",c[0][14])local f=ffi.cast("FindNext",c[0][33])local g=ffi.cast("FindIsDirectory",c[0][34])local h=ffi.cast("FindClose",c[0][35])local i=ffi.cast("FindFirstEx",c[0][36])a.modes={["r"]="r",["w"]="w",["a"]="a",["r+"]="r+",["w+"]="w+",["a+"]="a+",["rb"]="rb",["wb"]="wb",["ab"]="ab",["rb+"]="rb+",["wb+"]="wb+",["ab+"]="ab+"}a.open=function(j,k,l)if not a.modes[k]then error("File mode error!")end;local self=setmetatable({file=j,mode=k,path_id=l,handle=a.casts.open_file(a.class,j,k,l)},a)return self end;a.close=function(m)a.casts.close_file(a.class,m.handle)end;a.exists=function(j,l)return a.casts.file_exists(a.class,j,l)end;a.get_size=function(m)return a.casts.file_size(a.class,m.handle)end;a.write_binary=function(n,o)local m=a.open(n,"wb","MOD")a.casts.write_file(a.class,o,#o,m.handle)a.close(m)end;a.read_binary=function(n)local m=a.open(n,"rb","MOD")local p=a.get_size(m)local q=ffi.new("char[?]",p)a.casts.read_file(a.class,q,p,m.handle)a.close(m)return ffi.string(q,p)end;a.write=function(n,o)local m=a.open(n,"w","MOD")a.casts.write_file(a.class,o,#o,m.handle)a.close(m)end;a.append=function(n,o)local m=a.open(n,"a","MOD")a.casts.write_file(a.class,o,#o,m.handle)a.close(m)end;a.read=function(n)local m=a.open(n,"r","MOD")local p=a.get_size(m)local q=ffi.new("char[?]",p+1)a.casts.read_file(a.class,q,p,m.handle)a.close(m)return ffi.string(q)end;a.rename=function(r,s,l)return a.casts.rename_file(a.full_class,r,s,l)end;a.delete=function(j,l)a.casts.delete_file(a.full_class,j,l)end;a.create_directory=function(n,l)a.casts.create_dir(a.full_class,n,l)end;a.is_directory=function(n,l)return a.casts.is_dir(a.full_class,n,l)end;a.find_next=function(t)local j=a.casts.find_next(a.full_class,t)if j==0 then return nil end;return ffi.string(j)end;a.find_is_directory=function(t)return a.casts.find_is_dir(a.full_class,t)end;a.get_sec_files=function()local u=ffi.new("int[1]")e(c,"primordial")d(c,"././primordial/scripts","primordial")local v={}local j=i(c,"*","primordial",u)while j~=nil do local w=ffi.string(j)if g(c,u[0])==false and w:find("[.]lua")then table.insert(v,w)end;j=f(c,u[0])end;h(c,u[0])return v end;a.read_first_line=function(x)local y=x:match("^[^\r\n]+")return y end;a.get_files=function()local u=ffi.new("int[1]")e(c,"specter_configs")d(c,"./csgo/specter/","specter_configs")local v={}local j=i(c,"*","specter_configs",u)while j~=nil do local w=ffi.string(j)if g(c,u[0])==false and w:find("[.]cfg")then table.insert(v,w)end;j=f(c,u[0])end;h(c,u[0])return v end;return a
end)()

libs.eui = (function()
    local a={}a.__type={group=-1,button=0,keybind=1,text_input=2,text=3,separator=4,list=5,checkbox=6,color_picker=7,multi_selection=8,selection=9,slider=10}a.__spectersave=true;a.__data={}a.create=function(b,c)local d={group=b,column=c,id=a.__type.group}menu_set_group_column(b,c)a.__index=a;return setmetatable(d,a)end;function a:create_element(e,f,g)local h=nil;if e==a.__type.button then h=menu_add_button(self.group,f,g.fn)elseif e==a.__type.checkbox then h=menu_add_checkbox(self.group,f,g.default_value)elseif e==a.__type.color_picker then h=g.parent.ref:add_color_picker(f,g.default_value,g.alpha)elseif e==a.__type.keybind then h=g.parent.ref:add_keybind(f,g.default_value)elseif e==a.__type.list then h=menu_add_list(self.group,f,g.items,g.visible_count)elseif e==a.__type.multi_selection then h=menu_add_multi_selection(self.group,f,g.items,g.visible_count)elseif e==a.__type.selection then h=menu_add_selection(self.group,f,g.items,g.visible_count)elseif e==a.__type.slider then h=menu_add_slider(self.group,f,g.min,g.max,g.step,g.precision,g.suffix)elseif e==a.__type.text_input then h=menu_add_text_input(self.group,f)elseif e==a.__type.text then h=menu_add_text(self.group,f)elseif e==a.__type.separator then h=menu_add_separator(self.group)end;local d={name=f,id=e,ref=h,group=self.group,get=function(self,i)if self.id==a.__type.multi_selection then return self.ref:get(i)else return self.ref:get()end end}if not a.__data[self.group]then a.__data[self.group]={}end;a.__data[self.group][f]=d;if a.__spectersave then if not a[self.group]then a[self.group]={}end;a[self.group][f]=d;self[f]=d end;return setmetatable(d,a)end;function a:button(f,j)j=j or function()end;return self:create_element(a.__type.button,f,{fn=j})end;function a:checkbox(f,k)return self:create_element(a.__type.checkbox,f,{default_value=k})end;function a:color_picker(l,f,k,m)return self:create_element(a.__type.color_picker,f,{parent=l,default_value=k,alpha=m})end;function a:keybind(l,f,k)return self:create_element(a.__type.keybind,f,{parent=l,default_value=k})end;function a:list(f,n,o)return self:create_element(a.__type.list,f,{items=n,visible_count=o})end;function a:multi_selection(f,n,o)return self:create_element(a.__type.multi_selection,f,{items=n,visible_count=o})end;function a:selection(f,n,o)return self:create_element(a.__type.selection,f,{items=n,visible_count=o})end;function a:slider(f,p,q,r,s,t)return self:create_element(a.__type.slider,f,{min=p,max=q,step=r,precision=s,suffix=t})end;function a:text_input(f)return self:create_element(a.__type.text_input,f)end;function a:text(f,g)return self:create_element(a.__type.text,f,g)end;function a:separator()return self:create_element(a.__type.separator,"separator")end;a.export=function()local u={}for v,w in pairs(a.__data)do u[v]={}for x,y in pairs(w)do if not(y.id<a.__type.checkbox)then if y.id==a.__type.multi_selection then local z={}for A,B in pairs(y.ref:get_items())do table.insert(z,{B,y.ref:get(B)})end;table.insert(u[v],{y.name,z})elseif y.id==a.__type.color_picker then local C=y.ref:get()table.insert(u[v],{y.name,C.r,C.g,C.b,C.a})else table.insert(u[v],{y.name,y.ref:get()})end end end end;return libs.json.encode(u)end;a.import=function(d)local D=libs.json.parse(d)for v,w in pairs(D)do for x,y in pairs(w)do if not(a.__data[v]==nil or a.__data[v][y[1]]==nil)then if a.__data[v][y[1]].id==a.__type.multi_selection then for A,B in pairs(y[2])do a.__data[v][y[1]].ref:set(B[1],B[2])end elseif a.__data[v][y[1]].id==a.__type.color_picker then a.__data[v][y[1]].ref:set(color_t(y[2],y[3],y[4],y[5]))else a.__data[v][y[1]].ref:set(y[2])end end end end end;function a:depend(...)local E={...}local F=nil;for v,w in pairs(E)do local G=nil;if type(w[1])=="boolean"then G=w[1]else G=w[1].ref:get()==w[2]end;if F~=nil then F=F and G else F=G end end;if self.id==-1 then menu_set_group_visibility(self.group,F)else self.ref:set_visible(F)end end;return a
end)()

libs.httpcreator = (function()
    -- steam http. The passes run on real time: curtime starts again on every server, after a switch to a younger map no
    -- request was answered until it caught up. A finished request leaves the list before its callback and is not timed out
    -- in the same pass (its callback ran twice and the request after it was dropped)
    local a=ffi.cast("uint32_t**",ffi.cast("char**",ffi.cast("char*",memory_find_pattern("client.dll","B9 ? ? ? ? E8 ? ? ? ? 83 3D ? ? ? ? ? 0F 84"))+1)[0]+48)[0]or error("steam_http error")local b=ffi.cast("void***",a)or error("steam_http_ptr error")local c=b[0]or error("steam_http_ptr was null")local function d(e,f)return function(...)return e(f,...)end end;local g=d(ffi.cast(ffi.typeof("uint32_t(__thiscall*)(void*, uint32_t, const char*)"),c[0]),a)local h=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, uint64_t)"),c[5]),a)local i=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, uint32_t*)"),c[9]),a)local j=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, char*, uint32_t)"),c[10]),a)local k=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, uint32_t*)"),c[11]),a)local l=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, char*, uint32_t)"),c[12]),a)local m=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, const char*)"),c[3]),a)local n=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, const char*)"),c[4]),a)local o=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*)"),c[21]),a)local p=d(ffi.cast("bool(__thiscall*)(void*, uint32_t, const char*, const char*, uint32_t)",c[16]),a)local q=d(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t)"),c[14]),a)local r={}callbacks.add(e_callbacks.PAINT,function()for s,t in ipairs(r)do if global_vars_real_time()-t.ls>t.task_interval then t:_process_tasks()t.ls=global_vars_real_time()end end end)local u={}local v={__index=u}function u.new(w,x,y)return setmetatable({handle=w,url=x,callback=y,ticks=0},v)end;local z={}local A={__index=z}function z.new(B,C,D)return setmetatable({status=B,body=C,headers=D},A)end;function z:success()return self.status==200 end;local E={state={ok=200,no_response=204,timed_out=408,unknown=0}}local F={__index=E}function E.new(G)G=G or{}local t=setmetatable({requests={},task_interval=G.task_interval or 0.3,enable_debug=G.debug or false,timeout=G.timeout or 10,ls=global_vars_real_time()},F)table.insert(r,t)return t end;local H={["get"]=1,["head"]=2,["post"]=3,["put"]=4,["delete"]=5,["options"]=6,["patch"]=7}function E:request(I,J,K,L)if type(K)=="function"and L==nil then L=K;K={}end;K=K or{}local M=H[tostring(I):lower()]local N=g(M,J)local O="application/text"if type(K.headers)=="table"then for P,Q in pairs(K.headers)do P=tostring(P)Q=tostring(Q)if P:lower()=="content-type"then O=Q end;m(N,P,Q)end end;if type(K.body)=="string"then local R=K.body:len()p(N,O,ffi.cast("unsigned char*",K.body),R)end;if type(K.params)=="table"then for S,T in pairs(K.params)do n(N,S,T)end end;if type(K.user_agent_info)=="string"then o(N,K.user_agent_info)end;if not h(N,0)then return end;local U=u.new(N,J,L)self:_debug("[HTTP] New %s request to: %s",I:upper(),J)table.insert(self.requests,U)end;function E:get(J,L)local N=g(1,J)if not h(N,0)then return end;local U=u.new(N,J,L)self:_debug("[HTTP] New GET request to: %s",J)table.insert(self.requests,U)end;function E:post(J,V,L)local N=g(3,J)for S,T in pairs(V)do n(N,S,T)end;if not h(N,0)then return end;local U=u.new(N,J,L)self:_debug("[HTTP] New POST request to: %s",J)table.insert(self.requests,U)end;function E:download_image(J,W,L)local N=g(1,J)if not h(N,0)then return end;local function X(z)if z:success()then libs.filesystem.write_binary(W,z.body)if L then L(true,"Image downloaded successfully")end else if L then L(false,"Failed to download image")end end end;local U=u.new(N,J,X)table.insert(self.requests,U)end;function E:_process_tasks()for S,T in ipairs(self.requests)do local Y=ffi.new("uint32_t[1]")self:_debug("[HTTP] Processing request #%s",S)if k(T.handle,Y)then local Z=Y[0]if Z>0 then local _=ffi.new("char[?]",Z)if l(T.handle,_,Z)then self:_debug("[HTTP] Request #%s finished. Invoking callback.",S)table.remove(self.requests,S)T.done=true;T.callback(z.new(E.state.ok,ffi.string(_,Z),setmetatable({},{__index=function(a0,a1)return E._get_header(T,a1)end})))q(T.handle)end else table.remove(self.requests,S)T.done=true;T.callback(z.new(E.state.no_response,nil,{}))q(T.handle)end end;if not T.done then local a2=T.ticks+1;if a2>=self.timeout then table.remove(self.requests,S)T.done=true;T.callback(z.new(E.state.timed_out,nil,{}))q(T.handle)else T.ticks=a2 end end end end;function E:_debug(...)if self.enable_debug then client_log(string.format(...))end end;function E._get_header(U,a3)local Y=ffi.new("uint32_t[1]")if i(U.handle,a3,Y)then local Z=Y[0]local _=ffi.new("char[?]",Z)if j(U.handle,a3,_,Z)then return ffi.string(_,Z)end end;return nil end;function E._bind(a4,a5)return function(...)return a4[a5](a4,...)end end;return E
end)()

libs.panorama = (function()
    local a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,_,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,aa,ab,ac,ad,ae,af,ag,ah,ai,aj,ak,al,am,an,ao,ap,aq,ar;a={_VERSION=1.7}setmetatable(a,{__call=function(self)return self._VERSION end,__tostring=function(self)return self._VERSION end})b=require('ffi')do local as=b;c,d,e,f,g=as.cast,as.typeof,as.new,as.string,as.metatype end;h=function()return error('Unsupported provider')end;i=function()return error('Unsupported provider')end;j=function()return print('WARNING: Cleanup before shutdown disabled')end;local at;while true do if _G==nil then if quick_maths==nil then if info.fatality==nil then at='ev0lve'break end;at='fa7ality'break end;at='rifk7'break end;if MatSystem~=nil then at='spirthack'break end;if file~=nil then at='legendware'break end;if GameEventManager~=nil then at='memesense'break end;if penetration~=nil then at='pandora'break end;if math_utils~=nil then at='legion'break end;if plist~=nil then at='gamesense'break end;if network~=nil then at='neverlose'break end;if renderer~=nil and renderer.setup_texture~=nil then at='nixware'break end;at='primordial'break end;local au=at;if'ev0lve'==au then h=utils.find_pattern;i=utils.find_interface;j=function()end elseif'fa7ality'==au then h=utils.find_pattern;i=utils.find_interface;j=function()end elseif'primordial'==au then h=memory_find_pattern;i=memory_create_interface;j=function(av)return callbacks.add(e_callbacks.SHUTDOWN,av)end elseif'memesense'==au then h=Utils.PatternScan;i=Utils.CreateInterface;j=function(av)return Cheat.RegisterCallback('destroy',av)end elseif'legendware'==au then h=utils.find_signature;i=utils.create_interface;j=function(av)return client.add_callback('unload',av)end elseif'pandora'==au then h=client.find_sig;i=client.create_interface elseif'legion'==au then h=memory_find_pattern;i=memory_create_interface;j=function(av)return client.add_callback('on_unload',av)end elseif'gamesense'==au then h=function(aw,ax)local ay=''for az in ax:gmatch('%S+')do ay=ay..(az=='?'and'\xCC'or _G.string.char(tonumber(az,16)))end;return client.find_signature(aw,ay)end;i=client.create_interface;j=function(av)return client.set_event_callback('shutdown',av)end elseif'nixware'==au then h=client.find_pattern;i=se.create_interface;j=function(av)return client.register_callback("unload",av)end elseif'neverlose'==au then h=utils.opcode_scan;i=utils.create_interface;j=function()end elseif'rifk7'==au then h=function(aA,ax)local aB=c("uint32_t*",engine.signature(aA,ax))assert(tonumber(aB)~=0)return aB[0]end;i=function(aA,aC)aC=f.gsub(aC,"%d+","")return general.create_interface(aA,aC)end;print=function(aD)return general.log_to_console_colored("[lua] "..tostring(aD),255,141,161,255)end elseif'spirthack'==au then h=Utils.PatternScan;i=Utils.CreateInterface end;k=xpcall and pcall and true or false;l=b.C and at~='gamesense'm=function()for aE,aF in pairs(Z)do a3(aF):disposeGlobal()end end;n=error;if error then error=function(aG)m()return n(aG)end end;o=function(aG)return print('Caught lua exception in V8 HandleScope: ',tostring(aG))end;p=function(aG)return print('Caught lua exception in V8 Function Callback: ',tostring(aG))end;q=function(aH,aI)local aJ=getmetatable(aH)setmetatable(aH,nil)local aK=aH[aI]setmetatable(aH,aJ)return aK end;r=function(aH,aI,aL)local aJ=getmetatable(aH)setmetatable(aH,nil)aH[aI]=aL;return setmetatable(aH,aJ)end;if not rawget then rawget=q end;if not rawset then rawset=r end;s=function(aM,aN)return function(...)return aM(aN,...)end end;t=function(aO)local aP={}for aQ,aF in pairs(aO)do aP[aQ]=aF end;return aP end;u=function(aR,aS,aT,aU)local aV=c('void***',i(aR,aS))or error(aS..' is nil.')return s(c(aU,aV[0][aT]),aV)end;v=d('void***')w=function(aW,aX,aY)return c(aY,c(v,aW)[0][aX])end;x=function(aX,aY)local aO=d(aY)return function(aW,...)return w(aW,aX,aO)(aW,...)end end;y=(function()local aZ;aZ=function()return error('Failed to load GetProcAddress')end;local a_;a_=function()return error('Failed to load GetModuleHandleA')end;if l then b.cdef([[ uint32_t GetProcAddress(uint32_t, const char*); uint32_t GetModuleHandleA(const char*); ]])aZ=b.C.GetProcAddress;a_=b.C.GetModuleHandleA else aZ=c('uint32_t(__stdcall*)(uint32_t, const char*)',c('uint32_t**',c('uint32_t',h('engine.dll','FF 15 ? ? ? ? A3 ? ? ? ? EB 05'))+2)[0][0])a_=c('uint32_t(__stdcall*)(const char*)',c('uint32_t**',c('uint32_t',h('engine.dll','FF 15 ? ? ? ? 85 C0 74 0B'))+2)[0][0])end;if at=='gamesense'then local b0=h('engine.dll','51 C3')local b1=c('void*',aZ)aZ=function(b2,b3)local b4=c('uint32_t(__thiscall*)(void*, uint32_t, const char*)',b0)return b4(b1,b2,b3)end;local b5=c('void*',a_)a_=function(aw)local b6=c('uint32_t(__thiscall*)(void*, const char*)',b0)return b6(b5,aw)end end;return function(aA,b7,aU)return c(d(aU),aZ(a_(aA),b7))end end)()z=function(b8)local b9=c('uint8_t*',b8)local ba=b9[0]if(0xE8 or 0xE9)==ba then return c('uint32_t',b9+c('int32_t*',b9+1)[0]+5)elseif 0xFF==ba then if b9[1]==0x15 then return c('uint32_t**',c('const char*',b8)+2)[0][0]end else return b8 end end;A=function(...)local bb={...}local bc=#bb;local bd=e(('void*[%.f]'):format(bc))for aX=1,bc do bd[aX-1]=a4:fromLua(bb[aX]):getInternal()end;return bc,bd end;B=function(be)return function(bf)bf=aa(bf)local bb={}local bg=bf:length()if bg>0 then for aX=0,bg-1 do table.insert(bb,bf:get(aX))end end;local bh=nil;if k then local bi,bj=xpcall(function()return be(unpack(bb))end,p)if bi then bh=bj end else bh=be(unpack(bb))end;return bf:setReturnValue(a4:fromLua(bh):getInternal())end end;C=function(bh)local aX=1;for aE in pairs(bh)do if bh[aX]~=nil then aX=aX+1 else return false end end;return aX~=1 end;D=e('void*')E=e('int[1]')F={panelIDs={}}do local bk;local bl={get=function(self,aT,aO)return s(c(aO,self.this[0][aT]),self.this)end,getInstance=function(self)return self.this end}bl.__index=bl;bk=setmetatable({__init=function(self,b8)self.this=c('void***',b8)end,__base=bl,__name="vtable"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;G=bk end;do local bk;local bl={cache={},get=function(self,bo,aU)if not self.cache[bo]then self.cache[bo]=y(self.file,bo,aU)end;return self.cache[bo]end}bl.__index=bl;bk=setmetatable({__init=function(self,bp)self.file=bp end,__base=bl,__name="DllImport"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;H=bk end;I=G(u('panorama.dll','PanoramaUIEngine001',11,'void*(__thiscall*)(void*)')())J=I:get(36,'bool(__thiscall*)(void*,void const*)')K=I:get(56,'void*(__thiscall*)(void*)')L=I:get(113,'void****(__thiscall*)(void*,void*,char const*,char const*,int,int,bool)')M=s(c(d('void*(__thiscall*)(void*,void*,void*,void*,int,bool)'),z(h('panorama.dll','E8 ? ? ? ? 8B 4C 24 10 FF 15'))),I:getInstance())N=I:get(123,'void*(__thiscall*)(void*)')O=I:get(129,'void*(__thiscall*)(void*)')P=I:get(121,'void(__thiscall*)(void*, void*, void*)')Q=x(25,'void*(__thiscall*)(void*)')R=x(9,'const char*(__thiscall*)(void*)')S=x(40,'void*(__thiscall*)(void*,const char*)')T=x(218,'void*(__thiscall*)(void*)')U=s(c('void***(__thiscall*)(void*,void*)',z(h('panorama.dll','E8 ? ? ? ? 8B 00 85 C0 75 1B'))),I:getInstance())V={}W=function(bq)if V[bq]~=nil then return V[bq]end;V[bq]=T(bq)return V[bq]end;X=H('v8.dll')Y=O()Z={}do local bk;local bl={}bl.__index=bl;bk=setmetatable({__init=function(self,bh)self.this=c('void*',bh)end,__base=bl,__name="Message"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;_=bk end;do local bk;local bl={getInternal=function(self)return self.this end,isValid=function(self)return self.this[0]~=D end,getMessage=function(self)return _(self.this[0])end,globalize=function(self)local br=X:get('?GlobalizeReference@V8@v8@@CAPAPAVObject@internal@2@PAVIsolate@42@PAPAV342@@Z','void*(__cdecl*)(void*,void*)')(Y,self.this[0])local bs=a3(br)Z[bs:getIdentityHash()]=br;return bs end,__call=function(self)return a4(self.this[0])end}bl.__index=bl;bk=setmetatable({__init=function(self,bh)self.this=c('void**',bh)end,__base=bl,__name="Local"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;a0=bk end;do local bk;local bl={getInternal=function(self)return self.this end,toLocalChecked=function(self)if not(self.this[0]==D)then return a0(self.this)end end,toValueChecked=function(self)if not(self.this[0]==D)then return a4(self.this[0])end end}bl.__index=bl;bk=setmetatable({__init=function(self,bh)self.this=c('void**',bh)end,__base=bl,__name="MaybeLocal"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;a1=bk end;a2={__index=function(self,aI)local aN=rawget(self,'this')local bj=ak()(function()return aN:getAsValue():toObject():get(a4:fromLua(aI):getInternal()):toValueChecked():toLua()end)if type(bj)=='table'then rawset(bj,'parent',aN)end;return bj end,__newindex=function(self,aI,aL)local aN=rawget(self,'this')return ak()(function()return aN:getAsValue():toObject():set(a4:fromLua(aI):getInternal(),a4:fromLua(aL):getInternal()):toValueChecked():toLua()end)end,__len=function(self)local aN=rawget(self,'this')local bj=0;if aN.baseType=='Array'then bj=ak()(function()return aN:getAsValue():toArray():length()end)elseif aN.baseType=='Object'then bj=ak()(function()return aN:getAsValue():toObject():getPropertyNames():toValueChecked():toArray():length()end)end;return bj end,__pairs=function(self)local aN=rawget(self,'this')local bj;bj=function()return nil end;if aN.baseType=='Object'then ak()(function()local bt=a6(aN:getAsValue():toObject():getPropertyNames():toValueChecked())local bu,bv=0,bt:length()bj=function()bu=bu+1;local aI=bt[bu-1]if bu<=bv then return aI,self[aI]end end end)end;return bj end,__ipairs=function(self)local aN=rawget(self,'this')local bj;bj=function()return nil end;if aN.baseType=='Array'then ak()(function()local bu,bv=0,aN:getAsValue():toArray():length()bj=function()bu=bu+1;if bu<=bv then return bu,self[bu-1]end end end)end;return bj end,__call=function(self,...)local aN=rawget(self,'this')local bw={...}if aN.baseType~='Function'then error('Attempted to call a non-function value: '..aN.baseType)end;local bx=false;local bj=ak()(function()local by=al()by:enter()local bz=aN:getAsValue():toFunction():setParent(rawget(self,'parent'))(unpack(bw)):toLocalChecked()if by:hasCaught()then P(by:getInternal(),F.getPanel("CSGOJsRegistration"))if k then bx=true end end;by:exit()if bz==nil then return nil else return bz():toLua()end end)if bx then error("\n\nFailed to call the given javascript function, please check the error message above ^ \n\n(definitely not because I was too lazy to implement my own exception handler)\n")end;return bj end,__tostring=function(self)local aN=rawget(self,'this')return ak()(function()return aN:getAsValue():stringValue()end)end,__gc=function(self)local aN=rawget(self,'this')return aN:disposeGlobal()end}do local bk;local bl={setType=function(self,bh)self.baseType=bh;return self end,getInternal=function(self)return self.this end,disposeGlobal=function(self)return X:get('?DisposeGlobal@V8@v8@@CAXPAPAVObject@internal@2@@Z','void(__cdecl*)(void*)')(self.this)end,get=function(self)return a1(ak:createHandle(self.this))end,getAsValue=function(self)return a4(ak:createHandle(self.this)[0])end,toLua=function(self)return self:get():toValueChecked():toLua()end,getIdentityHash=function(self)return X:get('?GetIdentityHash@Object@v8@@QAEHXZ','int(__thiscall*)(void*)')(self.this)end,__call=function(self)return setmetatable({this=self,parent=nil},a2)end}bl.__index=bl;bk=setmetatable({__init=function(self,bh,bA)if bA==nil then bA='Value'end;self.this=bh;self.baseType=bA end,__base=bl,__name="Persistent"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;a3=bk end;do local bk;local bl={fromLua=function(self,bh)if bh==nil then return ac(Y):getValue()end;local bB=type(bh)local ba=bB;if'boolean'==ba then return ae(Y,bh):getValue()elseif'number'==ba then return af(Y,bh):getInstance()elseif'string'==ba then return ah(Y,bh):getInstance()elseif'table'==ba then if C(bh)then return a6:fromLua(Y,bh)else return a5:fromLua(Y,bh)end elseif'function'==ba then return a9(B(bh)):getFunction()()else return error('Failed to convert from lua to v8js: Unknown type')end end,isUndefined=function(self)return X:get('?IsUndefined@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isNull=function(self)return X:get('?IsNull@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isBoolean=function(self)return X:get('?IsBoolean@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isBooleanObject=function(self)return X:get('?IsBooleanObject@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isNumber=function(self)return X:get('?IsNumber@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isNumberObject=function(self)return X:get('?IsNumberObject@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isString=function(self)return X:get('?IsString@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isStringObject=function(self)return X:get('?IsStringObject@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isObject=function(self)return X:get('?IsObject@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isArray=function(self)return X:get('?IsArray@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,isFunction=function(self)return X:get('?IsFunction@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,booleanValue=function(self)return X:get('?BooleanValue@Value@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,numberValue=function(self)return X:get('?NumberValue@Value@v8@@QBENXZ','double(__thiscall*)(void*)')(self.this)end,stringValue=function(self)local bC=e('char*[2]')local bh=X:get('??0Utf8Value@String@v8@@QAE@V?$Local@VValue@v8@@@2@@Z','struct{char* str; int length;}*(__thiscall*)(void*,void*)')(bC,self.this)local bD=f(bh.str,bh.length)X:get('??1Utf8Value@String@v8@@QAE@XZ','void(__thiscall*)(void*)')(bC)return bD end,toObject=function(self)return a5(a1(X:get('?ToObject@Value@v8@@QBE?AV?$Local@VObject@v8@@@2@XZ','void*(__thiscall*)(void*,void*)')(self.this,E)):toValueChecked():getInternal())end,toArray=function(self)return a6(a1(X:get('?ToObject@Value@v8@@QBE?AV?$Local@VObject@v8@@@2@XZ','void*(__thiscall*)(void*,void*)')(self.this,E)):toValueChecked():getInternal())end,toFunction=function(self)return a7(a1(X:get('?ToObject@Value@v8@@QBE?AV?$Local@VObject@v8@@@2@XZ','void*(__thiscall*)(void*,void*)')(self.this,E)):toValueChecked():getInternal())end,toLocal=function(self)return a0(e('void*[1]',self.this))end,toLua=function(self)if self:isUndefined()or self:isNull()then return nil end;if self:isBoolean()or self:isBooleanObject()then return self:booleanValue()end;if self:isNumber()or self:isNumberObject()then return self:numberValue()end;if self:isString()or self:isStringObject()then return self:stringValue()end;if self:isObject()then if self:isArray()then return self:toArray():toLocal():globalize():setType('Array')()end;if self:isFunction()then return self:toFunction():toLocal():globalize():setType('Function')()end;return self:toObject():toLocal():globalize():setType('Object')()end;return error('Failed to convert from v8js to lua: Unknown type')end,getInternal=function(self)return self.this end}bl.__index=bl;bk=setmetatable({__init=function(self,bh)self.this=c('void*',bh)end,__base=bl,__name="Value"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;a4=bk end;do local bk;local bE=a4;local bl={fromLua=function(self,bF,bh)local bG=a5(a1(X:get('?New@Object@v8@@SA?AV?$Local@VObject@v8@@@2@PAVIsolate@2@@Z','void*(__cdecl*)(void*,void*)')(E,bF)):toValueChecked():getInternal())for aX,aF in pairs(bh)do bG:set(a4:fromLua(aX):getInternal(),a4:fromLua(aF):getInternal())end;return bG end,get=function(self,aI)return a1(X:get('?Get@Object@v8@@QAE?AV?$Local@VValue@v8@@@2@V32@@Z','void*(__thiscall*)(void*,void*,void*)')(self.this,E,aI))end,set=function(self,aI,aL)return X:get('?Set@Object@v8@@QAE_NV?$Local@VValue@v8@@@2@0@Z','bool(__thiscall*)(void*,void*,void*)')(self.this,aI,aL)end,getPropertyNames=function(self)return a1(X:get('?GetPropertyNames@Object@v8@@QAE?AV?$Local@VArray@v8@@@2@XZ','void*(__thiscall*)(void*,void*)')(self.this,E))end,callAsFunction=function(self,bH,bI,bJ)return a1(X:get('?CallAsFunction@Object@v8@@QAE?AV?$Local@VValue@v8@@@2@V32@HQAV32@@Z','void*(__thiscall*)(void*,void*,void*,int,void*)')(self.this,E,bH,bI,bJ))end,getIdentityHash=function(self)return X:get('?GetIdentityHash@Object@v8@@QAEHXZ','int(__thiscall*)(void*)')(self.this)end}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bh)self.this=bh end,__base=bl,__name="Object",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;a5=bk end;do local bk;local bE=a5;local bl={fromLua=function(self,bF,bh)local bM=a6(a1(X:get('?New@Array@v8@@SA?AV?$Local@VArray@v8@@@2@PAVIsolate@2@H@Z','void*(__cdecl*)(void*,void*,int)')(E,bF,#bh)):toValueChecked():getInternal())for aX=1,#bh do bM:set(aX-1,a4:fromLua(bh[aX]):getInternal())end;return bM end,get=function(self,aI)return a1(X:get('?Get@Object@v8@@QAE?AV?$Local@VValue@v8@@@2@I@Z','void*(__thiscall*)(void*,void*,unsigned int)')(self.this,E,aI))end,set=function(self,aI,aL)return X:get('?Set@Object@v8@@QAE_NIV?$Local@VValue@v8@@@2@@Z','bool(__thiscall*)(void*,unsigned int,void*)')(self.this,aI,aL)end,length=function(self)return X:get('?Length@Array@v8@@QBEIXZ','uint32_t(__thiscall*)(void*)')(self.this)end}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bh)self.this=bh end,__base=bl,__name="Array",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;a6=bk end;do local bk;local bE=a5;local bl={setParent=function(self,bh)self.parent=bh;return self end,__call=function(self,...)if self.parent==nil then return self:callAsFunction(aj(ai():getCurrentContext()):global():toValueChecked():getInternal(),A(...))else return self:callAsFunction(self.parent:getAsValue():getInternal(),A(...))end end}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bh,bL)self.this=bh;self.parent=bL end,__base=bl,__name="Function",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;a7=bk end;do local bk;local bl={}bl.__index=bl;bk=setmetatable({__init=function(self)self.this=a1(X:get('?New@ObjectTemplate@v8@@SA?AV?$Local@VObjectTemplate@v8@@@2@XZ','void*(__cdecl*)(void*)')(E)):toLocalChecked()end,__base=bl,__name="ObjectTemplate"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;a8=bk end;do local bk;local bl={getFunction=function(self)return a1(X:get('?GetFunction@FunctionTemplate@v8@@QAE?AV?$Local@VFunction@v8@@@2@XZ','void*(__thiscall*)(void*, void*)')(self:this():getInternal(),E)):toLocalChecked()end,getInstance=function(self)return self:this()end}bl.__index=bl;bk=setmetatable({__init=function(self,bN)self.this=a1(X:get('?New@FunctionTemplate@v8@@SA?AV?$Local@VFunctionTemplate@v8@@@2@PAVIsolate@2@P6AXABV?$FunctionCallbackInfo@VValue@v8@@@2@@ZV?$Local@VValue@v8@@@2@V?$Local@VSignature@v8@@@2@HW4ConstructorBehavior@2@@Z','void*(__cdecl*)(void*,void*,void*,void*,void*,int,int)')(E,Y,c('void(__cdecl*)(void******)',bN),e('int[1]'),e('int[1]'),0,0)):toLocalChecked()end,__base=bl,__name="FunctionTemplate"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;a9=bk end;do local bk;local bl={kHolderIndex=0,kIsolateIndex=1,kReturnValueDefaultValueIndex=2,kReturnValueIndex=3,kDataIndex=4,kCalleeIndex=5,kContextSaveIndex=6,kNewTargetIndex=7,getHolder=function(self)return a1(self:getImplicitArgs_()[self.kHolderIndex]):toLocalChecked()end,getIsolate=function(self)return ai(self:getImplicitArgs_()[self.kIsolateIndex][0])end,getReturnValueDefaultValue=function(self)return a4(e('void*[1]',self:getImplicitArgs_()[self.kReturnValueDefaultValueIndex]))end,getReturnValue=function(self)return a4(e('void*[1]',self:getImplicitArgs_()[self.kReturnValueIndex]))end,setReturnValue=function(self,aL)self:getImplicitArgs_()[self.kReturnValueIndex]=c('void**',aL)[0]end,getData=function(self)return a1(self:getImplicitArgs_()[self.kDataIndex]):toLocalChecked()end,getCallee=function(self)return a1(self:getImplicitArgs_()[self.kCalleeIndex]):toLocalChecked()end,getContextSave=function(self)return a1(self:getImplicitArgs_()[self.kContextSaveIndex]):toLocalChecked()end,getNewTarget=function(self)return a1(self:getImplicitArgs_()[self.kNewTargetIndex]):toLocalChecked()end,getImplicitArgs_=function(self)return self.this[0]end,getValues_=function(self)return self.this[1]end,getLength_=function(self)return self.this[2]end,length=function(self)return tonumber(c('int',self:getLength_()))end,get=function(self,aX)if self:length()>aX then return a4(self:getValues_()-aX):toLua()else return end end}bl.__index=bl;bk=setmetatable({__init=function(self,bh)self.this=c('void****',bh)end,__base=bl,__name="FunctionCallbackInfo"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;aa=bk end;do local bk;local bE=a4;local bl={getValue=function(self)return self.this end,toString=function(self)return self.this:getValue():stringValue()end}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bh)self.this=bh end,__base=bl,__name="Primitive",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;ab=bk end;do local bk;local bE=ab;local bl={}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bF)self.this=a4(c('uintptr_t',bF)+0x48)end,__base=bl,__name="Null",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;ac=bk end;do local bk;local bE=ab;local bl={}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bF)self.this=a4(c('uintptr_t',bF)+0x56)end,__base=bl,__name="Undefined",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;ad=bk end;do local bk;local bE=ab;local bl={}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bF,bO)self.this=a4(c('uintptr_t',bF)+(function()if bO then return 0x4C else return 0x50 end end)())end,__base=bl,__name="Boolean",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;ae=bk end;do local bk;local bE=a4;local bl={getLocal=function(self)return self.this end,getValue=function(self)return self:getInstance():numberValue()end,getInstance=function(self)return self:this()end}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bF,bh)self.this=a1(X:get('?New@Number@v8@@SA?AV?$Local@VNumber@v8@@@2@PAVIsolate@2@N@Z','void*(__cdecl*)(void*,void*,double)')(E,bF,tonumber(bh))):toLocalChecked()end,__base=bl,__name="Number",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;af=bk end;do local bk;local bE=af;local bl={}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bF,bh)self.this=a1(X:get('?NewFromUnsigned@Integer@v8@@SA?AV?$Local@VInteger@v8@@@2@PAVIsolate@2@I@Z','void*(__cdecl*)(void*,void*,uint32_t)')(E,bF,tonumber(bh))):toLocalChecked()end,__base=bl,__name="Integer",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;ag=bk end;do local bk;local bE=a4;local bl={getLocal=function(self)return self.this end,getValue=function(self)return self:getInstance():stringValue()end,getInstance=function(self)return self:this()end}bl.__index=bl;setmetatable(bl,bE.__base)bk=setmetatable({__init=function(self,bF,bh)self.this=a1(X:get('?NewFromUtf8@String@v8@@SA?AV?$MaybeLocal@VString@v8@@@2@PAVIsolate@2@PBDW4NewStringType@2@H@Z','void*(__cdecl*)(void*,void*,const char*,int,int)')(E,bF,bh,0,#bh)):toLocalChecked()end,__base=bl,__name="String",__parent=bE},{__index=function(bm,bK)local bh=rawget(bl,bK)if bh==nil then local bL=rawget(bm,"__parent")if bL then return bL[bK]end else return bh end end,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;if bE.__inherited then bE.__inherited(bE,bk)end;ah=bk end;do local bk;local bl={enter=function(self)return X:get('?Enter@Isolate@v8@@QAEXXZ','void(__thiscall*)(void*)')(self.this)end,exit=function(self)return X:get('?Exit@Isolate@v8@@QAEXXZ','void(__thiscall*)(void*)')(self.this)end,getCurrentContext=function(self)return a1(X:get('?GetCurrentContext@Isolate@v8@@QAE?AV?$Local@VContext@v8@@@2@XZ','void**(__thiscall*)(void*,void*)')(self.this,E)):toValueChecked():getInternal()end,getInternal=function(self)return self.this end}bl.__index=bl;bk=setmetatable({__init=function(self,bh)if bh==nil then bh=Y end;self.this=bh end,__base=bl,__name="Isolate"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;ai=bk end;do local bk;local bl={enter=function(self)return X:get('?Enter@Context@v8@@QAEXXZ','void(__thiscall*)(void*)')(self.this)end,exit=function(self)return X:get('?Exit@Context@v8@@QAEXXZ','void(__thiscall*)(void*)')(self.this)end,global=function(self)return a1(X:get('?Global@Context@v8@@QAE?AV?$Local@VObject@v8@@@2@XZ','void*(__thiscall*)(void*,void*)')(self.this,E))end}bl.__index=bl;bk=setmetatable({__init=function(self,bh)self.this=bh end,__base=bl,__name="Context"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;aj=bk end;do local bk;local bl={enter=function(self)return X:get('??0HandleScope@v8@@QAE@PAVIsolate@1@@Z','void(__thiscall*)(void*,void*)')(self.this,Y)end,exit=function(self)return X:get('??1HandleScope@v8@@QAE@XZ','void(__thiscall*)(void*)')(self.this)end,createHandle=function(self,bh)return X:get('?CreateHandle@HandleScope@v8@@KAPAPAVObject@internal@2@PAVIsolate@42@PAV342@@Z','void**(__cdecl*)(void*,void*)')(Y,bh)end,__call=function(self,aM,bq)if bq==nil then bq=F.GetPanel('CSGOJsRegistration')end;local bF=ai()bF:enter()self:enter()local bP;if bq then bP=U(W(bq))[0]else bP=aj(bF:getCurrentContext()):global():getInternal()end;bP=aj((function()if bP~=D then return self:createHandle(bP[0])else return 0 end end)())bP:enter()local bh=nil;if k then local bi,bj=xpcall(aM,o)if bi then bh=bj end else bh=aM()end;bP:exit()self:exit()bF:exit()return bh end}bl.__index=bl;bk=setmetatable({__init=function(self)self.this=e('char[0xC]')end,__base=bl,__name="HandleScope"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;ak=bk end;do local bk;local bl={enter=function(self)return X:get('??0TryCatch@v8@@QAE@PAVIsolate@1@@Z','void(__thiscall*)(void*, void*)')(self.this,Y)end,exit=function(self)return X:get('??1TryCatch@v8@@QAE@XZ','void(__thiscall*)(void*)')(self.this)end,canContinue=function(self)return X:get('?CanContinue@TryCatch@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,hasTerminated=function(self)return X:get('?HasTerminated@TryCatch@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,hasCaught=function(self)return X:get('?HasCaught@TryCatch@v8@@QBE_NXZ','bool(__thiscall*)(void*)')(self.this)end,message=function(self)return a0(X:get('?Message@TryCatch@v8@@QBE?AV?$Local@VMessage@v8@@@2@XZ','void*(__thiscall*)(void*, void*)')(self.this,E))end,getInternal=function(self)return self.this end}bl.__index=bl;bk=setmetatable({__init=function(self)self.this=e('char[0x19]')end,__base=bl,__name="TryCatch"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;al=bk end;do local bk;local bl={compile=function(self,bq,bQ,bR)if bR==nil then bR=''end;return s(c('void**(__thiscall*)(void*,void*,const char*,const char*)',at=='memesense'and h('panorama.dll','E8 ? ? ? ? 8B 4C 24 10 FF 15')-2816 or h('panorama.dll','55 8B EC 83 E4 F8 83 EC 64 53 8B D9')),I:getInstance())(bq,bQ,bR)end,loadstring=function(self,bS,bq)local bT=a1(self:compile(bq,bS)):toLocalChecked()if bT==D then if k then error("\nFailed to compile the given javascript string, please check the error message above ^\n")else print("\nFailed to compile the given javascript string, please check the error message above ^\n")return function()return print('WARNING: Attempted to call nullptr (script compilation failed)')end end end;local bF=ai()local bU=ak()bF:enter()bU:enter()local bP;if bq then bP=U(W(bq))[0]else bP=aj(bF:getCurrentContext()):global():getInternal()end;bP=aj((function()if bP~=D then return bU:createHandle(bP[0])else return 0 end end)())bP:enter()local bj=a1(M(E,bq,bT():getInternal(),0,false)):toValueChecked()if bj==D then if k then error("\nFailed to evaluate the given javascript string, please check the error message above ^\n")else print("\nFailed to evaluate the given javascript string, please check the error message above ^\n")bj=function()return print('WARNING: Attempted to call nullptr (script execution failed)')end end else bj=bj:toLua()end;bP:exit()bU:exit()bF:exit()return bj end}bl.__index=bl;bk=setmetatable({__init=function()end,__base=bl,__name="Script"},{__index=bl,__call=function(bm,...)local bn=setmetatable({},bl)bm.__init(bn,...)return bn end})bl.__class=bk;am=bk end;an=d([[ struct { char* pad1[0x4]; void* m_pPanel; void* unk1; } ]])ao=d([[ struct { struct { $ *m_pMemory; int m_nAllocationCount; int m_nGrowSize; } m_Memory; int m_Size; $ *m_pElements; } ]],an,an)g(ao,{__index={Count=function(self)return self.m_Memory.m_nAllocationCount end,Element=function(self,aX)return c(d('$&',an),self.m_Memory.m_pMemory[aX])end,RemoveAll=function(self)self=nil;self=d('$[?]',ao)(1)[0]self.m_Size=0 end},__ipairs=function(self)local bu,bv=0,self:Count()return function()bu=bu+1;local bV=self:Element(bu-1).m_pPanel;if bu<=bv and J(bV)then return bu,bV end end end})ap=d('$[?]',ao)(1)[0]aq=c('unsigned int*',c('uintptr_t**',I:getInstance())[0][36]+21)[0]ar=c(ap,c('uintptr_t',I:getInstance())+aq)F.hasPanel=function(bW)for aX,aF in ipairs(ar)do local bX=f(R(aF))if bX==bW then return true end end;return false end;F.getPanel=function(bW,bY)local bZ=F.panelIDs[bW]if bZ~=nil and J(bZ)and f(R(bZ))==bW then return bZ end;F.panelIDs={}local bV=D;for aX,aF in ipairs(ar)do local bX=f(R(aF))if bX~=''then F.panelIDs[bX]=aF;if bX==bW then bV=aF;break end end end;if bV==D then if bY~=nil then bV=F.getPanel(bY)else error(('Failed to get target panel %s (EAX == 0)'):format(tostring(bW)))end end;return bV end;F.getIsolate=function()return ai(O())end;F.runScript=function(b_,bq,c0)if bq==nil then bq=F.getPanel('CSGOJsRegistration')end;if c0==nil then c0='panorama/layout/base.xml'end;if not J(bq)then error('Invalid panel pointer (EAX == 0)')end;return L(bq,b_,c0,8,10,false)end;F.loadstring=function(b_,bq)if bq==nil then bq='CSGOJsRegistration'end;local bY='CSGOJsRegistration'if bq=='CSGOMainMenu'then bY='CSGOHud'end;if bq=='CSGOHud'then bY='CSGOMainMenu'end;return am:loadstring(('(()=>{%s})'):format(b_),F.getPanel(bq,bY))end;F.open=function(bq)if bq==nil then bq='CSGOJsRegistration'end;local bY='CSGOJsRegistration'if bq=='CSGOMainMenu'then bY='CSGOHud'end;if bq=='CSGOHud'then bY='CSGOMainMenu'end;return ak()(function()return aj(ai():getCurrentContext()):global():toValueChecked():toLua()end,F.GetPanel(bq,bY))end;F.GetPanel=F.getPanel;F.GetIsolate=F.getIsolate;F.RunScript=F.runScript;F.panelArray=ar;F.info=a;F.flush=m;setmetatable(F,{__tostring=function(self)return('luv8 panorama library v%.1f'):format(a._VERSION)end,__index=function(self,aI)if F.hasPanel(aI)then return F.open(aI)end;return F.open()[aI]end})return F
end)()

libs.tools.http = libs.httpcreator.new(
    {
        task_interval = 2.0,
        enable_debug = false,
        timeout = 10
    }
)

libs.tools.js2 = libs.panorama.open()
libs.tools.js = libs.panorama.loadstring([[
let entity_panels = {};
let entity_data = {};
let event_callbacks = {};
const valid = function(panel) {
    return panel != null && typeof panel.IsValid === "function" && panel.IsValid();
};
const destroy_panel = function(xuid) {
    const panel = entity_panels[xuid];
    if (valid(panel)) {
        // the country flag we covered comes back
        if (valid(panel.specter_flag)) {
            panel.specter_flag.visible = true;
            try { panel.specter_flag.style.width = null; panel.specter_flag.style.opacity = null; } catch (_) {}
        }
        panel.DeleteAsync(0);
    }
    delete entity_panels[xuid];
};
const destroy_panels = function() {
    Object.keys(entity_panels).forEach(destroy_panel);
};
const scoreboard = function() {
    const context = $.GetContextPanel();
    if (!valid(context)) return null;
    const ids = ["ScoreboardContainer", "id-eom-scoreboard-container"];
    for (let i = 0; i < ids.length; i++) {
        const container = context.FindChildTraverse(ids[i]);
        const board = valid(container) && container.FindChildTraverse("Scoreboard");
        if (valid(board)) return board;
    }
    const board = context.FindChildTraverse("Scoreboard");
    return valid(board) ? board : null;
};
// the country flag of a row (owners, Oct 2026: on some servers the flag is all a row has and our icon beside it looked bad: the
// icon takes the flag's place). The ids / classes are the ones of the CS:GO scoreboard; none found = the icon stays beside the rank
const find_flag = function(row) {
    const ids = ["FlagImg", "Flag", "CountryFlag"];
    for (let i = 0; i < ids.length; i++) {
        const found = row.FindChildTraverse(ids[i]);
        if (valid(found)) return found;
    }
    const classes = ["sb-row__cell__flag", "sb-row__flag", "sb-flag"];
    for (let i = 0; i < classes.length; i++) {
        const list = row.FindChildrenWithClassTraverse(classes[i]) || [];
        if (list.length > 0 && valid(list[0])) return list[0];
    }
    // the ids of the CS:GO scoreboard rows are "id-sb-name__*", "id-sb-skillgroup-image" ...: the flag is the panel whose id says flag / country
    // (owners, Oct 2026: the flags stayed, the guesses above found nothing)
    let found = null;
    walk(row, 0, function(panel) {
        if (found != null) return;
        const id = String(panel.id || "").toLowerCase();
        if (id.indexOf("specter") === 0) return;
        if (id.indexOf("flag") >= 0 || id.indexOf("country") >= 0) found = panel;
    });
    if (found != null) return found;
    // the flag is an image whose file lives in a flags folder, whatever its panel is called
    walk(row, 0, function(panel) {
        if (found != null) return;
        const id = String(panel.id || "");
        if (id.indexOf("specter") === 0) return;
        let src = "";
        try { src = String(panel.GetImageSrc ? panel.GetImageSrc() : (panel.src || "")).toLowerCase(); } catch (_) {}
        if (src.indexOf("flag") >= 0 || src.indexOf("countr") >= 0) found = panel;
    });
    return found;
};
// every panel under `panel` (depth 7 at most), parents first
const walk = function(panel, depth, visit) {
    if (!valid(panel) || depth > 7) return;
    visit(panel);
    const kids = typeof panel.Children === "function" ? (panel.Children() || []) : [];
    for (let i = 0; i < kids.length; i++) walk(kids[i], depth + 1, visit);
};
// the first row of the scoreboard as text (id, type, classes of every panel): what the "Dump scoreboard row" button prints
const dump = function() {
    const board = scoreboard();
    if (!valid(board)) return "no scoreboard (open it first)";
    const rows = board.FindChildrenWithClassTraverse("sb-row") || [];
    if (rows.length === 0) return "no rows";
    const lines = [];
    walk(rows[0], 0, function(panel) {
        let depth = 0;
        for (let p = panel; valid(p) && p !== rows[0] && depth < 12; p = p.GetParent()) depth++;
        let stat = "";
        try { stat = String(panel.GetAttributeString("data-stat", "")); } catch (_) {}
        lines.push("  ".repeat(depth) + String(panel.id || "-") + " <" + String(panel.paneltype || "?") + ">" + (stat ? " data-stat=" + stat : ""));
    });
    return lines.join("\n");
};
const player_xuid = function(index) {
    try {
        const value = String(GameStateAPI.GetPlayerXuidStringFromEntIndex(index) || "");
        return /^\d{17}$/.test(value) ? value : null;
    } catch (_) { return null; }
};
const get_panel = function(xuid) {
    const board = scoreboard();
    if (!valid(board)) return null;
    const rows = board.FindChildrenWithClassTraverse("sb-row") || [];
    let row = null;
    for (let i = 0; i < rows.length; i++) {
        if (valid(rows[i]) && String(rows[i].GetAttributeString("xuid", "") || rows[i].m_xuid || "") === xuid) {
            row = rows[i];
            break;
        }
    }
    if (!valid(row)) return null;
    const current = entity_panels[xuid];
    if (valid(current) && current.specter_row === row) return current;
    destroy_panel(xuid);
    const cells = row.Children() || [];
    let parent = row;
    for (let i = 0; i < cells.length; i++) {
        if (valid(cells[i]) && cells[i].GetAttributeString("data-stat", "") === "rank") {
            parent = cells[i];
            break;
        }
    }
    const flag = find_flag(row);
    if (flag != null && typeof flag.GetParent === "function" && valid(flag.GetParent())) parent = flag.GetParent();
    const panel = $.CreatePanel("Panel", parent, "specter-presence-" + xuid);
    panel.specter_row = row;
    if (flag != null) {
        flag.visible = false;
        try { flag.style.width = "0px"; flag.style.opacity = "0"; } catch (_) {}
        panel.specter_flag = flag;
        try { if (typeof parent.MoveChildBefore === "function") parent.MoveChildBefore(panel, flag); } catch (_) {}
    }
    panel.style.flowChildren = "right";
    panel.style.marginLeft = "4px";
    panel.style.verticalAlign = "center";
    const image = $.CreatePanel("Image", panel, "specter-image");
    image.style.width = "18px";
    image.style.height = "18px";
    const fallback = $.CreatePanel("Label", panel, "specter-fallback");
    fallback.text = "S";
    fallback.style.color = "#b4a0ff";
    fallback.style.fontSize = "16px";
    entity_panels[xuid] = panel;
    return panel;
};
const apply_data = function() {
    Object.keys(entity_data).forEach(function(key) {
        const data = entity_data[key];
        const xuid = player_xuid(parseInt(key, 10));
        if (xuid == null) {
            if (data.xuid) destroy_panel(data.xuid);
            return;
        }
        if (data.xuid && data.xuid !== xuid) {
            destroy_panel(data.xuid);
            delete entity_data[key];
            return;
        }
        const panel = get_panel(xuid);
        if (!valid(panel)) return;
        const image = panel.FindChild("specter-image");
        const fallback = panel.FindChild("specter-fallback");
        if (!valid(image) || !valid(fallback)) return;
        image.visible = data.ready;
        fallback.visible = !data.ready;
        if (data.ready && image.specter_path !== data.path) {
            image.SetImage(data.path);
            image.specter_path = data.path;
        }
    });
};
const update = function(index, path, ready, expected_xuid) {
    if (!index || index < 1 || index > 64) return false;
    entity_data[index] = { path: path, ready: ready === true, xuid: expected_xuid || player_xuid(index) };
    apply_data();
    return true;
};
const clear = function() { entity_data = {}; destroy_panels(); };
const destroy = function() {
    clear();
    Object.keys(event_callbacks).forEach(function(event) {
        $.UnregisterForUnhandledEvent(event, event_callbacks[event]);
        delete event_callbacks[event];
    });
};
const create = function() {
    Object.keys(event_callbacks).forEach(function(event) {
        $.UnregisterForUnhandledEvent(event, event_callbacks[event]);
    });
    event_callbacks = {};
    ["OnOpenScoreboard", "Scoreboard_UpdateEverything", "Scoreboard_UpdateJob"].forEach(function(event) {
        event_callbacks[event] = $.RegisterForUnhandledEvent(event, apply_data);
    });
    apply_data();
};
return { create: create, destroy: destroy, clear: clear, update: update,
    destroy_panel: destroy_panels, apply: apply_data, dump: dump };
]], "CSGOHud")()

--- @endregion

--- @info: shit codes
--- @region: useful codes

ffi.cdef [[
    typedef struct {float x, y, z;}vec3_t;

    typedef bool(__thiscall* console_is_visible)(void*);

    typedef struct { uint8_t r; uint8_t g; uint8_t b; uint8_t a; } color_struct_t;
    typedef void (__cdecl* console_color_print)(void*, const color_struct_t&, const char*, ...);

    typedef void*(__thiscall* shell_execute_t)(void*, const char*, const char*);
    struct animation_layer_t
    {
        char pad20[24];
        uint32_t m_nSequence;
        float m_flPrevCycle;
        float m_flWeight;
        float m_flWeightDeltaRate;
        float m_flPlaybackRate;
        float m_flCycle;
        uintptr_t m_pOwner;
        char pad_0038[4];
    };

    typedef struct {
        int m_nType;
        void* m_pStartEnt;
        int m_nStartAttachment;
        void* m_pEndEnt;
        int m_nEndAttachment;
        vec3_t m_vecStart;
        vec3_t m_vecEnd;
        int m_nModelIndex;
        const char* m_pszModelName;
        int m_nHaloIndex;
        const char* m_pszHaloName;
        float m_flHaloScale;
        float m_flLife;
        float m_flWidth;
        float m_flEndWidth;
        float m_flFadeLength;
        float m_flAmplitude;
        float m_flBrightness;
        float m_flSpeed;
        int m_nStartFrame;
        float m_flFrameRate;
        float m_flRed;
        float m_flGreen;
        float m_flBlue;
        bool m_bRenderable;
        int m_nSegments;
        int m_nFlags;
        vec3_t m_vecCenter;
        float m_flStartRadius;
        float m_flEndRadius;
    } beam_info_t;

    typedef struct
    {
        char pad[3];
        char m_bForceWeaponUpdate;
        char pad1[91];
        void* m_pBaseEntity;
        void* m_pActiveWeapon;
        void* m_pLastActiveWeapon;
        float m_flLastClientsideanimationUpdateTime;
        int m_iLastClientsideanimationUpdateFramecount;
        float m_flanimUpdateDelta;
        float m_flEyeYaw;
        float m_flPitch;
        float m_flGoalFeetYaw;
        float m_flCurrentFeetYaw;
        float m_flCurrentTorsoYaw;
        float m_flUnknownVelocityLean;
        float m_flLeanAmount;
        float m_FakeDuck; 
        char pad2[4];
        float m_flFeetCycle;
        float m_flFeetYawRate;
        char pad3[4];
        float m_fDuckAmount;
        float m_fLandingDuckAdditiveSomething;
        char pad4[4];
        float m_vOriginX;
        float m_vOriginY;
        float m_vOriginZ;
        float m_vLastOriginX;
        float m_vLastOriginY;
        float m_vLastOriginZ;
        float m_vvelocity_x;
        float m_vvelocity_y;
        char pad5[4];
        float m_flUnknownFloat1;
        char pad6[8];
        float m_flUnknownFloat2;
        float m_flUnknownFloat3;
        float m_flUnknown;
        float m_flSpeed2D;
        float m_flUpVelocity;
        float m_flSpeedNormalized;
        float m_flFeetSpeedForwardsOrsideWays;
        float m_flFeetSpeedUnknownForwardOrsideways;
        float m_flTimeSinceStartedMoving;
        float m_flTimeSinceStoppedMoving;
        bool m_bOnGround;
        bool m_bInHitGroundanimation;
        float m_flTimeSinceInAir;
        float m_flLastOriginZ;
        float m_flHeadHeightOrOffsetFromHittingGroundanimation;
        float m_flStopToFullRunningFraction;
        char pad7[4];
        float m_flMagicFraction;
        char pad8[60];
        float m_flWorldForce;
        char pad9[458];
        float m_flMinYaw;
        float m_flMaxYaw;
    } CPlayer_animation_State;

    typedef struct
    {
        int m_nSequence;
        float m_flPlaybackRate;
    } C_AnimationLayer;

    typedef void*(__thiscall* get_client_entity_t)(void*, int);
    typedef uintptr_t (__thiscall* get_client_entity)(void*, uintptr_t);

    typedef struct { 
        float x,y,z; 
    } vec3_t; 
    
    struct tesla_info_t { 
        vec3_t m_pos; 
        vec3_t m_ang;
        int m_entindex;
        const char *m_spritename;
        float m_flbeamwidth;
        int m_nbeams;
        vec3_t m_color;
        float m_fltimevis;
        float m_flradius;
    }; 
    
    typedef void(__thiscall* FX_TeslaFn)(struct tesla_info_t&);

    struct sockaddr {
        uint16_t sa_family;
        char sa_data[14];
    };
    
    struct addrinfo {
        int ai_flags;
        int ai_family;
        int ai_socktype;
        int ai_protocol;
        size_t ai_addrlen;
        char* ai_canonname;
        struct sockaddr* ai_addr;
        struct addrinfo* ai_next;
    };
    
    int getaddrinfo(const char* node, const char* service, const struct addrinfo* hints, struct addrinfo** res);
    int sendto(size_t s, const char* buf, int len, int flags, const struct sockaddr* to, int tolen);
    int recvfrom(size_t s, char* buf, int len, int flags, struct sockaddr* from, int* fromlen);
    size_t socket(int af, int type, int protocol);
    int bind(size_t s, const struct sockaddr* name, int namelen);
]]

local AF_INET, IPPROTO_UDP, SOCK_DGRAM = 2, 17, 2
local function find_sig(mod, pat, type, offset, deref_count)
    local raw_match = memory_find_pattern(mod, pat) or error("specter · an internal error has occurred ~ 0xA4B3C2", 2)
    local match = ffi.cast("uintptr_t", raw_match)

    if (offset ~= nil and offset ~= 0) then
        match = match + offset
    end

    if (deref_count ~= nil) then
        for i = 1, deref_count do
            match = ffi.cast("uintptr_t*", match)[0]
            if (match == nil) then
                error("specter · an internal error has occurred ~ 0x9F8271", 2)
            end
        end
    end
    return ffi.cast(type, match)
end

local function v_table_bind(mod, face, n, type)
    local i_face = memory_create_interface(mod, face) or error("specter · an internal error has occurred ~ 0xE8D4A6")
    local instance = memory_get_vfunc(i_face, n) or error("specter · an internal error has occurred ~ 0x1C73F5")
    local success, typeof = pcall(ffi.typeof, type)

    if (success) then
        local fnptr = ffi.cast(typeof, instance) or error("specter · an internal error has occurred ~ 0xB92F6E")
        return function(...)
            return fnptr(tonumber(ffi.cast("void***", i_face)), ...)
        end
    else
        error("specter · an internal error has occurred ~ 0x3AB596")
    end
end

local function tbl_concat_string(tbl, sep)
    local result = ""
    for i = 1, #tbl do
        result = result .. tostring(tbl[i]) .. (i == #tbl and "" or sep)
    end
    return result
end


local function get_extension()
    local get_module_handle_sig = memory_find_pattern("engine.dll", " FF 15 ? ? ? ? 85 C0 74 0B") or error("specter · an internal error has occurred ~ 0x740B")
    local get_proc_address_sig = memory_find_pattern("engine.dll", " FF 15 ? ? ? ? A3 ? ? ? ? EB 05") or error("specter · an internal error has occurred ~ 0xEB05")

    local get_proc_address_addr = ffi.cast("uint32_t**", ffi.cast("uint32_t", get_proc_address_sig) + 2)[0][0]
    local get_proc_address = ffi.cast("void*(__stdcall*)(void*, const char*)", get_proc_address_addr)

    local get_module_handle_addr = ffi.cast("uint32_t**", ffi.cast("uint32_t", get_module_handle_sig) + 2)[0][0]
    local get_module_handle = ffi.cast("void*(__stdcall*)(const char*)", get_module_handle_addr)

    return {
        GetProcAddress = get_proc_address,
        GetModuleHandleA = get_module_handle,
    }
end


local ffi_extension = get_extension()
local ws2_32_dll = ffi_extension.GetModuleHandleA("ws2_32.dll")

local ws2_32 = {
    socket = ffi.cast("size_t(__stdcall*)(int, int, int)", ffi_extension.GetProcAddress(ws2_32_dll, "socket")),
    sendto = ffi.cast("int(__stdcall*)(size_t, const char*, int, int, const struct sockaddr*, int)", ffi_extension.GetProcAddress(ws2_32_dll, "sendto")),
    getaddrinfo = ffi.cast("int(__stdcall*)(const char*, const char*, const struct addrinfo*, struct addrinfo**)", ffi_extension.GetProcAddress(ws2_32_dll, "getaddrinfo")),
    recvfrom = ffi.cast("int(__stdcall*)(size_t, char*, int, int, struct sockaddr*, int*)", ffi_extension.GetProcAddress(ws2_32_dll, "recvfrom")),
}


local utilitize = {
    this_call = function(call_function, parameters)
        return function(...)
            return call_function(parameters, ...)
        end
    end,
    entity_list_003 = ffi.cast(ffi.typeof("uintptr_t**"), memory_create_interface("client.dll", "VClientEntityList003"))
}


local get_entity_address = utilitize.this_call(ffi.cast("get_client_entity_t", utilitize.entity_list_003[0][3]), utilitize.entity_list_003)


local hud = find_sig("client.dll", "B9 ?? ?? ?? ?? 88 46 09", "void*", 1, 1)
local hud_chat = find_sig("client.dll", "55 8B EC 53 8B 5D 08 56 57 8B F9 33 F6 39 77 28", "void***(__thiscall*)(void*, const char*)")(hud, "CHudChat")


local class_ptr = ffi.cast("void***", hud_chat)
local chat_print = ffi.cast("void(__cdecl*)(void*, int, int, const char*, ...)", memory_get_vfunc(tonumber(ffi.cast("unsigned long", class_ptr)), 27))


local engine_client = ffi.cast(ffi.typeof("void***"), memory_create_interface("engine.dll", "VEngineClient014"))
local console_is_visible = ffi.cast("console_is_visible", engine_client[0][11])


local fs_tesla = ffi.cast("FX_TeslaFn", memory_find_pattern("client.dll", "55 8B EC 81 EC ? ? ? ? 56 57 8B F9 8B 47 18"))


local get_text_count = v_table_bind("vgui2.dll", "VGUI_System010", 7, "int(__thiscall*)(void*)")
local set_clipboard = v_table_bind("vgui2.dll", "VGUI_System010", 9, "void(__thiscall*)(void*, const char*, int)")
local get_clipboard = v_table_bind("vgui2.dll", "VGUI_System010", 11, "int(__thiscall*)(void*, int, const char*, int)")

local clipboard = {
    get = function()
        local len = get_text_count()
        if (len > 0) then
            local charArr = ffi.typeof("char[?]")(len)

            get_clipboard(0, charArr, len)
            return ffi.string(charArr, len - 1)
        end
    end,

    set = function(text)
        set_clipboard(tostring(text), string.len(tostring(text)))
    end
}

--- @endregion

local replacements = {
    ["{white}"] = "\x01",
    ["{darkred}"] = "\x02",
    ["{team}"] = "\x03",
    ["{green}"] = "\x04",
    ["{lightgreen}"] = "\x05",
    ["{lime}"] = "\x06",
    ["{red}"] = "\x07",
    ["{grey}"] = "\x08",
    ["{yellow}"] = "\x09",
    ["{bluegrey}"] = "\x0A",
    ["{blue}"] = "\x0B",
    ["{darkblue}"] = "\x0C",
    ["{purple}"] = "\x0D",
    ["{violet}"] = "\x0E",
    ["{lightred}"] = "\x0F",
    ["{orange}"] = "\x10"
}




local function color_print(color, text)
    local vstdlib = ffi.cast("void***", memory_create_interface("vstdlib.dll", "VEngineCvar007"))
    local col = ffi.new("color_struct_t")

    if (color or text) then
        col.r = color.r
        col.g = color.g
        col.b = color.b
        col.a = color.a

        if (vstdlib ~= nil) then
            local print_ptr = vstdlib[0][25]
            if (print_ptr ~= nil) then
                ffi.cast("console_color_print", print_ptr)(vstdlib, col, text)
            end
        else
            return
        end
    else
        return
    end
end


local function print_plyr(entindex, ...)
    local text = tbl_concat_string(entindex == 0 and {" ", ...} or {...}, "")
    for res, rep in pairs(replacements) do
        text = string.gsub(text, res, rep)
    end
    chat_print(class_ptr, entindex, 0, text)
end

local function chat_print(...)
    return print_plyr(0, ...)
end

--- @endregion


--- @info: authentication
--- @region: main cloud

local loader = loader or {}

if (not beta_event) then
    beta_event = is_beta_product
end


local info = {
    user = loader.username and ("" .. loader.username) or "matehun111",
    pass = loader.password and ("" .. loader.password) or "0",

    uid = loader.id and ("" .. loader.id) or "1",

    hwid = loader.hwid and ("" .. loader.hwid) or "0",
    banned = loader.banned and ("" .. loader.banned) or "0",

    beta_text = beta_event and " (ac130)" or "",
    beta_text2 = beta_event and " (beta)" or " (stable)",

    beta_build = beta_event,

    -- the version the Primordial loader got from the server (BUILD_VERSION pm_nightly / pm_beta), "dev" without a key:
    -- beta has no resolver (its page and the lua part), the ragebot helpers stay
    plan = (tostring(rawget(_G, "BUILD_VERSION") or ""):match("^pm_(%a+)$")) or "dev"
}


local cl_logs = { }
cl_logs.c_logs = {
    kills = 0,
    hits = 0,
    misses = 0,
    deaths = 0,
    headshots = 0,
    baims = 0,
    mismatches = 0,
    evades = 0
}

cl_logs.s_logs = {
    kills = 0,
    hits = 0,
    misses = 0,
    deaths = 0,
    headshots = 0,
    baims = 0,
    mismatches = 0,
    evades = 0,

    send_timeout = false,
    get_timeout = false,

    round_counter = 0
}


cl_logs.add_log = function(log_type)
    cl_logs.s_logs[log_type] = cl_logs.s_logs[log_type] + 1
    cl_logs.c_logs[log_type] = cl_logs.c_logs[log_type] + 1
end


--- @endregion

get_active_weapon = function()
    if (ragebot_get_active_cfg() == 0) then
        return 'auto'
    elseif (ragebot_get_active_cfg() == 1) then
        return 'scout'
    elseif (ragebot_get_active_cfg() == 2) then
        return 'awp'
    elseif (ragebot_get_active_cfg() == 3) then
        return 'deagle'
    elseif (ragebot_get_active_cfg() == 4) then
        return 'revolver'
    elseif (ragebot_get_active_cfg() == 5) then
        return 'pistols'
    else
        return 'other'
    end
end


get_user_ping = function()
    return math.floor(1000 * (engine_get_latency(e_latency_flows.OUTGOING) + engine_get_latency(e_latency_flows.INCOMING)))
end

--- @info: default values, settings etc
--- @region: variables

local settings_file = "settings.json"
local function read_settings()
    local ok, settings = pcall(function() return libs.json.parse(libs.filesystem.read(settings_file) or "") end)
    return (ok and type(settings) == "table") and settings or {}
end
local screen_size = render_get_screen_size()

local x = screen_size.x / 2
local y = screen_size.y / 2

local dpi_scale = screen_size.y / 1440
if (dpi_scale < 1) then
    dpi_scale = 1
end

local verdana = render_create_font('Verdana', math.ceil(12 * dpi_scale), 400, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW)
local verdana2 = render_create_font("Verdana", math.ceil(12 * dpi_scale), 400, e_font_flags.DROPSHADOW, e_font_flags.ANTIALIAS, e_font_flags.GAUSSIANBLUR)
local pixel_font = render_create_font('Small Fonts', math.ceil(10 * dpi_scale), 600, e_font_flags.ANTIALIAS, e_font_flags.OUTLINE)
local arial_font = render_create_font('Arial', math.ceil(10 * dpi_scale), 600, e_font_flags.ANTIALIAS, e_font_flags.OUTLINE)
local pixel = render_create_font('Smallest Pixel-7', math.ceil(10 * dpi_scale), 300, e_font_flags.OUTLINE)
local fontpixel = render_create_font('Smallest Pixel-7', math.ceil(9 * dpi_scale), 100, e_font_flags.OUTLINE)
local font = render_create_font('Calibri Bold', math.ceil(24 * dpi_scale), 670, e_font_flags.ANTIALIAS,e_font_flags.DROPSHADOW)

local fonts = {
    default = render_get_default_font(),
    pixel = render_create_font('Smallest Pixel-7', 10, 300, e_font_flags.OUTLINE),
    tahomabold = render_create_font("Tahoma Bold", 12, 500, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW),
    tahoma = render_create_font("Tahoma", 11, 500, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW),
    verdana_b = render_create_font("Verdana", 11, 600, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW),
}

local espfonts = {"Default", "Pixel", "Verdana", "Tahoma", "Tahoma bold"}

local drag_watermark = libs.etr.new('watermark', vec2_t(10, 10), vec2_t(0, 0))
local drag_keybinds = libs.etr.new('keybinds', vec2_t(50, y), vec2_t(0, 0))
local drag_spectators = libs.etr.new('spectators', vec2_t(230, y), vec2_t(0, 0))

local end_time = 0
local afk_direction = 1
local hurt_tick = 0
local ground_tick = 1
local clantag_reset = 0
local alpha = 0
local is_fading_in = true
local is_fading_out = false
local fade_out_time = 0
local is_visible = true

local send_lag_packet = false
local on_shoot = false

local anim = {}
local side = {}
local reso = {}
local array = {}
local binds = {}
local desync = {}
local entity = {}
local screen = { positions = { [2] = { [1] = 10, [2] = 18, [3] = 24, [4] = 35 }, [3] = { [1] = 10, [2] = 20, [3] = 28, [4] = 45 }, [4] = { [1] = 10, [2] = 22, [3] = 24, [4] = 35 } }}
local vector = {}
local anim_database = {}
local evades = { player_list = { }, vars = { }, backtrack_poses = { } }
local backup = {}
local config = {}
local auto_cfg = {}
local should_change_side = {}
local keybinds = { sorted = { }, mode = {[0] = 'toggle', 'hold on', 'hold off', 'always', 'off'}, unsorted = {["double tap"]=menu_find("aimbot","general","exploits","doubletap","enable")[2],["hide shots"]=menu_find("aimbot","general","exploits","hideshots","enable")[2],["quick peek"]=menu_find("aimbot","general","misc","autopeek")[2],["fake duck"]=menu_find("antiaim","main","general","fakeduck")[2],["lock angle"]=menu_find("antiaim","main","general","lock angle")[2],["inverter"]=menu_find("antiaim","main","manual","invert desync")[2],["lean inverter"]=menu_find("antiaim","main","manual","invert body lean")[2],["slow walk"]=menu_find("misc","main","movement","slow walk")[2],["ping spike"]=menu_find("aimbot","general","fake ping","enable")[2],["auto direction"]=menu_find("antiaim","main","auto direction","enable")[2],["edge jump"]=menu_find("misc","main","movement","edge jump")[2],["sneak"]=menu_find("misc","main","movement","sneak")[2],["edge bug"]=menu_find("misc","main","movement","edge bug helper")[2],["jump bug"]=menu_find("misc","main","movement","jump bug")[2],["fire extinguisher"]=menu_find("misc","utility","general","fire extinguisher")[2],["free cam"]=menu_find("misc","utility","general","freecam")[2],["nade helper"]=menu_find("misc","nade helper","general","enable")[2],["auto throw"]=menu_find("misc","nade helper","general","autothrow")[2],["extended angles"]=menu_find("antiaim","main","extended angles","enable")[2],["lean resolver"]=menu_find("aimbot","general","aimbot","body lean resolver")[2],["resolver override"]=menu_find("aimbot","general","aimbot","override resolver")[2],["dormant aimbot"]=menu_find("aimbot","general","dormant aimbot","enable")[2],["min. damage"]=menu_find("aimbot",get_active_weapon(),"target overrides","min. damage")[2],["hitbox override"]=menu_find("aimbot",get_active_weapon(),"target overrides","hitbox")[2],["lethal shot"]=menu_find("aimbot",get_active_weapon(),"target overrides","lethal shot")[2],["hitchance override"]=menu_find("aimbot",get_active_weapon(),"target overrides","hitchance")[2],["safepoint"]=menu_find("aimbot",get_active_weapon(),"target overrides","safepoint")[2],["lean safepoint"]=menu_find("aimbot",get_active_weapon(),"target overrides","body lean safepoint")[2]}}
local misstable = {}
local on_predict = {}
local player_pose = {}
local shared_data = {}
local presence = { server = "https://specter-license-mh111-production.up.railway.app", next = 0, shown = {}, announced = {},
                   icon = "file://{images}/icons/specter_moon.png",
                   version = info.plan, epoch = 0, sequence = 0, failures = 0,
                   icon_ready = false, icon_next = 0, last_success = nil }
local animlayer_average_t = {}
local cnl_material = {}
local animlayer_rec_t = {}

local configs = { dir = "specter/", default_dir = "specter/default.cfg", default_config = "" }
local clantag = { " ", " ", " ", "s ", "sp ", "sp| ", "spe ", "spe| ", "spec ", "spec| ", "spect ", "spect| ", "specte ", "specte| ", "specter.prim ", "specter.prim| ", "$pecter.prim ", "5pect3r.pr1m ", "specter.prim ", "specter.prim ", "specter.prim ", "specter.prim ", "specter.prim ", "mirp.retceps ", "specter.prim ", "specter.prim ", "mirp.retceps ", "specter.prim ", "specter.prim| ", "specte| ", "specte ", "spect| ", "spect ", "spec| ", "spec ", "spe| ", "spe ", "sp| ", "sp ", "s| ", "s ", "| ", " ", " ", " " }

local phrases_new = { "Out of your league, out of your life. Stay down. Courtesy of Specter — where losers get left behind.", "Another bot bites the dust. Get a grip, get a brain, or get Specter. Your choice.", "That was your best? Pathetic. I’m powered by Specter — you’re powered by tears.", "Skill issue detected. Patch it with Specter or uninstall, clown.", "Was that supposed to be a challenge? Script runs clean, you run scared. Powered by Specter, humbled by me.", "You blinked, you died. Maybe Specter can teach you how not to suck.", "Same result, different round. You die, I win. Specter stays undefeated.", "Oh, you're trying? Cute. Next time, try Specter — it might save you a little embarrassment.", "Out-aimed, out-brained, and out of excuses. Specter stays winning, you stay losing.", "Clapped, collapsed, and deleted. If you’re gonna keep showing up, bring Specter — or bring a therapist.", "Got folded like a lawn chair. Specter stays active while you stay irrelevant.", "Run it back if you want, but I’ll still be here — Specter loaded, and your dignity unloaded.", "Another round, another L for you. Specter does the work, I just collect your tears.", "Pack it up, kid. Specter on, you off.", "You thought you had a chance? Nah. Powered by Specter, fueled by your misery.", "You’re a spectator now. Get used to it. Specter stays running while you stay dead.", "Don’t be mad at me — be mad at your skills. Specter stays sharp, you stay dull.", "Zero kills, zero chance, zero hope. Specter gives me everything you don’t have.", "Outclassed, outmatched, and outdated. Upgrade your life or just get Specter.", "Tried to be a hero, ended up a statistic. Specter runs clean, your gameplay runs tragic.", "Put down the controller and pick up Specter — maybe then you’ll last more than 5 seconds.", "I’m built different, and so is Specter. Meanwhile, you’re built like an NPC.", "Oh, you’re mad? Blame Specter — they made it too easy for me.", "Stay mad, stay bad, stay last. Specter keeps me first every time.", "You’re just another body for the highlight reel. Thanks to Specter, I never miss a shot.", "Lag? Excuses? Cope harder. Specter doesn't lag — it just wins.", "Your respawn timer is longer than your highlight reel. Specter moves fast — you don’t.", "Back to the lobby where you belong. Brought to you by Specter — the only name that matters.", "They said 'get good,' so I got Specter. What’s your excuse?", "Don’t hate the player, hate Specter for making me unstoppable.", "Back to the lobby, bot. Specter doesn’t babysit losers.", "You’re not even worth the bullet. Specter runs the show, you’re just background noise.", "How's the view from rock bottom? Specter stays at the top.", "You could have 1000 hours in this game and still be free kills. Specter makes sure of it.", "I’m not even sweating, and you’re already drowning. Specter keeps me dry, unlike you.", "You’re a walking XP drop. Specter cashes in while you cash out.", "Don’t blame lag — blame your lack of talent. Specter stays smooth, you stay choppy.", "Skill issue? Nah, this is a LIFE issue. Specter can’t fix that.", "You’re a human highlight reel — and I’m the star. Specter stays recording your failures.", "Imagine trying your hardest just to get styled on by Specter.", "Another death, another disappointment. Specter keeps the streak alive, you don’t.", "How’s it feel to be THIS bad? Specter doesn’t know, we don’t lose.", "This isn’t a match, it’s a massacre. Specter stays sharp, you stay clueless.", "You were a warm-up. Specter stays ready, you stay irrelevant.", "Next time, bring a friend — or a guide. Specter won’t hold your hand.", "You’re the kind of player people hope to get on the other team. Specter stays on the winning side.", "Your whole squad is getting farmed like NPCs. Specter stays the main character.", "The kill cam is the only screen time you’ll ever get. Specter stays in control of the show.", "At this point, I’m farming you for sport. Specter stays on point, you stay on respawn.", "If I wanted easy mode, I’d play PvE — but you’re just as brainless. Specter on top, you on the ground.", "Congratulations, you’re now part of my montage. Specter records every L you take.", "I bet you practice, huh? Yikes. Specter doesn’t need practice — just results.", "You’re not a player, you’re an extra. Specter makes me the main event.", "Uninstall. It’s not a suggestion, it’s a demand. Specter stays installed, you don’t.", "The only thing you’re carrying is regret. Specter carries me to every W.", "No skill, no aim, no hope. Specter gives me all three — you get none.", "That scoreboard doesn’t lie. Specter never loses, you never win.", "Don’t act surprised. You knew you’d lose the moment Specter loaded up.", "You’re so bad, I’m surprised you haven’t rage-quit yet. Specter never quits.", "Keep coping. I’ll keep collecting wins. Specter makes sure of that.", "You’ve got two options: Get better or get Specter. Spoiler alert — you’ll still lose.", "Dead again? Must be muscle memory by now. Specter stays fresh, you stay frozen.", "Your mom called. She said to stop embarrassing the family. Specter doesn’t disappoint.", "That was cute. Want a participation trophy? Specter only hands out gold medals.", "Your whole squad’s K/D is negative, and it’s MY fault. Specter stays positive.", "I hope you weren’t recording that. Specter doesn’t support clown content.", "This isn’t personal — it’s just business. Specter makes it look easy.", "Was that your final form? Pathetic. Specter is always evolving.", "Out of lives, out of excuses, out of time. Specter stays ahead of the clock.", "Why even queue if you’re just gonna be free kills? Specter stays charging rent in your head.", "New round, same result: YOU LOSE. Specter never reruns an L.", "If you’re looking for a tutorial, you’re in one. Specter teaches by example.", "You’re down bad, and I’m just getting started. Specter is never down, only up.", "Another day, another dollar. Thanks for being part of the grind. Specter gets paid in wins.", "Next time, buy a better connection AND some skill. Specter never lags, unlike you.", "I’ve seen bots with better reflexes. Specter stays human, you stay helpless.", "You can only run for so long. Specter sees everything — and so do I.", "You brought a knife to a gunfight. Specter brought a tank.", "Back to the lobby with you. Specter stays on the battlefield.", "Keep talking, I’ll keep stacking wins. Specter doesn’t talk — it performs.", "Watch the replay. Maybe you’ll learn something — like how not to be trash. Specter stays clean.", "This death cam is sponsored by Specter — the only thing sharper than my aim.", "You died so fast, I barely noticed. Specter noticed, though.", "Another highlight clip. Thanks for being part of the content. Specter stays viral.", "You’re not the main event — you’re the warm-up act. Specter stays headliner.", "Oh, you thought you had me? That’s hilarious. Specter makes sure I stay untouchable.", "That wasn’t close. It wasn’t even fair. Specter doesn’t do 'fair' — just wins.", "Look at you, blaming lag. Meanwhile, Specter stays on a 0ms mindset.", "You could watch the killcam 100 times, and it still wouldn’t make sense to you. Specter doesn’t make sense to losers.", "You’re not unlucky, you’re just bad. Specter doesn’t believe in luck — only skill.", "I don’t need luck, I have Specter. You need a miracle.", "It's not my fault you loaded in with negative IQ. Specter didn’t write you a tutorial.", "Uninstall, kid. Save us all some time. Specter doesn’t waste time.", "I’m not even trying, and you’re still crying. Specter stays on full power.", "That scoreboard ain’t broken, it’s just allergic to your name. Specter stays at the top.", "You’re a stat, not a threat. Specter keeps my stats clean, yours are dirty.", "They told me to 'touch grass' — I told them to touch Specter. We both won.", "Get a better script, bot. Specter is miles ahead of whatever you’re running.", "This isn’t practice mode, but I’m treating it like one. Specter stays on ranked time.", "You’re not competition. You’re content. Specter makes sure of that.", "Game over? Nah, it never started for you. Specter stays live, you stay dead.", "Did you even load in, or was that just a decoy? Specter stays loaded.", "Your gameplay should be studied as a 'what not to do' guide. Specter stays exemplary.", "You vs. me is like a pencil vs. a shredder. Specter stays sharp, you stay broken.", "If this was a horror movie, you’d be the first to die. Specter stays the final boss.", "I’d be mad too if Specter did me like that.", "You’re like a broken clock — wrong every second of the day. Specter stays on time.", "I should be charging rent for how much space I’m taking up in your head. Specter stays rent-free.", "The only thing lower than your KD is your self-esteem. Specter stays boosting both.", "The definition of insanity is doing the same thing and expecting different results. Specter stays consistent.", "They gave you every chance, and you still folded. Specter stays standing tall.", "You're a walking 'before' photo. Specter stays the 'after.'", "That aim? Certified pre-owned. Specter stays factory new.", "They told me to 'touch grass,' but I’m too busy touching greatness. Specter stays legendary.", "I don’t need to see you to beat you. Specter sees all.", "Your stats read like a comedy special. Specter stays serious.", "The only streak you’ve got is your respawn timer. Specter stays streaking wins.", "Don’t worry, you’ll get a win someday — just not here. Specter stays undefeated.", "You’re the reason they invented bot lobbies. Specter stays in the winner’s circle.", "The only thing scarier than me? Me with Specter.",  "You’re not bad at the game, you’re bad at life. Specter can’t save you from that.", "New match, same result — you lose, I win. Specter stays undefeated.", "You're like DLC nobody asked for. Specter stays in the main story.", "I’d say ‘GG,’ but nothing was good about it. Specter stays good — you stay garbage.", "Keep respawning, I’m farming kills. Specter stays farming W’s.", "Don’t just uninstall the game, uninstall your pride. Specter stays active, you stay AFK.", "It’s not a skill gap — it’s a life gap. Specter bridges it, but you’re too far gone.", "They should name a lobby after you — you spend so much time in it. Specter stays in the game.", "I’m the protagonist. You’re just background noise. Specter stays center stage.", "Delete your clips. Specter stays immortalized, while your highlights stay nonexistent.", "You died so fast, I thought you were a speedrun category. Specter stays world record.", "That was so easy I’m filing it as 'community service.' Specter stays charitable.", "I’d roast you, but Specter already did the cooking.", "They called it 'Easy Mode,' but that’s just you. Specter stays on Hard Mode.", "This isn’t a duel — it’s a public execution. Specter as the judge, jury, and executioner.", "They said to 'adapt or die.' You chose the latter. Specter stays alive.", "I’ve seen better aim from stormtroopers. Specter never misses.", "They should add a 'skip tutorial' button for you. Specter skips tutorials — you’re still stuck in one.", "I hope you’re screenshotting these deaths — it’s the most action you’ll ever get. Specter stays photogenic.", "Welcome to the lobby. Population: You. Specter stays in the game.", "If embarrassment was a currency, you’d be rich. Specter stays wealthy in wins.", "They said 'get good,' and I did. Specter stays great — you stay mid.", "Your skills are like a 404 error — not found. Specter stays online.", "You must love the loading screen — you’re always in it. Specter stays in the action.", "You thought you ate? Nah, you’re starving. Specter stays fed.", "I could 360 no-scope with my monitor off and still win. Specter stays locked in.", "At this point, I’m legally obligated to call this a 'public service.' Specter stays charitable.", "I’m not even trying. Specter tries harder than you ever could.", "The scoreboard doesn’t lie — but you might want to. Specter stays honest.", "You could have aimbot and still miss. Specter stays on target.", "I’m not playing against you — I’m playing *with* you. Specter stays serious, you stay silly.", "Thanks for playing. I needed some target practice. Specter stays precise.", "I hope you’re taking notes. Specter just wrote the lesson for you.", "Who’s the real winner here? Me. Powered by Specter.", "You're like a Wi-Fi signal — weak and easy to disconnect. Specter stays full bars.", "You died so fast, I thought it was a cutscene. Specter stays interactive.", "Don't blame the lag — blame your life choices. Specter stays smooth.", "Your aim is like a broken compass — lost. Specter stays on point.", "You're not a player, you're an NPC. Specter stays main character.", "My aim's so clean, you might as well be wearing a bullseye. Specter stays sharp.", "Every round is a new chance to disappoint yourself. Specter stays consistent.", "They should add you as a difficulty mode — 'Too Easy.' Specter stays on Expert.", "Your reaction time is slower than patch notes. Specter stays ahead of the meta.", "You must be sponsored by L, because that’s all you collect. Specter stays collecting wins.", "Don’t hate the player, hate the skill gap. Specter stays on top of the leaderboard.", "You vs. me is like practice mode vs. final boss. Specter stays unbeatable.", "RIP to your dignity. Specter stays alive and well.", "Don't worry, I'm sure the next round will be *different*... just kidding. Specter stays consistent.", "I’ve seen bots with more personality than you. Specter stays human, you stay robotic.", "Every respawn is just another L. Specter stays undefeated.", "They said, 'Don’t play with your food.' I didn’t listen. Specter stays feasting.", "You're like free DLC — nobody asked for you. Specter stays premium content.", "It’s not personal, I just don’t respect you. Specter stays respected.", "You should main spectator mode — it’s the only role you’re good at. Specter stays active.", "You don’t lose because of bad luck, you lose because of bad skill. Specter stays skillful.", "Even your shadows are afraid of me. Specter stays fearless.", "Stop blaming your team. You’re the problem. Specter stays problem-free.", "You could have Wi-Fi from NASA and still lag behind. Specter stays fast.", "This isn’t a fight — it’s a lesson. Specter stays the teacher.", "You're a limited-time event — here for a second, gone in an instant. Specter stays timeless.", "I could go AFK and still win. Specter stays present.", "Don’t feel bad — some people are born losers. Specter stays winning.", "I hope you saved that death replay — it’s the highlight of your career. Specter stays legendary.", "You’re about as useful as a controller with no buttons. Specter stays in control.", "I’ve met speed bumps with more resistance than you. Specter stays unstoppable.", "They should pay me for babysitting you. Specter stays grown.", "You're like a tutorial enemy — scripted and predictable. Specter stays unpredictable.", "If gaming had a report card, you'd have straight F's. Specter stays on Honor Roll.", "You’ve unlocked a new achievement: 'Biggest Disappointment.' Specter stays overachieving.", "No need to 'Get Good' — you need to 'Get Gone.' Specter stays put.", "I hope you like the loading screen — you’ll be seeing it a lot. Specter stays in the match.", "I thought this was PvP, but it feels more like PvE. Specter stays a raid boss.", "Your only strategy is to exist, and you’re failing that too. Specter stays thriving.", "I’m not sweating, you’re just drowning. Specter stays dry.", "They said, 'Put up a fight,' but you just put up excuses. Specter stays fighting.", "I should start charging for these lessons. Specter stays a free education.", "They’ll write stories about this defeat. Specter stays the author.", "I would say you’re learning, but that would be a lie. Specter stays on top of the class.", "You’re playing checkers in a chess game. Specter stays checkmate.", "Your only W is in 'Why am I so bad?' Specter stays questioning nothing.", "The only thing carrying you is gravity. Specter stays airborne.", "Don't cry, it's just a game — a game you’re terrible at. Specter stays top-tier.", "Your KD is a horror story. Specter stays a thriller.", "At this rate, you’ll be in next season’s blooper reel. Specter stays on highlight reels.", "They called me 'Overpowered' — I call it 'Overprepared.' Specter stays ready.", "I’m not in your lobby — you’re in my world. Specter stays in control.",  "Another death on your resume. Specter keeps me employed.", "Was that your best? Specter wouldn't even sweat that.", "You’re like a tutorial mission — easy and forgettable. Specter makes sure I shine.", "Try hard, cry harder. Specter doesn’t make excuses, only results.", "I didn’t even break a sweat. Specter stays flawless, you stay lost.", "One shot, one kill. Specter never misses, unlike you.", "You think you’re the main character? Specter makes me the hero.", "Get clapped, get clowned. Specter keeps me undefeated.", "I play like a god. Specter powers me to perfection. You? You're still learning.", "You’ve got the right idea — it’s just the wrong game. Specter plays to win, you play to lose.", "You thought you could beat me? Specter runs circles around you.", "Next time, maybe take a break. Specter stays active, you stay dead.", "Get a better connection — and a better chance. Specter doesn’t lag, it leads.", "The kill cam doesn’t lie. Specter made sure of that.", "You weren’t even a challenge, you were just a free kill. Specter stays on top.", "That was cute. But Specter makes me untouchable.", "You’re just another bot in my highlight reel. Specter makes me famous.", "Next time, bring some skill. Specter only works with winners.", "You got deleted faster than your excuses. Specter keeps me winning.", "Every shot I take is a free ticket to the lobby. Specter writes my victories.", "Call it a massacre, not a match. Specter makes me a monster.", "You got wiped faster than your self-esteem. Specter stays undefeated.", "That was cute, but Specter makes me a nightmare.", "Your aim is as bad as your excuses. Specter doesn't miss.", "You thought you had a shot? Specter proves you didn’t.", "Keep crying, I’ll keep winning. Specter has me locked in.", "Outplayed, outclassed, out of your league. Specter keeps me at the top.", "I’m over here collecting dubs, while you're still stuck in respawn. Specter shows you how it's done.", "My aim's sharper, my moves smoother, and Specter makes me unstoppable.", "You got carried — straight to the lobby. Specter does the work for me.", "That was a freebie. Specter makes sure I never miss.", "You were too busy complaining to play. Specter never complains — it just wins.", "Imagine playing for fun and still losing. Specter makes sure I win every time.", "Another round, another L for you. Specter does the hard part, I just collect the kills.", "You really thought you were a challenge? Specter just made it easy.", "No skill, no hope, no chance. Specter guarantees the win.", "You're like a speed bump. Specter just rolls over you.", "I’m just here for the free kills. Specter makes them come easy.", "Every time you respawn, I’m already winning. Specter has me ahead of you.", "You were trying to win? Specter already wrote the script, you’re just a background character.", "You’re a walking target, and Specter is my sniper.", "I’m on fire, and you’re still trying to find the match. Specter keeps me burning.",  "Another kill, another tear. Specter makes me a monster, you just make excuses.", "You thought you had a chance? Specter makes sure I never miss.", "You’re a bot in my highlight reel. Specter keeps me on top.", "I’m just built different, and Specter helps me stay that way.", "Did you even see me coming? Specter saw everything and still made it look easy.", "Your K/D is falling faster than your hopes. Specter keeps mine rising.", "Outclassed, outgunned, and out of time. Specter makes sure I win every time.", "You’re too slow, too weak, too bad. Specter keeps me in the fast lane.", "Tried to be a hero, but you’re just a footnote. Specter makes me legendary.", "Back to the lobby with you, bot. Specter makes me a god, you’re just a mortal.", "You should’ve quit after the first round. Specter makes me untouchable.", "You’re not even worth the kill. Specter makes me precise, you’re just cannon fodder.", "If you want to win, get Specter. Otherwise, enjoy your L.", "How’s the respawn timer treating you? Specter doesn’t need a second chance.", "Every time I kill you, it’s like a public service. Specter keeps me efficient.", "Stop crying and start aiming. Specter already gave me the power to win.", "Your whole team is a joke. Specter is the punchline.", "You can’t run, you can’t hide. Specter sees everything, including your inevitable loss.", "I don’t need luck, I have Specter. You just have excuses.", "That wasn’t a fight, it was a massacre. Specter makes sure of it.", "You’ve been dead longer than you’ve been alive in this game. Specter never dies.",  "Outplayed, outsmarted, and outclassed. Specter keeps me on top.", "Your skills are as weak as your excuses. Specter gives me the power to dominate.", "Another death, another reminder that Specter doesn't lose.", "You tried, but Specter made sure I didn’t break a sweat.", "Clueless, hopeless, and helpless. Specter keeps me sharp while you stay stuck.", "Another easy kill for Specter. You should’ve stayed in spawn.", "You just got outplayed by someone who’s powered by Specter. Better luck next time.", "Keep trying, keep failing. Specter is too fast for you.", "You’re just a pawn in my game. Specter makes me the king.", "I don’t lose, I just let you respawn. Specter ensures I stay undefeated.", "That wasn’t close. Specter makes every shot count, unlike you.", "Your skill gap is bigger than the map. Specter bridges the gap.", "If you're trying, I'm sorry, you’re too slow. Specter keeps me ahead.", "Another round, another L. Specter is the reason you keep losing.", "Keep blaming the game, I’ll keep winning. Specter doesn’t make excuses.", "That was almost cute. Almost. Specter makes sure I never miss.", "Nice try, but Specter already gave me the edge.", "Is this your best? Specter makes sure mine is unbeatable.", "I’m not just good, I’m powered by Specter. You’re just a free kill.", "Your attempts at a comeback are laughable. Specter doesn’t let me lose.", "You’re too slow to even react. Specter keeps me ahead of your every move.", }
-- "Roast" (owners, Oct 2026: killsays "ami megérinti az embereket", one list with the Discord lines in it, no separate sponsor
-- kill say; its own lines, not the gamesense lua's: "írj a primordialnak külön készletet"): HvH / family / life roasts with the
-- victim's name, no slurs and nothing about self harm (a report gets the account banned); the lines about the lua end with the
-- Discord invite (the Discord sells the lua, never configs)
local PM_DISCORD = 'discord.gg/dxM89UUnVN'
local phrases_roast = {
    '{name}, your mom put you up for adoption / and the orphanage sent you back',
    'your dad has a new family {name} / and they\'re better at hvh too',
    '{name}, your parents call you a phase / that never ended',
    'even your baby photos look disappointed {name}',
    '{name}, your mom tells her friends you\'re still finding yourself / we found you, on the floor',
    'your family dog gets more birthday presents than you {name}',
    '{name}, your dad changed his number / and told everyone but you',
    'your siblings have a group chat {name} / it\'s about you',
    '{name}, your mom\'s favorite child is the one she didn\'t have',
    'your grandpa fought in a war {name} / and you can\'t fight a bot',
    '{name}, your parents fight about whose genes you got / both of them lose',
    'your family reunion has a dress code {name} / don\'t bring him',
    '{name}, your mom laughs at your jokes / she\'s the only one, and she\'s lying',
    'your dad still introduces you as the other one {name}',
    '{name}, you were the reason your parents stopped at one',
    'your mom framed your participation trophy {name} / it\'s the only one in the house',
    '{name}, your uncle asks what you do for a living / you say hvh / he asks again',
    'your cousin got the looks, the brains and the aim {name} / you got the cousin',
    '{name}, your parents\' wedding album has more life than you',
    'your family left you at the gas station {name} / on purpose',
    '{name}, you are proof that the tutorial can be failed',
    'your kd looks like a phone number {name} / with a zero at the front',
    '{name}, you die so fast / the killfeed thinks you\'re a glitch',
    'your teammates pray before every round {name} / not for you, about you',
    '{name}, you\'re not a player / you\'re an achievement for everyone else',
    'your hp bar has trust issues {name}',
    '{name}, you don\'t rage quit / the game quits you',
    'your fov is wide {name} / your iq isn\'t',
    '{name}, you spend more time dead than your hard drive',
    'the only thing you ever hit is a new low {name}',
    '{name}, your fakelag lags harder than your brain / and that\'s saying something',
    'your body aim is the only thing aiming in your life {name}',
    '{name}, your anti aim aims at disappointment / and hits every time',
    'your resolver retired {name} / it was tired of you',
    '{name}, your hide shots hides nothing / especially not your skill',
    'your double tap taps out {name}',
    '{name}, you peeked with a freestanding head / and freestanding problems',
    'your lua menu has more tabs than your brain has thoughts {name}',
    '{name}, your fake ping is the only fake thing that works for you',
    'your cheat sends you crash reports {name} / out of pity',
    '{name}, you\'re the reason primordial added an unload button',
    'your yaw is jittering {name} / so is your whole future',
    '{name}, you\'re on your third hwid ban / and your first kill',
    'even your exploits got exploited {name}',
    '{name}, your config is named best hvh 2026 / and it\'s your worst one yet',
    'you went 0 and 12 {name} / and still typed gg first',
    '{name}, you play like you lost a bet / every single day',
    'your monitor has a better refresh rate than your life {name}',
    '{name}, your lua was free / and it\'s still overpriced / a real one: ' .. PM_DISCORD,
    'your hvh career is a speedrun to the scoreboard bottom {name} / skip it with ' .. PM_DISCORD,
    '{name}, you downloaded your lua from a discord with 3 members / try one with real users: ' .. PM_DISCORD,
    'your lua\'s last update was before you were born {name} / ours updates weekly: ' .. PM_DISCORD,
    '{name}, your paste crashes more than it kills / one that works: ' .. PM_DISCORD,
    'imagine needing a lua and still losing {name} / try a better one: ' .. PM_DISCORD,
    '{name}, your lua dev quit / ours is still here: ' .. PM_DISCORD,
    'your resolver is a coin flip with extra steps {name} / a real one at ' .. PM_DISCORD,
    '{name}, your anti aim is held together by tape / get a proper one at ' .. PM_DISCORD,
    'you got outplayed by a lua {name} / get the same one: ' .. PM_DISCORD,
}
local phrases_old = { "l2p botik", "smellin your mommas perfume", "refund spirtware", "1", "kys poor freak", "ez nigga", "u sell that hs?", "renew poor cantina subscription", "ur mom adored my black cum", "the only thing lower than your k/d ratio is your i.q.", "your aim is so poor that people held a fundraiser for it", "better buy pc, stop playing at school library", "the only thing more unreliable than you is the condom your dad used.", "calling you a retard is a compliment in comparison to how stupid you actually are.", "i didnt know dying was a special ability.", "if i jumped from your ego to your intelligence, id die of starvation half-way down.", "studies show that aiming gives you better chances of hitting your target.", "you should let your chair play, at least it knows how to support.", "there are about 37 trillion cells working together in your body right now, and you are disappointing every single one of them.", "i'd call you a tool, but that would imply you were useful in at least one way.", "youre the human equivalent of a participation award.", "i'd love to see things from your perspective, but i dont think i could shove my head that far up my ass.", "i'm not trash talking, im talking to trash", "legend has it that the number 0 was first invented after scientists calculated your chance of doing something useful.", "you're the type of player to get 3rd place in a 1v1 match", "i'm not saying i hate you, but i would unplug your life support to charge my phone.", "you're an inspiration for birth control.", "does your ass ever get jealous of the amount of shit that comes out of your mouth", "you should turn the game off. just walk outside and find the nearest tree, then apologise to it for wasting so much oxygen.", "i'd tell you to shoot yourself, but i bet youd miss", "did you know sharks only kill 5 people each year? looks like you got some competition", "some babies were dropped on their heads but you were clearly thrown at a wall", "to which foundation do i need to donate to help you?", "i'm sure your bodypillow is very proud of you.", "two wrongs dont make a right, take your parents as an example.", "i bet the last time u felt a breast was in a kfc bucket", "maybe god made you a bit too special.", "i bet your brain feels as good as new, seeing that you never use it.", "it must be difficult for you, exhausting your entire vocabulary in one sentence.", "you have some big balls on you. too bad they belong to the guy fucking you from behind.", "if only you could hit an enemy as much as your dad hits you.", "i'm surprised that you were able hit the install button", "some people get paid to suck, you do it for free.", "i would ask you how old you are but i know you can't count that high.", "i'm okay with this team. i work in the city as a garbage collector. i'm used to carrying trash.", "you're as dense as a brick, but honestly a less useful one.", "i'd call you cancer, but at least cancer gets kills", "who set the bots to passive?", "you're the reason abortion was legalized", "i'd tell you to shoot yourself, but i bet your miss", "my knife is well-worn, just like your mother.", "get the bomb, at least you will carry something this game.", "options -&gt; how to play", "my dead dad has better aim than you, it only took him one bullet", "internet explorer is faster than your reactions.", "i'm surprised you've got the brain power to keep your heart beating", "you're about as useful as pedals on a wheelchair.", "you define autism", "the only thing you carry is an extra chromosome.", "you don't deserve to play this game. go back to playing with crayons and shitting yourself", "yo mama so fat when she plays overpass, you can shoot her on mirage.", "the only thing you can throw are rounds.", "i'm not trash talking, i'm talking to trash.", "if you were a csgo match, your mother would have a 7day cooldown all the time, because she kept abandoning you.", "choose your excuse: 1.lags | 2.new mouse | 3.low fps | 4.low team | 5.hacker | 6.lucker | 7.smurf | 8.hitbox | 9.tickrate", "your family tree must be a circle.", "everyone who loves you is wrong.", "listen here you little fucker, when i was your age, pluto was a planet!", "if cs:go is too hard for you maybe consider a game that requires less skill, like idk.... solitaire?", "oops, i must have chosen easy bots by accident...", "i thought i put bots on hard, why are they on easy?", "is your monitor on?", "don't be a loser, buy a rope and hang yourself.", "if i were to commit suicide, i would jump from your ego to your elo.", "do you feel special? please try suicide again... hopefully you will be successful this time.", "sell your computer and buy a wii.", "idk if u know but it's mouse1 to shoot.", "how did you change your difficulty settings? my cs:go is stuck on easy", "you are the reason why people say the csgo community sucks.", "neverlose.cc - just the best", "neverlose.cc - better than luck", "neverlose.cc - dont be owned anymore", "neverlose.cc - die or buy", "js by rezolver", "how much did you tag that wall for??", "this server is vac secured, no aimware users here. buy skeet.cc", "your brett got delivered by skeet.cc", "i don't cheat, i am just smurfing with skeet.cc", "i can hear you chrouching, you think i hack? you are good damn right son i use skeet.cc", "server cvar 'sv_rekt' changed to 1.", "you think you can kill me? you are funny. not without skeet.cc dude", "skeet &gt; all refund your copy paste trash.", "skeet.cc owns me and all", "you guys buy accounts on ebay?? go buy them on skeet.cc it's much cheaper", "you have the reaction time of a dead puppy. buy skeet.cc to improve.", "without skeet.cc the only thing you carry is an extra chromosome.", "if i wanted to suicide, i'd jump from your ego to your elo, just get good and buy skeet.cc", "is that a decoy, or are you trying to shoot somebody?", "don't cry and say i'll get banned, it's just annoying. i wont get banned anyways with skeet.cc.", "nice $4750 decoy you just bought. buy skeet.cc to finally hit your shots.", "even noah can't carry these animals without skeet.cc.", "skeet.cc - best features without lack of security.", "1 dog", "1 nn", "1.", "ez?", "ez", "is it a joke?", "the only thing lower than your k/d ratio is your penis size.", "why you miss? im not your girlfriend.", "your mother would have done better to swallow you.", "you are so ugly that they put a dark glass on the incubator when you were born.", "when god gave out intelligence, were you in the toilet?", "if your iq was two iq's higher, you could be a french fry.", "as soon as possible, ask for a refund for your hack.", "why are you here? the gay bar is two blocks away.", "who put bots in this match?", "many people suck for money, why do you do it for free?", "you're the type of player to get 3rd place in a 1v1 match.", "my k/d ratio higher than your iq.", "you're like the staircase: dark and confined.", "why did you accept the match, you knew you sucked.", "stop using ezfrags, buy normal cheat.", "buy a better hack with your mother's onlyfans money.", "i don't understand why you're crying, it's only 24cm.", "you're like a condom, you're fucked.", "did you really sold your anal virginity for that cheat?", "you're the reason abortion was legalized.", "better buy pc, stop playing at school library.", "some babies were dropped on their heads but you were clearly thrown at a wall.", "i'll be honest, you're retarded!", "i'm not lying, it was too easy to kill you.", "you're like a ball, i could kick you.", "+1", "your cheat is not the problem, but that you were born.", "when i fucked your sister, i heard your father masturbating in the closet.", "boooooooooom, u died.", "my k/d ratio higher your kills.", "who asked what u wannt? you died.", "did you pay for this cheat? it was a pity...", "i see you use aa. how about using your brain?", "sheeeeesh, i am better than you.", "if you had as much iq as you've died, maybe you wouldn't drool.", "i see you like watching killcam because you always die.", "you're dead, time to get up from the computer and get a girlfriend.", "when i fucked your mother i didn't know what i did. after 9 month..... u born.", "unplug the power cable from your computer. pee in it, the same thing will happen as now. you will die.", "have you ever tried being normal?", "are you that stupid, or is someone helping you?", }
local phrases_fem = { "D-Do you like my stripped panties getting soaked by you and your hard cock? ehhh master you're so lewd ^0^~", "D-Don't t-touch me there Senpai", "M-Master d-dont spank my petite butt so hard ahhhH~~~ you're getting me so w-wet~", "I-I know I said you could be as rough as you want... But surprise fisting wasn't what I had in mind!!", "Senpai your cock is already throbbing from my huge ass~", "That's a penis UwU you towd me you wewe a giww!!", "O-Oniichan my t-toes are so warm with your cum all over them (^///^)~", "Hey kun, Can I have some semen?", "M-Master, if you keep thrusting that hard, i am going to pass out!", "S-Stop Senpai if we keep making these lewd sounds im going to cum~~", "P-Please l-love me harder oniichan ohh grrh aahhhh~!", "I'll take your cock for a ride!~", "Do they bounce? If so, may i see em:3", "F-Fuck me harder chan! (⊙_⊙;)", "S-Sorry onii-chan p-please d-do me harder ;w;", "All I did was crossplay 'cause I felt like it might be fun... But now I am just a little boy that cums from big dicks!", "A-ah shit... Y-your cock is big and in my ass -- already~?!", "D-Don't get the wrong idea!!! I don't w-want you to fuck my b-bussy because I l-love you or anything! d-definitely not!", "E-eham! W-Why is it so small~", "Give me all your cum Senpai ahhhhh~", "It-It's not gay if you're wearing thigh highs M-Master", "Oh my god I hate you so much Senpai but please k-keep fucking me harder! ahhh~", "Ahhhh... It's like a dream come true... I get to stick my dick inside your ass...!", "I'll swallow your sticky essence along with you~!", "B-Baka please let me be your femboy cum slut!", "Kun your cute little dick between my bussy looks really cute, I am blushing (*/ω＼*)", "Ehem! I love the furry po-! I mean.. the uh community!", "You're such a pervert for filling me up with your seman Senpai~~", "But i'm just an another furry to the community :(", "M-Master does it feel good when I slide my smoll hand up and down on your cute manly part?", "I-I need somewhere to blow my load. Can i borrow your bussy?", "Please! s-stop it.. I'm feeling sooo good..~ hmpf! Fuck me harder Daddyh~", "W-Why is it that lately... Y-You haven't been playing with my ass!!?", "Fill my throat bwussy with your semen kun", "Is there reason to be mad? Of course when u die to an femboy!", "Hey, who wants a piece of this plump 19-year-old boy-bussy? Single file, boys, come get it while it's hot!", "U-uwu! I can also whimp for you..", "M-My bussy is overflowing with your semen M-Master", "When do you wanna meet up again? I've really taken a liking to your dick! (,,◠∇◠) I want you and only you to slam it into my buwssy every day! (≧∇≦)", "Y-You got me all wet now Senpai!", "Lets take this swimsuit off already <3 i'll drink your unknown melty juice", "Boykisser is such a cute femboy ahh~~ f-fuck... ⊙.☉", "Fill up my bussy with your semen kun ^-^" }

local builder = { misses = 0, invert_defensive = false, old_defensive = false, invert_delay = true, target_delay = 0, legbreak = 0, current_pitch = -89, current_yaw = -60, goal_pitch = 0, goal_yaw = 0, speed = 0, save_yaw = 0, misses = 0, warmup = game_rules_get_prop("m_bWarmupPeriod"), onpeek = false, afk_valid = false, afk = 0 }
local indicator = { font = render_get_default_font(), shot_count = 0, data = {}, pos = vec2_t(100, 100), size = vec2_t(200, 100), difference = vec2_t(0, 0), dragging = false }
local console_material = { "vgui_white", "vgui/hud/800corner1", "vgui/hud/800corner2", "vgui/hud/800corner3", "vgui/hud/800corner4" }
local esp = { sync_user = {}, unsync_user = {}, sync_update = 0 }
local resolver = { data = {}, mem = {}, previous = {}, misses = {}, trust = { fs = 0, jitter = 0 }, shots = {}, epoch = 0, stats = {} }
local delay = { tick_delay = client_time_to_ticks(1), last_tick = globals.tick_count() }
local animation = { alpha = 0, appearing = 0 }
local toss = { target_angles = vec3_t(0, 0, 0) }
local knife = { countdown = 0 }
local notifications = { types = { success = "success", warning = "warn", failure = "fail", information = "info" }, logs = {}, delay = 3.5 }
local logs = { logs = {}, font = arial_font, neutral_color = color_t(230, 230, 230, 255), background_color = color_t(0, 0, 0, 100) }
local edgeyaw = { pos = vec3_t(0, 0, 0), angle = angle_t(0, 0, 0), vec_trace_start = vec3_t(0, 0, 0), enabled = false }
local hit_groups = { [0] = "generic", [1] = "head", [2] = "pelvis", [3] = "stomach", [4] = "lower chest", [5] = "chest", [6] = "upper chest", [7] = "right thigh", [8] = "left thigh", [9] = "right calf", [10] = "left calf", [11] = "right foot", [12] = "left foot", [13] = "right hand", [14] = "left hand", [15] = "right upper arm", [16] = "right forearm", [17] = "left upper arm", [18] = "left forear" }
local colors = { ["hit"] = color_t(0, 255, 0), ["occlusion"] = color_t(146, 0, 255), ["extrapolation"] = color_t(221, 95, 151), ["resolver"] = color_t(250, 111, 166), ["spread"] = color_t(131, 111, 255), ["spread (missed safe)"] = color_t(64, 155, 246), ["prediction error"] = color_t(209, 121, 121), ["jitter"] = color_t(128, 132, 231), ["server rejection"] = color_t(122, 93, 194), ["ping (local death)"] = color_t(161, 111, 255), ["ping (target death)"] = color_t(237, 125, 149), ["dormant aimbot"] = color_t(222, 153, 163), ["backtrack failure"] = color_t(48, 123, 171), ["out of reach"] = color_t(51, 255, 165), ["unknown"] = color_t(244, 155, 131) }

local groups = {
    nav = libs.eui.create("Home | Specter v" .. client_version .. "" .. info.beta_text2 , 1),
    
    
    configs = libs.eui.create("Configs", 2),
    cloud_configs = libs.eui.create("Cloud configs", 3),


    statistics = libs.eui.create("Statistics", 2),

    servers = libs.eui.create("Servers", 2),
    

    ragebot = libs.eui.create("Ragebot", 3),
    tickbase = libs.eui.create("Tickbase", 3),
    
    resolver = libs.eui.create("Resolver", 3),
    resolver_beta = libs.eui.create("Resolver (beta)", 2),

    reso_cfg = libs.eui.create("Configuration (beta)", 2),


    settings = libs.eui.create("Settings", 1),

    yaw = libs.eui.create("Yaw", 2),
    jitter = libs.eui.create("Jitter", 2),
    desync = libs.eui.create("Desync", 2),

    antiaim = libs.eui.create("Global", 3),

    features = libs.eui.create("Features", 3),
    defensive = libs.eui.create("Defensive", 1),

    
    exploits = libs.eui.create("Exploits", 2),
    helpers = libs.eui.create("Helpers", 3),
    
    visuals = libs.eui.create("Visuals", 2),
    customization = libs.eui.create("Customization", 3),
    
    player = libs.eui.create("Player", 2),
    communication = libs.eui.create("Communication", 3),
    

    misc = libs.eui.create("Misc", 2),
    movement = libs.eui.create("Movement", 3),


    utils = libs.eui.create("Utils", 2),
    sync = libs.eui.create("Synchronization", 3)
}

for i = 1, 64, 1 do
    side[i] = 1
    desync[i] = 0
    anim[i] = 0
    should_change_side[i] = 0
    player_pose[i] = 0
end

--- @endregion

--- @info: ui management
--- @region: menu style(s)

local states = {"Global", "Stand", "Move", "Slow walk", "Duck", "Duck move", "Air", "Air duck", "Fakelag", "Manual", "Freestand"}
local shortstates = {"G", "S", "M", "SW", "D", "DM", "A", "AD", "F", "MN", "FR"}

local refs = {
    hide_shots = menu_find("aimbot", "general", "exploits", "hideshots", "enable")[2],
    double_tap = menu_find("aimbot", "general", "exploits", "doubletap", "enable")[2],

    quick_peek = menu_find("aimbot", "general", "misc", "autopeek")[2],
    slow_motion = menu_find("misc","main","movement", "slow walk", "enable")[2],

    force_damage = menu_find("aimbot", get_active_weapon(), "target overrides", "min. damage")[2],
    force_safe = menu_find("aimbot", get_active_weapon(), "target overrides", "safepoint")[2],

    force_hb = menu_find("aimbot", get_active_weapon(), "target overrides", "hitbox")[2],
    force_hc = menu_find("aimbot", get_active_weapon(), "target overrides", "hitchance")[2],
    force_baim = menu_find("aimbot", get_active_weapon(), "target overrides", "body lean safepoint")[2],

    pitch = menu_find("antiaim","main", "angles","pitch"),
    yawbase = menu_find("antiaim","main", "angles","yaw base"),
    yawadd = menu_find("antiaim","main", "angles","yaw add"),
    rotate = menu_find("antiaim","main", "angles", "rotate"),
    rotaterange = menu_find("antiaim","main", "angles", "rotate range"),
    rotatespeed = menu_find("antiaim","main", "angles", "rotate speed"),
    jittermode = menu_find("antiaim","main", "angles","jitter mode"),
    jittertype = menu_find("antiaim","main", "angles","jitter type"),
    jitterrange = menu_find("antiaim","main", "angles","jitter add"),

    ping = menu_find("aimbot", "general", "fake ping", "enable")[2],
    antibackstab = menu_find("antiaim","main", "general","anti knife"),

    fake_lag_value = menu_find("antiaim", "main", "fakelag", "amount"),
    fake_duck = menu_find("antiaim", "main", "general", "fakeduck")[2],
    
    overridemove = menu_find("antiaim","main", "desync", "override stand#move"),
    overridemovesw = menu_find("antiaim","main", "desync", "override stand#slow walk"),
    desyncside = menu_find("antiaim","main", "desync", "stand", "side"),
    leftamount = menu_find("antiaim","main", "desync", "left amount"),
    rightamount = menu_find("antiaim","main", "desync", "right amount"),

    left = menu_find("antiaim", "main", "manual", "left")[2],
    right = menu_find("antiaim", "main", "manual", "right")[2],
    back = menu_find("antiaim", "main", "manual", "back")[2],
    freestand = menu_find("antiaim", "main", "auto direction", "enable")[2],
    fsstate = menu_find("antiaim","main", "auto direction", "states"),
}

local defensive = {
    db = {},
    is_active = function(self, player, safe, mode)
        local idx = player:get_index()
        
        local tickcount = globals.tick_count()
        local sim_time = client_time_to_ticks(player:get_prop("m_flSimulationTime"))

        if (not mode) then
            mode = false
        end

        self.db[idx] = self.db[idx] and self.db[idx] or {
            last_sim_time = 0,
            defensive_until = 0
        }

        if (self.db[idx].last_sim_time == 0) then
            self.db[idx].last_sim_time = sim_time
            return false
        end

        local sim_diff = sim_time - self.db[idx].last_sim_time
        if (sim_diff < 0) then
            self.db[idx].defensive_until = tickcount + math.abs(sim_diff)
            if (safe) then
                self.db[idx].defensive_until = self.db[idx].defensive_until - client_time_to_ticks(engine_get_latency())
            end
        end

        self.db[idx].last_sim_time = sim_time
        local ret = {
            tick = self.db[idx].defensive_until,
            active = self.db[idx].defensive_until > tickcount
        }
        return mode and ret or self.db[idx].defensive_until > tickcount
    end,

    -- the shift empties the double tap, and the next one came as soon as it was charged again while the enemy was still in view: we
    -- never had a shot (owners: "csak hátráltat"). So after a shift the next one waits (DEF_COOL ticks), unless we are being shot at
    -- (urgent) and never on the tick we shoot ourselves
    DEF_COOL = 38,
    cool_until = 0,
    trigger = function(self, urgent, shooting)
        if (shooting == true) then return end
        local tick = globals.tick_count()
        if (not urgent and tick < self.cool_until) then return end
        if (refs.double_tap:get() and (exploits_get_charge() == exploits_get_max_charge())) then
            exploits.force_anti_exploit_shift()
            self.cool_until = tick + self.DEF_COOL
        end
    end
}

local ui = {
    nav = {
        slider = groups.nav:slider("Specter | tee hee!<3", 0, 15),

        text = groups.nav:text("Welcome, " .. info.user .. "!"),
        sep0 = menu_add_separator("Home | Specter v" .. client_version .. "" .. info.beta_text2),
        
        shared_esp = groups.nav:list("Specter Revealer", {}),
        restart_esp = groups.nav:button("Restart esp",
            function()
                on_shared_esp(true)
            end
        ),

        refresh_players = groups.nav:button("Refresh players",
            function()
                on_shared_players(true)
            end
        ),
        -- the first scoreboard row as text in the console (open the scoreboard first): the ids / types the badge looks for the country flag in
        dump_scoreboard = groups.nav:button("Dump scoreboard row",
            function()
                local ok, text = pcall(libs.tools.js.dump)
                for line in tostring(ok and text or "unable to read the scoreboard"):gmatch("[^\n]+") do
                    print(line)
                end
            end
        ),
        sep1 = menu_add_separator("Home | Specter v" .. client_version .. "" .. info.beta_text2),
    },

    configs = {
        cloud_list = groups.cloud_configs:list("Configs list", {}, 7),
        list = groups.configs:list("Configs list", {}, 7),

        config_name = groups.configs:text_input("Name to create")
    },

    statistics = {
        list = groups.statistics:list("Your personal statistics", {})
    },

    -- raw menu items, not eui ones: eui exports every checkbox into the configs, and an imported (cloud) config must never
    -- switch "Share my server" on. Off at every start.
    servers = {
        share = menu_add_checkbox("Servers", "Share my server", false),
        list = menu_add_list("Servers", "Specter users on servers", {}, 8),
        connect = menu_add_button("Servers", "Connect to the selected", function() servers.connect() end),
        refresh = menu_add_button("Servers", "Refresh the list", function() servers.update(true) end),
    },

    ragebot = {
        logic_reso = groups.resolver:checkbox("Logic resolver"),
        nexzu_reso = groups.resolver:checkbox("Improve resolver"),
        smart_baim = groups.resolver:checkbox("Smart body aim", true),
        smart_baim_hp = groups.resolver:slider("Body aim below HP", 0, 100, 1, 0, "hp"),
        smart_baim_lethal = groups.resolver:checkbox("Body aim if lethal on risky target", true),
        latency_guard = groups.resolver:checkbox("High ping protection", true),
        latency_limit = groups.resolver:slider("High ping threshold", 40, 250, 1, 0, "ms"),
        fast_peek = groups.resolver:checkbox("Fast crouch / peek scan", true),
        pose_reso = groups.resolver_beta:checkbox("Pose resolver"),
        resolver = {
            enable_resolver = groups.resolver_beta:checkbox("Custom resolver"),
            
            duck_mode = groups.resolver_beta:checkbox("Duck mode"),
            auto_duck = groups.resolver_beta:checkbox("Auto duck", true),
            
            safe_peek = groups.resolver_beta:checkbox("Safe peek", true),
            
            pred_sel = groups.resolver_beta:slider("Prediction sel", 2, 70, 1, 0, "%"),
            calc_box = groups.resolver_beta:slider("Calculate box", 2, 35, 1, 0, "u"),
            shot_pred = groups.resolver_beta:slider("Shot prediction", 2, 65, 1, 0, "°"),

            safe_mode = groups.resolver_beta:slider("Safe mode", 1, 20, 1, 0, "hp")
        },

        reso_cfg = {
            yaw_calc = groups.reso_cfg:selection(
                "Yaw calculation",
                {
                    "Simple",
                    "Advanced",
                    "Experimental"
                }
            ),

            disablers = groups.reso_cfg:multi_selection(
                "Disablers",
                {
                    "In air",
                    "In airduck",
                    "At duck",
                    "At peek",
                    "At scope",
                    "At noscope",
                    "With doubletap",
                    "With hideshots",
                    "Low fps (<75fps)",
                    "High ping (>80ms)"
                }
            ),

            at_disabler = groups.reso_cfg:selection(
                "At disabler",
                {
                    "Disable",
                    "Safe point",
                    "Keep resolving"
                }
            ),
        },

        backtrack = {
            enable_backtrack = groups.tickbase:checkbox("Improve backtrack"),
            extended_backtrack = groups.tickbase:checkbox("Extended backtrack"),
            prediction = groups.tickbase:checkbox("Advanced prediction", true),
        },

        safe_defensive = groups.ragebot:checkbox("Defensive safepoint"),
        multipoint_pred = groups.ragebot:checkbox("Multipoint correction"),

        accuracy_boost = {
            enable_booster = groups.ragebot:checkbox("Accuracy booster"),
            booster_mode = groups.ragebot:selection("Booster mode", {"Minimum", "Maximum"}),
        }
    },

    antiaim = {
        builder = {
            enable = groups.settings:checkbox("Custom antiaim"),
            edge_yaw = groups.settings:checkbox("Edge yaw"),
            random_side = groups.settings:checkbox("Random desync side", true),
            anti_brute = groups.settings:checkbox("Anti bruteforce", true),

            pitch = groups.antiaim:selection(
                "Pitch",
                {
                    "Off",
                    "Down",
                    "Up",
                    "Zero",
                    "Jitter"
                }
            ),

            yaw = groups.antiaim:selection(
                "Base",
                {
                    "Local view",
                    "At targets",
                    "Distance"
                }
            ),

            condition = groups.settings:selection("Condition", states, #states),
            defensive_ping = groups.antiaim:selection(
                "Defensive mode",
                {
                    "Ping safe",
                    "Unsafe"
                }
            )
        },

        features = {
            antibackstab = groups.features:checkbox("Anti backstab"),
            fakelag = groups.features:checkbox("Avoid onshot"),
            safehead = groups.features:multi_selection(
                "Safe head",
                {
                    "Air knife",
                    "Allow defensive",
                    "Air zeus",
                    "Height advantage"
                }
            ),

            warmup = groups.features:multi_selection(
                "Randomization",
                {
                    "No enemies alive",
                    "Warmup"
                }
            ),

            correction = groups.features:multi_selection(
                "Crouch correction",
                {
                    "Yaw"
                }
            )
        }
    },

    exploits = {
        quick_fall = groups.helpers:checkbox("Rubberbang"),
        lag_on_shoot = groups.helpers:checkbox("Lag on shoot"),
        fix_corr = groups.helpers:checkbox("Fix correction"),

        safe_recharge = groups.exploits:checkbox("Safe recharge"),
        better_hs = groups.exploits:checkbox("Better hideshots"),
        fix_dt = groups.exploits:checkbox("Optimize doubletap"),
        
        better_dt = {
            better_dt = groups.exploits:checkbox("Improve doubletap"),
            dt_mode = groups.exploits:selection(
                "Mode",
                {
                    "Dynamic",
                    "Custom"
                }
            ),
            
            speed_calc = groups.exploits:selection(
                "Speed calculation",
                {
                    "Static",
                    "Switch",
                    "Automatic"
                }
            ),
            dt_speed = groups.exploits:slider("DT Speed", 5, 17)
        }
    },

    visuals = {
        china_hat = {
            enable_hat = groups.visuals:checkbox("China hat"),
            hat_mode = groups.customization:selection(
                "Hat mode",
                {
                    "Regular",
                    "Rainbow"
                }
            ),
        },

        console = groups.visuals:checkbox("Console color", true),

        tesla = {
            enable_tesla = groups.visuals:checkbox("Tesla on shoot"),

            width = groups.customization:slider("Tesla · width", 0, 30),
            radius = groups.customization:slider("Tesla · radius", 0, 1000),
            beams = groups.customization:slider("Tesla · beams", 0, 100),
            delay = groups.customization:slider("Tesla · delay", 0, 5),
        },

        gs_indc = {
            indicators = groups.visuals:multi_selection(
                "Right indicators",
                {
                    "Double tap",
                    "Hide shots",
                    "Minimum dmg",
                    "Quick peek",
                    "Freestand",
                    "Ping spike",
                    "Force bodyaim",
                    "Force safepoint",
                    "Override hitbox",
                    "Override hitchance"
                },
            10)
        },

        crosshair_indc = {
            binds = groups.visuals:multi_selection(
                "Crosshair indicators",
                {
                    "Double tap",
                    "Hide shots",
                    "Minimum dmg",
                    "Quick peek",
                    "Freestand",
                    "Ping spike",
                    "Force bodyaim",
                    "Force safepoint",
                    "Override hitbox",
                    "Override hitchance"
                },
            10)
        },
        esp_fonts = groups.visuals:selection("ESP Font", espfonts, #espfonts),
    },

    player = {
        talk_back = groups.communication:checkbox("Talk back"),
        trash_talk = groups.communication:selection(
            "Trash talk",
            {
                "Off",
                
                "Skeet",
                "Femboy",
                "Original",
                "Roast"
            }
        ),

        voice_state = groups.communication:selection(
            "Voice state",
            {
                "Disable",
                
                "Mute players",
                "Unmute players"
            }
        ),

        visual_rec = groups.player:checkbox("Visual recoil"),

        anim_breaker = groups.player:checkbox("Animation breaker"),
        team_anim = groups.player:checkbox("Cool team animation"),

        super_toss = groups.player:selection(
            "Super toss",
            {
                "Off",
                
                "Legit",
                "Smart"
            }
        ),

        fast_ladder = groups.player:multi_selection(
            "Fast ladder",
            {
                "Up",
                "Down"
            }
        ),
    },

    misc = {
        fast_switch = groups.misc:checkbox("Fast weapon switch"),
        unlock_pingspike = groups.misc:checkbox("Unlock latency"),
        knifebot_helper = groups.misc:checkbox("Knifebot helper"),
        zeus_rush = groups.misc:checkbox("Zeus vs rushers"),
        zeus_dt = groups.misc:checkbox("Disable DT with zeus"),
        defuse_bot = groups.misc:checkbox("Auto defuse"),
        
        fake_media = {
            enable_fakemedia = groups.misc:checkbox("Fake media"),
            type = groups.misc:multi_selection(
                "Fake type",
                {
                    "Headshot",
                    "Wallbang",
                    "No Scope",
                    "Flashed",
                    "Thru smoke",
                    "Dominated",
                    "Revenge",
                },
            7),
        },
        
        jumpshot = groups.movement:checkbox("Jumpshot helper"),
        nofall_dmg = groups.movement:checkbox("No fall damage"),
        antiafk = groups.movement:checkbox("Anti afk")
    },

    utils = {
        keybinds = groups.utils:checkbox("Keybinds"),
        spectators = groups.utils:checkbox("Spectators"),
        watermark = groups.utils:checkbox("Watermark", true),
        watermark_style = groups.utils:selection("Watermark style", {"Specter", "Split", "Glass", "Neon"}),
        watermark_fields = groups.utils:multi_selection("Watermark info", {"Username", "FPS", "Ping", "Tickrate", "Time", "Icons"}),
        keybinds_style = groups.utils:selection("Keybinds style", {"Pills icons", "Pills classic"}),
        keybinds_mode = groups.utils:checkbox("Show bind mode", true),
        menu_glow = groups.utils:checkbox("Glow effects", false),

        clantag = groups.sync:checkbox("Clan tag", true),
        shared_esp = groups.sync:checkbox("Shared ESP", true),

        synced_players = groups.sync:multi_selection(
            "Synced players",
            {
                "Disable trash-talk",
                "Ignore talk-back",
                "Chat mentions",
            },
        3),

        event_logs = groups.utils:multi_selection(
            "Logs selection",
            {
                "Show stats",
                "Hits",
                "Purchases",
                "Hurts",
                "Misses",
                "Evades"
            }
        ),

        reset_stats = groups.utils:button("Reset stats",
            function()
                notifications.create("Specter", "Statistics have been reset!", notifications.types.success)
                print("statistics have been reset.")

                indicator.shot_count = 0
                indicator.data = {}
            end
        )
    }
}
-- EUI slider arguments specify step size, not a default value.
-- Initialize before saved configurations are imported.
ui.ragebot.smart_baim_hp.ref:set(40)
ui.ragebot.latency_limit.ref:set(80)
ui.antiaim.builder.ab_mode = groups.settings:selection("Anti brute mode", {"Shift", "Phases"})
ui.antiaim.builder.direct = groups.settings:checkbox("Direct control (dev)", true)
ui.antiaim.builder.adaptive = groups.settings:checkbox("Adaptive AA", false)
ui.utils.aa_stats = groups.utils:checkbox("AA stats", true)
ui.utils.aa_stats_reset = groups.utils:button("Reset AA stats", function()
    builder.aa_stats = {}
    notifications.create("Specter", "Anti-aim stats have been reset!", notifications.types.success)
end)
ui.utils.res_stats = groups.utils:checkbox("Resolver stats", true)
ui.utils.res_stats_reset = groups.utils:button("Reset resolver stats", function()
    resolver.stats = {}
    notifications.create("Specter", "Resolver stats have been reset!", notifications.types.success)
end)
ui.utils.res_stats_print = groups.utils:button("Resolver stats to console", function()
    local lines = resolver.stat_lines()
    print("resolver stats per state:")
    for _, line in ipairs(lines) do print(line) end
    if (#lines == 0) then print("no shots yet") end
end)
ui.utils.profile = groups.utils:button("Profile 10 s (dev)", function()
    perf.start()
end)
ui.antiaim.features.fl_variance = groups.features:checkbox("Fakelag variance")
ui.antiaim.builder.preset = groups.settings:button("Apply advanced preset", function()
    builder.apply_preset()
end)

for i = 1, #states do
    ui.antiaim.builder[i] = {
        override = groups.yaw:checkbox("Override - " .. states[i]),
        yaw_mode = groups.yaw:selection(shortstates[i] .. " | Yaw mode", {"Static", "Classic", "Advanced", "X-Way", "Distort", "Random hold"}),
        yaw_val = groups.yaw:slider(shortstates[i] .. " | Yaw", -90, 90, 1, 0, "°"),
        
        yaw_left = groups.yaw:slider(shortstates[i] .. " | Left", -90, 90, 1, 0, "°"),
        yaw_right = groups.yaw:slider(shortstates[i] .. " | Right", -90, 90, 1, 0, "°"),
        
        yaw_meta_left = groups.yaw:slider(shortstates[i] .. " | Left randomization", -90, 90, 1, 0, "°"),
        yaw_meta_right = groups.yaw:slider(shortstates[i] .. " | Right randomization", -90, 90, 1, 0, "°"),
        
        yaw_delay = groups.yaw:slider(shortstates[i] .. " | Delay", 2, 32, 1, 0, "t"),
        meta_delay = groups.yaw:slider(shortstates[i] .. " | Delay fluctuation", 0, 16, 1, 0, "t"),

        -- the advanced modes (X-Way / Distort / Random hold): "Yaw" above is their centre
        yaw_ways = groups.yaw:slider(shortstates[i] .. " | Ways", 3, 7, 1, 0, ""),
        yaw_range = groups.yaw:slider(shortstates[i] .. " | Range", 0, 90, 1, 0, "°"),
        yaw_hold = groups.yaw:slider(shortstates[i] .. " | Hold", 1, 8, 1, 0, "p"),
        sway_speed = groups.yaw:slider(shortstates[i] .. " | Sway speed", 1, 100, 1, 0, "%"),
        snap_chance = groups.yaw:slider(shortstates[i] .. " | Snap chance", 0, 50, 1, 0, "%"),

        yaw_modifier = groups.jitter:selection(shortstates[i] .. " | Modifier mode", {"None", "Offset", "Center", "3Way", "5Way", "Random", "Switch random"}),
        
        modifier_degree = groups.jitter:slider(shortstates[i] .. " | Modifier degree", -180, 180, 1, 0, "°"),
        modifier_random = groups.jitter:slider(shortstates[i] .. " | Modifier randomization", -180, 180, 1, 0, "°"),
        
        desync = groups.desync:selection(shortstates[i] .. " | Desync", {"Left", "Right", "Jitter", "Peek fake", "Random"}),
        
        desync_left = groups.desync:slider(shortstates[i] .. " | Fake left", 0, 60, 1, 0, "°"),
        desync_right = groups.desync:slider(shortstates[i] .. " | Fake right", 0, 60, 1, 0, "°"),
        
        desync_meta_left = groups.desync:slider(shortstates[i] .. " | Left randomization", -60, 60, 1, 0, "°"),
        desync_meta_right = groups.desync:slider(shortstates[i] .. " | Right randomization", -60, 60, 1, 0, "°"),
        
        trigger_defensive = groups.defensive:selection(shortstates[i] .. " | Defensive", {"Off", "On peek", "Force", "Antiaim", "Dynamic", "Smart"}),
        smart_triggers = groups.defensive:multi_selection(shortstates[i] .. " | Smart triggers", {"Peek", "Shot at", "Air", "Threat aim", "Random"}),
        defensive_pitch = groups.defensive:selection(shortstates[i] .. " | Defensive pitch", {"Inherit", "Off", "Down", "Up", "Zero", "Jitter", "Random", "Custom", "Switch", "Clock", "Random up/down", "Sway"}),
        
        defensive_pitch_val = groups.defensive:slider(shortstates[i] .. " | Pitch value (1)", -90, 90, 1, 0, "°"),
        defensive_pitch_val2 = groups.defensive:slider(shortstates[i] .. " | Pitch value (2)", -90, 90, 1, 0, "°"),
        
        defensive_yaw = groups.defensive:selection(shortstates[i] .. " | Defensive yaw", {"Inherit", "Static", "Sideways", "Switch", "Spin", "Random", "5Way", "Clock", "Opposite", "Random side", "Jitter flick", "Distort"}),
        defensive_yaw_val = groups.defensive:slider(shortstates[i] .. " | Yaw value", -180, 180, 1, 0, "°"),
        
        defensive_speed = groups.defensive:slider(shortstates[i] .. " | Spin speed", 0, 100, 1, 0, "%"),
        defensive_range = groups.defensive:slider(shortstates[i] .. " | Spin range", 0, 360, 1, 0, "°")
    }
end

local global = {
    velocity = 0,
    
    current_state = "",
    current_state_number = 0,
    
    update = function(self, cmd)
        local local_player = entity_list_get_local_player()
        if (local_player) then
            local velocity = math.vec_length2d(local_player:get_prop('m_vecVelocity'))
            local flags = local_player:get_prop('m_fFlags')
            
            local ducking = bit.lshift(1, 1)
            local ground = bit.lshift(1, 0)

            self.velocity = velocity
            local state = function()
                if (bit.band(flags, ground) == 1 and velocity > 3 and bit.band(flags, ducking) == 0 and not refs.slow_motion:get() and not cmd:has_button(e_cmd_buttons.JUMP)) then
                    self.current_state = "move"
                    self.current_state_number = 3
                elseif (bit.band(flags, ground) == 0 and bit.band(flags, ducking) == 0) then
                    self.current_state = "air"
                    self.current_state_number = 7
                elseif (bit.band(flags, ground) == 0 and bit.band(flags, ducking) > 0.9) then
                    self.current_state = "air duck"
                    self.current_state_number = 8
                elseif (bit.band(flags, ground) == 1 and velocity < 3 and bit.band(flags, ducking) == 0) then
                    self.current_state = "stand"
                    self.current_state_number = 2
                else
                    if (bit.band(flags, ground) == 1 and velocity > 3 and bit.band(flags, ducking) == 0 and refs.slow_motion:get()) then
                        self.current_state = "slow motion"
                        self.current_state_number = 4
                    end
                end

                if (bit.band(flags, ground) == 1 and bit.band(flags, ducking) > 0.9 and ui.antiaim.builder[6].override:get() and velocity > 10 and not cmd:has_button(e_cmd_buttons.JUMP)) then
                    self.current_state = "duck move"
                    self.current_state_number = 6
                elseif (bit.band(flags, ground) == 1 and bit.band(flags, ducking) > 0.9 and not cmd:has_button(e_cmd_buttons.JUMP)) then
                    self.current_state = "duck"
                    self.current_state_number = 5
                end

                if (not (refs.double_tap:get() or refs.hide_shots:get()) and ui.antiaim.builder[9].override:get()) then
                    self.current_state = "fakelag"
                    self.current_state_number = 9
                end

                if (refs.freestand:get() and ui.antiaim.builder[11].override:get()) then 
                    self.current_state = "freestand"
                    self.current_state_number = 11
                end

                -- manual left / right (Primordial's manual keys): the "manual" here was an undefined global, the state
                -- never came
                if (refs.left:get() or refs.right:get()) then 
                    self.current_state = "manual"
                    self.current_state_number = 10
                end
            end
            state()
        end
    end
}

local accent_color = color_t(222, 153, 185, 255)
local text_color = color_t(140, 71, 247, 255)

ui.quick_fall = groups.exploits:keybind(ui.exploits.quick_fall, "Rubberbang keybind")
ui.edge_yaw = groups.antiaim:keybind(ui.antiaim.builder.edge_yaw, "EdgeYaw keybind")

ui.accent_color = groups.nav:color_picker(ui.nav.text, "Accent color", accent_color)
ui.text_color = groups.nav:color_picker(ui.nav.text, "Text color", text_color)
for _, field in ipairs({"Username", "FPS", "Ping", "Time", "Icons"}) do
    ui.utils.watermark_fields.ref:set(field, true)
end

ui.console_color = groups.utils:color_picker(ui.visuals.console, "Console color", color_t(55, 55, 55, 154))
ui.tesla_color = groups.utils:color_picker(ui.visuals.tesla.enable_tesla, "Tesla color", color_t(255, 255, 255, 255))

ui.gs_color1 = groups.utils:color_picker(ui.visuals.gs_indc.indicators, "Main color", color_t(177, 255, 87, 255))
ui.gs_color2 = groups.utils:color_picker(ui.visuals.gs_indc.indicators, "Alt color", color_t(200, 199, 197, 255))

ui.hat_color = groups.visuals:color_picker(ui.visuals.china_hat.enable_hat, "Hat color", color_t(89, 237, 255, 255))

get_indc_color = function()
    local r, g, b = ui.gs_color1:get().r, ui.gs_color1:get().g, ui.gs_color1:get().b
    return color_t(r, g, b)
end

get_hat_color = function()
    local r, g, b = ui.hat_color:get().r, ui.hat_color:get().g, ui.hat_color:get().b
    return color_t(r, g, b)
end

get_accent_color = function()
    local r, g, b = ui.accent_color:get().r, ui.accent_color:get().g, ui.accent_color:get().b
    return specter_color_t(r, g, b)
end

get_text_color = function()
    local r, g, b = ui.text_color:get().r, ui.text_color:get().g, ui.text_color:get().b
    return specter_color_t(r, g, b)
end

-- menu (owners, Oct 2026): four main points, under them the pages of the active one; the page is ui.nav.slider (0 = home)
local nav_pages = {
    { name = "Config", subs = { { "Configs", 1 }, { "Statistics", 2 } } },
    { name = "Ragebot", subs = { { "Resolver", 3 }, { "Aimbot", 10 }, { "Tickbase", 11 }, { "Exploits", 5 } } },
    { name = "Anti-Aim", subs = { { "Builder", 4 }, { "Yaw / Jitter", 12 }, { "Desync", 13 }, { "Defensive", 14 } } },
    { name = "Misc", subs = { { "Visuals", 6 }, { "Player", 7 }, { "Movement", 8 }, { "Utils", 9 }, { "Servers", 15 } } },
}
if (info.plan == "beta") then
    table.remove(nav_pages[2].subs, 1)
end
local nav_main_of = {}
ui.nav.mains = {}
ui.nav.subs = {}

for i, main in ipairs(nav_pages) do
    ui.nav.mains[i] = groups.nav:button(main.name,
        function()
            ui.nav.slider.ref:set(main.subs[1][2])
        end
    )
end

ui.nav.sep2 = menu_add_separator("Home | Specter v" .. client_version .. "" .. info.beta_text2)

for i, main in ipairs(nav_pages) do
    for _, page in ipairs(main.subs) do
        nav_main_of[page[2]] = i
        table.insert(ui.nav.subs, { main = i, button = groups.nav:button("› " .. page[1],
            function()
                ui.nav.slider.ref:set(page[2])
            end
        ) })
    end
end

--- @endregion

--- @info: advanced print
--- @region: print

print = function(...)
    local args = {...}
    local output = {}

    local header_color = ui.accent_color:get()
    local text_color = color_t(168, 168, 168, 255)
    local reset_color = color_t(255, 255, 255, 255)

    local rainbow_colors = {
        color_t(255, 113, 237, 255),
        color_t(247, 120, 243, 255),
        color_t(239, 126, 249, 255),
        color_t(230, 132, 254, 255),
        color_t(222, 138, 255, 255),
        color_t(213, 143, 255, 255),
        color_t(204, 148, 255, 255),
        color_t(196, 153, 255, 255),
        color_t(187, 157, 255, 255),
        color_t(179, 162, 255, 255),
        color_t(171, 165, 255, 255),
        color_t(163, 169, 255, 255),
        color_t(156, 172, 255, 255),
        color_t(150, 176, 255, 255),
        color_t(144, 178, 255, 255),
        color_t(138, 181, 255, 255),
        color_t(134, 184, 255, 255),
        color_t(131, 186, 255, 255),
        color_t(128, 188, 255, 255),
        color_t(127, 190, 255, 255),

        color_t(255, 0, 0, 255),
        color_t(255, 0, 12, 255),
        color_t(255, 0, 21, 255),
        color_t(255, 0, 29, 255),
        color_t(255, 0, 36, 255),
        color_t(255, 0, 42, 255),
        color_t(255, 0, 48, 255),
        color_t(255, 0, 54, 255),
        color_t(255, 0, 60, 255),
        color_t(255, 0, 66, 255),
        color_t(255, 0, 71, 255),
        color_t(255, 0, 77, 255),
        color_t(255, 0, 83, 255),
        color_t(255, 0, 89, 255),
        color_t(255, 0, 95, 255),
        color_t(255, 0, 101, 255),
        color_t(255, 0, 107, 255),
        color_t(255, 0, 113, 255),
        color_t(255, 0, 119, 255),
        color_t(255, 0, 125, 255),

        color_t(255, 0, 0, 255),
        color_t(255, 64, 0, 255),
        color_t(255, 128, 0, 255),
        color_t(255, 191, 0, 255),
        color_t(255, 255, 0, 255),
        color_t(191, 255, 0, 255),
        color_t(128, 255, 0, 255),
        color_t(64, 255, 0, 255),
        color_t(0, 255, 0, 255),
        color_t(0, 255, 64, 255),
        color_t(0, 255, 128, 255),
        color_t(0, 255, 191, 255),
        color_t(0, 255, 255, 255),
        color_t(0, 191, 255, 255),
        color_t(0, 128, 255, 255),
        color_t(0, 64, 255, 255),
        color_t(0, 0, 255, 255),
        color_t(64, 0, 255, 255),
        color_t(128, 0, 255, 255),
        color_t(191, 0, 255, 255),

        color_t(168, 0, 255, 255),
        color_t(164, 6, 255, 255),
        color_t(159, 13, 255, 255),
        color_t(155, 19, 255, 255),
        color_t(151, 25, 255, 255),
        color_t(146, 32, 255, 255),
        color_t(142, 38, 255, 255),
        color_t(138, 44, 255, 255),
        color_t(134, 50, 255, 255),
        color_t(129, 57, 255, 255),
        color_t(125, 63, 255, 255),
        color_t(121, 69, 255, 255),
        color_t(116, 76, 255, 255),
        color_t(112, 82, 255, 255),
        color_t(108, 88, 255, 255),
        color_t(103, 95, 255, 255),
        color_t(99, 101, 255, 255),
        color_t(95, 107, 255, 255),
        color_t(90, 114, 255, 255)
    }

    table.insert(output, {header_color, "specter"})
    table.insert(output, {rainbow_colors[math.random(#rainbow_colors)], " · "})

    local current_color = text_color
    for _, value in ipairs(args) do
        if (type(value) == "table" and value.r and value.g and value.b and value.a) then
            current_color = value
        else
            table.insert(output, {current_color, tostring(value)})
        end
    end

    table.insert(output, {reset_color, "\n"})
    for _, pair in ipairs(output) do
        local color = pair[1]
        local text = pair[2] or ""

        color_print(color, text)
    end
end

specter_color_t = function(r, g, b, a)
    if (a == nil) then
        return {r = r, g = g, b = b, a = 255}
    else
        return {r = r, g = g, b = b, a = a}
    end
end

--- @endregion

--- @info: lua helpers
--- @region: useful thing(s)

-- configs funcs

configs.ffi = {}
configs.ffi.class_ptr = ffi.typeof("void***")
configs.ffi.rawvguisystem = memory_create_interface("vgui2.dll", "VGUI_System010") or error("specter · an internal error has occurred ~ 0xBE87F1")
configs.ffi.ivguisystem = ffi.cast(configs.ffi.class_ptr, configs.ffi.rawvguisystem) or error("specter · an internal error has occurred ~ 0x51D2A4")
configs.ffi.shell_execute = ffi.cast("shell_execute_t", configs.ffi.ivguisystem[0][3]) or error("specter · an internal error has occurred ~ 0x89E67C")

configs.ffi.__thiscall = function(func, this)
    return function(...)
        return func(this, ...)
    end
end

configs.ffi.vmt_bind = function(module, interface, index, typedef)
    local addr = ffi.cast("void***", memory_create_interface(module, interface)) or error("specter · an internal error has occurred ~ 0xFC4A7D")
    return configs.ffi.__thiscall(ffi.cast(typedef, addr[0][index]), addr)
end

configs.ffi.native_GetCurrentDirectory = configs.ffi.vmt_bind("filesystem_stdio.dll", "VFileSystem017", 40, "bool(__thiscall*)(void*, char*, int)")

configs.ffi.char = ffi.new("char[256]")
configs.ffi.native_GetCurrentDirectory(configs.ffi.char, ffi.sizeof(configs.ffi.char))

configs.path = string.format("%s/csgo/specter/", ffi.string(configs.ffi.char))

-- animstate funcs

local raw_entity_list = ffi.cast("void***", memory_create_interface("client.dll", "VClientEntityList003"))
local i_entity_list = ffi.cast("get_client_entity", raw_entity_list[0][3])

local entity_list_ptr = ffi.cast("void***", memory_create_interface("client.dll", "VClientEntityList003"))
local get_client_entity_fn = ffi.cast("get_client_entity", entity_list_ptr[0][3])

entity.get_vector_prop = function(idx, prop, array)
    local v1, v2, v3 = entity.get_prop(idx, prop, array)
    return {
        x = v1,
        y = v2,
        z = v3
    }
end

get_entity_pattern = function(Index)
    return i_entity_list(raw_entity_list, Index)
end

get_anim_layer = function(b, c)
    return ffi.cast("struct animation_layer_t**", ffi.cast("char*", ffi.cast(ffi.typeof('void***'), b)) + 0x2990)[0][c or 1]
end

entity.get_address = function(idx)
    return get_client_entity_fn(entity_list_ptr, idx)
end

entity.get_animlayer = function(idx)
    local addr = entity.get_address(idx)
    if (addr) then
        return ffi.cast("C_AnimationLayer**", ffi.cast("uintptr_t", addr) + 0x9960)[0]
    end
end

-- resolver funcs

get_side = function(playback_rate, ent)
    if (playback_rate ~= nil) then
        if (playback_rate > anim[ent]) then
            anim[ent] = playback_rate
            side[ent] = 2
        elseif (playback_rate < anim[ent]) then
            anim[ent] = playback_rate
            side[ent] = 1
        end
    end
end

normalize_yaw = function(yaw)
    if (yaw > 360) then
        return yaw - 360;
    elseif (yaw < 0) then
        return 360 + yaw
    end
    return yaw;
end

average = function(t)
    t = t or { }

    local sum = 0
    for _,v in pairs(t) do
        sum = sum + v
    end
    return sum / #t
end

normalize = function(value, min, max)
    return (value - min) / (max - min)
end

insert_first_index = function(tbl, value, maxSize)
    if (#tbl >= maxSize) then
        table.remove(tbl)
    end
    table.insert(tbl, 1, value)
end
    
rounded = function(number, decimal_places)
    local multiplier = 10 ^ (decimal_places or 0)
    return math.floor(number * multiplier + 0.5) / multiplier
end

-- utility funcs

vector_distance = function(src, dst)
    return math.sqrt((dst.x - src.x) ^ 2 + (dst.y - src.y) ^ 2 + (dst.z - src.z) ^ 2)
end

time_to_ticks = function(time)
    return math.floor(0.5 + (time / global_vars_interval_per_tick()))
end

get_state2 = function(player, speed)
    local flags = player:get_prop("m_fFlags")
    if (flags == 263) then
        return 6
    end

    if (flags == 256 or flags == 262) then
        return 4
    end

    if (flags ~= 263 and flags ~= 256 and flags ~= 262) then
        if (speed <= 3)  then
            return 2
        else
            if (speed > 3 and speed < 101) then
                return 7
            else
                return 3
            end
        end
    end
end

get_state = function(speed)
    local flags = entity_list_get_local_player():get_prop("m_fFlags")
    if (bit.band(flags, 1) == 1) then
        if (bit.band(flags, 4) == 4 or antiaim_is_fakeducking()) then
            return 4
        else
            if (speed <= 3) then
                return 1
            else
                if (menu_find("misc", "main", "movement", "slow walk")[2]) then
                    return 3
                else
                    return 2
                end
            end
        end
    elseif (bit.band(flags, 1) == 0) then
        if (bit.band(flags, 4) == 4) then
            return 6
        else
            return 5
        end
    end
end

check_conditions = function()
    if (engine_is_in_game() and entity_list_get_local_player() and entity_list_get_local_player():is_player() and entity_list_get_local_player() ~= nil) then
        return true
    else
        return false
    end
end

get_velocity = function()
    local local_player = entity_list_get_local_player()

    local velocity_x = local_player:get_prop("m_vecVelocity[0]")
    local velocity_y = local_player:get_prop("m_vecVelocity[1]")

    return math.floor(math.sqrt((velocity_x * velocity_x) + (velocity_y * velocity_y)))
end

get_dmg = function()
    local dmg_ovr = menu_find("aimbot", get_active_weapon(), "target overrides", "min. damage")[1]
    local dmg_ovr_key = menu_find("aimbot", get_active_weapon(), "target overrides", "min. damage")[2]
    local norm_dmg = menu_find("aimbot", get_active_weapon(), "targeting", "min. damage")

    return dmg_ovr_key:get() and dmg_ovr:get() or norm_dmg:get()
end

gradient = function(x, y, w, h, col1, col2)
    render_rect_fade(vec2_t(x, y - 4), vec2_t(w / 4, h), col2, col1, true)
    render_rect_fade(vec2_t(x + (w / 4), y - 4), vec2_t(w / 4, h), col1, col2, true)
end

is_point_visible = function(ent)
    if (entity_list_get_local_player():is_point_visible(ent:get_hitbox_pos(e_hitgroups.GENERIC))) then
        return true
    else
        return false
    end
end

distance = function(point1, point2)
    return math.sqrt((point2[1] - point1[1]) ^ 2 + (point2[2] - point1[2]) ^ 2)
end

ent_speed_2d = function(entity)
    local velocity_x = entity:get_prop("m_vecVelocity[0]")
    local velocity_y = entity:get_prop("m_vecVelocity[1]")
    
    return math.sqrt((velocity_x * velocity_x) + (velocity_y * velocity_y))
end

-- math funcs

math.clamp2 = function(value, min, max)
    return math.min(math.max(value, min), max)
end

math.clamp = function(v, min, max)
    if (min > max) then
        min, max = max, min
    end

    if (v > max) then
        return max
    end

    if (v < min) then
        return v
    end
    return v
end

math.vec_length2d = function(vec)
    root = 0.0
    sqst = vec.x * vec.x + vec.y * vec.y
    
    root = math.sqrt(sqst)
    return root
end

math.angle_diff = function(dest, src)
    local delta = 0.0
    
    delta = math.fmod(dest - src, 360.0)
    if (dest > src) then
        if (delta >= 180) then
            delta = delta - 360
        end
    else
        if (delta <= -180) then
            delta = delta + 360
        end
    end
    return delta
end

math.angle_normalize = function(angle)
    local ang = 0.0
    
    ang = math.fmod(angle, 360.0)
    if (ang < 0.0) then
        ang = ang + 360
    end
    return ang
end

math.anglemod = function(a)
    return (360 / 65536) * bit.band(math.floor(a * (65536 / 360.0), 65535))
end

math.approach_angle = function(target, value, speed)
    target = math.anglemod(target)
    value = math.anglemod(value)

    local delta = target - value
    if (speed < 0) then
        speed = -speed
    end

    if (delta < -180) then
        delta = delta + 360
    elseif (delta > 180) then
        delta = delta - 360
    end

    if (delta > speed) then
        value = value + speed
    elseif (delta < -speed) then
        value = value - speed
    else
        value = target
    end
    return value
end

math.yaw_to_player = function(player, forward)
    if (player) then
        local lp_origin = entity_list_get_local_player():get_render_origin()
        local pl_origin = player:get_render_origin()
    
        local yaw = (-math.atan2(pl_origin.x - lp_origin.x, pl_origin.y - lp_origin.y) / 3.14 * 180 + 180) - (forward and 90 or -90)
        if (yaw >= 180) then
            yaw = 360 - yaw
            yaw = -yaw
        end
        return yaw
    else
        return 0
    end
end

-- vector funcs

vector.to_angle = function(vec_1)
    local temp, pitch, yaw = 0, 0, 0
    if (vec_1.y == 0 and vec_1.x == 0) then
        yaw = 0
        if (vec_1.z > 0) then
            pitch = 270
        else
            pitch = 90
        end
    else
        yaw = math.atan2(vec_1.y, vec_1.x) * 180 / math.pi
        if (yaw < 0) then
            yaw = yaw + 360
        end

        temp = math.sqrt(vec_1.x * vec_1.x + vec_1.y * vec_1.y)
        pitch = math.atan2(-vec_1.z, temp) * 180 / math.pi

        if (pitch < 0) then
            pitch = pitch + 360
        end
    end
    return vec3_t(pitch, yaw, 0)
end

-- array funcs

array.put = function(array, val)
    array[#array + 1] = val
end

array.has = function(array, val)
    is_exist = false
    for i = 1, #array do
        if (array[i] == val) then
            is_exist = true
        end
    end
    return is_exist
end

-- visual funcs

anim_lerp = function(start, end_pos, time)
    return start + (end_pos - start) * (globals.frame_time() * time)
end

animated_sc = function(name, new_value, speed, init)
    speed = speed or 0.07
    if (anim_database[name] == nil) then
        anim_database[name] = (init and init) or 0
    end

    anim_database[name] = anim_lerp(anim_database[name], new_value, speed)
    return anim_database[name]
end

animated_text = function(font, text, accent_color, position, speed)
    local data, total_width = {}, 0
    local len, two_pi = #text, math.pi * 1.5
    local clr1 = speed == 0 and color_t(255, 255, 255, 255) or color_t(0, 0, 0, 155)

    for idx = 1, len do
        local modifier = two_pi / len * idx
        
        local char = text:sub(idx, idx)
        local char_width = render_get_text_size(font, char).x

        data[idx] = {total_width, char, modifier}
        total_width = total_width + char_width
    end

    total_width = total_width * 0.5
    return function()
        local time = -globals.cur_time() * math.pi * speed
        local header_offset = position - vec2_t(total_width, 0)

        for _, char in pairs(data) do
            local char_pos = header_offset + vec2_t(char[1], 0)
            local fade_value = math.sin(time + char[3]) * 0.5 + 0.5
            local color = clr1:fade(accent_color, fade_value)

            render_text(font, char[2], char_pos, color)
        end
    end
end

-- notifications funcs

notifications.create = function(header, body, kind)
    table.insert(notifications.logs, { head = tostring(header), body = tostring(body or ""), kind = kind, time = globals.real_time() })
end

-- logs funcs

logs.lerp = function(a, b, t)
    return a * (1 - t) + b * t
end

logs.add_hitlog = function(ctx)
    table.insert(logs.logs, { type = "hit", pos = vec2_t(0, 0), cached_pos = vec2_t(0, 0), opacity = 0, time = globals.real_time(), player = ctx.player:get_name(), damage_dealt = ctx.damage, damage_predicted = ctx.aim_damage, hitbox = hit_groups[ctx.hitgroup], hitbox_predicted = hit_groups[ctx.aim_hitgroup]})
end

logs.add_misslog = function(ctx)
    table.insert(logs.logs, { type = "miss", pos = vec2_t(0, 0), cached_pos = vec2_t(0, 0), opacity = 0, time = globals.real_time(), reason = ctx.reason_string, player = ctx.player ~= nil and ctx.player:get_name() or "unknown", safepoint = ctx.aim_safepoint, damage_predicted = ctx.aim_damage, hitbox = client_get_hitgroup_name(ctx.aim_hitgroup) })
end

handle_logs = function()
    local rainbow_colors = {
        color_t(255, 113, 237, 255),
        color_t(247, 120, 243, 255),
        color_t(239, 126, 249, 255),
        color_t(230, 132, 254, 255),
        color_t(222, 138, 255, 255),
        color_t(213, 143, 255, 255),
        color_t(204, 148, 255, 255),
        color_t(196, 153, 255, 255),
        color_t(187, 157, 255, 255),
        color_t(179, 162, 255, 255),
        color_t(171, 165, 255, 255),
        color_t(163, 169, 255, 255),
        color_t(156, 172, 255, 255),
        color_t(150, 176, 255, 255),
        color_t(144, 178, 255, 255),
        color_t(138, 181, 255, 255),
        color_t(134, 184, 255, 255),
        color_t(131, 186, 255, 255),
        color_t(128, 188, 255, 255),
        color_t(127, 190, 255, 255),

        color_t(255, 0, 0, 255),
        color_t(255, 0, 12, 255),
        color_t(255, 0, 21, 255),
        color_t(255, 0, 29, 255),
        color_t(255, 0, 36, 255),
        color_t(255, 0, 42, 255),
        color_t(255, 0, 48, 255),
        color_t(255, 0, 54, 255),
        color_t(255, 0, 60, 255),
        color_t(255, 0, 66, 255),
        color_t(255, 0, 71, 255),
        color_t(255, 0, 77, 255),
        color_t(255, 0, 83, 255),
        color_t(255, 0, 89, 255),
        color_t(255, 0, 95, 255),
        color_t(255, 0, 101, 255),
        color_t(255, 0, 107, 255),
        color_t(255, 0, 113, 255),
        color_t(255, 0, 119, 255),
        color_t(255, 0, 125, 255),

        color_t(255, 0, 0, 255),
        color_t(255, 64, 0, 255),
        color_t(255, 128, 0, 255),
        color_t(255, 191, 0, 255),
        color_t(255, 255, 0, 255),
        color_t(191, 255, 0, 255),
        color_t(128, 255, 0, 255),
        color_t(64, 255, 0, 255),
        color_t(0, 255, 0, 255),
        color_t(0, 255, 64, 255),
        color_t(0, 255, 128, 255),
        color_t(0, 255, 191, 255),
        color_t(0, 255, 255, 255),
        color_t(0, 191, 255, 255),
        color_t(0, 128, 255, 255),
        color_t(0, 64, 255, 255),
        color_t(0, 0, 255, 255),
        color_t(64, 0, 255, 255),
        color_t(128, 0, 255, 255),
        color_t(191, 0, 255, 255),

        color_t(168, 0, 255, 255),
        color_t(164, 6, 255, 255),
        color_t(159, 13, 255, 255),
        color_t(155, 19, 255, 255),
        color_t(151, 25, 255, 255),
        color_t(146, 32, 255, 255),
        color_t(142, 38, 255, 255),
        color_t(138, 44, 255, 255),
        color_t(134, 50, 255, 255),
        color_t(129, 57, 255, 255),
        color_t(125, 63, 255, 255),
        color_t(121, 69, 255, 255),
        color_t(116, 76, 255, 255),
        color_t(112, 82, 255, 255),
        color_t(108, 88, 255, 255),
        color_t(103, 95, 255, 255),
        color_t(99, 101, 255, 255),
        color_t(95, 107, 255, 255),
        color_t(90, 114, 255, 255)
    }

    local random_color = rainbow_colors[math.random(#rainbow_colors)]
    for i = #logs.logs, 1, -1 do
        local log = logs.logs[i]
        local string_

        if (log.type == 'hit') then
            string_ = string.format('specter » hit %s in %s (%s) for %i (%i)', log.player, log.hitbox, log.hitbox_predicted, log.damage_dealt, log.damage_predicted)
        else
            string_ = string.format('specter » missed (%s) %s in %s for %i (safe: %s)', log.reason, log.player, log.hitbox, log.damage_predicted, log.safepoint)
        end

        log.pos.y = (i - 1) * 22 + 0

        local orig_offset = vec2_t(screen_size.x / 2, screen_size.y / 2 + 100)
        orig_offset = orig_offset - vec2_t(render_get_text_size(logs.font, string_).x / 2, 0)

        if (globals.real_time() - log.time <= 0.1) then
            log.pos.x = -render_get_text_size(logs.font, string_).x
            log.cached_pos.y = log.pos.y
        elseif (globals.real_time() - log.time <= 1) then
            log.pos.x = logs.lerp(log.pos.x, 5, 0.1)
            log.opacity = logs.lerp(log.opacity, 255, 0.1)
        elseif (globals.real_time() - log.time >= 3) then
            log.pos.x = logs.lerp(log.pos.x, -render_get_text_size(logs.font, string_).x - 5, 0.1)
            log.opacity = logs.lerp(log.opacity, 0, 0.1)
        end

        if (log.cached_pos.y ~= log.pos.y) then
            log.cached_pos.y = logs.lerp(log.cached_pos.y, log.pos.y, 0.1)
        end
        log.cached_pos.x = log.pos.x

        local offset = 0
        local height = 0

        local color_accent = color_t(ui.accent_color:get().r, ui.accent_color:get().g, ui.accent_color:get().b, math.floor(log.opacity))
        local color_default = color_t(logs.neutral_color.r, logs.neutral_color.g, logs.neutral_color.b, math.floor(log.opacity))
        local color_bg = color_t(logs.background_color.r, logs.background_color.g, logs.background_color.b, math.floor(log.opacity))

        local bg_size = render_get_text_size(logs.font, string_) + vec2_t(14, 6)
        render_push_clip(orig_offset + log.cached_pos + vec2_t(offset - 7, height + bg_size.y / 2), vec2_t(bg_size.x * (globals.real_time() - log.time) / 2.8, bg_size.y / 2))
        
        render_rect(orig_offset + log.cached_pos + vec2_t(offset - 7, height - 3), bg_size, color_accent, 7)
        render_pop_clip()

        render_text(logs.font, 'specter', orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
        offset = offset + render_get_text_size(logs.font, 'specter').x

        render_text(logs.font, ' » ', orig_offset + log.cached_pos + vec2_t(offset, height), random_color)
        offset = offset + render_get_text_size(logs.font, ' » ').x

        if (log.type == 'hit') then
            render_text(logs.font, 'hit ', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, 'hit ').x

            render_text(logs.font, log.player, orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, log.player).x

            render_text(logs.font, ' in ', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, ' in ').x

            render_text(logs.font, log.hitbox, orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, log.hitbox).x

            render_text(logs.font, ' (', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, ' (').x

            render_text(logs.font, tostring(log.hitbox_predicted), orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, tostring(log.hitbox_predicted)).x
            
            render_text(logs.font, ')', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, ')').x

            render_text(logs.font, ' for ', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, ' for ').x

            render_text(logs.font, tostring(log.damage_dealt), orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, tostring(log.damage_dealt)).x

            render_text(logs.font, ' (', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, ' (').x

            render_text(logs.font, tostring(log.damage_predicted), orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, tostring(log.damage_predicted)).x

            render_text(logs.font, ')', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
        elseif (log.type == 'miss') then
            render_text(logs.font, 'missed ', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, 'missed ').x
            
            render_text(logs.font, '(', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, '(').x
            
            render_text(logs.font, log.reason, orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, log.reason).x
            
            render_text(logs.font, ')', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, ')').x
            
            render_text(logs.font, ' ' .. log.player, orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, ' ' .. log.player).x
            
            render_text(logs.font, ' at ', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, ' at ').x            
            render_text(logs.font, log.hitbox, orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, log.hitbox).x
            
            render_text(logs.font, ' for ', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, ' for ').x
            
            render_text(logs.font, tostring(log.damage_predicted), orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, tostring(log.damage_predicted)).x
            
            render_text(logs.font, ' (safe: ', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
            offset = offset + render_get_text_size(logs.font, ' (safe: ').x
            
            render_text(logs.font, tostring(log.safepoint), orig_offset + log.cached_pos + vec2_t(offset, height), color_accent)
            offset = offset + render_get_text_size(logs.font, tostring(log.safepoint)).x
            
            render_text(logs.font, ')', orig_offset + log.cached_pos + vec2_t(offset, height), color_default)
        end

        if (log.time + 3 < globals.real_time() and log.pos.x <= -render_get_text_size(logs.font, string_).x) then
            table.remove(logs.logs, i)
        end
    end
end

--- @endregion

--- @info: config system
--- @region: config

-- cloud based

-- default.cfg: the owner's config (resolver, anti-aim and the rest), applied on the first start (no csgo/specter folder yet)
configs.default_config = "eyJIZWxwZXJzIjpbWyJGaXggY29ycmVjdGlvbiIsdHJ1ZV0sWyJSdWJiZXJiYW5nIix0cnVlXSxbIkxhZyBvbiBzaG9vdCIsZmFsc2VdXSwiQ29tbXVuaWNhdGlvbiI6W1siVHJhc2ggdGFsayIsMV0sWyJUYWxrIGJhY2siLGZhbHNlXSxbIlZvaWNlIHN0YXRlIiwzXV0sIk1pc2MiOltbIkZha2UgdHlwZSIsW1siSGVhZHNob3QiLGZhbHNlXSxbIldhbGxiYW5nIixmYWxzZV0sWyJObyBTY29wZSIsZmFsc2VdLFsiRmxhc2hlZCIsZmFsc2VdLFsiVGhydSBzbW9rZSIsZmFsc2VdLFsiRG9taW5hdGVkIixmYWxzZV0sWyJSZXZlbmdlIixmYWxzZV1dXSxbIktuaWZlYm90IGhlbHBlciIsdHJ1ZV0sWyJVbmxvY2sgbGF0ZW5jeSIsdHJ1ZV0sWyJGYXN0IHdlYXBvbiBzd2l0Y2giLHRydWVdLFsiQXV0byBkZWZ1c2UiLHRydWVdLFsiRmFrZSBtZWRpYSIsZmFsc2VdLFsiWmV1cyB2cyBydXNoZXJzIix0cnVlXSxbIkRpc2FibGUgRFQgd2l0aCB6ZXVzIix0cnVlXV0sIlBsYXllciI6W1siQW5pbWF0aW9uIGJyZWFrZXIiLGZhbHNlXSxbIlN1cGVyIHRvc3MiLDFdLFsiQ29vbCB0ZWFtIGFuaW1hdGlvbiIsZmFsc2VdLFsiVmlzdWFsIHJlY29pbCIsZmFsc2VdLFsiRmFzdCBsYWRkZXIiLFtbIlVwIix0cnVlXSxbIkRvd24iLHRydWVdXV1dLCJUaWNrYmFzZSI6W1siSW1wcm92ZSBiYWNrdHJhY2siLHRydWVdLFsiUmVjb3JkIHdlaWdodGluZyB0eXBlIiwxXSxbIkFnZ3Jlc3NpdmUgZmFjdG9yIiwxNV0sWyJCYWNrdHJhY2sgZXhwaXJhdGlvbiIsMV0sWyJMb3cgcGVyZm9ybWFuY2UgbW9kZSIsZmFsc2VdLFsiRXh0ZW5kZWQgYmFja3RyYWNrIixmYWxzZV0sWyJNYXggdGFyZ2V0cyIsMl0sWyJBZGp1c3QgdGlja3MgZHluYW1pY2FsbHkiLDJdLFsiRW5hYmxlIGludGVycG9sYXRpb24iLHRydWVdLFsiUHJpb3JpdGl6ZSBvbGRlciByZWNvcmRzIixmYWxzZV0sWyJQcmVkaWN0aW9uIGZhY3RvciIsMTFdLFsiQmFja3RyYWNrIHNtb290aGluZyIsOV0sWyJTbW9vdGggdHJhbnNpdGlvbiIsdHJ1ZV0sWyJUcmFuc2l0aW9uIHNwZWVkIiwyNV0sWyJFbmFibGUgZXh0cmFwb2xhdGlvbiIsdHJ1ZV0sWyJBZ2dyZXNzaXZlIGJhY2t0cmFjayIsdHJ1ZV0sWyJUcmFuc2l0aW9uIHByaW9yaXR5IiwyXV0sIlJlc29sdmVyIjpbWyJMb2dpYyByZXNvbHZlciIsdHJ1ZV0sWyJJbXByb3ZlIHJlc29sdmVyIix0cnVlXV0sIkV4cGxvaXRzIjpbWyJEVCBTcGVlZCIsMTJdLFsiQmV0dGVyIGhpZGVzaG90cyIsdHJ1ZV0sWyJJbXByb3ZlIGRvdWJsZXRhcCIsdHJ1ZV0sWyJPcHRpbWl6ZSBkb3VibGV0YXAiLHRydWVdLFsiU2FmZSByZWNoYXJnZSIsdHJ1ZV0sWyJNb2RlIiwxXSxbIlNwZWVkIGNhbGN1bGF0aW9uIiwyXV0sIkdsb2JhbCI6W1siUGl0Y2giLDJdLFsiQmFzZSIsMl0sWyJEZWZlbnNpdmUgbW9kZSIsMl1dLCJVdGlscyI6W1siR2xvdyBlZmZlY3RzIix0cnVlXSxbIlRlc2xhIGNvbG9yIiwyNTUsODAsODAsMjU1XSxbIkNvbnNvbGUgY29sb3IiLDU1LDU1LDU1LDE1NF0sWyJBbHQgY29sb3IiLDIwMCwxOTksMTk3LDI1NV0sWyJXYXRlcm1hcmsiLGZhbHNlXSxbIktleWJpbmRzIixmYWxzZV0sWyJNYWluIGNvbG9yIiwxNzcsMjU1LDg3LDI1NV0sWyJCb3ggY29sb3IiLDQ3LDExNywyMjEsMjU1XSxbIlNwZWN0YXRvcnMiLGZhbHNlXSxbIkxvZ3Mgc2VsZWN0aW9uIixbWyJTaG93IHN0YXRzIix0cnVlXSxbIkhpdHMiLHRydWVdLFsiUHVyY2hhc2VzIixmYWxzZV0sWyJIdXJ0cyIsdHJ1ZV0sWyJNaXNzZXMiLHRydWVdLFsiRXZhZGVzIix0cnVlXV1dXSwiQ2xvdWQgY29uZmlncyI6W10sIk1vdmVtZW50IjpbWyJKdW1wc2hvdCBoZWxwZXIiLHRydWVdLFsiTm8gZmFsbCBkYW1hZ2UiLHRydWVdLFsiQW50aSBhZmsiLGZhbHNlXV0sIkNvbmZpZ3VyYXRpb24gKGJldGEpIjpbWyJBdCBkaXNhYmxlciIsM10sWyJZYXcgY2FsY3VsYXRpb24iLDNdLFsiRGlzYWJsZXJzIixbWyJJbiBhaXIiLGZhbHNlXSxbIkluIGFpcmR1Y2siLGZhbHNlXSxbIkF0IGR1Y2siLGZhbHNlXSxbIkF0IHBlZWsiLGZhbHNlXSxbIkF0IHNjb3BlIixmYWxzZV0sWyJBdCBub3Njb3BlIixmYWxzZV0sWyJXaXRoIGRvdWJsZXRhcCIsZmFsc2VdLFsiV2l0aCBoaWRlc2hvdHMiLGZhbHNlXSxbIkxvdyBmcHMgKDw3NWZwcykiLHRydWVdLFsiSGlnaCBwaW5nICg+ODBtcykiLHRydWVdXV1dLCJTdGF0aXN0aWNzIjpbXSwiSG9tZSB8IGF6dXJhIHY1LjQgKGJldGEpIjpbWyJUZXh0IGNvbG9yIiwxNDAsNzEsMjQ3LDI1NV0sWyJhenVyYS51bm8gfCB0ZWUgaGVlITwzIiwxXSxbIkFjY2VudCBjb2xvciIsMjIyLDE1MywxODUsMjU1XV0sIlZpc3VhbHMiOltbIkNoaW5hIGhhdCIsZmFsc2VdLFsiVGVzbGEgb24gc2hvb3QiLGZhbHNlXSxbIkNyb3NzaGFpciBpbmRpY2F0b3JzIixbWyJEb3VibGUgdGFwIix0cnVlXSxbIkhpZGUgc2hvdHMiLHRydWVdLFsiTWluaW11bSBkbWciLHRydWVdLFsiUXVpY2sgcGVlayIsdHJ1ZV0sWyJGcmVlc3RhbmQiLHRydWVdLFsiUGluZyBzcGlrZSIsdHJ1ZV0sWyJGb3JjZSBib2R5YWltIix0cnVlXSxbIkZvcmNlIHNhZmVwb2ludCIsdHJ1ZV0sWyJPdmVycmlkZSBoaXRib3giLHRydWVdLFsiT3ZlcnJpZGUgaGl0Y2hhbmNlIix0cnVlXV1dLFsiQ29uc29sZSBjb2xvciIsdHJ1ZV0sWyJFU1AgRm9udCIsM10sWyJEZWJ1ZyBsYWdjb21wIix0cnVlXSxbIlJpZ2h0IGluZGljYXRvcnMiLFtbIkRvdWJsZSB0YXAiLHRydWVdLFsiSGlkZSBzaG90cyIsdHJ1ZV0sWyJNaW5pbXVtIGRtZyIsdHJ1ZV0sWyJRdWljayBwZWVrIix0cnVlXSxbIkZyZWVzdGFuZCIsdHJ1ZV0sWyJQaW5nIHNwaWtlIix0cnVlXSxbIkZvcmNlIGJvZHlhaW0iLHRydWVdLFsiRm9yY2Ugc2FmZXBvaW50Iix0cnVlXSxbIk92ZXJyaWRlIGhpdGJveCIsdHJ1ZV0sWyJPdmVycmlkZSBoaXRjaGFuY2UiLHRydWVdXV0sWyJIYXQgY29sb3IiLDg5LDIzNywyNTUsMjU1XV0sIkZlYXR1cmVzIjpbWyJBdm9pZCBvbnNob3QiLHRydWVdLFsiQW50aSBiYWNrc3RhYiIsdHJ1ZV0sWyJDcm91Y2ggY29ycmVjdGlvbiIsW1siWWF3Iix0cnVlXV1dLFsiUmFuZG9taXphdGlvbiIsW1siTm8gZW5lbWllcyBhbGl2ZSIsZmFsc2VdLFsiV2FybXVwIixmYWxzZV1dXSxbIlNhZmUgaGVhZCIsW1siQWlyIGtuaWZlIix0cnVlXSxbIkFsbG93IGRlZmVuc2l2ZSIsdHJ1ZV0sWyJBaXIgemV1cyIsZmFsc2VdLFsiSGVpZ2h0IGFkdmFudGFnZSIsdHJ1ZV1dXSxbIkZha2VsYWcgdmFyaWFuY2UiLHRydWVdXSwiUmVzb2x2ZXIgKGJldGEpIjpbWyJTaG90IHByZWRpY3Rpb24iLDRdLFsiQ2FsY3VsYXRlIGJveCIsMTldLFsiQ3VzdG9tIHJlc29sdmVyIix0cnVlXSxbIkF1dG8gZHVjayIsdHJ1ZV0sWyJVbnNhZmUgcmVzb2x2ZXIiLHRydWVdLFsiU2FmZSBwZWVrIix0cnVlXSxbIlBvc2UgcmVzb2x2ZXIiLHRydWVdLFsiU2FmZSBtb2RlIiw0XSxbIkR1Y2sgbW9kZSIsZmFsc2VdLFsiUHJlZGljdGlvbiBzZWwiLDIwXV0sIlJhZ2Vib3QiOltbIkRlZmVuc2l2ZSBzYWZlcG9pbnQiLHRydWVdLFsiQm9vc3RlciBtb2RlIiwxXSxbIkFjY3VyYWN5IGJvb3N0ZXIiLHRydWVdLFsiTXVsdGlwb2ludCBjb3JyZWN0aW9uIix0cnVlXV0sIllhdyI6W1siU1cgfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIk92ZXJyaWRlIC0gQWlyIGR1Y2siLHRydWVdLFsiRiB8IExlZnQiLDBdLFsiRyB8IExlZnQiLC0xNV0sWyJNIHwgUmlnaHQgcmFuZG9taXphdGlvbiIsMThdLFsiRyB8IFlhdyIsMF0sWyJEIHwgWWF3IG1vZGUiLDRdLFsiQSB8IFJpZ2h0IHJhbmRvbWl6YXRpb24iLDIwXSxbIlNXIHwgWWF3IiwwXSxbIkRNIHwgTGVmdCIsLTE4XSxbIkEgfCBZYXcgbW9kZSIsNF0sWyJTVyB8IExlZnQgcmFuZG9taXphdGlvbiIsMF0sWyJNIHwgWWF3IG1vZGUiLDVdLFsiRyB8IFlhdyBtb2RlIiw0XSxbIlMgfCBZYXciLDBdLFsiRlIgfCBSaWdodCByYW5kb21pemF0aW9uIiw5XSxbIkZSIHwgUmlnaHQiLDExXSxbIlMgfCBEZWxheSIsNF0sWyJHIHwgUmlnaHQgcmFuZG9taXphdGlvbiIsMF0sWyJNIHwgRGVsYXkiLDVdLFsiRE0gfCBEZWxheSIsMl0sWyJBRCB8IFlhdyIsMF0sWyJTVyB8IExlZnQiLC0yMF0sWyJEIHwgRGVsYXkiLDJdLFsiRE0gfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiRyB8IERlbGF5Iiw1XSxbIkRNIHwgWWF3IiwwXSxbIkEgfCBEZWxheSIsM10sWyJGUiB8IERlbGF5IGZsdWN0dWF0aW9uIiwzXSxbIkZSIHwgRGVsYXkiLDVdLFsiTU4gfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiT3ZlcnJpZGUgLSBNb3ZlIix0cnVlXSxbIlMgfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiT3ZlcnJpZGUgLSBBaXIiLHRydWVdLFsiRCB8IExlZnQiLC0xNV0sWyJNIHwgUmlnaHQiLDEwXSxbIkZSIHwgTGVmdCByYW5kb21pemF0aW9uIiwtMTJdLFsiQSB8IFlhdyIsMF0sWyJGUiB8IFlhdyBtb2RlIiwyXSxbIk92ZXJyaWRlIC0gR2xvYmFsIix0cnVlXSxbIkFEIHwgUmlnaHQiLDddLFsiU1cgfCBZYXcgbW9kZSIsNl0sWyJTIHwgWWF3IG1vZGUiLDRdLFsiRlIgfCBMZWZ0IiwtMTFdLFsiRyB8IExlZnQgcmFuZG9taXphdGlvbiIsMF0sWyJEIHwgTGVmdCByYW5kb21pemF0aW9uIiwtMTFdLFsiQUQgfCBMZWZ0IiwtMTVdLFsiT3ZlcnJpZGUgLSBEdWNrIix0cnVlXSxbIk1OIHwgRGVsYXkgZmx1Y3R1YXRpb24iLDBdLFsiT3ZlcnJpZGUgLSBTbG93IHdhbGsiLHRydWVdLFsiQSB8IExlZnQgcmFuZG9taXphdGlvbiIsLTIwXSxbIkYgfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiRlIgfCBZYXciLDBdLFsiUyB8IERlbGF5IGZsdWN0dWF0aW9uIiwwXSxbIk92ZXJyaWRlIC0gRHVjayBtb3ZlIix0cnVlXSxbIk0gfCBEZWxheSBmbHVjdHVhdGlvbiIsOF0sWyJPdmVycmlkZSAtIEZyZWVzdGFuZCIsdHJ1ZV0sWyJPdmVycmlkZSAtIFN0YW5kIix0cnVlXSxbIk1OIHwgRGVsYXkiLDJdLFsiTU4gfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIlNXIHwgRGVsYXkiLDhdLFsiTU4gfCBSaWdodCIsMF0sWyJGIHwgRGVsYXkgZmx1Y3R1YXRpb24iLDBdLFsiTU4gfCBMZWZ0IiwwXSxbIk1OIHwgWWF3IiwwXSxbIkcgfCBEZWxheSBmbHVjdHVhdGlvbiIsMF0sWyJPdmVycmlkZSAtIE1hbnVhbCIsZmFsc2VdLFsiQSB8IERlbGF5IGZsdWN0dWF0aW9uIiw4XSxbIkQgfCBEZWxheSBmbHVjdHVhdGlvbiIsNF0sWyJNTiB8IFlhdyBtb2RlIiwxXSxbIk0gfCBMZWZ0IHJhbmRvbWl6YXRpb24iLC0xOF0sWyJGIHwgRGVsYXkiLDJdLFsiRiB8IFJpZ2h0IHJhbmRvbWl6YXRpb24iLDBdLFsiRiB8IFlhdyBtb2RlIiwxXSxbIkQgfCBSaWdodCIsMTBdLFsiRiB8IFlhdyIsMF0sWyJGIHwgUmlnaHQiLDBdLFsiRyB8IFJpZ2h0IiwxMF0sWyJBRCB8IExlZnQgcmFuZG9taXphdGlvbiIsMF0sWyJBIHwgUmlnaHQiLDI1XSxbIkRNIHwgRGVsYXkgZmx1Y3R1YXRpb24iLDBdLFsiUyB8IExlZnQiLC0yM10sWyJBRCB8IERlbGF5IGZsdWN0dWF0aW9uIiwwXSxbIkFEIHwgRGVsYXkiLDVdLFsiQUQgfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIkFEIHwgWWF3IG1vZGUiLDRdLFsiRE0gfCBSaWdodCIsMTVdLFsiRE0gfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIk0gfCBZYXciLDBdLFsiUyB8IFJpZ2h0IHJhbmRvbWl6YXRpb24iLDBdLFsiU1cgfCBSaWdodCIsMTVdLFsiTSB8IExlZnQiLC0xMF0sWyJEIHwgUmlnaHQgcmFuZG9taXphdGlvbiIsMTFdLFsiUyB8IFJpZ2h0IiwyNF0sWyJETSB8IFlhdyBtb2RlIiw1XSxbIlNXIHwgRGVsYXkgZmx1Y3R1YXRpb24iLDBdLFsiT3ZlcnJpZGUgLSBGYWtlbGFnIixmYWxzZV0sWyJBIHwgTGVmdCIsLTI1XSxbIkQgfCBZYXciLDBdLFsiRyB8IFdheXMiLDVdLFsiRyB8IFJhbmdlIiwyNV0sWyJHIHwgSG9sZCIsMl0sWyJHIHwgU3dheSBzcGVlZCIsNDBdLFsiRyB8IFNuYXAgY2hhbmNlIiwxNV0sWyJTIHwgV2F5cyIsNV0sWyJTIHwgUmFuZ2UiLDI1XSxbIlMgfCBIb2xkIiwyXSxbIlMgfCBTd2F5IHNwZWVkIiw0MF0sWyJTIHwgU25hcCBjaGFuY2UiLDE1XSxbIk0gfCBXYXlzIiw1XSxbIk0gfCBSYW5nZSIsMjJdLFsiTSB8IEhvbGQiLDJdLFsiTSB8IFN3YXkgc3BlZWQiLDQwXSxbIk0gfCBTbmFwIGNoYW5jZSIsMTVdLFsiU1cgfCBXYXlzIiw1XSxbIlNXIHwgUmFuZ2UiLDIyXSxbIlNXIHwgSG9sZCIsM10sWyJTVyB8IFN3YXkgc3BlZWQiLDQwXSxbIlNXIHwgU25hcCBjaGFuY2UiLDE1XSxbIkQgfCBXYXlzIiwzXSxbIkQgfCBSYW5nZSIsMThdLFsiRCB8IEhvbGQiLDJdLFsiRCB8IFN3YXkgc3BlZWQiLDQwXSxbIkQgfCBTbmFwIGNoYW5jZSIsMTVdLFsiRE0gfCBXYXlzIiw1XSxbIkRNIHwgUmFuZ2UiLDE4XSxbIkRNIHwgSG9sZCIsMl0sWyJETSB8IFN3YXkgc3BlZWQiLDQ1XSxbIkRNIHwgU25hcCBjaGFuY2UiLDIwXSxbIkEgfCBXYXlzIiw1XSxbIkEgfCBSYW5nZSIsMzBdLFsiQSB8IEhvbGQiLDFdLFsiQSB8IFN3YXkgc3BlZWQiLDQwXSxbIkEgfCBTbmFwIGNoYW5jZSIsMTVdLFsiQUQgfCBXYXlzIiw3XSxbIkFEIHwgUmFuZ2UiLDMyXSxbIkFEIHwgSG9sZCIsMV0sWyJBRCB8IFN3YXkgc3BlZWQiLDQwXSxbIkFEIHwgU25hcCBjaGFuY2UiLDE1XV0sIlN5c3RlbSI6W1sidmVyc2lvbiIsIjEuMCJdLFsiYnVpbGQiLCJiZXRhIl1dLCJEZWZlbnNpdmUiOltbIkZSIHwgRGVmZW5zaXZlIiwxXSxbIlNXIHwgU3BpbiByYW5nZSIsMF0sWyJBRCB8IFNwaW4gc3BlZWQiLDEwMF0sWyJETSB8IFNwaW4gcmFuZ2UiLDBdLFsiQSB8IFBpdGNoIHZhbHVlICgxKSIsLTg5XSxbIlNXIHwgWWF3IHZhbHVlIiwxMjBdLFsiQUQgfCBEZWZlbnNpdmUiLDFdLFsiRiB8IFBpdGNoIHZhbHVlICgxKSIsMF0sWyJEIHwgUGl0Y2ggdmFsdWUgKDEpIiwtODldLFsiUyB8IFBpdGNoIHZhbHVlICgyKSIsODldLFsiTU4gfCBEZWZlbnNpdmUiLDFdLFsiTSB8IFNwaW4gc3BlZWQiLDBdLFsiQSB8IERlZmVuc2l2ZSIsNl0sWyJTIHwgUGl0Y2ggdmFsdWUgKDEpIiwtODldLFsiQSB8IFlhdyB2YWx1ZSIsMTIwXSxbIkQgfCBZYXcgdmFsdWUiLDEyMF0sWyJBIHwgRGVmZW5zaXZlIHlhdyIsMTJdLFsiUyB8IFNwaW4gcmFuZ2UiLDBdLFsiQUQgfCBTcGluIHJhbmdlIiwzNjBdLFsiRiB8IERlZmVuc2l2ZSB5YXciLDFdLFsiRCB8IERlZmVuc2l2ZSB5YXciLDEwXSxbIkcgfCBEZWZlbnNpdmUgeWF3IiwxMF0sWyJNTiB8IERlZmVuc2l2ZSB5YXciLDFdLFsiRiB8IFNwaW4gcmFuZ2UiLDBdLFsiRE0gfCBEZWZlbnNpdmUiLDFdLFsiRCB8IFNwaW4gc3BlZWQiLDEwMF0sWyJEIHwgU3BpbiByYW5nZSIsMzYwXSxbIkcgfCBTcGluIHNwZWVkIiwxMDBdLFsiQSB8IFNwaW4gc3BlZWQiLDEwMF0sWyJETSB8IFBpdGNoIHZhbHVlICgyKSIsODldLFsiUyB8IFlhdyB2YWx1ZSIsMTIwXSxbIkYgfCBTcGluIHNwZWVkIiwwXSxbIkZSIHwgU3BpbiBzcGVlZCIsMTAwXSxbIlNXIHwgRGVmZW5zaXZlIHlhdyIsMTBdLFsiRlIgfCBEZWZlbnNpdmUgeWF3IiwxMF0sWyJGUiB8IFBpdGNoIHZhbHVlICgyKSIsODldLFsiTU4gfCBQaXRjaCB2YWx1ZSAoMikiLDBdLFsiTU4gfCBTcGluIHJhbmdlIiwwXSxbIk0gfCBTcGluIHJhbmdlIiwwXSxbIkEgfCBEZWZlbnNpdmUgcGl0Y2giLDEyXSxbIkYgfCBZYXcgdmFsdWUiLDBdLFsiRlIgfCBEZWZlbnNpdmUgcGl0Y2giLDExXSxbIkcgfCBZYXcgdmFsdWUiLDEyMF0sWyJTVyB8IERlZmVuc2l2ZSBwaXRjaCIsMTFdLFsiQUQgfCBQaXRjaCB2YWx1ZSAoMikiLDg5XSxbIk1OIHwgRGVmZW5zaXZlIHBpdGNoIiwxXSxbIkRNIHwgUGl0Y2ggdmFsdWUgKDEpIiwtODldLFsiRE0gfCBZYXcgdmFsdWUiLDEwMF0sWyJNIHwgWWF3IHZhbHVlIiwxMjBdLFsiTU4gfCBQaXRjaCB2YWx1ZSAoMSkiLDBdLFsiQSB8IFNwaW4gcmFuZ2UiLDM2MF0sWyJNTiB8IFNwaW4gc3BlZWQiLDBdLFsiRlIgfCBTcGluIHJhbmdlIiwzNjBdLFsiRyB8IERlZmVuc2l2ZSBwaXRjaCIsMTFdLFsiRlIgfCBQaXRjaCB2YWx1ZSAoMSkiLC04OV0sWyJETSB8IERlZmVuc2l2ZSBwaXRjaCIsMTFdLFsiRyB8IERlZmVuc2l2ZSIsMV0sWyJEIHwgRGVmZW5zaXZlIiwxXSxbIk0gfCBQaXRjaCB2YWx1ZSAoMikiLDg5XSxbIk0gfCBEZWZlbnNpdmUgcGl0Y2giLDExXSxbIkFEIHwgRGVmZW5zaXZlIHBpdGNoIiwxMV0sWyJGUiB8IFlhdyB2YWx1ZSIsMTIwXSxbIk0gfCBEZWZlbnNpdmUiLDZdLFsiQUQgfCBQaXRjaCB2YWx1ZSAoMSkiLC04OV0sWyJGIHwgRGVmZW5zaXZlIHBpdGNoIiwxXSxbIkYgfCBEZWZlbnNpdmUiLDFdLFsiQUQgfCBEZWZlbnNpdmUgeWF3IiwxMV0sWyJNIHwgRGVmZW5zaXZlIHlhdyIsMTJdLFsiUyB8IERlZmVuc2l2ZSIsMV0sWyJTVyB8IFBpdGNoIHZhbHVlICgyKSIsODldLFsiRE0gfCBEZWZlbnNpdmUgeWF3IiwxMl0sWyJTVyB8IERlZmVuc2l2ZSIsMV0sWyJHIHwgUGl0Y2ggdmFsdWUgKDIpIiw4OV0sWyJETSB8IFNwaW4gc3BlZWQiLDBdLFsiUyB8IFNwaW4gc3BlZWQiLDBdLFsiU1cgfCBQaXRjaCB2YWx1ZSAoMSkiLC04OV0sWyJHIHwgU3BpbiByYW5nZSIsMzYwXSxbIlMgfCBEZWZlbnNpdmUgeWF3IiwxMF0sWyJBRCB8IFlhdyB2YWx1ZSIsMTQwXSxbIkEgfCBQaXRjaCB2YWx1ZSAoMikiLDg5XSxbIkQgfCBEZWZlbnNpdmUgcGl0Y2giLDExXSxbIkYgfCBQaXRjaCB2YWx1ZSAoMikiLDBdLFsiU1cgfCBTcGluIHNwZWVkIiwwXSxbIkQgfCBQaXRjaCB2YWx1ZSAoMikiLDg5XSxbIk0gfCBQaXRjaCB2YWx1ZSAoMSkiLC04OV0sWyJTIHwgRGVmZW5zaXZlIHBpdGNoIiwxMV0sWyJNTiB8IFlhdyB2YWx1ZSIsMF0sWyJHIHwgUGl0Y2ggdmFsdWUgKDEpIiwtODldLFsiRyB8IFNtYXJ0IHRyaWdnZXJzIixbWyJQZWVrIixmYWxzZV0sWyJTaG90IGF0IixmYWxzZV0sWyJBaXIiLGZhbHNlXSxbIlRocmVhdCBhaW0iLGZhbHNlXSxbIlJhbmRvbSIsZmFsc2VdXV0sWyJTIHwgU21hcnQgdHJpZ2dlcnMiLFtbIlBlZWsiLGZhbHNlXSxbIlNob3QgYXQiLGZhbHNlXSxbIkFpciIsZmFsc2VdLFsiVGhyZWF0IGFpbSIsZmFsc2VdLFsiUmFuZG9tIixmYWxzZV1dXSxbIk0gfCBTbWFydCB0cmlnZ2VycyIsW1siUGVlayIsdHJ1ZV0sWyJTaG90IGF0IixmYWxzZV0sWyJBaXIiLGZhbHNlXSxbIlRocmVhdCBhaW0iLGZhbHNlXSxbIlJhbmRvbSIsZmFsc2VdXV0sWyJTVyB8IFNtYXJ0IHRyaWdnZXJzIixbWyJQZWVrIixmYWxzZV0sWyJTaG90IGF0IixmYWxzZV0sWyJBaXIiLGZhbHNlXSxbIlRocmVhdCBhaW0iLGZhbHNlXSxbIlJhbmRvbSIsZmFsc2VdXV0sWyJEIHwgU21hcnQgdHJpZ2dlcnMiLFtbIlBlZWsiLGZhbHNlXSxbIlNob3QgYXQiLGZhbHNlXSxbIkFpciIsZmFsc2VdLFsiVGhyZWF0IGFpbSIsZmFsc2VdLFsiUmFuZG9tIixmYWxzZV1dXSxbIkRNIHwgU21hcnQgdHJpZ2dlcnMiLFtbIlBlZWsiLGZhbHNlXSxbIlNob3QgYXQiLGZhbHNlXSxbIkFpciIsZmFsc2VdLFsiVGhyZWF0IGFpbSIsZmFsc2VdLFsiUmFuZG9tIixmYWxzZV1dXSxbIkEgfCBTbWFydCB0cmlnZ2VycyIsW1siUGVlayIsZmFsc2VdLFsiU2hvdCBhdCIsZmFsc2VdLFsiQWlyIix0cnVlXSxbIlRocmVhdCBhaW0iLGZhbHNlXSxbIlJhbmRvbSIsZmFsc2VdXV0sWyJBRCB8IFNtYXJ0IHRyaWdnZXJzIixbWyJQZWVrIixmYWxzZV0sWyJTaG90IGF0IixmYWxzZV0sWyJBaXIiLGZhbHNlXSxbIlRocmVhdCBhaW0iLGZhbHNlXSxbIlJhbmRvbSIsZmFsc2VdXV0sWyJGUiB8IFNtYXJ0IHRyaWdnZXJzIixbWyJQZWVrIixmYWxzZV0sWyJTaG90IGF0IixmYWxzZV0sWyJBaXIiLGZhbHNlXSxbIlRocmVhdCBhaW0iLGZhbHNlXSxbIlJhbmRvbSIsZmFsc2VdXV1dLCJDdXN0b21pemF0aW9uIjpbWyJUZXNsYSDCtyBiZWFtcyIsMjBdLFsiSGF0IG1vZGUiLDFdLFsiVGVzbGEgwrcgd2lkdGgiLDddLFsiVGVzbGEgwrcgZGVsYXkiLDJdLFsiVGVzbGEgwrcgcmFkaXVzIiwxMDFdXSwiU3luY2hyb25pemF0aW9uIjpbWyJTeW5jZWQgcGxheWVycyIsW1siRGlzYWJsZSB0cmFzaC10YWxrIix0cnVlXSxbIklnbm9yZSB0YWxrLWJhY2siLHRydWVdLFsiQ2hhdCBtZW50aW9ucyIsdHJ1ZV1dXSxbIkNsYW4gdGFnIixmYWxzZV0sWyJTaGFyZWQgRVNQIix0cnVlXV0sIkRlc3luYyI6W1siRCB8IEZha2UgbGVmdCIsNjBdLFsiQSB8IEZha2UgbGVmdCIsNjBdLFsiU1cgfCBEZXN5bmMiLDVdLFsiRyB8IEZha2UgbGVmdCIsNjBdLFsiRiB8IEZha2UgbGVmdCIsMF0sWyJHIHwgTGVmdCByYW5kb21pemF0aW9uIiwwXSxbIkQgfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiTU4gfCBGYWtlIHJpZ2h0IiwwXSxbIk0gfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIkEgfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiUyB8IEZha2UgcmlnaHQiLDYwXSxbIlMgfCBGYWtlIGxlZnQiLDYwXSxbIkRNIHwgRmFrZSBsZWZ0Iiw2MF0sWyJGUiB8IEZha2UgcmlnaHQiLDYwXSxbIlNXIHwgRmFrZSBsZWZ0Iiw2MF0sWyJNTiB8IERlc3luYyIsMV0sWyJGIHwgRmFrZSByaWdodCIsMF0sWyJGUiB8IExlZnQgcmFuZG9taXphdGlvbiIsMF0sWyJGUiB8IEZha2UgbGVmdCIsNjBdLFsiRyB8IEZha2UgcmlnaHQiLDYwXSxbIkRNIHwgRmFrZSByaWdodCIsNjBdLFsiQSB8IEZha2UgcmlnaHQiLDYwXSxbIkQgfCBGYWtlIHJpZ2h0Iiw2MF0sWyJTIHwgRGVzeW5jIiw1XSxbIk1OIHwgUmlnaHQgcmFuZG9taXphdGlvbiIsMF0sWyJBIHwgRGVzeW5jIiw1XSxbIk0gfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiU1cgfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiRCB8IERlc3luYyIsNV0sWyJGUiB8IFJpZ2h0IHJhbmRvbWl6YXRpb24iLDBdLFsiRiB8IERlc3luYyIsMV0sWyJHIHwgRGVzeW5jIiw1XSxbIkYgfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIkcgfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIkQgfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIkYgfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiQUQgfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIk0gfCBEZXN5bmMiLDVdLFsiTSB8IEZha2UgbGVmdCIsNjBdLFsiQUQgfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiQUQgfCBGYWtlIGxlZnQiLDYwXSxbIk0gfCBGYWtlIHJpZ2h0Iiw2MF0sWyJBRCB8IEZha2UgcmlnaHQiLDYwXSxbIkRNIHwgTGVmdCByYW5kb21pemF0aW9uIiwwXSxbIkFEIHwgRGVzeW5jIiw1XSxbIlMgfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIlNXIHwgRmFrZSByaWdodCIsNjBdLFsiQSB8IFJpZ2h0IHJhbmRvbWl6YXRpb24iLDBdLFsiTU4gfCBGYWtlIGxlZnQiLDBdLFsiRE0gfCBEZXN5bmMiLDVdLFsiTU4gfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiU1cgfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIlMgfCBMZWZ0IHJhbmRvbWl6YXRpb24iLDBdLFsiRE0gfCBSaWdodCByYW5kb21pemF0aW9uIiwwXSxbIkZSIHwgRGVzeW5jIiw1XV0sIkppdHRlciI6W1siRlIgfCBNb2RpZmllciBtb2RlIiw2XSxbIlNXIHwgTW9kaWZpZXIgbW9kZSIsNl0sWyJTVyB8IE1vZGlmaWVyIHJhbmRvbWl6YXRpb24iLDBdLFsiRlIgfCBNb2RpZmllciBkZWdyZWUiLDhdLFsiQUQgfCBNb2RpZmllciBkZWdyZWUiLDE0XSxbIkRNIHwgTW9kaWZpZXIgcmFuZG9taXphdGlvbiIsMF0sWyJTVyB8IE1vZGlmaWVyIGRlZ3JlZSIsMTBdLFsiQSB8IE1vZGlmaWVyIGRlZ3JlZSIsMTZdLFsiQUQgfCBNb2RpZmllciBtb2RlIiw2XSxbIkZSIHwgTW9kaWZpZXIgcmFuZG9taXphdGlvbiIsMF0sWyJTIHwgTW9kaWZpZXIgZGVncmVlIiwxMl0sWyJBIHwgTW9kaWZpZXIgbW9kZSIsN10sWyJHIHwgTW9kaWZpZXIgZGVncmVlIiwxMl0sWyJEIHwgTW9kaWZpZXIgZGVncmVlIiw4XSxbIkcgfCBNb2RpZmllciBtb2RlIiw2XSxbIkYgfCBNb2RpZmllciBkZWdyZWUiLDBdLFsiRCB8IE1vZGlmaWVyIG1vZGUiLDZdLFsiRiB8IE1vZGlmaWVyIG1vZGUiLDFdLFsiRE0gfCBNb2RpZmllciBtb2RlIiw2XSxbIk1OIHwgTW9kaWZpZXIgZGVncmVlIiwwXSxbIkQgfCBNb2RpZmllciByYW5kb21pemF0aW9uIiwwXSxbIkcgfCBNb2RpZmllciByYW5kb21pemF0aW9uIiwwXSxbIkYgfCBNb2RpZmllciByYW5kb21pemF0aW9uIiwwXSxbIk0gfCBNb2RpZmllciBtb2RlIiw3XSxbIk0gfCBNb2RpZmllciByYW5kb21pemF0aW9uIiw4XSxbIk1OIHwgTW9kaWZpZXIgcmFuZG9taXphdGlvbiIsMF0sWyJTIHwgTW9kaWZpZXIgbW9kZSIsNl0sWyJTIHwgTW9kaWZpZXIgcmFuZG9taXphdGlvbiIsMF0sWyJETSB8IE1vZGlmaWVyIGRlZ3JlZSIsMTBdLFsiTSB8IE1vZGlmaWVyIGRlZ3JlZSIsMTRdLFsiQSB8IE1vZGlmaWVyIHJhbmRvbWl6YXRpb24iLDEwXSxbIk1OIHwgTW9kaWZpZXIgbW9kZSIsMV0sWyJBRCB8IE1vZGlmaWVyIHJhbmRvbWl6YXRpb24iLDBdXSwiQ29uZmlncyI6W10sIlNldHRpbmdzIjpbWyJDdXN0b20gYW50aWFpbSIsdHJ1ZV0sWyJDb25kaXRpb24iLDFdLFsiRWRnZSB5YXciLGZhbHNlXSxbIlJhbmRvbSBkZXN5bmMgc2lkZSIsdHJ1ZV0sWyJBbnRpIGJydXRlZm9yY2UiLHRydWVdLFsiQW50aSBicnV0ZSBtb2RlIiwyXSxbIkFkYXB0aXZlIEFBIix0cnVlXV19"

configs.apply_default = function()
    pcall(libs.eui.import, libs.base64.decode(configs.default_config))
end

configs.reload_configs = function()
    local first_start = not libs.filesystem.is_directory(configs.dir)
    if (first_start) then
        libs.filesystem.create_directory(configs.dir, "")
    end

    if (first_start) then
        configs.apply_default()
    end
    libs.filesystem.write(configs.default_dir, configs.default_config)
    ui.configs.list.ref:set_items(libs.filesystem.get_files())
end

-- cloud configs (owners, Oct 2026: "a cloud cfg ... nem működik"): the old azura.uno socket is gone, the configs are on
-- our license server next to the gamesense lua's (lua=pm keeps them apart). The list and loading need nothing; sharing,
-- updating and deleting need the key: the Primordial loader keeps it in csgo/specter/key.txt (the dev build reads it
-- from there too), the HWID is the loader's (the server locked the key to it). A config goes up in 3000 char parts
-- (a URL can not carry it whole): part 0 first (it starts the upload on the server), then the rest together
local cloud = { items = {}, part = 3000 }

cloud.url = function(s)
    return (tostring(s):gsub("([^%w%-_.~])", function(c) return string.format("%%%02X", c:byte()) end))
end

-- the HWID of the Primordial loader (same text, same hash)
cloud.hwid = function()
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

-- "&key=..&hwid=.." for the server, nil (and a message) without a saved key
cloud.auth = function()
    local ok, exists = pcall(libs.filesystem.exists, "specter/key.txt", "MOD")
    local key = ""
    if (ok and exists) then
        local ok2, text = pcall(libs.filesystem.read, "specter/key.txt")
        key = ok2 and tostring(text):match("^%s*(.-)%s*$") or ""
    end
    if (key == "" and info.plan == "dev") then
        -- the dev build has no key: the server takes it as dev=1 + the user name (owners, Oct 2026: "dev can upload to cloud too")
        return "&dev=1&who=" .. cloud.url(info.user)
    end
    if (key == "") then
        notifications.create("Specter", "Log in once with the Specter loader to share configs (your key is saved then).",
            notifications.types.warning)
        return nil
    end
    return "&key=" .. cloud.url(key) .. "&hwid=" .. cloud.url(cloud.hwid())
end

-- GET from the server, the callback gets the parsed JSON (nil when the server did not answer / sent no JSON)
cloud.get = function(path, callback)
    libs.tools.http:get(presence.server .. path, function(response)
        local ok, data = pcall(libs.json.parse, response.body or "")
        callback((ok and type(data) == "table") and data or nil)
    end)
end

-- the selected row of the cloud list: { name, author }
cloud.selected = function()
    local ok, item = pcall(ui.configs.cloud_list.ref.get_active_item_name, ui.configs.cloud_list.ref)
    return ok and cloud.items[item] or nil
end

configs.reload_cloud_configs = function(report)
    cloud.get("/configs?lua=pm", function(list)
        if (list == nil) then
            if (report) then
                notifications.create("Specter", "The cloud did not answer, try again.", notifications.types.warning)
            end
            return
        end
        table.sort(list, function(x, y) return (x.ts or 0) > (y.ts or 0) end)
        local rows = {}
        cloud.items = {}
        for _, c in ipairs(list) do
            if (type(c.name) == "string" and type(c.author) == "string") then
                local row = c.author .. " ~ " .. c.name
                cloud.items[row] = { name = c.name, author = c.author }
                rows[#rows + 1] = row
            end
        end
        ui.configs.cloud_list.ref:set_items(rows)
        if (report) then
            notifications.create("Specter", #rows .. " cloud config" .. (#rows == 1 and "" or "s") .. ".", notifications.types.information)
        end
    end)
end

-- the current settings to the cloud under `name` (a config of ours with that name is replaced)
cloud.upload = function(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if (name == "" or #name > 32) then
        notifications.create("Specter", "Pick a config name (1-32 characters).", notifications.types.warning)
        return
    end
    local auth = cloud.auth()
    if (auth == nil) then
        return
    end
    local ok, config_table = pcall(libs.json.parse, libs.eui.export())
    if (not ok or type(config_table) ~= "table") then
        notifications.create("Specter", "Unable to export the config!", notifications.types.failure)
        return
    end
    config_table["System"] = { { "version", config_version }, { "build", config_build } }
    local data = libs.base64.encode(libs.json.encode(config_table))
    local parts = {}
    for i = 1, #data, cloud.part do
        parts[#parts + 1] = data:sub(i, i + cloud.part - 1)
    end
    local base = "/configs/upload_part?lua=pm" .. auth .. "&name=" .. cloud.url(name) .. "&total=" .. #parts
    local done = false
    local function finished(res)
        if (done or res == nil) then
            return
        end
        if (res.ok == false) then
            done = true
            notifications.create("Specter", "The cloud refused the config (" .. tostring(res.reason) .. ").", notifications.types.failure)
        elseif (res.done) then
            done = true
            notifications.create("Specter", "Config \"" .. name .. "\" shared to the cloud by " .. tostring(res.author) .. ".",
                notifications.types.success)
            configs.reload_cloud_configs()
        end
    end
    notifications.create("Specter", "Uploading the config to the cloud...", notifications.types.information)
    cloud.get(base .. "&idx=0&data=" .. cloud.url(parts[1]), function(res)
        finished(res)
        if (done or res == nil) then
            if (res == nil) then
                notifications.create("Specter", "The cloud did not answer, try again.", notifications.types.warning)
            end
            return
        end
        for i = 2, #parts do
            cloud.get(base .. "&idx=" .. (i - 1) .. "&data=" .. cloud.url(parts[i]), finished)
        end
    end)
end

ui.reload_cloud_config = menu_add_button("Cloud configs", "Refresh",
    function()
        configs.reload_cloud_configs(true)
    end
)

-- Update: the current settings to the selected cloud config's name (yours: replaced, someone else's: your own copy)
ui.update_cloud_config = menu_add_button("Cloud configs", "Update",
    function()
        local sel = cloud.selected()
        if (sel == nil) then
            notifications.create("Specter", "Select a cloud config first.", notifications.types.warning)
            return
        end
        cloud.upload(sel.name)
    end
)

ui.delete_cloud_config = menu_add_button("Cloud configs", "Delete",
    function()
        local sel = cloud.selected()
        local auth = sel and cloud.auth()
        if (sel == nil or auth == nil) then
            return
        end
        cloud.get("/configs/delete?lua=pm" .. auth .. "&name=" .. cloud.url(sel.name), function(res)
            if (res ~= nil and res.ok) then
                notifications.create("Specter", "Config deleted from the cloud.", notifications.types.success)
                configs.reload_cloud_configs()
            elseif (res ~= nil and res.reason == "not_found") then
                notifications.create("Specter", "You can only delete your own configs.", notifications.types.warning)
            else
                notifications.create("Specter", "The cloud refused it (" .. tostring(res and res.reason or "no answer") .. ").",
                    notifications.types.failure)
            end
        end)
    end
)

ui.load_cloud_config = menu_add_button("Cloud configs", "Use",
    function()
        local sel = cloud.selected()
        if (sel == nil) then
            notifications.create("Specter", "Select a cloud config first.", notifications.types.warning)
            return
        end
        cloud.get("/configs/get?lua=pm&name=" .. cloud.url(sel.name) .. "&author=" .. cloud.url(sel.author), function(res)
            if (res == nil or not res.ok or type(res.data) ~= "string") then
                notifications.create("Specter", "The config is not on the cloud any more.", notifications.types.failure)
                return
            end
            local ok, decoded = pcall(libs.base64.decode, res.data)
            local tmp = ui.nav.slider:get()
            if (not ok or not pcall(libs.eui.import, decoded)) then
                notifications.create("Specter", "Unable to import the config!", notifications.types.failure)
                return
            end
            ui.nav.slider.ref:set(tmp)
            local settings = read_settings()
            settings.accent_color = get_accent_color() or settings.accent_color
            settings.text_color = get_text_color() or settings.text_color
            libs.filesystem.write(settings_file, libs.json.encode(settings))
            notifications.create("Specter", "Loaded \"" .. sel.name .. "\" by " .. sel.author .. " from the cloud.",
                notifications.types.success)
        end)
    end
)

-- file based

ui.import_config = menu_add_button("Configs", "Import from clipboard", function()
    local run_success, run_result = pcall(libs.base64.decode, clipboard.get())
    if (not run_success) then
        notifications.create("Specter", "Unable to decode the config!", notifications.types.failure)
        print("failed to decode config. (" .. run_result .. ")")
        
        return
    end

    run_success, config_table = pcall(libs.json.parse, run_result)
    if (not run_success) then
        notifications.create("Specter", "Unable to parse the config!", notifications.types.failure)
        print("failed to parse config. (" .. tostring(config_table) .. ")")
        
        return
    end

    if (type(config_table) ~= "table") then
        notifications.create("Specter", "The config is not a valid table!", notifications.types.failure)
        print("config is not a valid table.")
        
        return
    end

    local system_data = config_table["System"]
    if (not system_data) then
        notifications.create("Specter", "The config lacks build informations!", notifications.types.warning)
        print("config does not contain build informations.")
        
        return
    end

    local version, build
    for _, entry in ipairs(system_data) do
        if (type(entry) == "table" and #entry == 2) then
            if (entry[1] == "version") then
                version = entry[2]
            elseif (entry[1] == "build") then
                build = entry[2]
            end
        end
    end

    if (version ~= config_version) then
        notifications.create("Specter", "Config version mismatch!", notifications.types.warning)
        print("config version does not match.")
        
        return
    end

    if (build ~= config_build) then
        notifications.create("Specter", "Config build mismatch!", notifications.types.warning)
        print("config build does not match.")
        
        return
    end

    local tmp = ui.nav.slider:get()
    import_success, import_result = pcall(libs.eui.import, libs.json.encode(config_table))

    if (not import_success) then
        notifications.create("Specter", "Unable to import the config!", notifications.types.failure)
        print("failed to import config. (" .. import_result .. ")")
    else
        notifications.create("Specter", "Config successfully imported from clipboard!", notifications.types.success)
        print("successfully imported config from clipboard.")

        local settings = read_settings()

        settings.accent_color = get_accent_color() or settings.accent_color
        settings.text_color = get_text_color() or settings.text_color
        
        libs.filesystem.write(settings_file, libs.json.encode(settings))
        ui.nav.slider.ref:set(tmp)
    end
end)

ui.export_config = menu_add_button("Configs", "Export to clipboard", function()
    local config = libs.eui.export()
    local config_table = libs.json.parse(config)
    
    config_table["System"] = {
        {"version", config_version},
        {"build", config_build}
    }

    clipboard.set(libs.base64.encode(libs.json.encode(config_table)))

    notifications.create("Specter", "Config successfully exported to clipboard!", notifications.types.success)
    print("successfully exported config to clipboard.")
end)

ui.open_folder = menu_add_button("Configs", "Open folder",
    function()
        configs.ffi.shell_execute(configs.ffi.ivguisystem, "open", configs.path)
    end
)

ui.reload_config = menu_add_button("Configs", "Refresh",
    function()
        configs.reload_configs()
    end
)

-- Upload: the current settings to the cloud under the selected local config's name
ui.upload_config = menu_add_button("Configs", "Upload",
    function()
        local ok, item = pcall(ui.configs.list.ref.get_active_item_name, ui.configs.list.ref)
        cloud.upload(ok and tostring(item or ""):gsub("%.cfg$", "") or "")
    end
)

ui.create_config = menu_add_button("Configs", "Create", function()
    local name = ui.configs.config_name:get()
    local dir = configs.dir .. "" .. name .. ".cfg"

    if (string.len(name) <= 0) then
        return
    end

    if (libs.filesystem.exists(dir)) then
        notifications.create("Specter", "Config already exists!", notifications.types.warning)
        print("config already exists.")
    
        return
    end
    
    libs.filesystem.write(dir, "")
    configs.reload_configs()
    
    notifications.create("Specter", "Config created successfully!", notifications.types.success)
    print("config has been created successfully.")
end)

ui.delete_config = menu_add_button("Configs", "Delete", function()
    local active = ui.configs.list.ref:get_active_item_name()
    local dir = configs.dir .. "" .. active
    
    if (active == "default.cfg") then
        notifications.create("Specter", "Deletion of the default config is not permitted!", notifications.types.warning)
        print("deletion of the default config is not permitted.")
        
        return
    end
    
    if (not libs.filesystem.exists(dir)) then
        notifications.create("Specter", "The specified config does not exist!", notifications.types.failure)
        print("config does not exist.")
        
        return
    end
    
    libs.filesystem.delete(dir, "game")
    configs.reload_configs()
    
    notifications.create("Specter", "Config deleted successfully!", notifications.types.success)
    print("config has been deleted successfully.")
end)

ui.save_config = menu_add_button("Configs", "Save", function()
    local cur = ui.configs.list.ref:get_active_item_name()
    if (cur == "default.cfg") then
        notifications.create("Specter", "Saving to the default config is not allowed!", notifications.types.warning)
        print("saving to the default config is not allowed.")
        
        return
    end
    
    local dir = configs.dir .. "" .. cur
    if (not libs.filesystem.exists(dir)) then
        notifications.create("Specter", "The specified config does not exist!", notifications.types.failure)
        print("config does not exist.")
        
        return
    end
    
    local config = libs.eui.export()
    local config_table = libs.json.parse(config)

    config_table["System"] = {
        {"version", config_version},
        {"build", config_build}
    }
    
    config = libs.base64.encode(libs.json.encode(config_table))
    libs.filesystem.write(dir, config)
    configs.remember(cur)
    
    notifications.create("Specter", "Config saved successfully!", notifications.types.success)
    print("config has been saved successfully.")
end)

-- loads a config file of csgo/specter/ (the Use button, and the start of the lua: the last config used comes back by itself, owners,
-- Oct 2026: "when you reload it, it automatically puts up the last config you used"); quiet = no notifications at the start
configs.load_named = function(cur, quiet)
    local notify = quiet and function() end or notifications.create
    local dir = configs.dir .. cur

    if (not libs.filesystem.exists(dir)) then
        notify("Specter", "The specified config does not exist!", notifications.types.failure)
        print("config does not exist.")
        
        return
    end

    local config, read_error = libs.filesystem.read(dir)
    if (not config) then
        notify("Specter", "Unable to read config!", notifications.types.failure)
        print("failed to read config. (" .. tostring(read_error) .. ")")
        
        return
    end

    local success, decoded_config = pcall(libs.base64.decode, config)
    if (not success) then
        notify("Specter", "Unable to decode the config!", notifications.types.failure)
        print("failed to decode config. (" .. tostring(decoded_config) .. ")")
        
        return
    end

    success, config_table = pcall(libs.json.parse, decoded_config)
    if (not success) then
        notify("Specter", "Unable to parse the config!", notifications.types.failure)
        print("failed to parse config. (" .. tostring(config_table) .. ")")
        
        return
    end

    if (type(config_table) ~= "table") then
        notify("Specter", "Config is not a valid table!", notifications.types.failure)
        print("config is not a valid table.")
        
        return
    end

    local system_data = config_table["System"]
    if (not system_data) then
        notify("Specter", "The config lacks build informations!", notifications.types.warning)
        print("config does not contain build informations.")
        
        return
    end

    local version, build
    for _, entry in ipairs(system_data) do
        if (type(entry) == "table" and #entry == 2) then
            if (entry[1] == "version") then
                version = entry[2]
            elseif (entry[1] == "build") then
                build = entry[2]
            end
        end
    end

    if (version ~= config_version) then
        notify("Specter", "Config version mismatch!", notifications.types.warning)
        print("config version does not match.")
        
        return
    end

    if (build ~= config_build) then
        notify("Specter", "Config build mismatch!", notifications.types.warning)
        print("config build does not match.")
        
        return
    end

    local tmp = ui.nav.slider:get()
    success, import_error = pcall(libs.eui.import, decoded_config)

    if (not success) then
        notify("Specter", "Unable to import the config!", notifications.types.failure)
        print("failed to import config. (" .. tostring(import_error) .. ")")
    else
        notify("Specter", "Config loaded successfully!", notifications.types.success)
        print("config has been loaded successfully.")

        local settings = read_settings()

        settings.accent_color = get_accent_color() or settings.accent_color
        settings.text_color = get_text_color() or settings.text_color
        settings.last_config = cur

        libs.filesystem.write(settings_file, libs.json.encode(settings))
        ui.nav.slider.ref:set(tmp)
    end
end

-- the last config that was loaded or saved is remembered in settings.json
configs.remember = function(name)
    local settings = read_settings()
    if (settings.last_config ~= name) then
        settings.last_config = name
        libs.filesystem.write(settings_file, libs.json.encode(settings))
    end
end

-- at the start: the config used last, when it is still there (the first start applies the default one, see reload_configs)
configs.restore_last = function()
    local name = read_settings().last_config
    if (type(name) ~= "string" or name == "" or name == "default.cfg" or not libs.filesystem.exists(configs.dir .. name)) then
        return
    end
    configs.load_named(name, true)
end

ui.load_config = menu_add_button("Configs", "Use", function()
    configs.load_named(ui.configs.list.ref:get_active_item_name(), false)
end)

--- @endregion

--- @info: lua network, clantag [sync]
--- @region: clantag

local clantag_prev
clan_anim = function(indices)
    local tickinterval = globals.interval_per_tick()
    local tickcount = globals.tick_count() + math.floor(engine_get_latency(e_latency_flows.INCOMING) + 0.21 / tickinterval + 0.5)

    return clantag[indices[math.floor(tickcount / math.floor(0.25 / tickinterval + 0.45) % #indices) + 1] + 1]
end

-- user detection (owners, Oct 2026: like the original lua, through our own server): the players of our game who run
-- Specter get the moon on the scoreboard and a row in "Specter Revealer". Every 30 s the license server hears that we are
-- online (a hash of our steam id, only with Shared ESP on) and is asked which of the players here are. No names leave the game
presence.hash = function(s)
    local h1, h2 = 5381, 52711
    s = "specter|" .. tostring(s)
    for i = 1, #s do
        local c = s:byte(i)
        h1 = (h1 * 33 + c) % 4294967296
        h2 = (h2 * 31 + c * 7) % 4294967296
    end
    return string.format("%08x%08x", h1, h2)
end

-- Steam64 must never pass through a Lua double: it exceeds exact integer precision.
presence.account_steam64 = function(account)
    account = tonumber(account)
    if (account == nil or account ~= account or account < 1 or account > 4294967295
        or account ~= math.floor(account)) then return nil end
    local base, add, out, carry = "76561197960265728", string.format("%.0f", account), {}, 0
    for i = #base, 1, -1 do
        local j = #add - (#base - i)
        local value = tonumber(base:sub(i, i)) + (j > 0 and tonumber(add:sub(j, j)) or 0) + carry
        out[i], carry = tostring(value % 10), math.floor(value / 10)
    end
    return table.concat(out)
end
presence.normalize_id = function(value)
    if (type(value) == "number") then return presence.account_steam64(value) end
    if (type(value) ~= "string" and type(value) ~= "cdata") then return nil end
    local text = tostring(value):gsub("ULL$", ""):gsub("LL$", ""):match("^%s*(.-)%s*$")
    if (#text == 17 and text:match("^%d+$") and text > "76561197960265728"
        and text <= "76561202255233023") then return text end
    local parity, half = text:match("^STEAM_[01]:([01]):(%d+)$")
    if (parity) then
        half = tonumber(half)
        return half and presence.account_steam64(half * 2 + tonumber(parity)) or nil
    end
    local account = text:match("^%[U:1:(%d+)%]$") or (#text <= 10 and text:match("^%d+$"))
    return account and presence.account_steam64(account) or nil
end
presence.identity = function(player)
    if (player == nil) then return nil end
    local ok, first, second = pcall(function() return player:get_steamids() end)
    local a, b = ok and presence.normalize_id(first) or nil, ok and presence.normalize_id(second) or nil
    local sid = b or a
    if (sid == nil) then
        local api = libs.tools.js2 and libs.tools.js2.GameStateAPI
        local success, value = pcall(function() return api.GetPlayerXuidStringFromEntIndex(player:get_index()) end)
        sid = success and presence.normalize_id(value) or nil
    end
    if (sid == nil) then return nil end
    local aliases, seen = { sid }, { [sid] = true }
    for _, value in ipairs({ first or false, second or false }) do
        if (type(value) == "string" and presence.normalize_id(value) == sid and not seen[value]) then
            aliases[#aliases + 1], seen[value] = value, true
        end
    end
    return { sid = sid, aliases = aliases }
end
presence.steamid = function(player)
    local identity = presence.identity(player)
    return identity and identity.sid or nil
end
presence.is_user = function(player)
    local sid = presence.steamid(player)
    for _, known in ipairs(esp.sync_user) do
        if (sid ~= nil and sid == known) then return true end
    end
    return false
end
presence.refresh_icons = function()
    for idx, row in pairs(presence.shown) do
        pcall(libs.tools.js.update, idx, presence.icon, presence.icon_ready, row.sid)
    end
end
-- An "S" badge remains visible while the moon is unavailable; retry image failures.
presence.install_icon = function()
    local now = globals.real_time()
    if (now < presence.icon_next - 60) then presence.icon_next = 0 end
    if (presence.icon_ready or presence.icon_busy or now < presence.icon_next) then return end
    local path = "materials/panorama/images/icons/specter_moon.png"
    local ok, exists = pcall(libs.filesystem.exists, path, "MOD")
    if (ok and exists) then
        presence.icon_ready = true
        presence.refresh_icons()
        return
    end
    pcall(libs.filesystem.create_directory, "materials/panorama/images/icons", "MOD")
    presence.icon_busy, presence.icon_next = now, now + 30
    local sent = pcall(libs.tools.http.download_image, libs.tools.http, presence.server .. "/moon.png", path,
        function(success)
            presence.icon_busy = nil
            local checked, saved = pcall(libs.filesystem.exists, path, "MOD")
            presence.icon_ready = success == true and checked and saved == true
            if (presence.icon_ready) then presence.refresh_icons() end
        end)
    if (not sent) then presence.icon_busy = nil end
end
presence.clear_view = function()
    presence.shown, esp.sync_user, shared_data = {}, {}, {}
    pcall(ui.nav.shared_esp.ref.set_items, ui.nav.shared_esp.ref, {})
    pcall(libs.tools.js.clear)
end
-- Invalidates pending callbacks as well as clearing map-local UI state.
presence.reset = function(announce)
    presence.epoch, presence.sequence = presence.epoch + 1, presence.sequence + 1
    presence.busy, presence.next, presence.last_success = nil, 0, nil
    presence.announced, presence.failures = {}, 0
    presence.clear_view()
    if (announce) then
        notifications.create("Specter", "Shared data has been reset!", notifications.types.success)
        print("shared data has been reset.")
    end
end
presence.failure = function(why)
    local now = globals.real_time()
    presence.failures = math.min(4, presence.failures + 1)
    presence.next = now + math.min(30, 2 ^ presence.failures * 2)
    presence.status = tostring(why)
    if (presence.report) then
        presence.report = false
        notifications.create("Specter", "Shared ESP: " .. presence.status .. ".", notifications.types.warning)
    end
end
-- what a user is called in the list / notification: "gs user" runs the gamesense lua (same hash, tag "gs"), "prim user" this one
presence.kind = function(version)
    return version == "gs" and "gs user" or ("prim user (" .. tostring(version) .. ")")
end
-- Verify each returned slot against the identity captured when the request began.
presence.apply = function(on, asked)
    local found, changed, names, unique = {}, false, {}, {}
    local me = entity_list_get_local_player()
    for hash, entry in pairs(asked) do
        local version = on[hash]
        if (version == "dev" or version == "beta" or version == "nightly" or version == "gs") then
            local player = entity_list_get_entity(entry.idx)
            if (presence.steamid(player) == entry.sid) then
                local previous = found[entry.idx]
                if (previous == nil or entry.canonical) then
                    found[entry.idx] = { sid = entry.sid, version = version, name = tostring(player:get_name()) }
                end
            end
        end
        unique[entry.idx] = true
    end
    for idx, row in pairs(found) do
        local old = presence.shown[idx]
        if (old == nil or old.sid ~= row.sid or old.name ~= row.name or old.version ~= row.version) then changed = true end
    end
    for idx in pairs(presence.shown) do if (found[idx] == nil) then changed = true end end
    if (changed) then
        presence.clear_view()
        local order = {}
        for idx in pairs(found) do order[#order + 1] = idx end
        table.sort(order)
        for _, idx in ipairs(order) do
            local row = found[idx]
            presence.shown[idx] = row
            if (me ~= nil and idx == me:get_index()) then
                -- our own row is listed too (owners, Oct 2026: "my name didn't appear"), first, never announced
                table.insert(shared_data, 1, row.name .. " (you) ~ " .. presence.kind(row.version))
            else
                shared_data[#shared_data + 1] = row.name .. " ~ " .. presence.kind(row.version)
                esp.sync_user[#esp.sync_user + 1] = row.sid
                if (not presence.announced[row.sid]) then
                    presence.announced[row.sid] = true
                    names[#names + 1] = row.name .. (row.version == "gs" and " (gs)" or " (prim)")
                end
            end
        end
        pcall(ui.nav.shared_esp.ref.set_items, ui.nav.shared_esp.ref, shared_data)
        presence.refresh_icons()
    end
    if (#names > 0) then
        notifications.create("Specter", "Specter users here: " .. table.concat(names, ", "), notifications.types.information)
    end
    if (presence.report) then
        presence.report = false
        local count = 0
        for _ in pairs(unique) do count = count + 1 end
        local visible = me ~= nil and found[me:get_index()] ~= nil
        local visibility = visible and "your badge is active"
            or (ui.utils.shared_esp:get() and "your badge is not confirmed yet" or "your visibility is off")
        local others = #shared_data - (visible and 1 or 0)
        notifications.create("Specter", "Shared ESP: " .. others .. " other user(s) found, " .. count
            .. " player(s) checked; " .. visibility .. ".",
            notifications.types.information)
    end
end
presence.update = function(force)
    -- PAINT also calls this outside a match so disconnects invalidate late replies.
    local connected = check_conditions()
    if (not connected) then
        if (presence.connected ~= false) then presence.reset(false) end
        presence.connected = false
        return
    end
    if (presence.connected == false) then presence.reset(false) end
    presence.connected = true
    local now, enabled = globals.real_time(), ui.utils.shared_esp:get()
    if (presence.enabled ~= nil and enabled ~= presence.enabled) then presence.reset(false) end
    presence.enabled = enabled
    local map = engine_get_level_name and engine_get_level_name() or nil
    if (presence.map ~= nil and map ~= presence.map) then presence.reset(false) end
    presence.map = map
    if (presence.last_success ~= nil and (now < presence.last_success or now - presence.last_success > 75)) then
        presence.clear_view()
        presence.last_success = nil
    end
    if (presence.icon_busy and (now < presence.icon_busy or now - presence.icon_busy > 25)) then
        presence.icon_busy = nil
        presence.icon_next = 0
    end
    presence.install_icon()
    if (presence.busy ~= nil) then
        if (now >= presence.busy.time and now - presence.busy.time < 25) then return end
        presence.sequence = presence.sequence + 1
        presence.busy = nil
        presence.failure("presence request timed out; retrying")
    end
    if (not force and now < presence.next and now > presence.next - 60) then return end
    local me = entity_list_get_local_player()
    local own = presence.identity(me)
    if (me == nil or own == nil) then
        if (next(presence.shown) ~= nil) then presence.clear_view() end
        presence.next = now + 2
        if (presence.report) then presence.failure("local Steam identity is not available yet; retrying") end
        return
    end
    local asked, list, own_hash = {}, {}, enabled and presence.hash(own.sid) or nil
    local function add(player, identity, aliases)
        for i, sid in ipairs(identity.aliases) do
            local hash = presence.hash(sid)
            if ((aliases or i == 1) and asked[hash] == nil and #list < 64) then
                asked[hash] = { idx = player:get_index(), sid = identity.sid, canonical = i == 1 }
                list[#list + 1] = hash
            end
        end
    end
    local peers = {}
    if (enabled) then add(me, own, false) end
    for _, player in pairs(entity_list_get_players() or {}) do
        if (player:get_index() ~= me:get_index()) then
            local identity = presence.identity(player)
            if (identity ~= nil) then
                add(player, identity, false)
                peers[#peers + 1] = { player = player, identity = identity }
            end
        end
    end
    for _, peer in ipairs(peers) do add(peer.player, peer.identity, true) end
    local version = presence.version == "beta" and "beta" or presence.version == "nightly" and "nightly" or "dev"
    local url = presence.server .. "/presence?t=" .. version .. "&q=" .. table.concat(list, ",")
    if (own_hash ~= nil) then url = url .. "&me=" .. own_hash end
    presence.sequence = presence.sequence + 1
    local request = { id = presence.sequence, epoch = presence.epoch, time = now, sid = own.sid, map = map }
    presence.busy, presence.next = request, now + 30
    local sent = pcall(libs.tools.http.get, libs.tools.http, url, function(response)
        if (presence.busy ~= request or request.epoch ~= presence.epoch) then return end
        presence.busy = nil
        local current = entity_list_get_local_player()
        if (not check_conditions() or presence.steamid(current) ~= request.sid or ui.utils.shared_esp:get() ~= enabled
            or (engine_get_level_name and engine_get_level_name() ~= request.map)) then
            presence.clear_view()
            presence.next = 0
            return
        end
        local ok, data = pcall(libs.json.parse, response and response.body or "")
        if (ok and type(data) == "table" and data.ok == true and type(data.on) == "table") then
            presence.last_success, presence.failures, presence.status = globals.real_time(), 0, "online"
            presence.apply(data.on, asked)
            -- Older scripts hash their primary Steam string. Register that alias
            -- as well while migrating, without sending a raw Steam ID or name.
            if (enabled and own.aliases[2] ~= nil) then
                local legacy = presence.hash(own.aliases[2])
                pcall(libs.tools.http.get, libs.tools.http, presence.server .. "/presence?t=" .. version
                    .. "&q=&me=" .. legacy, function() end)
            end
        else
            local why = ok and type(data) == "table" and data.reason or (response == nil and "no answer") or "bad answer"
            presence.failure("server error (" .. tostring(why) .. "); retrying")
        end
    end)
    if (not sent) then
        presence.busy = nil
        presence.failure("could not send presence request; retrying")
    end
end

-- report = the "Refresh players" button (the round start / connect refreshes say nothing)
on_shared_players = function(report)
    if (check_conditions()) then
        presence.report = presence.report or report == true
        presence.update(true)
    elseif (report == true) then
        notifications.create("Specter", "Shared ESP: join a game before refreshing players.", notifications.types.information)
    end
end

on_shared_esp = function(announce)
    presence.reset(announce == true)
end

on_chatsync = function(event)
    if (not ui.utils.synced_players:get(3)) then return end
    local entity = entity_list_get_player_from_userid(event.userid)
    local me = entity_list_get_local_player()
    if (entity ~= nil and me ~= nil and entity:get_index() ~= me:get_index() and presence.is_user(entity)) then
        chat_print("{blue}[{lightgreen}Specter{blue}]{white}:{yellow} A user said something on the chat{white}!")
    end
end

-- server list (owners, Oct 2026: "ha valaki elérhető egy külön tabban mutatja melyik szerveren van és lehet hozzá csatlakozni"):
-- the "Servers" page lists the Specter users who switched "Share my server" on (their server's ip:port, name, map, players) and
-- connects to the selected one. Opt in, off at every start; our own address is read from the net channel (GetAddress) and goes
-- to the license server (/servers) only while the box is on. The address of a row is checked before "connect" (a server list
-- is somebody else's text: never a console command)
servers = { next = 0, rows = {}, labels = "", sharing = false }
servers.valid = function(srv)
    if (type(srv) ~= "string") then return false end
    local a, b, c, d, port = srv:match("^(%d+)%.(%d+)%.(%d+)%.(%d+):(%d+)$")
    if (a == nil) then return false end
    a, b, c, d, port = tonumber(a), tonumber(b), tonumber(c), tonumber(d), tonumber(port)
    if (a > 255 or b > 255 or c > 255 or d > 255 or port < 1 or port > 65535) then return false end
    return not (a == 0 or a == 10 or a == 127 or a >= 224 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31)
        or (a == 169 and b == 254) or (a == 100 and b >= 64 and b <= 127))
end
servers.address = function()
    local ok, text = pcall(function()
        local iface = memory_create_interface("engine.dll", "VEngineClient014")
        local get_channel = ffi.cast("void*(__thiscall*)(void*)", memory_get_vfunc(iface, 78))
        local channel = get_channel(ffi.cast("void***", iface))
        local address = tonumber(ffi.cast("unsigned long", channel))
        if (address == nil or address == 0) then return nil end
        local get_address = ffi.cast("const char*(__thiscall*)(void*)", memory_get_vfunc(address, 1))
        local raw = get_address(ffi.cast("void***", channel))
        return raw ~= nil and ffi.string(raw) or nil
    end)
    return ok and servers.valid(text) and text or nil
end
servers.me = function()
    local own = presence.identity(entity_list_get_local_player())
    return own ~= nil and presence.hash(own.sid) or nil
end
servers.send = function(query, done)
    local version = presence.version == "beta" and "beta" or presence.version == "nightly" and "nightly" or "dev"
    pcall(libs.tools.http.get, libs.tools.http, presence.server .. "/servers?t=" .. version .. query, done or function() end)
end
servers.show = function(list)
    local rows, labels = {}, {}
    for _, row in ipairs(list) do
        if (type(row) == "table" and servers.valid(row.srv)) then
            local label = string.format("%s ~ %s ~ %d pl ~ %s", tostring(row.name):sub(1, 20), tostring(row.map):sub(1, 32),
                tonumber(row.players) or 0, row.srv)
            rows[label] = row
            labels[#labels + 1] = label
        end
    end
    servers.rows = rows
    local joined = table.concat(labels, "\n")
    if (joined ~= servers.labels) then
        servers.labels = joined
        pcall(ui.servers.list.set_items, ui.servers.list, labels)
    end
end
servers.update = function(force)
    local now = globals.real_time()
    local share, open = ui.servers.share:get(), ui.nav.slider:get() == 15
    if (servers.sharing and not share) then
        servers.sharing = false
        local me = servers.me()
        if (me ~= nil) then servers.send("&me=" .. me .. "&off=1") end
    end
    if (not force and not share and not open) then return end
    if (servers.busy ~= nil and now >= servers.busy and now - servers.busy < 15) then return end
    if (not force and now < servers.next and now > servers.next - 60) then return end
    servers.next = now + 20
    local query = ""
    local me = check_conditions() and servers.me() or nil
    local address = share and me ~= nil and servers.address() or nil
    if (address ~= nil) then
        local name = tostring(entity_list_get_local_player():get_name() or "user"):gsub(" ", "_"):gsub("[^%w_%-]", "")
        local map = tostring(engine_get_level_name_short and engine_get_level_name_short() or "?"):gsub("[^%w_]", "")
        local players = 0
        for _ in pairs(entity_list_get_players() or {}) do players = players + 1 end
        query = "&me=" .. me .. "&srv=" .. address .. "&nm=" .. name:sub(1, 20) .. "&mp=" .. (map ~= "" and map or "?") .. "&pl=" .. players
        servers.sharing = true
    elseif (me ~= nil) then
        query = "&me=" .. me
    end
    servers.busy = now
    servers.send(query, function(response)
        servers.busy = nil
        local ok, data = pcall(libs.json.parse, response and response.body or "")
        if (ok and type(data) == "table" and data.ok == true and type(data.list) == "table") then
            servers.show(data.list)
        elseif (force) then
            notifications.create("Specter", "Server list: no answer from the server.", notifications.types.warning)
        end
    end)
end
servers.connect = function()
    local ok, label = pcall(ui.servers.list.get_active_item_name, ui.servers.list)
    local row = ok and label and servers.rows[label] or nil
    if (row == nil or not servers.valid(row.srv)) then
        notifications.create("Specter", "Select a server in the list first.", notifications.types.warning)
        return
    end
    notifications.create("Specter", "Connecting to " .. row.name .. " (" .. row.srv .. ")", notifications.types.information)
    engine_execute_cmd("connect " .. row.srv)
end
servers.leave = function()
    if (servers.sharing) then
        servers.sharing = false
        local me = servers.me()
        if (me ~= nil) then servers.send("&me=" .. me .. "&off=1") end
    end
end

lets_sync = function()
    presence.update(false)
    servers.update(false)
end

run_clantag = function()
    if (ui.utils.clantag:get()) then
        local clantag = clan_anim({ 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 0 })
        local player_clantag = player_resource_get_prop("m_szClan", entity_list_get_local_player():get_index())
        
        if (clantag ~= clantag_prev) then
            if (player_clantag == "" or player_clantag ~= clantag) then
                if (game_rules_get_prop("m_gamePhase") == 5 or game_rules_get_prop("m_gamePhase") == 4) then
                    clantag = clan_anim({25})
                    if (not menu_find("misc", "utility", "general", "clantag"):get()) then
                        client_set_clantag(clantag)
                    end
                else
                    if (not menu_find("misc", "utility", "general", "clantag"):get()) then
                        client_set_clantag(clantag)
                    end
                end
            end
        end

        clantag_reset = 0
        clantag_prev = clantag

        return
    else
        if (clantag_reset < 1) then
            client_set_clantag("")
            clantag_reset = clantag_reset + 1
        end
        return
    end
end

--- @endregion

--- @info: advanced fast ladder with up and down selection
--- @region: fastladder

fast_ladder = function(cmd)
    if (ui.player.fast_ladder:get(1) or ui.player.fast_ladder:get(2)) then
        local local_player = entity_list_get_local_player()
        if (local_player:get_prop("m_MoveType") == 9) then
            local active_weapon = local_player:get_active_weapon()
            if (active_weapon ~= nil) then
                local data = active_weapon:get_weapon_data()
                if (data ~= nil) then
                    menu_find("antiaim", "main", "general", "ladder antiaim"):set(false)
                    menu_find("antiaim", "main", "general", "fast ladder move"):set(false)
                    
                    if (not data.type == 9 or not cmd:has_button(e_cmd_buttons.ATTACK)) then
                        local pitch = engine_get_view_angles()
                        local angle_value = 0
                
                        local abs_value = math.abs(angle_value)
                        if (cmd.move.x == 0) then
                            cmd.viewangles.x = 89
                            cmd.viewangles.y = cmd.viewangles.y + angle_value
                
                            if (abs_value > 0 and abs_value < 180 and cmd.move.y ~= 0) then
                                cmd.viewangles.y = cmd.viewangles.y - angle_value
                            end
                
                            if (abs_value == 180) then
                                if (cmd.move.y < 0) then
                                    cmd:remove_button(e_cmd_buttons.MOVELEFT)
                                    cmd:add_button(e_cmd_buttons.MOVERIGHT)
                                elseif (cmd.move.y > 0) then
                                    cmd:add_button(e_cmd_buttons.MOVELEFT)
                                    cmd:remove_button(e_cmd_buttons.MOVERIGHT)
                                end
                            end
                        elseif (cmd.move.x > 0 and ui.player.fast_ladder:get(1)) then
                            if (pitch.x < 45) then
                                cmd.viewangles.x = 89
                
                                cmd:remove_button(e_cmd_buttons.MOVELEFT)
                                cmd:add_button(e_cmd_buttons.MOVERIGHT)
                                
                                cmd:remove_button(e_cmd_buttons.FORWARD)
                                cmd:add_button(e_cmd_buttons.BACK)
                
                                if (cmd.move.y == 0) then
                                    cmd.viewangles.y = cmd.viewangles.y + 90
                                elseif (cmd.move.y < 0) then
                                    cmd.viewangles.y = cmd.viewangles.y + 150
                                elseif (cmd.move.y > 0) then
                                    cmd.viewangles.y = cmd.viewangles.y + 30
                                end
                            end
                        elseif (cmd.move.x < 0 and ui.player.fast_ladder:get(2)) then
                            cmd.viewangles.x = 89
                
                            cmd:add_button(e_cmd_buttons.MOVELEFT)
                            cmd:remove_button(e_cmd_buttons.MOVERIGHT)
                            
                            cmd:add_button(e_cmd_buttons.FORWARD)
                            cmd:remove_button(e_cmd_buttons.BACK)
                
                            if (cmd.move.y == 0) then
                                cmd.viewangles.y = cmd.viewangles.y + 90
                            elseif (cmd.move.y > 0) then
                                cmd.viewangles.y = cmd.viewangles.y + 150
                            elseif (cmd.move.y < 0) then
                                cmd.viewangles.y = cmd.viewangles.y + 30
                            end
                        end
                    else
                        return
                    end
                else
                    return
                end
            else
                return
            end
        else
            return
        end
    else
        return
    end
end

--- @endregion

--- @info: advanced super toss with multiple selection methods
--- @region: super_toss

toss.ang_vec = function(ang)
    return vec3_t(math.cos(ang.x * math.pi / 180) * math.cos(ang.y * math.pi / 180), math.cos(ang.x * math.pi / 180) * math.sin(ang.y * math.pi / 180), -math.sin(ang.x * math.pi / 180))
end

super_toss = function(cmd)
    if (ui.player.super_toss:get() ~= 1) then
        local local_player = entity_list_get_local_player()
        local active_weapon = local_player:get_active_weapon()

        if (local_player:get_prop("m_MoveType") ~= 9) then
            if (active_weapon ~= nil) then
                if (active_weapon:get_weapon_data()) then
                    if (active_weapon:get_prop("m_flThrowStrength")) then
                        toss.lastangles = engine_get_view_angles()
                        local ang_throw = vec3_t(cmd.viewangles.x, toss.lastangles.y, 0)
                    
                        ang_throw.x = ang_throw.x - (90 - math.abs(ang_throw.x)) * 10 / 90
                        ang_throw = toss.ang_vec(ang_throw)
                    
                        local throw_strength = math.clamp(active_weapon:get_prop("m_flThrowStrength"), 0, 1)
                        local fl_velocity = math.clamp(active_weapon:get_weapon_data().throw_velocity * 0.9, 15, 750)
                    
                        fl_velocity = fl_velocity * (throw_strength * 0.7 + 0.3)
                        fl_velocity = vec3_t(fl_velocity, fl_velocity, fl_velocity)
                    
                        local vec_throw = (ang_throw * fl_velocity + local_player:get_prop("m_vecVelocity") * vec3_t(1.45, 1.45, 1.45))
                        vec_throw = vec_throw:to_angle()
                    
                        local yaw_difference = toss.lastangles.y - vec_throw.y
                        local pitch_difference = toss.lastangles.x - vec_throw.x - 10
                        
                        while (yaw_difference > 180) do
                            yaw_difference = yaw_difference - 360
                        end
                    
                        while (yaw_difference < -180) do
                            yaw_difference = yaw_difference + 360
                        end

                        while (pitch_difference > 90) do
                            pitch_difference = pitch_difference - 45
                        end
                    
                        while (pitch_difference < -90) do
                            pitch_difference = pitch_difference + 45
                        end
                    
                        toss.target_angles.y = toss.lastangles.y + yaw_difference
                        toss.target_angles.x = math.clamp(toss.lastangles.x + pitch_difference, -89, 89)
                    
                        cmd.viewangles.y = toss.target_angles.y
                        if (ui.player.super_toss:get() == 2) then
                            if (bit.band(local_player:get_prop("m_fFlags"), bit.lshift(1, 0)) == 0) then
                                cmd.viewangles.x = toss.target_angles.x
                            end
                        elseif (ui.player.super_toss:get() == 3) then
                            cmd.viewangles.x = toss.target_angles.x
                        end
                        return
                    else
                        return
                    end
                else
                    return
                end
            else
                return
            end
        else
            return
        end
    else
        return
    end
end

--- @endregion

--- @info: nofall dmg when landing
--- @region: nofall

calculate_fall = function(length)
    local local_player = entity_list_get_local_player()
    local x, y, z = local_player:get_render_origin().x, local_player:get_render_origin().y, local_player:get_render_origin().z

    local max_radias = math.pi * 2
    local step = max_radias / 8

    for a = 0, max_radias, step do
        local pt_x, pt_y = ((10 * math.cos(a)) + x), ((10 * math.sin(a)) + y)
        
        local traced = trace_line(vec3_t(pt_x, pt_y, z), vec3_t(pt_x, pt_y, z - length), local_player)
        local fraction, entity = traced.fraction, traced.entity

        if (fraction ~= 1) then
            return true
        end
    end
    return false
end

no_fall = function(cmd)
    if (ui.misc.nofall_dmg:get()) then
        local velocity = entity_list_get_local_player():get_prop("m_vecVelocity").z
        local no_falldmg = nil

        if (velocity >= -500) then
            no_falldmg = false
        else
            if (calculate_fall(15)) then
                no_falldmg = false
            elseif (calculate_fall(75)) then
                no_falldmg = true
            end
        end

        if (velocity < -500) then
            if (no_falldmg) then
                cmd:add_button(e_cmd_buttons.DUCK)
            else
                cmd:remove_button(e_cmd_buttons.DUCK)
            end
            return
        else
            return
        end
    else
        return
    end
end

--- @endregion

--- @info: defensive safepoint
--- @region: safe def

-- Network budgets are measured in seconds; menu thresholds are milliseconds.
resolver.network = function()
    local function finite(value, lo, hi)
        value = tonumber(value)
        if (value == nil or value ~= value or math.abs(value) == math.huge) then return lo end
        return math.max(lo, math.min(hi, value))
    end
    local outgoing = finite(engine_get_latency(e_latency_flows.OUTGOING), 0, 1)
    local incoming = finite(engine_get_latency(e_latency_flows.INCOMING), 0, 1)
    local ping = (outgoing + incoming) * 1000
    local guarded = ui.ragebot.latency_guard:get()
        and ping >= ui.ragebot.latency_limit:get()
    return { outgoing = outgoing, incoming = incoming, ping = ping, high = guarded }
end
resolver.fast_target = function(ent)
    if (ent == nil or not ui.ragebot.fast_peek:get()) then return false end
    local flags = tonumber(ent:get_prop("m_fFlags")) or 0
    local p = resolver.data[ent:get_index()]
    local peek = ragebot_get_autopeek_pos()
    return bit.band(flags, 2) ~= 0 or (peek ~= nil and peek ~= false)
        or resolver.network().high
        or (p ~= nil and (p.defensive_until or 0) > globals.real_time())
end
safe_defensive = function(ctx, cmd, unpredicted_data)
    if (ctx.player == nil or resolver.fast_target(ctx.player)
        or (resolver.safe and resolver.safe[ctx.player:get_index()] == 3)) then return end
    if (ui.ragebot.safe_defensive:get()) then
        if (defensive:is_active(ctx.player)) then
            ctx:set_safepoint_state(true, e_hitscan_groups.HEAD)
        else
            return
        end
        return
    else
        return
    end
end

--- @endregion

--- @info: multipoint correction
--- @region: dmg pred

local damage = {
    scale = {
        stomach = 1.25,
        chest = 1,
        head = 4
    },

    calculate = function(self, player, hitbox)
        local local_player = entity_list_get_local_player()
        local weapon = local_player:get_active_weapon()
        
        if (weapon ~= nil) then
            local weapon_data = weapon:get_weapon_data()
            if (weapon_data ~= nil) then
                local armor = player:get_prop("m_ArmorValue")

                local dmg_after_range = (weapon_data.damage * math.pow(weapon_data.range_modifier, (local_player:get_prop("m_vecAbsOrigin"):dist(player:get_prop("m_vecAbsOrigin")) * 0.002)))
                local new_dmg = dmg_after_range * (weapon_data.armor_ratio * 0.5)

                if (dmg_after_range - (dmg_after_range * (weapon_data.armor_ratio * 0.5)) * 0.5 > armor) then
                    new_dmg = dmg_after_range - (armor / 0.5)
                end
                return new_dmg * self.scale[hitbox]
            else
                return 0
            end
        else
            return 0
        end
    end
}

-- HITSCAN runs per command and target (double tap: many in one frame): the group is picked once per tick and target
local dmg_pick = {}
dmg_prediction = function(ctx, cmd, unpredicted_data)
    if (ui.ragebot.multipoint_pred:get()) then
        if (not defensive:is_active(ctx.player)) then
            local enemy = ctx.player
            local nohead = resolver.safe ~= nil and resolver.safe[enemy:get_index()] == 3
            local tick = globals.tick_count()
            local cached = dmg_pick[enemy:get_index()]
            local k
            if (cached ~= nil and cached.tick == tick and cached.nohead == nohead) then
                k = cached.k
            else
                k = dmg_prediction_pick(enemy, nohead)
                dmg_pick[enemy:get_index()] = { tick = tick, nohead = nohead, k = k }
            end
            if (k) then
                local hitgroup = e_hitscan_groups[string.upper(k)]
                if (not resolver.fast_target(enemy)) then
                    ctx:set_hitchance(70, hitgroup)
                end
                ctx:set_hitscan_group_state(hitgroup, true, false)
            end
        end
    end
end

-- the first of head, chest, stomach that kills or does the min damage and a bullet reaches, false: none
dmg_prediction_pick = function(enemy, nohead)
    local local_player = entity_list_get_local_player()
    local local_pos = local_player:get_eye_position()
    local enemy_pos = {
        head = enemy:get_hitbox_pos(e_hitboxes.HEAD),
        chest = enemy:get_hitbox_pos(e_hitboxes.CHEST),
        stomach = enemy:get_hitbox_pos(e_hitboxes.PELVIS)
    }
    local enemy_dmg = {
        head = damage:calculate(enemy, "head"),
        chest = damage:calculate(enemy, "chest"),
        stomach = damage:calculate(enemy, "stomach")
    }

    -- head first (owners, Oct 2026: "nagyon sok a body hit"): `pairs` went through the three in the table's hash
    -- order, so the chest / stomach got the 70 % hitchance and the push while the head was shootable too. The head
    -- is skipped when Smart body aim took it out for this target (resolver.safe 3: only a lethal body shot)
    for _, k in ipairs({ "head", "chest", "stomach" }) do
        local v = enemy_dmg[k]
        if ((k ~= "head" or not nohead) and (v > enemy:get_prop("m_iHealth") or v > get_dmg())) then
            local bullet = trace_bullet(local_pos, enemy_pos[k], local_player, enemy)
            if (bullet.valid and (client_get_hitgroup_name(bullet.hitgroup) == k)) then
                return k
            end
        end
    end
    return false
end

--- @endregion

--- @info: boost the prediction time
--- @region: accuracy boost

accuracy_boost = function(ctx, cmd, unpredicted_data)
    -- Preserve native accuracy requirements on latency-sensitive peeks.
    -- Do not inject the script's 90% damage-accuracy requirement here.
    if (resolver.fast_target(ctx.player)) then return end
    if (ui.ragebot.accuracy_boost.enable_booster:get()) then
        if (ui.ragebot.accuracy_boost.booster_mode:get() == 1) then
            ctx:set_damage_accuracy(45)
        elseif (ui.ragebot.accuracy_boost.booster_mode:get() == 2) then
            ctx:set_damage_accuracy(90)
        end
        return
    else
        return
    end
end

--- @endregion

--- @info: anti afk
--- @region: antiafk

antiafk = function(cmd)
    if (ui.misc.antiafk:get()) then
        if (builder.afk_valid == true) then
            builder.afk = builder.afk + 1
            if (builder.afk > 128) then
                builder.afk = 0
                afk_direction = not afk_direction
            end
        end
    
        if (cmd:has_button(e_cmd_buttons.MOVELEFT)) then
            builder.afk_valid = false
        end
        
        if (cmd:has_button(e_cmd_buttons.MOVERIGHT)) then
            builder.afk_valid = false
        end
    
        if (cmd:has_button(e_cmd_buttons.FORWARD)) then
            builder.afk_valid = false
        end
        
        if (cmd:has_button(e_cmd_buttons.BACK)) then
            builder.afk_valid = false
        end
    
        if (builder.afk < 8 and builder.afk_valid) then
            cmd.move.x = 450 * (afk_direction and 1 or -1)
        end
        return
    else
        return
    end
end

--- @endregion

--- @info: it will defuse at 5.1 or 10.1 sec
--- @region: defuse bot

enemies_dead = function()
    for _, enemy in pairs(entity_list_get_players(true)) do
        if (enemy:is_alive()) then
            return false
        end
    end
    return true
end

remaining_ticks = function(player, bomb)
    local defuse_time = 10.1
    if (player:get_prop("m_bHasDefuser") == 1) then
        defuse_time = 5.1
    end
    return time_to_ticks(math.abs(global_vars_cur_time() - bomb:get_prop("m_flC4Blow")) - defuse_time)
end

defuse_bot = function(cmd)
    if (ui.misc.defuse_bot:get()) then
        local local_player = entity_list_get_local_player()
        if (local_player:get_prop("m_iTeamNum") ~= 3) then
            return false
        end
    
        local bomb = entity_list_get_entities_by_name("CPlantedC4")[1]
        if (not bomb or bomb:get_prop("m_bBombDefused") == 1) then
            return false
        end
    
        if (not enemies_dead()) then
            return false
        end
    
        local player_origin = local_player:get_render_origin()
        local bomb_origin = bomb:get_render_origin()
    
        if (vector_distance(player_origin, bomb_origin) > 75) then
            return false
        end
    
        local ticks_to_defuse = remaining_ticks(local_player, bomb)
        if (ticks_to_defuse <= 2) then
            cmd:add_button(e_cmd_buttons.USE)
            cmd.viewangles = angle_t(89, 0, 0)
            
            return true
        end
    else
        return false
    end
end

--- @endregion

--- @info: knifebot helper
--- @region: knifebot

knifebot_helper = function(cmd)
    if (ui.misc.knifebot_helper:get()) then
        local active_weapon = entity_list_get_entity(entity_list_get_local_player():get_prop("m_hActiveWeapon"))
        if (active_weapon ~= nil) then
            if (active_weapon:get_name() == "knife") then
                if (knife.countdown > globals.tick_count()) then
                    exploits_force_uncharge()
                    exploits_block_recharge()
                else
                    exploits_allow_recharge()
                end
                return
            else
                return
            end
        else
            return
        end
    else
        return
    end
end

--- @info: zeus vs rushers
--- @region: zeus rush

-- (owners, Oct 2026: "ha valaki jön felém késsel akkor zeust vesz elő és lezeusolja, és ha valaki zeussal akkor is zeust, ha
-- egy helyben állsz hamarabb lő a zeus"): an enemy that runs at us with a knife or a zeus makes us take our own zeus out, and the
-- zeus is fired by the lua once the enemy is in its range. The decision is a pure function (`zeus.decide`, tested); the game
-- calls are in `zeus_rush`. Standing still the shot is taken at the very edge of the range (the aim is not disturbed by our
-- own movement), moving it waits for a margin so the bolt does not fall short
-- the zeus is taken out only from a scout or an awp (owners, Oct 2026: "csak akkor valtson ha scout vagy awp van a kezembe"): with
-- any other weapon in hand nothing is switched
zeus = { RANGE = 182, EQUIP = { knife = 450, taser = 520 }, SNIPERS = { ssg08 = true, awp = true }, taken = false, equip_at = 0, threat_at = 0 }
-- enemies: { dist, closing (units / s towards us), holds = "knife" | "taser" | other, see = function() -> bool }
-- returns "equip" | "fire" | "restore" | nil
zeus.decide = function(st, now)
    local best_equip, best_fire
    for _, e in ipairs(st.enemies) do
        local limit = zeus.EQUIP[e.holds]
        if (limit ~= nil and e.dist <= limit and (e.closing > 40 or e.dist < 220)) then
            best_equip = true
        end
        local edge = zeus.RANGE - (st.speed < 5 and 2 or 12)
        if (e.dist <= edge and (best_fire == nil or e.dist < best_fire.dist)) then
            best_fire = e
        end
    end
    if (st.weapon == "taser") then
        if (st.clip ~= nil and st.clip <= 0) then
            return st.taken and "restore" or nil
        end
        if (best_fire ~= nil and best_fire.see()) then
            return "fire", best_fire
        end
        if (best_equip) then
            return nil
        end
        if (st.taken and now - st.threat_at > 1.5) then
            return "restore"
        end
        return nil
    end
    if (best_equip and st.has_zeus and zeus.SNIPERS[st.weapon] and now - st.equip_at > 0.6) then
        return "equip"
    end
    return nil
end

zeus_rush = function(cmd)
    if (not ui.misc.zeus_rush:get()) then return end
    local me = entity_list_get_local_player()
    if (me == nil or not me:is_alive() or game_rules_get_prop("m_bFreezePeriod") == true) then return end
    local now = globals.real_time()
    local weapon = entity_list_get_entity(me:get_prop("m_hActiveWeapon"))
    local name = weapon ~= nil and weapon:get_name() or ""
    -- "taken" = the zeus in hand is the one WE took out (only then it is put away); a "use" that did not give a zeus (we have
    -- none) is not repeated for a few seconds
    if (name == "taser") then
        if (zeus.pending) then zeus.taken, zeus.pending = true, false end
    else
        zeus.taken = false
        if (zeus.pending and now - zeus.equip_at > 0.7) then zeus.pending, zeus.equip_at = false, now + 4 end
    end
    local ok, st = pcall(function()
        local eye, vel = me:get_eye_position(), me:get_prop("m_vecVelocity")
        local enemies, shown = {}, 0
        for _, enemy in pairs(entity_list_get_players(true) or {}) do
            if (enemy:is_alive() and not enemy:is_dormant() and shown < 6) then
                local pos = enemy:get_hitbox_pos(e_hitboxes.CHEST)
                local held = entity_list_get_entity(enemy:get_prop("m_hActiveWeapon"))
                local held_name = held ~= nil and held:get_name() or ""
                if (held_name:find("knife", 1, true) or held_name == "bayonet") then held_name = "knife" end
                if (pos ~= nil) then
                    local dx, dy, dz = pos.x - eye.x, pos.y - eye.y, pos.z - eye.z
                    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if (dist < 700) then
                        shown = shown + 1
                        local ev = enemy:get_prop("m_vecVelocity")
                        local flat = math.max(0.001, math.sqrt(dx * dx + dy * dy))
                        local closing = ev ~= nil and -((ev.x * dx + ev.y * dy) / flat) or 0
                        enemies[#enemies + 1] = { dist = dist, closing = closing, holds = held_name, pos = pos, enemy = enemy,
                            see = function()
                                local tr = trace_line(eye, pos, enemy, 0x400B)
                                return tr ~= nil and type(tr.fraction) == "number" and tr.fraction >= 0.97
                            end }
                    end
                end
            end
        end
        return { enemies = enemies, speed = vel ~= nil and math.sqrt(vel.x * vel.x + vel.y * vel.y) or 0, weapon = name,
            clip = weapon ~= nil and tonumber(weapon:get_prop("m_iClip1")) or nil, taken = zeus.taken,
            has_zeus = true, equip_at = zeus.equip_at, threat_at = zeus.threat_at }, eye
    end)
    if (not ok or st == nil) then return end
    for _, e in ipairs(st.enemies) do
        if (zeus.EQUIP[e.holds] and e.dist <= zeus.EQUIP[e.holds]) then zeus.threat_at = now end
    end
    st.threat_at = zeus.threat_at
    local action, target = zeus.decide(st, now)
    if (action == "equip") then
        zeus.equip_at, zeus.pending = now, true
        engine_execute_cmd("use weapon_taser")
    elseif (action == "restore") then
        zeus.taken = false
        engine_execute_cmd("lastinv")
    elseif (action == "fire" and target ~= nil) then
        local eye = me:get_eye_position()
        local dx, dy, dz = target.pos.x - eye.x, target.pos.y - eye.y, target.pos.z - eye.z
        cmd.viewangles.x = math.deg(-math.atan2(dz, math.sqrt(dx * dx + dy * dy)))
        cmd.viewangles.y = math.deg(math.atan2(dy, dx))
        cmd:add_button(e_cmd_buttons.ATTACK)
        zeus.threat_at = now
    end
end

-- the double tap is off while the zeus is in hand (owners, Oct 2026: "ha zeusz van nálam automatikusan kikapcsolja a dt-t"): the charge is
-- emptied and kept empty (the same calls as the knifebot helper), given back as soon as another weapon is out
zeus.dt_off = false
zeus_dt = function()
    local me = entity_list_get_local_player()
    local weapon = me ~= nil and me:is_alive() and entity_list_get_entity(me:get_prop("m_hActiveWeapon")) or nil
    if (ui.misc.zeus_dt:get() and weapon ~= nil and weapon:get_name() == "taser") then
        zeus.dt_off = true
        exploits_force_uncharge()
        exploits_block_recharge()
    elseif (zeus.dt_off) then
        zeus.dt_off = false
        exploits_allow_recharge()
    end
end

--- @endregion

on_knifebot = function(event)
    if (ui.misc.knifebot_helper:get()) then
        local weapon = event.weapon
        local is_knife = string.match(weapon, "knife") or weapon == "bayonet"

        if (is_knife ~= nil) then
            local victim = entity_list_get_player_from_userid(event.userid)
            local attacker = entity_list_get_player_from_userid(event.attacker)
            
            if (victim ~= nil and attacker ~= nil) then
                if (attacker == entity_list_get_local_player()) then
                    knife.countdown = globals.tick_count() + 96
        
                    exploits_force_uncharge()
                    exploits_block_recharge()
                else
                    return
                end
                return
            else
                return
            end
        else
            return
        end
    else
        return
    end
end

--- @endregion

--- @info: evade message
--- @region: antibrute

for i = 1, 28 do
    evades.backtrack_poses[i] = vec3_t.new(0, 0, 0)
end

evades.remove_player = function(user_id)
    evades.player_list[tostring(user_id)] = nil
end

evades.add_player = function(user_id)
    local user_id_str = tostring(user_id)
    evades.player_list[user_id_str] = {
        name = entity_list_get_entity(user_id):get_name(),

        confirmation_dmg = false,
        last_shot = 0,

        shots = {
            hit = 0,
            miss = 0
        },

        bruteforce_data = {
            invert_hit = false,
            invert_miss = false,
            
            randomize_miss = false,
            randomize_hit = false,
            
            randomized_miss_desync = 0,
            randomized_hit_desync = 0
        }
    }
end

evades.create_ray = function(s, e)
    local ray = {}

    ray.orig = s
    ray.dir = vec3_t.new(e.x - s.x, e.y - s.y, e.z - s.z)

    local length = ray.dir:length()

    ray.dir.x = ray.dir.x / length
    ray.dir.y = ray.dir.y / length
    ray.dir.z = ray.dir.z / length

    return ray
end

evades.create_box = function(min, max)
    local box = {}
    
    box.min = min
    box.max = max

    return box
end

evades.intersect = function(ray, box)
    local min = box.min
    local max = box.max

    local t_min = (min.x - ray.orig.x) / ray.dir.x
    local t_max = (max.x - ray.orig.x) / ray.dir.x

    if (t_min > t_max) then
        local temp = t_min
        
        t_min = t_max
        t_max = temp
    end

    local ty_min = (min.y - ray.orig.y) / ray.dir.y
    local ty_max = (max.y - ray.orig.y) / ray.dir.y

    if (ty_min > ty_max) then
        local temp = ty_min
        
        ty_min = ty_max
        ty_max = temp
    end

    if (t_min > ty_max) or (ty_min > t_max) then
        return false
    end

    if (ty_min > t_min) then
        t_min = ty_min
    end

    if (ty_max < t_max) then
        t_max = ty_max
    end

    local tz_min = (min.z - ray.orig.z) / ray.dir.z
    local tz_max = (max.z - ray.orig.z) / ray.dir.z

    if (tz_min > tz_max) then
        local temp = tz_min
        
        tz_min = tz_max
        tz_max = temp
    end

    if (t_min > tz_max) or (tz_min > t_max) then
        return false
    end

    if (tz_min > t_min) then
        t_min = tz_min
    end

    if (tz_max < t_max) then
        t_max = tz_max
    end
    return true
end

update_bt = function()
    if (ui.utils.event_logs:get(6)) then
        evades.backtrack_poses[1] = entity_list_get_local_player():get_render_origin()
        for i = 28, 2, -1 do
            evades.backtrack_poses[i] = evades.backtrack_poses[i - 1]
        end
        return
    else
        return
    end
end

handle_playerlist = function()
    if (ui.utils.event_logs:get(6)) then
        for user_id_str, _ in pairs(evades.player_list) do
            local user_id = tonumber(user_id_str)
            local entity = entity_list_get_entity(user_id)

            if (entity == nil) then
                evades.remove_player(user_id)
            end
        end
        return
    else
        return
    end
end

on_brute = function(event)
    if (ui.utils.event_logs:get(6)) then
        if (event.name == "bullet_impact") then
            local shooter = entity_list_get_player_from_userid(event.userid)
            if (shooter ~= nil) then
                if (shooter:is_player() or shooter:is_enemy()) then
                    local shooter_idx = shooter:get_index()
                    local shooter_idx_str = tostring(shooter_idx)
            
                    local local_player = entity_list_get_local_player()
                    if (local_player ~= nil and local_player:is_valid() and local_player:is_alive() and local_player:is_player()) then
                        for idx, lp_origin in pairs(evades.backtrack_poses) do
                            local box_min, box_max = local_player:get_bounds()

                            local impact = vec3_t.new(event.x, event.y, event.z)
                            local ray = evades.create_ray(shooter:get_eye_position(), impact)
                
                            local length_players = ray.orig:dist(lp_origin)
                            local length_forward_lp = (ray.orig + ray.dir):dist(lp_origin)
                
                            if (length_forward_lp > length_players) then
                                return
                            end
                
                            local length_impact = ray.orig:dist(impact) + 20
                            if (length_impact < length_players) then
                                return
                            end
                
                            local box = evades.create_box(lp_origin + box_min, lp_origin + box_max)
                            local intersect = evades.intersect(ray, box)

                            if (intersect ~= false) then
                                local time = global_vars_tick_count()
                                if (not evades.player_list[shooter_idx_str]) then
                                    evades.add_player(shooter_idx)
                                    evades.player_list[shooter_idx_str].last_shot = time
                                end

                                local t_enm_data = evades.player_list[shooter_idx_str]
                                if (t_enm_data.last_shot == time) then
                                    return
                                end

                                client_delay_call(function()
                                    local bt_start = math.clamp(idx - 1, 0, 28)
                                    local bt_end = math.clamp(idx + 1, 0, 28)
                
                                    if (t_enm_data.confirmation_dmg) then
                                        t_enm_data.shots.hit = t_enm_data.shots.hit + 1
                
                                        t_enm_data.bruteforce_data.invert_hit = not t_enm_data.bruteforce_data.invert_hit
                                        t_enm_data.bruteforce_data.randomize_hit = not t_enm_data.bruteforce_data.randomize
                                        t_enm_data.bruteforce_data.randomized_hit_desync = client_random_float(0, 1)
                
                                        t_enm_data.bruteforce_data.invert_miss = false
                                        t_enm_data.bruteforce_data.randomize_miss = false

                                        local hit = t_enm_data.shots.hit
                                        local miss = t_enm_data.shots.miss

                                        local name = t_enm_data.name

                                        local percentage = (hit / (hit + miss)) * 100
                                        local rounded_percentage = math.floor(percentage * 100) / 100

                                        if (local_player ~= nil and local_player:is_valid() and local_player:is_alive() and local_player:is_player()) then
                                            print("shot by ", get_text_color(), name, get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "state: ", specter_color_t(168, 168, 168), global.current_state, ", ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), bt_end, "t") -- specter_color_t(108, 108, 108), "total: ", specter_color_t(168, 168, 168), t_enm_data.shots.hit, "/", t_enm_data.shots.miss + t_enm_data.shots.hit, specter_color_t(108, 108, 108), " (", specter_color_t(168, 168, 168), rounded_percentage, "%%", specter_color_t(108, 108, 108), ")")
                                        end
                                    else
                                        t_enm_data.shots.miss = t_enm_data.shots.miss + 1

                                        evades.vars.last_miss = time

                                        t_enm_data.bruteforce_data.invert_miss = not t_enm_data.bruteforce_data.invert_miss
                                        t_enm_data.bruteforce_data.randomize_miss = not t_enm_data.bruteforce_data.randomize
                                        t_enm_data.bruteforce_data.randomized_miss_desync = client_random_float(0, 1)
                
                                        t_enm_data.bruteforce_data.invert_hit = false
                                        t_enm_data.bruteforce_data.randomize_hit = false

                                        local hit = t_enm_data.shots.hit
                                        local miss = t_enm_data.shots.miss

                                        local name = t_enm_data.name
                                        
                                        local percentage = (hit / (hit + miss)) * 100
                                        local rounded_percentage = math.floor(percentage * 100) / 100

                                        if (local_player ~= nil and local_player:is_valid() and local_player:is_alive() and local_player:is_player()) then
                                            if (local_player:get_name() ~= name) then
                                                print("evaded ", get_text_color(), name, specter_color_t(168, 168, 168), "'s shot", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "state: ", specter_color_t(168, 168, 168), global.current_state, ", ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), bt_end, "t") -- specter_color_t(108, 108, 108), "total: ", specter_color_t(168, 168, 168), t_enm_data.shots.hit, "/", t_enm_data.shots.miss + t_enm_data.shots.hit, specter_color_t(108, 108, 108), " (", specter_color_t(168, 168, 168), rounded_percentage, "%%", specter_color_t(108, 108, 108), ")")
                                                evades.send_data = true
                                            end
                                        end
                                    end
                                    t_enm_data.confirmation_dmg = false
                                end, 0.2)

                                t_enm_data.last_shot = time
                                if (evades.send_data) then
                                    evades.send_data = false
                                    cl_logs.add_log("evades")
                                end
                                break
                            end
                        end
                    else
                        return
                    end
                else
                    return
                end
            else
                return
            end
        elseif (event.name == 'player_hurt') then
            local shooter = entity_list_get_player_from_userid(event.attacker)
            if (shooter ~= nil) then
                if (shooter:is_player() and shooter:is_enemy()) then
                    local local_player = entity_list_get_local_player()

                    local hit_user_id = event.userid
                    local hit_player = entity_list_get_player_from_userid(hit_user_id)
            
                    if (hit_player ~= nil and hit_player:is_valid() and hit_player:is_player()) then
                        if (local_player ~= nil and local_player:is_valid() and local_player:is_alive() and local_player:is_player()) then
                            if (hit_player:get_index() == local_player:get_index()) then
                                local user_idx = shooter:get_index()
                                local user_idx_str = tostring(user_idx)
                        
                                if (not evades.player_list[user_idx_str]) then
                                    evades.add_player(user_idx)
                                end

                                local t_enm_data = evades.player_list[user_idx_str]
                                t_enm_data.confirmation_dmg = true

                                client_delay_call(function()
                                    t_enm_data.confirmation_dmg = false
                                end, 0.5)
                                return
                            else
                                return
                            end
                        else
                            return
                        end
                    else
                        return
                    end
                else
                    return
                end
            else
                return
            end
        elseif (event.name == 'player_death') then
            local dead_player = entity_list_get_player_from_userid(event.userid)
            local local_player = entity_list_get_local_player()

            if (dead_player ~= nil) then
                if (dead_player:is_enemy()) then
                    if (local_player ~= nil and local_player:is_valid() and local_player:is_alive() and local_player:is_player()) then
                        local enm_idx = dead_player:get_index()
                        if (local_player:get_index() == enm_idx) then
                            local time = global_vars_tick_count()
                            if (not evades.player_list[tostring(enm_idx)]) then
                                evades.add_player(enm_idx)
                            end
                
                            local t_enm_data = evades.player_list[tostring(enm_idx)]
                            t_enm_data.shots.hit = t_enm_data.shots.hit + 1
                            
                            t_enm_data.bruteforce_data.invert_hit = not t_enm_data.bruteforce_data.invert_hit
                            t_enm_data.bruteforce_data.randomize_hit = not t_enm_data.bruteforce_data.randomize
                            t_enm_data.bruteforce_data.randomized_hit_desync = client_random_float(0, 1)
                
                            t_enm_data.bruteforce_data.invert_miss = false
                            t_enm_data.bruteforce_data.randomize_miss = false

                            evades.vars.last_hit = time
                            return
                        else
                            return
                        end
                    else
                        return
                    end
                else
                    return
                end
            else
                return
            end
        end
    end
end

--- @endregion

--- @info: repeats everyone's message
--- @region: talkback

on_talkback = function(event)
    if (ui.player.talk_back:get()) then
        local entity = entity_list_get_player_from_userid(event.userid)
        if (entity ~= nil) then
            local me = entity_list_get_local_player()
            if (me ~= nil and entity:get_index() ~= me:get_index()) then
                local is_sync = presence.is_user(entity)

                if (is_sync) then
                    if (ui.utils.synced_players:get(2)) then
                        return
                    else
                        message = event.text
                        if (not message:find("^/") and not message:find("^!")) then
                            engine_execute_cmd('say ' .. message)
                        end
                        return
                    end
                else
                    message = event.text
                    if (not message:find("^/") and not message:find("^!")) then
                        engine_execute_cmd('say ' .. message)
                    end
                    return
                end
            else
                return
            end
        else
            return
        end
    else
        return
    end
end

--- @endregion

--- @info: trash talk
--- @region: killsay

local old_phrase = ""
on_killsay = function(event)
    if (ui.player.trash_talk:get() ~= 1) then
        local attacker = entity_list_get_player_from_userid(event.attacker)
        local user_id = entity_list_get_player_from_userid(event.userid)

        if (attacker ~= nil and user_id ~= nil) then
            if (attacker == entity_list_get_local_player()) then
                if (entity_list_get_local_player():get_steamids() ~= user_id:get_steamids()) then
                    if (ui.player.trash_talk:get() == 2) then
                        local txt
                        repeat
                            txt = phrases_old[math.random(1, #phrases_old)]
                        until txt ~= old_phrase
                        client_delay_call(function()
                            engine_execute_cmd('say ' .. txt)
                        end, 1.8)
                        old_phrase = txt
                    elseif (ui.player.trash_talk:get() == 3) then
                        local txt
                        repeat
                            txt = phrases_fem[math.random(1, #phrases_fem)]
                        until txt ~= old_phrase
                        client_delay_call(function()
                            engine_execute_cmd('say ' .. txt)
                        end, 1.8)
                        old_phrase = txt
                    elseif (ui.player.trash_talk:get() == 4) then
                        local txt
                        repeat
                            txt = phrases_new[math.random(1, #phrases_new)]
                        until txt ~= old_phrase
                        client_delay_call(function()
                            engine_execute_cmd('say ' .. txt)
                        end, 1.8)
                        old_phrase = txt
                    elseif (ui.player.trash_talk:get() == 5) then
                        local txt
                        repeat
                            txt = phrases_roast[math.random(1, #phrases_roast)]
                        until txt ~= old_phrase
                        old_phrase = txt
                        -- the name goes into  say "..." : a quote / semicolon in it would end the command
                        local name = tostring(user_id:get_name() or ""):gsub('[%c";%%]', '')
                        txt = txt:gsub("{name}", function() return name ~= "" and name or "bot" end)
                        -- one chat line per " / " part, like the gamesense kill say (a joined line can pass the chat limit)
                        local part_no = 0
                        for part in (txt .. " / "):gmatch("(.-) / ") do
                            client_delay_call(function()
                                engine_execute_cmd('say "' .. part:gsub('[";]', '') .. '"')
                            end, 1.8 + part_no * 0.9)
                            part_no = part_no + 1
                        end
                    end
                    return
                else
                    return
                end
            else
                return
            end
        else
            return
        end
    else
        return
    end
end

--- @endregion

--- @info: tesla effect
--- region: effects

on_tesla = function(shot)
    if (ui.visuals.tesla.enable_tesla:get()) then
        local x, y, z = 0, 0, 0
        local tesla_info = ffi.new("struct tesla_info_t")

        tesla_info.m_flbeamwidth = ui.visuals.tesla.width:get()
        tesla_info.m_flradius = ui.visuals.tesla.radius:get()
        tesla_info.m_entindex = engine_get_local_player_index()
        tesla_info.m_color = { ui.tesla_color:get().r / 255, ui.tesla_color:get().g / 255, ui.tesla_color:get().b / 255 }
        tesla_info.m_pos = { shot.hitpoint_pos.x + 10, shot.hitpoint_pos.y, shot.hitpoint_pos.z + 10 }
        tesla_info.m_fltimevis = ui.visuals.tesla.delay:get()
        tesla_info.m_nbeams = ui.visuals.tesla.beams:get()
        tesla_info.m_spritename = true and "sprites/physbeam.vmt" or "sprites/purplelaser1.vmt"

        fs_tesla(tesla_info)
    else
        return
    end
    return
end

--- @endregion

--- @info: fast weapon switch
--- @region: fast switch

on_zeus = function(shot)
    if (ui.misc.fast_switch:get()) then
        local active_weapon = entity_list_get_local_player():get_active_weapon()
        if (active_weapon ~= nil) then
            if (active_weapon:get_name() == "taser") then
                exploits.force_anti_exploit_shift()
                
                engine_execute_cmd("slot2")
                engine_execute_cmd("slot1")
            else
                return
            end
            return
        else
            return
        end
    else
        return
    end
end

on_nade = function(event)
    if (ui.misc.fast_switch:get()) then
        if (entity_list_get_player_from_userid(event.userid) == entity_list_get_local_player()) then
            exploits.force_anti_exploit_shift()
            
            engine_execute_cmd("slot2")
            engine_execute_cmd("slot1")
        else
            return
        end
        return
    else
        return
    end
end

--- @endregion

--- @info: optimized backtrack
--- @region: backtrack system

-- Backtracking itself is Primordial's: its records, and the tick count it sends with the shot (the server rewinds the
-- players to that tick). The old code here wrote cmd.tick_count on every command from a record of the enemy nearest the
-- crosshair minus extra "dynamic ticks", so a shot the aimbot left the tick count of went to a time it did not aim at.
-- What a lua can add: more fake latency (the server takes records within 0.2 s of our real + fake latency, so older
-- records become hittable) and the order the aimbot picks targets in.
local backtrack = { amount = nil, saved = nil, peekers = {}, predict_tick = 0,
    no_ping = { knife = true, bayonet = true, hegrenade = true, flashbang = true, smokegrenade = true, molotov = true,
                incgrenade = true, decoy = true, c4 = true } }
do
    local ok, item = pcall(menu_find, "aimbot", "general", "fake ping", "ping amount")
    backtrack.ping = ok and item or nil
end

-- Fake ping uses a 100/200 ms total RTT budget with protection enabled.
-- Guarded high ping adds nothing; the saved value returns when disabled.
backtrack.update = function(local_player)
    if (backtrack.ping == nil) then
        return
    end

    if (not ui.ragebot.backtrack.enable_backtrack:get()) then
        if (backtrack.saved ~= nil) then
            backtrack.ping:set(backtrack.saved)
            backtrack.saved, backtrack.amount = nil, nil
        end
        return
    end

    local want = 0
    local weapon = local_player:get_active_weapon()
    if (weapon ~= nil and not backtrack.no_ping[weapon:get_name()]) then
        for _, enemy in pairs(entity_list_get_players(true) or {}) do
            if (enemy:is_alive()) then
                want = ui.ragebot.backtrack.extended_backtrack:get() and 500 or 100
                break
            end
        end
    end
    if (ui.ragebot.latency_guard:get()) then
        local net = resolver.network()
        local now = globals.real_time()
        if (net.high) then backtrack.high_until = now + 0.5 end
        -- Added fake latency must fit inside the desired TOTAL RTT budget.
        want = (backtrack.high_until or 0) > now and 0 or math.max(0, math.floor(want - net.ping))
    end
    -- a value the user set by hand wins: we only write when the slider still holds what we wrote last, else it is
    -- theirs now (kept as the floor, so the round change / no enemy / knife never drops it)
    local cur = backtrack.ping:get()
    if (backtrack.saved == nil or (backtrack.amount ~= nil and cur ~= backtrack.amount)) then
        backtrack.saved = cur
    end
    if (backtrack.saved ~= nil and backtrack.saved > want and (backtrack.high_until or 0) <= globals.real_time()) then
        want = backtrack.saved
    end
    if (backtrack.cap ~= nil and want > backtrack.cap) then want = backtrack.cap end
    if (want ~= backtrack.amount) then
        backtrack.ping:set(want)
        if (want > 200 and backtrack.ping:get() < want) then
            backtrack.cap = backtrack.ping:get()
        end
        backtrack.amount = want
    end
end
backtrack.horizon = function(net, ducking)
    local interval = math.max(0.001, math.min(0.1, globals.interval_per_tick()))
    local limit = ducking and 0.04 or net.high and 0.06 or 0.10
    return math.min(limit, math.max(interval, net.outgoing + interval * 2))
end
backtrack.predict = function(local_player)
    local tick = globals.tick_count()
    if (tick >= backtrack.predict_tick and tick - backtrack.predict_tick < 2) then return end
    backtrack.peekers, backtrack.peek_until = {}, 0
    if (not ui.ragebot.backtrack.prediction:get()) then
        return
    end
    -- Lists expire after three ticks; skipped scans never extend their life.
    backtrack.predict_tick = tick

    local eye = local_player:get_eye_position()
    if (eye == nil) then return end
    local net = resolver.network()
    local peekers, checked = {}, 0
    for _, enemy in pairs(entity_list_get_players(true) or {}) do
        if (checked >= 5) then
            break
        end
        if (enemy:is_alive() and not enemy:is_dormant()) then
            local head = enemy:get_hitbox_pos(e_hitboxes.HEAD)
            local velocity = enemy:get_prop("m_vecVelocity")
            local sim = tonumber(enemy:get_prop("m_flSimulationTime"))
            backtrack.records = backtrack.records or {}
            local record = backtrack.records[enemy:get_index()]
            local now = globals.real_time()
            if (sim == nil or sim ~= sim or math.abs(sim) == math.huge) then
                record = nil
                backtrack.records[enemy:get_index()] = nil
            elseif (record == nil or record.sim ~= sim) then
                local rewound = record ~= nil and sim < record.sim
                record = { sim = sim, time = now, defensive_until = rewound and now + 0.25
                    or (record and record.defensive_until or 0) }
                backtrack.records[enemy:get_index()] = record
            end
            local fresh = record ~= nil and now >= record.time and now - record.time <= 0.12
                and now >= record.defensive_until
            if (fresh and head ~= nil and velocity ~= nil and math.vec_length2d(velocity) > 8) then
                checked = checked + 1
                local ducking = bit.band(tonumber(enemy:get_prop("m_fFlags")) or 0, 2) ~= 0
                local ahead = backtrack.horizon(net, ducking)
                local to = vec3_t(head.x + velocity.x * ahead, head.y + velocity.y * ahead, head.z)
                local tracked = resolver.data[enemy:get_index()]
                local predicted = resolver.advanced ~= nil and resolver.advanced.forecast(tracked, enemy,
                    math.ceil(ahead / globals.interval_per_tick())) or nil
                if (predicted ~= nil and not predicted.blocked) then
                    local origin = tracked.advanced.last
                    to = vec3_t(head.x + predicted.x - origin.x, head.y + predicted.y - origin.y,
                        head.z + predicted.z - origin.z)
                end
                local wall = trace_line(head, to, enemy, 0x400B)
                if (wall ~= nil and type(wall.fraction) == "number" and wall.fraction == wall.fraction
                    and wall.fraction >= 0.98) then
                    local later = trace_bullet(eye, to, local_player, enemy)
                    local current = trace_bullet(eye, head, local_player, enemy)
                    if (later ~= nil and later.valid and (later.damage or 0) > 0
                        and not (current ~= nil and current.valid and (current.damage or 0) > 0)) then
                        peekers[#peekers + 1] = enemy:get_index()
                    end
                end
            end
        end
    end
    backtrack.peekers = peekers
    backtrack.peek_until = globals.real_time() + math.min(0.10, globals.interval_per_tick() * 3)
end

backtrack.target_selection = function(ctx)
    local now = globals.real_time()
    if (now > (backtrack.peek_until or 0) or now < (backtrack.peek_until or 0) - 0.10) then return end
    for _, idx in ipairs(backtrack.peekers) do
        local enemy = entity_list_get_entity(idx)
        if (enemy ~= nil and enemy:is_alive() and not enemy:is_dormant()) then ctx:prioritize_target(idx) end
    end
end

backtrack.restore = function()
    if (backtrack.ping ~= nil and backtrack.saved ~= nil) then
        backtrack.ping:set(backtrack.saved)
    end
end

--- @endregion

-- Statistics per state of the target (owners, Oct 2026: "/state, hogy megnézzük mire missel a legtöbbet, és könnyebb
-- lenne fixálni a resolvert mint egybe az egészet"): shots, hits, the miss reasons (a shot spoiled by a defensive shift /
-- a lag break is relabelled "defensive" / "lag break": Primordial reports it as "jitter" / "resolver") and how often
-- each hypothesis was used and hit. The row "jitter" counts the shots at a jittering target in any state
resolver.HYP = { "side", "-side", "side/2", "-side/2", "none", "feet", "-feet", "next", "-next" }
resolver.record = function(snap, hit_ok, reason)
    local label
    if (not hit_ok) then
        label = tostring(reason or "?")
        if (label == "resolver" or label == "jitter") then
            label = snap.defensive and "defensive" or snap.lagbreak and "lag break" or label
        end
    end
    local function add(name)
        local r = resolver.stats[name]
        if (r == nil) then
            r = { name = name, n = 0, hit = 0, why = {}, hyp = {} }
            resolver.stats[name] = r
        end
        r.n = r.n + 1
        if (hit_ok) then
            r.hit = r.hit + 1
        else
            r.why[label] = (r.why[label] or 0) + 1
        end
        if (snap.candidate ~= nil) then
            local h = r.hyp[snap.candidate] or { n = 0, hit = 0 }
            r.hyp[snap.candidate] = h
            h.n = h.n + 1
            h.hit = h.hit + (hit_ok and 1 or 0)
        end
    end
    add(snap.state or "?")
    if (snap.key == "jitter") then
        add("jitter")
    end
end
-- the rows in a fixed order: { name, n, hit, rate (0..100), miss = { { label, count } by count }, hyp = { { name, n, hit } } }
resolver.stat_rows = function()
    local order, rows = { "stand", "slow", "move", "duck", "cmove", "air", "airduck", "jitter" }, {}
    for _, name in ipairs(order) do
        local r = resolver.stats[name]
        if (r ~= nil and r.n > 0) then
            local miss, hyp = {}, {}
            for label, count in pairs(r.why) do miss[#miss + 1] = { label, count } end
            table.sort(miss, function(a, b) return a[2] > b[2] or (a[2] == b[2] and a[1] < b[1]) end)
            for i, h in pairs(r.hyp) do hyp[#hyp + 1] = { resolver.HYP[i] or tostring(i), h.n, h.hit } end
            table.sort(hyp, function(a, b) return a[2] > b[2] or (a[2] == b[2] and a[1] < b[1]) end)
            rows[#rows + 1] = { name = name, n = r.n, hit = r.hit, rate = math.floor(r.hit / r.n * 100 + 0.5), miss = miss, hyp = hyp }
        end
    end
    return rows
end
resolver.stat_lines = function()
    local lines = {}
    for _, r in ipairs(resolver.stat_rows()) do
        local miss, hyp = {}, {}
        for _, m in ipairs(r.miss) do miss[#miss + 1] = m[1] .. " " .. m[2] end
        for i, h in ipairs(r.hyp) do
            if (i <= 4) then hyp[#hyp + 1] = string.format("%s %d/%d", h[1], h[3], h[2]) end
        end
        lines[#lines + 1] = string.format("%s: %d shots, %d%% hit | miss: %s | hypotheses (hit/used): %s", r.name, r.n, r.rate,
            #miss > 0 and table.concat(miss, ", ") or "-", #hyp > 0 and table.concat(hyp, ", ") or "-")
    end
    return lines
end
--- @info: resolver: side from freestanding / jitter, learned per player and state from hits and misses
--- @region: resolver
-- [pm-resolver:begin] the loader's beta version is built without this part (make_primordial_beta in discord_bot.py)

-- Primordial's own resolver does the resolving (its animation fix and records; no workshop lua writes an enemy's feet
-- yaw, and the lua has no hook into it). This block adds what the API allows: resolver misses per player -> head safe
-- point in HITSCAN. What the menu does here:
--   Improve resolver / Logic resolver / Pose resolver / Custom resolver: any of them turns the resolver layer on
--   Logic resolver: head safe point after 2 resolver misses in a row on that player (Custom resolver: Hit sensitivity)
--   Custom resolver: the options below it
--   Duck mode / Auto duck / Safe peek / Safe mode: head safe point on crouching targets / with Auto, AWP, Deagle, other /
--   while we quick peek / on targets at or below that HP. Hit sensitivity: head safe point after that many misses in a row
--   Prediction sel: the reduced desync size (% of max). Calculate box: freestanding trace width. Shot prediction: jitter step
--   Yaw calculation: Simple = always 58, Advanced = max desync by speed / duck, Experimental = Advanced + reduced size
--   Disablers + At disabler: while one of them holds, the resolver is off / head safe point / keeps resolving
local RES_NOCHOKE = 8                      -- updates without a choked tick in a row: no desync possible, nothing forced
local RES_FS_TICKS = 8                     -- freestanding traces once per this many ticks per player
local RES_STATE_NUM = { stand = 1, slow = 2, move = 3, duck = 4, cmove = 5, air = 6, jitter = 7, airduck = 8 }
local RES_SCOPE_CFG = { 0, 1, 2, 6 }
local RES_SAFE_CFG = { 0, 2, 3, 7 }

local function res_clamp(v, lo, hi)
    v = tonumber(v)
    if (v == nil or v ~= v or v == math.huge or v == -math.huge) then
        return lo
    end
    if (v < lo) then
        return lo
    end
    if (v > hi) then
        return hi
    end
    return v
end

local function res_norm(a)
    a = tonumber(a)
    if (a == nil or a ~= a or a == math.huge or a == -math.huge) then
        return 0
    end
    a = math.fmod(a + 180, 360)
    if (a ~= a) then
        return 0
    end
    if (a < 0) then
        a = a + 360
    end
    return a - 180
end

local function res_sign(v)
    return v < 0 and -1 or 1
end

local function res_custom()
    return ui.ragebot.resolver.enable_resolver:get()
end

resolver.animstate = function(idx)
    local ptr = get_entity_address(idx)
    if (ptr == nil or ptr == ffi.NULL or tonumber(ffi.cast("uintptr_t", ptr)) == 0) then
        return nil
    end
    local state = ffi.cast("CPlayer_animation_State**", ffi.cast("uintptr_t", ptr) + 0x9960)[0]
    if (state == nil) then
        return nil
    end
    return state
end

-- the server's max desync: 58 deg scaled down with speed and duck (Yaw calculation "Simple": always 58)
resolver.max_desync = function(st)
    if (ui.ragebot.reso_cfg.yaw_calc:get() == 1) then
        return 58
    end

    local speed = res_clamp(st.m_flFeetSpeedForwardsOrsideWays, 0, 1)
    local factor = (res_clamp(st.m_flStopToFullRunningFraction, 0, 1) * -0.3 - 0.2) * speed + 1
    local duck = res_clamp(st.m_fDuckAmount, 0, 1)
    if (duck > 0) then
        factor = factor + duck * speed * (0.5 - factor)
    end
    return 58 * res_clamp(factor, 0.5, 1)
end

resolver.state_of = function(ent)
    local flags = tonumber(ent:get_prop("m_fFlags")) or 0
    if (bit.band(flags, 1) == 0) then
        return bit.band(flags, 2) ~= 0 and "airduck" or "air"
    end
    local velocity = ent:get_prop("m_vecVelocity")
    local speed = velocity and math.vec_length2d(velocity) or 0
    if (bit.band(flags, 2) ~= 0) then
        -- a crouched player who walks has the eye-following feet and the small crouch limit: its own state
        return speed > 5 and "cmove" or "duck"
    end
    if (speed > 100) then
        return "move"
    elseif (speed > 5) then
        return "slow"
    end
    return "stand"
end

-- +1 / -1: which side of the head (seen from us) is behind a wall, 0: neither / both
resolver.freestand = function(local_player, ent)
    local eye = local_player:get_eye_position()
    local head = ent:get_hitbox_pos(e_hitboxes.HEAD)
    if (eye == nil or head == nil) then
        return 0
    end

    local dx, dy = head.x - eye.x, head.y - eye.y
    local len = math.sqrt(dx * dx + dy * dy)
    if (len < 1) then
        return 0
    end

    local width = res_custom() and res_clamp(ui.ragebot.resolver.calc_box:get(), 10, 35) or 25
    local rx, ry = -dy / len * width, dx / len * width
    local lt = trace_line(eye, vec3_t(head.x + rx, head.y + ry, head.z), local_player, 0x200400B)
    local rt = trace_line(eye, vec3_t(head.x - rx, head.y - ry, head.z), local_player, 0x200400B)
    if (lt == nil or rt == nil or lt.fraction == nil or rt.fraction == nil) then
        return 0
    end
    local left, right = res_clamp(lt.fraction, 0, 1), res_clamp(rt.fraction, 0, 1)
    if (math.abs(left - right) < 0.05) then
        return 0
    end
    return left < right and 1 or -1
end

-- Disablers: 0 = none holds, else the "At disabler" choice (1 off, 2 head safe point, 3 keep resolving)
resolver.disabler = function(local_player)
    local d = ui.ragebot.reso_cfg.disablers
    local on_ground = local_player:has_player_flag(e_player_flags.ON_GROUND)
    local ducking = local_player:has_player_flag(e_player_flags.DUCKING)
    local scoped = local_player:get_prop("m_bIsScoped") == 1

    local hit = (d:get(1) and not on_ground)
        or (d:get(2) and not on_ground and ducking)
        or (d:get(3) and ducking)
        or (d:get(4) and ragebot_get_autopeek_pos())
        or (d:get(5) and scoped)
        or (d:get(6) and not scoped and table.contains(RES_SCOPE_CFG, ragebot_get_active_cfg()))
        or (d:get(7) and menu_find("aimbot", "general", "exploits", "doubletap", "enable")[2]:get())
        or (d:get(8) and menu_find("aimbot", "general", "exploits", "hideshots", "enable")[2]:get())
        or (d:get(9) and client_get_fps() < 75)
        or (d:get(10) and get_user_ping() > 80)
    if (not hit) then
        return 0
    end
    return ui.ragebot.reso_cfg.at_disabler:get()
end

resolver.memory = function(idx, key, kind)
    local mem = resolver.mem[idx]
    if (mem == nil) then
        mem = {}
        resolver.mem[idx] = mem
    end
    if (mem[key] == nil) then
        mem[key] = { rel = 1, misses = 0, candidates = {}, selected = 1 }
        for i = 1, resolver.NCAND do
            mem[key].candidates[i] = { good = 1, bad = 1 }
        end
    end
    return mem[key]
end
-- Per-target/per-state hypotheses. Side hint is evidence, not a guarantee.
-- the hypotheses of a target (value = the body yaw of the record, relative to its eye yaw; see resolver.hypothesis):
-- 1 / 2 the side hint, full size, as is / mirrored; 3 / 4 the same, half size; 5 no desync; 6 / 7 the computed body
-- yaw of the feet model, as is / mirrored; 8 / 9 the side the jitter pattern predicts for the NEXT record, as is / mirrored
resolver.NCAND = 9
resolver.PRIOR = { 0.14, 0.02, 0.08, 0.00, -0.03, 0.0, 0.0, 0.0, 0.0 }
-- opt.skip[i] = the hypothesis does not apply now, opt.bonus[i] = what the situation says for it before any result
-- what the common anti-aims do in each state (read from the Primordial workshop builders: Formal Yaw, Anti-Aim Builder, Destroy,
-- T1ny, Star-Project): standing = a held side / inverter with a near full body yaw (the side hint and the LBY feet model are
-- right); walking, running, crouch walking = the desync flips every tick / delay with the yaw jitter (the half size and the
-- jitter pattern pay); in the air = the largest jitter and a flipping desync, the feet lag (half size + pattern, no feet model);
-- crouched still = held like standing, but the limit is smaller. Added to the candidate bonus: a prior, the results overrule it
resolver.STATE_PRIOR = {
    stand = { [1] = 0.04, [6] = 0.04 },
    slow = { [1] = 0.02, [3] = 0.03, [6] = 0.02, [8] = 0.03 },
    move = { [3] = 0.04, [8] = 0.05 },
    duck = { [1] = 0.03, [3] = 0.02, [6] = 0.04 },
    cmove = { [3] = 0.04, [6] = 0.01, [8] = 0.04 },
    air = { [3] = 0.05, [8] = 0.06 },
    airduck = { [3] = 0.05, [8] = 0.06 },
}

resolver.choose = function(mem, confidence, allow_half, opt)
    local best, score = 1, -math.huge
    local skip, bonus = opt and opt.skip or {}, opt and opt.bonus or {}
    for i, c in ipairs(mem.candidates) do
        if (not skip[i]) then
            local n = c.good + c.bad
            local prior = (resolver.PRIOR[i] or 0) * confidence + (bonus[i] or 0)
            local value = c.good / n + 0.10 / math.sqrt(n) + prior
            if (mem.last_failed == i) then
                value = value - 0.25
            end
            if ((allow_half ~= false or (i ~= 3 and i ~= 4)) and value > score) then
                best, score = i, value
            end
        end
    end
    mem.selected = best
    return best
end
resolver.shot_id = function(event)
    return event and (event.id or event.shot_id) or nil
end
resolver.prune_shots = function(now)
    for i = #resolver.shots, 1, -1 do
        local s = resolver.shots[i]
        if (now < s.time or now - s.time > 4 or s.epoch ~= resolver.epoch) then
            table.remove(resolver.shots, i)
        end
    end
end
resolver.capture = function(shot)
    if (shot == nil or shot.player == nil) then return end
    local now, idx = globals.real_time(), shot.player:get_index()
    resolver.prune_shots(now)
    local p, prev = resolver.data[idx], resolver.previous[idx]
    local s = { id = resolver.shot_id(shot), idx = idx, time = now,
        epoch = resolver.epoch, track = p, aimpos = shot.player:get_hitbox_pos(1) }
    if (prev ~= nil) then
        s.key, s.kind, s.rel = prev.key, prev.kind, prev.rel
        s.candidate, s.desync = prev.candidate, prev.m_flDesync
        s.model, s.nxt = prev.model, prev.nxt
        s.phase, s.reliab = prev.phase, prev.reliab
    end
    -- classified at the result (resolver.spoiled): the round trip and the state of the target at the shot
    s.rtt = resolver.network().ping / 1000
    -- animation layer 6 (movement) of the target at the shot: logged next to the body yaw we gave, to find out from the real
    -- logs whether its playback rate tells the side (res_fix_att does that from the rate alone); read only, nil when missing
    local okl, rate, weight = pcall(function()
        local layer = get_anim_layer(get_entity_address(idx), 6)
        return layer.m_flPlaybackRate, layer.m_flWeight
    end)
    if (okl) then s.l6, s.l6w = rate, weight end
    s.state = resolver.state_of(shot.player)
    resolver.shots[#resolver.shots + 1] = s
    if (#resolver.shots > 128) then table.remove(resolver.shots, 1) end
end
resolver.take_shot = function(event, idx)
    resolver.prune_shots(globals.real_time())
    local id, found, count = resolver.shot_id(event), nil, 0
    for i, s in ipairs(resolver.shots) do
        if (s.idx == idx and (id == nil or s.id == id)) then
            found, count = i, count + 1
        end
    end
    -- Without a usable unique ID, overlapping shots are ambiguous.
    -- Never train against the latest global shot or guess their order.
    if (count ~= 1) then
        if (id == nil and count > 1) then
            for _, s in ipairs(resolver.shots) do
                if (s.idx == idx) then s.ambiguous = true end
            end
        end
        return nil
    end
    if (id == nil and resolver.shots[found].ambiguous) then return nil end
    return table.remove(resolver.shots, found)
end
local RES_JIT_N = 12
local RES_JIT_MIN = 20
local RES_JIT_HOLD = 0.25
local RES_JIT_SMALL = 4
local RES_JIT_TOL = 1.5
local RES_JIT_RETURNS = 6

resolver.jit_returns = function(yaws)
    local returns = 0
    for i = 1, #yaws - 2 do
        if (math.abs(res_norm(yaws[i] - yaws[i + 1])) >= RES_JIT_SMALL) then
            for k = 2, 4 do
                local old = yaws[i + k]
                if (old ~= nil and math.abs(res_norm(yaws[i] - old)) <= RES_JIT_TOL) then
                    returns = returns + 1
                    break
                end
            end
        end
    end
    return returns
end

resolver.jit_classify = function(steps, min, yaws)
    if (yaws ~= nil and resolver.jit_returns(yaws) >= RES_JIT_RETURNS) then
        return true
    end
    local big, flips, net, total, last = 0, 0, 0, 0, 0
    for i = 1, #steps do
        local d = steps[i]
        net = net + d
        total = total + math.abs(d)
        if (math.abs(d) >= min) then
            local sign = d < 0 and -1 or 1
            big = big + 1
            if (last ~= 0 and sign ~= last) then
                flips = flips + 1
            end
            last = sign
        end
    end
    return big >= 3 and flips >= 2 and math.abs(net) <= total * 0.5
end

resolver.K = {
    zero = 20,          -- |computed body yaw| below this: the feet model sees no desync (micromovement keeps the LBY on the eye yaw)
    shift = 0.5,        -- a sim time that goes back by less (s) is a tickbase shift (defensive), not a reset
    round_keep = 0.5,   -- how much of what was learned about a player stays into the next round
    change_keep = 0.35, -- the same when its yaw pattern changed
    change = 10,        -- records in a row with another pattern = the pattern changed
    forget = 0.97,      -- every counted result pulls all hypotheses of that situation back toward the start
    lc_window = 0.5,    -- seconds a broken lag compensation (a teleport) spoils the shots fired after it
    ev_margin = 0.06,   -- timing slack (s) of the shot / event matching
    ev_keep = 3,        -- seconds the observed shift / lag break events are kept
}

-- Defensive / lag break events of a target, as WE observe them (p.events, newest last). A shot is tested by the server
-- against the target's state when it arrives there, but we see the target's packets one way latency late, so the shift
-- that spoils a shot fired at t is observed about one round trip LATER, inside [t + rtt - dur, t + rtt]: dur = how long
-- the shift lasts (the size of the sim time step back, like defensive:is_active) or the lag comp window. So a shot is
-- classified when its RESULT arrives, from the events seen since it was fired
resolver.event = function(p, now, dur)
    p.events = p.events or {}
    p.events[#p.events + 1] = { obs = now, dur = dur }
    while (#p.events > 0 and now - p.events[1].obs > resolver.K.ev_keep) do
        table.remove(p.events, 1)
    end
end
-- true when an event of that kind spoils a shot fired at t_fire with a round trip of rtt, the result arriving at now
resolver.spoiled = function(p, t_fire, rtt, now, kind)
    local m = resolver.K.ev_margin
    for _, ev in ipairs(p.events or {}) do
        if (ev.kind == kind and ev.obs >= t_fire + rtt - ev.dur - m and ev.obs <= now + m) then
            return true
        end
    end
    return false
end

-- steam id of an entity: the learning follows the player, not the slot
resolver.sid = function(ent)
    local ok, a, b = pcall(ent.get_steamids, ent)
    if (not ok) then return nil end
    local id = (type(b) == "string" and #b >= 5) and b or tonumber(a)
    return id ~= nil and id ~= 0 and tostring(id) or nil
end

-- ── feet model (owners, Oct 2026: the GS lua's resolver works on it; the server's feet logic on netvars) ──
-- Standing, the feet turn to the lower body yaw target (100 deg/s); moving or in the air, they follow the eye yaw
-- (30-50 deg/s). They are never further than the max body yaw from the eye yaw: eye yaw - feet = the body yaw of the record
resolver.feet_limit = function(speed, duck)
    local ratio = 1 - 0.35 * res_clamp(speed / 250, 0, 1)
    duck = res_clamp(duck, 0, 1)
    if (duck > 0) then
        ratio = ratio + duck * res_clamp(speed / 85, 0, 1) * (0.5 - ratio)
    end
    return 58 * res_clamp(ratio, 0.5, 1)
end

resolver.approach = function(target, cur, step)
    local d = res_norm(target - cur)
    if (math.abs(d) <= step) then
        return res_norm(target)
    end
    return res_norm(cur + (d > 0 and step or -step))
end

-- how the feet model is read per state (owners: "minden statere külön resolver logic"). The feet follow the LBY while the target
-- stands (phase "lby": the model is built on it, full trust) and the eye yaw while it moves or is in the air (phase "eye": the
-- feet lag behind a changing yaw, so the model is trusted less). rel also grows with the records the model has seen (it starts
-- from the first record's yaw, a few records are needed to converge); zero = below this body yaw the model says "no desync"
resolver.profile = function(speed, air, steps, crouch)
    local eye = air or speed > 5
    local conv = res_clamp((steps or 0) / 6, 0.25, 1)
    local base = eye and (crouch and 0.5 or 0.35) or 1
    return { phase = eye and "eye" or "lby", rel = base * conv, zero = eye and 12 or resolver.K.zero }
end

-- one record at tick t (the arrival tick: a shifted update's sim time says nothing about how long the server animated)
resolver.feet_step = function(p, eye, lby, speed, air, maxd, t, interval)
    local moving = speed > 5 or air
    local target = moving and eye or lby
    if (target == nil) then
        p.model = nil
        return nil
    end
    if (p.feet == nil or p.feet_t == nil or t < p.feet_t) then
        p.feet, p.feet_t = target, t
    end
    local dt = res_clamp((t - p.feet_t) * interval, 0, 0.25)
    p.feet_t = t
    local rate = moving and (30 + 20 * res_clamp((speed - 70) / 65, 0, 1)) or 100
    p.feet = resolver.approach(target, p.feet, rate * dt)
    p.feet_steps = (p.feet_steps or 0) + 1
    local d = res_norm(eye - p.feet)
    if (d > maxd) then
        p.feet = res_norm(eye - maxd)
    elseif (d < -maxd) then
        p.feet = res_norm(eye + maxd)
    end
    p.model = res_norm(eye - p.feet)
    return p.model
end

-- ── jitter pattern: how long the target holds a side (owners: "periódus és fázis") ──
-- runs = the lengths (records) of the finished runs on one side, run_len = the current one, side = +1 / -1.
-- Returns the side of the NEXT record, the fixed period (or nil) and how sure that is (0..1). A fixed period (the last three
-- runs the same length: a delay jitter) switches exactly when the run reaches it; else it switches when most runs that
-- got as long as the current one ended there (a tick jitter every record, a random hold at the length it ends most often)
resolver.run_predict = function(runs, run_len, side)
    local n = #runs
    if (side == nil or n < 2) then
        return nil, nil, 0
    end
    local period = runs[n]
    local k = 0
    for i = n, 1, -1 do
        if (runs[i] ~= period) then break end
        k = k + 1
    end
    if (k >= 3) then
        local conf = math.min(1, 0.5 + 0.1 * k)
        return (run_len >= period) and -side or side, period, conf
    end
    local ended, longer = 0, 0
    for _, len in ipairs(runs) do
        if (len == run_len) then ended = ended + 1 end
        if (len >= run_len) then longer = longer + 1 end
    end
    if (longer == 0) then
        return -side, nil, 0.3
    end
    local sw = ended * 2 >= longer
    return sw and -side or side, nil, 0.5 * (sw and ended or longer - ended) / longer
end

resolver.run_update = function(p)
    if (not p.jitter) then
        p.run_side, p.run_len, p.next_side, p.period, p.period_conf = nil, 0, nil, nil, 0
        return
    end
    p.runs = p.runs or {}
    if (p.dir == p.run_side) then
        p.run_len = (p.run_len or 0) + 1
    else
        if (p.run_side ~= nil and (p.run_len or 0) > 0) then
            p.runs[#p.runs + 1] = p.run_len
            while (#p.runs > 24) do table.remove(p.runs, 1) end
        end
        p.run_side, p.run_len = p.dir, 1
    end
    p.next_side, p.period, p.period_conf = resolver.run_predict(p.runs, p.run_len, p.run_side)
end

-- the yaw pattern of a jitterer from its newest eye yaws (newest first): how many yaw positions it uses and their spread
resolver.pattern = function(yaws)
    local n = #yaws
    if (n < 6) then return nil end
    local v = {}
    for i = 1, n do v[i] = res_norm(yaws[i] - yaws[1]) end
    table.sort(v)
    local clusters, last = 0, nil
    for i = 1, n do
        if (last == nil or v[i] - last > 8) then clusters = clusters + 1 end
        last = v[i]
    end
    return { kind = clusters <= 1 and "static" or clusters == 2 and "two" or clusters <= 5 and "multi" or "random",
             span = v[n] - v[1] }
end

-- true when a jitterer kept another pattern for resolver.K.change records in a row (the AA was changed: what was learned
-- about it is worth less). Mouse turns do not count: only while the jitter detector holds
resolver.pattern_update = function(p)
    if (not p.jitter) then
        p.sig, p.sig_new, p.sig_n = nil, nil, 0
        return false
    end
    local sig = resolver.pattern(p.jy)
    if (sig == nil) then return false end
    local function differs(a, b) return a.kind ~= b.kind or math.abs(a.span - b.span) > 25 end
    if (p.sig == nil) then
        p.sig, p.sig_new, p.sig_n = sig, nil, 0
        return false
    end
    if (not differs(sig, p.sig)) then
        p.sig_new, p.sig_n = nil, 0
        return false
    end
    if (p.sig_new ~= nil and not differs(sig, p.sig_new)) then
        p.sig_n = p.sig_n + 1
    else
        p.sig_new, p.sig_n = sig, 1
    end
    if (p.sig_n >= resolver.K.change) then
        p.sig, p.sig_new, p.sig_n = sig, nil, 0
        return true
    end
    return false
end

-- pulls what was learned about a player toward the start (keep = how much stays)
resolver.decay_memory = function(player_mem, keep)
    for _, m in pairs(player_mem or {}) do
        for _, c in ipairs(m.candidates) do
            c.good = 1 + (c.good - 1) * keep
            c.bad = 1 + (c.bad - 1) * keep
        end
        m.misses, m.last_failed = 0, nil
    end
end

-- the body yaw (value) a hypothesis gives for the record
resolver.hypothesis = function(i, hint, nhint, half, maxd, c)
    if (i <= 5) then
        return ({ 1, -1, half, -half, 0 })[i] * hint * maxd
    elseif (i <= 7) then
        local v = res_clamp(c or 0, -maxd, maxd)
        return i == 6 and -v or v
    end
    return (i == 8 and nhint or -nhint) * maxd
end

-- one record: its eye yaw step, the jitter state; p.dir = the direction of the newest big step (the lua side override)
resolver.jit_record = function(p, delta, sim, min, eye)
    table.insert(p.jd, 1, delta)
    p.jd[RES_JIT_N + 1] = nil
    table.insert(p.jy, 1, eye)
    p.jy[RES_JIT_N + 1] = nil
    if (math.abs(delta) >= min) then
        p.dir = delta < 0 and -1 or 1
    end
    if (resolver.jit_classify(p.jd, min, p.jy)) then
        p.jit_sim = sim
    end
    p.jitter = p.jit_sim ~= nil and sim - p.jit_sim >= 0 and sim - p.jit_sim <= RES_JIT_HOLD
    local big, flips, last, total, net = 0, 0, 0, 0, 0
    for _, d in ipairs(p.jd) do
        total, net = total + math.abs(d), net + d
        if (math.abs(d) >= min) then
            local sign = res_sign(d)
            big = big + 1
            if (last ~= 0 and last ~= sign) then flips = flips + 1 end
            last = sign
        end
    end
    p.confidence = big >= 3 and res_clamp((flips / math.max(1, big - 1))
        * (1 - math.abs(net) / math.max(1, total)), 0, 1) or 0
    if (resolver.jit_returns(p.jy) >= RES_JIT_RETURNS) then
        p.confidence = math.max(p.confidence, 0.75)
    end
    resolver.run_update(p)
    if (resolver.pattern_update(p)) then
        p.changed, p.runs, p.run_side, p.run_len = true, {}, nil, 0
    end
end

-- every enemy, every net update, whichever resolver is on (also none): choke count and the jitter detector
resolver.track = function(ent, eye)
    local idx = ent:get_index()
    local p = resolver.data[idx]
    local sim = ent:get_prop("m_flSimulationTime")
    if (type(sim) ~= "number" or sim ~= sim or sim == math.huge or sim == -math.huge) then
        return nil
    end
    local spawn = ent:get_prop("m_flSpawnTime")
    local state, now = resolver.state_of(ent), globals.real_time()
    -- a tickbase shift (defensive / double tap) sends a sim time that does not move forward: not a record (the server
    -- keeps no lag record of it, its angles say nothing about the real AA) but the server animates it. What was learned
    -- stays (every shift used to wipe it), only a short grace window
    if (p ~= nil and sim < p.sim and p.sim - sim <= resolver.K.shift
        and (spawn == nil or p.spawn == nil or spawn == p.spawn)) then
        p.defensive_until, p.nochoke = now + 0.25, 0
        resolver.event(p, now, math.min(p.sim - sim, 1))
        p.events[#p.events].kind = "def"
        return p
    end
    if (p == nil or sim < p.sim or sim - p.sim > 1
        or (spawn ~= nil and p.spawn ~= nil and spawn ~= p.spawn)) then
        local rewind = p ~= nil and sim < p.sim
        local sid = resolver.sid(ent)
        -- what was learned stays with the PLAYER (steam id), not the slot or the record: it came back after a dormant
        -- phase / a respawn / a round change (it used to be wiped at every one of them)
        local keep = nil
        if (sid ~= nil) then
            if (p ~= nil and p.sid == sid) then
                keep = resolver.mem[idx]
            elseif (resolver.carry ~= nil and resolver.carry[sid] ~= nil) then
                keep = resolver.carry[sid]
                resolver.carry[sid] = nil
            end
        end
        resolver.mem[idx], resolver.previous[idx], resolver.misses[idx] = keep, nil, nil
        p = { sim = sim, eye = eye, nochoke = 0, jd = {}, jy = {}, dir = 1,
            jitter = false, fs = 0, fs_tick = -RES_FS_TICKS, confidence = 0,
            spawn = spawn, samples = 0, choke = 0, state = state, sid = sid, rec_n = 0,
            updated = now, defensive_until = rewind and now + 0.25 or 0, events = {} }
        resolver.data[idx] = p
        return p
    end
    local ticks = time_to_ticks(sim - p.sim)
    if (state ~= p.state) then
        p.jd, p.jy, p.jit_sim, p.jitter, p.confidence = {}, {}, nil, false, 0
        p.state, p.eye, p.nochoke = state, eye, 0
    end
    if (ticks >= 1) then
        p.samples = p.samples + 1
        p.rec_n = (p.rec_n or 0) + 1
        -- lag compensation broken: more than 64 units between two records = the server keeps no old record of him
        -- (teleport / lag break), the aimbot can only shoot the newest one extrapolated: a miss on it is about the
        -- position, not the angle
        local o = resolver.advanced.read(ent, "m_vecOrigin")
        if (o ~= nil) then
            if (p.last_o ~= nil and ticks <= 32) then
                local dx, dy, dz = o.x - p.last_o[1], o.y - p.last_o[2], o.z - p.last_o[3]
                if (dx * dx + dy * dy + dz * dz > 4096) then
                    resolver.event(p, now, resolver.K.lc_window)
                    p.events[#p.events].kind = "lc"
                end
            end
            p.last_o = { o.x, o.y, o.z }
        end
        p.choke = res_clamp(ticks - 1, 0, 64)
        p.nochoke = (ticks == 1) and (p.nochoke + 1) or 0
        local min = res_custom() and res_clamp(ui.ragebot.resolver.shot_pred:get(), 15, 65) or RES_JIT_MIN
        resolver.jit_record(p, res_norm(eye - p.eye), sim, min, eye)
        p.sim, p.eye = sim, eye
        p.updated = now
    end
    return p
end
resolver.fresh = function(p)
    if (p == nil or p.updated == nil) then return false end
    local now = globals.real_time()
    return now >= p.updated and now - p.updated <= 0.12
        and now >= (p.defensive_until or 0)
end
-- ── movement observer + forecast (owners' fixed file, Oct 2026): per target the last 64 records (origin, velocity, yaw, state),
-- a per state yaw predictor (static / linear / alternating, the one with the least error) and a forecast of the origin `ticks`
-- ahead (velocity fading, gravity in the air, bullet-solid walls stop it). Used by the advanced prediction of the peek check ──
resolver.advanced = { version = 2, limit = 64 }
resolver.advanced.finite = function(x)
    return type(x) == "number" and x == x and math.abs(x) < 1e12
end
-- a netvar vector as { x, y, z } or nil. Some of them arrive as a 2D vector (x, y only: indexing .z raises "not a numeric type"
-- and stops the whole callback), then z is the netvar's own "[2]" element, else 0
resolver.advanced.read = function(ent, name)
    local A = resolver.advanced
    local v = ent:get_prop(name)
    if v == nil or type(v) == "number" then
        return nil
    end
    local ok, x, y = pcall(function() return v.x, v.y end)
    if not ok or not A.finite(x) or not A.finite(y) then
        return nil
    end
    local okz, z = pcall(function() return v.z end)
    if not okz or not A.finite(z) then
        z = tonumber(ent:get_prop(name .. "[2]"))
        z = A.finite(z) and z or 0
    end
    return { x = x, y = y, z = z }
end
resolver.advanced.observe = function(p, ent, eye)
    local A = resolver.advanced
    local sim, dt = ent:get_prop("m_flSimulationTime"), globals.interval_per_tick()
    if not A.finite(sim) or not A.finite(eye) or not A.finite(dt) or dt <= 0 then return end
    local o, v = A.read(ent, "m_vecOrigin"), A.read(ent, "m_vecVelocity")
    if not o or not v then return end
    local h = p.advanced
    if not h then h = { records = {}, states = {}, transitions = {} }; p.advanced = h end
    local last = h.records[#h.records]
    if last and sim <= last.sim then return end
    local state, flags = resolver.state_of(ent), tonumber(ent:get_prop("m_fFlags")) or 0
    local r = {sim=sim, yaw=res_norm(eye), x=o.x, y=o.y, z=o.z,
        vx=v.x, vy=v.y, vz=v.z, state=state, ground=bit.band(flags,1)~=0,
        duck=bit.band(flags,2)~=0, ax=0, ay=0, time=globals.real_time()}
    if last then
        local elapsed=sim-last.sim
        local dx,dy,dz=r.x-last.x,r.y-last.y,r.z-last.z
        r.gap=math.floor(elapsed/dt+0.5)
        r.discontinuity=elapsed>64*dt or dx*dx+dy*dy+dz*dz>4096
        if not r.discontinuity and last.state==state then
            r.ax=res_clamp((r.vx-last.vx)/elapsed,-1000,1000)
            r.ay=res_clamp((r.vy-last.vy)/elapsed,-1000,1000)
        end
        if last.state~=state then
            local t=h.transitions[last.state] or {}; h.transitions[last.state]=t
            t[state]=math.min(10000,(t[state] or 0)+1)
        end
    end
    local m=h.states[state]
    if not m then m={samples={}, errors={static=45,linear=45,alternating=45},n=0}; h.states[state]=m end
    local a,b=m.samples[#m.samples],m.samples[#m.samples-1]
    if a and last and last.state==state and not r.discontinuity and sim-a.sim<=dt*4 then
        local rate=b and res_norm(a.yaw-b.yaw)/math.max(dt,a.sim-b.sim) or 0
        local pred={static=a.yaw,linear=res_norm(a.yaw+rate*(sim-a.sim)),alternating=b and b.yaw or a.yaw}
        for name,yaw in pairs(pred) do m.errors[name]=m.errors[name]*0.85+math.abs(res_norm(r.yaw-yaw))*0.15 end
        m.n=math.min(10000,m.n+1)
    end
    if r.discontinuity or (last and last.state~=state) then m.samples={} end
    m.samples[#m.samples+1]=r
    if #m.samples>32 then table.remove(m.samples,1) end
    m.kind,m.error="static",m.errors.static
    for _,name in ipairs({"linear","alternating"}) do
        if m.errors[name]<m.error then m.kind,m.error=name,m.errors[name] end
    end
    m.confidence=math.min(1,m.n/16)*math.max(0,1-m.error/90)
    m.last=r
    h.records[#h.records+1]=r
    while #h.records>1 and (#h.records>65 or sim-h.records[1].sim>64*dt) do table.remove(h.records,1) end
    h.last,h.model=r,m
end
resolver.advanced.interpolate = function(p,time)
    local A=resolver.advanced
    local h=p and p.advanced
    if not h or not A.finite(time) then return nil end
    for i=2,#h.records do
        local a,b=h.records[i-1],h.records[i]
        if time>=a.sim and time<=b.sim and not b.discontinuity then
            local u=(time-a.sim)/(b.sim-a.sim)
            return {x=a.x+(b.x-a.x)*u,y=a.y+(b.y-a.y)*u,z=a.z+(b.z-a.z)*u,
                yaw=res_norm(a.yaw+res_norm(b.yaw-a.yaw)*u),sim=time}
        end
    end
    return nil
end
resolver.advanced.forecast = function(p,ent,ticks)
    local A=resolver.advanced
    local h=p and p.advanced
    local r=h and h.last
    local dt,now=globals.interval_per_tick(),globals.real_time()
    ticks=tonumber(ticks)
    if not r or r.discontinuity or not A.finite(ticks) or not A.finite(dt) or dt<=0
        or now<r.time or now-r.time>0.12 or now<(p.defensive_until or 0) then return nil end
    ticks=math.floor(res_clamp(ticks,1,64))
    local cache=h.prediction
    if cache and cache.source==r and cache.requested_ticks==ticks then return cache end
    local gravity=800
    local ok,g=pcall(function() return cvars.sv_gravity:get_float() end)
    if ok and A.finite(g) and g>0 then gravity=g end
    local x,y,z,vx,vy,vz=r.x,r.y,r.z,r.vx,r.vy,r.vz
    local landing,blocked,steps=nil,false,0
    for i=1,ticks do
        local fade=math.exp(-(i-1)/4)
        local ax,ay=r.ax*fade,r.ay*fade
        local nx,ny=x+vx*dt+ax*dt*dt*0.5,y+vy*dt+ay*dt*dt*0.5
        local nz=r.ground and z or z+vz*dt-gravity*dt*dt*0.5
        local tr=trace_line(vec3_t(x,y,z+2),vec3_t(nx,ny,nz+2),ent,0x400B)
        if not tr or not A.finite(tr.fraction) then return nil end
        local f=res_clamp(tr.fraction,0,1)
        x,y,z=x+(nx-x)*f,y+(ny-y)*f,z+(nz-z)*f
        steps=i
        if f<0.999 then
            blocked=true
            local normal=tr.plane_normal
            local floor=normal~=nil and A.finite(normal.z) and normal.z>=0.7
            if not r.ground and vz<0 then
                landing={x=x,y=y,z=z,tick=i,verified=false,floor_hint=floor}
            end
            break
        end
        vx,vy=vx+ax*dt,vy+ay*dt
        if not r.ground then vz=vz-gravity*dt end
    end
    local predicted_state=r.state
    if landing and landing.floor_hint then
        local speed=math.sqrt(vx*vx+vy*vy)
        predicted_state=r.duck and (speed>5 and "cmove" or "duck")
            or (speed>100 and "move" or speed>5 and "slow" or "stand")
    end
    local m=h.states[predicted_state]
    local yaw,confidence=r.yaw,0
    if m and m.last then
        yaw=m.last.yaw
        confidence=m.confidence*math.exp(-math.max(0,r.sim-m.last.sim)/2)
        local a,b=m.samples[#m.samples],m.samples[#m.samples-1]
        if a and b and predicted_state==r.state then
            if m.kind=="linear" then
                yaw=res_norm(a.yaw+res_norm(a.yaw-b.yaw)/math.max(dt,a.sim-b.sim)*steps*dt)
            elseif m.kind=="alternating" and steps%2==1 then yaw=b.yaw end
        end
    end
    local out={x=x,y=y,z=z,yaw=yaw,state=predicted_state,landing=landing,blocked=blocked,
        pattern=m and m.kind or "unknown",confidence=confidence*math.exp(-steps/16),
        ticks=steps,requested_ticks=ticks,source=r}
    h.prediction=out
    return out
end
resolver.advanced.base_track = resolver.track
resolver.track = function(ent,eye)
    local p=resolver.advanced.base_track(ent,eye)
    -- the forecast is an extra: whatever goes wrong in it must not stop the NET_UPDATE callback
    if p then pcall(resolver.advanced.observe,p,ent,eye) end
    return p
end

resolver.update = function(local_player, ent)
    local idx = ent:get_index()
    local st = resolver.animstate(idx)
    if (st == nil) then
        return
    end

    local eye = st.m_flEyeYaw
    if (eye ~= eye or math.abs(eye) > 1e6) then
        return
    end

    local p = resolver.track(ent, eye)
    if (p == nil) then return end
    local state = resolver.state_of(ent)
    local key, kind, hint
    if (p.jitter and p.confidence >= 0.60 and p.choke <= 2 and resolver.fresh(p)) then
        key, kind, hint = "jitter", "jitter", -p.dir
    else
        key, hint = state, 1
        do
            local tick = globals.tick_count()
            if (tick - p.fs_tick >= RES_FS_TICKS or tick < p.fs_tick) then
                p.fs = resolver.freestand(local_player, ent)
                p.fs_tick = tick
            end
            if (p.fs ~= 0) then
                key, kind, hint = state .. " fs", "fs", p.fs
            end
        end
    end

    -- the yaw pattern of a jitterer changed: what was learned about him is worth less
    if (p.changed) then
        p.changed = false
        resolver.decay_memory(resolver.mem[idx], resolver.K.change_keep)
    end

    -- the computed body yaw of the newest record (the server's feet logic on netvars)
    local vel = ent:get_prop("m_vecVelocity")
    local speed = vel and math.vec_length2d(vel) or 0
    local flags = tonumber(ent:get_prop("m_fFlags")) or 0
    if (p.feet_n ~= p.rec_n) then
        p.feet_n = p.rec_n
        local lby = ent:get_prop("m_flLowerBodyYawTarget")
        lby = (type(lby) == "number" and lby == lby and math.abs(lby) <= 1e6) and lby or nil
        resolver.feet_step(p, eye, lby, speed, bit.band(flags, 1) == 0,
            resolver.feet_limit(speed, tonumber(ent:get_prop("m_flDuckAmount"))), globals.tick_count(), globals.interval_per_tick())
    end

    local mem = resolver.memory(idx, key, kind)
    local confidence = kind == "jitter" and p.confidence or kind == "fs" and 0.55 or 0.25
    local c = p.model
    local nx = kind == "jitter" and p.next_side or nil
    local prof = resolver.profile(speed, bit.band(flags, 1) == 0, p.feet_steps, bit.band(flags, 2) ~= 0)
    local opt = { skip = {}, bonus = {} }
    if (c == nil or math.abs(c) < prof.zero) then
        opt.skip[6], opt.skip[7] = true, true
    else
        opt.bonus[6] = 0.12 * prof.rel
    end
    for i, v in pairs(resolver.STATE_PRIOR[state] or {}) do
        opt.bonus[i] = (opt.bonus[i] or 0) + v
    end
    if (nx == nil) then
        opt.skip[8], opt.skip[9] = true, true
    else
        opt.bonus[8] = 0.15 * (p.period_conf or 0)
    end
    local candidate = resolver.choose(mem, confidence, ui.ragebot.reso_cfg.yaw_calc:get() == 3, opt)
    local half = res_custom() and res_clamp(ui.ragebot.resolver.pred_sel:get(), 25, 70) / 100 or 0.5
    local value = 0
    local applied = p.samples >= 2 and p.nochoke < RES_NOCHOKE and resolver.fresh(p)
    if (applied) then
        value = resolver.hypothesis(candidate, hint, nx and -nx or 0, half, resolver.max_desync(st), c)
        st.m_flGoalFeetYaw = res_norm(eye + value)
    end

    local prev = resolver.previous[idx]
    if (prev == nil) then
        prev = {}
        resolver.previous[idx] = prev
    end
    prev.m_flDesync = value
    prev.m_flSide = value < 0 and -1 or 1
    prev.m_flState = key
    prev.m_flStateNum = RES_STATE_NUM[key] or RES_STATE_NUM[state]
    prev.is_forced = mem.misses > 0
    prev.state = state
    prev.key = key
    prev.kind = kind
    prev.rel = value ~= 0 and res_sign(value * hint) or 0
    prev.candidate, prev.confidence = applied and candidate or nil, confidence
    prev.model, prev.nxt = c, nx
    prev.phase, prev.reliab = prof.phase, prof.rel
end
resolver.on_result = function(target, hit_ok, resolver_miss, event, reason)
    local snapshot = target and resolver.take_shot(event, target:get_index()) or nil
    resolver.last_result = snapshot
    if (snapshot == nil or snapshot.track == nil or snapshot.track ~= resolver.data[snapshot.idx]) then return end
    -- a shot that the server tested against a target in a defensive shift / a broken lag comp: a miss says nothing about
    -- the body yaw we gave (it is lag comp), and Primordial reports it as "jitter" / "resolver". Hits still count
    local now = globals.real_time()
    snapshot.defensive = resolver.spoiled(snapshot.track, snapshot.time, snapshot.rtt or 0, now, "def") or nil
    snapshot.lagbreak = resolver.spoiled(snapshot.track, snapshot.time, snapshot.rtt or 0, now, "lc") or nil
    if (not hit_ok and (snapshot.defensive or snapshot.lagbreak)) then
        resolver_miss = false
    end
    resolver.record(snapshot, hit_ok, reason)
    if (target ~= nil) then
        local idx = target:get_index()
        if (hit_ok) then
            resolver.misses[idx] = 0
        elseif (resolver_miss) then
            resolver.misses[idx] = (resolver.misses[idx] or 0) + 1
        end
    end
    if (snapshot.key == nil or snapshot.candidate == nil) then
        return
    end
    local mem = resolver.memory(snapshot.idx, snapshot.key, snapshot.kind)
    local c = mem.candidates[snapshot.candidate]
    if (c == nil) then return end
    if (hit_ok or resolver_miss) then
        -- a changing target is followed: every counted result pulls all hypotheses of the situation back toward the start
        for _, h in ipairs(mem.candidates) do
            h.good = 1 + (h.good - 1) * resolver.K.forget
            h.bad = 1 + (h.bad - 1) * resolver.K.forget
        end
    end
    if (hit_ok) then
        mem.misses = 0
        mem.last_failed = nil
        c.good = c.good + 1
    elseif (resolver_miss) then
        mem.misses = mem.misses + 1
        c.bad = c.bad + 1
        mem.last_failed = snapshot.candidate
    end
end
resolver.body_damage = function(ent)
    local local_player = entity_list_get_local_player()
    if (local_player == nil or ent == nil) then return 0 end
    -- once per tick and target (HITSCAN runs per command, double tap sends many in one frame)
    resolver.body_damage_seen = resolver.body_damage_seen or {}
    local tick, seen = globals.tick_count(), resolver.body_damage_seen[ent:get_index()]
    if (seen ~= nil and seen.tick == tick) then return seen.damage end
    local best = resolver.body_damage_now(local_player, ent)
    resolver.body_damage_seen[ent:get_index()] = { tick = tick, damage = best }
    return best
end
resolver.body_damage_now = function(local_player, ent)
    local eye = local_player:get_eye_position()
    if (eye == nil) then return 0 end
    local best = 0
    for _, hitbox in ipairs({ e_hitboxes.CHEST, e_hitboxes.PELVIS }) do
        local point = ent:get_hitbox_pos(hitbox)
        if (point ~= nil) then
            local bullet = trace_bullet(eye, point, local_player, ent)
            if (bullet ~= nil and bullet.valid and (bullet.hitgroup == 2 or bullet.hitgroup == 3)) then
                best = math.max(best, res_clamp(bullet.damage, 0, 500))
            end
        end
    end
    return best
end
resolver.enforce_body = function(ctx)
    ctx:set_hitscan_group_state(e_hitscan_groups.HEAD, false, false)
    ctx:set_hitscan_group_state(e_hitscan_groups.CHEST, true, false)
    ctx:set_hitscan_group_state(e_hitscan_groups.STOMACH, true, false)
    for _, name in ipairs({ "ARMS", "LEGS", "FEET" }) do
        local group = e_hitscan_groups[name]
        if (group ~= nil) then ctx:set_hitscan_group_state(group, false, false) end
    end
end

-- safe points / smart body aim for the aimbot's target.
-- Health-threshold body aim is independent of resolver activation. Additional
-- safety requires active, fresh evidence and respects the fast-peek policy.
resolver.hitscan = function(ctx)
    local ent = ctx.player
    if (ent == nil) then
        return
    end

    local idx = ent:get_index()
    local misses = resolver.misses[idx] or 0
    local p = resolver.data[idx]
    local fast = resolver.fast_target(ent)
    -- a jittering target gets head + chest safe points no matter the resolver toggles (owners, Oct 2026: "ALWAYS ...
    -- every resolver toggle off too, not beta"): Primordial's own resolver can not be told the side, so a safe point is
    -- the only safe shot. The real shot logs (Oct 2026, 86 shots) had jitter as the top miss cause (16 / 32) with almost
    -- no shot carrying a safe point, because this was gated behind resolver.active
    local fresh = resolver.fresh(p)
    local jitter = fresh and p.jitter == true and (p.confidence or 0) >= 0.65
    local jitter_safe = jitter and not fast
    -- safe_all (a disabler set to "head safe point") forces safety even on a fast peek, as before
    local safe = resolver.active and resolver.safe_all == true
    if (not fast) then
        safe = safe or jitter
        if (resolver.active) then
            safe = safe or misses >= 2
        end
        if (resolver.active and res_custom()) then
            local opt = ui.ragebot.resolver
            safe = safe
                or (opt.duck_mode:get() and bit.band(tonumber(ent:get_prop("m_fFlags")) or 0, 2) ~= 0)
                or (opt.auto_duck:get() and bit.band(tonumber(ent:get_prop("m_fFlags")) or 0, 2) ~= 0
                    and table.contains(RES_SAFE_CFG, ragebot_get_active_cfg()))
                or (opt.safe_peek:get() and ragebot_get_autopeek_pos())
                or ((tonumber(ent:get_prop("m_iHealth")) or 100) <= opt.safe_mode:get())
        end
    end

    -- Below the configured HP: body only. On risky targets above the threshold,
    -- the optional lethal fallback requires an actual valid body bullet trace.
    local body = false
    if (ui.ragebot.smart_baim:get()) then
        local hp = tonumber(ent:get_prop("m_iHealth")) or 100
        local threshold = res_clamp(ui.ragebot.smart_baim_hp:get(), 0, 100)
        body = hp > 0 and hp < threshold
        if (not body and hp > 0 and ui.ragebot.smart_baim_lethal:get() and (jitter or misses >= 1)) then
            body = hp <= resolver.body_damage(ent)
        end
    end

    -- what the shot logs carry: 3 = body (smart body aim), 2 = a safe point for a jittering target, 1 = for another reason
    resolver.safe = resolver.safe or {}
    resolver.safe[idx] = body and 3 or (jitter_safe and 2) or (safe and 1) or nil
    if (body) then
        resolver.enforce_body(ctx)
    end
    if (safe and not body) then
        ctx:set_safepoint_state(true, e_hitscan_groups.HEAD)
    end
    if ((body and safe) or jitter_safe) then
        ctx:set_safepoint_state(true, e_hitscan_groups.CHEST)
    end
end

resolver.reset = function()
    resolver.carry = {}
    resolver.data = {}
    resolver.mem = {}
    resolver.previous = {}
    resolver.misses = {}
    resolver.safe = {}
    resolver.shots, resolver.last_result = {}, nil
    resolver.epoch = resolver.epoch + 1
    resolver.trust = { fs = 0, jitter = 0 }
    backtrack.peekers, backtrack.records, backtrack.peek_until, backtrack.predict_tick = {}, {}, 0, -1
    backtrack.high_until = 0
end
-- a new round (owners: "minden körben újra scanneli az aa-t, változott-e"): the players are new records (positions,
-- feet, runs start over) but what was learned about each stays, halved: an AA mostly stays between rounds, and the
-- first results of the new round overrule it fast if it was changed
resolver.new_round = function()
    local carry = {}
    for idx, mem in pairs(resolver.mem) do
        local p = resolver.data[idx]
        if (p ~= nil and p.sid ~= nil) then
            resolver.decay_memory(mem, resolver.K.round_keep)
            carry[p.sid] = mem
        end
    end
    resolver.reset()
    resolver.carry = carry
end
resolver.native = function(off, fallback)
    local want = not off and (fallback == true or auto_cfg.resolve_antiaim == true)
    if (resolver.native_on ~= want) then
        menu_find("Aimbot", "General", "Aimbot", "Resolve Antiaim"):set(want)
        resolver.native_off = off
        resolver.native_on = want
    end
end

update_target = function(ctx)
    if (ctx.player ~= nil) then resolver.previous.target = ctx.player:get_index() end
end

lets_resolve = function()
    local local_player = entity_list_get_local_player()
    -- OUR resolver always runs (owners, Oct 2026: "a Primo resolver outdated és rosszul működik"): no resolver toggle
    -- needed, Primordial's own "Resolve Antiaim" is only the fallback while the ping is high / the target data is stale
    local on = local_player ~= nil and info.plan ~= "beta"
    local mode = on and resolver.disabler(local_player) or 0

    resolver.active = on and mode ~= 1
    resolver.safe_all = mode == 2
    -- no fallback to Primordial's resolver at any ping (owners, Oct 2026: "mindig a sima Primo resot használja": the shot
    -- logs, 120-160 ms ping, were all native = true, High ping protection had switched ours off)
    local override = resolver.active
    resolver.native(override, false)
    if (local_player == nil) then
        return
    end

    local enemies = entity_list_get_players(true)
    if (enemies == nil) then
        return
    end

    for _, v in pairs(enemies) do
        if (v:is_alive() and not v:is_dormant()) then
            if (override) then
                resolver.update(local_player, v)
            else
                resolver.previous[v:get_index()] = nil
                local eye = v:get_prop("m_angEyeAngles[1]")
                if (type(eye) == "number" and eye == eye and math.abs(eye) <= 1e6) then
                    resolver.track(v, eye)
                end
            end
        else
            local idx = v:get_index()
            local p = resolver.data[idx]
            if (not v:is_alive()) then
                -- dead: the learning waits for the next life of that player (by steam id)
                if (p ~= nil and p.sid ~= nil and resolver.mem[idx] ~= nil) then
                    resolver.carry = resolver.carry or {}
                    resolver.carry[p.sid] = resolver.mem[idx]
                end
                resolver.data[idx], resolver.mem[idx] = nil, nil
            end
            -- dormant: the record goes stale (nothing is written, no safe point from it), what was learned stays
            resolver.previous[idx], resolver.misses[idx] = nil, nil
            if (resolver.safe) then resolver.safe[idx] = nil end
        end
    end
end
-- [pm-resolver:end]

--- @endregion


--- @info: shot logs (owners, Oct 2026: like Specter's): one JSON line per shot with a result, to the license server
--- (/shotlog, base64 parts) every 40 shots and at round start; the bot writes them to the "shotlogs" branch, folder
--- shotlogs/primordial (the batch ids start with "pm"). No names: the target is a hash of its steam id with a salt of this load
--- @region: shot logs

local shotlog = { server = presence.server, buf = {}, sending = false,
                  salt = tostring(client_get_unix_time()) .. tostring(math.random(1000000)) }

shotlog.hash = function(s)
    local h = 5381
    s = shotlog.salt .. tostring(s)
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 4294967296
    end
    return string.format("%08x", h)
end

shotlog.num = function(v, digits)
    v = tonumber(v)
    if (v == nil or v ~= v or v == math.huge or v == -math.huge) then
        return nil
    end
    local m = 10 ^ (digits or 0)
    return math.floor(v * m + 0.5) / m
end

-- an anti-aim result (kind "aa"): which state / modes were on when an enemy hit us or a bullet passed the head. The
-- dev build only (with a key nothing is sent)
shotlog.aa = function(kind, snap, hitgroup, damage)
    if (info.plan ~= "dev") then
        return
    end
    local row = {
        lua = "primordial", v = 1, kind = "aa", r = kind, t = client_get_unix_time(),
        map = engine_get_level_name and engine_get_level_name() or nil, ping = get_user_ping(),
        st = snap.name, ym = snap.ym, jm = snap.jm, ds = snap.ds, def = snap.def or nil, ab = snap.ab or nil,
        dc = snap.dc or nil, arm = snap.arm,
        hg = hitgroup, dmg = shotlog.num(damage),
    }
    local ok, line = pcall(libs.json.encode, row)
    if (ok and type(line) == "string") then
        shotlog.buf[#shotlog.buf + 1] = line
    end
    if (#shotlog.buf >= 40) then
        shotlog.send()
    end
end

-- the FPS profiler (see perf at the top): 10 s of timings, then the most expensive parts in ms per frame
perf.start = function()
    if (not perf.usable) then
        notifications.create("Specter", "No performance counter on this PC.", notifications.types.failure)
        return
    end
    perf.t, perf.n, perf.frames = {}, {}, 0
    perf.until_t = globals.real_time() + 10
    perf.on = true
    notifications.create("Specter", "Profiling for 10 seconds, play normally.", notifications.types.information)
end

perf.tick = function()
    if (not perf.on) then
        return
    end
    perf.frames = perf.frames + 1
    if (globals.real_time() < perf.until_t) then
        return
    end
    perf.on = false
    local frames = math.max(1, perf.frames)
    local rows = {}
    for name, ms in pairs(perf.t) do
        rows[#rows + 1] = { name = name, ms = ms / frames, calls = perf.n[name] or 0 }
    end
    table.sort(rows, function(a, b) return a.ms > b.ms end)
    print(string.format("specter perf: %d frames in 10 s (%.0f fps), ms per frame:", frames, frames / 10))
    local parts = {}
    for i = 1, math.min(#rows, 14) do
        local r = rows[i]
        print(string.format("  %-16s %7.3f ms  (%d calls)", r.name, r.ms, r.calls))
        parts[r.name] = math.floor(r.ms * 1000 + 0.5) / 1000
    end
    notifications.create("Specter", "Profile done, the results are in the console.", notifications.types.success)
    if (info.plan == "dev") then
        local ok, line = pcall(libs.json.encode, { lua = "primordial", v = 1, kind = "perf", t = client_get_unix_time(),
            fps = math.floor(frames / 10), ms = parts })
        if (ok and type(line) == "string") then
            shotlog.buf[#shotlog.buf + 1] = line
            pcall(shotlog.send)
        end
    end
end

shotlog.send = function()
    if (shotlog.sending or #shotlog.buf == 0) then
        return
    end
    local lines = shotlog.buf
    shotlog.buf = {}

    local data = libs.base64.encode(table.concat(lines, "\n"))
    local parts = {}
    for i = 1, #data, 3000 do
        parts[#parts + 1] = data:sub(i, i + 2999)
    end
    if (#parts > 60) then
        return
    end

    local id = "pm" .. shotlog.hash(globals.real_time() .. #lines):sub(1, 8) .. tostring(client_get_unix_time() % 100000)
    local base = shotlog.server .. "/shotlog?id=" .. id .. "&total=" .. #parts
    shotlog.sending = true
    local function part(i)
        local enc = parts[i]:gsub("([^%w%-_.~])", function(c) return string.format("%%%02X", c:byte()) end)
        libs.tools.http:get(base .. "&idx=" .. (i - 1) .. "&data=" .. enc, function(response)
            if (not response:success() or i >= #parts) then
                shotlog.sending = false
                return
            end
            part(i + 1)
        end)
    end
    part(1)
end

-- one line per shot result: what Primordial says about the shot, our resolver / backtrack / prediction state, the target
shotlog.result = function(shot, hit)
    local target = shot.player
    if (target == nil or info.plan ~= "dev") then -- with a key (the loader's versions) nothing is sent
        return
    end
    local idx = target:get_index()
    local local_player = entity_list_get_local_player()
    local weapon = local_player and local_player:get_active_weapon()
    local velocity = target:get_prop("m_vecVelocity")
    local steamid = target:get_steamids()
    local peeking = false
    for _, p in ipairs(backtrack.peekers) do
        if (p == idx) then
            peeking = true
        end
    end

    local row = {
        lua = "primordial", v = 1, t = client_get_unix_time(), map = engine_get_level_name_short(),
        ping = get_user_ping(), wpn = weapon and weapon:get_name() or nil,
        tg = shotlog.hash(steamid or idx), r = hit and "hit" or "miss",
        ahg = shot.aim_hitgroup, bt = shotlog.num(shot.backtrack_ticks), hc = shotlog.num(shot.aim_hitchance),
        adm = shotlog.num(shot.aim_damage),
        cm = resolver.misses[idx] or 0, sp = resolver.safe and resolver.safe[idx] or nil, native = not resolver.native_off, fp = backtrack.amount, peek = peeking or nil,
        spd = velocity and shotlog.num(math.vec_length2d(velocity)) or nil, fl = target:get_prop("m_fFlags"),
        eye = shotlog.num(target:get_prop("m_angEyeAngles[1]"), 1),
        lby = shotlog.num(target:get_prop("m_flLowerBodyYawTarget"), 1),
        hp = target:get_prop("m_iHealth"),
    }
    -- what our resolver did for this shot: situation (rk), hypothesis (cd, see resolver.NCAND), the body yaw it wrote (vl),
    -- the feet model's body yaw (md) and the side the jitter pattern predicted (nx)
    local snap = resolver.last_result
    if (snap ~= nil and snap.idx == idx) then
        row.rk, row.cd, row.vl = snap.key, snap.candidate, shotlog.num(snap.desync, 1)
        row.md, row.nx = shotlog.num(snap.model, 1), snap.nxt
        row.df, row.lb, row.sx = snap.defensive, snap.lagbreak, snap.state
        row.ph, row.rl = snap.phase, shotlog.num(snap.reliab, 2)
        row.l6, row.l6w = shotlog.num(snap.l6, 6), shotlog.num(snap.l6w, 4)
    end
    if (hit) then
        row.hg, row.dmg = shot.hitgroup, shotlog.num(shot.damage)
        row.dead = (tonumber(row.hp) or 1) <= 0 or nil
    else
        row.why = tostring(shot.reason_string or "?")
    end

    local ok, line = pcall(libs.json.encode, row)
    if (ok and type(line) == "string") then
        shotlog.buf[#shotlog.buf + 1] = line
        while (#shotlog.buf > 400) do
            table.remove(shotlog.buf, 1)
        end
    end
    if (#shotlog.buf >= 40) then
        shotlog.send()
    end
end

--- @endregion

--- @info: cool team animation with ffi animation
--- @region: animation

team_animation = function()
    -- Legacy cosmetic routine writes random values into animation state.
    -- Do not execute it while the resolver relies on those same records.
    if (resolver.active) then return end
    if (ui.player.team_anim:get()) then
        local players = entity_list_get_players()
        local teams = entity_list_get_players(true)

        if (players ~= nil and teams ~= nil) then
            for _, v in pairs(players) do
                local is_teammate = false
                for _, teammate in pairs(teams) do
                    if (v == teammate) then
                        is_teammate = true
                        break
                    end
                end
        
                if (v:is_alive()) then
                    if (not is_teammate) then
                        local anim_fix = ffi.cast("CPlayer_animation_State**", ffi.cast("uintptr_t", get_entity_address(v:get_index())) + 0x9960)[0]
            
                        anim_fix.m_flGoalFeetYaw = 549
                        anim_fix.m_flCurrentFeetYaw = -256

                        anim_fix.m_fDuckAmount = client_random_float(0, 1)
            
                        anim_fix.m_flHeadHeightOrOffsetFromHittingGroundanimation = client_random_float(-34.91, 50.6)
                        anim_fix.m_flPitch = client_random_float(-91, 34)
            
                        anim_fix.m_flanimUpdateDelta = client_random_float(-2.758, 3.985)
                        anim_fix.m_flLeanAmount = client_random_float(-29.15, 51.63)

                        anim_fix.m_vOriginZ = client_random_float(-8726, 87269)
                        anim_fix.m_vOriginY = client_random_float(-2154, 21543)
                        anim_fix.m_vOriginX = client_random_float(-6978, 69781)
            
                        anim_fix.m_vvelocity_x = client_random_float(-3410, 34109)
                        anim_fix.m_vvelocity_y = client_random_float(-9842, 98421)
            
                        anim_fix.m_flCurrentTorsoYaw = client_random_float(-789, 654)
                        anim_fix.m_flFeetYawRate = client_random_float(-987, 876)
                        anim_fix.m_flFeetCycle = client_random_float(0.194, 0.957)
            
                        anim_fix.m_flMagicFraction = client_random_float(-4.456, 7.987)
                        anim_fix.m_flSpeed2D = client_random_float(-10, 2450)
            
                        anim_fix.m_flUpVelocity = client_random_float(-20, 100)
                        anim_fix.m_flSpeedNormalized = client_random_float(-2.456, 5.789)

                        anim_fix.m_flFeetSpeedForwardsOrsideWays = client_random_float(-30, 80)
                        anim_fix.m_flFeetSpeedUnknownForwardOrsideways = client_random_float(-40, 60)
                    end
                end
            end
        else
            return
        end
    else
        return
    end
end

--- @endregion

--- @info: advanced antiaim (pasted from metaset)
--- @region: antiaim

run_exploit = function(ctx, cmd, unpredicted)
    local weapon = entity_list_get_local_player():get_active_weapon()
    if (weapon) then
        local aw = weapon ~= nil and global_vars_cur_time() < weapon:get_prop("m_fLastShotTime") + (global_vars_interval_per_tick() * 4)
        if (refs.hide_shots:get()) then
            refs.fake_lag_value:set(15)
            return
        end

        if (refs.double_tap:get() and not refs.quick_peek:get()) then
            if (((exploits_get_charge() < exploits_get_max_charge()) or (exploits_get_max_charge() == 0)) and (ui.exploits.fix_dt:get()) and (not refs.fake_duck:get()) and (global.velocity > 3)) then
                refs.fake_lag_value:set(0)
            else
                refs.fake_lag_value:set(15)
            end
        elseif (not refs.double_tap:get()) then
            if (ui.antiaim.features.fl_variance:get() and ui.antiaim.builder.enable:get()) then
                -- a different choke each cycle (10-15): no fixed rhythm for the enemy's extrapolation
                if (engine_get_choked_commands() == 0) then
                    refs.fake_lag_value:set(builder.rnd(10, 15))
                end
            else
                refs.fake_lag_value:set(15)
            end
        end

        if (not aw) then
            backup.realangle = antiaim_get_real_angle()
        end

        if (aw and ui.antiaim.features.fakelag:get()) then
            refs.desyncside:set(1)
            if (weapon:get_name() == "ssg08" or weapon:get_name() == "awp" or weapon:get_name() == "revolver") then
                if (backup.realangle == nil) then
                    backup.realangle = 0
                end
                ctx:set_yaw(backup.realangle)
            else
                return
            end
            return
        else
            return
        end
    else
        return
    end
end

builder.lerp = function(start, end_pos, time)
    local alpha = 1 - math.exp(-math.max(0, time) * 170 * math.max(0, globals.frame_time()))
    local val = start + (end_pos - start) * alpha
    if (start == end_pos) then
        return end_pos
    end

    if (math.abs(val - end_pos) < 0.01) then
        return end_pos
    end
    return val
end

builder.spin = function(custom_speed)
    local currentstate = ui.antiaim.builder[global.current_state_number].override:get() and global.current_state_number or 1
    
    local speed = ui.antiaim.builder[currentstate].defensive_speed:get()
    local range = ui.antiaim.builder[currentstate].defensive_range:get()

    builder.speed = builder.speed + (custom_speed or speed) / 2
    if (builder.speed < -range) then
        builder.speed = builder.speed + (2 * range)
    elseif (builder.speed > range) then
        builder.speed = builder.speed - (2 * range)
    end
    return builder.speed
end

builder.clockpitch = function()
    if (builder.current_pitch <= -88) then
        builder.goal_pitch = 89
    elseif (builder.current_pitch >= 88) then
        builder.goal_pitch = -89
    end
    builder.current_pitch = builder.lerp(builder.current_pitch, builder.goal_pitch, 0.10)
end

builder.clockyaw = function()
    if (builder.current_yaw <= -59) then
        builder.goal_yaw = 60
    elseif (builder.current_yaw >= 59) then
        builder.goal_yaw = -60
    end
    builder.current_yaw = builder.lerp(builder.current_yaw, builder.goal_yaw, 0.10)
end

-- one decision per sent packet: the yaw left / right switch and the desync side, a fresh coin flip that is not tied to
-- the yaw side (a resolver that learns "yaw left = body right" from a few shots hits every shot after that)
builder.new_packet = function()
    local tick = globals.tick_count()
    local state = global.current_state_number
    builder.fresh = false
    local reset = builder.packet_tick ~= nil and tick < builder.packet_tick
    local changed = builder.packet_state ~= state
    if (reset or changed) then
        builder.xw_st = {}
        builder.ds_st = {}
        builder.hd_st, builder.jit_st, builder.def_st = {}, {}, {}
        builder.brain_d, builder.base_yaw, builder.jit_off = {}, nil, nil
        builder.amount_left, builder.amount_right = nil, nil
        builder.advanced_left, builder.advanced_right = nil, nil
        builder.target_delay = 0
        if (reset) then
            builder.ab_until, builder.ab_phase_until, builder.ab_trigger_tick = 0, 0, nil
            builder.brain, builder.incoming = {}, {}
            builder.packet_tick = nil
        end
        builder.packet_state = state
    end
    if ((engine_get_choked_commands() == 0 and builder.packet_tick ~= tick) or changed) then
        builder.fresh = true
        builder.packet_tick = tick
        builder.yaw_flip = not builder.yaw_flip
        builder.side_flip = math.random(2) == 1
    end
end

-- the yaw side of the "switch every packet" modes (delay 2): our own switch, or Primordial's desync side (old behaviour)
builder.left_now = function()
    if (ui.antiaim.builder.random_side:get()) then
        return builder.yaw_flip == true
    end
    return antiaim_get_desync_side() > 1
end

-- the desync side of the jitter / switching modes; a fixed side the user chose (static yaw, left / right / peek) stays
builder.random_side = function(ctx, anti_aim)
    local forced = anti_aim.desync:get() == 5
    if (not forced and not ui.antiaim.builder.random_side:get()) then
        return
    end
    if (not forced and anti_aim.yaw_mode:get() == 1 and anti_aim.desync:get() ~= 3) then
        return
    end
    refs.desyncside:set(2)
    ctx:set_invert_desync((builder.side_flip == true) ~= (builder.ab_active() and builder.ab_flip == true))
end

-- Adaptive AA at run time (see builder.adv.ARMS): the profile of the state's group sets the yaw switch timing and the
-- desync side on top of the state's settings. A static yaw (manual / fakelag states) and a fixed side the user chose
-- (Left / Right / Peek, Random desync side off) stay as they are
builder.brain, builder.brain_d = {}, {}
builder.brain_apply = function(ctx, anti_aim)
    builder.brain_now, builder.brain_index = nil, nil
    if (not ui.antiaim.builder.adaptive:get() or anti_aim.yaw_mode:get() == 1) then
        return
    end
    local group = builder.adv.arm_group(global.current_state_number)
    local index = builder.adv.brain_arm(builder.brain, group, globals.real_time(), math.random)
    local arm = builder.adv.ARMS[index]
    builder.brain_now = arm.name
    builder.brain_index = index
    local yaw_left
    if (arm.delay) then
        local d, tick = builder.brain_d, globals.tick_count()
        if (d.yaw == nil or (builder.fresh and (tick >= (d.until_t or 0) or tick < (d.until_t or 0) - 256))) then
            d.left = not d.left
            d.until_t = tick + math.max(3, anti_aim.yaw_delay:get()) + builder.rnd(0, anti_aim.meta_delay:get())
            d.yaw = d.left and (anti_aim.yaw_left:get() + builder.rnd(0, anti_aim.yaw_meta_left:get()))
                or (anti_aim.yaw_right:get() + builder.rnd(0, anti_aim.yaw_meta_right:get()))
        end
        builder.set_yaw(d.yaw)
        yaw_left = d.left == true
    else
        yaw_left = (builder.base_yaw or 0) < anti_aim.yaw_val:get()
    end

    if (anti_aim.desync:get() == 5 or ui.antiaim.builder.random_side:get()) then
        local invert = builder.adv.arm_invert(arm.side, yaw_left, builder.side_flip)
        refs.desyncside:set(2)
        ctx:set_invert_desync(invert ~= (builder.ab_active() and builder.ab_flip == true))
    end
end

-- anti bruteforce: an enemy bullet passing near the head or a hit moves the yaw 6-14 deg for 0.5-0.85 s and restarts
-- the left / right switch, so the angle the enemy just shot at is not the next one
builder.anti_brute_trigger = function()
    if (not ui.antiaim.builder.enable:get() or not ui.antiaim.builder.anti_brute:get()) then
        return
    end
    local tick = globals.tick_count()
    if (builder.ab_trigger_tick ~= nil and tick >= builder.ab_trigger_tick
        and tick - builder.ab_trigger_tick < math.max(1, time_to_ticks(0.15))) then
        return
    end
    builder.ab_trigger_tick = tick
    builder.target_delay = 0
    builder.yaw_flip = not builder.yaw_flip
    builder.brain_d.until_t = 0      -- Adaptive AA's delay profiles switch at the next packet too
    if (ui.antiaim.builder.ab_mode:get() == 2) then
        -- "Phases": the next phase for 4-7 s, its own centre shift, spread / jitter scale and desync side
        builder.ab_phase_until = globals.tick_count() + time_to_ticks(4 + math.random() * 3)
        builder.ab_center = builder.rnd(8, 22) * (math.random(2) == 1 and 1 or -1)
        builder.ab_scale = builder.rnd(70, 140) / 100
        builder.ab_flip = math.random(2) == 1
        builder.xw_st.bag = nil
        return
    end
    builder.ab_until = globals.tick_count() + time_to_ticks(client_random_float(0.5, 0.85))
    builder.ab_shift = client_random_int(6, 14) * (math.random(2) == 1 and 1 or -1)
end

-- the yaw add of the builder, kept apart from what is added on top of it (anti bruteforce, crouch correction)
builder.set_yaw = function(value)
    builder.base_yaw = value
    refs.yawadd:set(builder.yaw_now())
end

builder.yaw_now = function()
    local yaw = (builder.base_yaw or refs.yawadd:get()) + (builder.jit_off or 0)
    if ((builder.ab_until or 0) > globals.tick_count()) then
        yaw = yaw + builder.ab_shift
    end
    if (builder.ab_active()) then
        yaw = yaw + builder.ab_center
    end
    return math.max(-180, math.min(180, yaw))
end

builder.closest_point_on_ray = function(ray_from, ray_to, desired_point)
    local to = desired_point - ray_from
    local direction = ray_to - ray_from
    local ray_length = #direction
    if (ray_length <= 0.000001) then return ray_from end
    direction.x = direction.x / ray_length
    direction.y = direction.y / ray_length
    direction.z = direction.z / ray_length
    
    local direction_along = direction.x * to.x + direction.y * to.y + direction.z * to.z
    if (direction_along < 0) then
        return ray_from
    end
    
    if (direction_along > ray_length) then
        return ray_to
    end
    return vec3_t(ray_from.x + direction.x * direction_along, ray_from.y + direction.y * direction_along, ray_from.z + direction.z * direction_along)
end

-- advanced anti-aim (owners, Oct 2026: "nagyon advanced aa ... nagyon nehezen eltalalhato"): the parts that decide the
-- angles, without the game api (tests/primordial_regress.py runs them). Every yaw / jitter / side value is decided once per
-- sent packet, held until the next one
builder.xw_st, builder.ds_st, builder.hd_st, builder.jit_st, builder.def_st = {}, {}, {}, {}, {}
builder.adv = {}

-- a random integer of [a, b] in either order (a slider can give b < a)
builder.rnd = function(a, b)
    a, b = tonumber(a) or 0, tonumber(b) or 0
    if (a ~= a or b ~= b or math.abs(a) > 1e6 or math.abs(b) > 1e6) then
        a, b = 0, 0
    end
    a, b = math.floor(a + 0.5), math.floor(b + 0.5)
    if (b < a) then
        a, b = b, a
    end
    return math.random(a, b)
end

-- a yaw in -180 .. 180
builder.adv.norm = function(yaw)
    if (type(yaw) ~= "number" or yaw ~= yaw or math.abs(yaw) > 1e9) then
        return 0
    end
    yaw = (yaw + 180) % 360 - 180
    return math.max(-180, math.min(180, yaw))
end

-- X-Way: `ways` yaw positions spread over centre +- range, taken from a shuffled bag (every position once a round, never
-- the same one twice in a row), each held 1 .. hold packets
builder.adv.xway = function(st, ways, range, center, hold, rnd)
    ways = math.max(2, math.min(32, math.floor(ways)))
    if (st.range ~= range or st.center ~= center) then
        st.value, st.hold = nil, 0
        st.range, st.center = range, center
    end
    st.hold = (st.hold or 0) - 1
    if (st.hold > 0 and st.value ~= nil and st.ways == ways) then
        return st.value
    end
    if (st.bag == nil or #st.bag == 0 or st.ways ~= ways) then
        st.ways = ways
        st.bag = {}
        for k = 1, ways do
            st.bag[k] = k
        end
        for k = ways, 2, -1 do
            local j = rnd(1, k)
            st.bag[k], st.bag[j] = st.bag[j], st.bag[k]
        end
        if (st.bag[ways] == st.last) then
            st.bag[1], st.bag[ways] = st.bag[ways], st.bag[1]
        end
    end
    local k = table.remove(st.bag)
    st.last = k
    st.hold = rnd(1, math.max(1, math.floor(hold)))
    st.value = center + range * (2 * (k - 1) / (ways - 1) - 1)
    return st.value
end

-- Distort: the yaw creeps toward a random target in centre +- range (speed % of the way per packet), a new target when
-- it is reached, and now and then (snap %) it jumps there at once
builder.adv.distort = function(st, range, center, speed, snap, rnd)
    range = math.abs(range)
    st.cur = st.cur or center
    if (st.target == nil or math.abs(st.target - st.cur) < 2 or math.abs(st.target - center) > range) then
        st.target = center + rnd(-range, range)
    end
    if (rnd(1, 100) <= snap) then
        st.cur = st.target
    else
        st.cur = st.cur + (st.target - st.cur) * math.max(1, math.min(100, speed)) / 100
    end
    st.cur = math.max(center - range, math.min(center + range, st.cur))
    return st.cur
end

-- Random hold: left / right, each side held a random 1 .. hold packets
builder.adv.hold = function(st, left, right, hold, rnd)
    st.hold = (st.hold or 0) - 1
    if (st.hold <= 0) then
        st.left = not st.left
        st.hold = rnd(1, math.max(1, math.floor(hold)))
    end
    return st.left and left or right
end

-- the lua jitter on top of the yaw: 6 "Random" = anywhere in +- degree, 7 "Switch random" = the other side each packet,
-- degree + 0 .. random big
builder.adv.jitter = function(st, mode, degree, random, rnd)
    degree, random = math.abs(degree), math.abs(random)
    if (mode == 6) then
        return rnd(-degree, degree)
    end
    st.sign = -(st.sign or 1)
    return st.sign * (degree + rnd(0, random))
end

-- defensive pitch 11 "Random up/down" (up or down, picked at each defensive start) / 12 "Sway" (between the two values)
builder.adv.def_pitch = function(st, mode, v1, v2, fresh, t, rnd)
    if (mode == 11) then
        if (fresh or st.pitch == nil) then
            st.pitch = rnd(1, 2) == 1 and -89 or 89
        end
        return st.pitch
    end
    return v1 + (v2 - v1) * (0.5 + 0.5 * math.sin(t * 8))
end

-- defensive yaw (yaw add): 9 "Opposite" = 180 from the yaw now, 10 "Random side" = 90 .. 150 to a random side, picked at
-- each defensive start, 11 "Jitter flick" = +- value, flipped every SENT packet (`tick` = its parity: the game tick would stay on one
-- side when the choke is even), 12 "Distort" = creeping to random targets in +- value
builder.adv.def_yaw = function(st, mode, value, yaw, fresh, tick, rnd)
    local v = math.abs(value)
    if (mode == 9) then
        return builder.adv.norm(yaw + 180)
    elseif (mode == 10) then
        if (fresh or st.side == nil) then
            st.side = (rnd(1, 2) == 1 and 1 or -1) * rnd(90, 150)
        end
        return st.side
    elseif (mode == 11) then
        return tick % 2 == 0 and v or -v
    end
    st.dcur = st.dcur or 0
    if (fresh or st.dtarget == nil or math.abs(st.dtarget - st.dcur) < 3) then
        st.dtarget = rnd(-v, v)
    end
    st.dcur = st.dcur + (st.dtarget - st.dcur) * 0.35
    return builder.adv.norm(st.dcur)
end

-- does an enemy look at us: its eye yaw within `tol` degrees of the direction from it to us
-- can this enemy fire a gun within `tol` seconds: a gun (no knife / grenade / bomb), a round in it, the next shot not further away
builder.adv.armed = function(held, clip, ready_in, tol)
    if (type(held) ~= "string" or held == "" or held:find("knife", 1, true) or held == "bayonet" or held == "c4"
        or held:find("grenade", 1, true) or held == "flashbang" or held == "molotov" or held == "decoy" or held == "taser") then
        return false
    end
    if (type(clip) == "number" and clip <= 0) then
        return false
    end
    return type(ready_in) ~= "number" or ready_in <= (tol or 0.15)
end

builder.adv.aims_at = function(eye_yaw, dx, dy, tol)
    if (type(eye_yaw) ~= "number" or eye_yaw ~= eye_yaw or (dx == 0 and dy == 0)) then
        return false
    end
    local to_us = math.deg(math.atan2(dy, dx))
    return math.abs(builder.adv.norm(eye_yaw - to_us)) < tol
end

-- Adaptive AA (owners, Oct 2026: "az aa sokkal jobb volt [the old azura] ... nagyon advanced aa improve ami tényleg
-- unhittable"): no fixed anti-aim beats every resolver, each one guesses the desync side its own way (from the jitter, by
-- bruteforce, by learning). So the lua plays several profiles and keeps the one the enemies of THIS match can not hit.
-- A profile = when the yaw switches + which side the desync goes:
--   delay: left / right every few ticks (the state's Delay + fluctuation, the old azura "Advanced" mode), else the
--   state's own yaw mode (X-Way / Distort / Random hold, a new yaw per packet);
--   tied: the desync on the yaw side (the old azura), inverse: on the other side, coin: a fresh coin flip per packet.
builder.adv.ARMS = {
    { name = "Packet coin", delay = false, side = "coin" },
    { name = "Delay tied", delay = true, side = "tied" },
    { name = "Delay inverse", delay = true, side = "inverse" },
    { name = "Delay coin", delay = true, side = "coin" },
    { name = "Packet tied", delay = false, side = "tied" },
}
builder.adv.BRAIN_DECAY = 0.9       -- every result pulls all profiles of the group back toward the prior (resolvers adapt)
builder.adv.BRAIN_HOLD = { 6, 10 }  -- seconds a profile is kept before it is drawn again (a head hit switches at once)

-- which states learn together: 1 standing / ducking, 2 moving, 3 air, 4 the rest (global, fakelag, manual, freestand)
builder.adv.arm_group = function(state)
    if (state == 2 or state == 5) then
        return 1
    elseif (state == 3 or state == 4 or state == 6) then
        return 2
    elseif (state == 7 or state == 8) then
        return 3
    end
    return 4
end

-- a draw from Beta(a, b) for Thompson sampling: its mean + its spread x an Irwin-Hall normal (12 uniforms), so no
-- log / sqrt of a random number (a bad math.log in a shared lua table gave NaN in the gamesense resolver)
builder.adv.beta_sample = function(a, b, u)
    local n = a + b
    local z = -6
    for _ = 1, 12 do
        z = z + u()
    end
    return math.max(0, math.min(1, a / n + math.sqrt(a * b / (n * n * (n + 1))) * z))
end

-- the beliefs of a group: per profile a = 1 + bullets that passed the head, b = 1 + head hits (decayed); the old azura
-- "Delay tied" starts one evade ahead (the owners: it was the best)
builder.adv.brain_group = function(st, group)
    st.g = st.g or {}
    local g = st.g[group]
    if (g == nil) then
        g = { arms = {}, cur = nil, until_t = 0 }
        for i = 1, #builder.adv.ARMS do
            g.arms[i] = { a = (i == 2) and 2 or 1, b = 1 }
        end
        st.g[group] = g
    end
    return g
end

-- Thompson sampling: every profile draws from its belief, the highest draw plays (not `exclude`, the one just hit)
builder.adv.brain_pick = function(st, group, now, u, exclude)
    local g = builder.adv.brain_group(st, group)
    local best, best_v = nil, -1
    for i, arm in ipairs(g.arms) do
        if (i ~= exclude) then
            local v = builder.adv.beta_sample(arm.a, arm.b, u)
            if (v > best_v) then
                best, best_v = i, v
            end
        end
    end
    local hold = builder.adv.BRAIN_HOLD
    g.cur = best
    g.until_t = now + hold[1] + (hold[2] - hold[1]) * u()
    return best
end

-- the profile of a group now (drawn again when its time is up)
builder.adv.brain_arm = function(st, group, now, u)
    local g = builder.adv.brain_group(st, group)
    if (g.cur == nil or now >= g.until_t or now < g.until_t - 60) then
        return builder.adv.brain_pick(st, group, now, u)
    end
    return g.cur
end
builder.adv.brain_learn = function(st, group, kind, hitgroup, now, u, credited_arm)
    local g = builder.adv.brain_group(st, group)
    local cur = credited_arm or g.cur
    if (cur == nil or g.arms[cur] == nil) then
        return
    end
    local head = kind == "hit" and hitgroup == 1
    if (kind ~= "evaded" and not head) then
        return
    end
    local d = builder.adv.BRAIN_DECAY
    for i, arm in ipairs(g.arms) do
        local prior_a = (i == 2) and 2 or 1
        arm.a = prior_a + (arm.a - prior_a) * d
        arm.b = 1 + (arm.b - 1) * d
    end
    if (head) then
        g.arms[cur].b = g.arms[cur].b + 1
        if (g.cur == cur) then builder.adv.brain_pick(st, group, now, u, cur) end
    else
        g.arms[cur].a = g.arms[cur].a + 1
    end
end

-- the desync invert of a profile: Primordial's side is "left", invert = right. tied: left yaw (the Left value) = left
-- desync, inverse: the other one, coin: the packet's coin flip
builder.adv.arm_invert = function(side, yaw_left, coin)
    if (side == "tied") then
        return not yaw_left
    elseif (side == "inverse") then
        return yaw_left
    end
    return coin == true
end

-- anti bruteforce "Phases": while a phase runs (4-7 s after a bullet near the head) the yaw centre is shifted, the
-- jitter / spread is scaled and the desync side is the other one
builder.ab_active = function()
    return (builder.ab_phase_until or 0) > globals.tick_count()
end

builder.ab_scale_now = function()
    return builder.ab_active() and builder.ab_scale or 1
end

-- the Primordial desync side of a state: 1-4 its list, 5 "Random" = left, flipped per packet by random_side
builder.desync_side = function(anti_aim)
    local d = anti_aim.desync:get()
    return d == 5 and 2 or d + 1
end

-- AA stats (owners, Oct 2026: "melyikkel hányszor találnak el"): per anti-aim state how often an enemy hit us and how
-- often a bullet passed the head without a hit, with the modes that were on; shown by draw_aa_stats, and from the dev
-- build one shot log line each (kind "aa") so the config is tuned by real games
builder.aa_stats = {}
builder.AA_NAMES = {
    yaw = { "Static", "Classic", "Advanced", "X-Way", "Distort", "Random hold" },
    jitter = { "None", "Offset", "Center", "3Way", "5Way", "Random", "Switch random" },
    desync = { "Left", "Right", "Jitter", "Peek fake", "Random" },
}

-- the anti-aim as it is now: the state and the modes of the builder entry it uses
builder.aa_snapshot = function()
    local n = global.current_state_number
    if (states[n] == nil) then
        n = 1
    end
    local cs = ui.antiaim.builder[n].override:get() and n or 1
    local aa = ui.antiaim.builder[cs]
    return {
        n = n,
        name = states[n],
        ym = builder.AA_NAMES.yaw[aa.yaw_mode:get()] or "?",
        jm = builder.AA_NAMES.jitter[aa.yaw_modifier:get()] or "?",
        ds = builder.AA_NAMES.desync[aa.desync:get()] or "?",
        def = builder.old_defensive == true,
        ab = builder.ab_active(),
        dc = builder.direct_on(),
        arm = builder.brain_now,
        arm_index = builder.brain_index,
        time = globals.real_time(),
    }
end
-- Capture enemy fire before delayed bullet-impact/hurt feedback.
builder.incoming = {}
builder.capture_incoming = function(entity)
    if (entity == nil or not entity:is_enemy() or not ui.antiaim.builder.enable:get()) then return end
    local now = globals.real_time()
    for idx, row in pairs(builder.incoming) do
        if (now < row.time or now - row.time > 2) then builder.incoming[idx] = nil end
    end
    local snap = builder.aa_snapshot()
    snap.hurt, snap.evaded = false, false
    local previous = builder.incoming[entity:get_index()]
    snap.ambiguous = previous ~= nil and now - previous.time < 0.15
        and not previous.hurt and not previous.evaded
    builder.incoming[entity:get_index()] = snap
end
builder.incoming_snapshot = function(entity)
    local snap = entity and builder.incoming[entity:get_index()] or nil
    local now = globals.real_time()
    if (snap ~= nil and not snap.ambiguous and now >= snap.time and now - snap.time <= 2) then return snap end
    return nil
end
builder.aa_record = function(kind, hitgroup, damage, attacker, snapshot)
    if (not ui.antiaim.builder.enable:get()) then
        return
    end
    local snap = snapshot or builder.aa_snapshot()
    -- Unattributed damage still appears in stats, but cannot train an arm.
    if (snapshot ~= nil and snap.arm_index ~= nil) then
        builder.adv.brain_learn(builder.brain, builder.adv.arm_group(snap.n), kind, hitgroup,
            globals.real_time(), math.random, snap.arm_index)
    end
    local key = snap.name .. " · " .. (snap.arm or snap.ym)
    local row = builder.aa_stats[key]
    if (row == nil) then
        row = { n = snap.n, label = key, hit = 0, head = 0, evaded = 0 }
        builder.aa_stats[key] = row
    end
    if (kind == "hit") then
        row.hit = row.hit + 1
        if (hitgroup == 1) then
            row.head = row.head + 1
        end
        if (ui.utils.aa_stats:get()) then
            print("hit in ", get_text_color(), key, specter_color_t(168, 168, 168), " · ", get_text_color(),
                tostring(client_get_hitgroup_name(hitgroup) or "?"), specter_color_t(168, 168, 168), " · ", get_text_color(),
                tostring(damage or 0), specter_color_t(168, 168, 168), " dmg by ", get_text_color(), tostring(attacker or "?"))
        end
    else
        row.evaded = row.evaded + 1
    end
    pcall(shotlog.aa, kind, snap, hitgroup, damage)
end

-- "Apply advanced preset": every state on the advanced modes, the same values as the anti-aim of default.cfg (owners:
-- "csináld meg a legjobb configot ezzel"): tight yaw (X-Way +- 18-32, Distort, Random hold), a small lua jitter, Random
-- desync 60, Smart defensive with Random up/down / Sway pitch and Random side / Distort / Jitter flick yaw
builder.apply_preset = function()
    local function set(item, ...)
        if (item ~= nil and item.ref ~= nil) then
            pcall(item.ref.set, item.ref, ...)
        end
    end
    local b = ui.antiaim.builder
    set(b.enable, true)
    set(b.random_side, true)
    set(b.anti_brute, true)
    set(b.ab_mode, 2)
    set(b.pitch, 2)
    set(b.yaw, 2)
    set(b.defensive_ping, 1)
    set(ui.antiaim.features.fl_variance, true)
    set(b.adaptive, true)

    -- state: yaw mode, centre, ways, range, hold, sway, snap, left, right, jitter mode, degree, random, smart triggers,
    -- defensive pitch, pitch 1, pitch 2, defensive yaw, yaw value
    local P = {
        [1] = { 4, 0, 5, 25, 2, 40, 15, -15, 10, 6, 12, 0, {}, 11, -89, 89, 10, 120 },
        [2] = { 4, 0, 5, 25, 2, 40, 15, -23, 24, 6, 12, 0, {}, 11, -89, 89, 10, 120 },
        [3] = { 5, 0, 5, 22, 2, 40, 15, -10, 10, 7, 14, 8, { "Peek" }, 11, -89, 89, 12, 120 },
        [4] = { 6, 0, 5, 22, 3, 40, 15, -20, 15, 6, 10, 0, {}, 11, -89, 89, 10, 120 },
        [5] = { 4, 0, 3, 18, 2, 40, 15, -15, 10, 6, 8, 0, {}, 11, -89, 89, 10, 120 },
        [6] = { 5, 0, 5, 18, 2, 45, 20, -18, 15, 6, 10, 0, {}, 11, -89, 89, 12, 100 },
        [7] = { 4, 0, 5, 30, 1, 40, 15, -25, 25, 7, 16, 10, { "Air" }, 12, -89, 89, 12, 120 },
        [8] = { 4, 0, 7, 32, 1, 40, 15, -15, 7, 6, 14, 0, {}, 11, -89, 89, 11, 140 },
    }
    -- the delay profiles of Adaptive AA play the old azura left / right (the owner's values) with this randomization
    local META = { [1] = { 0, 0 }, [2] = { 0, 0 }, [3] = { -18, 18 }, [4] = { 0, 0 }, [5] = { -11, 11 }, [6] = { 0, 0 },
        [7] = { -20, 20 }, [8] = { 0, 0 } }
    for i, v in pairs(P) do
        local st = b[i]
        set(st.override, true)
        set(st.yaw_mode, v[1])
        set(st.yaw_val, v[2])
        set(st.yaw_ways, v[3])
        set(st.yaw_range, v[4])
        set(st.yaw_hold, v[5])
        set(st.sway_speed, v[6])
        set(st.snap_chance, v[7])
        set(st.yaw_left, v[8])
        set(st.yaw_right, v[9])
        set(st.yaw_meta_left, META[i][1])
        set(st.yaw_meta_right, META[i][2])
        set(st.yaw_modifier, v[10])
        set(st.modifier_degree, v[11])
        set(st.modifier_random, v[12])
        set(st.desync, 5)
        set(st.desync_left, 60)
        set(st.desync_right, 60)
        set(st.desync_meta_left, 0)
        set(st.desync_meta_right, 0)
        -- defensive only where it pays (owners, Oct 2026): on peek while running, and in the air (not crouched in the air); off standing, crouched, slow
        -- walking and freestanding (the shift there only gave the resolver a free miss)
        set(st.trigger_defensive, (i == 3 or i == 7) and 6 or 1)
        for _, name in ipairs({ "Peek", "Shot at", "Air", "Threat aim", "Random" }) do
            local on = false
            for _, want in ipairs(v[13]) do
                on = on or want == name
            end
            set(st.smart_triggers, name, on)
        end
        set(st.defensive_pitch, v[14])
        set(st.defensive_pitch_val, v[15])
        set(st.defensive_pitch_val2, v[16])
        set(st.defensive_yaw, v[17])
        set(st.defensive_yaw_val, v[18])
    end

    -- Freestand (shot logs, Oct 2026: a static yaw with the desync always "Right", no defensive: 7 head and 34 body hits
    -- in 58 shots at us): the yaw stays freestanding's (Classic), the desync side a coin flip, a small lua jitter, no defensive
    local fr = b[11]
    if (fr ~= nil) then
        set(fr.desync, 5)
        set(fr.desync_meta_left, 0)
        set(fr.desync_meta_right, 0)
        set(fr.yaw_modifier, 6)
        set(fr.modifier_degree, 8)
        set(fr.modifier_random, 0)
        set(fr.trigger_defensive, 1)
    end
    notifications.create("Specter", "Advanced anti-aim preset applied to every state.", notifications.types.success)
end

-- the Primordial jitter types (yaw add on top of the yaw), the lua's version for direct control: 1 Offset (0 / range),
-- 2 Center (-range/2 / +range/2), 3 3Way (-range, 0, range), 4 5Way (-range .. range in 5 steps); the next step per packet
builder.adv.native_jitter = function(st, kind, range, fresh)
    if (fresh) then
        st.step = (st.step or 0) + 1
    end
    local step = st.step or 0
    if (kind == 1) then
        return step % 2 == 0 and 0 or range
    elseif (kind == 2) then
        return step % 2 == 0 and -range / 2 or range / 2
    elseif (kind == 3) then
        return (step % 3 - 1) * range
    end
    return (step % 5 - 2) * range / 2
end

-- direct control (owners, Oct 2026: "teljesen saját antiaimot ... ami csak a luaba van", "csak a devbe"): the anti-aim code
-- above stays as it is, but in the dev build (no key) with "Direct control" on what it writes into Primordial's anti-aim
-- menu is collected instead (`refs` swapped for recorders, ctx:set_* recorded), and at the end of the tick the lua sends
-- the angles itself: ctx:set_yaw (the base it computes + 180 + yaw add + its jitter / spin), ctx:set_pitch,
-- ctx:set_desync (-1 .. 1, left negative, like the workshop luas; the invert stays off so the two can not cancel out).
-- Primordial's own yaw add / jitter / spin / pitch are kept neutral, its desync on (left, 100 %) so set_desync has one to
-- steer; peek fake / peek real stay Primordial's (the lua can not see its peek logic)
builder.DIRECT_REFS = { "pitch", "yawbase", "yawadd", "rotate", "rotaterange", "rotatespeed", "jittermode", "jittertype",
    "jitterrange", "desyncside", "leftamount", "rightamount" }
builder.direct = { out = {}, real = {}, jit = {}, spin = 0, jside = 1, pjit = 1, side = 2 }

builder.direct_on = function()
    return info.plan == "dev" and ui.antiaim.builder.enable:get() and ui.antiaim.builder.direct:get()
end

-- the refs the anti-aim code writes become recorders until direct_restore
builder.direct_begin = function()
    local d = builder.direct
    d.out = {}
    for _, f in ipairs(builder.DIRECT_REFS) do
        local real = d.real[f] or refs[f]
        d.real[f] = real
        refs[f] = {
            set = function(_, v)
                d.out[f] = v
            end,
            get = function()
                if (d.out[f] ~= nil) then
                    return d.out[f]
                end
                return real:get()
            end,
        }
    end
end

builder.direct_restore = function()
    for f, real in pairs(builder.direct.real) do
        refs[f] = real
    end
end

-- the ctx the anti-aim code gets: the angle / desync calls are recorded, everything else goes to the real one
builder.direct_ctx = function(ctx)
    local o = builder.direct.out
    return setmetatable({
        set_yaw = function(_, v) o.abs_yaw = v end,
        set_pitch = function(_, v) o.abs_pitch = v end,
        set_invert_desync = function(_, v) o.invert = v end,
        set_desync = function(_, v) o.desync = v end,
    }, {
        __index = function(_, k)
            local f = ctx[k]
            if (type(f) == "function") then
                return function(_, ...)
                    return f(ctx, ...)
                end
            end
            return f
        end,
    })
end

-- the yaw the anti-aim looks away from: 2 the view, 3 the enemy nearest the crosshair, 4 the nearest enemy (the base
-- items of the builder + 1); nil = no yaw at all (1, the round end)
-- own freestanding (direct control, owners Oct 2026: "teljesen saját aa ... minden"): which side of our head the threat
-- can not see. The fractions of the two traces from its eye to our head moved W units left / right: one side behind a
-- wall (fraction < 0.97) and the other open = hide on that side (+1 left, -1 right); both covered = keep the side we
-- had (the head is hidden either way, no flicking), none covered = 0 (the normal anti-aim)
builder.adv.fs_pick = function(left, right, prev)
    local lb, rb = left < 0.97, right < 0.97
    if (lb and not rb) then
        return 1
    elseif (rb and not lb) then
        return -1
    elseif (lb and rb) then
        return prev
    end
    return 0
end

builder.own_fs = { side = 0, tick = -100, yaw = nil }
-- the freestanding yaw (absolute), nil when no wall covers one side; traces every 4 ticks
builder.own_freestand = function(local_player)
    if (local_player == nil) then
        return nil
    end
    local fs, tick = builder.own_fs, globals.tick_count()
    if (tick - fs.tick < 4 and tick >= fs.tick) then
        return fs.yaw
    end
    fs.tick = tick
    fs.yaw = nil
    local head = local_player:get_hitbox_pos(e_hitboxes.HEAD)
    local view = engine_get_view_angles()
    if (head == nil or view == nil or type(view.y) ~= "number") then
        return nil
    end
    -- the threat: the enemy nearest the crosshair
    local threat, best
    for _, enemy in pairs(entity_list_get_players(true) or {}) do
        if (enemy:is_alive() and not enemy:is_dormant()) then
            local o = enemy:get_render_origin()
            local off = o ~= nil and math.abs(builder.adv.norm(math.deg(math.atan2(o.y - head.y, o.x - head.x)) - view.y))
            if (off and (best == nil or off < best)) then
                threat, best = enemy, off
            end
        end
    end
    if (threat == nil) then
        fs.side = 0
        return nil
    end
    local eye = threat:get_eye_position()
    if (eye == nil) then
        return nil
    end
    local to = math.atan2(eye.y - head.y, eye.x - head.x)
    local w = 24
    local lx, ly = math.cos(to + math.pi / 2) * w, math.sin(to + math.pi / 2) * w
    -- walls only (0x400B, no player models: our own body would count as a wall)
    local left = trace_line(eye, vec3_t(head.x + lx, head.y + ly, head.z), threat, 0x400B)
    local right = trace_line(eye, vec3_t(head.x - lx, head.y - ly, head.z), threat, 0x400B)
    left, right = left and left.fraction, right and right.fraction
    if (type(left) ~= "number" or type(right) ~= "number" or left ~= left or right ~= right) then
        return nil
    end
    fs.side = builder.adv.fs_pick(left, right, fs.side)
    if (fs.side ~= 0) then
        fs.yaw = builder.adv.norm(math.deg(to) + 90 * fs.side)
    end
    return fs.yaw
end

-- manual left / right / back (Primordial's manual keys): our yaw relative to the view, nil when none is held
builder.own_manual = function()
    if (refs.left:get()) then
        return 90
    elseif (refs.right:get()) then
        return -90
    elseif (refs.back:get()) then
        return 180
    end
    return nil
end

builder.direct_base = function(local_player, mode)
    if (mode == nil or mode <= 1) then
        return nil
    end
    local view = engine_get_view_angles()
    if (mode == 2) then
        return view.y
    end
    local eye = local_player:get_eye_position()
    local best, best_val
    for _, enemy in pairs(entity_list_get_players(true) or {}) do
        if (enemy:is_alive() and not enemy:is_dormant()) then
            local o = enemy:get_render_origin()
            local yaw = math.deg(math.atan2(o.y - eye.y, o.x - eye.x))
            local val = mode == 3 and math.abs(builder.adv.norm(yaw - view.y)) or ((o.x - eye.x) ^ 2 + (o.y - eye.y) ^ 2)
            if (best_val == nil or val < best_val) then
                best, best_val = yaw, val
            end
        end
    end
    return best or view.y
end

-- what the anti-aim code decided this tick, sent with the real ctx
builder.direct_apply = function(ctx, local_player)
    local d = builder.direct
    local o, R = d.out, d.real
    R.yawadd:set(0)
    R.jittermode:set(1)
    R.rotate:set(false)
    R.pitch:set(1)

    -- yaw: an own absolute yaw of the anti-aim code (defensive flicks, edge yaw), else manual (Primordial's manual keys,
    -- relative to the view), else own freestanding with the Freestand key (the head on the side the threat can not see;
    -- Primordial's auto direction is not used: an absolute set_yaw overrides it, the head came out from behind the
    -- wall, 41 hits in 51 shots at the Freestand state), else base + 180 + the yaw add / jitter
    local manual = o.abs_yaw == nil and builder.own_manual() or nil
    local free = (o.abs_yaw == nil and manual == nil and refs.freestand ~= nil and refs.freestand:get() == true)
        and builder.own_freestand(local_player) or nil
    if (o.abs_yaw ~= nil) then
        ctx:set_yaw(builder.adv.norm(o.abs_yaw))
    elseif (manual ~= nil) then
        ctx:set_yaw(builder.adv.norm(engine_get_view_angles().y + manual))
    elseif (free ~= nil) then
        ctx:set_yaw(free)
    else
        local base = builder.direct_base(local_player, o.yawbase or d.yawbase)
        d.yawbase = o.yawbase or d.yawbase
        if (base ~= nil) then
            local yaw = base + 180 + (o.yawadd or 0)
            if (o.rotate) then
                local range = math.max(1, o.rotaterange or 360)
                if (builder.fresh) then
                    d.spin = (d.spin + math.max(1, o.rotatespeed or 50) / 10) % range
                end
                yaw = base + 180 + d.spin - range / 2
            elseif (o.jittermode == 2) then
                yaw = yaw + builder.adv.native_jitter(d.jit, o.jittertype or 1, o.jitterrange or 0, builder.fresh)
            end
            ctx:set_yaw(builder.adv.norm(yaw))
        end
    end

    -- pitch: 1 Off, 2 Down, 3 Up, 4 Zero, 5 Jitter (up / down per packet)
    if (o.abs_pitch ~= nil) then
        ctx:set_pitch(o.abs_pitch)
    else
        local p = o.pitch or 1
        if (p == 5 and builder.fresh) then
            d.pjit = -d.pjit
        end
        local value = ({ [2] = 89, [3] = -89, [4] = 0, [5] = 89 * d.pjit })[p]
        if (value ~= nil) then
            ctx:set_pitch(value)
        end
    end

    -- desync: Primordial's side list 1 none, 2 left, 3 right, 4 jitter, 5 peek fake, 6 peek real
    if (o.desyncside ~= nil) then
        d.side = o.desyncside
    end
    local la = math.max(0, math.min(100, o.leftamount or R.leftamount:get()))
    local ra = math.max(0, math.min(100, o.rightamount or R.rightamount:get()))
    if (d.side == 5 or d.side == 6) then
        R.desyncside:set(d.side)
        R.leftamount:set(la)
        R.rightamount:set(ra)
    elseif (d.side <= 1) then
        R.desyncside:set(d.side)
    else
        local left = d.side == 2
        if (d.side == 4) then
            if (builder.fresh) then
                d.jside = -d.jside
            end
            left = d.jside > 0
        end
        if (o.invert) then
            left = not left
        end
        d.last_left = left
        R.desyncside:set(2)
        R.leftamount:set(100)
        R.rightamount:set(100)
        ctx:set_invert_desync(false)
        ctx:set_desync((left and -la or ra) / 100)
    end
end

-- the on peek defensive check = an UNSAFE peek (owners, Oct 2026: "ha unsafe a peek akkor kapcsolja be ... jelenleg a defensive nem
-- segít semmit, csak hátráltat"): an enemy that can really shoot us - a gun with a round in it that is ready to fire - and whose
-- bullet reaches our head or chest 3 ticks from now. It was "he can hit our feet OR we can hit him", so a peek the enemy could do
-- nothing about (his gun empty / knife out / wall at our head) shifted the double tap and left us without a shot. Two bullet traces
-- per enemy, and Primordial runs the anti-aim once per command: double tap sends many commands in one frame (owners, Oct 2026:
-- "lagging only in mid mirage with dt": an open map with every enemy in view and long traces). Each enemy is traced at most once
-- per 4 ticks, at most 2 enemies per frame; meanwhile its last result stays
builder.peek_seen, builder.peek_budget = {}, { frame = -1, left = 0 }
builder.peek_visible = function(local_player, player, abs_origin, localmod)
    local tick, idx = globals.tick_count(), player:get_index()
    local seen = builder.peek_seen[idx]
    if (seen ~= nil and tick >= seen.tick and tick - seen.tick < 4) then
        return seen.visible
    end
    local budget, frame = builder.peek_budget, global_vars_frame_count()
    if (budget.frame ~= frame) then
        budget.frame, budget.left = frame, 2
    end
    if (budget.left <= 0) then
        return seen ~= nil and seen.visible
    end
    budget.left = budget.left - 1
    local visible = false
    local weapon = player:get_active_weapon()
    local ready = true
    if (weapon ~= nil) then
        local next_shot = tonumber(weapon:get_prop("m_flNextPrimaryAttack"))
        ready = builder.adv.armed(weapon:get_name(), tonumber(weapon:get_prop("m_iClip1")),
            next_shot and next_shot - globals.cur_time() or nil)
    end
    local vel, origin = player:get_prop("m_vecVelocity"), player:get_eye_position()
    local head = local_player:get_eye_position()
    if (ready and vel ~= nil and origin ~= nil and head ~= nil) then
        local ahead = globals.interval_per_tick() * 3
        local from = origin + vec3_t(vel.x * ahead, vel.y * ahead, vel.z * ahead)
        local at_head = trace_bullet(from, head + localmod, local_player, player)
        visible = at_head.valid and at_head.damage > 3
        if (not visible) then
            local at_body = trace_bullet(from, abs_origin + localmod + vec3_t(0, 0, 40), local_player, player)
            visible = at_body.valid and at_body.damage > 3
        end
    end
    builder.peek_seen[idx] = { tick = tick, visible = visible }
    return visible
end

-- safe head by height (the gamesense lua's trace, owners, Oct 2026: "add safehead to the aa"): an enemy more than 5 units below
-- us whose bullet reaches our head. Looked at most every 4 ticks and 2 enemies at a time (a trace per command is too much)
builder.height = { tick = -100, on = false }
builder.height_safe = function(local_player)
    local tick, h = globals.tick_count(), builder.height
    if (tick >= h.tick and tick - h.tick < 4) then
        return h.on
    end
    h.tick, h.on = tick, false
    -- a netvar that comes in another shape than expected must not stop the callback (pcall)
    pcall(function()
        local origin, head = local_player:get_prop("m_vecAbsOrigin"), local_player:get_hitbox_pos(e_hitboxes.HEAD)
        if (origin == nil or head == nil) then
            return
        end
        local looked = 0
        for _, enemy in pairs(entity_list_get_players(true) or {}) do
            local o = enemy:is_alive() and not enemy:is_dormant() and enemy:get_prop("m_vecAbsOrigin") or nil
            if (o ~= nil and origin.z - o.z > 5) then
                looked = looked + 1
                local eye = enemy:get_eye_position()
                local traced = eye ~= nil and trace_bullet(eye, head + vec3_t(0, 0, 6), enemy, local_player) or nil
                if (traced ~= nil and traced.valid and (traced.damage or 0) > 0) then
                    h.on = true
                    return
                end
                if (looked >= 2) then
                    return
                end
            end
        end
    end)
    return h.on
end

run_antiaim = function(ctx, cmd, unpredicted)
    if (ui.antiaim.builder.enable:get()) then
        refs.overridemove:set(false)
        refs.overridemovesw:set(false)
        
        local currentstate = ui.antiaim.builder[global.current_state_number].override:get() and global.current_state_number or 1
        local anti_aim = ui.antiaim.builder[currentstate]

        local local_player = entity_list_get_local_player()
        local should_safe = 0
        local enemies = 0
        
        local visible = false
        local knifed = false

        local players = entity_list_get_players(true)
        local abs_origin = local_player:get_prop('m_vecAbsOrigin')
        
        local local_vel = local_player:get_prop("m_vecVelocity")
        local local_wep = local_player:get_active_weapon()

        local safe_defensive = ui.antiaim.builder.defensive_ping:get() == 1
        local antiaim_side = antiaim_get_desync_side() > 1 and 1 or -1
        if (builder.direct_on() and builder.direct.last_left ~= nil) then
            -- direct control: Primordial's menu side is always "left" (the side goes in the sign of set_desync)
            antiaim_side = builder.direct.last_left and -1 or 1
        end

        local on_defensive = (anti_aim.trigger_defensive:get() == 2 or anti_aim.trigger_defensive:get() == 4 or anti_aim.trigger_defensive:get() == 6)
        local is_defensive = refs.double_tap:get() and (exploits_get_charge() == exploits_get_max_charge()) and not refs.fake_duck:get()

        local body_yaw = local_player:get_prop("m_flPoseParameter", 11) * 120 - 60
        local side = body_yaw > 0 and 1 or -1

        local localmod = vec3_t(local_vel.x / 2, local_vel.y / 2, local_vel.z / 2)
        local int_vel = local_vel:length()
        
        builder.warmup = game_rules_get_prop("m_bWarmupPeriod")
        builder.onpeek = anti_aim.trigger_defensive:get() == 2

        -- smart defensive: what may trigger it this tick
        local trig = anti_aim.trigger_defensive:get()
        local smart = trig == 6 and anti_aim.smart_triggers or nil
        local threat = false
        local hp = local_player:get_prop("m_iHealth")
        if (builder.last_hp ~= nil and hp ~= nil and hp < builder.last_hp) then
            builder.shot_at_tick = globals.tick_count()
        end
        builder.last_hp = hp

        if (builder.old_defensive ~= defensive:is_active(local_player, safe_defensive) and defensive:is_active(local_player, safe_defensive) == false) then
            builder.invert_defensive = not builder.invert_defensive
        end
    
        if (game_rules_get_prop("m_gamePhase") == 4 or game_rules_get_prop("m_gamePhase") == 5) then
            refs.pitch:set(1)
            
            refs.yawbase:set(1)
            refs.jittermode:set(1)
            
            refs.desyncside:set(0)
            
            refs.fsstate:set(1, false)
            refs.fsstate:set(2, false)
            refs.fsstate:set(3, false)
            
            return
        end
    
        refs.fsstate:set(1, true)
        refs.fsstate:set(2, true)
        refs.fsstate:set(3, true)
    
        builder.anti_bruteforce = {
            [0] = {
                sides = {-120, 120},
                pitch = {-90, -90},
                mode = 1
            },

            [1] = {
                sides = {80, 80},
                pitch = {0, 0},
                mode = 2
            },

            [2] = {
                sides = {-90, -90},
                pitch = {math.random(-45, 60), math.random(-45, 60)},
                mode = 0
            },

            [3] = {
                sides = {90, 90},
                pitch = {math.random(-45, 60), math.random(-45, 60)},
                mode = 0
            }
        }

        for _, player in pairs(players) do
            if (player:is_alive() and player:is_player()) then
                enemies = enemies + 1
    
                if (smart ~= nil and smart:get(4) and not threat and not player:is_dormant()) then
                    local eye = player:get_eye_position()
                    local ok, eye_yaw = pcall(player.get_prop, player, "m_angEyeAngles[1]")
                    if (ok and eye ~= nil) then
                        threat = builder.adv.aims_at(tonumber(eye_yaw), abs_origin.x - eye.x, abs_origin.y - eye.y, 20)
                    end
                end

                if (anti_aim.trigger_defensive:get() == 2 or (smart ~= nil and smart:get(1))) then
                    if (not player:is_dormant() and builder.peek_visible(local_player, player, abs_origin, localmod)) then
                        visible = true
                    end
                end
    
                if (ui.antiaim.features.antibackstab:get()) then
                    if (not player:is_dormant()) then
                        local enemy_weapon = player:get_active_weapon()
                        if (enemy_weapon ~= nil) then
                            if (enemy_weapon:get_class_name() == "CKnife") then
                                if (local_player:get_render_origin():dist(player:get_render_origin()) < 250) then
                                    knifed = player
                                end
                            end
                        end
                    end
                end
            end
        end

        if (not cmd:has_button(e_cmd_buttons.USE)) then
            if (ui.antiaim.features.warmup:get(1) and enemies == 0) or (builder.warmup and ui.antiaim.features.warmup:get(2) and builder.warmup > 0) then
                if (local_player:get_prop("m_bInBombZone") == 1) then
                    exploits.force_anti_exploit_shift(true)
                    
                    refs.yawadd:set(0)
                    refs.pitch:set(4)
                    
                    refs.jittermode:set(2)
                    refs.rotate:set(true)
                    
                    refs.rotaterange:set(360)
                    refs.rotatespeed:set(75)
                    
                    refs.desyncside:set(5)
                    
                    return
                end
                return
            end
        
            builder.new_packet()
            refs.jittertype:set(2)
            refs.rotate:set(false)
            
            refs.pitch:set(ui.antiaim.builder.pitch:get())
            refs.yawbase:set(ui.antiaim.builder.yaw:get() + 1)
            if (builder.fresh or builder.amount_left == nil) then
                builder.amount_left = math.max(0, math.min(100, anti_aim.desync_left:get() / 60 * 100
                    + builder.rnd(0, anti_aim.desync_meta_left:get())))
                builder.amount_right = math.max(0, math.min(100, anti_aim.desync_right:get() / 60 * 100
                    + builder.rnd(0, anti_aim.desync_meta_right:get())))
            end
            refs.leftamount:set(builder.amount_left)
            refs.rightamount:set(builder.amount_right)
            if (anti_aim.yaw_modifier:get() >= 6) then
                -- the lua jitter (Random / Switch random): one offset per sent packet on top of the yaw
                refs.jittermode:set(1)
                if (builder.fresh or builder.jit_off == nil) then
                    builder.jit_off = builder.adv.jitter(builder.jit_st, anti_aim.yaw_modifier:get(),
                        anti_aim.modifier_degree:get() * builder.ab_scale_now(), anti_aim.modifier_random:get(), builder.rnd)
                end
            elseif (anti_aim.yaw_modifier:get() ~= 1) then
                builder.jit_off = 0
                refs.jittermode:set(2)
                
                refs.jittertype:set(anti_aim.yaw_modifier:get() - 1)
                refs.jitterrange:set(anti_aim.modifier_degree:get() * -1 + anti_aim.modifier_random:get())
            else
                builder.jit_off = 0
                refs.jittermode:set(1)
            end
        
            -- safe head: pitch down, yaw to the target, no jitter / desync. Air knife / Air zeus = crouched in the air with that
            -- weapon out, Height advantage = an enemy below us can hit the head
            local safe_opt, safe_on = ui.antiaim.features.safehead, false
            if ((safe_opt:get("Air knife") or safe_opt:get("Air zeus")) and global.current_state == "air duck") then
                local weapon = entity_list_get_entity(local_player:get_prop("m_hActiveWeapon"))
                local weapon_name = weapon ~= nil and weapon:get_name() or nil
                safe_on = (weapon_name == "knife" and safe_opt:get("Air knife")) or (weapon_name == "taser" and safe_opt:get("Air zeus"))
            end
            if (not safe_on and safe_opt:get("Height advantage")) then
                safe_on = builder.height_safe(local_player)
            end
            if (safe_on) then
                ctx:set_pitch(90)
                refs.yawadd:set(0)
                refs.desyncside:set(2)
                refs.leftamount:set(0)
                refs.jittermode:set(1)
                refs.rotate:set(false)
                should_safe = safe_opt:get("Allow defensive") and 2 or 1
            end

            if (should_safe == 0) then
                if (anti_aim.yaw_mode:get() == 1) then
                    builder.set_yaw(anti_aim.yaw_val:get())
                    refs.desyncside:set(builder.desync_side(anti_aim))
                elseif (anti_aim.yaw_mode:get() == 2) then
                    if (anti_aim.yaw_delay:get() == 2) then
                        builder.set_yaw(builder.left_now() and anti_aim.yaw_left:get() or anti_aim.yaw_right:get())
                        refs.desyncside:set(builder.desync_side(anti_aim))
                    else
                        if (engine_get_choked_commands() == 0) then
                            if (globals.tick_count() > builder.target_delay) then
                                builder.target_delay = globals.tick_count() + anti_aim.yaw_delay:get()
                                builder.invert_delay = not builder.invert_delay
                            end
        
                            refs.desyncside:set(builder.invert_delay and 2 or 3)
                            builder.set_yaw(builder.invert_delay and anti_aim.yaw_left:get() or anti_aim.yaw_right:get())
                        end
                    end
                elseif (anti_aim.yaw_mode:get() == 3) then
                    if (builder.fresh or builder.advanced_left == nil) then
                        builder.advanced_left = anti_aim.yaw_left:get() + builder.rnd(0, anti_aim.yaw_meta_left:get())
                        builder.advanced_right = anti_aim.yaw_right:get() + builder.rnd(0, anti_aim.yaw_meta_right:get())
                    end
                    local left, right = builder.advanced_left, builder.advanced_right
                    if (anti_aim.yaw_delay:get() == 2 and anti_aim.meta_delay:get() == 0) then
                        builder.set_yaw(builder.left_now() and left or right)
                        refs.desyncside:set(builder.desync_side(anti_aim))
                    else
                        if (engine_get_choked_commands() == 0) then
                            if (globals.tick_count() > builder.target_delay) then
                                builder.target_delay = globals.tick_count() + anti_aim.yaw_delay:get() + math.random(0, anti_aim.meta_delay:get())
                                builder.invert_delay = not builder.invert_delay
                            end
        
                            refs.desyncside:set(builder.invert_delay and 2 or 3)
                            builder.set_yaw(builder.invert_delay and left or right)
                        end
                    end
                elseif (anti_aim.yaw_mode:get() >= 4) then
                    -- X-Way / Distort / Random hold: a new yaw per sent packet
                    if (builder.fresh or builder.base_yaw == nil) then
                        local mode, scale = anti_aim.yaw_mode:get(), builder.ab_scale_now()
                        local center = anti_aim.yaw_val:get()
                        local yaw
                        if (mode == 4) then
                            yaw = builder.adv.xway(builder.xw_st, anti_aim.yaw_ways:get(), anti_aim.yaw_range:get() * scale, center,
                                anti_aim.yaw_hold:get(), builder.rnd)
                        elseif (mode == 5) then
                            yaw = builder.adv.distort(builder.ds_st, anti_aim.yaw_range:get() * scale, center, anti_aim.sway_speed:get(),
                                anti_aim.snap_chance:get(), builder.rnd)
                        else
                            yaw = builder.adv.hold(builder.hd_st, anti_aim.yaw_left:get() + builder.rnd(0, anti_aim.yaw_meta_left:get()),
                                anti_aim.yaw_right:get() + builder.rnd(0, anti_aim.yaw_meta_right:get()), anti_aim.yaw_hold:get(), builder.rnd)
                        end
                        builder.set_yaw(yaw)
                    end
                    refs.desyncside:set(builder.desync_side(anti_aim))
                end

                builder.random_side(ctx, anti_aim)
                builder.brain_apply(ctx, anti_aim)
            end
        
            if (should_safe == 0 and builder.base_yaw ~= nil) then
                refs.yawadd:set(builder.yaw_now())
            end

            if (smart ~= nil) then
                local tick = globals.tick_count()
                if (smart:get(5) and tick >= (builder.rand_next or 0)) then
                    builder.rand_next = tick + 8
                    builder.rand_on = math.random(100) <= 30
                end
                local shot_at = smart:get(2) and tick - (builder.shot_at_tick or -100000) < time_to_ticks(1.5)
                if (shot_at or (smart:get(1) and visible)
                    or (smart:get(3) and (global.current_state_number == 7 or global.current_state_number == 8))
                    or (smart:get(4) and threat) or (smart:get(5) and builder.rand_on)) then
                    defensive:trigger(shot_at, cmd:has_button(e_cmd_buttons.ATTACK))
                end
            elseif (anti_aim.trigger_defensive:get() == 2 and visible) then
                defensive:trigger(false, cmd:has_button(e_cmd_buttons.ATTACK))
            elseif (anti_aim.trigger_defensive:get() > 2) then
                defensive:trigger(false, cmd:has_button(e_cmd_buttons.ATTACK))
            end
        
            if (not (should_safe == 1)) then
                if (defensive:is_active(local_player, safe_defensive) and is_defensive and on_defensive) then
                    local def_fresh = not builder.old_defensive
                    if (anti_aim.defensive_pitch:get() >= 11) then
                        ctx:set_pitch(builder.adv.def_pitch(builder.def_st, anti_aim.defensive_pitch:get(), anti_aim.defensive_pitch_val:get(),
                            anti_aim.defensive_pitch_val2:get(), def_fresh, globals.real_time(), builder.rnd))
                    elseif (anti_aim.defensive_pitch:get() == 10) then
                        ctx:set_pitch(builder.current_pitch)
                    elseif (anti_aim.defensive_pitch:get() == 7) then
                        ctx:set_pitch(math.random(anti_aim.defensive_pitch_val:get(), anti_aim.defensive_pitch_val2:get()))
                    elseif (anti_aim.defensive_pitch:get() == 8) then
                        ctx:set_pitch(anti_aim.defensive_pitch_val:get())
                    elseif (anti_aim.defensive_pitch:get() == 9) then
                        ctx:set_pitch(builder.invert_defensive and anti_aim.defensive_pitch_val:get() or anti_aim.defensive_pitch_val2:get())
                    elseif (anti_aim.defensive_pitch:get() > 1) then
                        refs.pitch:set(anti_aim.defensive_pitch:get() - 1)
                    end
        
                    if (anti_aim.defensive_yaw:get() == 2) then
                        if (currentstate == 11) then
                            ctx:set_yaw(builder.save_yaw + (60 * antiaim_side) - anti_aim.defensive_yaw_val:get())
                        else
                            refs.yawadd:set(anti_aim.defensive_yaw_val:get())
                        end
                    elseif (anti_aim.defensive_yaw:get() == 3) then
                        refs.desyncside:set(4)
                        refs.yawadd:set(anti_aim.defensive_yaw_val:get() * antiaim_side)
                    elseif (anti_aim.defensive_yaw:get() == 4) then
                        refs.yawadd:set(globals.server_tick() % 24 > 11 and -anti_aim.defensive_yaw_val:get() or anti_aim.defensive_yaw_val:get())
                        refs.desyncside:set(globals.server_tick() % 24 > 11 and 2 or 3)
                    elseif (anti_aim.defensive_yaw:get() == 5) then
                        ctx:set_yaw(builder.spin(ui.antiaim.builder[currentstate].defensive_speed:get()))
                        refs.desyncside:set(5)
                    elseif (anti_aim.defensive_yaw:get() == 6) then
                        ctx:set_yaw(math.random(0, 360))
                    elseif (ui.antiaim.builder[currentstate].defensive_yaw:get() == 7) then
                        refs.jittermode:set(2)
                        refs.jittertype:set(4)
                        refs.jitterrange:set(180)
                        refs.desyncside:set(4)
                    elseif (ui.antiaim.builder[currentstate].defensive_yaw:get() == 8) then
                        refs.yawadd:set(builder.current_yaw)
                        refs.desyncside:set(builder.goal_yaw < 0 and 3 or 2)
                    elseif (anti_aim.defensive_yaw:get() >= 9) then
                        refs.yawadd:set(builder.adv.def_yaw(builder.def_st, anti_aim.defensive_yaw:get(), anti_aim.defensive_yaw_val:get(),
                            builder.yaw_now(), def_fresh, builder.yaw_flip and 0 or 1, builder.rnd))
                    end
                end
        
                if (not (defensive:is_active(local_player, true, true).tick > globals.tick_count())) then
                    builder.save_yaw = antiaim_get_real_angle()
                end
        
                if (anti_aim.trigger_defensive:get() == 5) then
                    if (is_defensive) then
                        if (defensive:is_active(local_player, safe_defensive)) then
                            local side = antiaim_get_desync_side() > 1 and 1 or 2
        
                            ctx:set_pitch(builder.anti_bruteforce[builder.misses].pitch[side])
                            if (builder.anti_bruteforce[builder.misses].mode == 1) then
                                refs.jittermode:set(2)
                                refs.jittertype:set(2)
                                
                                refs.yawadd:set(0)
                                refs.jitterrange:set(builder.anti_bruteforce[builder.misses].sides[1])
                            elseif (builder.anti_bruteforce[builder.misses].mode == 0) then
                                refs.yawadd:set(builder.anti_bruteforce[builder.misses].sides[side])
                            elseif (builder.anti_bruteforce[builder.misses].mode == 2) then
                                ctx:set_yaw(builder.spin(builder.anti_bruteforce[builder.misses].sides[side]))
                            end
                        end
                    end
                end
            end
        
            local forward = cmd:has_button(e_cmd_buttons.FORWARD)
            
            local right = cmd:has_button(e_cmd_buttons.MOVERIGHT)
            local left = cmd:has_button(e_cmd_buttons.MOVELEFT)
            
            local use = cmd:has_button(e_cmd_buttons.USE)
            local speed = math.vec_length2d(local_vel)
            
            local ivgleft = speed / 80 * 2
            local ivgright = speed / 80 * 10
        
            if (knifed ~= false) then
                ctx:set_yaw(math.yaw_to_player(knifed, true))
                refs.rotate:set(false)
                
                refs.desyncside:set(2)
                refs.leftamount:set(0)
            end
        
            if (ui.antiaim.features.correction:get("Yaw") and (global.current_state_number == 5 or global.current_state_number == 6)) then
                if (not defensive:is_active(local_player, safe_defensive)) then
                    if (right and forward) then
                        refs.yawadd:set(builder.yaw_now() + ivgright * (ui.antiaim.builder[currentstate].yaw_mode:get() == 3 and 1 or 1.3))
                    end
                    
                    if (left and forward) then
                        refs.yawadd:set(builder.yaw_now() - ivgleft)
                    end
                end
            end
            builder.old_defensive = defensive:is_active(local_player, safe_defensive)
        end
    else
        return
    end
end

on_miss = function(event)
    if (ui.antiaim.builder.enable:get()) then
        local userid = event.userid
        if (userid) then
            local entity = entity_list_get_player_from_userid(userid)
            if (entity ~= nil) then
                local local_player = entity_list_get_local_player()
                if (local_player ~= nil and local_player:is_player() and local_player:is_alive()) then
                    if (entity:is_player() and entity:is_enemy()) then
                        local eye_pos = entity:get_eye_position()
                        if (eye_pos) then
                            local bullet_impact = vec3_t(event.x, event.y, event.z)
                            
                            local localrecord = eye_pos:dist(bullet_impact)
                            local localorigin = eye_pos
                            local snapshot = builder.incoming_snapshot(entity)
                            misstable[#misstable + 1] = eye_pos:dist(bullet_impact)
                            client_delay_call(function()
                                if (localrecord == misstable[#misstable]) then
                                    local eye_pos = local_player:get_eye_position()
                                    if (eye_pos) then
                                        if (builder.closest_point_on_ray(localorigin, bullet_impact, eye_pos):dist(eye_pos) < 50) then
                                            builder.misses = builder.misses < #builder.anti_bruteforce and builder.misses + 1 or 0
                                            builder.anti_brute_trigger()
                                            if (snapshot ~= nil and not snapshot.hurt and not snapshot.evaded
                                                and globals.tick_count() - hurt_tick > 8) then
                                                snapshot.evaded = true
                                                builder.aa_record("evaded", nil, nil, nil, snapshot)
                                            end
                                        end

                                        misstable = {}
                                        return
                                    else
                                        return
                                    end
                                else
                                    return
                                end
                            end, 0.15)
                        else
                            return
                        end
                    else
                        return
                    end
                else
                    return
                end
            else
                return
            end
        else
            return
        end
    else
        return
    end
end

--- @endregion

--- @info: rubberbang | no recharge until safe place | teleport back after shot | doubletap optimizer
--- @region: quickfall | safe recharge | better hideshots | better doubletap

quick_fall = function(cmd, unpredicted_data)
    if (ui.exploits.quick_fall:get() and ui.quick_fall:get()) then
        local enemies = entity_list_get_players(true)
        if (enemies ~= nil) then
            local in_air = entity_list_get_local_player():get_prop("m_vecVelocity[2]") ~= 0
            local is_visible = false

            for _, enemy in pairs(enemies) do
                if (in_air) then
                    if (is_point_visible(enemy)) then
                        is_visible = true
                    end
                end
            end

            if (not is_visible and not in_air) then
                exploits_allow_recharge()
            elseif (is_visible) then
                exploits_force_uncharge()
                exploits_block_recharge()
            end
            return
        else
            return
        end
    else
        return
    end
end

safe_recharge = function(cmd, unpredicted_data)
    if (ui.exploits.safe_recharge:get()) then
        local enemies = entity_list_get_players(true)
        if (enemies ~= nil) then
            local is_visible = false
            for _, enemy in pairs(enemies) do
                if (is_point_visible(enemy)) then
                    is_visible = true
                end
            end

            if (not is_visible and not entity_list_get_local_player():get_prop("m_vecVelocity[2]") ~= 0) then
                exploits_allow_recharge()
            end

            if (is_visible) then
                exploits_block_recharge()
            elseif (not is_visible) then
                exploits_allow_recharge()
            end
            return
        else
            return
        end
    elseif (not ui.exploits.safe_recharge:get()) then
        exploits_allow_recharge()
    end
    return
end

better_hs = function(cmd)
    if (ui.exploits.better_hs:get()) then
        if (on_shoot) then
            local on_hideshots = menu_find("aimbot", "general", "exploits", "hideshots", "enable")
            local on_peek = menu_find("aimbot", "general", "misc", "autopeek", "enable")

            if (on_hideshots[2]:get() and on_peek[2]:get()) then
                local velocity = entity_list_get_local_player():get_prop("m_vecVelocity"):length()
                if (velocity > 35) then
                    exploits_force_uncharge()
                    exploits_force_recharge()

                    on_shoot = false
                    table.insert(on_predict, false)
                else
                    return
                end
                return
            else
                return
            end
        else
            return
        end
    else
        return
    end
end

-- the double tap speed (sv_maxusrcmdprocessticks), written only when it changes: it was set every frame (15 with Better
-- DT off, once per enemy with the distance modes), a cvar write per call (owners, Oct 2026: 70 fps).
-- Never more than the SERVER allows (owners, Oct 2026: "az improve doubletap miatt laggolok, nem tudok mozogni"): the cvar is
-- replicated, so what the client reads before we write it is the server's limit (16 by default, community servers differ).
-- Better DT asked for 17 (Static, the default), 14 / 12 or the slider's 5-17 whatever that limit was, and a server that gets
-- more user commands than it allows drops them: rubber banding, no movement. `dt_limit_value` is that limit; the server sending
-- its value again (a new connect) is noticed because the cvar no longer holds what we wrote
local dt_ticks_set, dt_limit_value = nil, nil
local function dt_limit()
    local ok, current = pcall(function() return cvars.sv_maxusrcmdprocessticks:get_int() end)
    current = ok and tonumber(current) or nil
    if (current ~= nil and (dt_ticks_set == nil or current ~= dt_ticks_set)) then
        dt_limit_value, dt_ticks_set = current, nil
    end
    return dt_limit_value
end
-- the ticks to write: the wanted number, but at most the server's limit (nil = leave the cvar alone)
local function dt_ticks_for(wanted, limit)
    if (wanted == nil or limit == nil or limit < 1) then return nil end
    return math.min(wanted, limit)
end
local function set_dt_ticks(wanted)
    local ticks = dt_ticks_for(wanted, dt_limit())
    if (ticks ~= nil and ticks ~= dt_ticks_set) then
        cvars.sv_maxusrcmdprocessticks:set_int(ticks)
        dt_ticks_set = ticks
    end
end
-- Switch: 17 close, 14 far; Automatic: 17 / 14 / 12 by the distance of the nearest enemy
local function dt_wanted(calc, dist)
    if (calc == 2) then
        return dist < 600 and 17 or 14
    end
    return dist < 600 and 17 or dist < 1000 and 14 or 12
end

custom_dt = function()
    if (not ui.exploits.better_dt.better_dt:get()) then
        set_dt_ticks(15)
        return
    end
    if (not menu_find("aimbot", "general", "exploits", "doubletap", "enable")[2]:get()) then
        return
    end
    if (ui.exploits.better_dt.dt_mode:get() ~= 1) then
        set_dt_ticks(ui.exploits.better_dt.dt_speed:get())
        return
    end
    local enemies = entity_list_get_players(true)
    if (enemies == nil or next(enemies) == nil) then
        return
    end
    local calc = ui.exploits.better_dt.speed_calc:get()
    if (calc == 1) then
        set_dt_ticks(17)
        return
    end
    -- it measured the distance to the map's origin (0, 0), not to an enemy: the value jumped around as we moved
    local me = entity_list_get_local_player():get_render_origin()
    local dist = math.huge
    for _, enemy in pairs(enemies) do
        if (enemy:is_alive() and not enemy:is_dormant()) then
            local o = enemy:get_render_origin()
            dist = math.min(dist, math.sqrt((o.x - me.x) ^ 2 + (o.y - me.y) ^ 2))
        end
    end
    if (dist ~= math.huge) then
        set_dt_ticks(dt_wanted(calc, dist))
    end
end

--- @endregion

--- @info: edge-yaw antiaim
--- @region: edgeyaw

edgeyaw.fix_yaw = function(yaw)
    while (yaw > 180) do
        yaw = yaw - 360
    end
    
    while (yaw < -180) do
        yaw = yaw + 360
    end
    return yaw
end

edgeyaw.multiply_vector = function(vec, mul)
    return vec3_t(vec.x * mul, vec.y * mul, vec.z * mul)
end

edgeyaw.lerp_vector = function(source, destination, percentage)
    return source + edgeyaw.multiply_vector((destination - source), percentage)
end

edgeyaw.angle_to_vector = function(angle)
    return vec3_t(math.cos(angle.y) * math.cos(angle.x), math.sin(angle.y) * math.cos(angle.x), math.sin(angle.x))
end

edgeyaw.vector_to_angle = function(vec)
    return angle_t(math.atan2(vec.y, vec.x), math.asin(vec.z), 0)
end

edgeyaw.normalize_yaw = function(yaw)
    local result = yaw
    while (result < -180) do
        result = result + 360
    end

    while (result > 180) do
        result = result - 360
    end
    return result
end

run_edgeyaw = function(ctx, cmd, unpredicted)
    if (ui.antiaim.builder.edge_yaw:get() and ui.edge_yaw:get()) then
        local local_player = entity_list_get_local_player()
        local can_hit = false

        local enemies = entity_list_get_players(true)
        if (enemies ~= nil) then
            for _, enemy in pairs(enemies) do
                if (enemy and enemy:is_player()) then
                    local trace = trace_bullet(local_player:get_hitbox_pos(e_hitboxes.HEAD), enemy:get_eye_position(), enemy, local_player)
                    if (trace.valid and trace.damage > 20) then
                        can_hit = true
                        break
                    end
                end
            end

            if (edgeyaw.enabled and not can_hit) then
                local angle = edgeyaw.vector_to_angle(edgeyaw.pos - local_player:get_eye_position())

                local raw_in_degrees = math.deg(angle.x)
                local new_yaw = raw_in_degrees

                local view_angle_yaw = cmd.viewangles.y

                local difference = math.abs(edgeyaw.normalize_yaw(raw_in_degrees - view_angle_yaw))
                local angle_difference = edgeyaw.fix_yaw(raw_in_degrees - view_angle_yaw)

                new_yaw = edgeyaw.fix_yaw(raw_in_degrees + angle_difference)

                if (difference > 90) then
                    new_yaw = edgeyaw.fix_yaw(raw_in_degrees)
                else
                    local start_left = local_player:get_render_origin() + vec3_t(0, 0, 20) + edgeyaw.multiply_vector(edgeyaw.angle_to_vector(angle_t(0, math.rad(edgeyaw.normalize_yaw(view_angle_yaw + 90)), 0)), 10)
                    local end_left = start_left + edgeyaw.multiply_vector(edgeyaw.angle_to_vector(angle_t(0, math.rad(edgeyaw.normalize_yaw(view_angle_yaw)), 0)), 40)
                    
                    local start_right = local_player:get_render_origin() + vec3_t(0, 0, 20) + edgeyaw.multiply_vector(edgeyaw.angle_to_vector(angle_t(0, math.rad(edgeyaw.normalize_yaw(view_angle_yaw - 90)), 0)), 10)
                    local end_left = start_right + edgeyaw.multiply_vector(edgeyaw.angle_to_vector(angle_t(0, math.rad(edgeyaw.normalize_yaw(view_angle_yaw)), 0)), 40)
                    
                    local fraction_left = trace_line(start_left, end_left, local_player, 0x200400B).fraction
                    local fraction_right = trace_line(start_right, end_left, local_player, 0x200400B).fraction

                    if (fraction_left < 0.9 and fraction_right >= 0.95) then
                        new_yaw = edgeyaw.fix_yaw(new_yaw + 35)
                    elseif (fraction_right < 0.9 and fraction_left >= 0.95) then
                        new_yaw = edgeyaw.fix_yaw(new_yaw - 35)
                    end
                end

                ctx:set_yaw(new_yaw)
                return
            else
                return
            end
        else
            return
        end
    else
        return
    end
end

edge_yaw = function()
    if (ui.antiaim.builder.edge_yaw:get() and ui.edge_yaw:get()) then
        local local_player = entity_list_get_local_player()
        local viewangles = engine_get_view_angles()

        local trace_end = {}

        edgeyaw.enabled = false
        edgeyaw.vec_trace_start = local_player:get_eye_position()

        if (engine_get_choked_commands() == 0) then
            edgeyaw.vec_trace_start = local_player:get_eye_position()
        end

        for yaw_iteration = 20, 360, 20 do
            yaw_iteration = edgeyaw.fix_yaw(yaw_iteration)

            local yaw_iteration_rad = math.rad(yaw_iteration)
            local edge_angle = angle_t(0, yaw_iteration_rad, 0)

            local forwarded_angle = edgeyaw.angle_to_vector(edge_angle)
            local vec_trace_end = edgeyaw.vec_trace_start + edgeyaw.multiply_vector(forwarded_angle, 40)

            local trace_info = trace_line(edgeyaw.vec_trace_start, vec_trace_end, local_player, 0x200400B)

            local fraction = trace_info.fraction
            local entity_hit = trace_info.entity

            if (entity_hit and entity_hit:get_class_name() == "CWorld" and fraction < 0.9) then
                trace_end[#trace_end + 1] = {
                    vec_trace_end = vec_trace_end,
                    yaw_deg = yaw_iteration
                }
            end
        end

        table.sort(trace_end,
            function(a, b)
                return a.yaw_deg < b.yaw_deg
            end
        )

        local edge_angle
        if (#trace_end > 2) then
            local middle_pos = edgeyaw.lerp_vector(trace_end[1].vec_trace_end, trace_end[#trace_end].vec_trace_end, 0.5)
            edge_angle = edgeyaw.vector_to_angle(middle_pos - edgeyaw.vec_trace_start)

            edgeyaw.enabled = true

            edgeyaw.pos = middle_pos
            edgeyaw.angle = edge_angle
        else
            return
        end
        return
    else
        return
    end
end

--- @endregion

--- @info: hit and miss indicator
--- @region: log indicator

handle_dragging = function()
    if (ui.utils.event_logs:get(1)) then
        if (indicator.data) then
            if (indicator.dragging or (input_is_key_held(e_keys.MOUSE_LEFT) and input_is_mouse_in_bounds(indicator.pos, indicator.size))) then
                indicator.pos = input_get_mouse_pos() - indicator.difference
                indicator.dragging = true
            else
                indicator.difference = input_get_mouse_pos() - indicator.pos
            end

            if (not input_is_key_held(e_keys.MOUSE_LEFT)) then
                indicator.dragging = false
            else
                return
            end
            return
        else
            return
        end
    else
        return
    end
end

handle_drawing = function()
    if (ui.utils.event_logs:get(1)) then
        local different_names = 0

        local y_start = indicator.size.y / 2
        local height = different_names * 15

        y_start = y_start - (height / 2)

        local text_start = indicator.pos + vec2_t(80, y_start)
        for name, value in pairs(indicator.data) do
            local color = colors[name] or color_t(0, 0, 0, 255)

            render_rect_filled(text_start + vec2_t(0, 2), vec2_t(10, 10), color, 2)
            render_text(indicator.font, string.format("(%.0f%%) %s", value / indicator.shot_count * 100, name), text_start + vec2_t(15, 0), color_t(255, 255, 255, 255))
            
            text_start = text_start + vec2_t(0, 15)
        end
        return
    else
        return
    end
end

--- @endregion

--- @info: menu effect, watermark, keybinds spectator, crosshair indicator, gs indicator, china hat
--- @region: visuals

lerp = function(time, a, b)
    return a * (1 - time) + b * time
end

draw_menu = function()
    local frametime = math.floor(globals.frame_time() * 150)

    animation.alpha = lerp(0.1 + math.min(frametime / 10.1, 0.3), animation.alpha, menu_is_open() and 255 or 0)
    animation.appearing = lerp(0.06 + math.min(frametime / 10.1, 0.25), animation.appearing, menu_is_open() and 0 or 100)
    
    if (animation.alpha < 2) then
        return
    end

    render_rect_fade(vec2_t(menu_get_pos().x - math.floor(animation.appearing), menu_get_pos().y - 21 - math.floor(animation.appearing)), vec2_t(200 + math.floor(animation.appearing * 5), 15), color_t(29, 29, 29, math.floor(animation.alpha)), color_t(29, 29, 29, 0), true)
    render_rect_filled(vec2_t(menu_get_pos().x + 2 - math.floor(animation.appearing), menu_get_pos().y - 19 - math.floor(animation.appearing)), vec2_t(2 + math.floor(animation.appearing * 2), 11), color_t(ui.accent_color:get().r, ui.accent_color:get().g, ui.accent_color:get().b, math.floor(animation.alpha)))
    
    local base_x = render_get_text_size(pixel_font, "specter0").x + menu_get_pos().x - 23 - -math.floor(animation.appearing)
    local base_y = menu_get_pos().y - 19 - math.floor(animation.appearing)

    local x_offset = base_x + render_get_text_size(pixel_font, "Specter" .. info.beta_text .. " ").x

    render_text(pixel_font, "Specter" .. info.beta_text .. " ", vec2_t(base_x, base_y), color_t(255, 255, 255, math.floor(animation.alpha)))
    render_text(pixel_font, "|", vec2_t(x_offset, base_y), color_t(ui.text_color:get().r, ui.text_color:get().g, ui.text_color:get().b, math.floor(animation.alpha)))

    x_offset = x_offset + render_get_text_size(pixel_font, "| ").x
    render_text(pixel_font, "user: " .. info.user .. " ", vec2_t(x_offset, base_y), color_t(255, 255, 255, math.floor(animation.alpha)))

    x_offset = x_offset + render_get_text_size(pixel_font, "user: " .. info.user .. " ").x
    render_text(pixel_font, "|", vec2_t(x_offset, base_y), color_t(ui.text_color:get().r, ui.text_color:get().g, ui.text_color:get().b, math.floor(animation.alpha)))

    x_offset = x_offset + render_get_text_size(pixel_font, "| ").x
    render_text(pixel_font, "uid: " .. info.uid, vec2_t(x_offset, base_y), color_t(255, 255, 255, math.floor(animation.alpha)))
end

-- watermark, hotkeys and spectators: the look of Specter's gamesense lua (dark rounded panels, the moon / sun, a
-- shimmering "specter", coloured fps / ping, one pill per bind), drawn with Primordial's render calls
local hud = { fps = 0, wm_w = 0, day = nil, placed = false, kb_rows = {}, kb_seq = 0, kb_h = 0, kb_w = 0, kb_a = 0,
              sp_h = 0, sp_w = 0, sp_a = 0,
              bold = render_create_font("Verdana", math.ceil(12 * dpi_scale), 700, e_font_flags.ANTIALIAS),
              font = render_create_font("Verdana", math.ceil(12 * dpi_scale), 400, e_font_flags.ANTIALIAS),
              BG = { 12, 12, 16 }, PILL = { 16, 16, 22 }, W = { 230, 230, 236 }, DIM = { 150, 150, 160 } }

hud.lerp = function(a, b, t)
    return a + (b - a) * math.min(1, t)
end

hud.col = function(r, g, b, a)
    return color_t(math.floor(r), math.floor(g), math.floor(b), math.floor(math.max(0, math.min(255, a))))
end

hud.box = function(x, y, w, h, rad, r, g, b, a)
    render_rect_filled(vec2_t(x, y), vec2_t(w, h), hud.col(r, g, b, a), rad)
end

hud.outline = function(x, y, w, h, rad, r, g, b, a)
    render_rect(vec2_t(x, y), vec2_t(w, h), hud.col(r, g, b, a), rad)
end

-- the dark panel with a faint border, the glow of "Glow effects" and the style's own touches
hud.panel = function(x, y, w, h, a, style, accent)
    local rad = math.floor(h / 2)
    if (ui.utils.menu_glow:get()) then
        local pulse = 0.7 + 0.3 * math.sin(globals.real_time() * 2)
        for i = 1, 3 do
            hud.box(x - i * 2, y - i * 2, w + i * 4, h + i * 4, rad + i * 2, accent.r, accent.g, accent.b, (4 - i) * 5 * pulse * a)
        end
    end
    if (style == 3) then -- glass
        hud.box(x, y, w, h, 5, 18, 18, 26, 160 * a)
        render_rect_fade(vec2_t(x, y), vec2_t(math.floor(w * 0.45), h), hud.col(accent.r, accent.g, accent.b, 45 * a),
            hud.col(accent.r, accent.g, accent.b, 0), true)
        hud.box(x, y + 5, 2, h - 10, 0, accent.r, accent.g, accent.b, 255 * a)
        return
    elseif (style == 4) then -- neon
        hud.box(x - 1, y - 1, w + 2, h + 2, rad + 1, accent.r, accent.g, accent.b, 210 * a)
        hud.box(x, y, w, h, rad, 8, 8, 12, 245 * a)
        return
    end
    hud.outline(x - 1, y - 1, w + 2, h + 2, rad + 1, 255, 255, 255, 16 * a)
    hud.box(x, y, w, h, rad, hud.BG[1], hud.BG[2], hud.BG[3], 238 * a)
end

-- an accent line fading out to both ends
hud.underline = function(x, y, w, accent, a)
    local half = math.floor(w / 2)
    if (half <= 0) then
        return
    end
    local k = 0.55 + 0.45 * math.sin(globals.real_time() * 1.8)
    render_rect_fade(vec2_t(x, y), vec2_t(half, 1), hud.col(accent.r, accent.g, accent.b, 0),
        hud.col(accent.r, accent.g, accent.b, 230 * k * a), true)
    render_rect_fade(vec2_t(x + half, y), vec2_t(w - half, 1), hud.col(accent.r, accent.g, accent.b, 230 * k * a),
        hud.col(accent.r, accent.g, accent.b, 0), true)
end

-- the moon at night, a turning sun by day (local time 7:00 - 19:00)
hud.sky = function(cx, cy, accent, a)
    local night = 1 - hud.day
    if (night > 0.02) then
        render_circle_filled(vec2_t(cx, cy), 4.5 * night, hud.col(accent.r, accent.g, accent.b, a))
        render_circle_filled(vec2_t(cx + 2.2 * night, cy - 1.6 * night), 3.8 * night, hud.col(hud.BG[1], hud.BG[2], hud.BG[3], a))
    end
    if (hud.day > 0.02) then
        render_circle_filled(vec2_t(cx, cy), 3.2 * hud.day, hud.col(255, 222, 140, a))
        local spin = globals.real_time() * 0.5
        for k = 0, 7 do
            local ang = spin + k * math.pi / 4
            local ca, sa = math.cos(ang), math.sin(ang)
            render_line(vec2_t(cx + ca * 4.8 * hud.day, cy + sa * 4.8 * hud.day), vec2_t(cx + ca * 6.6 * hud.day, cy + sa * 6.6 * hud.day),
                hud.col(255, 222, 140, a))
        end
    end
end

-- "specter" with a wave of the accent colour running through its letters
hud.brand = function(x, y, accent, a)
    local now = globals.real_time()
    local text = "specter"
    for i = 1, #text do
        local ch = text:sub(i, i)
        local t = 0.5 + 0.5 * math.sin(now * 1.6 - i * 0.55)
        render_text(hud.bold, ch, vec2_t(x, y), hud.col(245 + (accent.r - 245) * t, 245 + (accent.g - 245) * t, 250 + (accent.b - 250) * t, a))
        x = x + render_get_text_size(hud.bold, ch).x
    end
end

-- the small grey glyph in front of a watermark segment
hud.seg_icon = function(kind, cx, cy, a)
    local c = hud.col(150, 150, 160, a)
    if (kind == "user") then
        render_circle_filled(vec2_t(cx, cy - 2.5), 2.6, c)
        render_rect_filled(vec2_t(cx - 4, cy + 1), vec2_t(8, 4), c, 2)
    elseif (kind == "fps") then
        render_rect_filled(vec2_t(cx - 4, cy + 1), vec2_t(2, 3), c)
        render_rect_filled(vec2_t(cx - 1, cy - 1), vec2_t(2, 5), c)
        render_rect_filled(vec2_t(cx + 2, cy - 3), vec2_t(2, 7), c)
    elseif (kind == "ping") then
        render_circle(vec2_t(cx, cy), 4.5, c)
        render_circle_filled(vec2_t(cx, cy), 1.5, c)
    elseif (kind == "tick") then
        render_rect_filled(vec2_t(cx - 4, cy), vec2_t(8, 1), c)
        render_rect_filled(vec2_t(cx, cy - 4), vec2_t(1, 8), c)
    else
        render_circle(vec2_t(cx, cy), 4.5, c)
        render_rect_filled(vec2_t(cx, cy - 3), vec2_t(1, 3), c)
        render_rect_filled(vec2_t(cx, cy), vec2_t(2, 1), c)
    end
end

draw_watermark = function()
    local ft = globals.frame_time()
    if (ft > 0) then
        hud.fps = hud.fps == 0 and 1 / ft or hud.lerp(hud.fps, 1 / ft, ft * 2)
    end
    local h, m = client_get_local_time()
    local day = (h >= 7 and h < 19) and 1 or 0
    hud.day = hud.day and hud.lerp(hud.day, day, ft * 3) or day

    local accent = ui.accent_color:get()
    local style = ui.utils.watermark_style:get()
    local icons = ui.utils.watermark_fields:get(6)
    local W = hud.W

    local segs = {}
    if (ui.utils.watermark_fields:get(1)) then
        segs[#segs + 1] = { "user", info.user, "", W[1], W[2], W[3] }
    end
    if (ui.utils.watermark_fields:get(2)) then
        local fps = math.floor(hud.fps + 0.5)
        local r, g, b = W[1], W[2], W[3]
        if (fps < 60) then r, g, b = 255, 118, 118 elseif (fps < 120) then r, g, b = 255, 210, 125 end
        segs[#segs + 1] = { "fps", tostring(fps), " fps", r, g, b }
    end
    if (ui.utils.watermark_fields:get(3)) then
        local ping = math.floor(get_user_ping() + 0.5)
        local r, g, b = W[1], W[2], W[3]
        if (ping > 110) then r, g, b = 255, 118, 118 elseif (ping > 60) then r, g, b = 255, 210, 125 end
        segs[#segs + 1] = { "ping", tostring(ping), " ms", r, g, b }
    end
    if (ui.utils.watermark_fields:get(4)) then
        segs[#segs + 1] = { "tick", tostring(math.floor(client_get_tickrate() + 0.5)), " tick", W[1], W[2], W[3] }
    end
    if (ui.utils.watermark_fields:get(5)) then
        segs[#segs + 1] = { "time", string.format("%02d:%02d", h, m), "", W[1], W[2], W[3] }
    end

    local brand_size = render_get_text_size(hud.bold, "specter")
    local th = brand_size.y
    local H = th + 12
    local PADX, GAP = 12, 11
    local brand_w = PADX + 20 + brand_size.x + PADX

    local info_w = 0
    for _, sg in ipairs(segs) do
        sg.vw = render_get_text_size(hud.font, sg[2]).x
        sg.uw = sg[3] ~= "" and render_get_text_size(hud.font, sg[3]).x or 0
        sg.w = (icons and 14 or 0) + sg.vw + sg.uw
        info_w = info_w + sg.w
    end
    if (#segs > 0) then
        info_w = info_w + GAP * 2 * (#segs - 1) + PADX * 2
    end

    local split = style == 2 and #segs > 0
    local width = split and (brand_w + 6 + info_w) or (brand_w + (#segs > 0 and (info_w - PADX * 2 + GAP * 2) or 0))
    hud.wm_w = hud.wm_w == 0 and width or hud.lerp(hud.wm_w, width, ft * 12)
    local w = math.floor(hud.wm_w + 0.5)

    -- top right until it is dragged (M2 centers it, like the other panels)
    if (not hud.placed) then
        drag_watermark.pos = vec2_t(screen_size.x - w - 16, 16)
        hud.placed = true
    end
    drag_watermark.size = vec2_t(w, H)
    drag_watermark:update()
    local x, y = math.floor(drag_watermark.pos.x + 0.5), math.floor(drag_watermark.pos.y + 0.5)
    local cy = y + math.floor(H / 2)
    local ty = y + math.floor((H - th) / 2)

    if (split) then
        hud.panel(x, y, brand_w, H, 1, style, accent)
        hud.underline(x + 8, y + H - 1, brand_w - 16, accent, 1)
        hud.panel(x + brand_w + 6, y, math.max(0, w - brand_w - 6), H, 1, style, accent)
    else
        hud.panel(x, y, w, H, 1, style, accent)
        if (style ~= 4) then
            hud.underline(x + 10, y + H - 1, w - 20, accent, 1)
        end
    end

    hud.sky(x + PADX + 6, cy, accent, 255)
    hud.brand(x + PADX + 20, ty, accent, 255)

    local tx = split and (x + brand_w + 6 + PADX) or (x + brand_w - PADX + GAP * 2)
    for i, sg in ipairs(segs) do
        if (tx + sg.w > x + w - 6) then
            break
        end
        local sep = (i > 1 or not split) and (tx - GAP) or nil
        if (sep) then
            render_rect_filled(vec2_t(sep, y + 6), vec2_t(1, H - 12), hud.col(255, 255, 255, 20))
        end
        local vx = tx
        if (icons) then
            hud.seg_icon(sg[1], tx + 5, cy, 255)
            vx = tx + 14
        end
        render_text(hud.font, sg[2], vec2_t(vx, ty), hud.col(sg[4], sg[5], sg[6], 255))
        if (sg.uw > 0) then
            render_text(hud.font, sg[3], vec2_t(vx + sg.vw, ty), hud.col(hud.DIM[1], hud.DIM[2], hud.DIM[3], 255))
        end
        tx = tx + sg.w + GAP * 2
    end
end

-- a small glyph per bind (Keybinds style "Pills icons"), lines / circles / rectangles only
hud.bind_icon = function(name, cx, cy, c)
    if (name == "double tap") then -- bolt
        render_line(vec2_t(cx + 2, cy - 6), vec2_t(cx - 3, cy + 1), c)
        render_line(vec2_t(cx - 3, cy + 1), vec2_t(cx + 3, cy - 1), c)
        render_line(vec2_t(cx + 3, cy - 1), vec2_t(cx - 2, cy + 6), c)
    elseif (name == "hide shots") then -- slashed eye
        render_circle(vec2_t(cx, cy), 5, c)
        render_circle_filled(vec2_t(cx, cy), 1.8, c)
        render_line(vec2_t(cx - 5, cy + 5), vec2_t(cx + 5, cy - 5), c)
    elseif (name == "min. damage" or name == "dormant aimbot" or name == "hitchance override") then -- crosshair
        render_circle(vec2_t(cx, cy), 5, c)
        render_rect_filled(vec2_t(cx - 8, cy), vec2_t(3, 1), c)
        render_rect_filled(vec2_t(cx + 6, cy), vec2_t(3, 1), c)
        render_rect_filled(vec2_t(cx, cy - 8), vec2_t(1, 3), c)
        render_rect_filled(vec2_t(cx, cy + 6), vec2_t(1, 3), c)
    elseif (name == "auto direction" or name == "lock angle") then -- shield
        render_line(vec2_t(cx - 5, cy - 6), vec2_t(cx + 5, cy - 6), c)
        render_line(vec2_t(cx + 5, cy - 6), vec2_t(cx + 5, cy + 1), c)
        render_line(vec2_t(cx + 5, cy + 1), vec2_t(cx, cy + 7), c)
        render_line(vec2_t(cx, cy + 7), vec2_t(cx - 5, cy + 1), c)
        render_line(vec2_t(cx - 5, cy + 1), vec2_t(cx - 5, cy - 6), c)
    elseif (name == "quick peek") then -- arrow back
        render_rect_filled(vec2_t(cx - 6, cy), vec2_t(12, 1), c)
        render_line(vec2_t(cx - 2, cy - 4), vec2_t(cx - 6, cy), c)
        render_line(vec2_t(cx - 6, cy), vec2_t(cx - 2, cy + 4), c)
    elseif (name == "fake duck" or name == "sneak") then -- arrow down to a line
        render_rect_filled(vec2_t(cx, cy - 6), vec2_t(1, 9), c)
        render_line(vec2_t(cx - 4, cy - 1), vec2_t(cx, cy + 3), c)
        render_line(vec2_t(cx, cy + 3), vec2_t(cx + 4, cy - 1), c)
        render_rect_filled(vec2_t(cx - 5, cy + 6), vec2_t(11, 1), c)
    elseif (name == "safepoint" or name == "lean safepoint" or name == "lethal shot") then -- ring + dot
        render_circle(vec2_t(cx, cy), 6, c)
        render_circle_filled(vec2_t(cx, cy), 3, c)
    elseif (name == "ping spike") then -- signal bars
        for k = 0, 3 do
            render_rect_filled(vec2_t(cx - 6 + k * 3, cy + 5 - (k + 1) * 3), vec2_t(2, (k + 1) * 3), c)
        end
    elseif (name == "slow walk") then -- double chevron
        render_line(vec2_t(cx - 5, cy - 4), vec2_t(cx - 1, cy), c)
        render_line(vec2_t(cx - 1, cy), vec2_t(cx - 5, cy + 4), c)
        render_line(vec2_t(cx, cy - 4), vec2_t(cx + 4, cy), c)
        render_line(vec2_t(cx + 4, cy), vec2_t(cx, cy + 4), c)
    elseif (name == "inverter" or name == "lean inverter") then -- two arrows
        render_line(vec2_t(cx - 6, cy - 2), vec2_t(cx + 6, cy - 2), c)
        render_line(vec2_t(cx + 6, cy - 2), vec2_t(cx + 3, cy - 5), c)
        render_line(vec2_t(cx + 6, cy + 2), vec2_t(cx - 6, cy + 2), c)
        render_line(vec2_t(cx - 6, cy + 2), vec2_t(cx - 3, cy + 5), c)
    else
        render_circle_filled(vec2_t(cx, cy), 2.5, c)
    end
end

-- a pill switch, filled = on
hud.switch = function(x, y, filled, accent, a)
    if (filled) then
        hud.box(x, y, 18, 10, 5, accent.r, accent.g, accent.b, 230 * a)
        render_circle_filled(vec2_t(x + 13, y + 5), 3.2, hud.col(255, 255, 255, 255 * a))
    else
        hud.outline(x, y, 18, 10, 5, 255, 255, 255, 230 * a)
        render_circle_filled(vec2_t(x + 13, y + 5), 3, hud.col(255, 255, 255, 230 * a))
    end
end

-- a little keyboard for the header
hud.keyboard = function(cx, cy, c)
    render_rect(vec2_t(cx - 8, cy - 5), vec2_t(16, 10), c, 2)
    for k = 0, 3 do
        render_rect_filled(vec2_t(cx - 6 + k * 3, cy - 3), vec2_t(2, 2), c)
    end
    render_rect_filled(vec2_t(cx - 4, cy + 1), vec2_t(8, 2), c)
end

-- the header pill of a list (also what is dragged)
hud.header = function(x, y, w, a, title, accent, accent_box, draw_icon)
    hud.box(x, y, w, 28, 7, hud.PILL[1], hud.PILL[2], hud.PILL[3], 215 * a)
    hud.outline(x, y, w, 28, 7, 255, 255, 255, 22 * a)
    if (accent_box) then
        hud.box(x + 3, y + 3, 30, 22, 5, accent.r, accent.g, accent.b, 55 * a)
        draw_icon(x + 18, y + 14, hud.col(accent.r, accent.g, accent.b, 255 * a))
    else
        hud.box(x + 3, y + 3, 30, 22, 5, 255, 255, 255, 14 * a)
        draw_icon(x + 18, y + 14, hud.col(200, 200, 210, 255 * a))
    end
    render_text(hud.bold, title, vec2_t(x + math.floor(w / 2) + 14, y + 14), hud.col(hud.W[1], hud.W[2], hud.W[3], 255 * a), true)
end

-- every active bind as a pill: icon / dot, the name, the mode or a switch on the right; rows slide in and fade out
draw_keybinds = function()
    local ft = globals.frame_time()
    local menu_open = menu_is_open()
    local accent = ui.accent_color:get()
    local icons = ui.utils.keybinds_style:get() == 1
    local show_mode = ui.utils.keybinds_mode:get()

    local seen = {}
    for name, item in pairs(keybinds.unsorted) do
        local mode = item:get_mode()
        if (mode ~= 3 and mode ~= 4 and item:get()) then
            seen[name] = true
            local row = hud.kb_rows[name]
            if (row == nil) then
                hud.kb_seq = hud.kb_seq + 1
                row = { a = 0, order = hud.kb_seq }
                hud.kb_rows[name] = row
            end
            row.mode = keybinds.mode[mode]
        end
    end

    local list = {}
    for name, row in pairs(hud.kb_rows) do
        row.live = seen[name] == true
        row.a = hud.lerp(row.a, row.live and 1 or 0, ft * (row.live and 12 or 9))
        if (not row.live and row.a < 0.02) then
            hud.kb_rows[name] = nil
        else
            row.name = name
            list[#list + 1] = row
        end
    end
    table.sort(list, function(p, q) return p.order < q.order end)

    hud.kb_a = hud.lerp(hud.kb_a, (#list > 0 or menu_open) and 1 or 0, ft * 8)
    if (hud.kb_a < 0.01) then
        hud.kb_a = 0
        return
    end
    local a = hud.kb_a

    local HEAD, RH, GAP = 28, 26, 5
    local name_x = icons and 28 or 22
    local need = 180
    for _, row in ipairs(list) do
        row.label = row.name:gsub("^%l", string.upper)
        row.show_mode = show_mode and row.mode ~= "toggle" and row.mode or nil
        local right = row.show_mode and render_get_text_size(hud.font, row.show_mode).x or 18
        need = math.max(need, name_x + render_get_text_size(hud.bold, row.label).x + 18 + right + 12)
    end
    hud.kb_w = hud.kb_w == 0 and need or hud.lerp(hud.kb_w, need, ft * 12)
    local body = 0
    for _, row in ipairs(list) do
        body = body + (RH + GAP) * row.a
    end
    local total = HEAD + ((#list == 0 and menu_open) and 26 or body)
    hud.kb_h = hud.kb_h == 0 and total or hud.lerp(hud.kb_h, total, ft * 14)
    local w = math.floor(hud.kb_w + 0.5)

    drag_keybinds.size = vec2_t(w, math.floor(hud.kb_h + 0.5))
    drag_keybinds:update()
    local x, y = math.floor(drag_keybinds.pos.x + 0.5), math.floor(drag_keybinds.pos.y + 0.5)

    hud.header(x, y, w, a, "Hotkeys", accent, icons, hud.keyboard)

    local ry = y + HEAD + GAP
    for _, row in ipairs(list) do
        local ra = row.a * a
        local px = x + math.floor((1 - row.a) * 26)
        local cyr = ry + math.floor(RH / 2)
        hud.box(px, ry, w, RH, 7, hud.PILL[1], hud.PILL[2], hud.PILL[3], 200 * ra)
        hud.outline(px, ry, w, RH, 7, 255, 255, 255, 20 * ra)
        if (icons) then
            hud.bind_icon(row.name, px + 15, cyr, hud.col(accent.r, accent.g, accent.b, 255 * ra))
        else
            render_circle_filled(vec2_t(px + 12, cyr), 2.2, hud.col(255, 255, 255, 255 * ra))
        end
        local nth = render_get_text_size(hud.bold, row.label).y
        render_text(hud.bold, row.label, vec2_t(px + name_x, cyr - math.floor(nth / 2)), hud.col(hud.W[1], hud.W[2], hud.W[3], 255 * ra))
        if (row.show_mode) then
            local ms = render_get_text_size(hud.font, row.show_mode)
            render_text(hud.font, row.show_mode, vec2_t(px + w - 12 - ms.x, cyr - math.floor(ms.y / 2)),
                hud.col(hud.DIM[1], hud.DIM[2], hud.DIM[3], 255 * ra))
        else
            hud.switch(px + w - 28, cyr - 5, icons, accent, ra)
        end
        ry = ry + (RH + GAP) * row.a
    end

    if (#list == 0 and menu_open) then
        render_text(hud.font, "no active binds", vec2_t(x + math.floor(w / 2), y + HEAD + 14), hud.col(130, 130, 140, 200 * a), true)
    end
end

-- an eye for the spectators header
hud.eye = function(cx, cy, c)
    render_circle(vec2_t(cx, cy), 5, c)
    render_circle_filled(vec2_t(cx, cy), 2, c)
end

-- the spectators in the same pills, with their steam avatar
draw_spectators = function()
    local ft = globals.frame_time()
    local menu_open = menu_is_open()
    local accent = ui.accent_color:get()
    local list = libs.etr.get_spectators() or {}

    hud.sp_a = hud.lerp(hud.sp_a, (#list > 0 or menu_open) and 1 or 0, ft * 8)
    if (hud.sp_a < 0.01) then
        hud.sp_a = 0
        return
    end
    local a = hud.sp_a

    local HEAD, RH, GAP = 28, 26, 5
    local need, body = 180, 0
    for _, spec in ipairs(list) do
        spec.label = tostring(spec.name or "?")
        need = math.max(need, 30 + render_get_text_size(hud.bold, spec.label).x + 14)
        body = body + (RH + GAP) * (spec.alpha or 1)
    end
    hud.sp_w = hud.sp_w == 0 and need or hud.lerp(hud.sp_w, need, ft * 12)
    local total = HEAD + ((#list == 0 and menu_open) and 26 or body)
    hud.sp_h = hud.sp_h == 0 and total or hud.lerp(hud.sp_h, total, ft * 14)
    local w = math.floor(hud.sp_w + 0.5)

    drag_spectators.size = vec2_t(w, math.floor(hud.sp_h + 0.5))
    drag_spectators:update()
    local x, y = math.floor(drag_spectators.pos.x + 0.5), math.floor(drag_spectators.pos.y + 0.5)

    hud.header(x, y, w, a, "Spectators", accent, true, hud.eye)

    local ry = y + HEAD + GAP
    for _, spec in ipairs(list) do
        local ra = (spec.alpha or 1) * a
        local cyr = ry + math.floor(RH / 2)
        hud.box(x, ry, w, RH, 7, hud.PILL[1], hud.PILL[2], hud.PILL[3], 200 * ra)
        hud.outline(x, ry, w, RH, 7, 255, 255, 255, 20 * ra)
        local avatar = libs.etr.get_avatar(spec.label, spec.id)
        if (avatar ~= nil) then
            render_push_alpha_modifier(ra)
            render_texture(avatar.id, vec2_t(x + 6, cyr - 8), vec2_t(16, 16))
            render_pop_alpha_modifier()
        else
            render_circle_filled(vec2_t(x + 14, cyr), 2.2, hud.col(accent.r, accent.g, accent.b, 255 * ra))
        end
        local nth = render_get_text_size(hud.bold, spec.label).y
        render_text(hud.bold, spec.label, vec2_t(x + 30, cyr - math.floor(nth / 2)), hud.col(hud.W[1], hud.W[2], hud.W[3], 255 * ra))
        ry = ry + (RH + GAP) * (spec.alpha or 1)
    end

    if (#list == 0 and menu_open) then
        render_text(hud.font, "no spectators", vec2_t(x + math.floor(w / 2), y + HEAD + 14), hud.col(130, 130, 140, 200 * a), true)
    end
end

-- notifications (config loaded / saved, users found ...): the look of the watermark and the hotkeys. A dark rounded card
-- under the watermark, a coloured round icon per kind, the title, the text wrapped, a thin bar that runs out; it slides in
-- from the right and fades out
notifications.COLORS = { success = { 120, 220, 140 }, warn = { 255, 200, 100 }, fail = { 255, 110, 110 } }

notifications.icon = function(kind, cx, cy, r, g, b, a)
    hud.box(cx - 10, cy - 10, 20, 20, 10, r, g, b, 45 * a)
    local c = hud.col(r, g, b, 255 * a)
    if (kind == "success") then
        render_line(vec2_t(cx - 4, cy), vec2_t(cx - 1, cy + 3), c)
        render_line(vec2_t(cx - 1, cy + 3), vec2_t(cx + 5, cy - 3), c)
    elseif (kind == "fail") then
        render_line(vec2_t(cx - 4, cy - 4), vec2_t(cx + 4, cy + 4), c)
        render_line(vec2_t(cx + 4, cy - 4), vec2_t(cx - 4, cy + 4), c)
    elseif (kind == "warn") then
        render_rect_filled(vec2_t(cx - 1, cy - 5), vec2_t(2, 7), c)
        render_rect_filled(vec2_t(cx - 1, cy + 4), vec2_t(2, 2), c)
    else
        render_rect_filled(vec2_t(cx - 1, cy - 5), vec2_t(2, 2), c)
        render_rect_filled(vec2_t(cx - 1, cy - 1), vec2_t(2, 7), c)
    end
end

-- the text in lines that fit `width`
notifications.wrap = function(text, width)
    local out, line = {}, ""
    for word in text:gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if (line ~= "" and render_get_text_size(hud.font, try).x > width) then
            out[#out + 1] = line
            line = word
        else
            line = try
        end
    end
    if (line ~= "") then
        out[#out + 1] = line
    end
    return out
end

notifications.render = function()
    local now, ft = globals.real_time(), globals.frame_time()
    local W, PAD = 270, 12
    local y = 16 + math.floor(render_get_text_size(hud.bold, "specter").y + 12) + 10
    local accent = ui.accent_color:get()

    for i = #notifications.logs, 1, -1 do
        if (now - notifications.logs[i].time > notifications.delay + 0.6) then
            table.remove(notifications.logs, i)
        end
    end

    for _, n in ipairs(notifications.logs) do
        if (n.lines == nil) then
            n.lines = notifications.wrap(n.body, W - 46 - PAD)
            n.h = math.max(44, 30 + #n.lines * 14 + 8)
        end
        local left = notifications.delay - (now - n.time)
        local a = math.max(0, math.min(1, (now - n.time) * 6, (left + 0.6) / 0.6))
        n.y = n.y and hud.lerp(n.y, y, ft * 14) or y
        local x = math.floor(screen_size.x - W - 16 + (1 - math.min(1, (now - n.time) * 6)) * 40 + 0.5)
        local ny = math.floor(n.y + 0.5)
        local c = notifications.COLORS[n.kind] or { accent.r, accent.g, accent.b }

        hud.outline(x - 1, ny - 1, W + 2, n.h + 2, 9, 255, 255, 255, 16 * a)
        hud.box(x, ny, W, n.h, 8, hud.BG[1], hud.BG[2], hud.BG[3], 238 * a)
        notifications.icon(n.kind, x + PAD + 10, ny + 22, c[1], c[2], c[3], a)
        render_text(hud.bold, n.head, vec2_t(x + 46, ny + 10), hud.col(hud.W[1], hud.W[2], hud.W[3], 255 * a))
        for k, line in ipairs(n.lines) do
            render_text(hud.font, line, vec2_t(x + 46, ny + 14 + k * 14), hud.col(hud.DIM[1], hud.DIM[2], hud.DIM[3], 255 * a))
        end

        local part = math.max(0, math.min(1, left / notifications.delay))
        hud.box(x + 8, ny + n.h - 3, W - 16, 2, 1, 255, 255, 255, 12 * a)
        hud.box(x + 8, ny + n.h - 3, math.floor((W - 16) * part), 2, 1, c[1], c[2], c[3], 200 * a)

        y = y + (n.h + 8) * a
    end
end

-- a draggable pill panel: a header and one pill per row { label, right, dot = { r, g, b } }; panel = { drag, w, h } (the
-- size is animated). Used by the AA stats and the resolver stats
hud.pill_panel = function(panel, title, rows, empty_text)
    if (#rows == 0 and not menu_is_open()) then
        return
    end
    local ft = globals.frame_time()
    local accent = ui.accent_color:get()
    local HEAD, RH, GAP = 28, 26, 5
    local need = 220
    for _, row in ipairs(rows) do
        need = math.max(need, 22 + render_get_text_size(hud.bold, row.label).x + 18 + render_get_text_size(hud.font, row.right).x + 12)
    end
    panel.w = panel.w == 0 and need or hud.lerp(panel.w, need, ft * 12)
    local total = HEAD + (#rows == 0 and 26 or #rows * (RH + GAP))
    panel.h = panel.h == 0 and total or hud.lerp(panel.h, total, ft * 14)
    local w = math.floor(panel.w + 0.5)

    panel.drag.size = vec2_t(w, math.floor(panel.h + 0.5))
    panel.drag:update()
    local x, y = math.floor(panel.drag.pos.x + 0.5), math.floor(panel.drag.pos.y + 0.5)

    hud.header(x, y, w, 1, title, accent, true, function(cx, cy, c)
        render_line(vec2_t(cx - 5, cy - 6), vec2_t(cx + 5, cy - 6), c)
        render_line(vec2_t(cx + 5, cy - 6), vec2_t(cx + 5, cy + 1), c)
        render_line(vec2_t(cx + 5, cy + 1), vec2_t(cx, cy + 7), c)
        render_line(vec2_t(cx, cy + 7), vec2_t(cx - 5, cy + 1), c)
        render_line(vec2_t(cx - 5, cy + 1), vec2_t(cx - 5, cy - 6), c)
    end)

    local ry = y + HEAD + GAP
    for _, row in ipairs(rows) do
        local cyr = ry + math.floor(RH / 2)
        hud.box(x, ry, w, RH, 7, hud.PILL[1], hud.PILL[2], hud.PILL[3], 200)
        hud.outline(x, ry, w, RH, 7, 255, 255, 255, 20)
        render_circle_filled(vec2_t(x + 12, cyr), 3, hud.col(row.dot[1], row.dot[2], row.dot[3], 255))
        local th = render_get_text_size(hud.bold, row.label).y
        render_text(hud.bold, row.label, vec2_t(x + 22, cyr - math.floor(th / 2)), hud.col(hud.W[1], hud.W[2], hud.W[3], 255))
        local rs = render_get_text_size(hud.font, row.right)
        render_text(hud.font, row.right, vec2_t(x + w - 12 - rs.x, cyr - math.floor(rs.y / 2)), hud.col(hud.DIM[1], hud.DIM[2], hud.DIM[3], 255))
        ry = ry + RH + GAP
    end
    if (#rows == 0) then
        render_text(hud.font, empty_text, vec2_t(x + math.floor(w / 2), y + HEAD + 14), hud.col(130, 130, 140, 200), true)
    end
end

-- AA stats panel: one pill per state / yaw mode that was shot at, hits and evaded bullets and the hit rate
hud.aa_panel = { drag = libs.etr.new('aa_stats', vec2_t(50, screen_size.y / 2 + 160), vec2_t(0, 0)), w = 0, h = 0 }

draw_aa_stats = function()
    local list = {}
    for _, row in pairs(builder.aa_stats) do
        list[#list + 1] = row
    end
    table.sort(list, function(p, q)
        if (p.n ~= q.n) then
            return p.n < q.n
        end
        return p.label < q.label
    end)
    local rows = {}
    for _, row in ipairs(list) do
        local shots = row.hit + row.evaded
        local rate = shots > 0 and math.floor(row.hit / shots * 100 + 0.5) or 0
        -- the dot: green under 25 % hit, yellow under 50 %, red above
        rows[#rows + 1] = { label = row.label, right = string.format("%d hit · %d evaded · %d%%", row.hit, row.evaded, rate),
            dot = rate >= 50 and { 255, 110, 110 } or rate >= 25 and { 255, 200, 100 } or { 120, 220, 140 } }
    end
    hud.pill_panel(hud.aa_panel, "AA stats", rows, "nobody shot at you yet")
end

-- resolver stats panel (owners: "/state, hogy megnézzük mire missel a legtöbbet"): one pill per state of the target we shot
-- at: shots, hit rate and the two most frequent miss reasons (a shot spoiled by a defensive shift / lag break is
-- shown as "defensive" / "lag break"). The full lines (all reasons, the hypotheses) are in "Resolver stats to console"
hud.res_panel = { drag = libs.etr.new('res_stats', vec2_t(50, screen_size.y / 2 - 80), vec2_t(0, 0)), w = 0, h = 0 }

draw_res_stats = function()
    local rows = {}
    for _, r in ipairs(resolver.stat_rows()) do
        local miss = {}
        for i = 1, math.min(2, #r.miss) do
            miss[#miss + 1] = r.miss[i][1] .. " " .. r.miss[i][2]
        end
        -- the dot: green from 60 % hit, yellow from 40 %, red under
        rows[#rows + 1] = { label = r.name, dot = r.rate >= 60 and { 120, 220, 140 } or r.rate >= 40 and { 255, 200, 100 } or { 255, 110, 110 },
            right = string.format("%d shots · %d%%%s", r.n, r.rate, #miss > 0 and (" · " .. table.concat(miss, ", ")) or "") }
    end
    hud.pill_panel(hud.res_panel, "Resolver stats", rows, "no shots yet")
end

draw_indicator = function()
    local local_player = entity_list_get_local_player()
    local is_scoped = local_player:get_prop("m_bIsScoped") > 0

    binds.movetext = math.floor(animated_sc("offset_ind", is_scoped and 25 or 1, 10))
    binds.movebinds = math.floor(animated_sc("offset_ind_binds", is_scoped and 14 or 1, 10))

    binds.height = 4

    binds.anim = {}
    binds.list = {
        {"dt", refs.double_tap:get() and ui.visuals.crosshair_indc.binds:get(1), (exploits_get_max_charge() < 3 or exploits_get_charge() ~= exploits_get_max_charge()) and color_t(255, 0, 0, 250) or color_t(0, 255, 30, 200)},
        {"hide", refs.hide_shots:get() and ui.visuals.crosshair_indc.binds:get(2), (exploits_get_max_charge() < 3 or exploits_get_charge() ~= exploits_get_max_charge()) and color_t(255, 0, 0, 250) or color_t(255, 255, 255, 200)},
        {"dmg", refs.force_damage:get() and ui.visuals.crosshair_indc.binds:get(3), color_t(255, 255, 255, 200)},
        {"hc", refs.force_hc:get() and ui.visuals.crosshair_indc.binds:get(11), color_t(255, 255, 255, 200)},
        {"hb", refs.force_hb:get() and ui.visuals.crosshair_indc.binds:get(10), color_t(191, 250, 255, 255)},
        {"safe", refs.force_safe:get() and ui.visuals.crosshair_indc.binds:get(9), color_t(191, 250, 255, 255)},
        {"body", refs.force_baim:get() and ui.visuals.crosshair_indc.binds:get(8), color_t(191, 250, 255, 255)},
        {"peek", refs.quick_peek:get() and ui.visuals.crosshair_indc.binds:get(6), color_t(255, 255, 255, 200)},
        {"fs", refs.freestand:get() and ui.visuals.crosshair_indc.binds:get(5), color_t(255, 255, 255, 200)},
        {"fd", antiaim_is_fakeducking() and ui.visuals.crosshair_indc.binds:get(7), color_t(132, 195, 16, 200)},
        {"ping", refs.ping:get() and ui.visuals.crosshair_indc.binds:get(6), color_t(132, 195, 16, 200)}
    }

    for k, v in pairs(binds.list) do
        binds.anim[v[1]] = {}
        binds.anim[v[1]].alpha = animated_sc('binds_alpha_' .. v[1], v[2] and 255 or 0, 15)
        
        if (binds.anim[v[1]].alpha > 1) then
            render_text(pixel, v[1], vec2_t(screen_size.x / 2 + binds.movebinds - (is_scoped and 0 or render_get_text_size(pixel, v[1]).x / 2), screen_size.y / 2 + screen.positions[2][2] + binds.height), color_t(v[3].r, v[3].g, v[3].b, math.floor(binds.anim[v[1]].alpha > 50 and binds.anim[v[1]].alpha / 255 * v[3].a or 0)))
            binds.height = binds.height + math.floor(binds.anim[v[1]].alpha / 255 * 8 + 0.5)
        end
    end

    local dmg_ovr = menu_find("aimbot", get_active_weapon(), "target overrides", "min. damage")[1]
    local dmg_ovr_key = menu_find("aimbot", get_active_weapon(), "target overrides", "min. damage")[2]
    local norm_dmg = menu_find("aimbot", get_active_weapon(), "targeting", "min. damage")

    local value = dmg_ovr_key:get() and dmg_ovr:get() or norm_dmg:get()
    local lerp = math.floor(animated_sc("dmg", value, 15) + 0.5)
    
    local gradient = animated_text(verdana2, "Specter", ui.accent_color:get(), vec2_t(screen_size.x / 2 + binds.movetext + 1, screen_size.y / 2 + screen.positions[2][1]), 1)()
    render_text(fontpixel, tostring(lerp), vec2_t(screen_size.x / 2 + 5, screen_size.y / 2 - 15), color_t(255, 255, 255, 100))
end

draw_gs_indicator = function()
    local pos = vec2_t(0, 0)
    local addpos = vec2_t(0, 40)

    local startpos = vec2_t(screen_size.x * 0.00741666666 + 14, screen_size.y * 0.67777777777 + 5)
    local user_ticks = tonumber(cvars.sv_maxusrcmdprocessticks:get_string())

    default = function(str, color)
        local text_size = render_get_text_size(font, str)
        gradient(17, pos.y - 2, (text_size.x * 2.3) + 30, 33, color_t(0, 0, 0, 50), color_t(0, 0, 0, 0))

        render_text(font, str, pos, color)
        pos = pos - addpos
    end

    circle = function(str, color, percent)
        local text_size = render_get_text_size(font, str)
        gradient(17, pos.y - 2, (text_size.x * 2.3) + 60, 33, color_t(0, 0, 0, 50), color_t(0, 0, 0, 0))

        render_text(font, str, pos, color)
        render_progress_circle(pos + vec2_t(text_size.x * 1.5, text_size.y / 1.9), 5, color_t(0, 0, 0, 155), 3, 1)
        render_progress_circle(pos + vec2_t(text_size.x * 1.5, text_size.y / 1.9), 5, color, 3, percent)
    
        pos = pos - addpos
    end            

    pos = startpos
    if (ui.visuals.gs_indc.indicators:get(6) and refs.ping:get()) then
        default("PING", color_t(255, 87, 51, 255))
    end

    if (ui.visuals.gs_indc.indicators:get(4) and refs.quick_peek:get()) then
        default("PEEK", get_indc_color())
    end

    if (ui.visuals.gs_indc.indicators:get(9) and refs.force_hb:get()) then
        default("HB", color_t(ui.gs_color2:get().r, ui.gs_color2:get().g, ui.gs_color2:get().b))
    end
    
    if (ui.visuals.gs_indc.indicators:get(10) and refs.force_hc:get()) then
        default("HC", color_t(ui.gs_color2:get().r, ui.gs_color2:get().g, ui.gs_color2:get().b))
    end

    if (ui.visuals.gs_indc.indicators:get(7) and refs.force_baim:get()) then
        default("BAIM", get_indc_color())
    end

    if (ui.visuals.gs_indc.indicators:get(8) and refs.force_safe:get()) then
        default("SAFE", get_indc_color())
    end

    if (ui.visuals.gs_indc.indicators:get(7) and antiaim_is_fakeducking()) then
        default("FD", get_indc_color())
    end

    if (ui.visuals.gs_indc.indicators:get(2) and refs.hide_shots:get()) then
        default("OSAA", get_indc_color())
    end

    if (ui.visuals.gs_indc.indicators:get(1) and refs.double_tap:get()) then
        local charge = exploits_get_charge()
        local dt_color = (charge == user_ticks - 2) and get_indc_color() or color_t(ui.gs_color2:get().r, ui.gs_color2:get().g, ui.gs_color2:get().b)
        
        circle("DT", dt_color, charge / (user_ticks - 2))
    end

    if (ui.visuals.gs_indc.indicators:get(3) and refs.force_damage:get()) then
        default("MD", get_indc_color())
    end

    if (ui.visuals.gs_indc.indicators:get(5) and refs.freestand:get()) then
        default("FS", get_indc_color())
    end
    return
end

draw_hat = function()
    if (client_is_in_thirdperson()) then
        local local_player = entity_list_get_local_player()
        local origin = local_player:get_hitbox_pos(e_hitboxes.HEAD) + vec3_t(2, 0, 07)

        local screen_pos = render_world_to_screen(origin)
        if (screen_pos ~= nil) then
            local color = get_hat_color()
            if (ui.visuals.china_hat.hat_mode:get() == 2) then
                color = color_t.from_hsb(global_vars_tick_count() % 360 / 360, 1, 1)
            end

            local last_edge
            local view_yaw = engine_get_view_angles().y

            for angle_deg = 0, 360, 15 do
                local offset_vector = angle_t(0, angle_deg + view_yaw, 0):to_vector():scaled(10)
                offset_vector.z = -5

                local screen_pos_edge = render_world_to_screen(origin + offset_vector)
                if (screen_pos_edge ~= nil) then
                    render_line(screen_pos, screen_pos_edge, color)
                    if (last_edge) then
                        render_line(last_edge, screen_pos_edge, color)
                    end
                    last_edge = screen_pos_edge
                end
            end
            return
        else
            return
        end
    else
        return
    end
end

--- @endregion

--- @info: handle menu
--- @region: menu

materials_for_each(function(mat)
    for material = 1, #console_material do
        if (string.match(tostring(mat:get_name()), console_material[material])) then
            cnl_material[material] = mat
        end
    end
end)

local console_state = nil
local jumpshot_state = {}
game_handle = function()
    if (ui.misc.unlock_pingspike:get()) then
        if (cvars.sv_maxunlag:get_float() ~= 0.4) then
            cvars.sv_maxunlag:set_float(0.4)
        end
    else
        if (cvars.sv_maxunlag:get_float() ~= 0.2) then
            cvars.sv_maxunlag:set_float(0.2)
        end
    end

    -- the console colour: the materials are written only when the colour / console state changes (every frame before)
    if (engine_is_app_active()) then
        local c = ui.console_color:get()
        local on = ui.visuals.console:get() and console_is_visible(engine_client)
        local state = on and string.format("%d,%d,%d,%d", c.r, c.g, c.b, c.a) or "off"
        if (state ~= console_state) then
            console_state = state
            for material = 1, #cnl_material do
                local mat = cnl_material[material]
                if (on) then
                    mat:color_modulate(c.r / 255, c.g / 255, c.b / 255)
                    mat:alpha_modulate(c.a / 255)
                else
                    mat:color_modulate(1, 1, 1)
                    mat:alpha_modulate(1)
                end
            end
        end
    end
end

menu_handle = function()
    if (menu_is_open()) then
        handle_dragging()
        if (not info.beta_build) then
            ui.ragebot.resolver.enable_resolver.ref:set(false)
            ui.ragebot.reso_cfg.yaw_calc.ref:set(1)
            ui.ragebot.pose_reso.ref:set(false)
        end

        -- statistics
    
        if (ui.nav.slider:get() == 2) then
            ui.statistics.list.ref:set_items({})
            ui.statistics.list.ref:set(1)
    
            ui.statistics.list.ref:add_item("Hits: " .. cl_logs.c_logs.hits or 0)
            ui.statistics.list.ref:add_item("Misses: " .. cl_logs.c_logs.misses or 0)
            ui.statistics.list.ref:add_item("Kills: " .. cl_logs.c_logs.kills or 0)
            ui.statistics.list.ref:add_item("Deaths: " .. cl_logs.c_logs.deaths or 0)
            ui.statistics.list.ref:add_item("Head shots: " .. cl_logs.c_logs.headshots or 0)
            ui.statistics.list.ref:add_item("Body aims: " .. cl_logs.c_logs.baims or 0)
            ui.statistics.list.ref:add_item("Mismatches: " .. cl_logs.c_logs.mismatches or 0)
            ui.statistics.list.ref:add_item("Evades: " .. cl_logs.c_logs.evades or 0)
        end
    
        if (ui.nav.slider:get() == 1) then
            local item = ui.configs.cloud_list.ref:get_active_item_name()
            local g_item = ui.configs.list.ref:get_active_item_name()
    
            if (item ~= nil) then
                if (item:match("^(.-) %~") ~= info.user) then
                    ui.update_cloud_config:set_visible(false)
                    ui.delete_cloud_config:set_visible(false)
                else
                    ui.update_cloud_config:set_visible(true)
                    ui.delete_cloud_config:set_visible(true)
                end
            end
            
            if (g_item ~= nil) then
                if (g_item == "default.cfg") then
                    ui.save_config:set_visible(false)
                    ui.upload_config:set_visible(false)
                    ui.delete_config:set_visible(false)
                else
                    ui.save_config:set_visible(true)
                    ui.upload_config:set_visible(true)
                    ui.delete_config:set_visible(true)
                end
            end
        end
    
        -- main of menu handle
    
        ui.nav.slider:depend({(false)})

        local page = ui.nav.slider:get()
        local aa_page = page == 4 or (page >= 12 and page <= 14)
        for _, nav_sub in ipairs(ui.nav.subs) do
            nav_sub.button:depend({nav_main_of[page] == nav_sub.main})
        end
        ui.ragebot.smart_baim_hp:depend({ui.ragebot.smart_baim, true})
        ui.ragebot.smart_baim_lethal:depend({ui.ragebot.smart_baim, true})
        ui.ragebot.latency_limit:depend({ui.ragebot.latency_guard, true})
        ui.ragebot.resolver.duck_mode:depend({ui.ragebot.resolver.enable_resolver, true}, {info.beta_build == true})
        ui.ragebot.resolver.auto_duck:depend({ui.ragebot.resolver.enable_resolver, true}, {info.beta_build == true})
        ui.ragebot.resolver.safe_peek:depend({ui.ragebot.resolver.enable_resolver, true}, {info.beta_build == true})
        ui.ragebot.resolver.pred_sel:depend({ui.ragebot.resolver.enable_resolver, true}, {info.beta_build == true})
        ui.ragebot.resolver.calc_box:depend({ui.ragebot.resolver.enable_resolver, true}, {info.beta_build == true})
        ui.ragebot.resolver.shot_pred:depend({ui.ragebot.resolver.enable_resolver, true}, {info.beta_build == true})
        ui.ragebot.resolver.safe_mode:depend({ui.ragebot.resolver.enable_resolver, true}, {info.beta_build == true})
    
        -- configuration (beta) (ragebot)
        ui.ragebot.reso_cfg.disablers:depend({info.beta_build == true})
        ui.ragebot.reso_cfg.at_disabler:depend({info.beta_build == true})
        ui.ragebot.reso_cfg.yaw_calc:depend({info.beta_build == true})
    
        -- backtrack (ragebot)
        ui.ragebot.backtrack.extended_backtrack:depend({ui.ragebot.backtrack.enable_backtrack, true})
    
        -- accuracy boost (ragebot)
    
        ui.ragebot.accuracy_boost.booster_mode:depend({ui.ragebot.accuracy_boost.enable_booster, true})
    
        -- improve doubletap (exploits)
        ui.exploits.better_dt.dt_mode:depend({ui.exploits.better_dt.better_dt, true})
    
        ui.exploits.better_dt.speed_calc:depend({ui.exploits.better_dt.better_dt, true}, {ui.exploits.better_dt.dt_mode:get() == 1})
        ui.exploits.better_dt.dt_speed:depend({ui.exploits.better_dt.better_dt, true}, {ui.exploits.better_dt.dt_mode:get() == 2})
    
        -- customization (visuals)
        ui.visuals.china_hat.hat_mode:depend({ui.visuals.china_hat.enable_hat:get()})
        
        ui.visuals.tesla.width:depend({ui.visuals.tesla.enable_tesla:get()})
        ui.visuals.tesla.beams:depend({ui.visuals.tesla.enable_tesla:get()})
        ui.visuals.tesla.delay:depend({ui.visuals.tesla.enable_tesla:get()})
        ui.visuals.tesla.radius:depend({ui.visuals.tesla.enable_tesla:get()})
    
        -- fake media (misc)
        ui.misc.fake_media.type:depend({ui.misc.fake_media.enable_fakemedia:get()})

        -- logs selection (utils)
        ui.utils.reset_stats:depend({ui.utils.event_logs:get(1)})
        ui.utils.watermark_style:depend({ui.utils.watermark, true})
        ui.utils.watermark_fields:depend({ui.utils.watermark, true})
        ui.utils.keybinds_style:depend({ui.utils.keybinds, true})
        ui.utils.keybinds_mode:depend({ui.utils.keybinds, true})
    
        -- builder (antiaim)
        ui.antiaim.builder.enable:depend({aa_page})
        ui.antiaim.builder.condition:depend({aa_page}, {ui.antiaim.builder.enable, true})
        ui.antiaim.builder.ab_mode:depend({aa_page}, {ui.antiaim.builder.enable, true}, {ui.antiaim.builder.anti_brute, true})
        ui.antiaim.builder.direct:depend({aa_page}, {ui.antiaim.builder.enable, true}, {info.plan == "dev"})
        ui.antiaim.builder.adaptive:depend({aa_page}, {ui.antiaim.builder.enable, true})
        ui.utils.profile:depend({info.plan == "dev"})
        ui.antiaim.builder.preset:depend({aa_page}, {ui.antiaim.builder.enable, true})
        ui.antiaim.features.fl_variance:depend({aa_page}, {ui.antiaim.builder.enable, true})
    
        ui.antiaim.features.antibackstab:depend({aa_page}, {ui.antiaim.builder.enable, true})
        ui.antiaim.features.fakelag:depend({aa_page}, {ui.antiaim.builder.enable, true})
        ui.antiaim.features.safehead:depend({aa_page}, {ui.antiaim.builder.enable, true})
        ui.antiaim.features.warmup:depend({aa_page}, {ui.antiaim.builder.enable, true})
        ui.antiaim.features.correction:depend({aa_page}, {ui.antiaim.builder.enable, true})
    
        for i = 1, #states do
            local state = ui.antiaim.builder[i]
            if (i == 1) then
                state.override:depend({aa_page}, {ui.antiaim.builder.enable, true}, {ui.antiaim.builder.condition, -1})
                state.override.ref:set(true)
            else
                state.override:depend({aa_page}, {ui.antiaim.builder.enable, true}, {ui.antiaim.builder.condition, i})
            end
    
            state.yaw_mode:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i})
            local ym = state.yaw_mode:get()
            state.yaw_val:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 1 or ym == 4 or ym == 5)})
            state.yaw_left:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 2 or ym == 3 or ym == 6)})
            state.yaw_right:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 2 or ym == 3 or ym == 6)})
            state.yaw_meta_left:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 3 or ym == 6)})
            state.yaw_meta_right:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 3 or ym == 6)})
            state.yaw_delay:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 2 or ym == 3)})
            state.meta_delay:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 3)})
            state.yaw_ways:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 4)})
            state.yaw_range:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 4 or ym == 5)})
            state.yaw_hold:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 4 or ym == 6)})
            state.sway_speed:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 5)})
            state.snap_chance:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(ym == 5)})
            state.yaw_modifier:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i})
            state.modifier_degree:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(state.yaw_modifier:get() ~= 1)})
            state.modifier_random:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(state.yaw_modifier:get() ~= 1)})
            state.desync:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i})
            state.desync_left:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i})
            state.desync_right:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i})
            state.desync_meta_left:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i})
            state.desync_meta_right:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i})
            state.trigger_defensive:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i})
            local td = state.trigger_defensive:get()
            local def_angles = td == 2 or td == 4 or td == 6
            state.smart_triggers:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(td == 6)})
            local dp, dy = state.defensive_pitch:get(), state.defensive_yaw:get()
            state.defensive_pitch:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {def_angles})
            state.defensive_pitch_val:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(dp == 8 or dp == 9 or dp == 12)}, {def_angles})
            state.defensive_pitch_val2:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(dp == 9 or dp == 12)}, {def_angles})
            state.defensive_yaw:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {def_angles})
            state.defensive_yaw_val:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(dy == 2 or dy == 3 or dy == 4 or dy == 11 or dy == 12)}, {def_angles})
            state.defensive_speed:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(dy == 5)}, {def_angles})
            state.defensive_range:depend({aa_page}, {ui.antiaim.builder.enable, true}, {state.override, true}, {ui.antiaim.builder.condition, i}, {(dy == 5)}, {def_angles})
        end
    
        groups.nav:depend({(true)})
    
        groups.configs:depend({page == 1})
        groups.cloud_configs:depend({page == 1})
        groups.statistics:depend({page == 2})

        groups.resolver:depend({page == 3}, {info.plan ~= "beta"})
        groups.resolver_beta:depend({page == 3}, {info.beta_build == true}, {info.plan ~= "beta"})
        groups.reso_cfg:depend({page == 3}, {info.beta_build == true}, {info.plan ~= "beta"})
        groups.ragebot:depend({page == 10})
        groups.tickbase:depend({page == 11})
        groups.exploits:depend({page == 5})
        groups.helpers:depend({page == 5})

        groups.settings:depend({aa_page})
        groups.antiaim:depend({page == 4}, {ui.antiaim.builder.enable, true})
        groups.features:depend({page == 4})
        groups.yaw:depend({page == 12})
        groups.jitter:depend({page == 12})
        groups.desync:depend({page == 13})
        groups.defensive:depend({page == 14})

        groups.visuals:depend({page == 6})
        groups.customization:depend({page == 6})
        groups.player:depend({page == 7})
        groups.communication:depend({page == 7})
        groups.misc:depend({page == 8})
        groups.movement:depend({page == 8})
        groups.utils:depend({page == 9})
        groups.sync:depend({page == 9})
        groups.servers:depend({page == 15})

        if (ui.nav.slider:get() == 0) then
            menu_set_group_column("Home | Specter v" .. client_version .. "" .. info.beta_text2, 2)
        else
            menu_set_group_column("Home | Specter v" .. client_version .. "" .. info.beta_text2, 1)
        end
    
        if (info.beta_build) then
            menu_set_group_column("Resolver (beta)", 2)
    
            menu_set_group_column("Resolver", 3)
            menu_set_group_column("Ragebot", 2)
            menu_set_group_column("Tickbase", 2)
        else
            menu_set_group_column("Resolver (beta)", 2)
    
            menu_set_group_column("Resolver", 3)
            menu_set_group_column("Ragebot", 3)
            menu_set_group_column("Tickbase", 2)
        end
        menu_set_group_column("Settings", 1)
        menu_set_group_column("Global", 3)
        menu_set_group_column("Visuals", 2)
        menu_set_group_column("Customization", 3)
        menu_set_group_column("Yaw", 2)
        menu_set_group_column("Jitter", 2)
        menu_set_group_column("Desync", 2)
        menu_set_group_column("Defensive", 2)
        menu_set_group_column("Features", 3)
        menu_set_group_column("Utils", 2)
        menu_set_group_column("Synchronization", 3)
    else
        return
    end
end

--- @endregion

--- @info: main code
--- @region: callbacks

do_player = function()
    perf.add(e_callbacks.PLAYER_ESP, "PLAYER_ESP", function(ctx)
        if (ui.visuals.esp_fonts:get() == 2) then
            ctx:set_font(fonts.pixel)
        elseif (ui.visuals.esp_fonts:get() == 3) then
            ctx:set_font(fonts.verdana_b)
        elseif (ui.visuals.esp_fonts:get() == 4) then
            ctx:set_font(fonts.tahoma)
        elseif (ui.visuals.esp_fonts:get() == 5) then
            ctx:set_font(fonts.tahomabold)
        end
        return
    end)
end

do_aimhit = function()
    perf.add(e_callbacks.AIMBOT_HIT, "AIMBOT_HIT", function(hit)
        if (check_conditions()) then
            local hit_group = hit_groups[hit.hitgroup]
            local aim_group = hit_groups[hit.aim_hitgroup]

            local target = hit.player

            indicator.data["hit"] = (indicator.data["hit"] or 0) + 1
            indicator.shot_count = indicator.shot_count + 1

            if (ui.utils.event_logs:get(2)) then
                local weapon = entity_list_get_local_player():get_active_weapon()
                if (weapon ~= nil) then
                    logs.add_hitlog(hit)
                    if (weapon:get_name() ~= "taser") then
                        local target_hp = target:get_prop('m_iHealth')
                        if (hit_group == "head") then
                            cl_logs.add_log("headshots")
                        end

                        if (hit_group == "stomach" or hit_group == "chest" or hit_group == "upper chest" or hit_group == "lower chest" or hit_group == "pelvis") then
                            cl_logs.add_log("baims")
                        end

                        if (hit_group == aim_group) then
                            if (hit.damage == hit.aim_damage) then
                                if (target_hp > 0) then
                                    cl_logs.add_log("hits")
                                    print("hurt ", get_text_color(), target:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(168, 168, 168), " for ", get_text_color(), hit.damage .. " dmg", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), hit.backtrack_ticks, "t, ", specter_color_t(108, 108, 108), "∠: ", specter_color_t(168, 168, 168), reso.desync and math.floor(reso.desync) or "?", "°, ", specter_color_t(108, 108, 108), "remaining: ", specter_color_t(168, 168, 168), target_hp, " hp")
                                else
                                    cl_logs.add_log("kills")
                                    print("killed ", get_text_color(), target:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(168, 168, 168), " with ", get_text_color(), hit.damage .. " dmg", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), hit.backtrack_ticks, "t, ", specter_color_t(108, 108, 108), "∠: ", specter_color_t(168, 168, 168), reso.desync and math.floor(reso.desync) or "?", "°")
                                end
                            else
                                cl_logs.add_log("mismatches")
                                if (target_hp > 0) then
                                    cl_logs.add_log("hits")
                                    print("hurt ", get_text_color(), target:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(168, 168, 168), " for ", get_text_color(), hit.damage .. " dmg", specter_color_t(255, 162, 0), "!", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), hit.backtrack_ticks, "t, ", specter_color_t(108, 108, 108), "∠: ", specter_color_t(168, 168, 168), reso.desync and math.floor(reso.desync) or "?", "°, ", specter_color_t(108, 108, 108), "exp: ", specter_color_t(168, 168, 168), hit.aim_damage, ", ", specter_color_t(108, 108, 108), "remaining: ", specter_color_t(168, 168, 168), target_hp, " hp")
                                else
                                    cl_logs.add_log("kills")
                                    print("killed ", get_text_color(), target:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(168, 168, 168), " with ", get_text_color(), hit.damage .. " dmg", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), hit.backtrack_ticks, "t, ", specter_color_t(108, 108, 108), "∠: ", specter_color_t(168, 168, 168), reso.desync and math.floor(reso.desync) or "?", "°")
                                end
                            end
                        else
                            cl_logs.add_log("mismatches")
                            if (hit.damage == hit.aim_damage) then
                                if (target_hp > 0) then
                                    cl_logs.add_log("hits")
                                    print("hurt ", get_text_color(), target:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(255, 162, 0), "!", specter_color_t(168, 168, 168), " for ", get_text_color(), hit.damage .. " dmg", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), hit.backtrack_ticks, "t, ", specter_color_t(108, 108, 108), "∠: ", specter_color_t(168, 168, 168), reso.desync and math.floor(reso.desync) or "?", "°, ", specter_color_t(108, 108, 108), "exp: ", specter_color_t(168, 168, 168), aim_group, ", ", specter_color_t(108, 108, 108), specter_color_t(108, 108, 108), "remaining: ", specter_color_t(168, 168, 168), target_hp, " hp")
                                else
                                    cl_logs.add_log("kills")
                                    print("killed ", get_text_color(), target:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(255, 162, 0), "!", specter_color_t(168, 168, 168), " with ", get_text_color(), hit.damage .. " dmg", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), hit.backtrack_ticks, "t, ", specter_color_t(108, 108, 108), "∠: ", specter_color_t(168, 168, 168), reso.desync and math.floor(reso.desync) or "?", "°")
                                end
                            else
                                if (target_hp > 0) then
                                    cl_logs.add_log("hits")
                                    print("hurt ", get_text_color(), target:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(255, 162, 0), "!", specter_color_t(168, 168, 168), " for ", get_text_color(), hit.damage .. " dmg", specter_color_t(255, 162, 0), "!", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), hit.backtrack_ticks, "t, ", specter_color_t(108, 108, 108), "∠: ", specter_color_t(168, 168, 168), reso.desync and math.floor(reso.desync) or "?", "°, ", specter_color_t(108, 108, 108), "exp: ", specter_color_t(168, 168, 168), aim_group, ":", hit.aim_damage, ", ", specter_color_t(108, 108, 108), "remaining: ", specter_color_t(168, 168, 168), target_hp, " hp")
                                else
                                    cl_logs.add_log("kills")
                                    print("killed ", get_text_color(), target:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(255, 162, 0), "!", specter_color_t(168, 168, 168), " with ", get_text_color(), hit.damage .. " dmg", specter_color_t(255, 162, 0), "!", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168), hit.backtrack_ticks, "t, ", specter_color_t(108, 108, 108), "∠: ", specter_color_t(168, 168, 168), reso.desync and math.floor(reso.desync) or "?", "°")
                                end
                            end
                        end
                    end
                end
            end

            if (ui.antiaim.builder.enable:get()) then
                if (game_rules_get_prop("m_gamePhase") == 4 or game_rules_get_prop("m_gamePhase") == 5) then
                    refs.pitch:set(1)
                    refs.yawbase:set(1)
                    
                    refs.jittermode:set(1)
                    refs.desyncside:set(0)
                end
            end
            resolver.on_result(target, hit.hitgroup == hit.aim_hitgroup, false, hit)
            pcall(shotlog.result, hit, true)
            return
        else
            return
        end
    end)
end

do_aimmiss = function()
    perf.add(e_callbacks.AIMBOT_MISS, "AIMBOT_MISS", function(miss)
        local miss_group = hit_groups[miss.aim_hitgroup] or "?"
        local reason = type(miss.reason_string) == "string" and miss.reason_string or "unknown"
        local target = miss.player
        if (target == nil) then return end
        cl_logs.add_log("misses")
        resolver.on_result(target, false, reason == "resolver" or reason == "jitter", miss, reason)
        pcall(shotlog.result, miss, false)
        -- Host-reported reason is authoritative. Movement since the shot,
        -- hurt timing and backtrack age are diagnostics, not miss causes.
        indicator.data[reason] = (indicator.data[reason] or 0) + 1
        indicator.shot_count = indicator.shot_count + 1
        if (ui.utils.event_logs:get(5)) then
            logs.add_misslog(miss)
            local snap = resolver.last_result
            local desync = snap and snap.desync and math.floor(snap.desync) or "?"
            print("missed ", get_text_color(), target:get_name(), specter_color_t(168, 168, 168),
                "'s ", get_text_color(), miss_group, specter_color_t(168, 168, 168), " due to ",
                get_text_color(), reason, get_accent_color(), "  ~  ", specter_color_t(108, 108, 108),
                "hc: ", specter_color_t(168, 168, 168), tostring(miss.aim_hitchance or "?"),
                "%%, ", specter_color_t(108, 108, 108), "Δ: ", specter_color_t(168, 168, 168),
                tostring(miss.backtrack_ticks or "?"), "t, ", specter_color_t(108, 108, 108),
                "∠: ", specter_color_t(168, 168, 168), desync, "°")
        end
    end)
end

do_antiaim = function()
    perf.add(e_callbacks.ANTIAIM, "ANTIAIM", function(ctx, cmd, unpredicted)
        if (check_conditions()) then
            local on_land = bit.band(entity_list_get_local_player():get_prop("m_fFlags"), bit.lshift(1, 0)) ~= 0
            local state = get_state(get_velocity())
        
            if (builder.direct_on()) then
                -- direct control: the anti-aim code writes into recorders, then the lua sends the angles itself
                builder.direct_begin()
                local dctx = builder.direct_ctx(ctx)
                local ok, err = pcall(function()
                    run_antiaim(dctx, cmd, unpredicted)
                    run_exploit(dctx, cmd, unpredicted)
                    run_edgeyaw(dctx, cmd, unpredicted)
                end)
                builder.direct_restore()
                if (ok) then
                    ok, err = pcall(builder.direct_apply, ctx, entity_list_get_local_player())
                end
                if (not ok) then
                    error(err, 0)
                end
            else
                run_antiaim(ctx, cmd, unpredicted)
                run_exploit(ctx, cmd, unpredicted)
                run_edgeyaw(ctx, cmd, unpredicted)
            end

            if (ui.exploits.lag_on_shoot:get()) then
                if (send_lag_packet) then
                    ctx:set_fakelag(false)
                    send_lag_packet = false
                end
            end
        
            if (ui.player.anim_breaker:get()) then
                if (client_is_in_thirdperson()) then
                    menu_find("antiaim", "main", "general", "leg slide"):set(3)
                    ctx:set_render_pose(e_poses.RUN, 0)

                    if (on_land == true) then
                        ground_tick = ground_tick + 1
                    else
                        ground_tick = 0
                        end_time = global_vars_cur_time() + 1
                    end
                
                    if (state >= 5) then
                        ctx:set_render_animlayer(e_animlayers.LEAN, 10)
                    end
                
                    if (ground_tick > 1 and end_time > global_vars_cur_time()) then
                        ctx:set_render_pose(e_poses.BODY_PITCH, 0.5)
                    end
                
                    if (state == 3) then
                        ctx:set_render_animlayer(e_animlayers.MOVEMENT_MOVE, 0.0, 0.0)
                    end
                
                    if (state >= 5) then
                        ctx:set_render_pose(e_poses.JUMP_FALL, 1)
                    end
                
                    if (state >= 5) then
                        ctx:set_render_animlayer(e_animlayers.MOVEMENT_MOVE, 1)
                    end
                
                    if (get_velocity() < 1) then
                        ctx:set_render_animlayer(e_poses.AIM_BLEND_CROUCH_IDLE, 1)
                    end
                else
                    return
                end
                return
            else
                return
            end
        else
            return
        end
    end)
end

do_aimshoot = function()
    perf.add(e_callbacks.AIMBOT_SHOOT, "AIMBOT_SHOOT", function(shot)
        if (check_conditions() and shot.player ~= nil) then
            local idx = shot.player:get_index()
            if (resolver.capture ~= nil) then resolver.capture(shot) end
            reso.aimpos = shot.player:get_hitbox_pos(1)

            reso.desync = (resolver.previous[idx] and resolver.previous[idx].m_flDesync) and (math.floor(resolver.previous[idx].m_flDesync) or resolver.previous[idx].m_dlDesync)
            reso.side = resolver.previous[idx] and resolver.previous[idx].m_flSide or "?"
            
            reso.state = resolver.previous[idx] and resolver.previous[idx].m_flState or "?"
            reso.statenum = resolver.previous[idx] and resolver.previous[idx].m_flStateNum or "?"

            reso.idx = idx
            reso.key = resolver.previous[idx] and resolver.previous[idx].key
            reso.kind = resolver.previous[idx] and resolver.previous[idx].kind
            reso.rel = resolver.previous[idx] and resolver.previous[idx].rel
            
            if (resolver.previous[idx]) then
                reso.is_forced = resolver.previous[idx].is_forced
            else
                reso.is_forced = false
            end

            if (menu_find("aimbot", "general", "misc", "autopeek", "enable")[2]:get()) then
                on_shoot = true
            end
        
            if (ui.exploits.lag_on_shoot:get()) then
                send_lag_packet = true
            end

            on_tesla(shot)
            on_zeus(shot)
        else
            return
        end
        return
    end)
end

do_setupcmd = function()
    perf.add(e_callbacks.SETUP_COMMAND, "SETUP_COMMAND", function(cmd)
        if (check_conditions()) then
            global:update(cmd)

            fast_ladder(cmd)
            super_toss(cmd)
            antiafk(cmd)
            no_fall(cmd)

            update_bt(cmd)
        
            knifebot_helper(cmd)
            zeus_rush(cmd)
            local bt_player = entity_list_get_local_player()
            if (bt_player ~= nil and bt_player:is_alive()) then
                backtrack.update(bt_player)
                backtrack.predict(bt_player)
            end
            better_hs(cmd)
            defuse_bot(cmd)
        
            if (ui.player.visual_rec:get()) then
                if (globals.tick_count() % 64 == 0) then
                    menu_find("visuals", "view", "removals", "visual recoil"):set(false)
        
                    cvars.weapon_recoil_view_punch_extra:set_float(0)
                    cvars.view_recoil_tracking:set_float(1)
                end
            else
                cvars.weapon_recoil_view_punch_extra:set_float(0)
                cvars.view_recoil_tracking:set_float(0)
            end
            return
        else
            knife.countdown = 0
        end
        return
    end)
end

do_target = function()
    perf.add(e_callbacks.TARGET_SELECTION, "TARGET_SELECTION", function(ctx)
        if (check_conditions()) then
            backtrack.target_selection(ctx)
        end
    end)
end

do_hitscan = function()
    perf.add(e_callbacks.HITSCAN, "HITSCAN", function(ctx, cmd, unpredicted_data)
        if (check_conditions()) then
            update_target(ctx)
            if (info.plan ~= "beta") then
                resolver.hitscan(ctx)
            end

            safe_defensive(ctx, cmd, unpredicted_data)
            dmg_prediction(ctx, cmd, unpredicted_data)
        
            accuracy_boost(ctx, cmd, unpredicted_data)
            -- Final authority: later corrections cannot re-enable the head.
            if (ctx.player ~= nil and resolver.safe and resolver.safe[ctx.player:get_index()] == 3) then
                resolver.enforce_body(ctx)
            end
            if (builder.onpeek) then
                exploits.force_anti_exploit_shift()
            else
                return
            end
            return
        else
            return
        end
    end)
end

do_runcmd = function()
    perf.add(e_callbacks.RUN_COMMAND, "RUN_COMMAND", function(cmd, unpredicted_data)
        if (check_conditions()) then
            quick_fall(cmd, unpredicted_data)
            safe_recharge(cmd, unpredicted_data)
            zeus_dt()

            if (ui.exploits.fix_corr:get()) then
                cvars.cl_clock_correction:set_int(0)
            else
                cvars.cl_clock_correction:set_int(1)
            end
            return
        else
            return
        end
    end)
end

do_event = function()
    perf.add(e_callbacks.EVENT, "EVENT", function(event)
        if (check_conditions()) then
            local local_player = entity_list_get_local_player()
            local userid = event.userid

            local entity
            if (userid ~= nil) then
                entity = entity_list_get_player_from_userid(userid)
            end

            if (entity ~= nil) then
                if (event.name == "item_purchase") then
                    if (ui.utils.event_logs:get(3)) then
                        local item = string.gsub(event.weapon, "weapon_", "")
                        if (item ~= nil and item ~= "unknown") then
                            if (entity:get_name() ~= nil and entity ~= local_player) then
                                if (string.find(item, "awp") or string.find(item, "scar20") or string.find(item, "g3sg1")) then
                                    chat_print("{blue}[{lightgreen}Specter{blue}]{yellow} " .. entity:get_name() .. " {white}has bought {lightgreen}" .. item .. "{white}!")
                                end

                                if (string.find(item, "item_defuser")) then
                                    item = "defuser"
                                end

                                if (string.find(item, "usp_silencer")) then
                                    item = "usp-s"
                                end

                                if (string.find(item, "elite")) then
                                    item = "dual berettas"
                                end

                                if (string.find(item, "hkp2000")) then
                                    item = "p2000"
                                end

                                if (string.find(item, "incgrenade")) then
                                    item = "incendiary grenade"
                                end

                                if (string.find(item, "galilar")) then
                                    item = "gali ar"
                                end

                                if (string.find(item, "m4a1_silencer")) then
                                    item = "m4a1-s"
                                end

                                if (string.find(item, "m4a1")) then
                                    item = "m4a4"
                                end

                                if (string.find(item, "item_assaultsuit")) then
                                    item = "assaultsuit"
                                end

                                if (string.find(item, "item_kevlar")) then
                                    item = "kevlar"
                                end
                                print(get_text_color(), entity:get_name(), specter_color_t(168, 168, 168), " has bought ", get_text_color(), item)
                            end
                        end
                    end
                end

                if (event.name == "player_hurt") then
                    local attacker = entity_list_get_player_from_userid(event.attacker)
                    local hit_group = hit_groups[event.hitgroup]

                    local event_dmg = event.dmg_health
                    local dmg_health = entity:get_prop("m_iHealth") - event_dmg

                    local weapon = event.weapon
                    if (attacker) then
                        if (attacker == local_player) then
                            if (ui.utils.event_logs:get(2)) then
                                if (dmg_health <= 0) then
                                    cl_logs.add_log("kills")
                                    if (string.match(weapon, "knife") or weapon == "bayonet") then
                                        print("killed ", get_text_color(), entity:get_name(), specter_color_t(168, 168, 168), " with ", get_text_color(), event_dmg, " dmg ", specter_color_t(168, 168, 168), "using ", get_text_color(), "knife")
                                    elseif (weapon == "hegrenade") then
                                        print("killed ", get_text_color(), entity:get_name(), specter_color_t(168, 168, 168), " with ", get_text_color(), event_dmg, " dmg ", specter_color_t(168, 168, 168), "using ", get_text_color(), "nade")
                                    elseif (weapon == "inferno" or weapon == "incgrenade") then
                                        print("killed ", get_text_color(), entity:get_name(), specter_color_t(168, 168, 168), " with ", get_text_color(), event_dmg, " dmg ", specter_color_t(168, 168, 168), "using ", get_text_color(), "molotov")
                                    elseif (weapon == "taser") then
                                        print("killed ", get_text_color(), entity:get_name(), specter_color_t(168, 168, 168), " with ", get_text_color(), event_dmg, " dmg ", specter_color_t(168, 168, 168), "using ", get_text_color(), "taser")
                                    end
                                else
                                    cl_logs.add_log("hits")
                                    if (string.match(weapon, "knife") or weapon == "bayonet") then
                                        print("hurt ", get_text_color(), entity:get_name(), specter_color_t(168, 168, 168), " for ", get_text_color(), event_dmg, " hp ", specter_color_t(168, 168, 168), "with ", get_text_color(), "a knife", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "remaining: ", specter_color_t(168, 168, 168), dmg_health, " hp")
                                    elseif (weapon == "hegrenade") then
                                        print("hurt ", get_text_color(), entity:get_name(), specter_color_t(168, 168, 168), " for ", get_text_color(), event_dmg, " hp ", specter_color_t(168, 168, 168), "with ", get_text_color(), "a nade", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "remaining: ", specter_color_t(168, 168, 168), dmg_health, " hp")
                                    elseif (weapon == "inferno" or weapon == "incgrenade") then
                                        print("hurt ", get_text_color(), entity:get_name(), specter_color_t(168, 168, 168), " for ", get_text_color(), event_dmg, " hp ", specter_color_t(168, 168, 168), "with ", get_text_color(), "a molotov", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "remaining: ", specter_color_t(168, 168, 168), dmg_health, " hp")
                                    elseif (weapon == "taser") then
                                        print("hurt ", get_text_color(), entity:get_name(), specter_color_t(168, 168, 168), " for ", get_text_color(), event_dmg, " hp ", specter_color_t(168, 168, 168), "with ", get_text_color(), "a taser", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "remaining: ", specter_color_t(168, 168, 168), dmg_health, " hp")
                                    end
                                end
                            end
                        end

                        if (entity:get_index() == local_player:get_index()) then
                            if (ui.utils.event_logs:get(4)) then
                                if (dmg_health <= 0) then
                                    cl_logs.add_log("deaths")
                                    print("killed by ", get_text_color(), attacker:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(168, 168, 168), " with ", get_text_color(), event_dmg, " dmg")
                                else
                                    print("hurt by ", get_text_color(), attacker:get_name(), specter_color_t(168, 168, 168), " in ", get_text_color(), hit_group, specter_color_t(168, 168, 168), " for ", get_text_color(), event_dmg, " dmg", get_accent_color(), "  ~  ", specter_color_t(108, 108, 108), "remaining: ", specter_color_t(168, 168, 168), dmg_health, " hp")
                                end
                            end
                        end
                    end
                end

                if (event.name == "player_falldamage") then
                    if (ui.utils.event_logs:get(4)) then
                        if (entity:get_index() == local_player:get_index()) then
                            print("took ", get_text_color(), math.floor(event.damage + 0.1), " dmg", specter_color_t(168, 168, 168), " from ", get_text_color(), "fall damage.")
                        end
                    end
                end
            end

            if (event.name == "player_connect_full") then
                resolver.reset()
        
                on_shared_esp()
                on_shared_players()
            end

            if (event.name == "round_prestart") then
                if (game_rules_get_prop("m_totalRoundsPlayed") == 0) then
                    resolver.reset()
                end
            end

            if (event.name == "round_start") then
                resolver.new_round()
                builder.incoming, builder.brain_d = {}, {}
                builder.packet_tick, builder.packet_state = nil, nil
                builder.ab_until, builder.ab_phase_until, builder.ab_trigger_tick = 0, 0, nil
                pcall(shotlog.send)
                builder.misses = 0

                if (ui.misc.antiafk:get()) then
                    builder.afk_valid = true
                end


                collectgarbage("collect")
                print("round ", get_text_color(), game_rules_get_prop("m_totalRoundsPlayed"))
            end

            if (event.name == "player_connect" or event.name == "round_start") then
                client_delay_call(function()
                    on_shared_players()
                end, 2.0)
            end

            if (event.name == "game_end") then
                on_shared_esp()
            end

            if (event.name == "bullet_impact") then
                on_miss(event)
            end
            if (event.name == "weapon_fire") then
                builder.capture_incoming(entity_list_get_player_from_userid(event.userid))
            end
            if (event.name == "player_hurt") then
                on_knifebot(event)
                if (local_player == entity) and not (local_player == entity_list_get_player_from_userid(event.attacker)) then
                    hurt_tick = globals.tick_count()
                    builder.anti_brute_trigger()
                    local attacker = entity_list_get_player_from_userid(event.attacker)
                    if (attacker ~= nil and attacker:is_enemy()) then
                        local snapshot = builder.incoming_snapshot(attacker)
                        if (snapshot ~= nil) then snapshot.hurt = true end
                        builder.aa_record("hit", event.hitgroup, event.dmg_health, attacker:get_name(), snapshot)
                    end
                end
            end

            if (event.name == "player_death") then
                on_killsay(event)
                if (local_player == entity_list_get_player_from_userid(event.attacker)) then
                    if (ui.misc.fake_media.enable_fakemedia:get()) then
                        if (ui.misc.fake_media.type:get(1)) then
                            event.headshot = true
                        end

                        if (ui.misc.fake_media.type:get(2)) then
                            event.penetrated = true
                        end

                        if (ui.misc.fake_media.type:get(3)) then
                            event.noscope = true
                        end

                        if (ui.misc.fake_media.type:get(4)) then
                            event.attackerblind = true
                        end

                        if (ui.misc.fake_media.type:get(5)) then
                            event.thrusmoke = true
                        end

                        if (ui.misc.fake_media.type:get(6)) then
                            event.dominated = true
                        end

                        if (ui.misc.fake_media.type:get(7)) then
                            event.revenge = true
                        end
                    end
                    knife.countdown = 0
                end
            end
            
            if (event.name == "player_say") then
                on_chatsync(event)
                on_talkback(event)
            end

            if (event.name == "grenade_thrown") then
                on_nade(event)
            end
            on_brute(event)
        else
            return
        end
        return
    end)
end

do_net = function()
    perf.add(e_callbacks.NET_UPDATE, "NET_UPDATE", function(ctx)
        if (check_conditions()) then
            lets_resolve()
        
            team_animation()
        else
            return
        end
        return
    end)
end

do_paint = function()
    local center_pos
    local load_success, load_result = pcall(function()
        if (info.beta_build) then
            logo = render_load_image("csgo/materials/panorama/images/icons/clean_beta.png")
        else
            logo = render_load_image("csgo/materials/panorama/images/icons/clean_stable.png")
        end

        center_pos = vec2_t(screen_size.x / 2 - logo.size.x / 2, screen_size.y / 2 - logo.size.y / 2)
        return logo
    end)
    
    if (not load_success or logo == nil) then
        client_delay_call(function()
            load_success, load_result = pcall(function()
                if (info.beta_build) then
                    logo = render_load_image("csgo/materials/panorama/images/icons/clean_beta.png")
                else
                    logo = render_load_image("csgo/materials/panorama/images/icons/clean_stable.png")
                end

                center_pos = vec2_t(screen_size.x / 2 - logo.size.x / 2, screen_size.y / 2 - logo.size.y / 2)
                return logo
            end)
        end, 8)
    end

    perf.add(e_callbacks.PAINT, "PAINT", function()
        perf.tick()
        perf.span("notifications", notifications.render)
        if (ui.utils.watermark:get()) then
            perf.span("watermark", draw_watermark)
            perf.span("menu effect", draw_menu)
        end
        if (ui.utils.aa_stats:get() and engine_is_in_game()) then
            perf.span("aa stats", draw_aa_stats)
        end
        if (ui.utils.res_stats:get() and engine_is_in_game()) then
            perf.span("resolver stats", draw_res_stats)
        end

        perf.span("game handle", game_handle)
        perf.span("menu handle", menu_handle)
        perf.span("presence", lets_sync)

        if (engine_is_in_game() and engine_is_connected()) then
            perf.span("clantag", run_clantag)
        end

        if (check_conditions()) then
            local local_player = entity_list_get_local_player()

            perf.span("hit logs", handle_logs)
        
            if (local_player:is_alive()) then
                if (ui.misc.jumpshot:get()) then
                    -- written when the state (or the weapon group) changes, not every frame
                    local m_flags = local_player:get_prop("m_fFlags")
                    local air = ent_speed_2d(local_player) > 10 and (m_flags == 256 or m_flags == 262)
                    local weapon = get_active_weapon()
                    if (air ~= jumpshot_state.air or weapon ~= jumpshot_state.weapon) then
                        jumpshot_state.air, jumpshot_state.weapon = air, weapon
                        menu_find("misc","main","movement","autostrafer"):set(air)
                        menu_find("aimbot",weapon,"accuracy","auostop options","In-Air")[3]:set(7, air)
                    end
                end

                perf.span("miss stats", handle_drawing)
                perf.span("evade list", handle_playerlist)
    
                builder.clockpitch()
                builder.clockyaw()
            
                perf.span("better dt", custom_dt)
                perf.span("edge yaw", edge_yaw)

                if (ui.visuals.china_hat.enable_hat:get()) then
                    perf.span("china hat", draw_hat)
                end

                if (ui.utils.keybinds:get()) then
                    perf.span("keybinds", draw_keybinds)
                end
            
                if (ui.utils.spectators:get()) then
                    perf.span("spectators", draw_spectators)
                end

                if (not menu_is_open()) then
                    if (ui.visuals.crosshair_indc.binds:get(1) or ui.visuals.crosshair_indc.binds:get(2) or ui.visuals.crosshair_indc.binds:get(3) or ui.visuals.crosshair_indc.binds:get(4) or ui.visuals.crosshair_indc.binds:get(5) or ui.visuals.crosshair_indc.binds:get(6) or ui.visuals.crosshair_indc.binds:get(7) or ui.visuals.crosshair_indc.binds:get(8) or ui.visuals.crosshair_indc.binds:get(9) or ui.visuals.crosshair_indc.binds:get(10)) then
                        perf.span("crosshair ind", draw_indicator)
                    end

                    if (ui.visuals.gs_indc.indicators:get(1) or ui.visuals.gs_indc.indicators:get(2) or ui.visuals.gs_indc.indicators:get(3) or ui.visuals.gs_indc.indicators:get(4) or ui.visuals.gs_indc.indicators:get(5) or ui.visuals.gs_indc.indicators:get(6) or ui.visuals.gs_indc.indicators:get(7) or ui.visuals.gs_indc.indicators:get(8) or ui.visuals.gs_indc.indicators:get(9) or ui.visuals.gs_indc.indicators:get(10)) then
                        perf.span("gs ind", draw_gs_indicator)
                    end
                end
            end

            -- voice mute / unmute: only when it is set, and through pcall: the panorama GameStateAPI is nil at times
            -- (an index of it stopped the whole PAINT callback)
            local voice = ui.player.voice_state:get()
            if (voice >= 2 and globals.tick_count() - delay.last_tick > delay.tick_delay) then
                local players = entity_list_get_players()
                local api = libs.tools.js2 and libs.tools.js2.GameStateAPI
                if (players ~= nil and api ~= nil) then
                    delay.last_tick = globals.tick_count()
                    for _, player in pairs(players) do
                        pcall(function()
                            local xuid = api.GetPlayerXuidStringFromEntIndex(player:get_index())
                            if (xuid and (voice == 2) == (api.IsSelectedPlayerMuted(xuid) == false)) then
                                api.ToggleMute(xuid)
                            end
                        end)
                    end
                end
            end
        end

        if (logo ~= nil) then
            if (is_visible) then
                render_push_alpha_modifier(alpha)
                render_texture(logo.id, center_pos, logo.size)
                render_pop_alpha_modifier()
            end
    
            if (is_fading_in) then
                if (alpha < 1.0) then
                    alpha = alpha + 0.003
                else
                    is_fading_in = false
                    fade_out_time = globals.cur_time() + 2.0
                    is_fading_out = true
                end
            end
        
            if (is_fading_out) then
                if (globals.cur_time() >= fade_out_time) then
                    if (alpha > 0) then
                        alpha = alpha - 0.003
                    else
                        is_visible = false
                    end
                end
            end
        else
            return
        end
        return
    end)
    is_fading_in = true
end

callbacks.add(e_callbacks.SHUTDOWN, function()
    print("restoring configuration..")
    servers.leave()

    client_set_clantag("")
    menu_find("antiaim", "main", "general", "ladder antiaim"):set(auto_cfg.ladder_antiaim)
    menu_find("antiaim", "main", "general", "fast ladder move"):set(auto_cfg.fast_ladder_move)

    menu_find("Aimbot", "General", "Aimbot", "Resolve Antiaim"):set(auto_cfg.resolve_antiaim)
    backtrack.restore()
    menu_find("aimbot",get_active_weapon(),"accuracy","auostop options","In-Air")[3]:set(7, auto_cfg.air_autostop)

    menu_find("antiaim", "main", "angles", "pitch"):set(auto_cfg.pitch)
    menu_find("antiaim", "main", "angles", "yaw base"):set(auto_cfg.yawbase)
    menu_find("antiaim", "main", "angles", "yaw add"):set(auto_cfg.yawadd)
    
    menu_find("antiaim", "main", "angles", "rotate"):set(auto_cfg.rotate)
    menu_find("antiaim", "main", "angles", "rotate range"):set(auto_cfg.rotaterange)
    menu_find("antiaim", "main", "angles", "rotate speed"):set(auto_cfg.rotatespeed)
    
    menu_find("antiaim", "main", "angles", "jitter mode"):set(auto_cfg.jittermode)
    menu_find("antiaim", "main", "angles", "jitter type"):set(auto_cfg.jittertype)
    menu_find("antiaim", "main", "angles", "jitter add"):set(auto_cfg.jitterrange)
    
    menu_find("antiaim", "main", "desync", "override stand#move"):set(auto_cfg.overridemove)
    menu_find("antiaim", "main", "desync", "override stand#slow walk"):set(auto_cfg.overridemovesw)
    
    menu_find("antiaim", "main", "desync", "stand", "side"):set(auto_cfg.desyncside)
    
    menu_find("antiaim", "main", "desync", "left amount"):set(auto_cfg.leftamount)
    menu_find("antiaim", "main", "desync", "right amount"):set(auto_cfg.rightamount)
    
    menu_find("antiaim", "main", "auto direction", "states"):set(1, auto_cfg.fsstate)
    menu_find("antiaim", "main", "auto direction", "states"):set(2, auto_cfg.fsstate2)
    menu_find("antiaim", "main", "auto direction", "states"):set(3, auto_cfg.fsstate3)

    menu_find("misc","main","movement","autostrafer"):set(auto_cfg.autostrafer)

    cvars.weapon_recoil_view_punch_extra:set_float(auto_cfg.weapon_recoil_view_punch_extra)
    cvars.view_recoil_tracking:set_float(auto_cfg.view_recoil_tracking)

    cvars.sv_maxusrcmdprocessticks:set_int(auto_cfg.sv_maxusrcmdprocessticks)
    cvars.cl_clock_correction:set_int(auto_cfg.cl_clock_correction)

    cvars.cl_interpolate:set_int(auto_cfg.cl_interpolate)
    cvars.sv_maxunlag:set_float(auto_cfg.sv_maxunlag)

    cvars.sv_party_mode:set_int(auto_cfg.sv_party_mode)

    cvars.sv_maxupdaterate:set_int(auto_cfg.sv_maxupdaterate)
    cvars.sv_minupdaterate:set_int(auto_cfg.sv_minupdaterate)
    
    cvars.r_3dsky:set_int(auto_cfg.r_3dsky)
    cvars.cl_csm_shadows:set_int(auto_cfg.cl_csm_shadows)
    cvars.cl_use_opens_buy_menu:set_int(auto_cfg.cl_use_opens_buy_menu)
    cvars.cl_csm_world_shadows:set_int(auto_cfg.cl_csm_world_shadows)
    cvars.cl_foot_contact_shadows:set_int(auto_cfg.cl_foot_contact_shadows)
    cvars.cl_csm_viewmodel_shadows:set_int(auto_cfg.cl_csm_viewmodel_shadows)
    cvars.cl_csm_rope_shadows:set_int(auto_cfg.cl_csm_rope_shadows)
    cvars.cl_csm_sprite_shadows:set_int(auto_cfg.cl_csm_sprite_shadows)
    cvars.r_drawropes:set_int(auto_cfg.r_drawropes)
    cvars.r_drawsprites:set_int(auto_cfg.r_drawsprites)
    cvars.func_break_max_pieces:set_int(auto_cfg.func_break_max_pieces)
    cvars.mat_queue_mode:set_int(auto_cfg.mat_queue_mode)
    cvars.mat_drawwater:set_int(auto_cfg.mat_drawwater)
    cvars.cl_detail_multiplier:set_int(auto_cfg.cl_detail_multiplier)
    cvars.cl_bob_lower_amt:set_int(auto_cfg.cl_bob_lower_amt)
    cvars.m_rawinput:set_int(auto_cfg.m_rawinput)
    cvars.fps_max:set_int(auto_cfg.fps_max)
    cvars.fps_max_menu:set_int(auto_cfg.fps_max_menu)
    cvars.gameinstructor_enable:set_int(auto_cfg.gameinstructor_enable)
    cvars.cl_freezecameffects_showholiday:set_int(auto_cfg.cl_freezecameffects_showholiday)
    cvars.cl_disablehtmlmotd:set_int(auto_cfg.cl_disablehtmlmotd)
    cvars.muzzleflash_light:set_int(auto_cfg.muzzleflash_light)
    cvars.r_drawdecals:set_int(auto_cfg.r_drawdecals)
    cvars.cl_freezecampanel_position_dynamic:set_int(auto_cfg.cl_freezecampanel_position_dynamic)
    cvars.cl_disablefreezecam:set_int(auto_cfg.cl_disablefreezecam)
    cvars.fog_enable_water_fog:set_int(auto_cfg.fog_enable_water_fog)
    cvars.r_drawtracers:set_int(auto_cfg.r_drawtracers)
    cvars.r_drawtracers_firstperson:set_int(auto_cfg.r_drawtracers_firstperson)
    cvars.r_eyegloss:set_int(auto_cfg.r_eyegloss)
    cvars.r_eyemove:set_int(auto_cfg.r_eyemove)
    cvars.r_eyeshift_x:set_int(auto_cfg.r_eyeshift_x)
    cvars.r_eyeshift_y:set_int(auto_cfg.r_eyeshift_y)
    cvars.r_eyeshift_z:set_int(auto_cfg.r_eyeshift_z)
    cvars.r_eyesize:set_int(auto_cfg.r_eyesize)
    cvars.cl_autohelp:set_int(auto_cfg.cl_autohelp)
    cvars.cl_showhelp:set_int(auto_cfg.cl_showhelp)
    cvars.r_dynamic:set_int(auto_cfg.r_dynamic)
    cvars.cl_csm_static_prop_shadows:set_int(auto_cfg.cl_csm_static_prop_shadows)

    for material = 1, #cnl_material do
        mat = cnl_material[material]

        mat:color_modulate(1, 1, 1)
        mat:alpha_modulate(1)
    end

    on_shared_esp()
    print("goodbye, hope we can see you soon!", specter_color_t(131, 111, 255), " </3")
end)

--- @endregion

--- @info: initialization of everything (so you wont crash)
--- @region: init

print("preparing lua..")
setup = function()

    imports_setup = function()
        libs.tools.js.create()
        presence.install_icon()
        print("preparing lua..", get_text_color(), " (stage 25%%)")
    end

    save_cfg = function()
        auto_cfg.ladder_antiaim = menu_find("antiaim", "main", "general", "ladder antiaim"):get()
        auto_cfg.fast_ladder_move = menu_find("antiaim", "main", "general", "fast ladder move"):get()

        auto_cfg.resolve_antiaim = menu_find("Aimbot", "General", "Aimbot", "Resolve Antiaim"):get()
        auto_cfg.air_autostop = menu_find("aimbot",get_active_weapon(),"accuracy","auostop options","In-Air")[3]:get(7)

        auto_cfg.pitch = menu_find("antiaim","main", "angles", "pitch"):get()
        auto_cfg.yawbase = menu_find("antiaim","main", "angles","yaw base"):get()
        auto_cfg.yawadd = menu_find("antiaim","main", "angles","yaw add"):get()

        auto_cfg.rotate = menu_find("antiaim","main", "angles", "rotate"):get()
        auto_cfg.rotaterange = menu_find("antiaim","main", "angles","rotate range"):get()
        auto_cfg.rotatespeed = menu_find("antiaim","main", "angles","rotate speed"):get()
    
        auto_cfg.jittermode = menu_find("antiaim","main", "angles","jitter mode"):get()
        auto_cfg.jittertype = menu_find("antiaim","main", "angles","jitter type"):get()
        auto_cfg.jitterrange = menu_find("antiaim","main", "angles","jitter add"):get()

        auto_cfg.overridemove = menu_find("antiaim","main", "desync", "override stand#move"):get()
        auto_cfg.overridemovesw = menu_find("antiaim","main", "desync", "override stand#slow walk"):get()

        auto_cfg.desyncside = menu_find("antiaim","main", "desync", "stand", "side"):get()

        auto_cfg.leftamount = menu_find("antiaim","main", "desync", "left amount"):get()
        auto_cfg.rightamount = menu_find("antiaim","main", "desync", "right amount"):get()

        auto_cfg.fsstate = menu_find("antiaim","main", "auto direction", "states"):get(1)
        auto_cfg.fsstate2 = menu_find("antiaim","main", "auto direction", "states"):get(2)
        auto_cfg.fsstate3 = menu_find("antiaim","main", "auto direction", "states"):get(3)

        auto_cfg.autostrafer = menu_find("misc","main","movement","autostrafer"):get()

        auto_cfg.weapon_recoil_view_punch_extra = cvars.weapon_recoil_view_punch_extra:get_float()
        auto_cfg.view_recoil_tracking = cvars.view_recoil_tracking:get_float()

        auto_cfg.sv_maxusrcmdprocessticks = cvars.sv_maxusrcmdprocessticks:get_int()
        auto_cfg.cl_clock_correction = cvars.cl_clock_correction:get_int()

        auto_cfg.cl_interpolate = cvars.cl_interpolate:get_int()
        auto_cfg.sv_maxunlag = cvars.sv_maxunlag:get_float()

        auto_cfg.sv_party_mode = cvars.sv_party_mode:get_int()

        auto_cfg.sv_maxupdaterate = cvars.sv_maxupdaterate:get_int()
        auto_cfg.sv_minupdaterate = cvars.sv_minupdaterate:get_int()
        
        auto_cfg.r_3dsky = cvars.r_3dsky:get_int()
        auto_cfg.cl_csm_shadows = cvars.cl_csm_shadows:get_int()
        auto_cfg.cl_use_opens_buy_menu = cvars.cl_use_opens_buy_menu:get_int()
        auto_cfg.cl_csm_world_shadows = cvars.cl_csm_world_shadows:get_int()
        auto_cfg.cl_foot_contact_shadows = cvars.cl_foot_contact_shadows:get_int()
        auto_cfg.cl_csm_viewmodel_shadows = cvars.cl_csm_viewmodel_shadows:get_int()
        auto_cfg.cl_csm_rope_shadows = cvars.cl_csm_rope_shadows:get_int()
        auto_cfg.cl_csm_sprite_shadows = cvars.cl_csm_sprite_shadows:get_int()
        auto_cfg.r_drawropes = cvars.r_drawropes:get_int()
        auto_cfg.r_drawsprites = cvars.r_drawsprites:get_int()
        auto_cfg.func_break_max_pieces = cvars.func_break_max_pieces:get_int()
        auto_cfg.mat_queue_mode = cvars.mat_queue_mode:get_int()
        auto_cfg.mat_drawwater = cvars.mat_drawwater:get_int()
        auto_cfg.cl_detail_multiplier = cvars.cl_detail_multiplier:get_int()
        auto_cfg.cl_bob_lower_amt = cvars.cl_bob_lower_amt:get_int()
        auto_cfg.m_rawinput = cvars.m_rawinput:get_int()
        auto_cfg.fps_max = cvars.fps_max:get_int()
        auto_cfg.fps_max_menu = cvars.fps_max_menu:get_int()
        auto_cfg.gameinstructor_enable = cvars.gameinstructor_enable:get_int()
        auto_cfg.cl_freezecameffects_showholiday = cvars.cl_freezecameffects_showholiday:get_int()
        auto_cfg.cl_disablehtmlmotd = cvars.cl_disablehtmlmotd:get_int()
        auto_cfg.muzzleflash_light = cvars.muzzleflash_light:get_int()
        auto_cfg.r_drawdecals = cvars.r_drawdecals:get_int()
        auto_cfg.cl_freezecampanel_position_dynamic = cvars.cl_freezecampanel_position_dynamic:get_int()
        auto_cfg.cl_disablefreezecam = cvars.cl_disablefreezecam:get_int()
        auto_cfg.fog_enable_water_fog = cvars.fog_enable_water_fog:get_int()
        auto_cfg.r_drawtracers = cvars.r_drawtracers:get_int()
        auto_cfg.r_drawtracers_firstperson = cvars.r_drawtracers_firstperson:get_int()
        auto_cfg.r_eyegloss = cvars.r_eyegloss:get_int()
        auto_cfg.r_eyemove = cvars.r_eyemove:get_int()
        auto_cfg.r_eyeshift_x = cvars.r_eyeshift_x:get_int()
        auto_cfg.r_eyeshift_y = cvars.r_eyeshift_y:get_int()
        auto_cfg.r_eyeshift_z = cvars.r_eyeshift_z:get_int()
        auto_cfg.r_eyesize = cvars.r_eyesize:get_int()
        auto_cfg.cl_autohelp = cvars.cl_autohelp:get_int()
        auto_cfg.cl_showhelp = cvars.cl_showhelp:get_int()
        auto_cfg.r_dynamic = cvars.r_dynamic:get_int()
        auto_cfg.cl_csm_static_prop_shadows = cvars.cl_csm_static_prop_shadows:get_int()

        print("preparing lua..", get_text_color(), " (stage 30%%)")
    end

    fps_boost = function()
        cvars.sv_party_mode:set_int(1)

        cvars.sv_maxupdaterate:set_int(64)
        cvars.sv_minupdaterate:set_int(64)

        cvars.r_3dsky:set_int(0)
        cvars.cl_csm_shadows:set_int(1)
        cvars.cl_use_opens_buy_menu:set_int(0)
        cvars.cl_csm_world_shadows:set_int(1)
        cvars.cl_foot_contact_shadows:set_int(0)
        cvars.cl_csm_viewmodel_shadows:set_int(0)
        cvars.cl_csm_rope_shadows:set_int(0)
        cvars.cl_csm_sprite_shadows:set_int(0)
        cvars.r_drawropes:set_int(0)
        cvars.r_drawsprites:set_int(0)
        cvars.func_break_max_pieces:set_int(0)
        cvars.mat_queue_mode:set_int(-1)
        cvars.mat_drawwater:set_int(0)
        cvars.cl_detail_multiplier:set_int(0)
        cvars.cl_bob_lower_amt:set_int(0)
        cvars.m_rawinput:set_int(1)
        cvars.fps_max:set_int(0)
        cvars.fps_max_menu:set_int(0)
        cvars.gameinstructor_enable:set_int(0)
        cvars.cl_freezecameffects_showholiday:set_int(0)
        cvars.cl_disablehtmlmotd:set_int(0)
        cvars.muzzleflash_light:set_int(0)
        cvars.r_drawdecals:set_int(0)
        cvars.cl_freezecampanel_position_dynamic:set_int(0)
        cvars.cl_disablefreezecam:set_int(0)
        cvars.fog_enable_water_fog:set_int(0)
        cvars.r_drawtracers:set_int(0)
        cvars.r_drawtracers_firstperson:set_int(0)
        cvars.r_eyegloss:set_int(0)
        cvars.r_eyemove:set_int(0)
        cvars.r_eyeshift_x:set_int(0)
        cvars.r_eyeshift_y:set_int(0)
        cvars.r_eyeshift_z:set_int(0)
        cvars.r_eyesize:set_int(0)
        cvars.cl_autohelp:set_int(0)
        cvars.cl_showhelp:set_int(0)
        cvars.r_dynamic:set_int(0)
        cvars.cl_csm_static_prop_shadows:set_int(1)

        print("preparing lua..", get_text_color(), " (stage 35%%)")
    end

    configure_groups = function()
        groups.nav:depend({false})

        groups.ragebot:depend({false})
        groups.antiaim:depend({false})
        groups.exploits:depend({false})
        groups.helpers:depend({false})
        groups.statistics:depend({false})
        groups.configs:depend({false})
        groups.cloud_configs:depend({false})
        groups.player:depend({false})
        groups.communication:depend({false})
        groups.misc:depend({false})
        groups.movement:depend({false})
        groups.reso_cfg:depend({false})
        groups.utils:depend({false})
        groups.sync:depend({false})
        groups.servers:depend({false})
        groups.yaw:depend({false})
        groups.jitter:depend({false})
        groups.desync:depend({false})
        groups.visuals:depend({false})
        groups.tickbase:depend({false})
        groups.resolver:depend({false})
        groups.features:depend({false})
        groups.customization:depend({false})
        groups.settings:depend({false})
        groups.defensive:depend({false})
        groups.resolver_beta:depend({false})

        print("preparing lua..", get_text_color(), " (stage 40%%)")
    end

    execute_tasks = function()
        do_paint()
        print("preparing lua..", get_text_color(), " (stage 45%%)")

        do_net()
        print("preparing lua..", get_text_color(), " (stage 50%%)")

        do_event()
        print("preparing lua..", get_text_color(), " (stage 55%%)")

        do_runcmd()
        print("preparing lua..", get_text_color(), " (stage 60%%)")

        do_hitscan()
        do_target()
        print("preparing lua..", get_text_color(), " (stage 65%%)")

        do_setupcmd()
        print("preparing lua..", get_text_color(), " (stage 70%%)")

        do_aimshoot()
        print("preparing lua..", get_text_color(), " (stage 75%%)")

        do_antiaim()
        print("preparing lua..", get_text_color(), " (stage 80%%)")

        do_aimmiss()
        print("preparing lua..", get_text_color(), " (stage 85%%)")

        do_aimhit()
        print("preparing lua..", get_text_color(), " (stage 90%%)")

        do_player()
        print("preparing lua..", get_text_color(), " (stage 95%%)")
    end

    finish_up = function()
        configs.reload_configs()
        configs.restore_last()
        configs.reload_cloud_configs()

        print("preparing lua..", get_text_color(), " (stage 100%%)")
    end

    imports_setup()
    save_cfg()
    fps_boost()
    configure_groups()
    execute_tasks()
    finish_up()

    collectgarbage("collect")

    notifications.create("Specter", "Welcome to Specter, " .. info.user .. "!", notifications.types.information)
    print("welcome on Specter!", get_text_color(), " <3")
end
setup()

--- @endregion

--- @info: helper
--- @region: search table(s)

table.insert(on_predict, false)
table.contains = function(tbl, value)
    for _, v in ipairs(tbl) do
        if (v == value) then
            return true
        end
    end
    return false
end

table.check = function(t)
    for _ in pairs(t) do
        return false
    end
    return true
end

--- @endregion
