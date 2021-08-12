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
script_version("0.1beta")


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

local lencoding, encoding = pcall(require, 'encoding')
assert(lencoding, 'Library \'encoding\' not found.')
encoding.default = 'CP1251'
u8 = encoding.UTF8
CP1251 = encoding.CP1251


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
    -- return (neatJSON(config, {wrap = 60, sort = true, short = true, padding =1}))
	return (neatJSON(config, { wrap = 40, short = true, sort = true, aligned = true, arrayPadding = 1, afterComma = 1, beforeColon1 = 1 }))

end

local config = {}

if doesFileExist("moonloader/NoNameAnimHUD/NoNameAnimHUD.json") then
    local f = io.open("moonloader/NoNameAnimHUD/NoNameAnimHUD.json")
    config = decodeJson(f:read("*a"))
    f:close()
else
	config = {
		["main"] = {
			["active"] = true,
			["widescreen"] = false,
			["standart_icons"] = false},
		["outline"] = {
			["frames"] = 125,
			["customX1"] = 0,
			["customY1"] = 0,
			["customX2"] = 0,
			["customY2"] = 0},
		["idle"] = {
			["frames"] = 53,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["chromegun"] = {
			["frames"] = 101,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["ak47"] = {
			["frames"] = 101,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["desert_eagle"] = {
			["frames"] = 101,
			["customX1"] = 3,
			["customY1"] = 3,
			["customX2"] = -2.5,
			["customY2"] = -3},
		["m4"] = {
			["frames"] = 101,
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
	
	style.PopupRounding = 3;
	style.WindowBorderSize = 1;
	style.ChildBorderSize  = 1;
	style.PopupBorderSize  = 1;
	style.FrameBorderSize  = 1;
	style.WindowTitleAlign = ImVec2(0.5, 0.5)
	style.ChildRounding     = 3;
	style.WindowPadding = ImVec2(15, 15)
	style.WindowRounding = 15.0
	style.FramePadding = ImVec2(5, 5)
	style.ItemSpacing = ImVec2(2, 8)
	style.ItemInnerSpacing = ImVec2(8, 6)
	style.IndentSpacing = 25.0
	style.ScrollbarSize = 8.0
	style.ScrollbarRounding = 15.0
	style.GrabMinSize = 15.0
	style.GrabRounding = 7.0
	style.FrameRounding = 6.0
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
	colors[clr.ScrollbarBg] = ImVec4(0.24, 0.24, 0.24, 0.53)
	colors[clr.ScrollbarGrab] = ImVec4(0.41, 0.41, 0.41, 1.00)
	colors[clr.ScrollbarGrabHovered] = ImVec4(0.52, 0.52, 0.52, 1.00)
	colors[clr.ScrollbarGrabActive] = ImVec4(0.76, 0.76, 0.76, 1.00)
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

local main_window, standart_icons, widescreen_active = new.bool(), new.bool(config.main.standart_icons), new.bool(config.main.widescreen)
local sizeX, sizeY = getScreenResolution()

local int_item = new.int(0)
local item_list = {'outline','idle', 'desert_eagle', 'm4', 'chromegun', 'ak47'}
local ImItems = new['const char*'][#item_list](item_list)

local offset_item = new.int(5)
local offset_list = {'0.1', '0.2', '0.3', '0.4', '0.5', '1.0', '2.0', '4.0', '6.0', '8.0'}
local offset_ImItems = new['const char*'][#offset_list](offset_list)

imgui.OnInitialize(function()
	Standart()
	
	logo = imgui.CreateTextureFromFileInMemory(_logo, #_logo)
	
    imgui.GetIO().IniFilename = nil
end)

local newFrame = imgui.OnFrame(
    function() return main_window[0] end,
    function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(247, 247), imgui.Cond.FirstUseEver, imgui.NoResize)
        imgui.Begin("##Main Window", main_window, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 220) / 2) 
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 17)
		imgui.Image(logo, imgui.ImVec2(220, 52))
		if imgui.IsItemHovered() then
			imgui.BeginTooltip()
			imgui.PushTextWrapPos(600)
			imgui.TextUnformatted("by dmitriyewich aka Valgard Dmitriyewich.\nРаспространение допускается только с указанием автора или ссылки на пост в вк/gthub\nПКМ - Открыть группу в вк")
			imgui.PopTextWrapPos()
			imgui.EndTooltip()
		end
		if imgui.IsItemClicked(1) then
			os.execute(('explorer.exe "%s"'):format('https://vk.com/dmitriyewichmods'))
		end
		---------------------------------------------------------
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 215) / 2) 
		imgui.PushItemWidth(215)
		imgui.Combo("##Combo1", int_item, ImItems, #item_list)
		imgui.PopItemWidth()
		imgui.PushItemWidth(74)
		
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 74) / 2) 
		imgui.Combo("##Combo2", offset_item, offset_ImItems, #offset_list)
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 10)
		imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize("Шаг смещения").x) / 2)
		imgui.Text('Шаг смещения')
		imgui.PopItemWidth()
		-- local comboitem =
		

		---------------------------------------------------------
		---------------------------------------------------------	
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 128) / 2)
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 7)
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
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 7)
		imgui.SetCursorPosX((imgui.GetWindowWidth() - (imgui.CalcTextSize("Шаг смещения").x + imgui.CalcTextSize("Сброс").x) - 2) / 2)
		if imgui.Button("Сохранить##1") then
			savejson(convertTableToJsonString(config), "moonloader/NoNameAnimHUD/NoNameAnimHUD.json")
		end
		imgui.SameLine()
		if imgui.Button("Сброс##1") then
			config[''..item_list[int_item[0] + 1]].customX1 = 0
			config[''..item_list[int_item[0] + 1]].customX2 = 0
			config[''..item_list[int_item[0] + 1]].customY1 = 0
			config[''..item_list[int_item[0] + 1]].customY2 = 0
		end

        if imgui.Checkbox('Включить стандартные иконки', standart_icons) then -- Кодируем название кнопки
            config.main.standart_icons = standart_icons[0]
        end
        if imgui.Checkbox('Режим широкого экрана', widescreen_active) then -- Кодируем название кнопки
            config.main.widescreen = widescreen_active[0]
        end

        imgui.End()
    end
)

