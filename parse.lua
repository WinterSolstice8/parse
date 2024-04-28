require('common')
addon.name = 'Parse'
addon.author = 'Flippant (Ported to Ashita by Wintersolstice)'
addon.version = '0.986'

messageColor = 200

default_settings = T{}
default_settings.update_interval = 1
default_settings.autoexport_interval = 500
default_settings.debug = false
default_settings.index_shield = false
default_settings.index_reprisal = true
default_settings.index_palisade = true
default_settings.index_battuta = true
default_settings.record = T{
		["me"] = true,
		["party"] = true,
		["trust"] = true,
		["alliance"] = true,
		["pet"] = true,
		["fellow"] = true
	}
default_settings.logger = T{"Flipp*"}
default_settings.label = T{
		["player"] = {red=100,green=200,blue=200},
		["stat"] = {red=225,green=150,blue=0},
	}
default_settings.display = T{}
default_settings.display.melee = T{
	["type"] = "offense",
	["order"] = T{"damage","melee","ws"},
	["max"] = 6,
	["data_types"] = T{
		["damage"] = T{[1] = 'total', [2] = 'total-percent'},
		["melee"] = T{'percent'},
		["miss"] = T{'tally'},
		["crit"] = T{'percent'},
		["ws"] = T{'avg'},
		["ja"] = T{'avg'},
		["multi"] = T{'avg'},
		["ws_miss"] = T{'tally'}
	},
	["fontsSettings"] = T{
		["visible"] = true,
		["color"] = 0xFFFFFFFF,
		["font_family"] = "consolas",
		["font_height"] = 10,
		["bold"] = true,
		["color_outline"] = 0xC8000000,
		["draw_flags"] = FontDrawFlags.Outlined,
		["position_x"] = 570,
		["position_y"] = 50,
		["background"] = T{
			["visible"] = true,
			["color"] = 0x32000000,
		}
	},
}

default_settings.display.defense = {
		["type"] = "defense",
		["order"] = T{"block","hit","parry","guard","counter"},
		["max"] = 2,
		["data_types"] = T{
			["block"] = T{'avg','percent'},
			["evade"] = T{'percent'},
			["hit"] = T{'avg'},
			["parry"] = T{'percent'},
			["guard"] = T{'avg', 'percent'},
			["counter"] = T{'avg', 'percent'},
			["absorb"] = T{'percent'},
			["intimidate"] = T{'percent'},
		},
		["fontsSettings"] = T{
			["visible"] = false,
			["color"] = 0xFFFFFFFF,
			["font_family"] = "consolas",
			["font_height"] = 10,
			["bold"] = true,
			["color_outline"] = 0xC8000000,
			["draw_flags"] = FontDrawFlags.Outlined,
			["position_x"] = 150,
			["position_y"] = 440,
			["background"] = T{
				["visible"] = true,
				["color"] = 0x32000000,
			}
		},
	}
default_settings.display.ranged = {
		["type"] = "offense",
		["pos"] = T{x=570,y=200},
		["order"] = T{"damage","ranged","ws"},
		["max"] = 6,
		["data_types"] = T{
			["damage"] = T{'total','total-percent'},
			["ranged"] = T{'percent'},
			["r_crit"] = T{'percent'},
			["ws"] = T{'avg'},
		},
		["fontsSettings"] = T{
			["visible"] = false,
			["color"] = 0xFFFFFFFF,
			["font_family"] = "consolas",
			["font_height"] = 10,
			["bold"] = true,
			["color_outline"] = 0xC8000000,
			["draw_flags"] = FontDrawFlags.Outlined,
			["position_x"] = 570,
			["position_y"] = 200,
			["background"] = T{
				["visible"] = true,
				["color"] = 0x32000000,
			}
		},
	}
default_settings.display.magic = T{
		["type"] = "offense",
		["order"] = {"damage","spell"},
		["max"] = 6,
		["data_types"] = T{
			["damage"] = T{'total','total-percent'},
			["spell"] = T{'avg'},
		},
		["fontsSettings"] = T{
			["visible"] = false,
			["color"] = 0xFFFFFFFF,
			["font_family"] = "consolas",
			["font_height"] = 10,
			["bold"] = true,
			["color_outline"] = 0xC8000000,
			["draw_flags"] = FontDrawFlags.Outlined,
			["position_x"] = 570,
			["position_y"] = 50,
			["background"] = T{
				["visible"] = true,
				["color"] = 0x32000000,
			}
		},
	}

local settingsLib = require('settings')

settings = settingsLib.load(default_settings)

if not settings then
	settings = default_settings
end

