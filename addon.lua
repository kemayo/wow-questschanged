local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

local icon = LibStub("LibDBIcon-1.0", true)

ns.VIGNETTES = C_EventUtils.IsEventValid("VIGNETTE_MINIMAP_UPDATED")

local db, dbpc
local quests = {}
local new_quests = {}
local new_quests_byid = {}
local session_quests = {}
ns.quests_completed = {}

ns.WARBANDS_ICON = CreateAtlasMarkup("warbands-icon", 16, 16)
ns.CROSS_ICON = CreateAtlasMarkup("common-icon-redx", 16, 16)

local SPAM_QUESTS = {
    [32468] = true, -- Crystal Clarity
    [32469] = true, -- Crystal Clarity
}

local Callbacks = CreateFrame("EventFrame")
Callbacks:SetUndefinedEventsAllowed(true)
Callbacks:SetScript("OnEvent", function(self, event, ...)
    self:TriggerEvent(event, event, ...)
end)
Callbacks:RegisterEvent("ADDON_LOADED")
Callbacks:Hide()
ns.Callbacks = Callbacks

Callbacks:GenerateCallbackEvents{
    "OnQuestAdded", "OnQuestRemoved", "OnAllQuestsRemoved",
    "OnVignetteAdded", "OnVignetteRemoved", "OnAllVignettesRemoved",
    "OnPingAdded", "OnPingRemoved", "OnAllPingsRemoved",
}
ns.Event = Callbacks.Event

-- help out with callback boilerplate:
function ns:RegisterCallback(event, func)
    if not func and ns[event] then func = ns[event] end
    if not Callbacks:DoesFrameHaveEvent(event) then
        Callbacks:RegisterEvent(event)
    end
    return Callbacks:RegisterCallback(event, func, self)
end
function ns:UnregisterCallback(event)
    if not Callbacks:DoesFrameHaveEvent(event) then
        Callbacks:UnregisterEvent(event)
    end
    return Callbacks:UnregisterCallback(event, self)
end
function ns:TriggerEvent(...)
    return Callbacks:TriggerEvent(...)
end

ns:RegisterCallback("ADDON_LOADED", function(self, event, name)
    if name ~= myname then return end

    _G[myname.."DB"] = setmetatable(_G[myname.."DB"] or {}, {
        __index = {
            minimap = false,
            announce = false,
            removed = true,
            showInCompartment=true,
        },
    })
    _G[myname.."DBPC"] = setmetatable(_G[myname.."DBPC"] or {}, {
        __index = {
            -- nothing right now
        },
    })
    db = _G[myname.."DB"]
    dbpc = _G[myname.."DBPC"]
    if not dbpc.log then
        dbpc.log = {}
    end

    ns.db = db
    ns.dbpc = dbpc

    if icon then
        icon:Register(myname, ns.dataobject, db)
    end

    self:UnregisterCallback("ADDON_LOADED")
    if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterCallback("PLAYER_LOGIN") end
end)
function ns:PLAYER_LOGIN()
    -- Quests
    self:RegisterCallback("QUEST_LOG_UPDATE")
    if C_EventUtils.IsEventValid("ENCOUNTER_LOOT_RECEIVED") then
        self:RegisterCallback("ENCOUNTER_LOOT_RECEIVED")
    end
    self:UnregisterCallback("PLAYER_LOGIN")

    if C_QuestLog.GetAllCompletedQuestIDs then
        new_quests = C_QuestLog.GetAllCompletedQuestIDs(new_quests)
        for _, questid in pairs(new_quests) do
            quests[questid] = true
        end
    else
        quests = GetQuestsCompleted()
    end

    -- Vignettes
    if ns.VIGNETTES then
        self:RegisterCallback("PLAYER_ENTERING_WORLD")
        self:RegisterCallback("VIGNETTE_MINIMAP_UPDATED")
        self:RegisterCallback("VIGNETTES_UPDATED")
    end

    if C_EventUtils.IsEventValid("MINIMAP_PING") then
        self:RegisterCallback("MINIMAP_PING")
    else
        Minimap:HookScript("OnMouseDown", function(...) ns:OnMinimapMouseDown(...) end)
    end
end
function ns:QUEST_LOG_UPDATE()
    Callbacks:Show()
end
ns.ENCOUNTER_LOOT_RECEIVED = ns.QUEST_LOG_UPDATE