function main()
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
	while not isSampAvailable() do wait(1000) end

	sampRegisterChatCommand('animhud', function() main_window[0] = not main_window[0] end)
	sampSetClientCommandDescription('animhud', (string.format(u8:decode'Активация/деактивация окна %s, Файл: %s', thisScript().name, thisScript().filename)))

	idle, outline, desert_eagle, m4, chromegun = {}, {}, {}, {}, {}
	i_idle, i_outline, i_desert_eagle, i_m4, i_chromegun  = 0, 0, 0, 0, 0

	lua_thread.create(function() -- отдельный поток для прогона кадров, если в обычный запихнуть, то будет мигать.
		while true do wait(50)
			i_idle, i_outline, i_desert_eagle, i_m4, i_chromegun  = i_idle + 1, i_outline + 1, i_desert_eagle + 1, i_m4 + 1, i_chromegun + 1
			if i_idle >= #idle then
				i_idle = 0
				if getCurrentCharWeapon(PLAYER_PED) == 0 then
					wait(5000)
				else
					goto continue
				end
			end
			if i_outline >= #outline then
				i_outline = 0
			end
			if i_desert_eagle >= #desert_eagle then
				i_desert_eagle = 0
				if getCurrentCharWeapon(PLAYER_PED) == 24 then
					wait(5000)
				else
					goto continue
				end
			end
			if i_m4 >= #m4 then
				i_m4 = 0
				if getCurrentCharWeapon(PLAYER_PED) == 31 then
					wait(5000)
				else
					goto continue
				end
			end
			if i_chromegun >= #chromegun then
				i_chromegun = 0
				if getCurrentCharWeapon(PLAYER_PED) == 25 then
					wait(5000)
				else
					goto continue
				end
			end
			::continue::
		end
    end)

---------------idle---------idle-----------------------
	if mad.get_txd('txd_idle') ~= nil then -- Проверяет наличие txd в памяти, костыль на случай перезапуска скрипта(ов)
		txd_idle = mad.get_txd('txd_idle')
	else
		txd_idle = mad.load_txd(getWorkingDirectory() .. '//NoNameAnimHUD//Anim//idle.txd', 'txd_idle')
	end

	while txd_idle == nil do wait(1000) end -- Так надо
	for i = 0, config.idle.frames - 1 do
		texture_from_txd_idle = txd_idle:get_texture(i)
		idle[i] = texture_from_txd_idle
	end
---------------idle----------idle-------------------------

---------------txd_outline----------txd_outline--------------
	if mad.get_txd('txd_outline') ~= nil then
		txd_outline = mad.get_txd('txd_outline')
	else
		txd_outline = mad.load_txd(getWorkingDirectory() .. '//NoNameAnimHUD//Anim//outline.txd', 'txd_outline')
	end

	while txd_outline == nil do wait(100) end
	for i = 0, config.outline.frames - 1 do
		texture_from_txd_outline = txd_outline:get_texture(i)
		outline[i] = texture_from_txd_outline
	end
	-- print(outline[0])
---------------txd_outline----------txd_outline---------------

---------------desert_eagle_anim----------desert_eagle_anim---------------
	if mad.get_txd('desert_eagle_anim') ~= nil then
		desert_eagle_anim = mad.get_txd('desert_eagle_anim')
	else
		desert_eagle_anim = mad.load_txd(getWorkingDirectory() .. '//NoNameAnimHUD//Anim//desert_eagle_anim.txd', 'desert_eagle_anim')
	end

	while desert_eagle_anim == nil do wait(100) end
	for i = 0, config.desert_eagle.frames - 1 do
		texture_from_txd_desert_eagle = desert_eagle_anim:get_texture(i)
		desert_eagle[i] = texture_from_txd_desert_eagle
	end

---------------desert_eagle_anim----------desert_eagle_anim---------------

---------------m4_anim----------m4_anim---------------
	if mad.get_txd('m4_anim') ~= nil then
		m4_anim = mad.get_txd('m4_anim')
	else
		m4_anim = mad.load_txd(getWorkingDirectory() .. '//NoNameAnimHUD//Anim//m4_anim.txd', 'm4_anim')
	end

	while m4_anim == nil do wait(100) end
	for i = 0, config.m4.frames - 1 do
		texture_from_txd_m4 = m4_anim:get_texture(i)
		m4[i] = texture_from_txd_m4
	end
