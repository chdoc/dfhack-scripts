local options = {}

local argparse = require('argparse')
local commands = argparse.processArgsGetopt({ ... }, {
    { 'd', 'dead', handler = function() options.dead = true end }
})

local dialogs = require 'gui.dialogs'

local viewscreen = dfhack.gui.getDFViewscreen(true)
if viewscreen._type ~= df.viewscreen_setupadventurest then
    qerror("This script can only be used during adventure mode setup!")
end

--luacheck: in=df.viewscreen_setupadventurest,df.nemesis_record
function addNemesisToUnretireList(advSetUpScreen, nemesis, index)
    local unretireOption = false
    for i = #advSetUpScreen.valid_race - 1, 0, -1 do
        if advSetUpScreen.valid_race[i] == -2 then -- this is the "Specific Person" option on the menu
            unretireOption = true
            break
        end
    end

    if not unretireOption then
        advSetUpScreen.valid_race:insert('#', -2)
    end

    -- Revive the historical figure
    local histFig = nemesis.figure
    if histFig.died_year >= -1 then
        histFig.died_year = -1
        histFig.died_seconds = -1
    end

    nemesis.flags.ADVENTURER = true
    -- nemesis.id and df.global.world.nemesis.all index should *usually* align but there may be bugged scenarios where they don't.
    -- This is a workaround for the issue by using the vector index rather than nemesis.id
    advSetUpScreen.nemesis_index:insert('#', index)
end

--luacheck: in=table
function showNemesisPrompt(advSetUpScreen)
    local choices = {}
    for i, nemesis in ipairs(df.global.world.nemesis.all) do
        if nemesis.figure and not nemesis.flags.ADVENTURER then -- these are already available for unretiring
            local histFig = nemesis.figure
            local histFlags = histFig.flags
            if (histFig.died_year == -1 or histFlags.ghost or options.dead) and
                not histFlags.deity and
                not histFlags.force
            then
                local creature = df.creature_raw.find(histFig.race).caste[histFig.caste]
                local name = creature.caste_name[0]
                if histFig.info and histFig.info.curse then
                    local curse = histFig.info.curse
                    if curse.name ~= '' then
                        name = name .. ' ' .. curse.name
                    end
                    if curse.undead_name ~= '' then
                        name = curse.undead_name .. " - reanimated " .. name
                    end
                end
                if histFlags.ghost then
                    name = name .. " ghost"
                end
                local sym = df.pronoun_type.attrs[creature.sex].symbol
                if sym then
                    name = name .. ' (' .. sym .. ')'
                end
                if histFig.name.has_name then
                    name = name .. dfhack.TranslateName(histFig.name) ..
                         "\n\"" .. dfhack.TranslateName(histFig.name, true) .. "\""
                end
                name = name .. ' [nemid:'.. nemesis.id ..']'
                table.insert(choices, { text = name, nemesis = nemesis, search_key = name:lower() })
            end
        end
    end
    dialogs.showListPrompt('unretire-anyone', "Select someone to add to the \"Specific Person\" list:", COLOR_WHITE,
        choices, function(id, choice)
            addNemesisToUnretireList(advSetUpScreen, choice.nemesis, i)
        end, nil, nil, true)
end

showNemesisPrompt(viewscreen)