do
    local time_since = 0
    Callbacks:SetScript("OnUpdate", function(self, elapsed)
        time_since = time_since + elapsed
        if time_since < 0.3 then
            return
        end
        ns:CheckQuests()
        time_since = 0
        self:Hide()
    end)
end

ns.quest_names = {}
setmetatable(ns.quest_names, {__index = function(self, key)
    local name = (C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo)(key)
    if name then
        self[key] = name
        return name
    end
    return false
end,})

function QuestsChangedGetQuestTitle(id)
    return ns.quest_names[id]
end

function ns:CheckQuests()
    if not quests then
        return
    end
    local mapdata, x, y
    wipe(new_quests_byid)
    if C_QuestLog.GetAllCompletedQuestIDs then
        new_quests = C_QuestLog.GetAllCompletedQuestIDs(new_quests)
        for _, questid in pairs(new_quests) do
            new_quests_byid[questid] = true
        end
    else
        new_quests_byid = GetQuestsCompleted(new_quests_byid)
    end
    for questid in pairs(new_quests_byid) do
        if not quests[questid] and not session_quests[questid] and not SPAM_QUESTS[questid] then
            if not mapdata then
                local mapID = C_Map.GetBestMapForUnit('player')
                if mapID then
                    mapdata = C_Map.GetMapInfo(mapID)
                    local position = C_Map.GetPlayerMapPosition(mapdata.mapID, 'player')
                    if position then
                        x, y = position:GetXY()
                    end
                end
            end
            local questName = self.quest_names[questid] -- prime it
            local quest = {
                id = questid,
                time = time(),
                map = mapdata and mapdata.mapID or 0,
                x = x or 0,
                y = y or 0,
            }
            table.insert(self.quests_completed, quest)
            table.insert(self.dbpc.log, quest)
            session_quests[questid] = true

            if db.announce then
                self.Print("Quest complete:", questid, questName or UNKNOWN)
            end

            self:TriggerEvent(self.Event.OnQuestAdded, quest, #self.dbpc.log)
        end
        quests[questid] = true
    end
    if db.removed then
        for questid in pairs(quests) do
            if not new_quests_byid[questid] and not SPAM_QUESTS[questid] then
                quests[questid] = nil
                if db.announce then
                    self.Print("Quest no longer complete:", questid, self.quest_names[questid] or UNKNOWN)
                end
            end
        end
    end
end

function ns:RemoveQuest(index)
    if index == "all" then
        table.wipe(self.quests_completed)
        table.wipe(self.dbpc.log)
        self:TriggerEvent(self.Event.OnAllQuestsRemoved)
    else
        local quest
        if type(index) == "table" then
            quest = index
            index = tIndexOf(self.dbpc.log, quest)
            if not index then return end
        else
            quest = self.dbpc.log[index]
        end

        for i, q in ipairs(self.quests_completed) do
            if q.id == quest.id then
                tremove(self.quests_completed, i)
                break
            end
        end
        tremove(self.dbpc.log, index)
        self:TriggerEvent(self.Event.OnQuestRemoved, quest, index)
    end
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobject = ldb:GetDataObjectByName("QuestsChanged") or ldb:NewDataObject("QuestsChanged", {
    type = "data source",
    label = "QuestsChanged",
    icon = [[Interface\Minimap\Tracking\QuestBlob]],
})

dataobject.OnClick = function(frame, button)
    if button == "RightButton" then
        if IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown() then
            return ns:RemoveQuest("all")
        else
            -- clear the current session
            table.wipe(ns.quests_completed)
        end
    elseif button == "MiddleButton" then
        local uiMapID = C_Map.GetBestMapForUnit('player')
        if not uiMapID then return end
        local position = C_Map.GetPlayerMapPosition(uiMapID, 'player')
        if not position then return end
        local px, py = position:GetXY()
        if not (px and py) then return end
        ns:AddPing(uiMapID, px, py, "player")
    else
        if IsShiftKeyDown() then
            local data = ns.dbpc.log[#ns.dbpc.log]
            StaticPopup_Show("QUESTSCHANGED_COPYBOX", nil, nil, ("[%d] = {quest=%d, label=\"\"},"):format(
                ns.GetCoord(data.x, data.y),
                (data.id or "nil")
            ))
        else
            ns:ToggleLog()
        end
    end
end

dataobject.OnTooltipShow = function(tooltip)
    ns:CheckQuests() -- in case
    tooltip:AddLine("QuestsChanged")
    for _, quest in ipairs(ns.quests_completed) do
        local map, level
        if type(quest.map) == 'string' then
            -- pre-8.0 quest logging has mapFiles, just show them
            map = quest.map
            level = quest.level
        else
            map, level = ns.MapNameFromID(quest.map)
        end
        local still_completed = C_QuestLog.IsQuestFlaggedCompleted(quest.id)
        if still_completed then
            tooltip:AddDoubleLine(
                ("%d: %s %s%s"):format(
                    quest.id, ns.quest_names[quest.id] or UNKNOWN,
                    C_QuestLog.IsQuestFlaggedCompletedOnAccount and C_QuestLog.IsQuestFlaggedCompletedOnAccount(quest.id) and ns.WARBANDS_ICON or "",
                    still_completed and "" or ns.CROSS_ICON
                ),
                ("%s (%s) %.2f, %.2f"):format(quest.map, map .. (level and (' / ' .. level) or ''), quest.x * 100, quest.y * 100)
            )
        end
    end

    local x, y
    local mapID = C_Map.GetBestMapForUnit('player')
    if mapID then
        local position = C_Map.GetPlayerMapPosition(mapID, 'player')
        if position then
            x, y = position:GetXY()
        end
    end
    local mapname, subname = ns.MapNameFromID(mapID)

    tooltip:AddDoubleLine("Location", ("%s (%s) %.2f, %.2f"):format(mapID or UNKNOWN, mapname .. (subname and (' / ' .. subname) or ''), (x or 0) * 100, (y or 0) * 100), 1, 0, 1, 1, 0, 1)
    tooltip:AddLine("Left-click to show your quest history", 0, 1, 1)
    tooltip:AddLine("Shift-left-click to copy the last quest", 0, 1, 1)
    tooltip:AddLine("Middle-click to log a ping at your current location", 0, 1, 1)
    tooltip:AddLine("Right-click to clear the current session", 1, 0, 0)
    tooltip:AddLine("Ctrl-shift-alt-right-click to clear the entire history", 1, 0, 0)
end

ns.dataobject = dataobject

-- slash

_G["SLASH_".. myname:upper().."1"] = "/questschanged"
SlashCmdList[myname:upper()] = function(msg)
    msg = msg:trim()
    if msg == "log" or msg == "" then
        ns:ToggleLog()
    elseif msg == "icon" then
        if not icon then return end
        db.hide = not db.hide
        if db.hide then
            icon:Hide(myname)
        else
            icon:Show(myname)
        end
        ns.Print("icon", db.hide and "hidden" or "shown")
    elseif msg == "removed" then
        db.removed = not db.removed
        ns.Print("watch for removed quests", db.removed and "enabled" or "disabled")
    elseif msg == "announce" then
        db.announce = not db.announce
        ns.Print("announce in chat", db.announce and "enabled" or "disabled")
    end
end

-- utility

function ns.Print(...) print("|cFF33FF99".. myfullname.. "|r:", ...) end

function ns.MapNameFromID(mapID)
    if not mapID then
        return UNKNOWN
    end
    local mapdata = C_Map.GetMapInfo(mapID)
    if not mapdata then
        return UNKNOWN
    end
    local groupID = C_Map.GetMapGroupID(mapID)
    if groupID then
        local groupdata = C_Map.GetMapGroupMembersInfo(groupID)
        for _, subzonedata in ipairs(groupdata) do
            if subzonedata.mapID == mapID then
                return mapdata.name, subzonedata.name
            end
        end
    end
    return mapdata.name
end

function ns.GetCoord(x, y)
    return floor(x * 10000 + 0.5) * 10000 + floor(y * 10000 + 0.5)
end

StaticPopupDialogs["QUESTSCHANGED_COPYBOX"] = {
    text = "Copy me",
    hasEditBox = true,
    hideOnEscape = true,
    whileDead = true,
    closeButton = true,
    editBoxWidth = 350,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    button1 = "Done",
    OnButton1 = function(self, data)
        return false
    end,
    OnShow = function(self, data)
        if data and self:GetEditBox() then
            self:GetEditBox():SetText(data)
            self:GetEditBox():HighlightText()
        end
    end,
}