---------------m4_anim----------m4_anim---------------

---------------chromegun_anim----------chromegun_anim---------------
	if mad.get_txd('chromegun_anim') ~= nil then
		chromegun_anim = mad.get_txd('chromegun_anim')
	else
		chromegun_anim = mad.load_txd(getWorkingDirectory() .. '//NoNameAnimHUD//Anim//chromegun_anim.txd', 'chromegun_anim')
	end

	while chromegun_anim == nil do wait(100) end
	for i = 0, config.chromegun.frames - 1 do
		texture_from_txd_chromegun = chromegun_anim:get_texture(i)
		chromegun[i] = texture_from_txd_chromegun
	end
---------------chromegun_anim----------chromegun_anim---------------

-- GetX_Icons()
-- print(fawfaf.x)

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

	while true do wait(0)

		-- renderDrawLine(convert_x(255.0), convert_y(0), convert_x(255), convert_y(448), 2.0, 0xFFD00000)

		-- display_texture(outline[i_outline], convert_x(200), convert_y(100), convert_x(400), convert_y(200))
	
		-------------------------------

		if not standart_icons[0] and (getCurrentCharWeapon(PLAYER_PED) == 0 or getCurrentCharWeapon(PLAYER_PED) == 24 or getCurrentCharWeapon(PLAYER_PED) == 31 or getCurrentCharWeapon(PLAYER_PED) == 25) then
			memory.write(0x58D7D0, 195, 1, true) -- Выключить иконки.
		else
			memory.write(0x58D7D0, 161, 1, true) -- Включить иконки.
		end

		if getCurrentCharWeapon(PLAYER_PED) == 0 then -- фист
			-- display_texture(idle[i_idle], convert_x(500), convert_y(25), convert_x(540), convert_y(62))
			display_texture(idle[i_idle], convert_x(GetX_Icons() + config.idle.customX1) , convert_y(GetY_Icons() + config.idle.customY1), convert_x((GetX_Icons() + width_icons().x) + config.idle.customX2), convert_y((GetY_Icons() + width_icons().y) + config.idle.customY2))
		end

		if getCurrentCharWeapon(PLAYER_PED) == 24 then -- дигл
			-- display_texture(desert_eagle[i_desert_eagle], convert_x(500), convert_y(25), convert_x(540), convert_y(62))
			display_texture(desert_eagle[i_desert_eagle], convert_x(GetX_Icons() + config.desert_eagle.customX1) , convert_y(GetY_Icons() + config.desert_eagle.customY1), convert_x((GetX_Icons() + width_icons().x) + config.desert_eagle.customX2), convert_y((GetY_Icons() + width_icons().y) + config.desert_eagle.customY2))
		end
		if getCurrentCharWeapon(PLAYER_PED) == 31 then -- м4
			-- display_texture(m4[i_m4], convert_x(500), convert_y(25), convert_x(540), convert_y(62))
			display_texture(m4[i_m4], convert_x(GetX_Icons() + config.m4.customX1) , convert_y(GetY_Icons() + config.m4.customY1), convert_x((GetX_Icons() + width_icons().x) + config.m4.customX2), convert_y((GetY_Icons() + width_icons().y) + config.m4.customY2))
		end

		if getCurrentCharWeapon(PLAYER_PED) == 25 then
			-- display_texture(chromegun[i_chromegun], convert_x(500), convert_y(25), convert_x(540), convert_y(62))
			display_texture(chromegun[i_chromegun], convert_x(GetX_Icons() + config.chromegun.customX1) , convert_y(GetY_Icons() + config.chromegun.customY1), convert_x((GetX_Icons() + width_icons().x) + config.chromegun.customX2), convert_y((GetY_Icons() + width_icons().y) + config.chromegun.customY2)) -- дробовик
		end

		if getCurrentCharWeapon(PLAYER_PED) == 0 or getCurrentCharWeapon(PLAYER_PED) == 24 or getCurrentCharWeapon(PLAYER_PED) == 31 or
		getCurrentCharWeapon(PLAYER_PED) == 25 then
			-- display_texture(outline[i_outline], convert_x(497.5), convert_y(22.5), convert_x(542.5), convert_y(64.5))
			display_texture(outline[i_outline], convert_x(GetX_Icons() + config.outline.customX1) , convert_y(GetY_Icons() + config.outline.customY1), convert_x((GetX_Icons() + width_icons().x) + config.outline.customX2), convert_y((GetY_Icons() + width_icons().y) + config.outline.customY2)) -- обводка
		end
		-- -------------------------------

		-- display_texture(idle[i_idle], convert_x(350), convert_y(100), convert_x(450), convert_y(200))
		-- display_texture(desert_eagle[i_desert_eagle], convert_x(480), convert_y(100), convert_x(580), convert_y(200))
		-- display_texture(outline[i_outline], convert_x(465), convert_y(225), convert_x(565), convert_y(325))

	end
end

