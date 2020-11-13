--[==[

Copyright ©2020 Samuel Thomas Pain

The contents of this addon, excluding third-party resources, are
copyrighted to their authors with all rights reserved.

This addon is free to use and the authors hereby grants you the following rights:

1. 	You may make modifications to this addon for private use only, you
    may not publicize any portion of this addon.

2. 	Do not modify the name of this addon, including the addon folders.

3. 	This copyright notice shall be included in all copies or substantial
    portions of the Software.

All rights not explicitly addressed in this license are reserved by
the copyright holders.

]==]--

local addonName, Guildbook = ...

local build = 3.3
local locale = GetLocale()

local AceComm = LibStub:GetLibrary("AceComm-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate")
local LibSerialize = LibStub:GetLibrary("LibSerialize")

---------------------------------------------------------------------------------------------------------------------------------------------------------------
--debug printers
---------------------------------------------------------------------------------------------------------------------------------------------------------------
function Guildbook.DEBUG(msg)
    if GUILDBOOK_GLOBAL and GUILDBOOK_GLOBAL['Debug'] then
        print(tostring('|cffC41F3BGB-DEBUG: '..msg))
    end
end

function Guildbook.DEBUG_COMMS(msg)
    if GUILDBOOK_GLOBAL and GUILDBOOK_GLOBAL['Debug'] then
        print(tostring('|cff0070DEGB-COMMS: '..msg))
    end
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------
--variables
---------------------------------------------------------------------------------------------------------------------------------------------------------------
local L = Guildbook.Locales
local DEBUG = Guildbook.DEBUG
local DEBUG_COMMS = Guildbook.DEBUG_COMMS

Guildbook.FONT_COLOUR = '|cff0070DE'
Guildbook.PlayerMixin = nil
Guildbook.GuildBankCommit = {
    Commit = nil,
    Character = nil,
}


---------------------------------------------------------------------------------------------------------------------------------------------------------------
--slash commands
---------------------------------------------------------------------------------------------------------------------------------------------------------------
SLASH_GUILDHELPERCLASSIC1 = '/guildbook'
SlashCmdList['GUILDBOOK'] = function(msg)
    if msg == '-help' then
        print(':(')

    elseif msg == '-scanbank' then
        Guildbook:ScanCharacterContainers()

    end
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------
--init
---------------------------------------------------------------------------------------------------------------------------------------------------------------
function Guildbook:Init()
    DEBUG('running init')
    
    local version = GetAddOnMetadata('Guildbook', "Version")

    self.ContextMenu_DropDown = CreateFrame("Frame", "GuildbookContextMenu", UIParent, "UIDropDownMenuTemplate")
    self.ContextMenu = {}

    AceComm:Embed(self)
    self:RegisterComm(addonName, 'ON_COMMS_RECEIVED')

    --create stored variable tables
    if GUILDBOOK_GLOBAL == nil or GUILDBOOK_GLOBAL == {} then
        GUILDBOOK_GLOBAL = self.Data.DefaultGlobalSettings
        DEBUG('created global saved variable table')
    else
        DEBUG('global variables exists')
    end
    if GUILDBOOK_CHARACTER == nil or GUILDBOOK_CHARACTER == {} then
        GUILDBOOK_CHARACTER = self.Data.DefaultCharacterSettings
        DEBUG('created character saved variable table')
    else
        DEBUG('character variables exists')
    end
    --added later
    if not GUILDBOOK_GLOBAL['GuildRosterCache'] then
        GUILDBOOK_GLOBAL['GuildRosterCache'] = {}
    end
    if GUILDBOOK_GLOBAL['Build'] == nil then
        GUILDBOOK_GLOBAL['Build'] = 0
    end
    if tonumber(GUILDBOOK_GLOBAL['Build']) < build then
        GUILDBOOK_GLOBAL['Build'] = build
        StaticPopup_Show('GuildbookUpdates', version, Guildbook.News[build])
    end
    -- added later again
    if not GUILDBOOK_GLOBAL['Calendar'] then
        GUILDBOOK_GLOBAL['Calendar'] = {}
    end
    if not GUILDBOOK_GLOBAL['CalendarDeleted'] then
        GUILDBOOK_GLOBAL['CalendarDeleted'] = {}
    end
    if not GUILDBOOK_GLOBAL['LastCalendarTransmit'] then
        GUILDBOOK_GLOBAL['LastCalendarTransmit'] = GetServerTime()
    end
    if not GUILDBOOK_GLOBAL['LastCalendarDeletedTransmit'] then
        GUILDBOOK_GLOBAL['LastCalendarDeletedTransmit'] = GetServerTime()
    end

    local ldb = LibStub("LibDataBroker-1.1")
    self.MinimapButton = ldb:NewDataObject('GuildbookMinimapIcon', {
        type = "data source",
        icon = 134939,
        OnClick = function(self, button)
            if button == "LeftButton" then
                if InterfaceOptionsFrame:IsVisible() then
                    InterfaceOptionsFrame:Hide()
                else
                    InterfaceOptionsFrame_OpenToCategory(addonName)
                    InterfaceOptionsFrame_OpenToCategory(addonName)
                end
            elseif button == 'RightButton' then
                ToggleFriendsFrame(3)
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine(tostring('|cff0070DE'..addonName))
            tooltip:AddDoubleLine('|cffffffffLeft Click|r Options')
            tooltip:AddDoubleLine('|cffffffffRight Click|r Guild')
        end,
    })
    self.MinimapIcon = LibStub("LibDBIcon-1.0")
    if not GUILDBOOK_GLOBAL['MinimapButton'] then GUILDBOOK_GLOBAL['MinimapButton'] = {} end
    self.MinimapIcon:Register('GuildbookMinimapIcon', self.MinimapButton, GUILDBOOK_GLOBAL['MinimapButton'])
    -- used a timer here for some reason to force hiding
    C_Timer.After(1, function()
        if GUILDBOOK_GLOBAL['ShowMinimapButton'] == false then
            self.MinimapIcon:Hide('GuildbookMinimapIcon')
            DEBUG('minimap icon saved var setting: false, hiding minimap button')
        end
    end)

    GuildbookOptionsMainSpecDD_Init()
    GuildbookOptionsOffSpecDD_Init()

    --the OnShow event doesnt fire for the first time the options frame is shown? set the values here
    -- these are all xml define widgets - REMOVE at some point?
    if GUILDBOOK_CHARACTER and GUILDBOOK_GLOBAL then
        UIDropDownMenu_SetText(GuildbookOptionsMainSpecDD, GUILDBOOK_CHARACTER['MainSpec'])
        UIDropDownMenu_SetText(GuildbookOptionsOffSpecDD, GUILDBOOK_CHARACTER['OffSpec'])
        GuildbookOptionsMainCharacterNameInputBox:SetText(GUILDBOOK_CHARACTER['MainCharacter'])
        GuildbookOptionsMainSpecIsPvpSpecCB:SetChecked(GUILDBOOK_CHARACTER['MainSpecIsPvP'])
        GuildbookOptionsOffSpecIsPvpSpecCB:SetChecked(GUILDBOOK_CHARACTER['OffSpecIsPvP'])
        GuildbookOptionsDebugCB:SetChecked(GUILDBOOK_GLOBAL['Debug'])
        GuildbookOptionsShowMinimapButton:SetChecked(GUILDBOOK_GLOBAL['ShowMinimapButton'])

        if GUILDBOOK_CHARACTER['AttunementsKeys'] then
            GuildbookOptionsAttunementKeysUBRS:SetChecked(GUILDBOOK_CHARACTER['AttunementsKeys']['UBRS'])
            GuildbookOptionsAttunementKeysMC:SetChecked(GUILDBOOK_CHARACTER['AttunementsKeys']['MC'])
            GuildbookOptionsAttunementKeysONY:SetChecked(GUILDBOOK_CHARACTER['AttunementsKeys']['ONY'])
            GuildbookOptionsAttunementKeysBWL:SetChecked(GUILDBOOK_CHARACTER['AttunementsKeys']['BWL'])
            GuildbookOptionsAttunementKeysNAXX:SetChecked(GUILDBOOK_CHARACTER['AttunementsKeys']['NAXX'])
        end
    end

    -- allow time for loading and whats nots, then send character data
    C_Timer.After(3, function()
        --Guildbook:SendCharacterStats()
        Guildbook:CharacterStats_OnChanged()
    end)

    -- set up delays for calendar data syncing to prevent mass chat spam on log in
    C_Timer.After(5, function()
        Guildbook:SendGuildCalendarEvents()
    end)
    C_Timer.After(10, function()
        Guildbook:SendGuildCalendarDeletedEvents()
    end)
    C_Timer.After(15, function()
        Guildbook:RequestGuildCalendarEvents()
    end)
    C_Timer.After(20, function()
        Guildbook:RequestGuildCalendarDeletedEvents()
    end)

