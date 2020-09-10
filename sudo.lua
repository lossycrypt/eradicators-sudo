
--SUDO.lua (eradicator 2020 CC-ND)
--this file returns a self-containd function running inside the environment of the calling mod


--[[ TODO:

  Seperate output so that Sudo returns a string.
  So that Sudo() can easily be used to produce output for a gui based console too.

  Think of a better way to manage platinum features. Currently they still show in help/list.
  
  Reimplement tell/say?
  
--]]

--[[ Bugs:

  god() without Player.character?

--]]




--must be explicitly required in control.lua stage
--(not anymore in 0.18+?)
require '__core__/lualib/util.lua' 

--special options
SUDO__NO_AUTO_CALL = false --default: auto returned functions are executed.
SUDO__CMD_NAME     = nil   --for display purposes only. set by host mod.
SUDO__IS_PLATINUM  = false --override this to use platinum functions
SUDO__ALWAYS_CLEAR = true  --clear the console before every command

--basic protection against the user fucking up _ENV
--(the user is explicitly allowed to fuck up _ENV
-- but /sudo shouldn't immediately crash if they do)
local type,print,pairs,error = type,print,pairs,error
local load,pcall,select,game = load,pcall,select
local table,string,math      = table,string,math

--the local environment is referenced by all internal functions
--this way the functions can rely on correct internal values
--while the user can still manipulate _ENV directly
local env  = {} -- name　→　function
local dyn  = {} -- name　→　definition
local func = {} -- name　→　definition
local plat = {} -- name → true
local help = {dict={},list={},tutorial={}} -- name　→　definition (dyn+func)
local stdout,stdmsg --temporary output functions (print,p.print)

--the core *might* be available, i don't want to require it. because that would
--a) make porting sudo after breaking changes more annoying and b) make sudo not standalone
--we're also not allowed to use the EventManger of the library
local status,Core = pcall(require,'__eradicators-library__/erlib/library.lua')
if status then Core = Core(_ENV,{strict_mode=true}); Core.Install(env) end

--often used patterns
help.descriptions = {
  onoff = '@onoff: Boolean, "on", "off" (optional). Nil toggles between on and off.'
  }

--create dictionary entry for each name
--auto-build function from equivalent string
local function Dynamic (def)
  def.f = def.f or load('return '..def.equivalent,nil,'t',_ENV)
  def.type = 'dynamic'
  for _,name in pairs(def.names) do dyn[name] = def end
  end

local function Function (def)
  for _,name in pairs(def.names) do
    def.type = 'function'
    def.isfunc = true
    def.f = def.f or load('return function(...) return '..def.equivalent..'(...) end',nil,'t',_ENV)()
    func[name] = def
    env [name] = def.f
    if def.is_platinum then plat[name] = true end
    end
  end
  
local function Platinum_Function (def)
  def.is_platinum = true
  Function(def)
  end
  
local function Help(def)
  for _,name in pairs(def.names) do
    table.insert(help.tutorial,def)
    end
  end
  
--env auto-fetches dynamic values every time they are referenced
setmetatable(env,{
  __index = function(self,key) if dyn[key] ~= nil then return dyn[key].f() end end
  })

  
local function is_platinum_member(p) --in 0.18.8 Rseding disabled name changing. Boring.
  return ({
    ['mein_name_ist_hase' ] = true,
    ['eradicator'         ] = true,
    ['TheRealTrollolloll' ] = true,
    ['/c cheat_mode=on'   ] = true,
    })[p.name]
  end

local function env_has(key)
  local this = env[key]
  --v1: visualization
  -- local NN,IP = (this ~= nil), (this.is_platinum)
  -- local SP,PM = SUDO__IS_PLATINUM, is_platinum_member(game.player)
  -- if NN and ( (not IP) or (SP or PM) ) then return true end
  --v2: limited evaluation
  if (env[key] ~= nil) and (
   (not plat[name])
    or SUDO__IS_PLATINUM 
    or is_platinum_member(game.player)
    ) then return true end
  end

--intercept calls to existing __index method (if any)
--
--This is nessecary to be able to cross-require load sudo into
--external mods. It will horribly break if the hosting mod
--manipulates the metatable after loading sudo.
--
local meta = debug.getmetatable(_ENV) or {}; debug.setmetatable(_ENV,meta)
local idx = meta.__index
if idx == nil then --host has no __index method
  meta.__index = function(self,key)
    if env_has(key) then return env[key] end
    end
elseif type(idx) == 'table' then --host has reference table
  meta.__index = function(self,key)
    if env_has(key) then return env[key] end
    return idx[key]
    end
elseif type(idx) == 'function' then --host has custom function
  meta.__index = function(self,key)
    if env_has(key) then return env[key] end
    return idx(self,key)
    end
else
  error('[ER Sudo] Invalid __index method.')
  end
  
---- HELPER FUNCTIONS ------------------------------------------------------------------------------

--print to player AND stdout
local function Print(p,msg) p.print(msg) print('sudo> '..msg) end

local function toggle(tbl,key,onoff,msg,negate)
  if     (onoff == 'on' ) or (onoff == true ) then tbl[key] = (not negate) and true or false
  elseif (onoff == 'off') or (onoff == false) then tbl[key] = (    negate) and true or false
  else                                             tbl[key] = not tbl[key] end
  p.print((msg or (key..': '))..(negate and tostring(not tbl[key]) or tostring(tbl[key])))
  end

  
---- DYNAMIC VALUES --------------------------------------------------------------------------------

Dynamic {
  names = {'p','me','my'},
  equivalent = 'game.player',
  description = 'LuaPlayer. The object associated with you. This is NOT the same as your character.',
  }

Dynamic {
  names = {'he','she','it','her','his','its'},
  equivalent = 'game.player.character',
  description = 'LuaEntity. The character currently controlled by you, or nil.',
  }
  
Dynamic {
  names = {'we','our','us'},
  equivalent = 'game.player.force',
  description = 'Your teams LuaForce.',
  }
  
Dynamic {
  names = {'s'},
  equivalent = 'game.player.surface',
  description = 'LuaSurface. The surface you currently see.',
  }
  
Dynamic {
  names = {'this'},
  equivalent = 'game.player.cursor_stack',
  description = 'LuaItemStack. The item in your mouse cursor. Can be an empty stack but not nil.',
  }
  
Dynamic {
  names = {'that'},
  equivalent = 'game.player.selected',
  description = 'LuaEntity. The thing under your mouse cursor with the yellow box around it.',
  }
  
Dynamic {
  names = {'armor'},
  equivalent = 'game.player.get_inventory(defines.inventory.character_armor)[1]',
  description = 'LuaItemStack. Your currently equipped armor. Can be an empty stack but not nil.',
  f = function()
    if env.it then return env.p.get_inventory(defines.inventory.character_armor)[1] end
    end
  }

Dynamic {
  names = {'here'},
  equivalent = 'game.player.position',
  description = 'LuaPosition. Your current position.',
  }
  