function ConvertFistX(x) -- Как ни странно - переводит игровую X-координату под фист
	if config.main.widescreen then
		-- print("Available")
		local xcx = ((x / 849) * 849) - 529
		local xcx = float2hex(-xcx)
		return xcx
	elseif not config.main.widescreen then
		-- print("No Available")
		local xcx = ((x / 529) * 529) - 529
		local xcx = float2hex(-xcx)
		return xcx
	end

end

function GetX_Icons() -- получает игровую X-координату фиста
	local Fist_X = memory.getuint32(0x58F927, false) -- WeaponIconX
	local fX_Fist = memory.getfloat(Fist_X)

	if config.main.widescreen then
		-- print("Available")
		local xcx = ((fX_Fist / 849) * 849) - 576.5
		local xcx = math.round(-xcx, 2)
		return xcx
	elseif not config.main.widescreen then
		-- print("No Available")
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
		-- print("Available")
		local ycy = ((fY_Fist / 583) * 583) - 5
		local ycy = math.round(ycy, 2) -- округление, не обязательно
		return ycy
	elseif not config.main.widescreen then
		-- print("No Available")
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

-- print()

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


function display_texture(tex, x, y, x2, y2, r, g, b, a, angle)
	tex:draw(x, y, x2, y2, r, g, b, a, angle)
end

function convert_x(x)
	local gposX, gposY = convertGameScreenCoordsToWindowScreenCoords(x, x)
	return gposX
end

function convert_y(y)
	local gposX, gposY = convertGameScreenCoordsToWindowScreenCoords(y, y)
	return gposY
end

function onWindowMessage(msg, wparam, lparam) -- Hook "onWindowMessage"
    if msg == wm.WM_KEYDOWN and wparam == 0x1B and main_window[0] then
        main_window[0] = false -- Переменную отвечающая за рисование окна ставим в "false", чтобы окно перестало рисоваться
        consumeWindowMessage(true, false) -- Текущее оконное сообщение помечаем для игнорирования
    end
end

function onExitScript()
	-- freeMemory(memoryX)
	-- freeMemory(memoryY)
	memory.write(0x58D7D0, 161, 1, true) -- Включить иконки.
end