end


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Guildbook:GetGuildName()
    local guildName = false
    if IsInGuild() and GetGuildInfo("player") then
        local guildName, _, _, _ = GetGuildInfo('player')
        return guildName
    end
end

function Guildbook:ScanCharacterContainers()
    if BankFrame:IsVisible() then
        local guid = UnitGUID('player')
        if not self.PlayerMixin then
            self.PlayerMixin = PlayerLocation:CreateFromGUID(guid)
        else
            self.PlayerMixin:SetGUID(guid)
        end
        if self.PlayerMixin:IsValid() then
            local name = C_PlayerInfo.GetName(self.PlayerMixin)

            if not GUILDBOOK_CHARACTER['GuildBank'] then
                GUILDBOOK_CHARACTER['GuildBank'] = {
                    [name] = {
                        Data = {},
                        Commit = GetServerTime()
                    }
                }
            else
                GUILDBOOK_CHARACTER['GuildBank'][name] = {
                    Commit = GetServerTime(),
                    Data = {},
                }
            end

            -- player bags
            for bag = 0, 4 do
                for slot = 1, GetContainerNumSlots(bag) do
                    local id = select(10, GetContainerItemInfo(bag, slot))
                    local count = select(2, GetContainerItemInfo(bag, slot))
                    if id and count then
                        if not GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] then
                            GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] = count
                        else
                            GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] = GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] + count
                        end
                    end
                end
            end

            -- main bank
            for slot = 1, 28 do
                local id = select(10, GetContainerItemInfo(-1, slot))
                local count = select(2, GetContainerItemInfo(-1, slot))
                if id and count then
                    if not GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] then
                        GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] = count
                    else
                        GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] = GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] + count
                    end
                end
            end

            -- bank bags
            for bag = 5, 11 do
                for slot = 1, GetContainerNumSlots(bag) do
                    local id = select(10, GetContainerItemInfo(bag, slot))
                    local count = select(2, GetContainerItemInfo(bag, slot))
                    if id and count then
                        if not GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] then
                            GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] = count
                        else
                            GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] = GUILDBOOK_CHARACTER['GuildBank'][name].Data[id] + count
                        end
                    end
                end
            end

            local bankUpdate = {
                type = 'GUILD_BANK_DATA_RESPONSE',
                payload = {
                    Data = GUILDBOOK_CHARACTER['GuildBank'][name].Data,
                    Commit = GUILDBOOK_CHARACTER['GuildBank'][name].Commit,
                    Bank = name,
                }
            }
            self:Transmit(bankUpdate, 'GUILD', sender, 'BULK')
            DEBUG_COMMS('sending guild bank data due to new commit')
        end
    end
end

function Guildbook:ScanTradeSkill()
    local prof = GetTradeSkillLine()
    GUILDBOOK_CHARACTER[prof] = {}
    for i = 1, GetNumTradeSkills() do
        local name, type, _, _, _, _ = GetTradeSkillInfo(i)
        if (name and type ~= "header") then
            local itemLink = GetTradeSkillItemLink(i)
            local itemID = select(1, GetItemInfoInstant(itemLink))
            local itemName = select(1, GetItemInfo(itemID))
            DEBUG(string.format('|cff0070DETrade item|r: %s, with ID: %s', name, itemID))
            if itemName and itemID then
                GUILDBOOK_CHARACTER[prof][itemID] = {}
            end
            local numReagents = GetTradeSkillNumReagents(i);
            if numReagents > 0 then
                for j = 1, numReagents, 1 do
                    local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(i, j)
                    local reagentLink = GetTradeSkillReagentItemLink(i, j)
                    local reagentID = select(1, GetItemInfoInstant(reagentLink))
                    if reagentName and reagentID and reagentCount then
                        DEBUG(string.format('    Reagent name: %s, with ID: %s, Needed: %s', reagentName, reagentID, reagentCount))
                        GUILDBOOK_CHARACTER[prof][itemID][reagentID] = reagentCount
                    end
                end
            end
        end
    end