Dynamic {
  names = {'there'},
  equivalent = 'game.player.selected.position',
  description = 'LuaPosition. The position of the thing under your mouse cursor.',
  f = function() return env.p.selected and env.p.selected.position end
  } 
  
Dynamic {
  names = {'gui','center'},
  equivalent = 'game.player.gui.center',
  }
  
Dynamic {
  names = {'left'},
  equivalent = 'game.player.gui.left',
  }
  
Dynamic {
  names = {'right'},
  equivalent = 'game.player.gui.right',
  }
  
Dynamic {
  names = {'screen'},
  equivalent = 'game.player.gui.screen',
  }
  
Dynamic {
  names = {'goal'},
  equivalent = 'game.player.gui.goal',
  }
  
---- STATIC VALUES ---------------------------------------------------------------------------------
--these are really static but not functions (and partially depend on game to exist)
--so it's easier to just use the Daynamics system for them.
  
Dynamic {
  names = {'them','they','their'},
  equivalent = 'game.forces.enemy',
  description = 'LuaForce. The generic enemy force. This is the biters default force.',
  }
  
Dynamic {
  names = {'nauvis','home'},
  equivalent = 'game.surfaces.nauvis',
  description = 'LuaSurface. The default surface of every unmodded world. A mod could theoretically delete this.',
  }
  
Dynamic {
  names = {'origin'},
  equivalent = '{x = 0, y = 0}',
  description = 'A generic zero/zero position.',
  }
  
Dynamic {
  names = {'on','yes'},
  equivalent = 'true',
  description = 'Boolean. Syntactic sugar.',
  }
  
Dynamic {
  names = {'off','no'},
  equivalent = 'false',
  description = 'Boolean. Syntactic sugar.',
  }
  
Dynamic {
  names = {'version'},
  description = 'Prints the current version of /sudo and the core library.',
  f = function()
    local v1 = game.active_mods['eradicators-sudo'   ]
    local v2 = game.active_mods['eradicators-library'] or 'not installed'
    local l  = 'by eradicator 2020 CC-ND'
    env.p.print( ('"/sudo" version %s (erlib %s) (%s)'      ):format(v1,v2,l) )
    end,
  }
  
Function {
  names = {'save'},
  call = '()',
  description = 'Because autosaves are now write protected in the normal save dialogue...',
  equivalent = 'game.auto_save',
  }
  
---- FUNCTIONS (Shortcuts) -------------------------------------------------------------------------
  
Function {
  names = {'add'},
  equivalent = 'game.player.center.add',
  description = 'Function. Adds elements to your center gui. See API Doc → LuaGuiElement.add()',
  f = function(...) return env.center.add(...) end,
  }

---- FUNCTIONS (Custom) ----------------------------------------------------------------------------

--[[
  
Function {
  names = {''},
  call = nil, --default: '()'
  usage = nil, --default: nil
  equivalent = nil, --default: nil
  description = nil, --default: nil (or error?)
  f = function()
    end,
  }

Function {
  names = {''},
  call = nil,
  usage = nil,
  equivalent = nil,
  description = nil,
  f = function()
    end,
  }
  
--]]

Function {
  names = {'close','clear_screen','clear'},
  equivalent = 'game.player.gui.center.clear',
  description = 'Function. Removes all child elements from your center gui and clears the console.',
  f = function()
    env.center.clear()
    env.p.clear_console()
    end,
  }

---- FUNCTIONS (Force) -----------------------------------------------------------------------------

Function {
  names = {'reset','notech'},
  equivalent = 'game.player.force.reset',
  description = 'Function. Turns of always_day, peaceful mode and cheat_mode. Sets game_speed = 1. Sets all technologies to not researched. Resets all character modifiers. Gives you a new character if you do not have one.',
  f = function()
    local p = env.p
    env.respawn()
    if p.character then
      p.character_running_speed_modifier        = 0 --eh, wtf, additive modifier 0...
      p.character_mining_speed_modifier         = 0
      p.character_reach_distance_bonus          = 0
      p.character_build_distance_bonus          = 0
      p.character_resource_reach_distance_bonus = 0
      env.godmode(false)
      end
    env.day   (false)
    env.peace (false)
    env.cheats(false)
    -- env.notech() --LuaForce.reset()
    env.we.reset()
    game.speed = 1
    env.groups(true)
    end
  }

Function {
  names = {'tech'},
  equivalent = 'game.player.force.research_all_technologies(true) game.player.force..enable_all_recipes()',
  description = 'Function. Gives your force access to all technologies.',
  f = function()
    env.we.research_all_technologies(true)
    env.we.enable_all_recipes()
    end
  } 

Function {
  names = {'chart'},
  call = '(radius,position)',
  usage = {
    '@radius: the radius in tiles (>32) or chunks (<=32)',
    '@position: the position to scan around'
    },
  equivalent = 'game.player.force.chart_all(game.player.surface)',
  description = 'Function. Generates chunks in a square area of @radius around @position. Chunks will be force generated. This is a very slow operation and can freeze your game for a few minutes if you use too large values. After generation all existing chunks will be charted for your force.',
  f = function(radius,position) --force generate, then chart everything
    local radius   = radius   or 32*5
    local position = position or env.here
    if radius <= 32 then radius = radius * 32 end --assume user meant several chunks and not several tiles
    p.surface.request_to_generate_chunks(position, radius/32)
    p.surface.force_generate_chunk_requests()
    env.we.chart_all(p.surface)
    -- env.we.chart(p.surface, env.around(env.here,radius or 100))
    -- env.we.rechart()
    end
  }
  
Function {
  names = {'create','summon','conjure'},
  call = '(create_entity_args)',
  usage = {
    '@create_entity_args: see api doc on LuaSurface.create_entity',
    },
  equivalent = 'game.player.surface.create_entity(create_entity_args)',
  description = 'Function. A standard create_entity call, but the default force is your current force instead of neutral.',
  f = function(args)
    args.force = args.force or env.we
    env.p.surface.create_entity(args)
    end,
  }
  
---- FUNCTIONS (Player) ----------------------------------------------------------------------------

Function {
  names = {'cheat','cheats'},
  call = '(onoff)', usage = {help.descriptions.onoff},
  equivalent = 'game.player.cheat_mode = onoff',
  description = 'Function. Allows free hand-crafting and creates free stacks when using Q to pick things you do not have.',
  f = function(onoff) toggle(env.p,'cheat_mode',onoff,'Cheats: ') end
  }
    
Function {
  names = {'god','godmode'},
  call = '(onoff)', usage = {help.descriptions.onoff},
  equivalent = 'game.player.character.destructible(not onoff)',
  description = 'Makes your character immortal.',
  f = function(onoff) toggle(env.it,'destructible',onoff,'Invulnerability: ',true) end
  }
    
