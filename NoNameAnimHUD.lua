--[[
      _             _  _          _                         _        _   
     | |           (_)| |        (_)                       (_)      | |  
   __| | _ __ ___   _ | |_  _ __  _  _   _   ___ __      __ _   ___ | |__
  / _` || '_ ` _ \ | || __|| '__|| || | | | / _ \\ \ /\ / /| | / __|| '_ \
 | (_| || | | | | || || |_ | |   | || |_| ||  __/ \ V  V / | || (__ | | | |
  \__,_||_| |_| |_||_| \__||_|   |_| \__, | \___|  \_/\_/  |_| \___||_| |_|
                                      __/ |                              
                                     |___/                                 ]]
						
						
script_name("NoNameAnimHUD")
script_author("deddosouru(идея), dmitriyewich")
script_url("https://vk.com/dmitriyewichmods")
script_dependencies("ffi", "memory", "vkeys", "mimgui", "MoonAdditions" )
script_properties('work-in-pause', 'forced-reloading-only')
script_version("1.2")


local lvkeys, vkeys = pcall(require, 'vkeys')
assert(lvkeys, 'Library \'vkeys\' not found.')
local lffi, ffi = pcall(require, 'ffi')
assert(lffi, 'Library \'ffi\' not found.')
local lmemory, memory = pcall(require, 'memory')
assert(lmemory, 'Library \'memory\' not found.')
local lmad, mad = pcall(require, 'MoonAdditions')
assert(lmad, 'Library \'MoonAdditions\' not found.')
local lwm, wm = pcall(require, 'windows.message')
assert(lwm, 'Library \'windows.message\' not found.')  -- https://github.com/THE-FYP/MoonAdditions
local limgui, imgui = pcall(require, 'mimgui') -- https://github.com/THE-FYP/mimgui
assert(limgui, 'Library \'mimgui\' not found.')

local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof

local active = true

local lencoding, encoding = pcall(require, 'encoding')
assert(lencoding, 'Library \'encoding\' not found.')
encoding.default = 'CP1251'
u8 = encoding.UTF8
CP1251 = encoding.CP1251

ffi.cdef[[
	typedef void* HANDLE;
	typedef void* LPSECURITY_ATTRIBUTES;
	typedef unsigned long DWORD;
	typedef int BOOL;
	typedef const char *LPCSTR;
	typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
	} FILETIME, *PFILETIME, *LPFILETIME;

	BOOL __stdcall GetFileTime(HANDLE hFile, LPFILETIME lpCreationTime, LPFILETIME lpLastAccessTime, LPFILETIME lpLastWriteTime);
	HANDLE __stdcall CreateFileA(LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
	BOOL __stdcall CloseHandle(HANDLE hObject);
]]

local function isarray(t, emptyIsObject) -- by Phrogz, сортировка
	if type(t)~='table' then return false end
	if not next(t) then return not emptyIsObject end
	local len = #t
	for k,_ in pairs(t) do
		if type(k)~='number' then
			return false
		else
			local _,frac = math.modf(k)
			if frac~=0 or k<1 or k>len then
				return false
			end
		end
	end
	return true
end

local function map(t,f)
	local r={}
	for i,v in ipairs(t) do r[i]=f(v) end
	return r
end

local keywords = {["and"]=1,["break"]=1,["do"]=1,["else"]=1,["elseif"]=1,["end"]=1,["false"]=1,["for"]=1,["function"]=1,["goto"]=1,["if"]=1,["in"]=1,["local"]=1,["nil"]=1,["not"]=1,["or"]=1,["repeat"]=1,["return"]=1,["then"]=1,["true"]=1,["until"]=1,["while"]=1}

local function neatJSON(value, opts) -- by Phrogz, сортировка
	opts = opts or {}
	if opts.wrap==nil  then opts.wrap = 80 end
	if opts.wrap==true then opts.wrap = -1 end
	opts.indent         = opts.indent         or "  "
	opts.arrayPadding  = opts.arrayPadding  or opts.padding      or 0
	opts.objectPadding = opts.objectPadding or opts.padding      or 0
	opts.afterComma    = opts.afterComma    or opts.aroundComma  or 0
	opts.beforeComma   = opts.beforeComma   or opts.aroundComma  or 0
	opts.beforeColon   = opts.beforeColon   or opts.aroundColon  or 0
	opts.afterColon    = opts.afterColon    or opts.aroundColon  or 0
	opts.beforeColon1  = opts.beforeColon1  or opts.aroundColon1 or opts.beforeColon or 0
	opts.afterColon1   = opts.afterColon1   or opts.aroundColon1 or opts.afterColon  or 0
	opts.beforeColonN  = opts.beforeColonN  or opts.aroundColonN or opts.beforeColon or 0
	opts.afterColonN   = opts.afterColonN   or opts.aroundColonN or opts.afterColon  or 0

	local colon  = opts.lua and '=' or ':'
	local array  = opts.lua and {'{','}'} or {'[',']'}
	local apad   = string.rep(' ', opts.arrayPadding)
	local opad   = string.rep(' ', opts.objectPadding)
	local comma  = string.rep(' ',opts.beforeComma)..','..string.rep(' ',opts.afterComma)
	local colon1 = string.rep(' ',opts.beforeColon1)..colon..string.rep(' ',opts.afterColon1)
	local colonN = string.rep(' ',opts.beforeColonN)..colon..string.rep(' ',opts.afterColonN)

	local build
	local function rawBuild(o,indent)
		if o==nil then
			return indent..'null'
		else
			local kind = type(o)
			if kind=='number' then
				local _,frac = math.modf(o)
				return indent .. string.format( frac~=0 and opts.decimals and ('%.'..opts.decimals..'f') or '%g', o)
			elseif kind=='boolean' or kind=='nil' then
				return indent..tostring(o)
			elseif kind=='string' then
				return indent..string.format('%q', o):gsub('\\\n','\\n')
			elseif isarray(o, opts.emptyTablesAreObjects) then
				if #o==0 then return indent..array[1]..array[2] end
				local pieces = map(o, function(v) return build(v,'') end)
				local oneLine = indent..array[1]..apad..table.concat(pieces,comma)..apad..array[2]
				if opts.wrap==false or #oneLine<=opts.wrap then return oneLine end
				if opts.short then
					local indent2 = indent..' '..apad;
					pieces = map(o, function(v) return build(v,indent2) end)
					pieces[1] = pieces[1]:gsub(indent2,indent..array[1]..apad, 1)
					pieces[#pieces] = pieces[#pieces]..apad..array[2]
					return table.concat(pieces, ',\n')
				else
					local indent2 = indent..opts.indent
					return indent..array[1]..'\n'..table.concat(map(o, function(v) return build(v,indent2) end), ',\n')..'\n'..(opts.indentLast and indent2 or indent)..array[2]
				end
			elseif kind=='table' then
				if not next(o) then return indent..'{}' end

				local sortedKV = {}
				local sort = opts.sort or opts.sorted
				for k,v in pairs(o) do
					local kind = type(k)
					if kind=='string' or kind=='number' then
						sortedKV[#sortedKV+1] = {k,v}
						if sort==true then
							sortedKV[#sortedKV][3] = tostring(k)
						elseif type(sort)=='function' then
							sortedKV[#sortedKV][3] = sort(k,v,o)
						end
					end
				end
				if sort then table.sort(sortedKV, function(a,b) return a[3]<b[3] end) end
				local keyvals
				if opts.lua then
					keyvals=map(sortedKV, function(kv)
						if type(kv[1])=='string' and not keywords[kv[1]] and string.match(kv[1],'^[%a_][%w_]*$') then
							return string.format('%s%s%s',kv[1],colon1,build(kv[2],''))
						else
							return string.format('[%q]%s%s',kv[1],colon1,build(kv[2],''))
						end
					end)
				else
					keyvals=map(sortedKV, function(kv) return string.format('%q%s%s',kv[1],colon1,build(kv[2],'')) end)
				end
				keyvals=table.concat(keyvals, comma)
				local oneLine = indent.."{"..opad..keyvals..opad.."}"
				if opts.wrap==false or #oneLine<opts.wrap then return oneLine end
				if opts.short then
					keyvals = map(sortedKV, function(kv) return {indent..' '..opad..string.format('%q',kv[1]), kv[2]} end)
					keyvals[1][1] = keyvals[1][1]:gsub(indent..' ', indent..'{', 1)
					if opts.aligned then
						local longest = math.max(table.unpack(map(keyvals, function(kv) return #kv[1] end)))
						local padrt   = '%-'..longest..'s'
						for _,kv in ipairs(keyvals) do kv[1] = padrt:format(kv[1]) end
					end
					for i,kv in ipairs(keyvals) do
						local k,v = kv[1], kv[2]
						local indent2 = string.rep(' ',#(k..colonN))
						local oneLine = k..colonN..build(v,'')
						if opts.wrap==false or #oneLine<=opts.wrap or not v or type(v)~='table' then
							keyvals[i] = oneLine
						else
							keyvals[i] = k..colonN..build(v,indent2):gsub('^%s+','',1)
						end
					end
					return table.concat(keyvals, ',\n')..opad..'}'
				else
					local keyvals
					if opts.lua then
						keyvals=map(sortedKV, function(kv)
							if type(kv[1])=='string' and not keywords[kv[1]] and string.match(kv[1],'^[%a_][%w_]*$') then
								return {table.concat{indent,opts.indent,kv[1]}, kv[2]}
							else
								return {string.format('%s%s[%q]',indent,opts.indent,kv[1]), kv[2]}
							end
						end)
					else
						keyvals = {}
						for i,kv in ipairs(sortedKV) do
							keyvals[i] = {indent..opts.indent..string.format('%q',kv[1]), kv[2]}
						end
					end
					if opts.aligned then
						local longest = math.max(table.unpack(map(keyvals, function(kv) return #kv[1] end)))
						local padrt   = '%-'..longest..'s'
						for _,kv in ipairs(keyvals) do kv[1] = padrt:format(kv[1]) end
					end
					local indent2 = indent..opts.indent
					for i,kv in ipairs(keyvals) do
						local k,v = kv[1], kv[2]
						local oneLine = k..colonN..build(v,'')
						if opts.wrap==false or #oneLine<=opts.wrap or not v or type(v)~='table' then
							keyvals[i] = oneLine
						else
							keyvals[i] = k..colonN..build(v,indent2):gsub('^%s+','',1)
						end
					end
					return indent..'{\n'..table.concat(keyvals, ',\n')..'\n'..(opts.indentLast and indent2 or indent)..'}'
				end
			end
		end
	end

	local function memoize()
		local memo = setmetatable({},{_mode='k'})
		return function(o,indent)
			if o==nil then
				return indent..(opts.lua and 'nil' or 'null')
			elseif o~=o then
				return indent..(opts.lua and '0/0' or '"NaN"')
			elseif o==math.huge then
				return indent..(opts.lua and '1/0' or '9e9999')
			elseif o==-math.huge then
				return indent..(opts.lua and '-1/0' or '-9e9999')
			end
			local byIndent = memo[o]
			if not byIndent then
				byIndent = setmetatable({},{_mode='k'})
				memo[o] = byIndent
			end
			if not byIndent[indent] then
				byIndent[indent] = rawBuild(o,indent)
			end
			return byIndent[indent]
		end
	end

	build = memoize()
	return build(value,'')
end

function savejson(table, path)
    local f = io.open(path, "w")
    f:write(table)
    f:close()
end

function convertTableToJsonString(config)
	return (neatJSON(config, { wrap = 40, short = true, sort = true, aligned = true, arrayPadding = 1, afterComma = 1, beforeColon1 = 1 }))
end

local language = {
	RU = {
		by = 'by dmitriyewich aka Valgard Dmitriyewich.\nРаспространение допускается только с указанием автора или ссылки на пост в ВК/mixmods/github\nПКМ - Открыть группу в ВК',
		input_delay = "Задержка кадров",
		input_delay_replay = "Задержка повтора анимации",
		text1 = "Шаг смещения",
		button_save = "Сохранить",
		button_reset = "Сброс",
		checkbox1 = "Включить стандартные иконки",
		checkbox2 = "Режим широкого экрана",
		checkbox3 = "Включены анимированные иконки"
	},
	EN = {
		by = 'by dmitriyewich aka Valgard Dmitriyewich.\nDistribution is allowed only with the indication of the author or a link to the post in the VK/mixmods/github\nRMB - Open a group in VK',
		input_delay = "Frame delay",
		input_delay_replay = "Delay in repeating the animation",
		text1 = "Offset step",
		button_save = "Save",
		button_reset = "Reset",
		checkbox1 = "Enable standard icons",
		checkbox2 = "Widescreen mode",
		checkbox3 = "Enabled animated icons"
	}
}

local config = {}

if doesFileExist("moonloader/NoNameAnimHUD/NoNameAnimHUD.json") then
    local f = io.open("moonloader/NoNameAnimHUD/NoNameAnimHUD.json")
    config = decodeJson(f:read("*a"))
    f:close()
else
	config = {
		["main"] = {
			["language"] = "RU",
			["widescreen"] = false,
			["main_active"] = true,
			["standart_icons"] = false},
		["outline_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 0,
			["customY1"] = 0,
			["customX2"] = 0,
			["customY2"] = 0},
		["fist_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["brassknuckle_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["golfclub_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["nitestick_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["knifecur_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["bat_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["shovel_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["poolcue_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["katana_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["chnsaw_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["colt45_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["silenced_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["desert_eagle_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["chromegun_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["sawnoff_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["shotgspa_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["micro_uzi_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["mp5lng_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["tec9_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["ak47_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["m4_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["cuntgun_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["sniper_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["rocketla_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["heatseek_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["flame_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["minigun_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["grenade_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["teargas_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["molotov_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["satchel_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["spraycan_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["fire_ex_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["camera_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["gun_dildo1_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["gun_dildo2_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["gun_vibe1_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["gun_vibe2_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["flowera_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["gun_cane_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["nvgoggles_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["irgoggles_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["gun_para_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["bomb_anim"] = {
			["delay"] = 0,
			["delay_replay"] = 0,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3};
	}
    savejson(convertTableToJsonString(config), "moonloader/NoNameAnimHUD/NoNameAnimHUD.json")
end

function Standart()	
	imgui.SwitchContext()
	local style = imgui.GetStyle()
	local colors = style.Colors
	local clr = imgui.Col
	local ImVec4 = imgui.ImVec4
	local ImVec2 = imgui.ImVec2

    style.WindowPadding = ImVec2(15, 15)
	style.WindowRounding = 10.0
    style.WindowBorderSize = 0.7;
	style.WindowMinSize = ImVec2(1.5, 1.5)
	style.WindowTitleAlign = ImVec2(0.5, 0.5)
	style.ChildRounding = 3
	style.ChildBorderSize = 1;
	style.PopupRounding = 3;
	style.PopupBorderSize  = 1;
	style.FramePadding = ImVec2(5, 5)
	style.FrameRounding = 6.0
	style.FrameBorderSize  = 0.8;
	style.ItemSpacing = ImVec2(2, 7)
	style.ItemInnerSpacing = ImVec2(8, 6)
	style.ScrollbarSize = 8.0
	style.ScrollbarRounding = 15.0
	style.GrabMinSize = 15.0
	style.GrabRounding = 7.0
	style.IndentSpacing = 25.0
	style.ButtonTextAlign = ImVec2(0.5, 0.5)
	style.SelectableTextAlign = ImVec2(0.5, 0.5)

	colors[clr.Text] = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[clr.TextDisabled] = ImVec4(0.40, 0.40, 0.40, 1.00)
	colors[clr.ChildBg] = ImVec4(0.25, 0.25, 0.25, 1.00)
	colors[clr.WindowBg] = ImVec4(0.25, 0.25, 0.25, 1.00)
	colors[clr.PopupBg] = ImVec4(0.25, 0.25, 0.25, 1.00)
	colors[clr.Border] = ImVec4(0.12, 0.12, 0.12, 0.71)
	colors[clr.BorderShadow] = ImVec4(1.00, 1.00, 1.00, 0.06)
	colors[clr.FrameBg] = ImVec4(0.42, 0.42, 0.42, 0.54)
	colors[clr.FrameBgHovered] = ImVec4(0.42, 0.42, 0.42, 0.40)
	colors[clr.FrameBgActive] = ImVec4(0.56, 0.56, 0.56, 0.67)
	colors[clr.TitleBg] = ImVec4(0.19, 0.19, 0.19, 1.00)
	colors[clr.TitleBgActive] = ImVec4(0.22, 0.22, 0.22, 1.00)
	colors[clr.TitleBgCollapsed] = ImVec4(0.17, 0.17, 0.17, 0.90)
	colors[clr.MenuBarBg] = ImVec4(0.335, 0.335, 0.335, 1.000)
	colors[clr.ScrollbarBg] = ImVec4(0.24, 0.24, 0.24, 0.00)
	colors[clr.ScrollbarGrab] = ImVec4(0.41, 0.41, 0.41, 0.00)
	colors[clr.ScrollbarGrabHovered] = ImVec4(0.52, 0.52, 0.52, 0.00)
	colors[clr.ScrollbarGrabActive] = ImVec4(0.76, 0.76, 0.76, 0.00)
	colors[clr.CheckMark] = ImVec4(0.65, 0.65, 0.65, 1.00)
	colors[clr.SliderGrab] = ImVec4(0.52, 0.52, 0.52, 1.00)
	colors[clr.SliderGrabActive] = ImVec4(0.64, 0.64, 0.64, 1.00)
	colors[clr.Button] = ImVec4(0.54, 0.54, 0.54, 0.35)
	colors[clr.ButtonHovered] = ImVec4(0.52, 0.52, 0.52, 0.59)
	colors[clr.ButtonActive] = ImVec4(0.76, 0.76, 0.76, 1.00)
	colors[clr.Header] = ImVec4(0.38, 0.38, 0.38, 1.00)
	colors[clr.HeaderHovered] = ImVec4(0.47, 0.47, 0.47, 1.00)
	colors[clr.HeaderActive] = ImVec4(0.76, 0.76, 0.76, 0.77)
	colors[clr.Separator] = ImVec4(0.000, 0.000, 0.000, 0.137)
	colors[clr.SeparatorHovered] = ImVec4(0.700, 0.671, 0.600, 0.290)
	colors[clr.SeparatorActive] = ImVec4(0.702, 0.671, 0.600, 0.674)
	colors[clr.ResizeGrip] = ImVec4(0.26, 0.59, 0.98, 0.25)
	colors[clr.ResizeGripHovered] = ImVec4(0.26, 0.59, 0.98, 0.67)
	colors[clr.ResizeGripActive] = ImVec4(0.26, 0.59, 0.98, 0.95)
	colors[clr.PlotLines] = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered] = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[clr.PlotHistogram] = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
	colors[clr.TextSelectedBg] = ImVec4(0.73, 0.73, 0.73, 0.35)
	colors[clr.ModalWindowDimBg] = ImVec4(0.80, 0.80, 0.80, 0.35)
	colors[clr.DragDropTarget] = ImVec4(1.00, 1.00, 0.00, 0.90)
	colors[clr.NavHighlight] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.NavWindowingHighlight] = ImVec4(1.00, 1.00, 1.00, 0.70)
	colors[clr.NavWindowingDimBg] = ImVec4(0.80, 0.80, 0.80, 0.20)
	colors[clr.Tab] = ImVec4(0.25, 0.25, 0.25, 1.00)
	colors[clr.TabHovered] = ImVec4(0.40, 0.40, 0.40, 1.00)
	colors[clr.TabActive] = ImVec4(0.33, 0.33, 0.33, 1.00)
	colors[clr.TabUnfocused] = ImVec4(0.25, 0.25, 0.25, 1.00)
	colors[clr.TabUnfocusedActive] = ImVec4(0.33, 0.33, 0.33, 1.00)
end

local main_window, standart_icons, widescreen_active, main_active_imgui = new.bool(), new.bool(config.main.standart_icons), new.bool(config.main.widescreen), new.bool(config.main.main_active)
local sizeX, sizeY = getScreenResolution()

local int_item = new.int(0)
local item_list = {"outline_anim"}
local ImItems = new['const char*'][#item_list](item_list)

local offset_item = new.int(5)
local offset_list = {'0.1', '0.2', '0.3', '0.4', '0.5', '1.0', '2.0', '4.0', '6.0', '8.0'}
local offset_ImItems = new['const char*'][#offset_list](offset_list)

local ImageButton_color = imgui.ImVec4(1,1,1,1)

local input_delay = new.char[128]()
local input_delay_replay = new.char[128]()

imgui.OnInitialize(function()
	Standart()
	
	logo = imgui.CreateTextureFromFileInMemory(_logo, #_logo)
	close_window = imgui.CreateTextureFromFileInMemory(_close, #_close)
	
    imgui.GetIO().IniFilename = nil
end)

local mainFrame = imgui.OnFrame(
    function() return main_window[0] end,
    function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(247, 230), imgui.Cond.FirstUseEver, imgui.NoResize)
        imgui.Begin("##Main Window", main_window, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollbar)
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 220) / 2) 
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 14)
		imgui.Image(logo, imgui.ImVec2(220, 52))
		if imgui.IsItemHovered() then
			imgui.BeginTooltip()
			imgui.PushTextWrapPos(500)
			imgui.TextUnformatted(language[config.main.language].by)
			imgui.PopTextWrapPos()
			imgui.EndTooltip()
		end	
		if imgui.IsItemClicked(1) then
			os.execute(('explorer.exe "%s"'):format('https://vk.com/dmitriyewichmods'))
		end
		---------------------------------------------------------
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 215) / 2) 
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 6)
		imgui.PushItemWidth(215)
		imgui.Combo("##Combo1", int_item, ImItems, #item_list)
		imgui.PopItemWidth()
		
		
		imgui.PushItemWidth(74)
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 74 - imgui.CalcTextSize(language[config.main.language].text1).x) / 2)
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 6)
		imgui.Combo("##Combo2", offset_item, offset_ImItems, #offset_list)
		imgui.SameLine()
		imgui.Text(language[config.main.language].text1)
		imgui.PopItemWidth()
		---------------------------------------------------------
		
		---------------------------------------------------------	
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 128) / 2)
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
		if imgui.Button("X1+##1", imgui.ImVec2(30, 30)) then
			config[''..item_list[int_item[0] + 1]].customX1 = config[''..item_list[int_item[0] + 1]].customX1 + offset_list[offset_item[0] + 1]
		end
		imgui.SameLine()
		if imgui.Button("X2+##1", imgui.ImVec2(30, 30)) then
			config[''..item_list[int_item[0] + 1]].customX2 = config[''..item_list[int_item[0] + 1]].customX2 + offset_list[offset_item[0] + 1]
		end
		imgui.SameLine()
		if imgui.Button("Y1+##1", imgui.ImVec2(30, 30)) then
			config[''..item_list[int_item[0] + 1]].customY1 = config[''..item_list[int_item[0] + 1]].customY1 + offset_list[offset_item[0] + 1]
		end
		imgui.SameLine()
		if imgui.Button("Y2+##1", imgui.ImVec2(30, 30)) then
			config[''..item_list[int_item[0] + 1]].customY2 = config[''..item_list[int_item[0] + 1]].customY2 + offset_list[offset_item[0] + 1]
		end
		
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 128) / 2)
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 7)
		if imgui.Button("X1-##1", imgui.ImVec2(30, 30)) then
			config[''..item_list[int_item[0] + 1]].customX1 = config[''..item_list[int_item[0] + 1]].customX1 - offset_list[offset_item[0] + 1]
		end
		imgui.SameLine()
		if imgui.Button("X2-##1", imgui.ImVec2(30, 30)) then
			config[''..item_list[int_item[0] + 1]].customX2 = config[''..item_list[int_item[0] + 1]].customX2 - offset_list[offset_item[0] + 1]
		end
		imgui.SameLine()
		if imgui.Button("Y1-##1", imgui.ImVec2(30, 30)) then
			config[''..item_list[int_item[0] + 1]].customY1 = config[''..item_list[int_item[0] + 1]].customY1 - offset_list[offset_item[0] + 1]
		end
		imgui.SameLine()
		if imgui.Button("Y2-##1", imgui.ImVec2(30, 30)) then
			config[''..item_list[int_item[0] + 1]].customY2 = config[''..item_list[int_item[0] + 1]].customY2 - offset_list[offset_item[0] + 1]
		end
		---------------------------------------------------------
		
		---------------------------------------------------------
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 170) / 2)
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
		imgui.TextQuestion("?", language[config.main.language].input_delay)
		imgui.SameLine()
		
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
		imgui.PushItemWidth(74)
		
		local input_delay_hint = config[''..item_list[int_item[0] + 1]].delay
			imgui.StrCopy(input_delay, ''..config[''..item_list[int_item[0] + 1]].delay)
		if imgui.InputTextWithHint('##input_delay', ''..input_delay_hint, input_delay, sizeof(input_delay) - 1, imgui.InputTextFlags.CharsDecimal) then
			if str(input_delay) == nil or str(input_delay) == "" then
				imgui.StrCopy(input_delay, '0')
			end
			config[''..item_list[int_item[0] + 1]].delay = tonumber(str(input_delay))
        end
		imgui.PopItemWidth()
		imgui.SameLine()
		imgui.PushItemWidth(74)
		local input_delay_replay_hint = config[''..item_list[int_item[0] + 1]].delay_replay
			imgui.StrCopy(input_delay_replay, ''..config[''..item_list[int_item[0] + 1]].delay_replay)
		if imgui.InputTextWithHint('##input_delay_replay', ''..input_delay_replay_hint, input_delay_replay, sizeof(input_delay_replay) - 1, imgui.InputTextFlags.CharsDecimal) then
			if str(input_delay_replay) == nil or str(input_delay_replay) == "" then
				imgui.StrCopy(input_delay_replay, '0')
			end
			config[''..item_list[int_item[0] + 1]].delay_replay = tonumber(str(input_delay_replay))
        end
		imgui.PopItemWidth()
		imgui.SameLine()
		imgui.TextQuestion("?", language[config.main.language].input_delay_replay)
		---------------------------------------------------------
		
		---------------------------------------------------------
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 2)
		imgui.SetCursorPosX((imgui.GetWindowWidth() - (imgui.CalcTextSize(language[config.main.language].button_save).x + imgui.CalcTextSize(language[config.main.language].button_reset).x) - 23) / 2)
		if imgui.Button(language[config.main.language].button_save.."##1") then
			savejson(convertTableToJsonString(config), "moonloader/NoNameAnimHUD/NoNameAnimHUD.json")
		end
		imgui.SameLine()
		if imgui.Button(language[config.main.language].button_reset.."##2") then
			config[''..item_list[int_item[0] + 1]].customX1 = 0
			config[''..item_list[int_item[0] + 1]].customX2 = 0
			config[''..item_list[int_item[0] + 1]].customY1 = 0
			config[''..item_list[int_item[0] + 1]].customY2 = 0
			config[''..item_list[int_item[0] + 1]].delay = 0
			imgui.StrCopy(input_delay, '0')
			config[''..item_list[int_item[0] + 1]].delay_replay = 0
			imgui.StrCopy(input_delay_replay, '0')
		end
		---------------------------------------------------------
		imgui.SetCursorPosX(imgui.GetCursorPosX() - 8)
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 20)
		if config.main.language == "RU" then imgui.Text("RU") else imgui.TextDisabled("RU") end
		if imgui.IsItemClicked(0) then config.main.language = "RU" end
		imgui.SameLine()
		imgui.Text("|")
		imgui.SameLine()
		if config.main.language == "EN" then imgui.Text("EN") else imgui.TextDisabled("EN") end
		if imgui.IsItemClicked(0) then config.main.language = "EN" end
		
		---------------------------------------------------------
		imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 0.0)
		imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.00, 0.00, 0.00, 0.0))
		imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00, 0.00, 0.00, 0.00))
		imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.76, 0.76, 0.76, 1.00))
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 25)) 
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 25)
		if imgui.ImageButton(close_window, imgui.ImVec2(16, 16), _,  _, 1, imgui.ImVec4(0,0,0,0), ImageButton_color) then
			main_window[0] = false
		end
		if imgui.IsItemHovered() then
			ImageButton_color = imgui.ImVec4(1,1,1,0.5)
		else
			ImageButton_color = imgui.ImVec4(1,1,1,1)
		end
		imgui.PopStyleColor()
		imgui.PopStyleVar()
		---------------------------------------------------------
		
        if imgui.Checkbox(language[config.main.language].checkbox1.."##1", standart_icons) then
            config.main.standart_icons = standart_icons[0]
        end
        if imgui.Checkbox(language[config.main.language].checkbox2.."##2", widescreen_active) then
            config.main.widescreen = widescreen_active[0]
        end
		
        if imgui.Checkbox(language[config.main.language].checkbox3.."##3", main_active_imgui) then
            config.main.main_active = main_active_imgui[0]
        end

        imgui.End()
    end
)

	function imgui.TextQuestion(label, description)
		imgui.TextDisabled(label)
		if imgui.IsItemHovered() then
			imgui.BeginTooltip()
				imgui.PushTextWrapPos(600)
					imgui.TextUnformatted(description)
				imgui.PopTextWrapPos()
			imgui.EndTooltip()
		end
	end


function main()
	local samp = 0
	
	if isSampLoaded() then samp = 1 end
	if samp == 1 then
		while not isSampAvailable() do wait(1000) end
		
		sampRegisterChatCommand('animhud', function() main_window[0] = not main_window[0] end)
		sampSetClientCommandDescription('animhud', (string.format(u8:decode'Активация/деактивация окна %s, Файл: %s', thisScript().name, thisScript().filename)))
	end

	active_gun = {
		[0] = {["name"] ="fist_anim", ["active"] = false, ["frames"] = {}},
		[1] = {["name"] ="brassknuckle_anim", ["active"] = false, ["frames"] = {}},
		[2] = {["name"] ="golfclub_anim", ["active"] = false, ["frames"] = {}},
		[3] = {["name"] ="nitestick_anim", ["active"] = false, ["frames"] = {}},
		[4] = {["name"] ="knifecur_anim", ["active"] = false, ["frames"] = {}},
		[5] = {["name"] ="bat_anim", ["active"] = false, ["frames"] = {}},
		[6] = {["name"] ="shovel_anim", ["active"] = false, ["frames"] = {}},
		[7] = {["name"] ="poolcue_anim", ["active"] = false, ["frames"] = {}},
		[8] = {["name"] ="katana_anim", ["active"] = false, ["frames"] = {}},
		[9] = {["name"] ="chnsaw_anim", ["active"] = false, ["frames"] = {}},
		[10] = {["name"] ="gun_dildo1_anim", ["active"] = false, ["frames"] = {}},
		[11] = {["name"] ="gun_dildo2_anim", ["active"] = false, ["frames"] = {}},
		[12] = {["name"] ="gun_vibe1_anim", ["active"] = false, ["frames"] = {}},
		[13] = {["name"] ="gun_vibe2_anim", ["active"] = false, ["frames"] = {}},
		[14] = {["name"] ="flowera_anim", ["active"] = false, ["frames"] = {}},
		[15] = {["name"] ="gun_cane_anim", ["active"] = false, ["frames"] = {}},
		[16] = {["name"] ="grenade_anim", ["active"] = false, ["frames"] = {}},
		[17] = {["name"] ="teargas_anim", ["active"] = false, ["frames"] = {}},
		[18] = {["name"] ="molotov_anim", ["active"] = false, ["frames"] = {}},
		[22] = {["name"] ="colt45_anim", ["active"] = false, ["frames"] = {}},
		[23] = {["name"] ="silenced_anim", ["active"] = false, ["frames"] = {}},
		[24] = {["name"] ="desert_eagle_anim", ["active"] = false, ["frames"] = {}},
		[25] = {["name"] ="chromegun_anim", ["active"] = false, ["frames"] = {}},
		[26] = {["name"] ="sawnoff_anim", ["active"] = false, ["frames"] = {}},
		[27] = {["name"] ="shotgspa_anim", ["active"] = false, ["frames"] = {}},
		[28] = {["name"] ="micro_uzi_anim", ["active"] = false, ["frames"] = {}},
		[29] = {["name"] ="mp5lng_anim", ["active"] = false, ["frames"] = {}},
		[30] = {["name"] ="ak47_anim", ["active"] = false, ["frames"] = {}},
		[31] = {["name"] ="m4_anim", ["active"] = false, ["frames"] = {}},
		[32] = {["name"] ="tec9_anim", ["active"] = false, ["frames"] = {}},
		[33] = {["name"] ="cuntgun_anim", ["active"] = false, ["frames"] = {}},
		[34] = {["name"] ="sniper_anim", ["active"] = false, ["frames"] = {}},
		[35] = {["name"] ="rocketla_anim", ["active"] = false, ["frames"] = {}},
		[36] = {["name"] ="heatseek_anim", ["active"] = false, ["frames"] = {}},
		[37] = {["name"] ="flame_anim", ["active"] = false, ["frames"] = {}},
		[38] = {["name"] ="minigun_anim", ["active"] = false, ["frames"] = {}},
		[39] = {["name"] ="satchel_anim", ["active"] = false, ["frames"] = {}},
		[40] = {["name"] ="bomb_anim", ["active"] = false, ["frames"] = {}},
		[41] = {["name"] ="spraycan_anim", ["active"] = false, ["frames"] = {}},
		[42] = {["name"] ="fire_ex_anim", ["active"] = false, ["frames"] = {}},
		[43] = {["name"] ="camera_anim", ["active"] = false, ["frames"] = {}},
		[44] = {["name"] ="nvgoggles_anim", ["active"] = false, ["frames"] = {}},
		[45] = {["name"] ="irgoggles_anim", ["active"] = false, ["frames"] = {}},
		[46] = {["name"] ="gun_para_anim", ["active"] = false, ["frames"] = {}}
	}
	
	
	tetststs = {
	["fist_anim"] = 0,
	["brassknuckle_anim"] = 1,
	["golfclub_anim"] = 2,
	["nitestick_anim"] = 3,
	["knifecur_anim"] = 4,
	["bat_anim"] = 5,
	["shovel_anim"] = 6,
	["poolcue_anim"] = 7,
	["katana_anim"] = 8,
	["chnsaw_anim"] = 9,
	["gun_dildo1_anim"] = 10,
	["gun_dildo2_anim"] = 11,
	["gun_vibe1_anim"] = 12,
	["gun_vibe2_anim"] = 13,
	["flowera_anim"] = 14,
	["gun_cane_anim"] = 15,
	["grenade_anim"] = 16,
	["teargas_anim"] = 17,
	["molotov_anim"] = 18,
	["colt45_anim"] = 22,
	["silenced_anim"] = 23,
	["desert_eagle_anim"] = 24,
	["chromegun_anim"] = 25,
	["sawnoff_anim"] = 26,
	["shotgspa_anim"] = 27,
	["micro_uzi_anim"] = 28,
	["mp5lng_anim"] = 29,
	["ak47_anim"] = 30,
	["m4_anim"] = 31,
	["tec9_anim"] = 32,
	["cuntgun_anim"] = 33,
	["sniper_anim"] = 34,
	["rocketla_anim"] = 35,
	["heatseek_anim"] = 36,
	["flame_anim"] = 37,
	["minigun_anim"] = 38,
	["satchel_anim"] = 39,
	["bomb_anim"] = 40,
	["spraycan_anim"] = 41,
	["fire_ex_anim"] = 42,
	["camera_anim"] = 43,
	["nvgoggles_anim"] = 44,
	["irgoggles_anim"] = 45,
	["gun_para_anim"] = 46
	}
	
	outline_anim, fist_anim, desert_eagle = {}, {}, {}

---------------txd_outline_anim----------txd_outline_anim--------------
	if doesFileExist("moonloader/NoNameAnimHUD/Anim/outline_anim.txd") then
		if mad.get_txd('txd_outline_anim') ~= nil then
			txd_outline_anim = mad.get_txd('txd_outline_anim')
		else
			txd_outline_anim = mad.load_txd(getWorkingDirectory() .. '//NoNameAnimHUD//Anim//outline_anim.txd', 'txd_outline_anim')
		end

		local i_texture_outline_anim = 0
		repeat
			texture_from_txd_outline_anim = txd_outline_anim:get_texture(i_texture_outline_anim)
			outline_anim[i_texture_outline_anim] = texture_from_txd_outline_anim
			i_texture_outline_anim = i_texture_outline_anim + 1
		until texture_from_txd_outline_anim == nil
		outline_anim_active = true
	else
		outline_anim_active = false
	end
---------------txd_outline_anim----------txd_outline_anim---------------

-------------------------txd_anim--------------------txd_anim----------
	local mask = getWorkingDirectory() .. "//NoNameAnimHUD//Anim//*" 

	local handle, file = findFirstFile(mask)
	
	while handle and file do
		if file ~= "." and file ~= ".." and file ~= "outline_anim.txd" then
			if doesFileExist("moonloader/NoNameAnimHUD/Anim/"..file) then
				local no_tdx = file:gsub(".txd", "")
				local no_tdx_tbl = file:gsub(".txd", "")
				
				if mad.get_txd(no_tdx) ~= nil then -- Проверяет наличие txd в памяти, костыль на случай перезапуска скрипта(ов)
					txd_file = mad.get_txd(no_tdx)
				else
					txd_file = mad.load_txd(getWorkingDirectory() .. '//NoNameAnimHUD//Anim//'..file, no_tdx)
				end

				local i_texture = 0
				repeat
					no_tdx = txd_file:get_texture(i_texture)
					active_gun[tetststs[no_tdx_tbl]].frames[i_texture] = no_tdx
					i_texture = i_texture + 1
				until no_tdx == nil
				
				active_gun[tetststs[no_tdx_tbl]].active = true
				item_list[#item_list+1] = no_tdx_tbl
				ImItems = new['const char*'][#item_list](item_list)
			else
				active_gun[tetststs[no_tdx_tbl]].active = false
			end
		end
		file = findNextFile(handle)
	end
-------------------------txd_anim--------------------txd_anim----------

	files = {}
	local time = get_file_modify_time(string.format("%s/NoNameAnimHUD/NoNameAnimHUD.json",getWorkingDirectory()))
	if time ~= nil then
	  files[string.format("%s/NoNameAnimHUD/NoNameAnimHUD.json",getWorkingDirectory())] = time
	end
	lua_thread.create(function() -- отдельный поток для проверки изменений конфига
		while true do wait(274)
			if files ~= nil and not main_window[0] then  -- by FYP
				for fpath, saved_time in pairs(files) do
					local file_time = get_file_modify_time(fpath)
					if file_time ~= nil and (file_time[1] ~= saved_time[1] or file_time[2] ~= saved_time[2]) then
						print('Reloading "' .. thisScript().name .. '"...')
						thisScript():reload()
						files[fpath] = file_time -- update time
					end
				end
			end
		end
	end)

	lua_thread.create(function() -- отдельный поток для прогона кадров обводки, если в обычный запихнуть, то будет мигать.
		i_outline_anim = 0
		while true do wait(config.outline_anim.delay)
			i_outline_anim = i_outline_anim + 1
			if i_outline_anim >= #outline_anim then
				i_outline_anim = 0
				wait(config.outline_anim.delay_replay)
			end
		end
    end)

	lua_thread.create(function() -- отдельный поток для прогона кадров иконок
		i_delay = 0
		i_delay_replay = 0
		i_frames_max = 0
		i_frames = 0
		while true do wait(i_delay)
			if i_frames > i_frames_max then
				i_frames = 0
			else
				i_frames = i_frames + 1
				if i_frames == i_frames_max then
					i_frames = 0
					wait(i_delay_replay)
				end
			end
		end
    end)

	-- writeMemory(0x589353, 1, 0)
	-- print(readMemory(0x589353, 1, true))
	-----XXXXXXXXXXXXXXXXX-----------
	-- memoryX = allocateMemory(4)
	-- writeMemory(memoryX, 4, ConvertFistX(497), false)
	-- writeMemory(0x58F927, 4, memoryX)

	-- testX = memory.getuint32(0x58F927, false) -- WeaponIconX
	-- print("X ".. memory.getfloat(testX))
	-- print("X ".. GetX_Icons())
	-----XXXXXXXXXXXXXXXXX-----------


	-----YYYYYYYYYYYYYYYYYY---
	-- memoryY = allocateMemory(4)
	-- writeMemory(memoryY, 4, ConvertFistY(448), true)
	-- writeMemory(0x58F913, 4, memoryY, true)

	-- testY = memory.getuint32(0x58F913, true) -- WeaponIconX
	-- print("Y ".. memory.getfloat(testY))
	-- print("Y ".. GetY_Icons())
	-----YYYYYYYYYYYYYYYYYY---
	-- print(active_gun[24].active)
	
				
	while true do wait(0)
	
		if samp == 0 then
			if testCheat("animhud") then main_window[0] = not main_window[0] end
			if hasCutsceneLoaded() then active = false else active = true end
		end
		
		if samp == 1 then
			if sampGetGamestate() == 3 then active = true else active = false end
		end

		-------------------------------
		local radar = memory.getint8(0xBA6769)
		local hud = memory.getint8(0xA444A0)
		if config.main.main_active and active and hud == 1 and radar == 1 then
			local currentGun = getCurrentCharWeapon(PLAYER_PED)
			if not standart_icons[0] and active_gun[currentGun].active then
				memory.write(0x58D7D0, 195, 1, true) -- Выключить иконки.
			else
				memory.write(0x58D7D0, 161, 1, true) -- Включить иконки.
			end

			
			if active_gun[currentGun].active then
				i_frames_max = #active_gun[currentGun].frames
				i_delay = config[''..active_gun[currentGun].name].delay
				i_delay_replay = config[''..active_gun[currentGun].name].delay_replay
				
				display_texture(active_gun[currentGun].frames[i_frames], convert_x(GetX_Icons() + config[''..active_gun[currentGun].name].customX1) , convert_y(GetY_Icons() + config[''..active_gun[currentGun].name].customY1), convert_x((GetX_Icons() + width_icons().x) + config[''..active_gun[currentGun].name].customX2), convert_y((GetY_Icons() + width_icons().y) + config[''..active_gun[currentGun].name].customY2))
			end

			if outline_anim_active and active_gun[currentGun].active then
				display_texture(outline_anim[i_outline_anim], convert_x(GetX_Icons() + config.outline_anim.customX1) , convert_y(GetY_Icons() + config.outline_anim.customY1), convert_x((GetX_Icons() + width_icons().x) + config.outline_anim.customX2), convert_y((GetY_Icons() + width_icons().y) + config.outline_anim.customY2)) -- обводка
			end
		else
			memory.write(0x58D7D0, 161, 1, true) -- Включить иконки.
		end
		-- -------------------------------
	end
end

function ConvertFistX(x) -- Как ни странно - переводит игровую X-координату под фист
	if config.main.widescreen then
		local xcx = ((x / 849) * 849) - 529
		local xcx = float2hex(-xcx)
		return xcx
	elseif not config.main.widescreen then
		local xcx = ((x / 529) * 529) - 529
		local xcx = float2hex(-xcx)
		return xcx
	end

end

function GetX_Icons() -- получает игровую X-координату фиста
	local Fist_X = memory.getuint32(0x58F927, false) -- WeaponIconX
	local fX_Fist = memory.getfloat(Fist_X)

	if config.main.widescreen then
		local xcx = ((fX_Fist / 849) * 849) - 576.5
		local xcx = math.round(-xcx, 2)
		return xcx
	elseif not config.main.widescreen then
		local xcx = ((fX_Fist / 529) * 529) - 529
		local xcx = math.round(-xcx, 2)
		return xcx
	end
end

--Вообще Y переводить не обязательно, вроде как изначально там правильное значение
function ConvertFistY(y) -- переводит игровую Y-координату под фист
	if config.main.widescreen then
		local ycy = ((y / 448) * 448) + 135
		local ycy = float2hex(ycy)
		return ycy
	elseif not config.main.widescreen then
		local ycy = ((y / 448) * 448) - 448
		local ycy = float2hex(ycy)
		return ycy
	end
end

function GetY_Icons() -- получает игровую Y-координату фиста
	local Fist_Y = memory.getuint32(0x58F913, false) -- WeaponIconY
	local fY_Fist = memory.getfloat(Fist_Y)

	if config.main.widescreen then
		local ycy = ((fY_Fist / 583) * 583) - 5
		local ycy = math.round(ycy, 2) -- округление, не обязательно
		return ycy
	elseif not config.main.widescreen then
		local ycy = ((fY_Fist / 448) * 448)
		local ycy = math.round(ycy, 2) -- округление, не обязательно
		return ycy
	end
end

function width_icons() --ширина+высота фиста, стандарт 47,0
	local Iconcs_Width = memory.getuint32(0x58FAAB, false) -- WeaponIconWidth,
	local fX_Width = memory.getfloat(Iconcs_Width)
	if config.main.widescreen then
		width_table = {}
		width_table['x'] = fX_Width - 15.5
		width_table['y'] = fX_Width - 10.5
		return width_table
	elseif not config.main.widescreen then
		width_table = {}
		width_table['x'] = fX_Width
		width_table['y'] = fX_Width
		return width_table
	end
end

math.round = function(num, idp) -- округление, не обязательно
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function float2hex (n) -- https://stackoverflow.com/a/19996852
    if n == 0.0 then return 0.0 end

    local sign = 0
    if n < 0.0 then
        sign = 0x80
        n = -n
    end

    local mant, expo = math.frexp(n)
    local hext = {}

    if mant ~= mant then
        hext[#hext+1] = string.char(0xFF, 0x88, 0x00, 0x00)

    elseif mant == math.huge or expo > 0x80 then
        if sign == 0 then
            hext[#hext+1] = string.char(0x7F, 0x80, 0x00, 0x00)
        else
            hext[#hext+1] = string.char(0xFF, 0x80, 0x00, 0x00)
        end

    elseif (mant == 0.0 and expo == 0) or expo < -0x7E then
        hext[#hext+1] = string.char(sign, 0x00, 0x00, 0x00)

    else
        expo = expo + 0x7E
        mant = (mant * 2.0 - 1.0) * math.ldexp(0.5, 24)
        hext[#hext+1] = string.char(sign + math.floor(expo / 0x2),
                                    (expo % 0x2) * 0x80 + math.floor(mant / 0x10000),
                                    math.floor(mant / 0x100) % 0x100,
                                    mant % 0x100)
    end

    return tonumber(string.gsub(table.concat(hext),"(.)",
                                function (c) return string.format("%02X%s",string.byte(c),"") end), 16)
end

function get_file_modify_time(path) -- by FYP
	local handle = ffi.C.CreateFileA(path,
		0x80000000, -- GENERIC_READ
		0x00000001 + 0x00000002, -- FILE_SHARE_READ | FILE_SHARE_WRITE
		nil,
		3, -- OPEN_EXISTING
		0x00000080, -- FILE_ATTRIBUTE_NORMAL
		nil)
	local filetime = ffi.new('FILETIME[3]')
	if handle ~= -1 then
		local result = ffi.C.GetFileTime(handle, filetime, filetime + 1, filetime + 2)
		ffi.C.CloseHandle(handle)
		if result ~= 0 then
			return {tonumber(filetime[2].dwLowDateTime), tonumber(filetime[2].dwHighDateTime)}
		end
	end
	return nil
end

function display_texture(tex, x, y, x2, y2, r, g, b, a, angle)
	if tex ~= nil then
		tex:draw(x, y, x2, y2, r, g, b, a, angle)
	else
		i_frames = 0
	end
end

function convert_x(x)
	local gposX, gposY = convertGameScreenCoordsToWindowScreenCoords(x, x)
	return gposX
end

function convert_y(y)
	local gposX, gposY = convertGameScreenCoordsToWindowScreenCoords(y, y)
	return gposY
end

function onWindowMessage(msg, wparam, lparam)
    if msg == wm.WM_KEYDOWN and wparam == 0x1B and main_window[0] then
        main_window[0] = false
        consumeWindowMessage(true, false)
    end
end

function onExitScript()
	-- freeMemory(memoryX)
	-- freeMemory(memoryY)
	memory.write(0x58D7D0, 161, 1, true) -- Включить иконки.
end


_close ="\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x21\x00\x00\x00\x21\x08\x06\x00\x00\x00\x57\xE4\xC2\x6F\x00\x00\x00\x09\x70\x48\x59\x73\x00\x00\x06\xEC\x00\x00\x06\xEC\x01\x1E\x75\x38\x35\x00\x00\x04\xE8\x69\x54\x58\x74\x58\x4D\x4C\x3A\x63\x6F\x6D\x2E\x61\x64\x6F\x62\x65\x2E\x78\x6D\x70\x00\x00\x00\x00\x00\x3C\x3F\x78\x70\x61\x63\x6B\x65\x74\x20\x62\x65\x67\x69\x6E\x3D\x22\xEF\xBB\xBF\x22\x20\x69\x64\x3D\x22\x57\x35\x4D\x30\x4D\x70\x43\x65\x68\x69\x48\x7A\x72\x65\x53\x7A\x4E\x54\x63\x7A\x6B\x63\x39\x64\x22\x3F\x3E\x20\x3C\x78\x3A\x78\x6D\x70\x6D\x65\x74\x61\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x3D\x22\x61\x64\x6F\x62\x65\x3A\x6E\x73\x3A\x6D\x65\x74\x61\x2F\x22\x20\x78\x3A\x78\x6D\x70\x74\x6B\x3D\x22\x41\x64\x6F\x62\x65\x20\x58\x4D\x50\x20\x43\x6F\x72\x65\x20\x36\x2E\x30\x2D\x63\x30\x30\x36\x20\x37\x39\x2E\x64\x61\x62\x61\x63\x62\x62\x2C\x20\x32\x30\x32\x31\x2F\x30\x34\x2F\x31\x34\x2D\x30\x30\x3A\x33\x39\x3A\x34\x34\x20\x20\x20\x20\x20\x20\x20\x20\x22\x3E\x20\x3C\x72\x64\x66\x3A\x52\x44\x46\x20\x78\x6D\x6C\x6E\x73\x3A\x72\x64\x66\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x77\x77\x77\x2E\x77\x33\x2E\x6F\x72\x67\x2F\x31\x39\x39\x39\x2F\x30\x32\x2F\x32\x32\x2D\x72\x64\x66\x2D\x73\x79\x6E\x74\x61\x78\x2D\x6E\x73\x23\x22\x3E\x20\x3C\x72\x64\x66\x3A\x44\x65\x73\x63\x72\x69\x70\x74\x69\x6F\x6E\x20\x72\x64\x66\x3A\x61\x62\x6F\x75\x74\x3D\x22\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x6D\x70\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x64\x63\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x70\x75\x72\x6C\x2E\x6F\x72\x67\x2F\x64\x63\x2F\x65\x6C\x65\x6D\x65\x6E\x74\x73\x2F\x31\x2E\x31\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x2F\x31\x2E\x30\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x6D\x70\x4D\x4D\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x6D\x6D\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x73\x74\x45\x76\x74\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x73\x54\x79\x70\x65\x2F\x52\x65\x73\x6F\x75\x72\x63\x65\x45\x76\x65\x6E\x74\x23\x22\x20\x78\x6D\x70\x3A\x43\x72\x65\x61\x74\x6F\x72\x54\x6F\x6F\x6C\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x32\x32\x2E\x34\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x20\x78\x6D\x70\x3A\x43\x72\x65\x61\x74\x65\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x33\x54\x31\x39\x3A\x30\x30\x3A\x34\x30\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x3A\x4D\x6F\x64\x69\x66\x79\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x33\x54\x31\x39\x3A\x30\x37\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x3A\x4D\x65\x74\x61\x64\x61\x74\x61\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x33\x54\x31\x39\x3A\x30\x37\x2B\x30\x33\x3A\x30\x30\x22\x20\x64\x63\x3A\x66\x6F\x72\x6D\x61\x74\x3D\x22\x69\x6D\x61\x67\x65\x2F\x70\x6E\x67\x22\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x43\x6F\x6C\x6F\x72\x4D\x6F\x64\x65\x3D\x22\x33\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x49\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x32\x31\x36\x36\x32\x61\x65\x62\x2D\x64\x66\x61\x32\x2D\x62\x35\x34\x31\x2D\x62\x30\x64\x37\x2D\x63\x66\x32\x39\x35\x34\x32\x34\x66\x37\x32\x35\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x44\x6F\x63\x75\x6D\x65\x6E\x74\x49\x44\x3D\x22\x78\x6D\x70\x2E\x64\x69\x64\x3A\x32\x31\x36\x36\x32\x61\x65\x62\x2D\x64\x66\x61\x32\x2D\x62\x35\x34\x31\x2D\x62\x30\x64\x37\x2D\x63\x66\x32\x39\x35\x34\x32\x34\x66\x37\x32\x35\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x4F\x72\x69\x67\x69\x6E\x61\x6C\x44\x6F\x63\x75\x6D\x65\x6E\x74\x49\x44\x3D\x22\x78\x6D\x70\x2E\x64\x69\x64\x3A\x32\x31\x36\x36\x32\x61\x65\x62\x2D\x64\x66\x61\x32\x2D\x62\x35\x34\x31\x2D\x62\x30\x64\x37\x2D\x63\x66\x32\x39\x35\x34\x32\x34\x66\x37\x32\x35\x22\x3E\x20\x3C\x78\x6D\x70\x4D\x4D\x3A\x48\x69\x73\x74\x6F\x72\x79\x3E\x20\x3C\x72\x64\x66\x3A\x53\x65\x71\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x73\x74\x45\x76\x74\x3A\x61\x63\x74\x69\x6F\x6E\x3D\x22\x63\x72\x65\x61\x74\x65\x64\x22\x20\x73\x74\x45\x76\x74\x3A\x69\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x32\x31\x36\x36\x32\x61\x65\x62\x2D\x64\x66\x61\x32\x2D\x62\x35\x34\x31\x2D\x62\x30\x64\x37\x2D\x63\x66\x32\x39\x35\x34\x32\x34\x66\x37\x32\x35\x22\x20\x73\x74\x45\x76\x74\x3A\x77\x68\x65\x6E\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x33\x54\x31\x39\x3A\x30\x30\x3A\x34\x30\x2B\x30\x33\x3A\x30\x30\x22\x20\x73\x74\x45\x76\x74\x3A\x73\x6F\x66\x74\x77\x61\x72\x65\x41\x67\x65\x6E\x74\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x32\x32\x2E\x34\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x2F\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x53\x65\x71\x3E\x20\x3C\x2F\x78\x6D\x70\x4D\x4D\x3A\x48\x69\x73\x74\x6F\x72\x79\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x44\x65\x73\x63\x72\x69\x70\x74\x69\x6F\x6E\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x52\x44\x46\x3E\x20\x3C\x2F\x78\x3A\x78\x6D\x70\x6D\x65\x74\x61\x3E\x20\x3C\x3F\x78\x70\x61\x63\x6B\x65\x74\x20\x65\x6E\x64\x3D\x22\x72\x22\x3F\x3E\xCF\x38\xDC\x53\x00\x00\x04\x73\x49\x44\x41\x54\x58\x85\xC5\x97\x4B\x6F\x1B\x55\x14\xC7\x03\x02\x04\xE2\x0B\xC0\x9E\x25\xAB\x0A\xE8\x86\x45\x58\x20\x40\x15\x12\xB1\x33\x1E\x3F\xE2\x47\xD3\xD4\x6E\x43\x1B\x52\x1A\xE2\xF8\x3D\x63\x8F\x5F\xB1\xF3\x7E\xB6\x85\x0F\xC5\x82\x47\x85\xC4\x02\x54\x21\xB1\x8A\xED\x48\x14\x55\xE8\x72\xFE\xD7\x3E\xCE\x9D\x71\xC6\x8F\xA4\x6A\x17\x47\xE3\x99\xB9\x73\xCE\xCF\xFF\x7B\xEE\x39\xF7\x4E\x09\x21\xA6\x5E\xB6\xBD\x74\x00\x57\x08\x5D\xF7\x5C\xF1\xF9\xBD\x4B\x9A\xDF\x73\x4D\xD3\xB4\xB7\x2E\x1B\x04\x3E\x66\xF5\xD9\x2F\x66\x75\xCF\x5D\xF8\x9E\x9A\x9A\x7A\xC5\x15\x82\x06\xBF\xE3\x0F\xCE\xFE\x19\x8A\x06\x4E\x6E\x7F\x9D\x78\x1A\x9B\x8F\xB6\xF5\x80\xF6\x17\x3D\xFF\xE8\xA2\x00\xBA\x3E\xF3\xBE\x1E\xF0\xFD\x11\x9D\x8F\xB4\x6F\x2D\xDE\x7C\x1A\x0A\x07\x5B\xE4\xF3\x89\x67\xCE\xF3\xEE\x00\x04\x05\x7A\xC3\x1F\xD0\x7E\x5C\x5A\xBE\xF3\xAC\x52\x2B\x09\x58\xB5\x6E\x89\x54\x66\x55\xD0\x47\x1D\x7A\xFF\xF1\xE4\x00\x9E\x2B\xFE\x80\xAF\x95\x4C\x7F\x27\x6A\xEB\x65\xE9\x0F\x7E\x97\xBF\xBD\xFB\x8C\x62\xFD\x12\x8B\xC5\xDE\xB4\x43\x04\x66\x3E\x0D\x47\x82\x1D\x15\x00\x1F\xD6\x1B\x15\x91\x2F\x64\x84\x3F\x38\x19\x08\x03\x64\xF3\x29\xB1\xDE\xAC\x4A\x3F\x2A\x48\x24\x36\xD7\xA6\x98\x9F\xDB\x21\xFC\x9E\x60\x3C\x71\xA3\x0F\xC1\x00\x70\xD0\xD8\xA8\x89\x82\x99\x1B\x1B\x84\x01\x72\x46\x5A\x34\x37\xEB\xF2\x7B\x15\x04\xFE\xE3\xB7\x16\x3A\x14\x33\xE6\x84\xB8\x16\xB9\x3E\xD7\x56\x55\x60\x00\x38\xDA\xD8\x5A\x17\x66\x31\x4F\x20\xBE\xA1\x20\x0C\x50\x30\x33\x62\x73\xBB\x21\xBF\x53\x41\x58\x0D\x52\xA2\xE5\xF3\x79\xBF\xB2\x41\x20\x63\xF5\x90\xF6\x53\x72\x6D\xC5\xA6\x02\x03\xC0\xE1\xD6\x4E\x53\x14\x2D\xC3\x15\x84\x01\x8C\x62\x4E\x6C\xEF\x6E\xC8\xF1\x2A\x08\xAB\x91\x4C\xAF\x50\x9E\xF9\x7E\xE6\x55\x62\x73\xE2\xF5\x7B\x3F\xD0\x83\x5A\x3B\xD3\x9B\x47\x56\x81\x01\xE0\x78\x67\x6F\x53\x58\x65\x73\x00\x84\x01\x4C\x2B\x2F\x76\xF7\xB7\xE4\x38\x15\x84\xD5\xC8\x19\x19\x81\x18\x88\xE5\x5A\x27\xE0\x18\x83\x30\x58\x55\x81\x01\x10\x60\xEF\x60\x5B\x94\xAB\xA5\x3E\x88\x04\x08\xFA\x5A\xA5\xB2\x21\xF6\x0F\x77\xE4\x7B\x15\x84\xD5\x28\x98\x59\x09\xE0\x54\xD1\xAD\xB8\x48\x90\x82\x91\xB5\xA9\xC0\x00\x08\x74\x70\xB4\x2B\xAA\x35\x4B\x82\x00\xC0\xAA\x9A\xE2\xF0\x78\x4F\x3E\x57\x41\x58\x0D\x4C\xD1\x79\x00\xAE\x10\x7D\x90\x80\xAF\x63\x98\x79\xE9\x84\x55\x60\x00\x04\x3C\x7E\x78\x40\x12\x93\xCC\xCD\x9A\xFC\x0D\x53\x41\x58\x0D\x24\x34\x7C\xB9\x25\xF4\xA8\x72\x2B\x41\xCC\x52\x41\x3A\x53\x55\x38\x7A\xB0\x2F\x83\x3E\xFC\xFE\xA8\x6F\xB8\xC7\x73\x80\xB0\x1A\x48\xE4\x61\x00\x23\x21\x54\x90\xA2\x55\xE8\x43\x20\x08\x82\x3D\x78\x74\x28\x83\x3F\xFA\xE1\x58\x5E\x71\xAF\x42\x94\x2A\xE6\x48\x80\xB1\x20\xCE\x72\xC4\xD7\x29\x59\xC6\x80\x12\x0C\x82\x2B\x2B\x81\xF7\x56\x65\x70\x05\x5D\x0A\x82\x41\x68\x09\x9E\xA2\xD0\x40\x11\xCE\x7C\xCC\x3B\x82\xAA\x53\x51\xA7\x3A\x83\xB1\xE3\x96\xF9\x89\x21\x72\xF9\x34\x2D\xCF\xA2\xB0\x60\xF4\x6F\x61\xB8\x07\x1C\x6A\x0B\x0C\x4B\xF1\xB9\x43\x30\x40\x3A\x97\x94\x75\xBF\x0C\xA3\xC0\xA8\x15\xB8\xDA\x9A\x5E\xBD\x2C\x2B\x6E\x36\x97\x12\xFA\xF3\x9A\x0E\x06\xC8\xE4\xD6\x7A\x1D\xD0\x92\x57\xE7\xEF\x6E\x4F\x00\x40\x45\x96\x66\x58\x96\x54\xBB\x74\x62\xF6\x01\xF2\x5D\x80\xEA\x7A\xF7\x5F\x9E\x05\x54\xED\x2C\x78\xD7\xBA\x7D\x22\x97\xCF\x5C\x7C\x89\xAA\x00\x1C\x88\x03\xD4\x7A\x57\xCC\x3F\xEA\x00\x8C\xF3\x41\x5A\xA3\x6A\xBB\x1F\x05\x32\x04\x40\x93\x53\xA0\xFE\x3B\xEE\x82\xD2\x39\xF6\x18\x45\xEC\x31\xF4\x53\x82\xED\x14\xA8\xD7\xA0\x41\xB1\x71\x03\x64\xCB\x15\xD2\xE3\x97\xED\x1E\x40\x27\x95\x5D\xB5\xB5\x74\xB6\xC6\x46\xD7\xB9\xD1\x03\xC0\xEE\x88\x0B\x5A\x9E\x56\x45\x83\x9A\x5E\xB3\x67\x2A\x10\xFC\xA0\x3B\x8F\x6C\x60\xD4\x5E\xAF\xEA\x3D\x00\x75\x87\x35\xB0\xCB\x52\x00\x6C\x05\x0D\x20\xD4\xF4\x9C\xC1\xCF\xF2\xC8\x12\xE9\xEC\x9A\x7B\x2B\xC7\xB6\x9C\x5E\x3E\x49\xA6\x56\xFA\x00\xE7\xED\x37\xD1\xE2\xA9\x12\xDA\x00\x9C\x20\xC8\x81\x7E\xFE\x28\xFB\x4A\xB6\x55\x8A\x41\xCB\xF7\xF7\x78\x3C\xFE\xBA\x0D\x82\xB6\x5A\x9F\xC5\xE6\x23\x27\x4E\x00\x15\xA4\x3B\xAF\xE7\x03\x38\x41\x50\x27\xCE\x03\x60\xA3\x58\x2D\x3A\x8B\x68\x36\x08\x7A\x90\x48\x2C\xDE\xFC\xC7\x0D\x42\xCE\x67\x60\x38\x80\x0D\x84\x24\x87\xF4\x6E\xFE\x12\x8B\x0B\xA7\x14\x73\xC1\xA1\x84\xE7\x93\x70\x34\xD4\xBA\x2C\xC0\xB8\x20\xB4\xA9\xEE\x90\xFA\x5E\x1B\x04\xE6\x87\x92\xF2\xF1\xBD\xFB\x4B\xFF\xA9\x83\xD3\x99\xE4\xC4\x00\x4E\x10\x67\x9E\xDD\xBB\xBF\x2C\xFC\x21\xED\x37\xC3\x30\x5E\x1D\x58\x1D\xF4\xD1\x7B\x34\xE7\xBF\x86\x69\x3B\x7E\xFB\x4E\xE2\xDF\xF9\x1B\xD1\x13\x02\xFB\x1B\x2A\x4D\x0A\xC0\x46\xFB\xCF\x0F\x91\x84\xD1\xEB\x91\x16\xCE\x1A\x38\xF4\xD0\xF9\xE5\x31\x8E\x87\xAE\x75\x62\x7A\x7A\xFA\x35\x24\xA9\xA6\x7B\xBF\xA1\xB3\xC8\x4C\x38\x1C\x7E\xFB\xA2\x00\x0E\x9F\x5E\x1C\x76\xE8\xFA\x25\x2B\x30\xB4\x62\xBE\x68\xFB\x1F\xF7\x5C\xF7\xCB\x56\x46\x99\xC0\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82"


_logo ="\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x01\x00\x00\x00\x00\x3C\x08\x06\x00\x00\x00\x89\xBD\x64\x04\x00\x00\x00\x09\x70\x48\x59\x73\x00\x00\x2E\x23\x00\x00\x2E\x23\x01\x78\xA5\x3F\x76\x00\x00\x06\xB3\x69\x54\x58\x74\x58\x4D\x4C\x3A\x63\x6F\x6D\x2E\x61\x64\x6F\x62\x65\x2E\x78\x6D\x70\x00\x00\x00\x00\x00\x3C\x3F\x78\x70\x61\x63\x6B\x65\x74\x20\x62\x65\x67\x69\x6E\x3D\x22\xEF\xBB\xBF\x22\x20\x69\x64\x3D\x22\x57\x35\x4D\x30\x4D\x70\x43\x65\x68\x69\x48\x7A\x72\x65\x53\x7A\x4E\x54\x63\x7A\x6B\x63\x39\x64\x22\x3F\x3E\x20\x3C\x78\x3A\x78\x6D\x70\x6D\x65\x74\x61\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x3D\x22\x61\x64\x6F\x62\x65\x3A\x6E\x73\x3A\x6D\x65\x74\x61\x2F\x22\x20\x78\x3A\x78\x6D\x70\x74\x6B\x3D\x22\x41\x64\x6F\x62\x65\x20\x58\x4D\x50\x20\x43\x6F\x72\x65\x20\x36\x2E\x30\x2D\x63\x30\x30\x36\x20\x37\x39\x2E\x64\x61\x62\x61\x63\x62\x62\x2C\x20\x32\x30\x32\x31\x2F\x30\x34\x2F\x31\x34\x2D\x30\x30\x3A\x33\x39\x3A\x34\x34\x20\x20\x20\x20\x20\x20\x20\x20\x22\x3E\x20\x3C\x72\x64\x66\x3A\x52\x44\x46\x20\x78\x6D\x6C\x6E\x73\x3A\x72\x64\x66\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x77\x77\x77\x2E\x77\x33\x2E\x6F\x72\x67\x2F\x31\x39\x39\x39\x2F\x30\x32\x2F\x32\x32\x2D\x72\x64\x66\x2D\x73\x79\x6E\x74\x61\x78\x2D\x6E\x73\x23\x22\x3E\x20\x3C\x72\x64\x66\x3A\x44\x65\x73\x63\x72\x69\x70\x74\x69\x6F\x6E\x20\x72\x64\x66\x3A\x61\x62\x6F\x75\x74\x3D\x22\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x6D\x70\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x6D\x70\x4D\x4D\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x6D\x6D\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x73\x74\x45\x76\x74\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x73\x54\x79\x70\x65\x2F\x52\x65\x73\x6F\x75\x72\x63\x65\x45\x76\x65\x6E\x74\x23\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x2F\x31\x2E\x30\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x64\x63\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x70\x75\x72\x6C\x2E\x6F\x72\x67\x2F\x64\x63\x2F\x65\x6C\x65\x6D\x65\x6E\x74\x73\x2F\x31\x2E\x31\x2F\x22\x20\x78\x6D\x70\x3A\x43\x72\x65\x61\x74\x6F\x72\x54\x6F\x6F\x6C\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x32\x32\x2E\x34\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x20\x78\x6D\x70\x3A\x43\x72\x65\x61\x74\x65\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x3A\x4D\x65\x74\x61\x64\x61\x74\x61\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x3A\x4D\x6F\x64\x69\x66\x79\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x49\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x61\x65\x32\x36\x64\x34\x34\x38\x2D\x34\x34\x34\x32\x2D\x30\x62\x34\x37\x2D\x38\x65\x36\x35\x2D\x62\x31\x35\x65\x63\x38\x37\x38\x64\x66\x36\x35\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x44\x6F\x63\x75\x6D\x65\x6E\x74\x49\x44\x3D\x22\x61\x64\x6F\x62\x65\x3A\x64\x6F\x63\x69\x64\x3A\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x38\x66\x39\x34\x31\x37\x31\x66\x2D\x37\x61\x37\x37\x2D\x37\x66\x34\x37\x2D\x38\x62\x37\x65\x2D\x31\x66\x65\x62\x32\x61\x31\x37\x38\x62\x37\x34\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x4F\x72\x69\x67\x69\x6E\x61\x6C\x44\x6F\x63\x75\x6D\x65\x6E\x74\x49\x44\x3D\x22\x78\x6D\x70\x2E\x64\x69\x64\x3A\x30\x37\x37\x35\x65\x36\x39\x36\x2D\x39\x64\x63\x37\x2D\x61\x66\x34\x33\x2D\x38\x34\x33\x63\x2D\x65\x38\x37\x38\x33\x64\x36\x62\x36\x61\x31\x39\x22\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x43\x6F\x6C\x6F\x72\x4D\x6F\x64\x65\x3D\x22\x33\x22\x20\x64\x63\x3A\x66\x6F\x72\x6D\x61\x74\x3D\x22\x69\x6D\x61\x67\x65\x2F\x70\x6E\x67\x22\x3E\x20\x3C\x78\x6D\x70\x4D\x4D\x3A\x48\x69\x73\x74\x6F\x72\x79\x3E\x20\x3C\x72\x64\x66\x3A\x53\x65\x71\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x73\x74\x45\x76\x74\x3A\x61\x63\x74\x69\x6F\x6E\x3D\x22\x63\x72\x65\x61\x74\x65\x64\x22\x20\x73\x74\x45\x76\x74\x3A\x69\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x30\x37\x37\x35\x65\x36\x39\x36\x2D\x39\x64\x63\x37\x2D\x61\x66\x34\x33\x2D\x38\x34\x33\x63\x2D\x65\x38\x37\x38\x33\x64\x36\x62\x36\x61\x31\x39\x22\x20\x73\x74\x45\x76\x74\x3A\x77\x68\x65\x6E\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x73\x74\x45\x76\x74\x3A\x73\x6F\x66\x74\x77\x61\x72\x65\x41\x67\x65\x6E\x74\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x32\x32\x2E\x34\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x2F\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x73\x74\x45\x76\x74\x3A\x61\x63\x74\x69\x6F\x6E\x3D\x22\x73\x61\x76\x65\x64\x22\x20\x73\x74\x45\x76\x74\x3A\x69\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x61\x65\x32\x36\x64\x34\x34\x38\x2D\x34\x34\x34\x32\x2D\x30\x62\x34\x37\x2D\x38\x65\x36\x35\x2D\x62\x31\x35\x65\x63\x38\x37\x38\x64\x66\x36\x35\x22\x20\x73\x74\x45\x76\x74\x3A\x77\x68\x65\x6E\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x73\x74\x45\x76\x74\x3A\x73\x6F\x66\x74\x77\x61\x72\x65\x41\x67\x65\x6E\x74\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x32\x32\x2E\x34\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x20\x73\x74\x45\x76\x74\x3A\x63\x68\x61\x6E\x67\x65\x64\x3D\x22\x2F\x22\x2F\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x53\x65\x71\x3E\x20\x3C\x2F\x78\x6D\x70\x4D\x4D\x3A\x48\x69\x73\x74\x6F\x72\x79\x3E\x20\x3C\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x54\x65\x78\x74\x4C\x61\x79\x65\x72\x73\x3E\x20\x3C\x72\x64\x66\x3A\x42\x61\x67\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x4C\x61\x79\x65\x72\x4E\x61\x6D\x65\x3D\x22\x4E\x6F\x20\x4E\x61\x6D\x65\x20\x41\x6E\x69\x6D\x48\x55\x44\x22\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x4C\x61\x79\x65\x72\x54\x65\x78\x74\x3D\x22\x4E\x6F\x20\x4E\x61\x6D\x65\x20\x41\x6E\x69\x6D\x48\x55\x44\x22\x2F\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x4C\x61\x79\x65\x72\x4E\x61\x6D\x65\x3D\x22\x64\x6D\x69\x74\x72\x69\x79\x65\x77\x69\x63\x68\x22\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x4C\x61\x79\x65\x72\x54\x65\x78\x74\x3D\x22\x64\x6D\x69\x74\x72\x69\x79\x65\x77\x69\x63\x68\x22\x2F\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x42\x61\x67\x3E\x20\x3C\x2F\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x54\x65\x78\x74\x4C\x61\x79\x65\x72\x73\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x44\x65\x73\x63\x72\x69\x70\x74\x69\x6F\x6E\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x52\x44\x46\x3E\x20\x3C\x2F\x78\x3A\x78\x6D\x70\x6D\x65\x74\x61\x3E\x20\x3C\x3F\x78\x70\x61\x63\x6B\x65\x74\x20\x65\x6E\x64\x3D\x22\x72\x22\x3F\x3E\xD0\x6C\x53\x7B\x00\x00\x06\x7E\x49\x44\x41\x54\x78\xDA\xED\x9D\x8B\x75\xA3\x3A\x10\x86\x71\x4E\x1A\xA0\x05\x5A\x60\x4B\xC0\x25\x78\x4B\x70\x0B\x4E\x09\x76\x09\x37\x25\xC4\x25\x98\x12\x42\x0B\x6E\x81\x12\xB8\x90\x95\xB2\x5A\x45\x08\x3D\x86\x41\xB2\xFF\xEF\x1C\x9F\x38\x01\x29\x9A\x61\x66\x34\x7A\x00\xBB\x61\x18\x0A\x00\xC0\x73\xF2\x02\x15\x00\x80\x00\x00\x00\x40\x00\x00\x00\x20\x00\x00\x00\x10\x00\x00\x00\x08\x00\x00\x00\x04\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x80\x00\x00\x00\x40\x00\x00\x00\x20\x00\x00\x00\x10\x00\x00\x00\x79\xF0\x6A\xF8\xDB\x79\xFC\xD4\x86\xBF\x5F\x76\xBB\x5D\x3B\x7D\x19\x86\xE1\x38\xFE\x38\x98\x2A\x1C\xCF\xD9\xAB\xBF\x8F\xE7\x9E\x44\x7D\xA5\x43\x7B\xFA\xF1\xD3\x8D\x75\x5C\x5C\x1A\x3F\xD6\x4D\xDA\x56\xAD\xEE\x8F\xB9\x36\x2F\x94\x9B\x6B\xD3\xC4\xEF\xB1\x6C\x6F\x28\x53\x8D\x3F\xFE\x9B\x29\x33\xE9\xE3\xCD\xA1\x6E\x13\xAD\xAB\x2E\x29\x64\xA7\xBC\x26\x96\x7A\xAE\xE3\x39\xEF\x1B\xEA\xFA\xFB\x1C\xD7\xF3\x98\xEA\x72\xB6\x85\x7F\xEE\x00\x9E\x7E\xD1\x3E\xB7\xC1\xCC\x59\x75\xEA\x99\x73\x06\x4D\xD9\x9F\x43\x18\x9F\x8E\x86\x4A\xD6\x56\xAD\xDE\x72\xA1\x7D\x75\x40\x9B\x26\x0E\x33\x65\x8E\x96\x32\x37\xC7\xBA\xAD\x65\x3D\x9C\x3F\x58\x76\xCA\x6B\x62\xA9\xE7\xB4\xB1\xAE\x6F\x8E\xF2\x72\xD7\xE5\xC2\x87\xEE\xF3\x3E\x43\x80\xC6\xD3\x90\x4E\x81\x91\x6A\xA2\x56\x2F\x74\x00\x4D\x11\x47\x1D\x79\xDC\xB7\x5C\x5D\xAC\x43\x93\x90\xEC\x4D\xC1\x0B\xB7\xAE\x73\xE0\xA0\x07\xF0\x17\x4F\xA7\x2C\x09\x0D\x69\xCD\xF2\xBE\x6D\xF5\xFD\xDF\x25\xB1\x13\xAC\xE6\x1C\x4B\x3D\x36\xA3\xEC\xB1\xD7\x24\x79\x5D\x67\x42\x13\x33\x09\xE8\xA3\xBC\xD8\x8B\x5D\xAE\x64\x00\x14\xFF\xBB\x89\x70\x82\xCA\x30\x26\xAD\x56\xBC\xE0\x55\x22\xB2\x73\x3B\xDF\x16\xBA\xCE\x0E\xDF\x00\x40\x95\x3E\xB5\xCA\x87\x3B\x05\xA4\x28\x5B\x11\x3A\xC1\xDA\x4E\x51\x25\x24\x3B\x77\xFA\xCD\xAD\xEB\x2D\xB9\x87\xF8\xD5\xAB\xEF\x18\x62\xFC\xBC\xC5\x3A\xBF\x3A\x93\x2C\x26\x38\xD6\xB8\x30\x31\x6D\x5D\x6A\x4F\x35\xA5\xB3\xA6\x59\xE6\x00\x27\xA0\x90\xBD\xB3\xC8\xDA\x27\x24\x3B\x85\xFD\x6C\xAD\xEB\x54\x79\x57\x57\x7C\x5C\xFD\xCA\x37\x00\x54\x7A\x5A\x95\x30\x41\x6D\xF5\x28\x53\x07\x66\x30\x6B\xF4\x4A\xBD\x5C\x62\x8B\x9C\x2F\x58\x5B\x76\x6E\xFB\x79\xA6\x0C\x80\x65\x08\x90\x9B\x12\xD7\x98\x05\x8F\x4D\x67\xBF\x9D\x40\x4C\xD0\x95\x09\xE9\x6B\x6D\xD9\xB9\xED\x27\x65\x5D\x67\x1B\x00\x72\x5A\x46\x09\x69\x6B\x45\x7C\x9E\xCD\x09\x52\x0B\xA6\x1C\xB2\x6F\x35\x0F\x80\xDE\x1F\x19\x00\xA9\x81\x52\x04\x80\xD4\x82\x29\xA7\xEC\xDC\x36\x50\xC3\xDD\x69\x02\x40\x4E\x4B\x29\x21\x6D\xAD\x19\x0C\x39\xD5\x5E\x89\x43\x76\x6E\xFB\x41\x06\x40\x1C\x00\x1E\x3D\x0B\x30\x19\xA7\x71\xC2\x2B\x60\x93\x8D\xA4\x14\x3B\x1D\x53\x1B\x93\x72\xC8\xCE\x6D\x3F\xA9\xEA\x3A\x09\x5E\x09\x0D\x25\xE5\x2C\xC0\x89\xD1\x50\xE6\x0C\xB3\x9B\x31\xDA\x4A\x1C\x0B\xE1\x44\x6C\xE4\x3F\xDA\xE7\xB3\x32\xC0\x2C\x3B\xB7\xFD\xAC\xA9\xEB\xF2\x19\x03\xC0\xA3\x32\xD7\xAB\xB5\x33\x46\x14\x63\xC8\x25\x71\xBB\x4D\x37\xFE\xEC\x12\x95\x9D\x1B\x0E\x5D\x3F\xD5\x10\xE0\x51\x29\x2D\xBD\x60\xEE\x43\x21\xC8\x0E\x10\x00\x42\x7A\x41\xB1\xEB\xAD\xCD\xBC\x17\x84\xEC\x00\x01\x60\x81\x66\x26\x05\x9E\x1D\xCB\x7A\xDC\xE1\x76\x8F\x3C\x9E\xB3\xEC\xDC\xA4\xAE\x6B\x04\x80\xD4\x70\xD8\xA2\xDA\x7A\x8E\x9D\x75\xAE\x91\xC7\x73\x96\x9D\x9B\x64\x75\x9D\x73\x00\xE8\x32\x92\x2B\xA4\xAD\x95\xA7\xF1\xFB\x3A\x41\x6F\x31\xBC\x6B\xE1\x7F\xD3\x8E\x2E\xEF\xDE\xF0\x49\x45\x76\x6E\xFB\xE1\xD4\x75\x97\x73\x00\xF0\x59\x05\x68\x8B\x7C\x76\x53\x85\xB4\xB5\x0E\x34\xE0\xCA\xB3\x5D\x87\x99\xBF\xC7\xA4\xD3\xB1\x37\x03\x71\xC9\x5E\x33\xDB\xC0\xEA\xBA\x1E\xB3\xA7\x3E\xE7\x00\xF0\xE2\xA9\xD0\x22\xA3\x00\x40\xE5\x04\x9D\xD2\xAB\x50\x38\x41\x8A\x29\xE9\x96\xB2\x73\xDB\x00\xD2\xFF\x90\x00\x40\x71\xBB\x29\x17\x81\x6D\xAD\x2C\xE9\xE4\x54\x67\xF4\x72\xD8\x58\xC7\xDD\xD0\x9B\x76\x81\xF7\xD6\x53\xC2\x21\x7B\xCB\x6C\x03\xA9\xEA\x3A\xDB\x0C\xE0\xD1\xB3\x80\xB9\x5E\xF0\xD3\xE1\x29\xC2\x3E\x3D\xE1\x35\xC1\x1E\x89\x4B\x76\x6E\xFB\x49\x51\xD7\x08\x00\xA9\x05\x00\xCB\x36\x58\xAA\x31\x74\xB2\x46\xC9\x2C\x3B\x02\x00\x02\x40\x92\x19\x40\xEC\xA6\x16\xE7\xF2\x22\x35\xBD\x2B\x29\xE9\xD6\x6B\xD2\x15\x63\xF9\x2D\x86\x01\x29\xE9\x3A\x39\x5E\x3D\x15\xDA\x89\x59\xCF\xA8\x47\x6E\x6B\xCF\xFC\xAF\x57\xBA\xF8\x3E\x6D\x8D\x75\x02\x5F\x19\xA6\x9E\xE8\x44\xD8\x23\x35\x96\x34\x7D\x7A\x43\xCE\x35\x05\xD9\x89\xEC\xA7\xD8\x58\xD7\xA4\x43\x2F\x42\x5F\x68\x34\x13\xA8\xC9\x03\x80\x12\xC5\x0F\x11\x0D\x9D\x2E\xFE\x99\x31\x0B\x38\xAC\xE0\xC0\x54\x01\x80\xA3\x47\xEC\x12\x93\x3D\xD6\x7E\x8A\x84\x75\xBD\xA5\x2F\x34\x45\xC0\xFD\x19\x2F\x2B\x18\x94\x24\x76\xB6\xB5\x67\x30\xFE\x25\x23\x9E\x7A\xCF\x6F\x8A\xF9\xCD\x35\x5E\xBD\xA8\x98\x55\x6F\x2D\xB3\xEB\x54\xF4\x0E\x69\x2F\xAB\xEC\x05\xF3\xC6\x19\x46\x5D\xA7\xEE\x0B\x64\x01\xA0\x65\xBA\xD0\x14\x17\x6C\xB1\xAD\x62\x16\xBB\x74\x51\xBC\x6D\x29\x2B\x60\x32\xED\xC2\x60\x78\x5D\x82\xB2\x6F\xD1\x13\x5F\x8A\x6D\x49\xC1\x17\x8C\xFA\xF7\x0E\x00\x22\x92\xBA\x4C\xA6\xBC\x47\x34\xBC\x13\xE5\x29\xA2\xFF\x52\x5B\x2B\x4B\xF9\xD6\x23\x1A\xD7\x9E\x6D\x4B\x21\xFD\x67\x97\xDD\xC3\x7E\x28\xB3\x80\xAD\xD3\xFF\xF7\x08\x99\xEF\x14\xBE\x20\x87\x43\x7A\x26\xF4\x42\x11\x45\x66\x94\xDE\x8B\xB4\xD1\x47\x78\x29\xEC\x9E\x70\xC3\x46\xE8\x7E\xF6\xDE\xD3\xA9\x52\xBC\x33\xEE\x9E\xA8\xEC\x39\xAD\x26\x51\x04\xA0\x49\x9F\xBF\x02\x7D\xE1\x17\x81\x2F\x7C\xBD\x38\x66\xAC\xE7\xF7\x8F\xB6\x59\xF6\x78\x00\x00\x1E\x1C\xDC\x0E\x0C\x00\x02\x00\x00\xA0\xF8\xF3\xAC\xBF\x41\xF9\x4C\x4B\x74\x8D\xF8\x2E\x9F\x03\x78\x16\xBF\x9F\x94\xF3\x2B\xAD\xDC\x71\xA1\xAE\x93\xAC\xF3\xCF\x02\xCB\x6C\x3D\xD3\x79\x9F\xD3\x77\xE5\xBC\x0F\x31\x74\x1B\xC4\x77\x59\xB6\x90\xE7\x1A\xDA\x57\x68\x32\x20\x00\x00\x60\x41\xBE\xC0\x54\x9D\x23\xB1\xBD\x5F\x40\x7D\x42\xF2\x34\x76\x2F\x17\xEA\x92\xE7\xD5\xCA\xB1\xBB\xB2\x64\xAB\x3E\x86\xED\xAB\x5E\xF1\x18\x76\xF9\x7A\xB3\x52\x3D\xA6\x50\x6B\x65\x91\x01\x00\x10\xC0\xDC\xB2\xE1\xD1\xE0\xC8\x72\x95\x41\x3A\xFA\x3F\x6F\xE9\x55\xBF\x6B\x4C\x1B\x94\xA6\x47\x8C\x1F\x84\x43\xAB\x3B\x15\xA7\x6D\xCB\x7B\x51\x56\x06\x05\xE9\xF8\x4D\xF1\x77\xF5\xC6\x34\x39\x28\x1F\x58\x72\x41\x00\x00\x80\x96\x23\x61\x5D\xB2\xF7\x3E\x18\x7A\xF3\xAF\x77\x0F\x88\x67\x2E\xDE\x0D\x99\x47\xA5\x64\x11\x2E\x34\x08\x00\x00\xC4\xE3\xBD\x6D\xDA\xB2\x49\xAA\xD5\x02\x40\xAB\xFD\x9F\x9B\x1C\x1A\x28\x4E\xDC\xAB\x0E\xED\xB1\xBF\xE1\x86\x00\x00\x00\x4D\x8F\xED\xBB\xB9\xCD\xE8\x7C\x62\x6D\xBF\x53\x52\xFE\xDE\x90\xC6\x77\xCA\xC6\x9D\x5A\xFC\xFD\xAE\x05\x06\x17\xF6\x08\x00\x00\xC4\x21\x1F\x26\xEA\x7B\x57\xA1\xEC\xA5\xDF\x2C\xC7\xF4\x9E\xFC\xEB\xB9\x83\x4A\x50\x50\x83\xCF\xDD\x33\xFD\x37\xD5\x8F\x00\x00\x80\x85\xB9\x77\x09\x5E\x02\x32\x80\xD6\x32\x7C\xE8\xB5\x9F\xDF\x43\x80\x71\xE8\x70\x53\x6E\x15\x56\xCF\x6B\x17\x32\x11\x39\x7C\x70\x7A\x1F\x22\x02\x00\x00\x3F\x39\xCF\x38\x59\xC8\x9E\xFC\xAB\x36\xD6\x77\x41\xCE\xF6\xEB\x41\xA4\xB3\x04\x0D\x79\x5C\x2F\x6B\x05\x5B\x81\x01\x78\x62\x90\x01\x00\x80\x00\x00\x00\x78\x46\xFE\x07\xFA\x33\x42\x13\x95\x66\xBC\x9B\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82"

-- Licensed under the MIT License
-- Copyright (c) 2021, dmitriyewich <https://github.com/dmitriyewich/NoNameAnimHUD>