end

function Guildbook:ScanCraftSkills_Enchanting()
    local currentCraftingWindow = GetCraftSkillLine(1)
    if currentCraftingWindow == 'Enchanting' then
        GUILDBOOK_CHARACTER['Enchanting'] = {}
        for i = 1, GetNumCrafts() do
            local name, _, type, _, _, _, _ = GetCraftInfo(i)
            if (name and type ~= "header") then
                local itemID = select(7, GetSpellInfo(name))
                DEBUG(string.format('|cff0070DETrade item|r: %s, with ID: %s', name, itemID))
                if itemID then
                    GUILDBOOK_CHARACTER['Enchanting'][itemID] = {}
                end
                local numReagents = GetCraftNumReagents(i);
                DEBUG(string.format('this recipe has %s reagents', numReagents))
                if numReagents > 0 then
                    for j = 1, numReagents do
                        local reagentName, reagentTexture, reagentCount, playerReagentCount = GetCraftReagentInfo(i, j)
                        local reagentLink = GetCraftReagentItemLink(i, j)
                        if reagentName and reagentCount then
                            DEBUG(string.format('reagent number: %s with name %s and count %s', j, reagentName, reagentCount))
                            if reagentLink then
                                local reagentID = select(1, GetItemInfoInstant(reagentLink))
                                DEBUG('reagent id: '..reagentID)
                                if reagentID and reagentCount then
                                    GUILDBOOK_CHARACTER['Enchanting'][itemID][reagentID] = reagentCount
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end


--- scan the characters current guild cache and check for any characters with name/class/spec data not matching guid data
function Guildbook:CleanUpGuildRosterData(guild)
    if GUILDBOOK_GLOBAL and GUILDBOOK_GLOBAL.GuildRosterCache[guild] then
        print(string.format('%s Guildbook|r, scanning roster for %s', Guildbook.FONT_COLOUR, guild))
        local currentGUIDs = {}
        local totalMembers, onlineMembers, _ = GetNumGuildMembers()
        for i = 1, totalMembers do
            local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            currentGUIDs[guid] = true
        end
        for guid, info in pairs(GUILDBOOK_GLOBAL.GuildRosterCache[guild]) do
            if not currentGUIDs[guid] then
                GUILDBOOK_GLOBAL.GuildRosterCache[guild][guid] = nil
                print(string.format('removed %s from roster cache', info.Name))
            else
                if not self.PlayerMixin then
                    self.PlayerMixin = PlayerLocation:CreateFromGUID(guid)
                else
                    self.PlayerMixin:SetGUID(guid)
                end
                if self.PlayerMixin:IsValid() then
                    local _, class, _ = C_PlayerInfo.GetClass(self.PlayerMixin)
                    local name = C_PlayerInfo.GetName(self.PlayerMixin)
                    if name and class then
                        if info.Class ~= class then
                            print(name..' has error with class, updating class to mixin value')
                            info.Class = class
                        end
                        if info.Name ~= name then
                            print(name..' has error with name, updating name to mixin value')
                            info.Name = name
                        end
                        local ms = false
                        if info.MainSpec ~= '-' then
                            for _, spec in pairs(Guildbook.Data.Class[class].Specializations) do
                                if info.MainSpec == spec then
                                    ms = true
                                end
                            end
                        elseif info.MainSpec == '-' then
                            ms = true
                        end
                        if ms == false then
                            print(name..' has error with main spec, setting to default')
                            info.MainSpec = '-'
                        end
                        local os = false
                        if info.OffSpec ~= '-' then
                            for _, spec in pairs(Guildbook.Data.Class[class].Specializations) do
                                if info.OffSpec == spec then
                                    os = true
                                end
                            end
                        elseif info.OffSpec == '-' then
                            os = true
                        end
                        if os == false then
                            print(name..' has error with off spec, setting to default')
                            info.OffSpec = '-'
                        end
    
                    end
                end
            end
        end
    end
end

function Guildbook:CleanUpCharacterSettings()
    if GUILDBOOK_CHARACTER then
        if GUILDBOOK_CHARACTER['UNKNOWN'] then
            GUILDBOOK_CHARACTER['UNKNOWN'] = nil
        end
    end
end

function Guildbook.GetProfessionData()
    local myCharacter = { Fishing = 0, Cooking = 0, FirstAid = 0, Prof1 = '-', Prof1Level = 0, Prof2 = '-', Prof2Level = 0 }
    for s = 1, GetNumSkillLines() do
        local skill, _, _, level, _, _, _, _, _, _, _, _, _ = GetSkillLineInfo(s)
        if Guildbook.GetEnglish[locale][skill] == 'Fishing' then 
            myCharacter.Fishing = level
            --DEBUG(string.format('Found %s skill, level: %s', skill, level))
        elseif Guildbook.GetEnglish[locale][skill] == 'Cooking' then
            myCharacter.Cooking = level
            --DEBUG(string.format('Found %s skill, level: %s', skill, level))
        elseif Guildbook.GetEnglish[locale][skill] == 'First Aid' then
            myCharacter.FirstAid = level
            --DEBUG(string.format('Found %s skill, level: %s', skill, level))
        else
            for k, prof in pairs(Guildbook.Data.Profession) do
                --DEBUG(string.format('Prof %s - skill %s', prof.Name, skill))
                if prof.Name == Guildbook.GetEnglish[locale][skill] then
                    if myCharacter.Prof1 == '-' then
                        myCharacter.Prof1 = Guildbook.GetEnglish[locale][skill]
                        myCharacter.Prof1Level = level
                        --DEBUG(string.format('Prof %s matches skill %s, level: %s', prof.Name, skill, level))
                    elseif myCharacter.Prof2 == '-' then
                        myCharacter.Prof2 = Guildbook.GetEnglish[locale][skill]
                        myCharacter.Prof2Level = level
                        --DEBUG(string.format('Prof %s matches skill %s, level: %s', prof.Name, skill, level))
                    end
                end
            end
        end
    end
    if GUILDBOOK_CHARACTER then
        GUILDBOOK_CHARACTER['Profession1'] = myCharacter.Prof1
        GUILDBOOK_CHARACTER['Profession1Level'] = myCharacter.Prof1Level
        --DEBUG('Set player Profession1 as: '..myCharacter.Prof1)
        GUILDBOOK_CHARACTER['Profession2'] = myCharacter.Prof2
        GUILDBOOK_CHARACTER['Profession2Level'] = myCharacter.Prof2Level
        --DEBUG('Set player Profession2 as: '..myCharacter.Prof2)
    end