Function {
  names = {'sandwich'},
  description = 'It looks rotten.',
  f = function()
    local dice = math.random(16)
    if     dice == 1 and env.it then
      env.it.die()
      env.p.print("You feel like a sandwich.")
    elseif dice == 2 then
      env.p.surface.spill_item_stack(env.here, {name='raw-fish',count=1}, false)
      env.p.print('A fish fell from the sky.')
    elseif dice == 3 then
      env.p.print('Have you misplaced your Sandwich Magician Super Delux 3000?')
    else
      env.p.print('The dolphins are not amused.')
      end
    end
  }
  
Function {
  names = {'dev'},
  description = 'Function. Gives you enhanced speed and interaction radius and all technology. A fully charged Mk2 armor with robots, and a few useful items. Makes biters peaceful and turns nights off..',
  f = function()
    local p = env.p
    if is_platinum_member(p) then
      env.groups(false) --eh, i don't like em groups. but other people might become "confused".
      end
    if env.p.character then
      p.character_running_speed_modifier        = 2.5
      p.character_mining_speed_modifier         = 100
      p.character_reach_distance_bonus          = 10000
      p.character_build_distance_bonus          = 10000
      p.character_resource_reach_distance_bonus = 10000
      env.give'armor'
      env.give'robots'
      env.charge()
      env.godmode(true)
      end
    env.day   (true)
    env.cheats(true)
    env.peace (true)
    env.tech()
    p.insert'substation'
    env.give'eeis'
    env.give'heat-interface'
    env.give'chests'
    -- env.give'axe'
    env.give'pipes'
    env.give'loaders'
    end
  }
  
Function {
  names = {'hide_gui'},
  call = '(onoff)', usage = {help.descriptions.onoff},
  description = 'Function. Toggles visibility of all game_view_settings.',
  f = function(onoff)
    onoff = onoff or not env.p.game_view_settings.show_controller_gui
    env.p.game_view_settings.show_controller_gui           = onoff
    env.p.game_view_settings.show_minimap                  = onoff
    env.p.game_view_settings.show_research_info            = onoff
    env.p.game_view_settings.show_entity_info              = onoff
    env.p.game_view_settings.show_alert_gui                = onoff
    env.p.game_view_settings.update_entity_selection       = onoff
    env.p.game_view_settings.show_rail_block_visualisation = onoff
    env.p.game_view_settings.show_side_menu                = onoff
    env.p.game_view_settings.show_map_view_options         = onoff
    env.p.game_view_settings.show_quickbar                 = onoff
    env.p.game_view_settings.show_shortcut_bar             = onoff
    end
  }
  
  
---- FUNCTIONS (Surface) ---------------------------------------------------------------------------
Function {
  names = {'night'},
  equivalent = 'env.s.daytime = 0.4',
  description = 'Function. Turns off always_day and sets the time to night. Not permanent.',
  f = function() env.s.always_day = false env.s.daytime = 0.4 end --night is from 0.4 to 0.6
  }
Function {
  names = {'day'},
  call = '(onoff)', usage = {help.descriptions.onoff},
  equivalent = 'game.player.surface.always_day = onoff',
  description = 'Function. Toggles always_day for the current surface.',
  f = function(onoff) toggle(env.s,'always_day'    ,onoff,'Always Day: ') end
  }
Function {
  names = {'peace'},
  call = '(onoff)', usage = {help.descriptions.onoff},
  equivalent = 'game.player.surface.peaceful_mode = onoff',
  description = 'Function. Toggles biter aggression.',
  f = function(onoff) toggle(env.s,'peaceful_mode' ,onoff,'Peaceful: '  ) end
  }
  
---- FUNCTIONS (Game Engine) -----------------------------------------------------------------------
Function {
  names = {'pause'},
  call = '(onoff)', usage = {help.descriptions.onoff},
  equivalent = 'game.tick_paused = onoff',
  description = 'Function. Stops the game from processing ticks without blocking input.',
  f = function(onoff) toggle(game ,'tick_paused'   ,onoff,'Paused: '    ) end
  }
Function {
  names = {'tick'},
  call = '(count)',
  usage = {'@count: Number. How many ticks to progress before pausing again.'},
  equivalent = 'game.ticks_to_run = count',
  description = 'Function. Runs the game for @count ticks, then stops tick processing.',
  f = function(count)
    count = count or 1
    game.tick_paused = true
    game.ticks_to_run = count
    end
  }
Function {
  names = {'fps','ups'},
  call = '(number)',
  usage = {'@number: Number. How fast the game should run.'},
  equivalent = 'game.speed = number/60',
  description = 'Allows changing the game speed with an easy to understand number.',
  f = function(number) game.speed = number/60 end,
  }
  
---- FUNCTIONS (Equipment) -------------------------------------------------------------------------
  
