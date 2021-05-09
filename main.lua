

--[[ Welcome to the "Shitty Unmaintaind Development Obstructor"
  
  # What is this?
    + An achievement-safe lua command executer like /c, with added comfort features.
  
  # QUIRKS:
    ! storing global variables is NOT desync safe the same way standard /c commands is also NOT safe.
      this is on purpose to not pollute the savegame data with random junk
      
  # Restrictions:
    ! /sudo aims to be a *command line* helper, as such it does NOT offer:
      - player settings
      - selection tools
      - desync protection
      - any event based functionality (to keep it simple)
      - protection from shooting yourself in the foot with malicious/outdated/obscene code snippets from reddit.
      
  ]]


local This = {}

---- SETTINGS --------------------------------------------------------------------------------------
This.settings = function()
  data:extend{{
    name = 'er:sudo-command-name',
    type = 'string-setting',
    setting_type  = 'startup',
    default_value = '/sudo',
    order = 'zzz',
    }}
  end

---- CONTROL ---------------------------------------------------------------------------------------
--this control wrapper only manages registering the function as a named command

This.control = function()
    
  --get custom command name (without the initial '/')
  local sudo_name        = settings.startup['er:sudo-command-name'].value:sub(2,-1)
  local sudo_description = 'Makes you no sandwich.'
  
  --the main function is self contained
  --it processes all input and produces all output
  local sudo = require('__eradicators-sudo__/sudo.lua')(sudo_name)
  local sudo_wrapper = function(e)
    -- local p = game.players[e.player_index]
    -- sudo(p,e.parameter,print,p.print) --future: make sudo not print anything on it's own to support more usecases
    sudo(game.players[e.player_index],e.parameter,nil,nil)
    end

  --user forgot to prefix with slash or is stupid
  if #sudo_name == 0 then
    error('\n\n'                                                             ..
          '################################################################' ..
          '\n\n'                                                             ..
          "INVALID MOD OPTION: Eradicator's Sudo command name is too short." ..
          '\n\n'                                                             ..
          '(default: "/sudo")'                                               ..
          '\n\n'                                                             ..
          '################################################################' ..
          '\n\n'
          )

  --pcall is the easiest way to detect collisions with internal commands like /c or /help
  --because these are not reported by commands.commands
  -- elseif not pcall(commands .add_command,sudo_name,sudo_description,sudo) then
  elseif not pcall(commands .add_command,sudo_name,sudo_description,sudo_wrapper) then
    error('\n\n'                                                             ..
          '################################################################' ..
          '\n\n'                                                             ..
          "Eradicator's /sudo could not register it's command because \n"    ..
          'there is already a command named "'..sudo_name..'".\n'            ..
          '\n'                                                               ..
          'Try changing the command name in the mod settings.'               ..
          '\n\n'                                                             ..
          '################################################################' ..
          '\n\n'
          )
    end
  
  end
  
return This