end

function Guildbook.GetInstanceInfo()
    local t = {}
    if GetNumSavedInstances() > 0 then
        for i = 1, GetNumSavedInstances() do
            local name, id, reset, difficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)
            tinsert(t, { Name = name, ID = id, Resets = date('*t', tonumber(GetTime() + reset)) })
        end
    end
    return t
end

function Guildbook.GetItemLevel()
    local character, itemlevel, itemCount = {}, 0, 0
	for k, slot in ipairs(Guildbook.Data.InventorySlots) do
		character[slot.Name] = GetInventoryItemID('player', slot.Id)
		if character[slot.Name] ~= nil then
			local iName, iLink, iRarety, ilvl = GetItemInfo(character[slot.Name])
			itemlevel = itemlevel + ilvl
			itemCount = itemCount + 1
		end
	end	
	return math.floor(itemlevel/itemCount)
end

function Guildbook:IsGuildMemberOnline(info)
    local guildName = Guildbook:GetGuildName()
    if guildName then
        local totalMembers, onlineMembers, _ = GetNumGuildMembers()
        for i = 1, totalMembers do
            local name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(i)
            if isOnline and info == guid then
                return true
            end
        end
    end
end

function Guildbook:Transmit(data, channel, target, priority)
    local serialized = LibSerialize:Serialize(data);
    local compressed = LibDeflate:CompressDeflate(serialized);
    local encoded    = LibDeflate:EncodeForWoWAddonChannel(compressed);
    self:SendCommMessage(addonName, encoded, channel, target, priority);
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- tradeskills comms
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Guildbook:SendTradeSkillsRequest(target, profession)
    local request = {
        type = "TRADESKILLS_REQUEST",
        payload = profession,
    }
    self:Transmit(request, "WHISPER", target, "NORMAL")
    DEBUG_COMMS(string.format('sent request for %s from %s', profession, target))
end

function Guildbook:OnTradeSkillsRequested(request, distribution, sender)
    if distribution ~= "WHISPER" then
        return
    end
    if GUILDBOOK_CHARACTER and GUILDBOOK_CHARACTER[request.payload] then
        local response = {
            type    = "TRADESKILLS_RESPONSE",
            payload = {
                profession = request.payload,
                recipes = GUILDBOOK_CHARACTER[request.payload],
            }
        }
        self:Transmit(response, distribution, sender, "BULK")
        DEBUG_COMMS(string.format('sending %s data to %s', request.payload, sender))
    end
end

function Guildbook:OnTradeSkillsReceived(data, distribution, sender)
    if data.payload.profession and type(data.payload.recipes) == 'table' then
        C_Timer.After(4.0, function()
            local guildName = Guildbook:GetGuildName()
            if guildName and GUILDBOOK_GLOBAL['GuildRosterCache'][guildName] then
                for guid, character in pairs(GUILDBOOK_GLOBAL['GuildRosterCache'][guildName]) do
                    if character.Name == sender then                
                        character[data.payload.profession] = data.payload.recipes
                        DEBUG_COMMS('set: '..character.Name..' prof: '..data.payload.profession)
                    end
                end
            end
            self.GuildFrame.TradeSkillFrame.RecipesTable = data.payload.recipes
        end)
    else
        -- this is due to older data format, if we get this we wont save as the prof name isnt sent
        -- will remove this support after 1 update
        -- C_Timer.After(4.0, function()
        --     self.GuildFrame.TradeSkillFrame.RecipesTable = data.payload
        -- end)
        print('You have an outdated version, please download the latest version.')
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- character data comms
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Guildbook:CharacterDataRequest(target)
    local request = {
        type = 'CHARACTER_DATA_REQUEST'
    }
    self:Transmit(request, 'WHISPER', target, 'NORMAL')
end

-- limited to once per minute to reduce chat spam
local characterStatsLastSent = -math.huge
function Guildbook:CharacterStats_OnChanged()
    if characterStatsLastSent + 60.0 < GetTime() then
        local d = self:GetCharacterDataPayload()
        if type(d) == 'table' and d.payload.GUID then
            self:Transmit(d, 'GUILD', sender, 'NORMAL')
            DEBUG_COMMS('CharacterStats_OnChanged > GUILD')
        end
        characterStatsLastSent = GetTime()
    else
        DEBUG(string.format('character stats not sent, wait %s', (characterStatsLastSent + 60.0 - GetTime())))
    end
end

function Guildbook:GetCharacterDataPayload()
    local guid = UnitGUID('player')
    local level = UnitLevel('player')
    local ilvl = self:GetItemLevel()
    self.GetProfessionData()
    if not self.PlayerMixin then
        self.PlayerMixin = PlayerLocation:CreateFromGUID(guid)
    else
        self.PlayerMixin:SetGUID(guid)
    end
    if self.PlayerMixin:IsValid() then
        local _, class, _ = C_PlayerInfo.GetClass(self.PlayerMixin)
        local name = C_PlayerInfo.GetName(self.PlayerMixin)
        local response = {
            type = 'CHARACTER_DATA_RESPONSE',
            payload = {
                GUID = guid,
                Level = level,
                ItemLevel = ilvl,
                Class = class,
                Name = name,
                Profession1Level = GUILDBOOK_CHARACTER["Profession1Level"],
                OffSpec = GUILDBOOK_CHARACTER["OffSpec"],
                Profession1 = GUILDBOOK_CHARACTER["Profession1"],
                MainCharacter = GUILDBOOK_CHARACTER["MainCharacter"],
                MainSpec = GUILDBOOK_CHARACTER["MainSpec"],
                MainSpecIsPvP = GUILDBOOK_CHARACTER["MainSpecIsPvP"],
                Profession2Level = GUILDBOOK_CHARACTER["Profession2Level"],
                Profession2 = GUILDBOOK_CHARACTER["Profession2"],
                AttunementsKeys = GUILDBOOK_CHARACTER["AttunementsKeys"],
                Availability = GUILDBOOK_CHARACTER["Availability"],
                OffSpecIsPvP = GUILDBOOK_CHARACTER["OffSpecIsPvP"],
            }
        }
        return response
    end