update_tracker,update_interval = 0,settings.update_interval
autoexport = nil
autoexport_tracker,autoexport_interval = 0,settings.autoexport_interval
pause = false
logging = true
buffs = {["Palisade"] = false, ["Reprisal"] = false, ["Battuta"] = false, ["Retaliation"] = false}

database = {}
filters = T{
		['mob'] = {},
		['player'] = {}
	}
renames = {}
text_box = {}
logs = {}

stat_types = {}
stat_types.defense = T{"hit","block","evade","parry","intimidate","absorb","shadow","anticipate","nonparry","nonblock","retrate","nonret","guard","counter"}
stat_types.melee = T{"melee","miss","crit"}
stat_types.ranged = T{"ranged","r_miss","r_crit"}
stat_types.category = T{"ws","ja","spell","mb","enfeeb","ws_miss","ja_miss","enfeeb_miss"}
stat_types.other = T{"spike","sc","add"}
stat_types.multi = T{'1','2','3','4','5','6','7','8'}

damage_types = T{"melee","crit","ranged","r_crit","ws","ja","spell","mb","spike","sc","add","counter","retaliation"}

require 'utility'
require 'retrieval'
require 'display'
require 'action_parse'
require 'report'
require 'file_handle'


-- From Thorny
local ffi = require("ffi");
ffi.cdef[[
    int32_t memcmp(const void* buff1, const void* buff2, size_t count);
]];
local lastChunkBuffer = T{};
local currentChunkBuffer = T{};

local function CheckForDuplicate(e)
    --Check if new chunk..
    if (ffi.C.memcmp(e.data_raw, e.chunk_data_raw, e.size) == 0) then
        lastChunkBuffer = currentChunkBuffer;
        currentChunkBuffer = T{};
    end

    --Add packet to current chunk's buffer..
    local ptr = ffi.cast('uint8_t*', e.data_raw);
    local newPacket = ffi.new('uint8_t[?]', 512);
    ffi.copy(newPacket, ptr, e.size);
    currentChunkBuffer:append(newPacket);

    --Check if last chunk contained this packet..
    for _,packet in ipairs(lastChunkBuffer) do
        if (ffi.C.memcmp(packet, ptr, e.size) == 0) then
            return true;
        end
    end
    return false;
end

ashita.events.register('packet_in', 'packet_in_cb', function(e)
	-- Thanks Thorny!
	local isDuplicate = false
	if (not e.injected) then
		isDuplicate = CheckForDuplicate(e)
	end

	if e.id == 0x028 and not isDuplicate then -- Action packet
		parse_action_packet(e.data)
	end
end)

init_boxes()

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args()
    if args[1] == '/parse' then
		if args[2] == "report" then
			report_data(args[3],args[4],args[5],args[6])
				return true
		elseif (args[2] == 'filter' or args[2] == 'f') and args[2] then
			edit_filters(args[3],args[4],args[5])
			update_texts()
			return true
		elseif (args[2] == 'list' or args[2] == '2') then
			print_list(args[3])
		elseif (args[2] == 'show' or args[2] == 's' or args[2] == 'display' or args[2] == 'd') then
			toggle_box(args[3])
			update_texts()
		elseif args[2] == 'reset' then
			reset_parse()
			update_texts()
		elseif args[2] == 'rename' and args[3] and args[4] then
			if args[4]:gsub('[%w_]','')=="" then
				renames[args[3]:gsub("^%l", string.upper)] = args[4]
				message('Data for player/mob '..args[3]:gsub("^%l", string.upper)..' will now be indexed as '..args[4])	
				return
			end
			message('Invalid character found. You may only use alphanumeric characters or underscores.')
		elseif args[2] == 'export' then
			export_parse(args[3])
		elseif args[2] == 'autoexport' then
			if (autoexport and not args[3]) or args[3] == 'off' then
				autoexport = nil message('Autoexport turned off.')
			else
				autoexport = args[3] or 'autoexport'
				message('Autoexport now on. Saving under file name "'..autoexport..'" every '..autoexport_interval..' recorded actions.')
			end
		elseif args[2] == 'import' and args[3] then
			import_parse(args[3])
			update_texts()
		elseif args[2] == 'log' then
			if logging then logging=false message('Logging has been turned off.') else logging=true message('Logging has been turned on.') end
		elseif args[2] == 'help' then
			message('report [stat] [chatmode] : Reports stat to designated chatmode. Defaults to damage.')
			message('filter/f [add/+ | remove/- | clear/reset] [string] : Adds/removes/clears mob filter.')
			message('show/s [melee/ranged/magic/defense] : Shows/hides display box. "melee" is the default.')
			message('pause/p : Pauses/unpauses parse. When paused, data is not recorded.')
			message('reset :  Resets parse.')
			message('rename [player name] [new name] : Renames a player or monster for NEW incoming data.')
			message('import/export [file name] : Imports/exports an XML file to/from database. Only filtered monsters are exported.')
			message('autoexport [file name] : Automatically exports an XML file every '..autoexport_interval..' recorded actions.')
			message('log : Toggles logging feature.')
			message('list/l [mobs/players] : Lists the mobs and players currently in the database. "mobs" is the default.')
			message('interval [number] :  Defines how many actions it takes before displays are updated.')
		else
			message('That command was not found. Use /parse help for a list of commands.')
		end
    end
    return false