_logo ="\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x01\x00\x00\x00\x00\x3C\x08\x06\x00\x00\x00\x89\xBD\x64\x04\x00\x00\x00\x09\x70\x48\x59\x73\x00\x00\x2E\x23\x00\x00\x2E\x23\x01\x78\xA5\x3F\x76\x00\x00\x06\xB3\x69\x54\x58\x74\x58\x4D\x4C\x3A\x63\x6F\x6D\x2E\x61\x64\x6F\x62\x65\x2E\x78\x6D\x70\x00\x00\x00\x00\x00\x3C\x3F\x78\x70\x61\x63\x6B\x65\x74\x20\x62\x65\x67\x69\x6E\x3D\x22\xEF\xBB\xBF\x22\x20\x69\x64\x3D\x22\x57\x35\x4D\x30\x4D\x70\x43\x65\x68\x69\x48\x7A\x72\x65\x53\x7A\x4E\x54\x63\x7A\x6B\x63\x39\x64\x22\x3F\x3E\x20\x3C\x78\x3A\x78\x6D\x70\x6D\x65\x74\x61\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x3D\x22\x61\x64\x6F\x62\x65\x3A\x6E\x73\x3A\x6D\x65\x74\x61\x2F\x22\x20\x78\x3A\x78\x6D\x70\x74\x6B\x3D\x22\x41\x64\x6F\x62\x65\x20\x58\x4D\x50\x20\x43\x6F\x72\x65\x20\x36\x2E\x30\x2D\x63\x30\x30\x36\x20\x37\x39\x2E\x64\x61\x62\x61\x63\x62\x62\x2C\x20\x32\x30\x32\x31\x2F\x30\x34\x2F\x31\x34\x2D\x30\x30\x3A\x33\x39\x3A\x34\x34\x20\x20\x20\x20\x20\x20\x20\x20\x22\x3E\x20\x3C\x72\x64\x66\x3A\x52\x44\x46\x20\x78\x6D\x6C\x6E\x73\x3A\x72\x64\x66\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x77\x77\x77\x2E\x77\x33\x2E\x6F\x72\x67\x2F\x31\x39\x39\x39\x2F\x30\x32\x2F\x32\x32\x2D\x72\x64\x66\x2D\x73\x79\x6E\x74\x61\x78\x2D\x6E\x73\x23\x22\x3E\x20\x3C\x72\x64\x66\x3A\x44\x65\x73\x63\x72\x69\x70\x74\x69\x6F\x6E\x20\x72\x64\x66\x3A\x61\x62\x6F\x75\x74\x3D\x22\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x6D\x70\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x6D\x70\x4D\x4D\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x6D\x6D\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x73\x74\x45\x76\x74\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x73\x54\x79\x70\x65\x2F\x52\x65\x73\x6F\x75\x72\x63\x65\x45\x76\x65\x6E\x74\x23\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x2F\x31\x2E\x30\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x64\x63\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x70\x75\x72\x6C\x2E\x6F\x72\x67\x2F\x64\x63\x2F\x65\x6C\x65\x6D\x65\x6E\x74\x73\x2F\x31\x2E\x31\x2F\x22\x20\x78\x6D\x70\x3A\x43\x72\x65\x61\x74\x6F\x72\x54\x6F\x6F\x6C\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x32\x32\x2E\x34\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x20\x78\x6D\x70\x3A\x43\x72\x65\x61\x74\x65\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x3A\x4D\x65\x74\x61\x64\x61\x74\x61\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x3A\x4D\x6F\x64\x69\x66\x79\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x49\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x61\x65\x32\x36\x64\x34\x34\x38\x2D\x34\x34\x34\x32\x2D\x30\x62\x34\x37\x2D\x38\x65\x36\x35\x2D\x62\x31\x35\x65\x63\x38\x37\x38\x64\x66\x36\x35\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x44\x6F\x63\x75\x6D\x65\x6E\x74\x49\x44\x3D\x22\x61\x64\x6F\x62\x65\x3A\x64\x6F\x63\x69\x64\x3A\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x38\x66\x39\x34\x31\x37\x31\x66\x2D\x37\x61\x37\x37\x2D\x37\x66\x34\x37\x2D\x38\x62\x37\x65\x2D\x31\x66\x65\x62\x32\x61\x31\x37\x38\x62\x37\x34\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x4F\x72\x69\x67\x69\x6E\x61\x6C\x44\x6F\x63\x75\x6D\x65\x6E\x74\x49\x44\x3D\x22\x78\x6D\x70\x2E\x64\x69\x64\x3A\x30\x37\x37\x35\x65\x36\x39\x36\x2D\x39\x64\x63\x37\x2D\x61\x66\x34\x33\x2D\x38\x34\x33\x63\x2D\x65\x38\x37\x38\x33\x64\x36\x62\x36\x61\x31\x39\x22\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x43\x6F\x6C\x6F\x72\x4D\x6F\x64\x65\x3D\x22\x33\x22\x20\x64\x63\x3A\x66\x6F\x72\x6D\x61\x74\x3D\x22\x69\x6D\x61\x67\x65\x2F\x70\x6E\x67\x22\x3E\x20\x3C\x78\x6D\x70\x4D\x4D\x3A\x48\x69\x73\x74\x6F\x72\x79\x3E\x20\x3C\x72\x64\x66\x3A\x53\x65\x71\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x73\x74\x45\x76\x74\x3A\x61\x63\x74\x69\x6F\x6E\x3D\x22\x63\x72\x65\x61\x74\x65\x64\x22\x20\x73\x74\x45\x76\x74\x3A\x69\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x30\x37\x37\x35\x65\x36\x39\x36\x2D\x39\x64\x63\x37\x2D\x61\x66\x34\x33\x2D\x38\x34\x33\x63\x2D\x65\x38\x37\x38\x33\x64\x36\x62\x36\x61\x31\x39\x22\x20\x73\x74\x45\x76\x74\x3A\x77\x68\x65\x6E\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x73\x74\x45\x76\x74\x3A\x73\x6F\x66\x74\x77\x61\x72\x65\x41\x67\x65\x6E\x74\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x32\x32\x2E\x34\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x2F\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x73\x74\x45\x76\x74\x3A\x61\x63\x74\x69\x6F\x6E\x3D\x22\x73\x61\x76\x65\x64\x22\x20\x73\x74\x45\x76\x74\x3A\x69\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x61\x65\x32\x36\x64\x34\x34\x38\x2D\x34\x34\x34\x32\x2D\x30\x62\x34\x37\x2D\x38\x65\x36\x35\x2D\x62\x31\x35\x65\x63\x38\x37\x38\x64\x66\x36\x35\x22\x20\x73\x74\x45\x76\x74\x3A\x77\x68\x65\x6E\x3D\x22\x32\x30\x32\x31\x2D\x30\x38\x2D\x31\x32\x54\x31\x33\x3A\x33\x39\x3A\x32\x31\x2B\x30\x33\x3A\x30\x30\x22\x20\x73\x74\x45\x76\x74\x3A\x73\x6F\x66\x74\x77\x61\x72\x65\x41\x67\x65\x6E\x74\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x32\x32\x2E\x34\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x20\x73\x74\x45\x76\x74\x3A\x63\x68\x61\x6E\x67\x65\x64\x3D\x22\x2F\x22\x2F\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x53\x65\x71\x3E\x20\x3C\x2F\x78\x6D\x70\x4D\x4D\x3A\x48\x69\x73\x74\x6F\x72\x79\x3E\x20\x3C\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x54\x65\x78\x74\x4C\x61\x79\x65\x72\x73\x3E\x20\x3C\x72\x64\x66\x3A\x42\x61\x67\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x4C\x61\x79\x65\x72\x4E\x61\x6D\x65\x3D\x22\x4E\x6F\x20\x4E\x61\x6D\x65\x20\x41\x6E\x69\x6D\x48\x55\x44\x22\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x4C\x61\x79\x65\x72\x54\x65\x78\x74\x3D\x22\x4E\x6F\x20\x4E\x61\x6D\x65\x20\x41\x6E\x69\x6D\x48\x55\x44\x22\x2F\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x4C\x61\x79\x65\x72\x4E\x61\x6D\x65\x3D\x22\x64\x6D\x69\x74\x72\x69\x79\x65\x77\x69\x63\x68\x22\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x4C\x61\x79\x65\x72\x54\x65\x78\x74\x3D\x22\x64\x6D\x69\x74\x72\x69\x79\x65\x77\x69\x63\x68\x22\x2F\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x42\x61\x67\x3E\x20\x3C\x2F\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x54\x65\x78\x74\x4C\x61\x79\x65\x72\x73\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x44\x65\x73\x63\x72\x69\x70\x74\x69\x6F\x6E\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x52\x44\x46\x3E\x20\x3C\x2F\x78\x3A\x78\x6D\x70\x6D\x65\x74\x61\x3E\x20\x3C\x3F\x78\x70\x61\x63\x6B\x65\x74\x20\x65\x6E\x64\x3D\x22\x72\x22\x3F\x3E\xD0\x6C\x53\x7B\x00\x00\x06\x7E\x49\x44\x41\x54\x78\xDA\xED\x9D\x8B\x75\xA3\x3A\x10\x86\x71\x4E\x1A\xA0\x05\x5A\x60\x4B\xC0\x25\x78\x4B\x70\x0B\x4E\x09\x76\x09\x37\x25\xC4\x25\x98\x12\x42\x0B\x6E\x81\x12\xB8\x90\x95\xB2\x5A\x45\x08\x3D\x86\x41\xB2\xFF\xEF\x1C\x9F\x38\x01\x29\x9A\x61\x66\x34\x7A\x00\xBB\x61\x18\x0A\x00\xC0\x73\xF2\x02\x15\x00\x80\x00\x00\x00\x40\x00\x00\x00\x20\x00\x00\x00\x10\x00\x00\x00\x08\x00\x00\x00\x04\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x80\x00\x00\x00\x40\x00\x00\x00\x20\x00\x00\x00\x10\x00\x00\x00\x79\xF0\x6A\xF8\xDB\x79\xFC\xD4\x86\xBF\x5F\x76\xBB\x5D\x3B\x7D\x19\x86\xE1\x38\xFE\x38\x98\x2A\x1C\xCF\xD9\xAB\xBF\x8F\xE7\x9E\x44\x7D\xA5\x43\x7B\xFA\xF1\xD3\x8D\x75\x5C\x5C\x1A\x3F\xD6\x4D\xDA\x56\xAD\xEE\x8F\xB9\x36\x2F\x94\x9B\x6B\xD3\xC4\xEF\xB1\x6C\x6F\x28\x53\x8D\x3F\xFE\x9B\x29\x33\xE9\xE3\xCD\xA1\x6E\x13\xAD\xAB\x2E\x29\x64\xA7\xBC\x26\x96\x7A\xAE\xE3\x39\xEF\x1B\xEA\xFA\xFB\x1C\xD7\xF3\x98\xEA\x72\xB6\x85\x7F\xEE\x00\x9E\x7E\xD1\x3E\xB7\xC1\xCC\x59\x75\xEA\x99\x73\x06\x4D\xD9\x9F\x43\x18\x9F\x8E\x86\x4A\xD6\x56\xAD\xDE\x72\xA1\x7D\x75\x40\x9B\x26\x0E\x33\x65\x8E\x96\x32\x37\xC7\xBA\xAD\x65\x3D\x9C\x3F\x58\x76\xCA\x6B\x62\xA9\xE7\xB4\xB1\xAE\x6F\x8E\xF2\x72\xD7\xE5\xC2\x87\xEE\xF3\x3E\x43\x80\xC6\xD3\x90\x4E\x81\x91\x6A\xA2\x56\x2F\x74\x00\x4D\x11\x47\x1D\x79\xDC\xB7\x5C\x5D\xAC\x43\x93\x90\xEC\x4D\xC1\x0B\xB7\xAE\x73\xE0\xA0\x07\xF0\x17\x4F\xA7\x2C\x09\x0D\x69\xCD\xF2\xBE\x6D\xF5\xFD\xDF\x25\xB1\x13\xAC\xE6\x1C\x4B\x3D\x36\xA3\xEC\xB1\xD7\x24\x79\x5D\x67\x42\x13\x33\x09\xE8\xA3\xBC\xD8\x8B\x5D\xAE\x64\x00\x14\xFF\xBB\x89\x70\x82\xCA\x30\x26\xAD\x56\xBC\xE0\x55\x22\xB2\x73\x3B\xDF\x16\xBA\xCE\x0E\xDF\x00\x40\x95\x3E\xB5\xCA\x87\x3B\x05\xA4\x28\x5B\x11\x3A\xC1\xDA\x4E\x51\x25\x24\x3B\x77\xFA\xCD\xAD\xEB\x2D\xB9\x87\xF8\xD5\xAB\xEF\x18\x62\xFC\xBC\xC5\x3A\xBF\x3A\x93\x2C\x26\x38\xD6\xB8\x30\x31\x6D\x5D\x6A\x4F\x35\xA5\xB3\xA6\x59\xE6\x00\x27\xA0\x90\xBD\xB3\xC8\xDA\x27\x24\x3B\x85\xFD\x6C\xAD\xEB\x54\x79\x57\x57\x7C\x5C\xFD\xCA\x37\x00\x54\x7A\x5A\x95\x30\x41\x6D\xF5\x28\x53\x07\x66\x30\x6B\xF4\x4A\xBD\x5C\x62\x8B\x9C\x2F\x58\x5B\x76\x6E\xFB\x79\xA6\x0C\x80\x65\x08\x90\x9B\x12\xD7\x98\x05\x8F\x4D\x67\xBF\x9D\x40\x4C\xD0\x95\x09\xE9\x6B\x6D\xD9\xB9\xED\x27\x65\x5D\x67\x1B\x00\x72\x5A\x46\x09\x69\x6B\x45\x7C\x9E\xCD\x09\x52\x0B\xA6\x1C\xB2\x6F\x35\x0F\x80\xDE\x1F\x19\x00\xA9\x81\x52\x04\x80\xD4\x82\x29\xA7\xEC\xDC\x36\x50\xC3\xDD\x69\x02\x40\x4E\x4B\x29\x21\x6D\xAD\x19\x0C\x39\xD5\x5E\x89\x43\x76\x6E\xFB\x41\x06\x40\x1C\x00\x1E\x3D\x0B\x30\x19\xA7\x71\xC2\x2B\x60\x93\x8D\xA4\x14\x3B\x1D\x53\x1B\x93\x72\xC8\xCE\x6D\x3F\xA9\xEA\x3A\x09\x5E\x09\x0D\x25\xE5\x2C\xC0\x89\xD1\x50\xE6\x0C\xB3\x9B\x31\xDA\x4A\x1C\x0B\xE1\x44\x6C\xE4\x3F\xDA\xE7\xB3\x32\xC0\x2C\x3B\xB7\xFD\xAC\xA9\xEB\xF2\x19\x03\xC0\xA3\x32\xD7\xAB\xB5\x33\x46\x14\x63\xC8\x25\x71\xBB\x4D\x37\xFE\xEC\x12\x95\x9D\x1B\x0E\x5D\x3F\xD5\x10\xE0\x51\x29\x2D\xBD\x60\xEE\x43\x21\xC8\x0E\x10\x00\x42\x7A\x41\xB1\xEB\xAD\xCD\xBC\x17\x84\xEC\x00\x01\x60\x81\x66\x26\x05\x9E\x1D\xCB\x7A\xDC\xE1\x76\x8F\x3C\x9E\xB3\xEC\xDC\xA4\xAE\x6B\x04\x80\xD4\x70\xD8\xA2\xDA\x7A\x8E\x9D\x75\xAE\x91\xC7\x73\x96\x9D\x9B\x64\x75\x9D\x73\x00\xE8\x32\x92\x2B\xA4\xAD\x95\xA7\xF1\xFB\x3A\x41\x6F\x31\xBC\x6B\xE1\x7F\xD3\x8E\x2E\xEF\xDE\xF0\x49\x45\x76\x6E\xFB\xE1\xD4\x75\x97\x73\x00\xF0\x59\x05\x68\x8B\x7C\x76\x53\x85\xB4\xB5\x0E\x34\xE0\xCA\xB3\x5D\x87\x99\xBF\xC7\xA4\xD3\xB1\x37\x03\x71\xC9\x5E\x33\xDB\xC0\xEA\xBA\x1E\xB3\xA7\x3E\xE7\x00\xF0\xE2\xA9\xD0\x22\xA3\x00\x40\xE5\x04\x9D\xD2\xAB\x50\x38\x41\x8A\x29\xE9\x96\xB2\x73\xDB\x00\xD2\xFF\x90\x00\x40\x71\xBB\x29\x17\x81\x6D\xAD\x2C\xE9\xE4\x54\x67\xF4\x72\xD8\x58\xC7\xDD\xD0\x9B\x76\x81\xF7\xD6\x53\xC2\x21\x7B\xCB\x6C\x03\xA9\xEA\x3A\xDB\x0C\xE0\xD1\xB3\x80\xB9\x5E\xF0\xD3\xE1\x29\xC2\x3E\x3D\xE1\x35\xC1\x1E\x89\x4B\x76\x6E\xFB\x49\x51\xD7\x08\x00\xA9\x05\x00\xCB\x36\x58\xAA\x31\x74\xB2\x46\xC9\x2C\x3B\x02\x00\x02\x40\x92\x19\x40\xEC\xA6\x16\xE7\xF2\x22\x35\xBD\x2B\x29\xE9\xD6\x6B\xD2\x15\x63\xF9\x2D\x86\x01\x29\xE9\x3A\x39\x5E\x3D\x15\xDA\x89\x59\xCF\xA8\x47\x6E\x6B\xCF\xFC\xAF\x57\xBA\xF8\x3E\x6D\x8D\x75\x02\x5F\x19\xA6\x9E\xE8\x44\xD8\x23\x35\x96\x34\x7D\x7A\x43\xCE\x35\x05\xD9\x89\xEC\xA7\xD8\x58\xD7\xA4\x43\x2F\x42\x5F\x68\x34\x13\xA8\xC9\x03\x80\x12\xC5\x0F\x11\x0D\x9D\x2E\xFE\x99\x31\x0B\x38\xAC\xE0\xC0\x54\x01\x80\xA3\x47\xEC\x12\x93\x3D\xD6\x7E\x8A\x84\x75\xBD\xA5\x2F\x34\x45\xC0\xFD\x19\x2F\x2B\x18\x94\x24\x76\xB6\xB5\x67\x30\xFE\x25\x23\x9E\x7A\xCF\x6F\x8A\xF9\xCD\x35\x5E\xBD\xA8\x98\x55\x6F\x2D\xB3\xEB\x54\xF4\x0E\x69\x2F\xAB\xEC\x05\xF3\xC6\x19\x46\x5D\xA7\xEE\x0B\x64\x01\xA0\x65\xBA\xD0\x14\x17\x6C\xB1\xAD\x62\x16\xBB\x74\x51\xBC\x6D\x29\x2B\x60\x32\xED\xC2\x60\x78\x5D\x82\xB2\x6F\xD1\x13\x5F\x8A\x6D\x49\xC1\x17\x8C\xFA\xF7\x0E\x00\x22\x92\xBA\x4C\xA6\xBC\x47\x34\xBC\x13\xE5\x29\xA2\xFF\x52\x5B\x2B\x4B\xF9\xD6\x23\x1A\xD7\x9E\x6D\x4B\x21\xFD\x67\x97\xDD\xC3\x7E\x28\xB3\x80\xAD\xD3\xFF\xF7\x08\x99\xEF\x14\xBE\x20\x87\x43\x7A\x26\xF4\x42\x11\x45\x66\x94\xDE\x8B\xB4\xD1\x47\x78\x29\xEC\x9E\x70\xC3\x46\xE8\x7E\xF6\xDE\xD3\xA9\x52\xBC\x33\xEE\x9E\xA8\xEC\x39\xAD\x26\x51\x04\xA0\x49\x9F\xBF\x02\x7D\xE1\x17\x81\x2F\x7C\xBD\x38\x66\xAC\xE7\xF7\x8F\xB6\x59\xF6\x78\x00\x00\x1E\x1C\xDC\x0E\x0C\x00\x02\x00\x00\xA0\xF8\xF3\xAC\xBF\x41\xF9\x4C\x4B\x74\x8D\xF8\x2E\x9F\x03\x78\x16\xBF\x9F\x94\xF3\x2B\xAD\xDC\x71\xA1\xAE\x93\xAC\xF3\xCF\x02\xCB\x6C\x3D\xD3\x79\x9F\xD3\x77\xE5\xBC\x0F\x31\x74\x1B\xC4\x77\x59\xB6\x90\xE7\x1A\xDA\x57\x68\x32\x20\x00\x00\x60\x41\xBE\xC0\x54\x9D\x23\xB1\xBD\x5F\x40\x7D\x42\xF2\x34\x76\x2F\x17\xEA\x92\xE7\xD5\xCA\xB1\xBB\xB2\x64\xAB\x3E\x86\xED\xAB\x5E\xF1\x18\x76\xF9\x7A\xB3\x52\x3D\xA6\x50\x6B\x65\x91\x01\x00\x10\xC0\xDC\xB2\xE1\xD1\xE0\xC8\x72\x95\x41\x3A\xFA\x3F\x6F\xE9\x55\xBF\x6B\x4C\x1B\x94\xA6\x47\x8C\x1F\x84\x43\xAB\x3B\x15\xA7\x6D\xCB\x7B\x51\x56\x06\x05\xE9\xF8\x4D\xF1\x77\xF5\xC6\x34\x39\x28\x1F\x58\x72\x41\x00\x00\x80\x96\x23\x61\x5D\xB2\xF7\x3E\x18\x7A\xF3\xAF\x77\x0F\x88\x67\x2E\xDE\x0D\x99\x47\xA5\x64\x11\x2E\x34\x08\x00\x00\xC4\xE3\xBD\x6D\xDA\xB2\x49\xAA\xD5\x02\x40\xAB\xFD\x9F\x9B\x1C\x1A\x28\x4E\xDC\xAB\x0E\xED\xB1\xBF\xE1\x86\x00\x00\x00\x4D\x8F\xED\xBB\xB9\xCD\xE8\x7C\x62\x6D\xBF\x53\x52\xFE\xDE\x90\xC6\x77\xCA\xC6\x9D\x5A\xFC\xFD\xAE\x05\x06\x17\xF6\x08\x00\x00\xC4\x21\x1F\x26\xEA\x7B\x57\xA1\xEC\xA5\xDF\x2C\xC7\xF4\x9E\xFC\xEB\xB9\x83\x4A\x50\x50\x83\xCF\xDD\x33\xFD\x37\xD5\x8F\x00\x00\x80\x85\xB9\x77\x09\x5E\x02\x32\x80\xD6\x32\x7C\xE8\xB5\x9F\xDF\x43\x80\x71\xE8\x70\x53\x6E\x15\x56\xCF\x6B\x17\x32\x11\x39\x7C\x70\x7A\x1F\x22\x02\x00\x00\x3F\x39\xCF\x38\x59\xC8\x9E\xFC\xAB\x36\xD6\x77\x41\xCE\xF6\xEB\x41\xA4\xB3\x04\x0D\x79\x5C\x2F\x6B\x05\x5B\x81\x01\x78\x62\x90\x01\x00\x80\x00\x00\x00\x78\x46\xFE\x07\xFA\x33\x42\x13\x95\x66\xBC\x9B\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82"