end

function Guildbook:OnCharacterDataRequested(request, distribution, sender)
    if distribution ~= 'WHISPER' then
        return
    end
    local d = self:GetCharacterDataPayload()
    if type(d) == 'table' and d.payload.GUID then
        self:Transmit(d, 'WHISPER', sender, 'NORMAL')
        DEBUG_COMMS('OnCharacterDataRequested, > WHISPER='..sender)
    end
end

function Guildbook:OnCharacterDataReceived(data, distribution, sender)
    local guildName = self:GetGuildName()
    if guildName then
        if not GUILDBOOK_GLOBAL.GuildRosterCache[guildName] then
            GUILDBOOK_GLOBAL.GuildRosterCache[guildName] = {}
        end
        if not GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID] then
            GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID] = {}
        end
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].Level = tonumber(data.payload.Level)
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].ItemLevel = tonumber(data.payload.ItemLevel)
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].Class = data.payload.Class
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].Name = data.payload.Name
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].Profession1Level = tonumber(data.payload.Profession1Level)
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].OffSpec = data.payload.OffSpec
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].Profession1 = data.payload.Profession1
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].MainCharacter = data.payload.MainCharacter
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].MainSpec = data.payload.MainSpec
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].MainSpecIsPvP = data.payload.MainSpecIsPvP
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].Profession2Level = tonumber(data.payload.Profession2Level)
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].Profession2 = data.payload.Profession2
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].AttunementsKeys = data.payload.AttunementsKeys
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].Availability = data.payload.Availability
        GUILDBOOK_GLOBAL['GuildRosterCache'][guildName][data.payload.GUID].OffSpecIsPvP = data.payload.OffSpecIsPvP
        DEBUG_COMMS(string.format('OnCharacterDataReceived > sender=%s', data.payload.Name))
        C_Timer.After(1, function()
            Guildbook:UpdateGuildMemberDetailFrame(data.payload.GUID)
        end)        
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- guild bank comms
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Guildbook:SendGuildBankCommitRequest(bankCharacter)
    local request = {
        type = 'GUILD_BANK_COMMIT_REQUEST',
        payload = bankCharacter,
    }
    self:Transmit(request, 'GUILD', nil, 'NORMAL')
    DEBUG_COMMS(string.format('SendGuildBankCommitRequest > character=%s', bankCharacter))
end

function Guildbook:OnGuildBankCommitRequested(data, distribution, sender)
    if distribution == 'GUILD' then
        if GUILDBOOK_CHARACTER['GuildBank'] and GUILDBOOK_CHARACTER['GuildBank'][data.payload] and GUILDBOOK_CHARACTER['GuildBank'][data.payload].Commit then
            local response = {
                type = 'GUILD_BANK_COMMIT_RESPONSE',
                payload = { 
                    Commit = GUILDBOOK_CHARACTER['GuildBank'][data.payload].Commit,
                    Character = data.payload
                }
            }
            self:Transmit(response, 'WHISPER', sender, 'NORMAL')
            DEBUG_COMMS(string.format('OnGuildBankCommitRequested > character=%s, commit=%s', data.payload, GUILDBOOK_CHARACTER['GuildBank'][data.payload].Commit))
        end
    end
end

function Guildbook:OnGuildBankCommitReceived(data, distribution, sender)
    if distribution == 'WHISPER' then
        DEBUG_COMMS(string.format('Received a commit for bank character %s from %s - commit time: %s', data.payload.Character, sender, data.payload.Commit))
        if Guildbook.GuildBankCommit['Commit'] == nil then
            Guildbook.GuildBankCommit['Commit'] = data.payload.Commit
            Guildbook.GuildBankCommit['Character'] = sender
            Guildbook.GuildBankCommit['BankCharacter'] = data.payload.Character
            DEBUG_COMMS(string.format('First response added to temp table, %s->%s', sender, data.payload.Commit))
        else
            if tonumber(data.payload.Commit) > tonumber(Guildbook.GuildBankCommit['Commit']) then
                Guildbook.GuildBankCommit['Commit'] = data.payload.Commit
                Guildbook.GuildBankCommit['Character'] = sender
                Guildbook.GuildBankCommit['BankCharacter'] = data.payload.Character
                DEBUG_COMMS(string.format('Response commit is newer than temp table commit, updating info - %s->%s', sender, data.payload.Commit))
            end
        end
    end
end

function Guildbook:SendGuildBankDataRequest()
    if Guildbook.GuildBankCommit['Character'] ~= nil then
        local request = {
            type = 'GUILD_BANK_DATA_REQUEST',
            payload = Guildbook.GuildBankCommit['BankCharacter']
        }
        self:Transmit(request, 'WHISPER', Guildbook.GuildBankCommit['Character'], 'NORMAL')
        DEBUG_COMMS(string.format('Sending request for guild bank data to %s for bank character %s', Guildbook.GuildBankCommit['Character'], Guildbook.GuildBankCommit['BankCharacter']))
    end
end

function Guildbook:OnGuildBankDataRequested(data, distribution, sender)
    if distribution == 'WHISPER' then
        local response = {
            type = 'GUILD_BANK_DATA_RESPONSE',
            payload = {
                Data = GUILDBOOK_CHARACTER['GuildBank'][data.payload].Data,
                Commit = GUILDBOOK_CHARACTER['GuildBank'][data.payload].Commit,
                Bank = data.payload,
            }
        }
        self:Transmit(response, 'WHISPER', sender, 'BULK')
        DEBUG_COMMS('Sending guild bank data to: '..sender..' as requested')
    end
end