end)


--[[

windower.register_event('addon command', function(...)
    local args = {...}
    if args[1] == 'report' then
		report_data(args[2],args[3],args[4],args[5])
	elseif (args[1] == 'filter' or args[1] == 'f') and args[2] then
		edit_filters(args[2],args[3],args[4])
		update_texts()
	elseif (args[1] == 'list' or args[1] == 'l') then
		print_list(args[2])
	elseif (args[1] == 'show' or args[1] == 's' or args[1] == 'display' or args[1] == 'd') then
		toggle_box(args[2])
		update_texts()
	elseif args[1] == 'reset' then
		reset_parse()
		update_texts()
	elseif args[1] == 'pause' or args[1] == 'p' then
		if pause then pause=false else pause=true end
		update_texts()
	elseif args[1] == 'rename' and args[2] and args[3] then
		if args[3]:gsub('[%w_]','')=="" then
			renames[args[2]:gsub("^%l", string.upper)] = args[3]
			message('Data for player/mob '..args[2]:gsub("^%l", string.upper)..' will now be indexed as '..args[3])	
			return
		end
		message('Invalid character found. You may only use alphanumeric characters or underscores.')
	elseif args[1] == 'interval' then
		if type(tonumber(args[2]))=='number' then update_tracker,update_interval = 0, tonumber(args[2]) end
		message('Your current update interval is every '..update_interval..' actions.')
	elseif args[1] == 'export' then
		export_parse(args[2])
	elseif args[1] == 'autoexport' then
		if (autoexport and not args[2]) or args[2] == 'off' then
			autoexport = nil message('Autoexport turned off.')
		else
			autoexport = args[2] or 'autoexport'
			message('Autoexport now on. Saving under file name "'..autoexport..'" every '..autoexport_interval..' recorded actions.')
		end
	elseif args[1] == 'import' and args[2] then
		import_parse(args[2])
		update_texts()
    elseif args[1] == 'log' then
        if logging then logging=false message('Logging has been turned off.') else logging=true message('Logging has been turned on.') end
	elseif args[1] == 'help' then
		message('report [stat] [chatmode] : Reports stat to designated chatmode. Defaults to damage.')
		message('filter/f [add/+ | remove/- | clear/reset] [string] : Adds/removes/clears mob filter.')
		message('show/s [melee/ranged/magic/defense] : Shows/hides display box. "melee" is the default.')
		message('pause/p : Pauses/unpauses parse. When paused, data is not recorded.')
		message('reset :  Resets parse.')
		message('rename [player name] [new name] : Renames a player or monster for NEW incoming data.')
		message('import/export [file name] : Imports/exports an XML file to/from database. Only filtered monsters are exported.')
		message('autoexport [file name] : Automatically exports an XML file every '..autoexport_interval..' recorded actions.')
        message('log : Toggles logging feature.')
		message('list/l [mobs/players] : Lists the mobs and players currently in the database. "mobs" is the default.')
        message('interval [number] :  Defines how many actions it takes before displays are updated.')
	else
		message('That command was not found. Use //parse help for a list of commands.')
	end
end )

--]]
tracked_buffs = {
	[403] = "Reprisal",
	[478] = "Palisade",
	[570] = "Battuta",
	[405] = "Retaliation"
}

--windower.register_event('gain buff', function(id)
	--if tracked_buffs[id] then
--		buffs[tracked_buffs[id]] = true
--	end
--end )

--windower.register_event('lose buff', function(id)
	--if tracked_buffs[id] then
--		buffs[tracked_buffs[id]] = true
--	end
--end )

function get_stat_type(stat)
	for stat_type,stats in pairs(stat_types) do
		if stats:contains(stat) then
			return stat_type
		end
	end
	return nil
end

function reset_parse()
	database = {}
end