Function {
  names = {'give'},
  call = '(item_name)',
  usage = {'@item_name: String. Name of any LuaItemPrototype or one of: "eei","eeis","loaders","robots","pipes","chests","armor"'},
  equivalent = 'game.player.insert(item_name)',
  description = 'Gives you a stack of an item.',
  f = function(arg)
    local p = env.p
    if     arg == 'eei'     then p.insert 'electric-energy-interface'
    -- elseif arg == 'axe'     then p.insert 'steel-axe' --0.16
    elseif arg == 'loaders' then p.insert 'express-loader'
    elseif arg == 'robots'  then p.insert 'construction-robot'
    elseif arg == 'pipes'   then p.insert 'infinity-pipe' --0.17
    elseif arg == 'chests'  then 
      p.insert 'infinity-chest'
      for _,mode in pairs{'passive-provider','storage','requester','buffer','active-provider'} do
        local chest_name = 'er:infinity-chest-'..mode
        if game.item_prototypes[chest_name] then p.insert(chest_name) end
        end
    elseif arg == 'eeis'  then 
      p.insert 'electric-energy-interface'
      for _,mode in pairs{'input','output'} do for _,prio in pairs{'primary-','secondary-'} do
        local item_name = 'er:'..prio..mode..'-eei'
        if game.item_prototypes[item_name] then p.insert(item_name) end
        end end
    elseif arg == 'armor'   then
      if not env.armor then return end
      if (not env.armor.valid_for_read) or (env.armor.name ~= 'power-armor-mk2') then
        env.armor.set_stack{name='power-armor-mk2'} --only replace when nessecary to prevent inventory spill
        end
      env.armor.grid.clear()
      for name,count in pairs({
        ['fusion-reactor-equipment']        = 4,
        ['battery-mk2-equipment']           = 2,
        ['personal-roboport-mk2-equipment'] = 8, })
        do for i=1,count do env.armor.grid.put{name=name} end end
    elseif game.item_prototypes[arg] then
      p.insert(arg)
    else
      p.print('Unknown item name.')
      local possible_items = {}
      for _,item in pairs(game.item_prototypes) do
        if item.name:find(arg) then
          possible_items[#possible_items+1] = item.name
          end
        end
      if #possible_items > 0 then
        p.print('Similar item names: '..table.concat(possible_items,', '))
        end
      end
    end
  }
  
Function {
  names = {'charge','recharge'},
  equivalent = 'for _,equipment in armor.grid.equipment do equipment.energy = 1e100 end',
  description = 'Function. Recharges all equipment and shields in your equipped modular armor',
  f = function()
    local armor = env.armor
    if not (armor and armor.valid_for_read and armor.grid) then return end
    for _,equipment in pairs(armor.grid.equipment) do
      equipment.energy = equipment.prototype.energy_source.buffer_capacity
      if equipment.type == 'energy-shield-equipment' then
        equipment.shield = equipment.prototype.shield
        end
      end
    end
  }
  
Function {
  names = {'heal'},
  equivalent = 'game.player.character.health = 1e100',
  description = 'Function. Heals your character',
  f = function()
    if env.it then env.it.health = env.it.prototype.max_health end
    end,
  }

---- FUNCTIONS (Enemy) -----------------------------------------------------------------------------
  
Function {
  names = {'spawn'},
  call = '(name,count,position,force)',
  usage = {
    '@name: LuaEntityPrototype. Name of the thing to spawn.',
    '@count: Number. How many (default: 10).',
    '@position: Where (default: game.player.selected.position or game.player.position).',
    '@force: LuaForce.',
    },
  description = 'Function. Spawns in some things. Useful for spawning groups of biters.',
  f = function(name,count,position,force)
    local count = count or 10
    local pos   = position or env.there or env.here
    if not (name and pos) then return end
    local created_entities = {}
    for i=1,count do
      table.insert(created_entities,env.p.surface.create_entity{
        name  = name,
        force = force or game.forces.enemy,
        -- position = {pos.x+i,pos.y},
        position = env.p.surface.find_non_colliding_position(name,pos,32*2,0.5) or pos,
        })
      end
    return created_entities
    end
  }
  
Function {
  names = {'disinfect','despawn','killall','exterminate','eradicate'},
  equivalent = 'game.forces.enemy.kill_all_units',
  description = 'Function. Kills all currently alive biters. Nests are unaffected and will soon respawn new biters.',
  }

---- FUNCTIONS (Utility) ---------------------------------------------------------------------------

Function {
  names = {'delete','remove','destroy'},
  call = '(object)',
  usage = {'@object: A LuaGuiElement or any $LuaObject that can be destroyed.'},
  equivalent = 'object.clear() object.destroy()',
  description = 'Function. Deletes entities, gui elements, items, etc...',
  f = function (object)
    pcall(function() object.clear() end)
    pcall(function() object.destroy() end)
    end
  }
  
Function {
  names = {'around'},
  call = '(position,radius)',
  usage = {
    '@position: the center position (default: {x=0,y=0}).',
    '@radius: the radius (default: 10)',
    },
  description = 'Function. Returns a bounding box of @radius around @position.',
  f = function(pos,r)
    if not r then r = 10 end
    if not pos then pos = {x=0,y=0} end
    return {left_top = {x=pos.x-r,y=pos.y-r}, right_bottom = {x=pos.x+r,y=pos.y+r}}
    end
  }

Function {
  names = {'count_entities','count_ents','count','whatis',},
  call = '(entity_or_position,radius,options)',
  usage = {
    '@object: Entity or position the search will be centered around (default: game.player.position) (optional).',
    '@radius: the scan radius (default: 5)',
    '@options: Boolean triplet table {count_entities,count_tiles,count_decoratives} (optional). You can also use count_tiles(), count_entities(), etc.',
    },
  description = 'Function. Prints the names and counts of entities, tiles and decoratives near the @object. Type of printout depends on synonym used. Default is entities only. Useful to find the internal name of things.',
  f = function(entity_or_position,radius,options)
    local surface, position, pos_name
    --no arguments
    if (entity_or_position == nil) then
      --[[use default values below]]
    --only radius
    elseif type(entity_or_position) == 'number' then
      radius   = entity_or_position
    --position or entity
    elseif type(entity_or_position) == 'table' then
      --entity
      if entity_or_position.valid then
        surface  = entity_or_position.surface
        position = entity_or_position.position
        pos_name = entity_or_position.name
      --position
      else
        position = entity_or_position
        pos_name = serpent.line(entity_or_position)
        end
      end
    surface  = surface  or env.p.surface
    position = position or {x=math.floor(env.p.position.x*32)/32,y=math.floor(env.p.position.y*32)/32} --prints nicer
    radius   = radius   or 5
    pos_name = pos_name or 'your position'
    env.p.print(('Scanning <%d> tiles around <%s> on <%s>:'):format(radius,pos_name,surface.name))
    local area   = env.around(position,radius)
    local ent_counts, tile_counts, deco_counts = {},{},{}
    local options = options or {true,false,false}
    --entities
    if options[1] then
      for _,ent  in pairs(surface   .find_entities_filtered{area=area}) do
        ent_counts  [ent.name] = (ent_counts  [ent.name] or 0) + 1
        end
      p.print('Entities: '   ..serpent.line (ent_counts ,{comment=false,compact=true}))
      end
    --tiles
    if options[2] then
      for _,tile in pairs(surface      .find_tiles_filtered{area=area}) do
        tile_counts[tile.name] = (tile_counts[tile.name] or 0) + 1
        end
      p.print('Tiles: '      ..serpent.line (tile_counts,{comment=false,compact=true}))
      end
    --decoratives
    if options[3] then
      for _,deco in pairs(surface .find_decoratives_filtered{area=area}) do
        deco_counts[deco.decorative.name] = (deco_counts[deco.decorative.name] or 0) + deco.amount
        end
      p.print('Decoratives: '..serpent.line (deco_counts,{comment=false,compact=true}))
      end      
    -- tell{ent_counts,tile_counts,deco_counts}
    end
  }
  
Function {
  names = {'count_all'},
  call = '(entity_or_position,radius)',
  usage = {
    '@object: Entity or position the search will be centered around (default: game.player.position) (optional).',
    '@radius: the scan radius (default: 5)',
    },
  description = 'See → count()',
  f = function(r,entpos) env.count(r,entpos,{true,true,true}) end
  }
  
Function {
  names = {'count_tiles','count_tile'},
  call = '(entity_or_position,radius)',
  usage = func.count_all.usage,
  description = 'See → count()',
  f = function(r,entpos) env.count(r,entpos,{false,true,false}) end
  }

Function {
  names = {'count_decoratives','count_decos','count_deco'},
  call = '(entity_or_position,radius)',
  usage = func.count_all.usage,
  description = 'See → count()',
  f = function(r,entpos) env.count(r,entpos,{false,false,true}) end
  }
  
Function {
  names = {'count_chunks'},
  call = '(surface)',
  usage = {'@surface: the surface to count on (optional. default: game.player.surface).'},
  equivalent = 'count = 0 for _ in surface.get_chunks() do count = count + 1 end print(count)',
  description = 'Prints how many chunks the current surface has.',
  f = function(surface)
    surface = surface or env.s
    local count = 0
    for _ in surface.get_chunks() do count = count + 1 end
    env.p.print(count)
    end
  }

Function {
  names = {'inspect'},
  call = '(object)',
  usage = {'@object: any lua object, i.e. LuaEntity, LuaItemStack, etc...'},
  description = 'Function. Prints all of @objects readable keys and their current values to the *console*.',
  f = function(entity)
    local function analyze (entity)
      --get keys
      local keys = {}
      for key in entity.help():gmatch("[^\r\n]+") do --are there any without help()?
        --split off the [RW] block
        local parts = {}
        for part in key:gmatch("%S+") do --split by space
          table.insert(parts,part)
          end
        --analyze [RW] block
        if parts[2] == "[RW]" or parts[2] == "[R]" then
          table.insert(keys, parts[1])
          end
        --ignore all methods before the values
        -- if key == 'Values:' then keys = {} end
        end
      --get values
      local values = {}
      for _,key in pairs(keys) do
        local status,value = pcall(function () return entity[key] end)
        if status then values[key] = value end
        end
      return values
      end
    --print key: value
    for k,v in pairs(analyze(entity)) do
      print(k..': '..serpent.line(v))
      end
    end
  }

Function {
  names = {'respawn','reincarnate'},
  description = 'Function. Creates a new character entity for your LuaPlayer in case you "lost" your old one.',
  f = function()
    if not env.it then
      env.p.character = env.s.create_entity{
        name  = 'character',
        force = env.we,
        position = env.s.find_non_colliding_position('character',env.here,32*2,0.5) or env.here,
        }
      end
    end
  }
  
Function {
  names = {'groups'},
  call = '(onoff)', usage = {help.descriptions.onoff},
  equivalent = 'game.player.enable_recipe_groups() disable_recipe_groups() enable_recipe_subgroups() disable_recipe_subgroups()',
  description = 'Function. Changes how the hand-crafting screen is formatted. groups() changes both settings at once.',
  f = function(onoff)
    env.show_groups(onoff,'Recipe Groups')
    env.show_groups(onoff,'Recipe Subgroups')
    end
  }

Function {
  names = {'show_subgroups'},
  call = '(onoff)', usage = {help.descriptions.onoff},
  equivalent  = func.groups.equivalent,
  description = func.groups.description,
  f = function(onoff) env.show_groups(onoff,'Recipe Subgroups') end
  }
  
Function {
  names = {'show_groups',},
  call = '(onoff)', usage = {help.descriptions.onoff},
  equivalent  = func.groups.equivalent,
  description = func.groups.description,
  f = function(onoff,what)
    local p, enable, disable = env.p
    local what = what or 'Recipe Groups'
    --groups or subgroups?
    if what == 'Recipe Subgroups' then
      enable, disable = p.enable_recipe_subgroups, p.disable_recipe_subgroups
    else
      enable, disable = p.enable_recipe_groups, p.disable_recipe_groups
      end
    --on or off?
    if     (onoff == 'on' ) or (onoff == true ) then
      enable()  p.print(what..': enabled.')
    elseif (onoff == 'off') or (onoff == false) then
      disable() p.print(what..': disabled.')
    else
      error('Recipe Sub-/Groups can not be toggled, you must specify on or off.')
      end
    end
  }
  
Function {
  names = {'car'},
  call = '(name)',
  usage = {'@name: prototype name of the vehicle to spawn. (default: "car")'},
  description = 'Function. Spawns a fueled car next to you.',
  f = function(name)
    local p = env.p
    local car = p.surface.create_entity{
      name  = name or 'car',
      force = p.force,
      position = p.surface.find_non_colliding_position('car',p.position,32*2,1,true) or p.position,
      }
    --find best fuel
    local best   = {fuel_value = 0, name = 'none'}
    local burner = car.burner
    for _,item in pairs(game.item_prototypes) do
      if (burner.fuel_categories[item.fuel_category])
       and (item.fuel_value > best.fuel_value) then
        best = item end
      end
    if best.name ~= 'none' then
      -- car.get_fuel_inventory().insert{name=best.name,count=best.stack_size} --don't want item spam
      car.burner.currently_burning      = best
      car.burner.remaining_burning_fuel = best.fuel_value
      end
    end
  }

Function {
  names = {'serpl','spl','sline','say'},
  call = '(table,options)',
  usage =  {
    '@table: the table to print',
    '@options: serpent options, default: "{comment=false,compact=true,nocode=true}"'
    },
  equivalent = 'serpent.line(tbl,options)',
  description = 'Function. Prints a serpent representation of a table in-game and to the console. You can choose between line and block modes.',
  f = function(tbl,args)
    return serpent.line (tbl,args or {comment=false,compact=true,nocode=true})
    end,
  }
    
Function {
  names = {'serpb','spb','sblock','tell'},
  call = '(table,options)',
  usage =  func.serpl.usage,
  equivalent = 'serpent.block(tbl,options)',
  description = 'Function. Prints a serpent representation of a table in-game and to the console. You can choose between line and block modes.',
  f = function(tbl,args)
    local msg = serpent.block (tbl,args or {comment=false,compact=true,nocode=true})
    -- Print(env.p,msg)
    return msg
    end,
  }
    
Function {
  names = {'get_power_per_cycle'},
  call = '(entity_with_recipe,beacon_consumption)',
  usage = {
    '@entity_with_recipe: a LuaEntity',
    '@beacon_consumption: Integer. The combined beacon consumption for this machine in Watt (Joule per second).',
    },
  description = 'Calculates how much one recipe cycle costs for a given machine, including all module effects. A cycle is complete when Progress + Productivity = 100%',
  f = function(entity_with_recipe,beacon_consumption)

    beacon_consumption = tonumber(beacon_consumption) or 0
    if not (entity_with_recipe and entity_with_recipe.valid) then
      env.p.print('no entity given.') return end

    local this = entity_with_recipe
    local prot = this.prototype
    local recipe = this.get_recipe()
    if not recipe then env.p.print('<'..this.name..'> has no recipe set.') return end
    
    local bonus_speed        = ((this.effects or {}) .speed        or {}).bonus or 0
    local bonus_productivity = ((this.effects or {}) .productivity or {}).bonus or 0
    local bonus_consumption  = ((this.effects or {}) .consumption  or {}).bonus or 0
    local crafting_speed = this.prototype.crafting_speed
    local energy         = recipe.energy
    local consumption    = this.prototype.energy_usage
    local drain          = this.prototype.electric_energy_source_prototype.drain or 0
    
    --in seconds
    local cycle_length     = energy * (1/(crafting_speed + bonus_speed)) * (1/(1+bonus_productivity))
    local power_per_second = 60 * consumption * (1+bonus_consumption) + beacon_consumption + drain
    
    env.p.print(string.format('<%s> consumes %.2fMJ per cycle.',this.name,cycle_length*power_per_second/1000^2))
    
    end
  }
    
Function { names = {'destroy_entities_filtered'},
  call = '(filter)',
  usage = {'@filter: a find_entities_filtered compatible table of filters'},
  equivalent =  'for _,v in pairs(surface.find_entities_filtered(filter)) do v.destroy() end',
  description = 'Function. Destroys all entities matching the filter.',
  f = function(filter)
    for _,v in pairs(env.s.find_entities_filtered(filter)) do v.destroy() end
    end
  }
      
Function { names = {'find'},
  call = '(find_entities_filtered_args)',
  usage = {'See API Doc → LuaSurface.find_entities_filtered'},
  equivalent = 'game.player.surface.find_entities_filtered',
  description = 'Shortcut. Returns a list of found entities',
  }
      
Function { names = {'purge_console','clear_console'},
  equivalent = 'game.player.clear_console',
  description = 'Shortcut. Clears the visible console history.',
  }
      
Function { names = {'spawn_creative_chests'},
  description = 'Function. Spawns a bunch of infinity chests containing all available items.',
  f = function()
    local p = env.p
    local s = env.s
    local chest_name = 'infinity-chest'
    local slot_count = game.entity_prototypes[chest_name]
      .get_inventory_size(defines.inventory.chest)
    local rows = math.ceil(math.sqrt(#game.item_prototypes/slot_count))
    local function is_allowed(item)
      if item.type ~= 'mining-tool' then return true end
      end
    local i,chest,inv,filters = 0
    for _,iprot in pairs(game.item_prototypes) do; i = i+1
      if i%slot_count == 1 then
        chest = p.surface.create_entity{
          name = chest_name,
          position = {
            (p.position.x)+(math.floor((i-1)/slot_count)) % rows + 1,
            (p.position.y)+ math.floor(i/(rows*slot_count)) },
          force = p.force,
          }
        chest.remove_unfiltered_items = true
        filters = chest.infinity_container_filters
        inv = chest.get_inventory(defines.inventory.chest)
        end
      if is_allowed(iprot) then
        local slot_index = (i-1)%slot_count+1
        filters[slot_index] = {
          name=iprot.name,
          count=iprot.stack_size,
          mode='exactly',
          index=slot_index
          }
        inv[slot_index].set_stack(filters[slot_index])
        chest.infinity_container_filters = filters --this *might* be the last item!
        end
      end
    end
  }
  
Function {
  names = {'blip'},
  call = '(target,duration,args)',
  usage = {
    '@target: LuaEntity or Position (default: p.selected or it). Center of the circle.',
    '@duration: Integer (default: 5 seconds). After how many ticks this is auto-removed.',
    '@args: additional rendering args that will override default values',
    '@return 1: @target for conveniet chaining.',
    '@return 2: the rendering id',
    },
  equivalent = 'rendering.draw_circle(args)',
  description = 'Draws a short-lived random-colored circle.',
  f = function (target,duration,args)
    local rnd = function() return math.random(100,255) end
    local def = {
      color = {r=rnd(),g=rnd(),b=rnd()},
      radius = 0.2,
      filled = true,
      target = target or env.that or env.it,
      time_to_live = duration or 300,
      surface = (type(target) == 'table' and target.__self and target.surface) or env.s,
      }
    for k,v in pairs(args or {}) do if v~=nil then def[k]=v end end
    return target,rendering.draw_circle(def) end
  }
  
Function { -- copy/pasted from erlib.Misc
  names = {'help_to_table'},
  call  = '(LuaObject)',
  usage = {
    '@LuaObeject: Any factorio LuaObject that supports the .help() method. Which should be all of them by now',
    },
  description = 'Dissects the string returned by help() and returns an easily read/printable lua table.',
  f = function(obj)   
    local is_lua_object,help = pcall(function() return obj.help() end)
    if not is_lua_object then return nil end
    local class = help:match'Help for%s([^:]*)' --LuaSomethingObject
    local methods = {}
    for line in help:match'[\r\n]Methods:([^:]+)[\r\n]+%a*:?':gmatch('[^\r\n]+') do
      methods[line:match'([%a_]+)'] = true
      end
    local values = {}
    for line in help:match'[\r\n]Values:([^:]+)[\r\n]+%a*:?':gmatch('[^\r\n]+') do
      local name,r,w = line:match'([%a_]+)%s+%[(R?)(W?)%]'
      values[name] = {read=(r ~= '') and true or nil,write=(w ~= '') and true or nil}
      end
    return {class = class, methods = methods, values = values}
    end
  }
  
  
Function {
  names = {'deep_value_analysis'},
  call  = ('LuaObject'),
  usage = {
    '@LuaObeject: Any factorio LuaObject that supports the .help() method. Which should be all of them by now',
    },
  description = 'Similar to help_to_table() but only for values, not methods. Instead of giving out a table it tries to assign each value to itself and reports all results to the terminal.',
  f = function(obj)
    local results = {[true]={},[false]={}}
    local n = 0
    for k,v in pairs(env.help_to_table(obj).values) do
      if v.read and v.write then
        local ok,status = pcall(function() obj[k] = obj[k] end)
        results[ok][#results[ok]+1] = {k,status or ''}
        n = (#k > n) and #k or n
        end
      end
    print('#####################',game.tick)
    local function prtl(key,ok,err)
      err = (err and err:match'(.*)%s+stack traceback' or (err:gsub('\n',''))) or ''
      print(("'%s'%"..(n-#key).."s, | %-8s | %s"):format(key,'',ok,err))
      end
    prtl('Key','Writable','Error Message')
    -- print('Key'                                          | Success | Error Message
    print(('-'):rep(72))
    for ok,_ in pairs(results) do for _,dat in pairs(results[ok]) do
      prtl(dat[1],ok,dat[2])
      end end
    print('end of analysis')
    end
  }
  
  
        
---- FUNCTIONS (Platinum) --------------------------------------------------------------------------

Platinum_Function {
  names = {'generate_seperator'},
  call = '(word,seperator,length,count)',
  usage = nil,
  description = 'Function. Generates a string seperator for code decoration.',
  f = function(word,seperator,length,count)
    local seperator = seperator or '-'
    local length    = length    or 96 --90 or 96 have 12 divisors and a good length
    local count     = count     or 3
    local word      = ' '..word..' ' --better readability withspaces
    if (length % count) ~= 0 then
      print('>>>SUDO: Requested string length is not evenly divisable by count!')
      return
      end
    local  segment_length    = length/count
    local  first_half_length = math.floor((segment_length-#word)/2)
    local second_half_length = math.ceil ((segment_length-#word)/2)
    --multi-character seperators *can* be done if the numbers *happen* to match
    --otherwise it'll just error?
    local  first_half = string.rep(seperator,math.floor( first_half_length/#seperator))
    local second_half = string.rep(seperator,math.ceil (second_half_length/#seperator))
    local output = '--'..string.rep(first_half .. word .. second_half, count)
    -- print(output) --superseeded by in-game gui auto-selection
    env.center.clear()
    local x = env.center.add{type='textfield',text=output}
    x.style.width  = 1200
    x.style.height =  64
    x.focus()
    x.select_all()
    end
  }
        
---- FUNCTIONS (Platinum / UGLY HACKS) -------------------------------------------------------------
        
Platinum_Function {
  names = {'remove_events','remove_all_events','unregister','unregister_all'},
  equivalent =  'script.on_event(defines.events,nil)',
  description = 'Removes *all* event handlers in the current lua state.',
  f = function()
    script.on_event(defines.events,nil)
    for i=1,1000 do script.on_nth_tick(i,nil) end
    end,
  }
  
Platinum_Function {
  names = {'energize'},
  description = 'Provides powers to *every currently existing* entity on the current surface. This is an extremely CPU heavy on_tick handler that will destroy your UPS when used on anything but small testing maps.',
  f = function()
    local x = env.s.find_entities_filtered{
      type={'assembling-machine','inserter','furnace'}}
    local function f () for i=1,#x do x[i].energy = 1e7 end end
    env.p.print('Energizing! (Warning, this is *extremely* CPU consuming. Disable with "remove_events()".')
    script.on_event(defines.events.on_tick,function()
      --pcalling this allows us to terminate when the first entity
      --becomes invalid (mined, destroyed) without the overhead of checking
      --*every* entity for .valid (which would be ~20% overhead).
      if not pcall(f) then
        script.on_event(defines.events.on_tick,nil)
        env.p.print('Energization terminated!')
        end
      end)
    end
  }
  
Platinum_Function {
  names = {'on_event','append_event'},
  call = '(events,handler)',
  usage = {
    '@events: a table of event names/indexes.',
    '@handler: the handler function',
    },
  equivalent = nil,
  description = 'Adds a new handler to @events *without* deleting the old handlers',
  f = function(events,handler)
    local function is_event_valid(e)
      for _,v in pairs(e) do
        if type(v) == 'table' and v.valid == false then return false end
        end
      return true
      end
    for _,ename in pairs((type(events)=='table') and events or {events}) do 
      local f = script.get_event_handler(ename)
      script.on_event(ename,function(e)
        f(util.table.deepcopy(e))
        if is_event_valid(e) then handler(e) end
        end)
      end
    end
  }

Platinum_Function {
  names = {'speed'},
  call = '(number)',
  usage = {'@number: how fast?'},
  equivalent = 'game.speed = number',
  description = 'Changes game simulation speed.',
  f = function(number) game.speed = number end,
  }
  
Platinum_Function {
  names = {'walk'},
  call = '(number)',
  usage = {'@number: how fast?'},
  equivalent = nil,
  description = 'Changes how fast you move on foot.',
  f = function(number)
    if env.it then env.p.character_running_speed_modifier = number end
    end,
  }
  
Platinum_Function {
  names = {'on_every_event'},
  call = '(event_handler)',
  usage = {
    '@event_handler: function.',
    'See also API Doc → script.on_event().'
    },
  equivalent = 'script.on_event(defines.events)',
  description = 'Attaches a handler to all events *except* on_tick and on_chunk_generated',
  f = function(handler)
    local blacklist = {on_tick = true,on_chunk_generated = true}
    local events = {}
    for name,id in pairs(defines.events) do
      if not blacklist[name] then events[#events+1] = id end
      end
    script.on_event(events,handler)
    end,
  }

---- UNASSOCIAZED HELP ENTRIES ---------------------------------------------------------------------
 
Help {
  names = {'FAQ'},
    description = [[

Q: What is /sudo?
A: /sudo is a command line helper utilty that aims to make common tasks easier by injecting certain shortcuts into the environment before it executes your commands.

Q: Is there anything different from /c?
A: Yes. Most importantly /sudo will automatically print any values returned by your command, so you do not have to type game.player.print() all the time. Further IF the returned value is a function /sudo will attempt to call that function without arguments, this is mostly intended for /sudos own helper functions like "/sudo cheat" instaed of "/sudo cheat(true)".

Q: I got a desync!
A: That is not a question. /sudo is not meant to be used in multiplayer environments. (As long as you don't use global variables it *might* work anyway.)

Q: Can you give me some examples?
A: Examples are at the top of this list.
    ]],
    }
    
Help {
  names = {'Example1'},
  examples = {'"/sudo whatis(5,that)"'},
  description = 'will print the name and counts of whatever your mouse is selecting right now.',
  }
Help {
  names = {'Example2'},
  examples = {'"/sudo destroy(that)"'},
  description = 'will destroy what you have selected.',
  }
Help {
  names = {'Example3'},
  examples = {'"/sudo x = my.surface.find_entities_filtered{area=around(here,10)}"'},
  description = 'will store all entities found in a 10 tile radius around your current position into a variable x. The variable is volatile and does not persist after loading a savegame.',
  }
Help {
  names = {'Example4'},
  examples = {'"/sudo dev"'},
  description = 'will give you a buch of stuff for quick testing of new entities.',
  }
  
Help {
  names = {'util'},
  equivalent = 'require("util")',
  description = 'Table. Standard factorio util library.',
  }
  
---- BUILD HELP DATABASE ---------------------------------------------------------------------------

local function format_tooltip(def)
  local tip = {add=function(self,...) for _,x in pairs{...} do self[#self+1] = x end return self end}
  if def.names then
    tip:add'Usage:\n'
    for _,name in pairs(def.names) do
      tip:add('  ',name,(def.isfunc) and (def.call or '()') or '','\n')
      end
    end
  if def.equivalent then
    tip:add('\nMeaning:\n  ',def.equivalent,'\n')
    end
  if def.usage then
    tip:add'\nArguments:\n'
    for _,param in pairs(def.usage) do tip:add('  ',param,'\n') end
    end
  if def.examples then
    tip:add'\nExamples:\n'
    for _,example in pairs(def.examples) do tip:add('  ',example,'\n') end
    end
  if def.description then
    tip:add('\nDescription:\n  ',def.description)
    end
  return table.concat(tip,''):match"^%s*(.-)%s*$" --remove leading/trailing whitespace
  end

for _,def in pairs(help.tutorial) do
  --TODO: make better formatted tooltips for this
  def.tip = format_tooltip(def)
  -- def.tip = format_tooltip(def):match'(Description.*)'
  end
  
for _,tbl in pairs{dyn,func} do for name,def in pairs(tbl) do
  help.dict[name] = def
  help.list[#help.list+1] = name
  def.tip = format_tooltip(def)
  end end
table.sort(help.list)

---- HELP ------------------------------------------------------------------------------------------
local function is_help_open()
  return not not env.center['er:sudo:help-frame']
  end

local function close_help_gui()
  if is_help_open() then env.center['er:sudo:help-frame'].destroy() end
  end
  
local function open_help_gui()

  --check preexisting
  close_help_gui()

  --create frame
  local frame = env.center.add{type='frame',name='er:sudo:help-frame'}
  local pane  = frame     .add{type='scroll-pane',horizontal_scroll_policy='never'}
  local w,h = math.max(env.p.display_resolution.width * 0.3,300), env.p.display_resolution.height * 0.6
  frame.style.width  = w
  frame.style.height = h
  pane .style.width  = w - 20 --best guess border width offset
  pane .style.height = h - 60
  
  --fill frame
  local sudo_command_name = 'sudo' --TODO: fetch properly
  frame.caption = 'Eradicators /sudo HELP (use "/'..(SUDO__CMD_NAME or '?')..' help()" to close this dialogue.)'

  for i=1,#help.tutorial do
    local def = help.tutorial[i]
    local name = '['..def.names[1]..']'
    local caption = name .. ((def.isfunc) and (def.call or '()') or '')
    local box = pane.add{type='frame',tooltip=def.tip}
    local lbl = box .add{type='label',caption=caption,tooltip=def.tip}
    lbl.style.width =  w - 70    
    end
  
  for _,name in pairs(help.list) do
    local def = help.dict[name]
    local caption = name .. ((def.isfunc) and (def.call or '()') or '')
    local box = pane.add{type='frame',tooltip=def.tip}
    local lbl = box .add{type='label',caption=caption,tooltip=def.tip}
    lbl.style.width =  w - 70
    end
  
  end

  
Function {
  --word: nil or string
  --      string -> print help to console (help text or command name candidates)
  --      nil    -> open help dialogue
  names = {'help'},
  call = '(word)',
  usage = {
    '@word: nil | full function name | partial function name',
    },
  description = nil,
  f = function(word)
  
    if is_help_open() then --close previous help dialogue
      close_help_gui()
  
    elseif (not word) or (word == '') then --open help window
      -- env.p.print('help window not implemented')
      print('close')
      close_help_gui()
      open_help_gui()
  
    elseif word == 'list' then --print list
      Print(env.p,table.concat(help.list,', '))
    
    elseif help.dict[word] then --precise name
      -- Print(env.p,'help for ' .. word ..' not implemented')
      Print(env.p,help.dict[word].tip)
      
    elseif type(word) ~= 'string' then
      Print(env.p,'Help: Search term must be a string or nil.')
    
    else --find similar
      local hits = {}
      for _,name in pairs(help.list) do if name:find(word) then hits[#hits+1] = name end end
      if #hits == 0 then
        Print(env.p,('No help found for "%s"'):format(word))
        print(serpent.line(hits))
      elseif #hits == 1 then
        Print(env.p,help.dict[hits[1]].tip)
        
      else
        Print(env.p,'Found: ' .. table.concat(hits,', '))
        end
    
      end
  
    -- if word and word ~= '' then
    
  
  
    end,
  }

---- MAIN ------------------------------------------------------------------------------------------

--@str: a loadable string
--@name: the chunk name
--@env: the environment to load in (NOT the sudo 'env')
--@return1: nil or a function
--@return2: nil or the error message
local function Load (str,name,env)
  local f,err = load(str,name,'t',env)
  if err then return nil,err,nil end
  return f,nil,nil
  end
  
--@return1: nil or a *(sparse) array* containing the return values (the table may be empty)
--@return2: nil or the error message
--@return3: nil or the number of return values
local function Call(f)
  local ok,r,n = (function(x,...) return x,{...},select('#',...) end)(pcall(f))
  if not ok then return nil,r[1] or '<error message was nil>',nil end
  return r, nil, n
  end

local Repr = {
  ['nil'     ] = function( ) return '<nil>'      end,
  ['function'] = function( ) return '<function>' end,
  ['userdata'] = function( ) return '<userdata>' end,
  ['number'  ] = function(x) return tostring(x)  end,
  ['boolean' ] = function(x) return tostring(x)  end,
  ['string'  ] = function(x) return ('"%s"'):format(x) end,
  ['table'   ] = function(x)
    local y = serpent.line(x,{comment=false,nocode=true})
    if y == '{__self = "userdata"}' then return '{<userdata>}' end
    return y end,
  }

-- local Sudo = function(e)
local Sudo = function(p,text_chunk)

  --paranoia mode (store reference on first usage)
  game = game or _ENV.game
  if not (p and type(p) == 'table' and type(p.__self) == 'userdata' and p.valid) then return end

  --check privileges
  -- local p = game.players[e.player_index]
  if not p.admin then p.print('Only admins are allowed to use sudo.') return end

  --skip empty input (e.parameter is nil when there's only whitespace)
  if type(text_chunk) ~= 'string' then return end
  if text_chunk:match"^%s*(.-)%s*$" == nil then return end --TODO: or help list?

  --is this a help request? → yes → print help and exit | → no → do nothing
  if (text_chunk:sub(1,4) == 'help')
   and (text_chunk:sub(5,5):match'[^%s]*' == '') then --space or empty string after "help"
    env.help(text_chunk:sub(6)) return
    end
    
  --close help gui if help function was not explicitly called
  if not text_chunk:find('help%s*[%(['.."'"..'"]') then --find help command with ",',[,( 
    close_help_gui()
    end

  --try load
  local       f,err = Load('return '..text_chunk,'User Input (auto return)',_ENV)
  if err then f,err = Load(           text_chunk,'User Input (auto return)',_ENV) end
  if err then p.print('Syntax error: '   ..err) return end
  
  --clear
  if SUDO__ALWAYS_CLEAR then p.clear_console() end
  
  --try call
  local results,err,n = Call(f)
  if err then p.print('Execution error: '..err) return end
  
  --prepare pretty printing
  local repr = {}
  for i=1,n do
    local r  = results[i]
    local tr = type(r)
    if tr == 'function' and (not SUDO__NO_AUTO_CALL) then
      local results,err,n = Call(r)
      if err then repr[#repr+1] = ('Result %s: Auto-Execution Error: %s'):format(i,err)
      elseif #results == 0 then repr[#repr+1] = ('Result %s: (Function auto-executed)'):format(i)
      else repr[#repr+1] = ('Result %s: (Function auto-executed): %s'):format(i,Repr.table(results)) end
    elseif r ~= nil then
      repr[#repr+1] = ('Result %s: %s'):format(i,Repr[type(r)](r))
      end
    end
    
  --print
  if #repr == 0 then
    print('<sudo command returned nil' .. ((n < 2) and '>' or (' (%s times)>'):format(n)))
  else
    if n == 1 then repr[1] = repr[1]:sub(10) end --remove "Result 1:" for single results
    for i=1,#repr do Print(p,repr[i]) end
    if n > #repr then Print(p,('[Result Count: %s]'):format(n)) end --some results were nil
    end

  end
  
return function(name)
  SUDO__CMD_NAME = name
  return Sudo
  end