function Guildbook:OnGuildBankDataReceived(data, distribution, sender)
    if distribution == 'WHISPER' or distribution == 'GUILD' then
        if not GUILDBOOK_CHARACTER['GuildBank'] then
            GUILDBOOK_CHARACTER['GuildBank'] = {
                [data.payload.Bank] = {
                    Commit = data.payload.Commit,
                    Data = data.payload.Data,
                }
            }
        else
            GUILDBOOK_CHARACTER['GuildBank'][data.payload.Bank] = {
                Commit = data.payload.Commit,
                Data = data.payload.Data,
            }
        end
    end
    self.GuildFrame.GuildBankFrame:ProcessBankData(data.payload.Data)
    self.GuildFrame.GuildBankFrame:RefreshSlots()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- calendar data comms
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local calDelay = 120.0

function Guildbook:RequestGuildCalendarDeletedEvents(event)
    local calendarEvents = {
        type = 'GUILD_CALENDAR_EVENTS_DELETED_REQUESTED',
        payload = '-',
    }
    self:Transmit(calendarEvents, 'GUILD', nil, 'NORMAL')
    DEBUG_COMMS('Sending calendar events deleted request')
end

function Guildbook:RequestGuildCalendarEvents(event)
    local calendarEventsDeleted = {
        type = 'GUILD_CALENDAR_EVENTS_REQUESTED',
        payload = '-',
    }
    self:Transmit(calendarEventsDeleted, 'GUILD', nil, 'NORMAL')
    DEBUG_COMMS('Sending calendar events request')
end

function Guildbook:SendGuildCalendarEvent(event)
    local calendarEvent = {
        type = 'GUILD_CALENDAR_EVENT_CREATED',
        payload = event,
    }
    self:Transmit(calendarEvent, 'GUILD', nil, 'NORMAL')
    DEBUG_COMMS(string.format('Sending calendar event to guild, event title: %s', event.title))
end

function Guildbook:OnGuildCalendarEventCreated(data, distribution, sender)
    DEBUG_COMMS(string.format('Received a calendar event created from %s', sender))
    local guildName = Guildbook:GetGuildName()
    if guildName then
        if not GUILDBOOK_GLOBAL['Calendar'] then
            GUILDBOOK_GLOBAL['Calendar'] = {
                [guildName] = {},
            }
        else
            if not GUILDBOOK_GLOBAL['Calendar'][guildName] then
                GUILDBOOK_GLOBAL['Calendar'][guildName] = {}
            end
        end
        local exists = false
        for k, event in pairs(GUILDBOOK_GLOBAL['Calendar'][guildName]) do
            if event.created == data.payload.created then
                exists = true
                DEBUG_COMMS('this event already exists in your db')
            end
        end
        if exists == false then
            table.insert(GUILDBOOK_GLOBAL['Calendar'][guildName], data.payload)
            DEBUG_COMMS(string.format('Received guild calendar event, title: %s', data.payload.title))
        end
    end
end

function Guildbook:SendGuildCalendarEventAttend(event, attend)
    local calendarEvent = {
        type = 'GUILD_CALENDAR_EVENT_ATTEND',
        payload = {
            e = event,
            a = attend,
            guid = UnitGUID('player'),
        },
    }
    self:Transmit(calendarEvent, 'GUILD', nil, 'NORMAL')
    DEBUG_COMMS(string.format('Sending calendar event attend update to guild, event title: %s, attend: %s', event.title, attend))
end

function Guildbook:OnGuildCalendarEventAttendReceived(data, distribution, sender)
    local guildName = Guildbook:GetGuildName()
    if guildName and GUILDBOOK_GLOBAL['Calendar'][guildName] then
        for k, v in pairs(GUILDBOOK_GLOBAL['Calendar'][guildName]) do
            if v.created == data.payload.e.created and v.owner == data.payload.e.owner then
                v.attend[data.payload.guid] = {
                    ['Updated'] = GetServerTime(),
                    ['Status'] = tonumber(data.payload.a),
                }
                DEBUG_COMMS(string.format('Updated event: %s attend, data from %s, attend: %s', v.title, sender, data.payload.a))
            end
        end
    end
    C_Timer.After(1, function()
        Guildbook.GuildFrame.GuildCalendarFrame.EventFrame:UpdateAttending()
    end)
end

function Guildbook:SendGuildCalendarEventDeleted(event)
    local calendarEventDeleted = {
        type = 'GUILD_CALENDAR_EVENT_DELETED',
        payload = event,
    }
    self:Transmit(calendarEventDeleted, 'GUILD', nil, 'NORMAL')
    DEBUG_COMMS(string.format('Sending calendar event deleted to guild, event title: %s', event.title))
end

function Guildbook:OnGuildCalendarEventDeleted(data, distribution, sender)
    self.GuildFrame.GuildCalendarFrame.EventFrame:RegisterEventDeleted(data.payload)
    DEBUG_COMMS('OnGuildCalendarEventDeleted > event='..data.payload.title)
    C_Timer.After(1, function()
        Guildbook.GuildFrame.GuildCalendarFrame.EventFrame:RemoveDeletedEvents()
    end)
end


-- this will be restricted to only send events that fall within a month, this should reduce chat spam
-- it is further restricted to send not within 2 minutes of previous send
function Guildbook:SendGuildCalendarEvents()
    local today = date('*t')
    local future = date('*t', (time(today) + (60*60*24*28)))
    local events = {}
    if GetServerTime() > GUILDBOOK_GLOBAL['LastCalendarTransmit'] + 120.0 then
        local guildName = Guildbook:GetGuildName()
        if guildName and GUILDBOOK_GLOBAL['Calendar'][guildName] then
            for k, event in pairs(GUILDBOOK_GLOBAL['Calendar'][guildName]) do
                if event.date.month >= today.month and event.date.year >= today.year and event.date.month <= future.month and event.date.year <= future.year then
                    table.insert(events, event)
                    --DEBUG_COMMS(string.format('Added event: %s to this months sending table', event.title))
                end
            end
            local calendarEvents = {
                type = 'GUILD_CALENDAR_EVENTS',
                payload = events,
            }
            self:Transmit(calendarEvents, 'GUILD', nil, 'BULK')
            DEBUG_COMMS(string.format('SendGuildCalendarEvents > range=%s-%s-%s to %s-%s-%s', today.day, today.month, today.year, future.day, future.month, future.year))
        end
        GUILDBOOK_GLOBAL['LastCalendarTransmit'] = GetServerTime()
    end