function toggle_box(box_name)
	if not box_name then
		box_name = 'melee'
	end
	if text_box[box_name] then
		if settings.display[box_name].fontsSettings.visible then
			text_box[box_name].visible = false
			settings.display[box_name].fontsSettings.visible = false
		else
			text_box[box_name].visible = true
			settings.display[box_name].fontsSettings.visible = true
		end
	else
		message('That display was not found. Display names are: melee, defense, ranged, magic.')
	end
end

function edit_filters(filter_action,str,filter_type)
	if not filter_type or not filters[filter_type] then
		filter_type = 'mob'
	end

	if filter_action=='add' or filter_action=="+" then
		if not str then message("Please provide string to add to filters.") return end
		table.insert(filters[filter_type],str)
		message('"'..str..'" has been added to '..filter_type..' filters.')
	elseif filter_action=='remove' or filter_action=="-" then
		if not str then message("Please provide string to remove from filters.") return end
		
		local i = 1
		for k, v in pairs(filters[filter_type]) do
			if v == str then
				table.remove(filters[filter_type], i)
				break
			end
			i = i + 1
		end

		message('"'..str..'" has been removed from '..filter_type..' filters.')
	elseif filter_action=='clear' or filter_action=="reset" then
		filters[filter_type] = {}
		message(filter_type..' filters have been cleared.')
	end	
end

function get_filters()
	local text = ""

	if filters['mob'] and getTableLength(filters['mob']) > 0 then
		text = text .. 'Monsters:'
		for k, v in pairs(filters['mob']) do
			text = text .. ' ' .. v
		end
	end

	if filters['player'] and getTableLength(filters['player']) > 0 then
		text = text .. '\nPlayers:'
		for k, v in pairs(filters['player']) do
			text = text .. ' ' .. v
		end
	end
	return text
end

function print_list(list_type) 
	if not list_type or list_type=="monsters" or list_type=="m" then 
		list_type="mobs" 
	elseif list_type=="p" then
		list_type="players"
	end
	
	local lst = T{}
	if list_type=='mobs' then
		lst = get_mobs()
	elseif list_type=='players' then
		lst = get_players()
	else
		message('List type not found. Valid list types: mobs, players')
		return
	end
	
	if lst:length()==0 then message('No data found. Nothing to list!') return end
	
	lst['n'] = nil
	local msg = ""
	for __,i in pairs(lst) do
		msg = msg .. i .. ', '
	end
	
	msg = msg:slice(1,#msg-2)
	
	msg = prepare_string(msg,100)
	msg['n'] = nil
	
	for i,line in pairs(msg) do
		message(line)
	end
end

-- Returns true if monster is not filtered, false if monster is filtered out
function check_filters(filter_type,mob_name)
-- FIXME: fix filters
--	if not filters[filter_type] or filters[filter_type]:tostring()=="{}" then
--		return true
--	end

	local response = false
	local only_excludes = true
	for _, v in pairs(filters[filter_type]) do
		if v:lower():startswith('!^') then --exact exclusion filter
			if v:lower():gsub('%!',''):gsub('%^','')==mob_name:lower() then --immediately return false
				return false
			end
        elseif v:lower():startswith('!') then --exclusion filter
			if string.find(mob_name:lower(),v:lower():gsub('%!','')) then --immediately return false
				return false
			end
		elseif v:lower():startswith('^') then --exact match filter
			if v:lower():gsub('%^','')==mob_name:lower() then
				response = true				
			end
			only_excludes = false
		elseif string.find(mob_name:lower(),v:lower()) then --wildcard filter (default behavior)
			response = true
			only_excludes = false
		else
			only_excludes = false
		end
	end
	if not response and only_excludes then
		response = true
	end
	return response
end

local lastUpdate = os.time()
ashita.events.register('d3d_present', 'present_cb', function()
	if os.time() - lastUpdate > settings.update_interval then
		update_texts()
	end
end)


settingsLib.register('settings', 'settings_update', function(newSettings)
    for boxName,boxData in pairs(newSettings.display) do
        text_box[boxName].position_x = boxData.fontsSettings.position_x
        text_box[boxName].position_y = boxData.fontsSettings.position_y
        text_box[boxName].visible    = boxData.fontsSettings.visible
    end
    settingsLib.save()
end)

ashita.events.register('unload', 'unload_cb', function ()
	for box,__ in pairs(settings.display) do
		settings.display[box].fontsSettings.position_x = text_box[box].position_x
		settings.display[box].fontsSettings.position_y = text_box[box].position_y
	end
    settingsLib.save()
end)

ashita.events.register('mouse', 'mouse_cb', function (e)
end)

--config.register(settings, function(settings)
--    update_texts:loop(settings.update_interval)
--end)

--Copyright (c) 2013~2016, F.R
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of <addon name> nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