end

function Guildbook:OnGuildCalendarEventsReceived(data, distribution, sender)
    DEBUG_COMMS(string.format('Received calendar events from %s', sender))
    local guildName = Guildbook:GetGuildName()
    if guildName and GUILDBOOK_GLOBAL['Calendar'][guildName] then
        for k, event in ipairs(data.payload) do
            DEBUG_COMMS(string.format('Scanning events received, event: %s', event.title))
            local exists = false
            for _, e in pairs(GUILDBOOK_GLOBAL['Calendar'][guildName]) do
                if e.created == event.created and e.owner == event.owner then
                    exists = true
                    DEBUG_COMMS('    event exists!')

                    -- check and update attend
                    for guid, info in pairs(e.attend) do
                        if tonumber(info.Updated) < event.attend[guid].Updated then
                            info.Status = event.attend[guid].Status
                            info.Updated = event.attend[guid].Updated
                            DEBUG_COMMS('Updated attend status for event: '..event.title)
                        end
                    end
                end
            end
            if exists == false then
                table.insert(GUILDBOOK_GLOBAL['Calendar'][guildName], event)
                DEBUG_COMMS(string.format('This event is a new event, adding to db: %s', event.title))
            end
        end
    end
end

function Guildbook:SendGuildCalendarDeletedEvents()
    DEBUG_COMMS('Sending calendar deleted events')
    if GetServerTime() > GUILDBOOK_GLOBAL['LastCalendarDeletedTransmit'] + 120.0 then
        local guildName = Guildbook:GetGuildName()
        if guildName and GUILDBOOK_GLOBAL['CalendarDeleted'][guildName] then
            local calendarDeletedEvents = {
                type = 'GUILD_CALENDAR_DELETED_EVENTS',
                payload = GUILDBOOK_GLOBAL['CalendarDeleted'][guildName],
            }
            self:Transmit(calendarDeletedEvents, 'GUILD', nil, 'BULK')
            DEBUG_COMMS('Sending deleted calendar events to guild')
        end
        GUILDBOOK_GLOBAL['LastCalendarDeletedTransmit'] = GetServerTime()
    end
end


function Guildbook:OnGuildCalendarEventsDeleted(data, distribution, sender)
    DEBUG_COMMS(string.format('Received calendar events deleted from %s', sender))
    local guildName = Guildbook:GetGuildName()
    if guildName and GUILDBOOK_GLOBAL['CalendarDeleted'][guildName] then
        for k, v in pairs(data.payload) do
            if not GUILDBOOK_GLOBAL['CalendarDeleted'][guildName][k] then
                GUILDBOOK_GLOBAL['CalendarDeleted'][guildName][k] = true
                DEBUG_COMMS('Added event to deleted table')
            end
        end
    end
    self.GuildFrame.GuildCalendarFrame.EventFrame:RemoveDeletedEvents()
end

-- TODO: add script for when a player drops a prof
SkillDetailStatusBarUnlearnButton:HookScript('OnClick', function()

end)


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- soft reserve
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Guildbook:RequestRaidSoftReserves()
    local request = {
        type = 'RAID_SOFT_RESERVES_REQUEST',
    }
    self:Transmit(request, 'RAID', nil, 'NORMAL')
    DEBUG_COMMS('Sent a request on RAID channel for soft reserves')
end

function Guildbook:OnRaidSoftReserveRequested(data, distribution, sender)
    if GUILDBOOK_CHARACTER and GUILDBOOK_CHARACTER['SoftReserve'] then
        local response = {
            type = 'RAID_SOFT_RESERVE_RESPONSE',
            payload = GUILDBOOK_CHARACTER['SoftReserve'],
        }
        self:Transmit(response, 'RAID', nil, 'NORMAL')
        DEBUG_COMMS('Soft reserve response sent')
    end
end

function Guildbook:OnRaidSoftReserveReceived(data, distribution, sender)
    DEBUG_COMMS('Soft reserve response receieved from: '..sender)
    if self.GuildFrame.SoftReserveFrame.SelectedRaid ~= nil then
        if data.payload and data.payload[self.GuildFrame.SoftReserveFrame.SelectedRaid] then
            DEBUG_COMMS(string.format('%s has a soft reserved %s for %s', sender, data.payload[self.GuildFrame.SoftReserveFrame.SelectedRaid], self.GuildFrame.SoftReserveFrame.SelectedRaid))
            for i = 1, 40 do
                name, _, _, level, class, fileName, _, online, _, role, isML, _ = GetRaidRosterInfo(i)
                -- this may not be quite right check for realms (name-realm)
                if name and (name == sender) then
                    self.GuildFrame.SoftReserveFrame.RaidRosterList[i].data = {
                        Character = name,
                        ItemID = tonumber(data.payload[self.GuildFrame.SoftReserveFrame.SelectedRaid]),
                        Class = fileName,
                    }
                    self.GuildFrame.SoftReserveFrame.RaidRosterList[i]:Show()
                end
            end
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- events
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Guildbook:ADDON_LOADED(...)
    if tostring(...):lower() == addonName:lower() then
        self:Init()
    end
end

function Guildbook:TRADE_SKILL_UPDATE()
    C_Timer.After(1, function()
        DEBUG('trade skill update, scanning skills')
        self:ScanTradeSkill()
    end)
end

function Guildbook:CRAFT_UPDATE()
    C_Timer.After(1, function()
        DEBUG('craft skill update, scanning skills')
        self:ScanCraftSkills_Enchanting()
    end)
end

function Guildbook:PLAYER_ENTERING_WORLD()
    self:ModBlizzUI()
    self:SetupStatsFrame()
    self:SetupTradeSkillFrame()
    self:SetupGuildBankFrame()
    self:SetupGuildCalendarFrame()
    self:SetupGuildMemberDetailframe()
    self:SetupSoftReserveFrame()
    --self:SetupProfilesFrame()
    self.EventFrame:UnregisterEvent('PLAYER_ENTERING_WORLD')
end

function Guildbook:RAID_ROSTER_UPDATE()
    DEBUG('Raid roster update event')
    self:RequestRaidSoftReserves()
end


function Guildbook:GUILD_ROSTER_UPDATE(...)
    -- print('roster update')
    -- if GuildMemberDetailFrame:IsVisible() then     
    --     local name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID = GetGuildRosterInfo(GetGuildRosterSelection())
    --     print('>>>', name, isOnline)
    --     if isOnline then
    --         -- Guildbook:UpdateGuildMemberDetailFrameLabels()
    --         -- Guildbook:ClearGuildMemberDetailFrame()
    --         -- Guildbook:CharacterDataRequest(name)
    --     end
    -- end
end

function Guildbook:PLAYER_LEVEL_UP()
    C_Timer.After(3, function()
        Guildbook:CharacterStats_OnChanged()
    end)
end

function Guildbook:SKILL_LINES_CHANGED()
    C_Timer.After(3, function()
        Guildbook:CharacterStats_OnChanged()
    end)
end

-- added to automate the guildl bank scan
function Guildbook:BANKFRAME_OPENED()
    for i = 1, GetNumGuildMembers() do
        local _, _, _, _, _, _, publicNote, _, _, _, _, _, _, _, _, _, GUID = GetGuildRosterInfo(i)
        if publicNote:lower():find('guildbank') and GUID == UnitGUID('player') then
            self:ScanCharacterContainers()
        end
    end
end

--- handle comms
-- create a 10 sec period between request responses to reduce chat spam
local tradeDelay, bankDelay = 10, 10
local lastTradeSkillRequest = {}
local lastGuildBankRequest = {}
function Guildbook:ON_COMMS_RECEIVED(prefix, message, distribution, sender)
    if prefix ~= addonName then 
        return 
    end
    local decoded = LibDeflate:DecodeForWoWAddonChannel(message);
    if not decoded then
        return;
    end
    local decompressed = LibDeflate:DecompressDeflate(decoded);
    if not decompressed then
        return;
    end
    local success, data = LibSerialize:Deserialize(decompressed);
    if not success or type(data) ~= "table" then
        return;
    end

    if data.type == "TRADESKILLS_REQUEST" then
        if not lastTradeSkillRequest[sender] then
            lastTradeSkillRequest[sender] = -math.huge
        end
        if lastTradeSkillRequest[sender] + tradeDelay < GetTime() then
            self:OnTradeSkillsRequested(data, distribution, sender)
            lastTradeSkillRequest[sender] = GetTime()
        else
            local remaining = string.format("%.1d", (lastTradeSkillRequest[sender] + tradeDelay - GetTime()))
            DEBUG(string.format('please allow 10 secs between requests, %d seconds remaining', remaining))
        end

    elseif data.type == "TRADESKILLS_RESPONSE" then
        self:OnTradeSkillsReceived(data, distribution, sender);

    elseif data.type == 'CHARACTER_DATA_REQUEST' then
        self:OnCharacterDataRequested(data, distribution, sender)

    elseif data.type == 'CHARACTER_DATA_RESPONSE' then
        self:OnCharacterDataReceived(data, distribution, sender)

    elseif data.type == 'GUILD_BANK_COMMIT_REQUEST' then
        self:OnGuildBankCommitRequested(data, distribution, sender)

    elseif data.type == 'GUILD_BANK_COMMIT_RESPONSE' then
        self:OnGuildBankCommitReceived(data, distribution, sender)

    elseif data.type == 'GUILD_BANK_DATA_REQUEST' then
        if not lastGuildBankRequest[sender] then
            lastGuildBankRequest[sender] = -math.huge
        end
        if lastGuildBankRequest[sender] + bankDelay < GetTime() then
            self:OnGuildBankDataRequested(data, distribution, sender)
            lastGuildBankRequest[sender] = GetTime()
        end

    elseif data.type == 'GUILD_BANK_DATA_RESPONSE' then
        self:OnGuildBankDataReceived(data, distribution, sender)

    elseif data.type == 'RAID_SOFT_RESERVES_REQUEST' then
        self:OnRaidSoftReserveRequested(data, distribution, sender)

    elseif data.type == 'RAID_SOFT_RESERVE_RESPONSE' then
        self:OnRaidSoftReserveReceived(data, distribution, sender)

    elseif data.type == 'GUILD_CALENDAR_EVENT_CREATED' then
        self:OnGuildCalendarEventCreated(data, distribution, sender)

    elseif data.type == 'GUILD_CALENDAR_EVENTS' then
        self:OnGuildCalendarEventsReceived(data, distribution, sender)

    elseif data.type == 'GUILD_CALENDAR_EVENT_DELETED' then
        self:OnGuildCalendarEventDeleted(data, distribution, sender)

    elseif data.type == 'GUILD_CALENDAR_DELETED_EVENTS' then
        self:OnGuildCalendarEventsDeleted(data, distribution, sender)

    elseif data.type == 'GUILD_CALENDAR_EVENT_ATTEND' then
        self:OnGuildCalendarEventAttendReceived(data, distribution, sender)

    elseif data.type == 'GUILD_CALENDAR_EVENTS_REQUESTED' then
        local today = date('*t')
        self:SendGuildCalendarEvents()

    elseif data.type == 'GUILD_CALENDAR_EVENTS_DELETED_REQUESTED' then
        self:SendGuildCalendarDeletedEvents()

    end
end


--set up event listener
Guildbook.EventFrame = CreateFrame('FRAME', 'GuildbookEventFrame', UIParent)
Guildbook.EventFrame:RegisterEvent('GUILD_ROSTER_UPDATE')
Guildbook.EventFrame:RegisterEvent('ADDON_LOADED')
Guildbook.EventFrame:RegisterEvent('PLAYER_LEVEL_UP')
Guildbook.EventFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
Guildbook.EventFrame:RegisterEvent('SKILL_LINES_CHANGED')
Guildbook.EventFrame:RegisterEvent('TRADE_SKILL_UPDATE')
Guildbook.EventFrame:RegisterEvent('CRAFT_UPDATE')
Guildbook.EventFrame:RegisterEvent('RAID_ROSTER_UPDATE')
Guildbook.EventFrame:RegisterEvent('BANKFRAME_OPENED')
Guildbook.EventFrame:SetScript('OnEvent', function(self, event, ...)
    --DEBUG('EVENT='..tostring(event))
    Guildbook[event](Guildbook, ...)
end)